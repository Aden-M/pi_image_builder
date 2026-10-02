#!/bin/bash
# 05_set_password.sh (Chroot)
# Loads passwords from the staged users.csv. Each row's plaintext password is
# applied with chpasswd; a blank password locks the account (SSH-key login only).

set -e
# shellcheck disable=SC1091
source /opt/provisioning/lib.sh

echo "Loading passwords from CSV..."

users_rows | while IFS=',' read -r username password groups shell ssh_keys; do
    username="$(trim "$username")"
    [ -z "$username" ] && continue

    if ! id "$username" &>/dev/null; then
        echo "  user '${username}' missing; skipping password."
        continue
    fi

    # NOTE: password is intentionally not trimmed (spaces may be significant).
    if [ -n "$password" ]; then
        echo "${username}:${password}" | chpasswd
        echo "  password set for '${username}'."
    else
        passwd -l "$username" >/dev/null 2>&1 || true
        echo "  no password for '${username}'; account locked (key-only login)."
    fi
done

echo "Password loading complete."
