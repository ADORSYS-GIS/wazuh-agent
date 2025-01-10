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
WOPS_VERSION=${WOPS_VERSION:-"0.2.11"}
# Define the OSSEC configuration path
if [ "$(uname)" = "Darwin"* ]; then
    # macOS
    OSSEC_CONF_PATH="/Library/Ossec/etc/ossec.conf"
else
    # Linux
    OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
fi

USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'events.dev.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.9.2-1'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-test-agent-name}

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
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/develop/scripts/deps.sh > "$TMP_FOLDER/deps.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.sh > "$TMP_FOLDER/install-wazuh-agent.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-cert-oauth2.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/main/scripts/install.sh > "$TMP_FOLDER/install-wazuh-agent-status.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/install.sh > "$TMP_FOLDER/install-yara.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/install.sh > "$TMP_FOLDER/install-snort.sh"

# Step 0: Install dependencies
info_message "Install dependencies"
if ! (sudo env bash "$TMP_FOLDER/deps.sh") 2>&1; then
    error_message "Failed to install dependencies"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (sudo LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" bash "$TMP_FOLDER/install-wazuh-agent.sh") 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
info_message "Installing wazuh-cert-oauth2-client"
if ! (sudo LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH APP_NAME="$APP_NAME" WOPS_VERSION="$WOPS_VERSION" bash "$TMP_FOLDER/install-wazuh-cert-oauth2.sh") 2>&1; then
    error_message "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install wazuh-agent-status
info_message "Installing wazuh-agent-status"
if ! (bash "$TMP_FOLDER/install-wazuh-agent-status.sh") 2>&1; then
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
