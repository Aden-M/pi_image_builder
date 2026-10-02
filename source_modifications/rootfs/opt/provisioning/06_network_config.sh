#!/bin/bash
# 06_network_config.sh (Chroot)
# Generates a netplan config from the staged network.conf for Wi-Fi and/or
# static IPs. If no network.conf is present (or it configures nothing), the
# image keeps its default cloud-init DHCP behaviour untouched.

set -e

NETCONF="/opt/provisioning/network.conf"
NETPLAN="/etc/netplan/99-harness.yaml"

if [ ! -f "$NETCONF" ]; then
    echo "No network.conf staged; leaving default DHCP (cloud-init)."
    exit 0
fi

# shellcheck disable=SC1090
source "$NETCONF"

# Decide whether anything is actually configured.
configured=0
if [ -n "${WIFI_SSID:-}" ];      then configured=1; fi
if [ -n "${ETH_STATIC_IP:-}" ];  then configured=1; fi
if [ -n "${WIFI_STATIC_IP:-}" ]; then configured=1; fi

if [ "$configured" -eq 0 ]; then
    echo "network.conf present but nothing configured; leaving default DHCP."
    exit 0
fi

ETH_IF="${ETH_IF:-eth0}"
WIFI_IF="${WIFI_IF:-wlan0}"

echo "Writing custom netplan configuration to ${NETPLAN}..."

# Take authority over networking away from cloud-init so our file is not
# overwritten on boot. (Only done when we actually provide config.)
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# Build the netplan YAML.
{
    echo "network:"
    echo "  version: 2"
    echo "  renderer: networkd"

    # --- Ethernet ---
    echo "  ethernets:"
    echo "    ${ETH_IF}:"
    if [ -n "${ETH_STATIC_IP:-}" ]; then
        echo "      dhcp4: false"
        echo "      addresses: [${ETH_STATIC_IP}]"
        if [ -n "${ETH_GATEWAY:-}" ]; then
            echo "      routes:"
            echo "        - to: default"
            echo "          via: ${ETH_GATEWAY}"
        fi
        if [ -n "${ETH_DNS:-}" ]; then
            echo "      nameservers:"
            echo "        addresses: [$(echo "$ETH_DNS" | tr ';' ',')]"
        fi
    else
        echo "      dhcp4: true"
        echo "      optional: true"
    fi

    # --- Wi-Fi (only when an SSID is set) ---
    if [ -n "${WIFI_SSID:-}" ]; then
        echo "  wifis:"
        echo "    ${WIFI_IF}:"
        if [ -n "${WIFI_STATIC_IP:-}" ]; then
            echo "      dhcp4: false"
            echo "      addresses: [${WIFI_STATIC_IP}]"
            if [ -n "${WIFI_GATEWAY:-}" ]; then
                echo "      routes:"
                echo "        - to: default"
                echo "          via: ${WIFI_GATEWAY}"
            fi
            if [ -n "${WIFI_DNS:-}" ]; then
                echo "      nameservers:"
                echo "        addresses: [$(echo "$WIFI_DNS" | tr ';' ',')]"
            fi
        else
            echo "      dhcp4: true"
        fi
        echo "      access-points:"
        echo "        \"${WIFI_SSID}\":"
        echo "          password: \"${WIFI_PASSWORD}\""
    fi
} > "$NETPLAN"

# netplan requires the file to be root-only or it warns and may ignore it.
chmod 600 "$NETPLAN"

# Wi-Fi needs the supplicant and a regulatory domain to bring the radio up.
if [ -n "${WIFI_SSID:-}" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get install -y wpasupplicant
    if [ -n "${WIFI_COUNTRY:-}" ]; then
        echo "REGDOMAIN=${WIFI_COUNTRY}" > /etc/default/crda 2>/dev/null || true
    fi
fi

# Validate config generation (does not apply inside chroot).
netplan generate 2>/dev/null || true

echo "Network configuration complete."
