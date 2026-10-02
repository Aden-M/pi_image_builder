#!/bin/bash
# 04_mount_image.sh (Run on Host, requires sudo)
# Loop-mounts the working image, grows the rootfs to fill the added slack
# space, mounts both partitions, and overlays ./source_modifications/rootfs
# onto the target rootfs. Loop device + mount point are recorded in
# .build_state so 05 and 06 can find them.

set -e

# --- Configuration ---
WORKSPACE_ROOT="$(pwd)"
WORK_IMAGE="${WORKSPACE_ROOT}/raspi4b_headless.img"
MOUNT_DIR="${WORKSPACE_ROOT}/mnt"
MOD_DIR="${WORKSPACE_ROOT}/source_modifications/rootfs"
STATE_FILE="${WORKSPACE_ROOT}/.build_state"
# Partition layout of the Ubuntu Pi image: p1 = boot firmware (vfat), p2 = rootfs (ext4)
BOOT_PART_NUM="1"
ROOT_PART_NUM="2"
# ---------------------

if [ ! -f "$WORK_IMAGE" ]; then
    echo "Error: $WORK_IMAGE not found. Run 02_extract_image.sh first."
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    echo "Error: $STATE_FILE already exists (image may still be mounted)."
    echo "Run 06_package_image.sh to finish, or clean up manually, before re-mounting."
    exit 1
fi

echo "Attaching ${WORK_IMAGE} to a loop device..."
LOOP_DEV="$(sudo losetup -Pf --show "$WORK_IMAGE")"
echo "Loop device: ${LOOP_DEV}"

ROOT_PART="${LOOP_DEV}p${ROOT_PART_NUM}"
BOOT_PART="${LOOP_DEV}p${BOOT_PART_NUM}"

echo "Growing rootfs partition (${ROOT_PART}) to fill available space..."
sudo parted -s "$LOOP_DEV" resizepart "$ROOT_PART_NUM" 100%
sudo partprobe "$LOOP_DEV"

echo "Checking and resizing the ext4 filesystem..."
sudo e2fsck -f -y "$ROOT_PART" || true
sudo resize2fs "$ROOT_PART"

echo "Mounting partitions under ${MOUNT_DIR}..."
mkdir -p "$MOUNT_DIR"
sudo mount "$ROOT_PART" "$MOUNT_DIR"
sudo mkdir -p "${MOUNT_DIR}/boot/firmware"
sudo mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

if [ ! -d "$MOD_DIR" ]; then
    echo "Error: source modifications not found at $MOD_DIR."
    exit 1
fi

echo "Overlaying source modifications onto the rootfs..."
# cp -a preserves permissions, symlinks, and directory structure.
sudo cp -a "${MOD_DIR}/." "${MOUNT_DIR}/"

# Persist state for the provisioning and packaging steps.
{
    echo "LOOP_DEV=${LOOP_DEV}"
    echo "MOUNT_DIR=${MOUNT_DIR}"
    echo "WORK_IMAGE=${WORK_IMAGE}"
} > "$STATE_FILE"

echo "Image mounted and modifications injected."
echo "Next: run 05_provision_image.sh"
