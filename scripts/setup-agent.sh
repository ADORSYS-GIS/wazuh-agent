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
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
WOPS_VERSION=${WOPS_VERSION:-"0.2.18"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.3.11"}
WAZUH_SNORT_VERSION=${WAZUH_SNORT_VERSION:-"0.2.4"}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-"0.1.4"}

# Define the OSSEC configuration path
if [ "$(uname)" = "Darwin" ]; then
    OSSEC_PATH="/Library/Ossec/etc"
else
    OSSEC_PATH="/var/ossec/etc"
fi
OSSEC_CONF_PATH="$OSSEC_PATH/ossec.conf"

USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.12.0-1'}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-'0.3.3'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-test-agent-name}

# Installation choice variables
IDS_ENGINE=""
SURICATA_MODE=""
INSTALL_TRIVY="FALSE"

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
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }

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
    echo -e "${BOLD}Wazuh Agent Comprehensive Installation Script${NORMAL}"
    echo ""
    echo -e "${BOLD}DESCRIPTION:${NORMAL}"
    echo "  This script automates the full setup of a Wazuh agent and a suite of essential"
    echo "  security integrations. It installs core components automatically and lets you"
    echo "  configure the installation with your choice of optional tools."
    echo ""
    echo -e "  ${BLUE}CORE COMPONENTS (Always Installed):${NORMAL}"
    echo "    - Wazuh Agent: The core agent for monitoring and response."
    echo "    - Wazuh Cert OAuth2: Client for certificate-based authentication."
    echo "    - Wazuh Agent Status: Tool to monitor the agent's health."
    echo "    - Yara Integration: For malware detection using Yara rules."
    echo ""
    echo -e "  ${YELLOW}CONFIGURABLE COMPONENTS (User Choice):${NORMAL}"
    echo "    You must select ONE of the following Network Intrusion Detection Systems (NIDS)"
    echo "    and can optionally include a vulnerability scanner."
    echo ""
    echo -e "${BOLD}USAGE:${NORMAL}"
    echo "  ./setup-agent.sh [-s <mode> | -n] [-t] [-h]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NORMAL}"
    echo -e "  ${YELLOW}-s <mode>${NORMAL}  Install ${BOLD}Suricata${NORMAL}. The <mode> must be 'ids' (detection) or 'ips' (prevention)."
    echo -e "              (Cannot be used with -n)"
    echo -e "  ${YELLOW}-n${NORMAL}         Install ${BOLD}Snort${NORMAL} as the NIDS engine."
    echo -e "              (Cannot be used with -s)"
    echo -e "  ${YELLOW}-t${NORMAL}         Optionally install ${BOLD}Trivy${NORMAL} for vulnerability scanning."
    echo -e "  ${YELLOW}-h${NORMAL}         Display this help message and exit."
    echo ""
    echo -e "${BOLD}EXAMPLES:${NORMAL}"
    echo "  # Install all core components + Suricata (IDS mode) + Trivy:"
    echo "  ./setup-agent.sh -s ids -t"
    echo ""
    echo "  # Install all core components + Snort:"
    echo "  ./setup-agent.sh -n"
}

# ==============================================================================
# Argument Parsing
# ==============================================================================

# Provide a non-interactive default for NIDS selection (default: suricata)
default_nids="suricata"

while getopts "s:nth" opt; do
    case ${opt} in
        s)
            IDS_ENGINE="suricata"
            SURICATA_MODE=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]') # store mode in lowercase
            if [ "$SURICATA_MODE" != "ids" ] && [ "$SURICATA_MODE" != "ips" ]; then
                error_message "Invalid mode for Suricata: '$OPTARG'. Must be 'ids' or 'ips'."
                help_message
                exit 1
            fi
            ;;
        n) IDS_ENGINE="snort" ;;
        t) INSTALL_TRIVY="TRUE" ;;
        h) help_message; exit 0 ;;
        \?) error_message "Invalid option: -$OPTARG" >&2; help_message; exit 1 ;;
        :) error_message "Option -$OPTARG requires an argument." >&2; help_message; exit 1 ;;
    esac
done

# Validate that Snort and Suricata are not chosen together
if [ -n "$SURICATA_MODE" ] && [ "$IDS_ENGINE" = "snort" ]; then
    error_message "Invalid options: You cannot install both Suricata (-s) and Snort (-n)."
    help_message
    exit 1
fi

# If no NIDS selected, use default
if [ -z "$IDS_ENGINE" ]; then
    info_message "No NIDS selected, defaulting to: $default_nids. Use -s <mode> for Suricata or -n for Snort."
    IDS_ENGINE="$default_nids"
fi

# If Suricata is selected but no mode is given, default to 'ids'
if [ "$IDS_ENGINE" = "suricata" ] && [ -z "$SURICATA_MODE" ]; then
    info_message "No mode specified for Suricata, defaulting to 'ids' mode."
    SURICATA_MODE="ids"
fi

# Helper functions to uninstall snort and suricata
uninstall_snort() {
    if command_exists snort; then
        info_message "Uninstalling Snort..."
        curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/uninstall.sh" > "$TMP_FOLDER/uninstall-snort.sh"
        if ! (bash "$TMP_FOLDER/uninstall-snort.sh") 2>&1; then
            error_message "Failed to uninstall 'snort'"
            exit 1
        fi
    fi
}

uninstall_suricata() {
    if command_exists suricata; then
        info_message "Uninstalling Suricata..."
        curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.sh" > "$TMP_FOLDER/uninstall-suricata.sh"
        if ! (bash "$TMP_FOLDER/uninstall-suricata.sh") 2>&1; then
            error_message "Failed to uninstall 'suricata'"
            exit 1
        fi
    fi
}

# ==============================================================================
# Main Installation Logic
# ==============================================================================

info_message "Starting setup. Using temporary directory: \"$TMP_FOLDER\""

# Step -1: Download all core scripts
info_message "Downloading core component scripts..."
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/deps.sh" > "$TMP_FOLDER/install-deps.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-agent.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-cert-oauth2.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-wazuh-agent-status.sh"
curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-yara.sh"

# Step 0: Install dependencies
info_message "Installing dependencies"
if ! (bash "$TMP_FOLDER/install-deps.sh") 2>&1; then
    error_message "Failed to install dependencies"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (maybe_sudo env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" bash "$TMP_FOLDER/install-wazuh-agent.sh") 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
info_message "Installing wazuh-cert-oauth2-client"
if ! (maybe_sudo env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH APP_NAME="$APP_NAME" WOPS_VERSION="$WOPS_VERSION" bash "$TMP_FOLDER/install-wazuh-cert-oauth2.sh") 2>&1; then
    error_message "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install wazuh-agent-status
info_message "Installing wazuh-agent-status"
if ! (maybe_sudo env WAZUH_MANAGER="$WAZUH_MANAGER" bash "$TMP_FOLDER/install-wazuh-agent-status.sh") 2>&1; then
    error_message "Failed to install 'wazuh-agent-status'"
    exit 1
fi

# Step 4: Download and install yara
info_message "Installing yara"
if ! (LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH=$OSSEC_CONF_PATH bash "$TMP_FOLDER/install-yara.sh") 2>&1; then
    error_message "Failed to install 'yara'"
    exit 1
fi

# Step 5: Install the selected IDS Engine (Snort or Suricata)
if [ "$IDS_ENGINE" = "suricata" ]; then
    uninstall_snort
    info_message "Installing Suricata in ${BOLD}${SURICATA_MODE}${NORMAL} mode..."
    curl -sL --progress-bar "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/v$WAZUH_SURICATA_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-suricata.sh"
    # Pass the selected mode to the suricata install script
    if ! (bash "$TMP_FOLDER/install-suricata.sh" --mode "$SURICATA_MODE") 2>&1; then
        error_message "Failed to install 'suricata'"
        exit 1
    fi
elif [ "$IDS_ENGINE" = "snort" ]; then
    uninstall_suricata
    info_message "Installing Snort..."
    curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/install.sh" > "$TMP_FOLDER/install-snort.sh"
    if ! (env LOG_LEVEL="$LOG_LEVEL" OSSEC_CONF_PATH="$OSSEC_CONF_PATH" bash "$TMP_FOLDER/install-snort.sh") 2>&1; then
        error_message "Failed to install 'snort'"
        exit 1
    fi
fi

# Step 6: Install Trivy if the flag is set
if [ "$INSTALL_TRIVY" = "TRUE" ]; then
    info_message "Installing Trivy..."
    curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/install.sh" > "$TMP_FOLDER/install-trivy.sh"
    if ! (bash "$TMP_FOLDER/install-trivy.sh") 2>&1; then
        error_message "Failed to install trivy"
        exit 1
    fi
fi

# Step 7: Download version file
info_message "Downloading version file..."
if ! (maybe_sudo curl -SL -s "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/version.txt" -o "$OSSEC_PATH/version.txt") 2>&1; then
    error_message "Failed to download version file"
    exit 1
fi
info_message "Version file downloaded successfully."

success_message "Wazuh setup has been completed successfully."