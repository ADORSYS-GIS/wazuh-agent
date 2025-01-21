#!/bin/sh

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

WAZUH_USER=${WAZUH_USER:-'wazuh'}
WAZUH_GROUP=${WAZUH_GROUP:-'wazuh'}

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

warn_message() {
    log "${YELLOW}${BOLD}[WARNING]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"
}

print_step() {
    log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"
}

# Check if sudo is available or if the script is run as root
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

# Determine OS type and package manager or set for macOS
if [ "$(uname)" = "Darwin" ]; then
    OS="macOS"
    OSSEC_PATH="/Library/Ossec/"
    OSSEC_CONTROL_PATH="/Library/Ossec/bin/wazuh-control"
elif [ -f /etc/debian_version ]; then
    OS="Linux"
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    OSSEC_PATH="/var/ossec/"
    OSSEC_CONTROL_PATH="/var/ossec/bin/wazuh-control"
elif [ -f /etc/redhat-release ]; then
    OS="Linux"
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
    OSSEC_PATH="/var/ossec/"
    OSSEC_CONTROL_PATH="/var/ossec/bin/wazuh-control"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    OS="Linux"
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
    OSSEC_PATH="/var/ossec/"
    OSSEC_CONTROL_PATH="/var/ossec/bin/wazuh-control"
else
    error_message "Unsupported OS"
    exit 1
fi

# Stop Wazuh service if running
stop_service() {
    if [ -x "$OSSEC_CONTROL_PATH" ]; then
        info_message "Stopping Wazuh service..."
        maybe_sudo "$OSSEC_CONTROL_PATH" stop || true
        info_message "Wazuh service stopped successfully"
    else
        warn_message "Wazuh service does not exist, skipping"
    fi
}

# Uninstall Wazuh agent
uninstall_agent() {
    if [ -d "$OSSEC_PATH" ]; then
        info_message "Uninstalling Wazuh agent..."
        if [ "$OS" = "Linux" ]; then
            if [ "$PACKAGE_MANAGER" = "apt" ]; then
                maybe_sudo apt remove -y wazuh-agent
                maybe_sudo apt autoremove -y
            elif [ "$PACKAGE_MANAGER" = "yum" ]; then
                maybe_sudo yum remove -y wazuh-agent
            elif [ "$PACKAGE_MANAGER" = "zypper" ]; then
                maybe_sudo zypper remove -y wazuh-agent
            fi
        elif [ "$OS" = "macOS" ]; then
            maybe_sudo rm -rf /Library/Ossec
    
            # Remove LaunchDaemon and StartUP items
            maybe_sudo rm -f /Library/LaunchDaemons/com.wazuh.agent.plist
            maybe_sudo rm -rf /Library/StartupItems/WAZUH
    
            # Remove from the pkgutil
            maybe_sudo pkgutil --forget com.wazuh.pkg.wazuh-agent
        fi
        info_message "Wazuh agent uninstalled successfully."
    else
        warn_message "Wazuh agent does not exist, skipping"
    fi
}

# Remove repository and GPG key
cleanup_repo() {
    if [ "$OS" = "Linux" ]; then
        info_message "Removing repository and GPG key"
        if [ -f "$REPO_FILE" ]; then
            maybe_sudo rm -f "$REPO_FILE"
        fi

        if [ "$PACKAGE_MANAGER" = "apt" ] && [ -f "/usr/share/keyrings/wazuh.gpg" ]; then
            maybe_sudo rm -f /usr/share/keyrings/wazuh.gpg
        fi
    fi
    info_message "Repository and GPG key removed successfully."
}

# Clean up any remaining Wazuh files
cleanup_files() {
    info_message "Cleaning up remaining Wazuh files"
    if [ "$OS" = "Linux" ]; then
        info_message "Cleaning up remaining Wazuh files"
        maybe_sudo rm -rf /var/ossec
    fi
    info_message "User and group cleanup completed."
}

# Remove user and group
remove_user_group() {
    info_message "Removing user and group if they exist"
    if [ "$OS" = "Darwin" ]; then
        # macOS commands
        if dscl . -list /Users | grep -q "^$WAZUH_USER$"; then
            info_message "Removing user $WAZUH_USER..."
            maybe_sudo dscl . -delete "/Users/$WAZUH_USER" || warn_message "Failed to remove user $WAZUH_USER. Skipping."
        fi

        if dscl . -list /Groups | grep -q "^$WAZUH_GROUP$"; then
            info_message "Removing group $WAZUH_GROUP..."
            maybe_sudo dscl . -delete "/Groups/$WAZUH_GROUP" || warn_message "Failed to remove group $WAZUH_GROUP. Skipping."
        fi
    fi
    if [ "$OS" = "Linux" ]; then
        # Linux commands
        if id -u "$WAZUH_USER" >/dev/null 2>&1; then
            info_message "Removing user $WAZUH_USER..."
            maybe_sudo userdel "$WAZUH_USER" || warn_message "Failed to remove user $WAZUH_USER. Skipping."
        fi

        if getent group "$WAZUH_GROUP" >/dev/null 2>&1; then
            info_message "Removing group $WAZUH_GROUP..."
            maybe_sudo groupdel "$WAZUH_GROUP" || warn_message "Failed to remove group $WAZUH_GROUP. Skipping."
        fi
    fi
    info_message "User and group cleanup completed."
}

# Main execution
stop_service
uninstall_agent
cleanup_repo
cleanup_files
remove_user_group

success_message "Wazuh agent uninstallation completed successfully."

# End of script
