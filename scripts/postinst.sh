#!/bin/bash
set -e

# Post-installation script for wazuh-agent-bundle
# This script runs after the package is installed on Linux

OSSEC_PATH="/var/ossec"
AR_BIN_DIR="/var/ossec/active-response/bin"
WAZUH_GPG_KEY="/usr/share/keyrings/wazuh.gpg"
WAZUH_REPO_FILE="/etc/apt/sources.list.d/wazuh.list"

# ---------------------------------------------------------------
# Step 1: Add Wazuh's official APT repo so apt can install
#         wazuh-agent as a dependency automatically
# ---------------------------------------------------------------
if [[ ! -f "$WAZUH_REPO_FILE" ]]; then
    echo "Setting up Wazuh APT repository..."

    # Import Wazuh GPG key
    if command -v gpg >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH \
            | gpg --no-default-keyring --keyring "$WAZUH_GPG_KEY" --import 2>/dev/null
        chmod 644 "$WAZUH_GPG_KEY"

        # Add Wazuh APT repo
        echo "deb [signed-by=$WAZUH_GPG_KEY] https://packages.wazuh.com/4.x/apt/ stable main" \
            > "$WAZUH_REPO_FILE"

        echo "Wazuh repository added successfully."
    else
        echo "Warning: curl or gpg not available, skipping Wazuh repo setup"
    fi
else
    echo "Wazuh repository already configured."
fi

# ---------------------------------------------------------------
# Step 2: Write version file
# ---------------------------------------------------------------
VERSION_FILE="$OSSEC_PATH/version.txt"
PKG_VERSION=""

if command -v dpkg-query >/dev/null 2>&1; then
    PKG_VERSION=$(dpkg-query --showformat='${Version}' --show wazuh-agent-bundle 2>/dev/null || true)
elif command -v rpm >/dev/null 2>&1; then
    PKG_VERSION=$(rpm -q --queryformat '%{VERSION}' wazuh-agent-bundle 2>/dev/null || true)
fi

mkdir -p "$OSSEC_PATH"
if [[ -n "$PKG_VERSION" ]]; then
    echo "$PKG_VERSION" > "$VERSION_FILE"
    echo "Wrote version $PKG_VERSION to $VERSION_FILE"
else
    echo "Warning: could not determine package version, skipping version file"
fi

# ---------------------------------------------------------------
# Step 3: Set correct ownership and permissions on USB DLP scripts
# ---------------------------------------------------------------
mkdir -p "$AR_BIN_DIR"

if getent group wazuh > /dev/null 2>&1; then
    OWNER="root:wazuh"
else
    echo "Warning: wazuh group not found, setting ownership to root:root"
    OWNER="root:root"
fi

if [[ -f "$AR_BIN_DIR/disable-usb-storage.sh" ]]; then
    chown "$OWNER" "$AR_BIN_DIR/disable-usb-storage.sh"
    chmod 750 "$AR_BIN_DIR/disable-usb-storage.sh"
fi

if [[ -f "$AR_BIN_DIR/alert-usb-hid.sh" ]]; then
    chown "$OWNER" "$AR_BIN_DIR/alert-usb-hid.sh"
    chmod 750 "$AR_BIN_DIR/alert-usb-hid.sh"
fi

echo "Post-installation completed successfully"
