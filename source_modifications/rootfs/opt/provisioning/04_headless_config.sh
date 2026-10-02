#!/bin/bash
# 04_headless_config.sh (Chroot)
# Ubuntu Server is already headless; this locks that in and keeps the image
# reliably reachable over SSH on first boot.

set -e

echo "Applying headless configuration..."

# 1. Force the CLI (multi-user) boot target — no display manager.
systemctl set-default multi-user.target || true

# 2. Ensure the SSH server is present and enabled at boot.
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y openssh-server
systemctl enable ssh || true

# 3. Set a stable hostname (cloud-init would otherwise default it to 'ubuntu').
echo "raspberrypi" > /etc/hostname
sed -i 's/127.0.1.1.*/127.0.1.1\traspberrypi/' /etc/hosts 2>/dev/null || \
    echo "127.0.1.1	raspberrypi" >> /etc/hosts

# 4. Suppress cloud-init's default 'ubuntu' user (we create 'pi' ourselves) and
#    keep our hostname, while leaving cloud-init's network config intact so the
#    Pi still gets an IP on first boot.
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99_pi_harness.cfg <<'EOF'
# Managed by raspi image builder
users: []
preserve_hostname: true
EOF

echo "Headless configuration complete."
