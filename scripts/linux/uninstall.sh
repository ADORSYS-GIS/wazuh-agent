#!/bin/sh

set -eu

# Repository ref
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.9.0-rc.1'}
WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}

# Download utils.sh from repository
# Create a secure temporary directory for utilities
UTILS_TMP=$(mktemp -d)
trap 'rm -rf "$UTILS_TMP"' EXIT
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/shared/utils.sh" -o "$UTILS_TMP/utils.sh"; then
    echo "Failed to download utils.sh"
    exit 1
fi

# Function to calculate SHA256 (cross-platform bootstrap)
calculate_sha256_bootstrap() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# 1. Download checksums
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi

# 2. Verify utils.sh integrity BEFORE sourcing it
EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# 3. Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

# Common variables
WAZUH_USER=${WAZUH_USER:-'wazuh'}
WAZUH_GROUP=${WAZUH_GROUP:-'wazuh'}
OSSEC_CONTROL_PATH="/var/ossec/bin/wazuh-control"
OSSEC_PATH="/var/ossec/"

# Determine Linux distribution and package manager
if [ -f /etc/debian_version ]; then
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    GPG_KEY_FILE="/usr/share/keyrings/wazuh.gpg"
elif [ -f /etc/redhat-release ]; then
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
else
    error_exit "Unsupported Linux distribution"
fi

# Stop Wazuh service if running
stop_service() {
    SYSTEMD_RUNNING=$(ps -C systemd > /dev/null 2>&1 && echo "yes" || echo "no")
    info_message "Stopping Wazuh service..."
    if [ "$SYSTEMD_RUNNING" = "yes" ]; then
      if ! systemctl disable wazuh-agent || ! systemctl stop wazuh-agent || ! systemctl daemon-reload; then
          warn_message "Failed to stop Wazuh agent service via systemctl. Continuing with manual cleanup."
      fi
    elif maybe_sudo [ -x "$OSSEC_CONTROL_PATH" ]; then
        if ! maybe_sudo "$OSSEC_CONTROL_PATH" stop; then
          warn_message "Failed to stop Wazuh agent service via ossec-control. Continuing with manual cleanup."
        fi
        info_message "Wazuh service stopped successfully"
    else
        warn_message "Wazuh service does not exist, skipping"
    fi

    # Process cleanup (Prevents 'deluser' failure if other components are still running under the wazuh user)
    if id -u "$WAZUH_USER" >/dev/null 2>&1; then
        info_message "Checking for remaining processes owned by $WAZUH_USER..."
        if pgrep -u "$WAZUH_USER" > /dev/null; then
            maybe_sudo pkill -u "$WAZUH_USER" || true
            sleep 2
            if pgrep -u "$WAZUH_USER" > /dev/null; then
                maybe_sudo pkill -9 -u "$WAZUH_USER" || true
            fi
        fi
    fi
}

# Uninstall Wazuh agent
uninstall_agent() {
    # Check if Wazuh is installed (comprehensive detection for partial installs)
    local wazuh_installed=false
    local cleanup_reason=""
    
    # Check main installation directory
    if maybe_sudo [ -d "$OSSEC_PATH" ]; then
        wazuh_installed=true
        cleanup_reason="Main Wazuh directory found"
    fi
    
    # Check if package is installed via package manager
    if [ "$PACKAGE_MANAGER" = "apt" ] && dpkg -l | grep -q "wazuh-agent"; then
        cleanup_reason="Package found in dpkg database"
    elif [ "$PACKAGE_MANAGER" = "yum" ] && rpm -q wazuh-agent >/dev/null 2>&1; then
        cleanup_reason="Package found in RPM database"
    elif [ "$PACKAGE_MANAGER" = "zypper" ] && zypper search -i wazuh-agent >/dev/null 2>&1; then
        cleanup_reason="Package found in Zypper database"
    fi
    
    if [ "$wazuh_installed" = true ]; then
        info_message "Wazuh components detected: $cleanup_reason"
        info_message "Uninstalling Wazuh agent for Linux ($PACKAGE_MANAGER)..."
        
        if [ "$PACKAGE_MANAGER" = "apt" ]; then
            if ! maybe_sudo apt remove --purge wazuh-agent -y; then
                error_exit "Failed to remove Wazuh agent package"
            fi
            if ! maybe_sudo apt autoremove -y; then
                error_exit "Failed to autoremove Wazuh agent dependencies"
            fi
        elif [ "$PACKAGE_MANAGER" = "yum" ]; then
            if ! maybe_sudo yum remove -y wazuh-agent; then
                error_exit "Failed to remove Wazuh agent package"
            fi
        elif [ "$PACKAGE_MANAGER" = "zypper" ]; then
            if ! maybe_sudo zypper remove -y wazuh-agent; then
                error_exit "Failed to remove Wazuh agent package"
            fi
        fi
        
        info_message "Wazuh agent uninstalled successfully."
    else
        warn_message "Wazuh agent does not exist, skipping"
    fi
}

# Remove repository and GPG key
cleanup_repo() {
    info_message "Removing repository and GPG key"
    if [ -f "$REPO_FILE" ]; then
        if ! maybe_sudo rm -f "$REPO_FILE"; then
            error_error "Failed to remove repository file"
        fi
    fi

    if [ "$PACKAGE_MANAGER" = "apt" ] && [ -f "$GPG_KEY_FILE" ]; then
        if ! maybe_sudo rm -f "$GPG_KEY_FILE"; then
            error_error "Failed to remove GPG key"
        fi
    fi
    info_message "Repository and GPG key removed successfully."
}

# Clean up any remaining Wazuh files
cleanup_files() { 
    info_message "Cleaning up remaining Wazuh files"
    if ! maybe_sudo rm -rf /var/ossec; then
        error_error "Failed to remove Wazuh directory"
    fi
    info_message "Linux cleanup completed."
}

# Remove user and group
remove_user_group() {
    info_message "Removing user and group if they exist"
    
    if id -u "$WAZUH_USER" >/dev/null 2>&1; then
        info_message "Removing user $WAZUH_USER..."
        if ! maybe_sudo userdel "$WAZUH_USER"; then
            warn_message "Failed to remove user $WAZUH_USER. Skipping."
        fi
    fi

    if getent group "$WAZUH_GROUP" >/dev/null 2>&1; then
        info_message "Removing group $WAZUH_GROUP..."
        if ! maybe_sudo groupdel "$WAZUH_GROUP"; then
            warn_message "Failed to remove group $WAZUH_GROUP. Skipping."
        fi
    fi
    
    info_message "User and group cleanup completed."
}

# Verify uninstallation was successful
verify_uninstallation() {
    info_message "Verifying uninstallation..."
    local verification_failed=false
    
    # Check if main directory still exists
    if [ -d "$OSSEC_PATH" ]; then
        error_message "Wazuh directory still exists: $OSSEC_PATH"
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        error_error "Uninstallation verification failed - some components were not removed"
    else
        success_message "Uninstallation verification passed - all components removed successfully"
        return 0
    fi
}

# Main execution
case $(uname) in
    Linux*)
        stop_service
        uninstall_agent
        cleanup_repo
        cleanup_files
        remove_user_group

        # Verify the uninstallation
        if verify_uninstallation; then
            success_message "Wazuh agent uninstallation completed successfully."
            info_message "You can now reinstall Wazuh agent without conflicts."
        else
            error_error "Uninstallation completed with issues. Manual cleanup may be required."
        fi
        ;;
    *)
        error_exit "Unsupported OS"
        ;;
esac

# End of script
