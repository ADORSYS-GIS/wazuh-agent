#!/bin/bash

if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Default application details
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
OSSEC_CONF_PATH=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    OSSEC_CONF_PATH="/Library/Ossec/etc/ossec.conf"
else
    # Linux
    OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() {
    log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

cleanup_files() {
    info_message "Cleaning up files and configurations"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific cleanup
        info_message "Stopping Wazuh agent on macOS"
        sudo launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist || true

        info_message "Removing Wazuh agent on macOS"
        sudo rm -rf /Library/Ossec || true
        sudo rm -f /Library/LaunchDaemons/com.wazuh.agent.plist || true

        info_message "Removing configuration files on macOS"
        sudo rm -f "$OSSEC_CONF_PATH" || true

        info_message "Removing temporary directories on macOS"
        sudo rm -rf /tmp/*wazuh* || true
    else
        # Linux specific cleanup
        info_message "Stopping Wazuh agent"
        sudo systemctl stop wazuh-agent || true
        sudo systemctl disable wazuh-agent || true

        info_message "Removing Wazuh agent"
        sudo apt-get remove --purge wazuh-agent -y || sudo yum remove wazuh-agent -y || true

        info_message "Removing configuration files"
        sudo rm -rf /var/ossec || true
    fi

    # Remove wazuh-cert-oauth2-client
    info_message "Removing wazuh-cert-oauth2-client"
    sudo rm -rf "/opt/$APP_NAME" || true

    # Remove Wazuh Agent Status script
    info_message "Removing Wazuh Agent Status Server script"
    sudo rm -rf /usr/local/bin/wazuh-agent-status || true
    info_message "Removing Wazuh Agent Status Client script"
    sudo rm -rf /usr/local/bin/wazuh-agent-status-client || true

    # Remove yara and snort
    info_message "Removing yara"
    sudo apt-get remove --purge yara -y || sudo yum remove yara -y || true
    info_message "Removing snort"
    sudo apt-get remove --purge snort -y || sudo yum remove snort -y || true

    # Final cleanup
    info_message "Removing temporary directories"
    sudo rm -rf /tmp/*wazuh* || true
}

main() {
    info_message "Starting uninstall process"
    cleanup_files
    info_message "Uninstall process completed"
}

trap 'error_message "An error occurred during uninstallation."' ERR
main
