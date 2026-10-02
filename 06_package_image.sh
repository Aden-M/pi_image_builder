#!/bin/bash
# 06_package_image.sh (Run on Host, requires sudo)
# Seals the provisioned image: removes the qemu shim, unmounts partitions,
# detaches the loop device, and compresses the result into a flashable
# .img.xz. The uncompressed .img is left in place as well.

set -e

WORKSPACE_ROOT="$(pwd)"
STATE_FILE="${WORKSPACE_ROOT}/.build_state"
COMPRESS="${COMPRESS:-1}"   # set COMPRESS=0 to skip xz compression

if [ ! -f "$STATE_FILE" ]; then
    echo "Error: $STATE_FILE not found. Nothing appears to be mounted."
    exit 1
fi
# shellcheck disable=SC1090
source "$STATE_FILE"

echo "Removing qemu emulator shim from the image..."
sudo rm -f "${MOUNT_DIR}/usr/bin/qemu-aarch64-static"

echo "Syncing and unmounting..."
sync
sudo umount "${MOUNT_DIR}/boot/firmware" 2>/dev/null || true
sudo umount "${MOUNT_DIR}" 2>/dev/null || true

echo "Detaching loop device ${LOOP_DEV}..."
sudo losetup -d "$LOOP_DEV" 2>/dev/null || true

rmdir "$MOUNT_DIR" 2>/dev/null || true
rm -f "$STATE_FILE"

echo "========================================"
echo "Base image sealed: ${WORK_IMAGE}"

if [ "$COMPRESS" = "1" ]; then
    echo "Compressing to $(basename "$WORK_IMAGE").xz (this can take a while)..."
    xz -T0 -k -f "$WORK_IMAGE"
    echo "Flashable compressed image: ${WORK_IMAGE}.xz"
fi

echo "========================================"
echo "Success! Flash with Raspberry Pi Imager, BalenaEtcher, or:"
echo "  xzcat ${WORK_IMAGE}.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync"
