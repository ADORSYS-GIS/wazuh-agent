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

# ==============================================================================
# Default Configuration
# ==============================================================================
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
WOPS_VERSION=${WOPS_VERSION:-"0.4.1"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.3.11"}
WAZUH_SNORT_VERSION=${WAZUH_SNORT_VERSION:-"0.2.4"}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-"0.2.0"}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-"0.4.1-rc5-user"}
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.9.0-rc.1'}

# Repo ref variables for components
WAZUH_CERT_OAUTH2_REPO_REF=${WAZUH_CERT_OAUTH2_REPO_REF:-"refs/tags/v$WOPS_VERSION"}
WAZUH_YARA_REPO_REF=${WAZUH_YARA_REPO_REF:-"refs/tags/v$WAZUH_YARA_VERSION"}
WAZUH_SNORT_REPO_REF=${WAZUH_SNORT_REPO_REF:-"refs/tags/v$WAZUH_SNORT_VERSION"}
WAZUH_SURICATA_REPO_REF=${WAZUH_SURICATA_REPO_REF:-"refs/tags/v$WAZUH_SURICATA_VERSION"}
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
WAZUH_AGENT_STATUS_REPO_REF=${WAZUH_AGENT_STATUS_REPO_REF:-"refs/tags/v$WAZUH_AGENT_STATUS_VERSION"}

# Uninstall choice variables
UNINSTALL_TRIVY="FALSE"

TMP_FOLDER="$(mktemp -d)"

# ==============================================================================
# Helper Functions
# ==============================================================================

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}
trap cleanup EXIT

# Help function to display usage
help_message() {
    printf "%b\n" "${BOLD}Wazuh Agent Comprehensive Uninstallation Script${NORMAL}"
    printf "\n"
    printf "%b\n" "${BOLD}DESCRIPTION:${NORMAL}"
    printf "%s\n" "  This script automates the full removal of a Wazuh agent and its integrations."
    printf "%s\n" "  It uninstalls core components automatically and will also uninstall Snort and Suricata NIDS engines if they are installed."
    printf "\n"
    printf "%b\n" "  ${BLUE}CORE COMPONENTS (Always Uninstalled):${NORMAL}"
    printf "%s\n" "    - Wazuh Agent"
    printf "%s\n" "    - Wazuh Agent Status"
    printf "%s\n" "    - Yara Integration"
    printf "%s\n" "    - Snort (if installed)"
    printf "%s\n" "    - Suricata (if installed)"
    printf "\n"
    printf "%b\n" "  ${YELLOW}CONFIGURABLE COMPONENTS (User Choice):${NORMAL}"
    printf "%s\n" "    You can optionally include a vulnerability scanner."
    printf "\n"
    printf "%b\n" "${BOLD}USAGE:${NORMAL}"
    printf "%s\n" "  ./uninstall-agent.sh [-t] [-h]"
    printf "\n"
    printf "%b\n" "${BOLD}OPTIONS:${NORMAL}"
    printf "%b\n" "  ${YELLOW}-t${NORMAL}         Optionally uninstall ${BOLD}Trivy${NORMAL}."
    printf "%b\n" "  ${YELLOW}-h${NORMAL}         Display this help message and exit."
    printf "\n"
    printf "%b\n" "${BOLD}EXAMPLES:${NORMAL}"
    printf "%s\n" "  # Uninstall all core components + Trivy:"
    printf "%s\n" "  ./uninstall-agent.sh -t"
    printf "\n"
}

# Only -t and -h options remain
while getopts "th" opt; do
    case ${opt} in
        t) UNINSTALL_TRIVY="TRUE" ;;
        h) help_message; exit 0 ;;
        \?) error_message "Invalid option: -$OPTARG" >&2; help_message; exit 1 ;;
    esac
done

# ==============================================================================
# Main Uninstallation Logic
# ==============================================================================

info_message "Starting uninstallation. Using temporary directory: \"$TMP_FOLDER\""

# Step 0: Download all uninstall scripts
info_message "Downloading all uninstall scripts..."
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-wazuh-agent.sh"; then
    error_message "Failed to download uninstall-wazuh-agent.sh"
    exit 1
fi
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/${WAZUH_AGENT_STATUS_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-wazuh-agent-status.sh"; then
    error_message "Failed to download uninstall-wazuh-agent-status.sh"
    exit 1
fi
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/${WAZUH_YARA_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-yara.sh"; then
    error_message "Failed to download uninstall-yara.sh"
    exit 1
fi

# Always download both NIDS uninstallers
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-suricata.sh"; then
    error_message "Failed to download uninstall-suricata.sh"
    exit 1
fi
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-snort.sh"; then
    error_message "Failed to download uninstall-snort.sh"
    exit 1
fi

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-trivy.sh"; then
        error_message "Failed to download uninstall-trivy.sh"
        exit 1
    fi
fi

# Step 1: Uninstall Wazuh agent
print_step 1 "Uninstalling Wazuh agent..."
if ! (maybe_sudo bash "$TMP_FOLDER/uninstall-wazuh-agent.sh") 2>&1; then
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

# Step 4: Uninstall IDS engines if present
if command_exists suricata; then
    print_step 4 "Uninstalling suricata..."
    if ! (bash "$TMP_FOLDER/uninstall-suricata.sh") 2>&1; then
        error_message "Failed to uninstall 'suricata'"
        exit 1
    fi
fi

if command_exists snort; then
    print_step 4 "Uninstalling snort..."
    if ! (bash "$TMP_FOLDER/uninstall-snort.sh") 2>&1; then
        error_message "Failed to uninstall 'snort'"
        exit 1
    fi
fi

# Step 5: Uninstall Trivy if the flag is set
if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    print_step 5 "Uninstalling trivy..."
    if ! (bash "$TMP_FOLDER/uninstall-trivy.sh") 2>&1; then
        error_message "Failed to uninstall 'trivy'"
        exit 1
    fi
fi

# Step 6: Remove Docker listener virtual environment
VENV_DIR="${VENV_DIR:-/opt/wazuh-docker-env}"
if [ -d "$VENV_DIR" ]; then
    print_step 6 "Removing Docker listener virtual environment..."
    maybe_sudo rm -rf "$VENV_DIR"
    info_message "Docker listener virtual environment removed."
else
    info_message "No Docker listener virtual environment found. Skipping."
fi

success_message "Uninstallation completed successfully."
