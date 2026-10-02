#!/bin/bash
# 05_provision_image.sh (Run on Host, requires sudo)
# Enters the mounted rootfs via qemu-aarch64 chroot and runs the master
# provisioning hook (/opt/provisioning/00_install_all.sh). The image rootfs
# stays mounted afterwards so 06_package_image.sh can seal it.

set -e

WORKSPACE_ROOT="$(pwd)"
STATE_FILE="${WORKSPACE_ROOT}/.build_state"
QEMU_BIN="/usr/bin/qemu-aarch64-static"

if [ ! -f "$STATE_FILE" ]; then
    echo "Error: $STATE_FILE not found. Run 04_mount_image.sh first."
    exit 1
fi
# shellcheck disable=SC1090
source "$STATE_FILE"
ROOTFS_DIR="$MOUNT_DIR"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: rootfs mount point $ROOTFS_DIR does not exist."
    exit 1
fi

if [ ! -f "$QEMU_BIN" ]; then
    echo "Error: $QEMU_BIN not found on host."
    echo "Install it with: sudo apt-get install -y qemu-user-static binfmt-support"
    exit 1
fi

echo "Preparing chroot environment in: $ROOTFS_DIR"

# Tear down ONLY the pseudo-filesystem binds on exit; leave the image rootfs
# mounted so packaging can proceed. Full unmount happens in 06.
cleanup() {
    echo "Unmounting chroot pseudo-filesystems..."
    sudo umount "$ROOTFS_DIR/proc" 2>/dev/null || true
    sudo umount "$ROOTFS_DIR/sys" 2>/dev/null || true
    sudo umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    sudo umount "$ROOTFS_DIR/dev" 2>/dev/null || true
    # Restore the image's default resolv.conf symlink (systemd-resolved stub).
    sudo rm -f "$ROOTFS_DIR/etc/resolv.conf"
    sudo ln -sf ../run/systemd/resolve/stub-resolv.conf "$ROOTFS_DIR/etc/resolv.conf"
    echo "Cleanup finished."
}
trap cleanup EXIT

# Ensure the aarch64 emulator is present inside the rootfs.
sudo cp "$QEMU_BIN" "$ROOTFS_DIR/usr/bin/qemu-aarch64-static"

echo "Mounting host pseudo-filesystems..."
sudo mount --bind /dev "$ROOTFS_DIR/dev"
sudo mount -t devpts devpts "$ROOTFS_DIR/dev/pts"
sudo mount --bind /sys "$ROOTFS_DIR/sys"
sudo mount --bind /proc "$ROOTFS_DIR/proc"
# Give the chroot working DNS by copying the host resolver over the image's
# symlink (restored on cleanup) so apt can reach the archive.
sudo rm -f "$ROOTFS_DIR/etc/resolv.conf"
sudo cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

echo "Executing provisioning payload inside chroot..."
sudo chmod +x "$ROOTFS_DIR/opt/provisioning/00_install_all.sh"
sudo chroot "$ROOTFS_DIR" /bin/bash -c "/opt/provisioning/00_install_all.sh"

echo "Provisioning complete. Next: run 06_package_image.sh"
# The trap unmounts the pseudo-filesystems; the image rootfs remains mounted.
