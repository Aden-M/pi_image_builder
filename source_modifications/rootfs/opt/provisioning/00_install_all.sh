#!/bin/bash
# 00_install_all.sh (Runs inside Chroot)

set -e

PROVISIONING_DIR="/opt/provisioning"

echo "Starting automated chroot provisioning..."

if [ ! -d "$PROVISIONING_DIR" ]; then
    echo "Error: Provisioning directory not found at $PROVISIONING_DIR"
    exit 1
fi

# Find and execute all numbered scripts in strict numerical order
for script in $(find "$PROVISIONING_DIR" -maxdepth 1 -name "[0-9][0-9]_*.sh" | sort); do
    # Skip the master runner itself
    if [[ "$(basename "$script")" != "00_install_all.sh" ]]; then
        echo ""
        echo "========================================"
        echo "--> Executing $(basename "$script")"
        echo "========================================"
        
        # Ensure the script has execution permissions
        chmod +x "$script"
        
        # Execute the payload
        bash "$script"
    fi
done

echo ""
echo "========================================"
echo "All provisioning payloads executed successfully."
echo "Cleaning up provisioning payload directory..."

# Remove the staging directory to secure the keys and save space
rm -rf "$PROVISIONING_DIR"

echo "Provisioning complete. Image is ready."