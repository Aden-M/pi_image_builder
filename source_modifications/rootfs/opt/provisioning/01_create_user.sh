#!/bin/bash
# 01_create_user.sh (Chroot)
# Creates every user listed in the staged users.csv and applies their groups.
# Passwords are set later by 05_set_password.sh; shells by 03_setup_zsh.sh.

set -e
# shellcheck disable=SC1091
source /opt/provisioning/lib.sh

echo "Creating users from CSV..."

users_rows | while IFS=',' read -r username password groups shell ssh_keys; do
    username="$(trim "$username")"
    [ -z "$username" ] && continue
    groups="$(trim "$groups")"

    if id "$username" &>/dev/null; then
        echo "User '${username}' already exists; skipping creation."
    else
        echo "Creating user '${username}'..."
        useradd -m -s /bin/bash "$username"
    fi

    # Apply extra groups (';'-separated), skipping any that don't exist.
    if [ -n "$groups" ]; then
        IFS=';' read -ra grparr <<< "$groups"
        for grp in "${grparr[@]}"; do
            grp="$(trim "$grp")"
            [ -z "$grp" ] && continue
            if getent group "$grp" >/dev/null 2>&1; then
                usermod -aG "$grp" "$username"
            else
                echo "  group '${grp}' not found; skipping."
            fi
        done
    fi
done

echo "User creation complete."
