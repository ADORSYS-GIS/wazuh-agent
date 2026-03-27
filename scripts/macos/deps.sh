#!/bin/sh

set -eu

# Repository ref
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.9.0-rc.1'}
WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}

# Try to source local utils.sh first, fallback to downloading
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../shared/utils.sh" ]; then
    . "$SCRIPT_DIR/../shared/utils.sh"
else
    # Create a secure temporary directory for utilities
    UTILS_TMP=$(mktemp -d)
    trap 'rm -rf "$UTILS_TMP"' EXIT
    if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/shared/utils.sh" -o "$UTILS_TMP/utils.sh"; then
        error_message "Failed to download utils.sh"
        exit 1
    fi
    . "$UTILS_TMP/utils.sh"
fi

# 1. Download checksums (only if we downloaded utils.sh)
if [ ! -f "$SCRIPT_DIR/../shared/utils.sh" ]; then
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" "$UTILS_TMP/checksums.sha256"; then
        error_message "Failed to download checksums.sha256"
        exit 1
    fi

    # 2. Verify utils.sh integrity
    EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
    ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

    if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        echo "Error: Checksum verification failed for utils.sh" >&2
        exit 1
    fi
fi

LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')

#Get the logged-in user on macOS
brew_command() {
    sudo -u "$LOGGED_IN_USER" -i brew "$@"
}

# Detect OS and install packages
OS_NAME=$(uname -s)
case "$OS_NAME" in
    "Darwin")
        info_message "Detected macOS"
        brew_command install jq gsed bash python3
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

success_message "Dependencies installed successfully!"