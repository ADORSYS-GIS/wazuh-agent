#!/bin/sh

# Default log level and application details
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
WOPS_VERSION=${WOPS_VERSION:-"0.2.1"}
OSSEC_CONF_PATH=${OSSEC_CONF_PATH:-"/var/ossec/etc/ossec.conf"}
USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'master.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.8.2-1'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-}
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

# Step 0: Ensure Curl and JQ are installed
info_message "Ensuring dependencies are installed"
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/deps.sh | sudo bash) 2>&1; then
    error_message "Failed to ensure deps"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/fix/scripts/install.sh | LOG_LEVEL=$LOG_LEVEL OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER=$WAZUH_MANAGER sudo bash) 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
info_message "Installing wazuh-cert-oauth2-client"
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/main/scripts/install.sh | LOG_LEVEL=$LOG_LEVEL OSSEC_CONF_PATH=$OSSEC_CONF_PATH APP_NAME=$APP_NAME WOPS_VERSION=$WOPS_VERSION sudo sh) 2>&1; then
    error_message "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install yara
info_message "Installing yara"
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/install.sh |  bash) 2>&1; then
    error_message "Failed to install 'yara'"
    exit 1
fi

# Step 4: Download and install snort
info_message "Installing snort"
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/install.sh |  bash) 2>&1; then
    error_message "Failed to install 'snort'"
    exit 1
fi