#!/bin/bash
# 03_setup_zsh.sh (Chroot)
# Installs zsh and sets each user's login shell per the CSV 'shell' column
# (default zsh). Plugins live in /usr/share/zsh-plugins (host step 00 + overlay);
# the skeleton .zshrc ships via /etc/skel.

set -e
# shellcheck disable=SC1091
source /opt/provisioning/lib.sh

echo "Installing Zsh base package..."
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y zsh
ZSH_BIN="$(command -v zsh)"

users_rows | while IFS=',' read -r username password groups shell ssh_keys; do
    username="$(trim "$username")"
    [ -z "$username" ] && continue
    shell="$(trim "$shell")"
    shell="${shell:-zsh}"

    if ! id "$username" &>/dev/null; then
        continue
    fi
    home="$(getent passwd "$username" | cut -d: -f6)"

    case "$shell" in
        zsh)
            chsh -s "$ZSH_BIN" "$username"
            if [ -f /etc/skel/.zshrc ] && [ ! -f "${home}/.zshrc" ]; then
                cp /etc/skel/.zshrc "${home}/.zshrc"
                chown "${username}:${username}" "${home}/.zshrc"
            fi
            echo "  '${username}' -> zsh"
            ;;
        bash)
            chsh -s /bin/bash "$username"
            echo "  '${username}' -> bash"
            ;;
        *)
            echo "  '${username}': unknown shell '${shell}'; leaving default."
            ;;
    esac
done

echo "Zsh configured."
