#!/bin/bash
# 02_extract_image.sh (Run on Host)
# Decompresses the downloaded Ubuntu image into a writable working copy and
# grows the file so the rootfs has room for package installs during chroot
# provisioning. (The normal first-boot auto-expand never runs in a chroot.)

set -e

# --- Configuration ---
UBUNTU_POINT="24.04.3"
BASE_IMAGE_XZ="ubuntu-${UBUNTU_POINT}-preinstalled-server-arm64+raspi.img.xz"
WORK_IMAGE="raspi4b_headless.img"

# Extra free space (in MiB) appended to the image for apt installs, zsh, etc.
EXPAND_MB="2048"
# ---------------------

if [ ! -f "$BASE_IMAGE_XZ" ]; then
    echo "Error: $BASE_IMAGE_XZ not found. Run 01_download_base_image.sh first."
    exit 1
fi

echo "Decompressing ${BASE_IMAGE_XZ} -> ${WORK_IMAGE}..."
# -k keeps the compressed source; -c streams to our named working copy.
xz -dc "$BASE_IMAGE_XZ" > "$WORK_IMAGE"

echo "Appending ${EXPAND_MB} MiB of slack space to ${WORK_IMAGE}..."
truncate -s "+${EXPAND_MB}M" "$WORK_IMAGE"

echo "Extraction complete. Working image: ${WORK_IMAGE}"
echo "The rootfs partition will be grown to fill this space during 04_mount_image.sh."
