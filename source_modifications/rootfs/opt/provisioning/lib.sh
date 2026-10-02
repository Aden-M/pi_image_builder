#!/bin/bash
# lib.sh — shared helpers for CSV-driven provisioning. Sourced, not executed.
# (No numeric prefix, so 00_install_all.sh does not run it as a step.)

USERS_CSV="/opt/provisioning/users.csv"

# Emit data rows from the users CSV: skips blank lines, comment lines (#), and
# the header row (a line beginning with 'username,'). Never fails the caller.
users_rows() {
    [ -f "$USERS_CSV" ] || return 0
    grep -vE '^[[:space:]]*(#|$)' "$USERS_CSV" \
        | grep -viE '^[[:space:]]*username[[:space:]]*,' \
        || true
}

# Trim leading/trailing whitespace from $1 and print the result.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}
