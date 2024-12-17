#!/bin/sh

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

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
    echo "$TIMESTAMP [$LEVEL] $MESSAGE"
}

# Logging helpers
info_message() {
    log INFO "$*"
}

error_message() {
    log ERROR "$*"
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

# Determine OS type and package manager or set for macOS
if [ "$(uname)" = "Darwin" ]; then
    OS="macOS"
    OSSEC_CONF_PATH="/Library/Ossec/etc/ossec.conf"
elif [ -f /etc/debian_version ]; then
    OS="Linux"
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
elif [ -f /etc/redhat-release ]; then
    OS="Linux"
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    OS="Linux"
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
else
    error_message "Unsupported OS"
    exit 1
fi

# Uninstall Wazuh agent
uninstall_agent() {
    info_message "Uninstalling Wazuh agent on $OS"
    
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
    if [ "$OS" = "Linux" ]; then
        info_message "Cleaning up remaining Wazuh files"
        maybe_sudo rm -rf /var/ossec
    fi
}

# Remove user and group
remove_user_group() {
    if id -u "$USER" >/dev/null 2>&1; then
        info_message "Removing user $USER..."
        maybe_sudo userdel "$USER" || warn_message "Failed to remove user $USER. Skipping."
    fi

    if getent group "$GROUP" >/dev/null 2>&1; then
        info_message "Removing group $GROUP..."
        maybe_sudo groupdel "$GROUP" || warn_message "Failed to remove group $GROUP. Skipping."
    fi

    success_message "User and group cleanup completed."
}

# Stop Wazuh service if running
stop_service() {
    info_message "Stopping Wazuh service if running"
    if [ "$OS" = "Linux" ]; then
        SYSTEMD_RUNNING=$(ps -C systemd > /dev/null 2>&1 && echo "yes" || echo "no")
        if [ "$SYSTEMD_RUNNING" = "yes" ]; then
            maybe_sudo systemctl stop wazuh-agent || true
            maybe_sudo systemctl disable wazuh-agent || true
            maybe_sudo systemctl daemon-reload || true
        elif [ -f /etc/init.d/wazuh-agent ]; then
            maybe_sudo service wazuh-agent stop || true
        fi
    elif [ "$OS" = "macOS" ]; then
        maybe_sudo /Library/Ossec/bin/wazuh-control stop || true
    fi
    info_message "Wazuh service stopped successfully."
}

# Main execution
stop_service
uninstall_agent
cleanup_repo
cleanup_files
remove_user_group

info_message "Wazuh agent uninstallation completed successfully."

# End of script