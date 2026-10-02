#!/bin/bash
# 00_build_zsh_plugins.sh (Run on Host)
# Fetches Zsh plugins into the host staging area so they can be overlaid
# onto the target rootfs later. Platform-agnostic.

set -e

PLUGIN_DIR="source_modifications/rootfs/usr/share/zsh-plugins"

# Ensure the target directory structure exists
mkdir -p "$PLUGIN_DIR"

# Clone plugins only if they are not already staged (makes the script re-runnable)
clone_plugin() {
    local url="$1"
    local name
    name="$(basename "$url")"
    if [ -d "${PLUGIN_DIR}/${name}" ]; then
        echo "Plugin ${name} already staged. Skipping."
    else
        git clone --depth 1 "$url" "${PLUGIN_DIR}/${name}"
    fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting"
clone_plugin "https://github.com/marlonrichert/zsh-autocomplete"

echo "Installed zsh plugins into ${PLUGIN_DIR}."
