#!/bin/bash
# 01_download_base_image.sh (Run on Host)
# Downloads the Ubuntu Server preinstalled image for Raspberry Pi and
# verifies it against Canonical's published SHA256SUMS.

set -e

# --- Configuration ---
# Ubuntu release line and exact point release for the Pi preinstalled server image.
# Bump UBUNTU_POINT to the latest 24.04.x point release as needed.
export UBUNTU_SERIES="24.04"
export UBUNTU_POINT="24.04.3"

# Canonical cdimage location for released Raspberry Pi images.
export CDIMAGE_BASE="https://cdimage.ubuntu.com/releases/${UBUNTU_SERIES}/release"

# The preinstalled *server* (headless) image for arm64 Raspberry Pi.
export BASE_IMAGE_XZ="ubuntu-${UBUNTU_POINT}-preinstalled-server-arm64+raspi.img.xz"
# ---------------------

echo "Downloading Ubuntu Server ${UBUNTU_POINT} for Raspberry Pi (arm64)..."
wget -c "${CDIMAGE_BASE}/${BASE_IMAGE_XZ}"

echo "Downloading checksum manifest..."
wget -O SHA256SUMS "${CDIMAGE_BASE}/SHA256SUMS"

echo "Verifying image integrity..."
# Only check the line matching our image; fail loudly on mismatch.
if grep -F "${BASE_IMAGE_XZ}" SHA256SUMS | sha256sum -c -; then
    echo "Checksum OK."
else
    echo "Error: checksum verification FAILED for ${BASE_IMAGE_XZ}."
    echo "Delete the file and re-run this script."
    exit 1
fi

echo "Download complete: ${BASE_IMAGE_XZ}"
