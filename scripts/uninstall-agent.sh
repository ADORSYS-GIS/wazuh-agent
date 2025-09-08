#!/bin/sh

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# ==============================================================================
# Default Configuration
# ==============================================================================
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
WOPS_VERSION=${WOPS_VERSION:-"0.2.18"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.3.11"}
WAZUH_SNORT_VERSION=${WAZUH_SNORT_VERSION:-"0.2.4"}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-"0.1.4"}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-"0.3.3"}

# Uninstall choice variables
UNINSTALL_TRIVY="FALSE"

TMP_FOLDER="$(mktemp -d)"

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# ==============================================================================
# Helper Functions
# ==============================================================================

# Function for logging with timestamp
log() {
    LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }
print_step() { log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"; }

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
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-wazuh-agent.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-wazuh-agent-status.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-yara.sh"

# Always download both NIDS uninstallers
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-suricata.sh"
curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/uninstall.sh > "$TMP_FOLDER/uninstall-snort.sh"

if [ "$UNINSTALL_TRIVY" = "TRUE" ]; then
    curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/uninstall.sh > "$TMP_FOLDER/uninstall-trivy.sh"
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

success_message "Uninstallation completed successfully."
