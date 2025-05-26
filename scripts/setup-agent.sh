#!/bin/sh

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Default log level and application details
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
WOPS_VERSION=${WOPS_VERSION:-"0.2.18"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.3.3"}
WAZUH_SNORT_VERSION=${WAZUH_SNORT_VERSION:-"0.2.2"}
# Define the OSSEC configuration path
if [ "$(uname)" = "Darwin" ]; then
    OSSEC_PATH="/Library/Ossec/etc"
else
    OSSEC_PATH="/var/ossec/etc"
fi
OSSEC_CONF_PATH="$OSSEC_PATH/ossec.conf"

USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.11.1-1'}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-'0.3.2'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-test-agent-name}

INSTALL_TRIVY=${INSTALL_TRIVY:-'FALSE'}

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
    log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}

trap cleanup EXIT

info_message "Starting setup. Using temporary directory: \"$TMP_FOLDER\""

# Step -1: Download all scripts
info_message "Download all scripts..."
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-agent.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-cert-oauth2.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-agent-status.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-yara.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-snort.sh"

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (maybe_sudo env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" bash "$TMP_FOLDER/install-wazuh-agent.sh") 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
info_message "Installing wazuh-cert-oauth2-client"
if ! (maybe_sudo env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH APP_NAME="$APP_NAME" WOPS_VERSION="$WOPS_VERSION" bash "$TMP_FOLDER/install-wazuh-cert-oauth2.sh") 2>&1; then
    error_message "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install wazuh-agent-status
info_message "Installing wazuh-agent-status"
if ! (maybe_sudo bash "$TMP_FOLDER/install-wazuh-agent-status.sh") 2>&1; then
    error_message "Failed to install 'wazuh-agent-status'"
    exit 1
fi

# Step 4: Download and install yara
info_message "Installing yara"
if ! (LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH bash "$TMP_FOLDER/install-yara.sh") 2>&1; then
    error_message "Failed to install 'yara'"
    exit 1
fi

# Step 5: Download and install snort
info_message "Installing snort"
if ! (LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH bash "$TMP_FOLDER/install-snort.sh") 2>&1; then
    error_message "Failed to install 'snort'"
    exit 1
fi

# Step 6: Install Trivy if the flag is set
if [ "$INSTALL_TRIVY" = "TRUE" ]; then
    info_message "Installing Trivy..."
    curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/install.sh" > "$TMP_FOLDER/install-trivy.sh"
    if ! (maybe_sudo bash "$TMP_FOLDER/install-trivy.sh") 2>&1; then
        error_message "Failed to install trivy"
        exit 1
    fi
fi

# Step 7: Download version file
info_message "Downloading version file..."
if ! (maybe_sudo curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/version.txt" -o "$OSSEC_PATH/version.txt") 2>&1; then
    error_message "Failed to download version file"
    exit 1
fi
info_message "Version file downloaded successfully."

success_message "Wazuh has been setup successfully."
