#!/bin/bash
# 03_stage_payload.sh (Run on Host)
# Stages the provisioning payload into the source_modifications overlay:
#   - config/users.csv    -> /opt/provisioning/users.csv
#   - config/network.conf -> /opt/provisioning/network.conf   (optional)
#   - keys/*              -> /opt/provisioning/keys/           (SSH keys)
# Missing config files are auto-created from their .example templates.

set -e

WORKSPACE_ROOT="$(pwd)"
KEYS_DIR="${WORKSPACE_ROOT}/keys"
CONFIG_DIR="${WORKSPACE_ROOT}/config"
PROV="${WORKSPACE_ROOT}/source_modifications/rootfs/opt/provisioning"

mkdir -p "${PROV}/keys"

# --- Users CSV (required) ---
if [ ! -f "${CONFIG_DIR}/users.csv" ]; then
    if [ -f "${CONFIG_DIR}/users.csv.example" ]; then
        echo "config/users.csv not found; creating it from the example template."
        echo ">>> EDIT config/users.csv before a production build. <<<"
        cp "${CONFIG_DIR}/users.csv.example" "${CONFIG_DIR}/users.csv"
    else
        echo "Error: neither config/users.csv nor config/users.csv.example exists."
        exit 1
    fi
fi
cp "${CONFIG_DIR}/users.csv" "${PROV}/users.csv"
echo "Staged users.csv"

# --- Network config (optional) ---
if [ ! -f "${CONFIG_DIR}/network.conf" ] && [ -f "${CONFIG_DIR}/network.conf.example" ]; then
    echo "config/network.conf not found; creating it from the example (DHCP defaults)."
    cp "${CONFIG_DIR}/network.conf.example" "${CONFIG_DIR}/network.conf"
fi
if [ -f "${CONFIG_DIR}/network.conf" ]; then
    cp "${CONFIG_DIR}/network.conf" "${PROV}/network.conf"
    echo "Staged network.conf"
fi

# --- SSH keys (referenced by users.csv ssh_keys column) ---
if [ -d "$KEYS_DIR" ] && [ -n "$(ls -A "$KEYS_DIR" 2>/dev/null | grep -v '^\.gitkeep$' || true)" ]; then
    cp -a "${KEYS_DIR}/." "${PROV}/keys/"
    rm -f "${PROV}/keys/.gitkeep"
    echo "Staged SSH keys from ${KEYS_DIR}"
else
    echo "Warning: no SSH keys found in ${KEYS_DIR}."
    echo "Users with no key and no password will be locked out."
fi

echo "Payload staged successfully at ${PROV}"
