#!/bin/bash
# 02_setup_keys.sh (Chroot)
# Installs SSH keys per user. For each CSV row, the ';'-separated key filenames
# in the ssh_keys column are looked up in the staged keys directory and their
# contents appended to that user's ~/.ssh/authorized_keys.

set -e
# shellcheck disable=SC1091
source /opt/provisioning/lib.sh

STAGED_KEYS="/opt/provisioning/keys"

echo "Installing SSH keys per user..."

users_rows | while IFS=',' read -r username password groups shell ssh_keys; do
    username="$(trim "$username")"
    [ -z "$username" ] && continue
    ssh_keys="$(trim "$ssh_keys")"

    if ! id "$username" &>/dev/null; then
        echo "  user '${username}' missing; skipping keys."
        continue
    fi
    if [ -z "$ssh_keys" ]; then
        echo "  no keys listed for '${username}'."
        continue
    fi

    home="$(getent passwd "$username" | cut -d: -f6)"
    [ -z "$home" ] && continue

    mkdir -p "${home}/.ssh"
    authfile="${home}/.ssh/authorized_keys"

    IFS=';' read -ra keyfiles <<< "$ssh_keys"
    for kf in "${keyfiles[@]}"; do
        kf="$(trim "$kf")"
        [ -z "$kf" ] && continue
        if [ -f "${STAGED_KEYS}/${kf}" ]; then
            cat "${STAGED_KEYS}/${kf}" >> "$authfile"
            echo "" >> "$authfile"
            echo "  '${username}' <- ${kf}"
        else
            echo "  key file '${kf}' not found in staging; skipping."
        fi
    done

    chmod 700 "${home}/.ssh"
    if [ -f "$authfile" ]; then
        chmod 600 "$authfile"
    fi
    chown -R "${username}:${username}" "${home}/.ssh"
done

echo "SSH key setup complete."
