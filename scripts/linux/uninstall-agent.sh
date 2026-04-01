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

# Download checksums and verify utils.sh integrity BEFORE sourcing it
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

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
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-wazuh-agent.sh" "scripts/linux/uninstall.sh" "Wazuh agent uninstall script" "$UTILS_TMP/checksums.sha256"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/${WAZUH_AGENT_STATUS_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-wazuh-agent-status.sh" "scripts/linux/uninstall.sh" "Wazuh Agent Status uninstall script"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/${WAZUH_YARA_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-yara.sh" "scripts/linux/uninstall.sh" "Yara uninstall script"

# Always download both NIDS uninstallers
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-suricata.sh" "scripts/linux/uninstall.sh" "Suricata uninstall script"
download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-snort.sh" "scripts/linux/uninstall.sh" "Snort uninstall script"

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    download_and_verify_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}/scripts/linux/uninstall.sh" "$TMP_FOLDER/uninstall-trivy.sh" "scripts/linux/uninstall.sh" "Trivy uninstall script"
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
