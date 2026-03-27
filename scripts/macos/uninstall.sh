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
        error_exit "Failed to download checksums.sha256"
    fi

    # 2. Verify utils.sh integrity
    EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
    ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

    if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        error_exit "Error: Checksum verification failed for utils.sh" >&2
    fi
fi

# Variables
WAZUH_USER=${WAZUH_USER:-'wazuh'}
WAZUH_GROUP=${WAZUH_GROUP:-'wazuh'}
OSSEC_PATH="/Library/Ossec/"
OSSEC_CONTROL_PATH="/Library/Ossec/bin/wazuh-control"

# Stop Wazuh service if running
stop_service() {
    if maybe_sudo [ -x "$OSSEC_CONTROL_PATH" ]; then
        info_message "Stopping Wazuh service..."
        maybe_sudo "$OSSEC_CONTROL_PATH" stop || true
        info_message "Wazuh service stopped successfully"
    else
        warn_message "Wazuh service does not exist, skipping"
    fi
}

uninstall_agent() {
    # Check if Wazuh is installed (comprehensive detection for partial installs)
    local wazuh_installed=false
    local cleanup_reason=""
    
    # Check main installation directory
    if maybe_sudo [ -d "$OSSEC_PATH" ]; then
        wazuh_installed=true
        cleanup_reason="Main Wazuh directory found"
    fi
    
    # macOS specific checks for partial installations
    if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.plist" ]; then
        wazuh_installed=true
        cleanup_reason="Package receipt file found"
    elif [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.bom" ]; then
        wazuh_installed=true
        cleanup_reason="Package BOM file found"
    elif [ -f "/Library/LaunchDaemons/com.wazuh.agent.plist" ]; then
        wazuh_installed=true
        cleanup_reason="LaunchDaemon file found"
    elif [ -d "/Library/StartupItems/WAZUH" ]; then
        wazuh_installed=true
        cleanup_reason="StartupItems directory found"
    fi
    
    if [ "$wazuh_installed" = true ]; then
        info_message "Wazuh components detected: $cleanup_reason"
        info_message "Uninstalling Wazuh agent for macOS..."
        
        maybe_sudo rm -rf /Library/Ossec

        # Remove LaunchDaemon and StartUP items
        maybe_sudo rm -f /Library/LaunchDaemons/com.wazuh.agent.plist
        maybe_sudo rm -rf /Library/StartupItems/WAZUH

        # Remove from the pkgutil first (before removing receipt files)
        maybe_sudo pkgutil --forget com.wazuh.pkg.wazuh-agent 2>/dev/null || warn_message "Package not found in pkgutil database"

        # Remove package receipt file (critical for reinstallation)
        if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.plist" ]; then
            info_message "Removing package receipt file..."
            maybe_sudo rm -f /var/db/receipts/com.wazuh.pkg.wazuh-agent.plist
        fi
        
        # Remove package BOM file if it exists
        if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.bom" ]; then
            info_message "Removing package BOM file..."
            maybe_sudo rm -f /var/db/receipts/com.wazuh.pkg.wazuh-agent.bom
        fi
        
        info_message "Wazuh agent uninstalled successfully."
    else
        warn_message "Wazuh agent does not exist, skipping"
    fi
}


# Remove user and group
remove_user_group() {
    info_message "Removing user and group if they exist"
    
    # macOS commands
    if dscl . -list /Users | grep -q "^$WAZUH_USER$"; then
        info_message "Removing user $WAZUH_USER..."
        maybe_sudo dscl . -delete "/Users/$WAZUH_USER" || warn_message "Failed to remove user $WAZUH_USER. Skipping."
    fi

    if dscl . -list /Groups | grep -q "^$WAZUH_GROUP$"; then
        info_message "Removing group $WAZUH_GROUP..."
        maybe_sudo dscl . -delete "/Groups/$WAZUH_GROUP" || warn_message "Failed to remove group $WAZUH_GROUP. Skipping."
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
    
    # macOS specific checks
    if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.plist" ]; then
        error_message "Package receipt file still exists: /var/db/receipts/com.wazuh.pkg.wazuh-agent.plist"
        verification_failed=true
    fi
    
    if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.bom" ]; then
        error_message "Package BOM file still exists: /var/db/receipts/com.wazuh.pkg.wazuh-agent.bom"
        verification_failed=true
    fi
    
    if [ -f "/Library/LaunchDaemons/com.wazuh.agent.plist" ]; then
        error_message "LaunchDaemon file still exists: /Library/LaunchDaemons/com.wazuh.agent.plist"
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        error_exit "Uninstallation verification failed - some components were not removed"
    else
        success_message "Uninstallation verification passed - all components removed successfully"
        return 0
    fi
}

# Main execution

case $(uname -s) in
    Darwin*)
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
            error_exit "Uninstallation completed with issues. Manual cleanup may be required."
        fi
    ;;
    *)
        error_exit "Unsupported OS"
    ;;
esac

# End of script
