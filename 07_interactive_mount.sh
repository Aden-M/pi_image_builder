#!/bin/bash
# 07_interactive_mount.sh (Run on Host, requires sudo)
# Self-contained: loop-mounts the working image, drops you into an interactive
# aarch64 chroot for manual inspection/tweaks, then fully unmounts and detaches
# the loop device on exit. Independent of the 04/05/06 build-state flow.

set -e

WORKSPACE_ROOT="$(pwd)"
WORK_IMAGE="${1:-${WORKSPACE_ROOT}/raspi4b_headless.img}"
MOUNT_DIR="${WORKSPACE_ROOT}/mnt_interactive"
QEMU_BIN="/usr/bin/qemu-aarch64-static"
BOOT_PART_NUM="1"
ROOT_PART_NUM="2"

if [ ! -f "$WORK_IMAGE" ]; then
    echo "Error: image $WORK_IMAGE not found."
    exit 1
fi
if [ ! -f "$QEMU_BIN" ]; then
    echo "Error: $QEMU_BIN not found. Install: sudo apt-get install -y qemu-user-static binfmt-support"
    exit 1
fi

echo "Attaching ${WORK_IMAGE} to a loop device..."
LOOP_DEV="$(sudo losetup -Pf --show "$WORK_IMAGE")"

cleanup() {
    echo -e "\nExiting interactive session. Cleaning up..."
    sudo rm -f "${MOUNT_DIR}/usr/bin/qemu-aarch64-static" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/proc" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/sys" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/dev/pts" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/dev" 2>/dev/null || true
    # Restore the image's default resolv.conf symlink before unmounting.
    if mountpoint -q "$MOUNT_DIR"; then
        sudo rm -f "$MOUNT_DIR/etc/resolv.conf"
        sudo ln -sf ../run/systemd/resolve/stub-resolv.conf "$MOUNT_DIR/etc/resolv.conf"
    fi
    sudo umount "$MOUNT_DIR/boot/firmware" 2>/dev/null || true
    sudo umount "$MOUNT_DIR" 2>/dev/null || true
    sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
    rmdir "$MOUNT_DIR" 2>/dev/null || true
    echo "Cleanup finished."
}
trap cleanup EXIT

mkdir -p "$MOUNT_DIR"
sudo mount "${LOOP_DEV}p${ROOT_PART_NUM}" "$MOUNT_DIR"
sudo mkdir -p "${MOUNT_DIR}/boot/firmware"
sudo mount "${LOOP_DEV}p${BOOT_PART_NUM}" "${MOUNT_DIR}/boot/firmware"

sudo cp "$QEMU_BIN" "${MOUNT_DIR}/usr/bin/qemu-aarch64-static"
sudo mount --bind /dev "$MOUNT_DIR/dev"
sudo mount -t devpts devpts "$MOUNT_DIR/dev/pts"
sudo mount --bind /sys "$MOUNT_DIR/sys"
sudo mount --bind /proc "$MOUNT_DIR/proc"
sudo rm -f "$MOUNT_DIR/etc/resolv.conf"
sudo cp /etc/resolv.conf "$MOUNT_DIR/etc/resolv.conf"

echo "--------------------------------------------------------"
echo " Entering interactive chroot shell (aarch64)."
echo " Type 'exit' or press Ctrl+D to leave and trigger cleanup."
echo "--------------------------------------------------------"
sudo chroot "$MOUNT_DIR" /bin/bash || true

# Cleanup runs automatically via the EXIT trap.
