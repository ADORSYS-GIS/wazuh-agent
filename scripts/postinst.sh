#!/bin/bash
set -e

# Post-installation script for wazuh-agent-bundle
# This script runs after the package is installed

# Detect OS and set paths accordingly
if [ "$(uname)" = "Darwin" ]; then
    OSSEC_PATH="/Library/Ossec"
    AR_BIN_DIR="/Library/Ossec/active-response/bin"
    GROUP="wheel"
else
    OSSEC_PATH="/var/ossec"
    AR_BIN_DIR="/var/ossec/active-response/bin"
    GROUP="wazuh"
fi

# Write version file
VERSION_FILE="$OSSEC_PATH/version.txt"
if [ -n "${VERSION:-}" ]; then
    echo "$VERSION" > "$VERSION_FILE"
    echo "Wrote version $VERSION to $VERSION_FILE"
else
    echo "Warning: VERSION environment variable not set, skipping version file"
fi

# Ensure active-response bin directory exists
mkdir -p "$AR_BIN_DIR"

# Set correct ownership and permissions on active-response scripts
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    if [ -f "$AR_BIN_DIR/disable-usb-storage-macos.sh" ]; then
        chown root:wheel "$AR_BIN_DIR/disable-usb-storage-macos.sh"
        chmod 750 "$AR_BIN_DIR/disable-usb-storage-macos.sh"
    fi
    if [ -f "$AR_BIN_DIR/alert-usb-hid.sh" ]; then
        chown root:wheel "$AR_BIN_DIR/alert-usb-hid.sh"
        chmod 750 "$AR_BIN_DIR/alert-usb-hid.sh"
    fi
else
    # Linux
    if [ -f "$AR_BIN_DIR/disable-usb-storage.sh" ]; then
        chown root:wazuh "$AR_BIN_DIR/disable-usb-storage.sh"
        chmod 750 "$AR_BIN_DIR/disable-usb-storage.sh"
    fi
    if [ -f "$AR_BIN_DIR/alert-usb-hid.sh" ]; then
        chown root:wazuh "$AR_BIN_DIR/alert-usb-hid.sh"
        chmod 750 "$AR_BIN_DIR/alert-usb-hid.sh"
    fi
fi

echo "Post-installation completed successfully"
