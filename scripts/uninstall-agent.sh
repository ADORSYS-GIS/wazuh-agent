#!/bin/sh

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

TMP_FOLDER="$(mktemp -d)"

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

# Logging helpers
info_message() {
    log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[INFO]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

print_step() {
    log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"
}

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}

trap cleanup EXIT

info_message "Starting uninstallation. Using temporary directory: \"$TMP_FOLDER\""

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/Improve-install.sh/issue-78/scripts/install.sh > "$TMP_FOLDER/uninstall-wazuh-agent.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/main/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-wazuh-agent-status.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-yara.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-snort.sh"

# Step 1: Uninstall Wazuh agent
print_step 1 "Uninstalling Wazuh agent..."
if ! (sudo bash "$TMP_FOLDER/uninstall-wazuh-agent.sh") 2>&1; then
    error_message "Failed to uninstall wazuh-agent"
    exit 1
fi

# Step 2: Uninstall wazuh-agent-status
print_step 2 "Uninstalling wazuh-agent-status..."
if ! (bash "$TMP_FOLDER/uninstall-wazuh-agent-status.sh") 2>&1; then
    error_message "Failed to uninstall 'wazuh-agent-status'"
    exit 1
fi

# Step 3: Uninstall yara
print_step 3 "Uninstalling yara..."
if ! (bash "$TMP_FOLDER/uninstall-yara.sh") 2>&1; then
    error_message "Failed to uninstall 'yara'"
    exit 1
fi

# Step 4: Uninstall snort
print_step 4 "Uninstalling snort..."
if ! (bash "$TMP_FOLDER/uninstall-snort.sh") 2>&1; then
    error_message "Failed to uninstall 'snort'"
    exit 1
fi

success_message "Uninstallation completed successfully."
