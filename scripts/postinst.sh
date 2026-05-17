#!/bin/bash
set -e

# Post-installation script for wazuh-agent-bundle
# This script runs after the package is installed on Linux

OSSEC_PATH="/var/ossec"
AR_BIN_DIR="/var/ossec/active-response/bin"

# Write version file - read from dpkg/rpm since nFPM doesn't pass VERSION env var
VERSION_FILE="$OSSEC_PATH/version.txt"
PKG_VERSION=""

if command -v dpkg-query >/dev/null 2>&1; then
    PKG_VERSION=$(dpkg-query --showformat='${Version}' --show wazuh-agent-bundle 2>/dev/null || true)
elif command -v rpm >/dev/null 2>&1; then
    PKG_VERSION=$(rpm -q --queryformat '%{VERSION}' wazuh-agent-bundle 2>/dev/null || true)
fi

if [ -n "$PKG_VERSION" ]; then
    echo "$PKG_VERSION" > "$VERSION_FILE"
    echo "Wrote version $PKG_VERSION to $VERSION_FILE"
else
    echo "Warning: could not determine package version, skipping version file"
fi

# Ensure active-response bin directory exists
mkdir -p "$AR_BIN_DIR"

# Set correct ownership and permissions on active-response scripts
# Only chown to wazuh group if it exists (created by wazuh-agent install)
if getent group wazuh > /dev/null 2>&1; then
    OWNER="root:wazuh"
else
    echo "Warning: wazuh group not found, setting ownership to root:root"
    OWNER="root:root"
fi

if [ -f "$AR_BIN_DIR/disable-usb-storage.sh" ]; then
    chown "$OWNER" "$AR_BIN_DIR/disable-usb-storage.sh"
    chmod 750 "$AR_BIN_DIR/disable-usb-storage.sh"
fi

if [ -f "$AR_BIN_DIR/alert-usb-hid.sh" ]; then
    chown "$OWNER" "$AR_BIN_DIR/alert-usb-hid.sh"
    chmod 750 "$AR_BIN_DIR/alert-usb-hid.sh"
fi

echo "Post-installation completed successfully"
