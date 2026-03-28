#!/bin/sh

set -eu

# Repository ref
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.9.0-rc.1'}
WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}

# Create a secure temporary directory for utilities
TMP_FOLDER="$(mktemp -d)"
trap 'rm -rf "$TMP_FOLDER"' EXIT

# Try to source local utils.sh first, fallback to downloading
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../shared/utils.sh" ]; then
    . "$SCRIPT_DIR/../shared/utils.sh"
else
    if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/shared/utils.sh" -o "$TMP_FOLDER/utils.sh"; then
        error_message "Failed to download utils.sh"
        exit 1
    fi
    . "$TMP_FOLDER/utils.sh"
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
info_message "Downloading checksums..."
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" "$TMP_FOLDER/checksums.sha256"; then
    error_message "Failed to download checksums.sha256"
    exit 1
fi

# 2. Verify utils.sh integrity (only if we downloaded it)
if [ ! -f "$SCRIPT_DIR/../shared/utils.sh" ]; then
    EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$TMP_FOLDER/checksums.sha256" | awk '{print $1}')
    ACTUAL_HASH=$(calculate_sha256_bootstrap "$TMP_FOLDER/utils.sh")

    if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        echo "Error: Checksum verification failed for utils.sh" >&2
        echo "Expected hash: $EXPECTED_HASH" >&2
        echo "Actual hash: $ACTUAL_HASH" >&2
        exit 1
    fi
fi

# ==============================================================================
# Default Configuration
# ==============================================================================
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
WOPS_VERSION=${WOPS_VERSION:-"0.4.2"}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-"0.3.14"}
WAZUH_SNORT_VERSION=${WAZUH_SNORT_VERSION:-"0.2.4"}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-"0.2.0"}

# macOS-specific OSSEC configuration path
OSSEC_PATH="/Library/Ossec/etc"
OSSEC_CONF_PATH="$OSSEC_PATH/ossec.conf"
AR_BIN_DIR="/Library/Ossec/active-response/bin"

USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.14.2-1'}
WAZUH_AGENT_STATUS_VERSION=${WAZUH_AGENT_STATUS_VERSION:-'0.4.1-rc5-user'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-'test-agent-name'}

# Additional repo ref variables for other components
WAZUH_CERT_OAUTH2_REPO_REF=${WAZUH_CERT_OAUTH2_REPO_REF:-"refs/tags/v$WOPS_VERSION"}
WAZUH_YARA_REPO_REF=${WAZUH_YARA_REPO_REF:-"refs/tags/v$WAZUH_YARA_VERSION"}
WAZUH_SNORT_REPO_REF=${WAZUH_SNORT_REPO_REF:-"refs/tags/v$WAZUH_SNORT_VERSION"}
WAZUH_SURICATA_REPO_REF=${WAZUH_SURICATA_REPO_REF:-"refs/tags/v$WAZUH_SURICATA_VERSION"}
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
WAZUH_AGENT_STATUS_REPO_REF=${WAZUH_AGENT_STATUS_REPO_REF:-"refs/tags/v$WAZUH_AGENT_STATUS_VERSION"}

# Installation choice variables
IDS_ENGINE=""
SURICATA_MODE=""
INSTALL_TRIVY="FALSE"

cleanup() {
    # Remove temporary folder
    if [ -d "$TMP_FOLDER" ]; then
        rm -rf "$TMP_FOLDER"
    fi
}
trap cleanup EXIT

# Help function to display usage
help_message() {
    echo -e "${BOLD}Wazuh Agent Comprehensive Installation Script for macOS${NORMAL}"
    echo ""
    echo -e "${BOLD}DESCRIPTION:${NORMAL}"
    echo "  This script automates the full setup of a Wazuh agent and a suite of essential"
    echo "  security integrations on macOS. It installs core components automatically and lets you"
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
        if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-snort.sh"; then
            error_message "Failed to download uninstall-snort.sh"
            exit 1
        fi
        if ! (bash "$TMP_FOLDER/uninstall-snort.sh") 2>&1; then
            error_message "Failed to uninstall 'snort'"
            exit 1
        fi
    fi
}

uninstall_suricata() {
    if command_exists suricata; then
        info_message "Uninstalling Suricata..."
        if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/scripts/macos/uninstall.sh" "$TMP_FOLDER/uninstall-suricata.sh"; then
            error_message "Failed to download uninstall-suricata.sh"
            exit 1
        fi
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

# Step -1: Download and verify all core scripts
info_message "Downloading and verifying core component scripts..."

for script in "deps.sh" "install.sh" "setup-agent.sh" "setup-docker.sh" "uninstall-agent.sh" "uninstall.sh"; do
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/macos/$script" "$TMP_FOLDER/$script"; then
        error_message "Failed to download core script: $script"
        exit 1
    fi
    
    EXPECTED_SCRIPT_HASH=$(grep "scripts/macos/$script" "$TMP_FOLDER/checksums.sha256" | awk '{print $1}')
    if [ -n "$EXPECTED_SCRIPT_HASH" ]; then
        if ! verify_checksum "$TMP_FOLDER/$script" "$EXPECTED_SCRIPT_HASH"; then
            exit 1
        fi
    else
        warn_message "No checksum found for $script, skipping verification"
    fi
done

# Map filenames for later use
mv "$TMP_FOLDER/deps.sh" "$TMP_FOLDER/install-deps.sh"
mv "$TMP_FOLDER/install.sh" "$TMP_FOLDER/install-wazuh-agent.sh"

if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/${WAZUH_CERT_OAUTH2_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-wazuh-cert-oauth2.sh"; then
    error_message "Failed to download install-wazuh-cert-oauth2.sh"
    exit 1
fi

if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/${WAZUH_AGENT_STATUS_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-wazuh-agent-status.sh"; then
    error_message "Failed to download install-wazuh-agent-status.sh"
    exit 1
fi

if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/${WAZUH_YARA_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-yara.sh"; then
    error_message "Failed to download install-yara.sh"
    exit 1
fi

# Step 0: Install dependencies
info_message "Installing dependencies"
if ! (env WAZUH_AGENT_REPO_REF="$WAZUH_AGENT_REPO_REF" bash "$TMP_FOLDER/install-deps.sh" < /dev/null) 2>&1; then
    error_message "Failed to install dependencies"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (maybe_sudo env OSSEC_CONF_PATH=$OSSEC_CONF_PATH WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" WAZUH_AGENT_REPO_REF="$WAZUH_AGENT_REPO_REF" bash "$TMP_FOLDER/install-wazuh-agent.sh" < /dev/null) 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
info_message "Installing wazuh-cert-oauth2-client"
if ! (maybe_sudo env OSSEC_CONF_PATH=$OSSEC_CONF_PATH APP_NAME="$APP_NAME" WOPS_VERSION="$WOPS_VERSION" bash "$TMP_FOLDER/install-wazuh-cert-oauth2.sh" < /dev/null) 2>&1; then
    error_message "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install wazuh-agent-status
info_message "Installing wazuh-agent-status"
if ! (maybe_sudo env WAZUH_AGENT_STATUS_VERSION="$WAZUH_AGENT_STATUS_VERSION" WAZUH_AGENT_STATUS_REPO_REF="$WAZUH_AGENT_STATUS_REPO_REF" WAZUH_MANAGER="$WAZUH_MANAGER" bash "$TMP_FOLDER/install-wazuh-agent-status.sh" < /dev/null) 2>&1; then
    error_message "Failed to install 'wazuh-agent-status'"
    exit 1
fi

# Step 4: Download and install yara
info_message "Installing yara"
if ! (maybe_sudo env WAZUH_YARA_VERSION="$WAZUH_YARA_VERSION" bash "$TMP_FOLDER/install-yara.sh" < /dev/null) 2>&1; then
    error_message "Failed to install 'yara'"
    exit 1
fi

# Step 5: Install the selected IDS Engine (Snort or Suricata)
info_message "Selected IDS engine: $IDS_ENGINE"
if [ "$IDS_ENGINE" = "suricata" ]; then
    uninstall_snort
    info_message "Installing Suricata in ${BOLD}${SURICATA_MODE}${NORMAL} mode..."
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/${WAZUH_SURICATA_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-suricata.sh"; then
        error_message "Failed to download install-suricata.sh"
        exit 1
    fi
    # Pass the selected mode to the suricata install script
    if ! (maybe_sudo env bash "$TMP_FOLDER/install-suricata.sh" --mode "$SURICATA_MODE" < /dev/null) 2>&1; then
        error_message "Failed to install 'suricata'"
        exit 1
    fi
elif [ "$IDS_ENGINE" = "snort" ]; then
    uninstall_suricata
    info_message "Installing Snort..."
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/${WAZUH_SNORT_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-snort.sh"; then
        error_message "Failed to download install-snort.sh"
        exit 1
    fi
    if ! (env WAZUH_SNORT_REPO_REF="$WAZUH_SNORT_REPO_REF" OSSEC_CONF_PATH="$OSSEC_CONF_PATH" bash "$TMP_FOLDER/install-snort.sh" < /dev/null) 2>&1; then
        error_message "Failed to install 'snort'"
        exit 1
    fi
fi

# Step 6: Install Trivy if the flag is set
if [ "$INSTALL_TRIVY" = "TRUE" ]; then
    info_message "Installing Trivy..."
    if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}/scripts/macos/install.sh" "$TMP_FOLDER/install-trivy.sh"; then
        error_message "Failed to download install-trivy.sh"
        exit 1
    fi
    if ! (env WAZUH_TRIVY_REPO_REF="$WAZUH_TRIVY_REPO_REF" bash "$TMP_FOLDER/install-trivy.sh" < /dev/null) 2>&1; then
        error_message "Failed to install trivy"
        exit 1
    fi
fi

# Step 7: Install USB DLP Active Response scripts
info_message "Installing USB DLP Active Response scripts..."


# Create directory if it doesn't exist
maybe_sudo mkdir -p "$AR_BIN_DIR"

# Download and install USB DLP scripts
USB_DLP_BASE_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF/files/active-response"

# macOS-specific scripts
info_message "Installing macOS USB DLP scripts..."
if ! download_file "$USB_DLP_BASE_URL/disable-usb-storage.sh" "$TMP_FOLDER/disable-usb-storage.sh"; then
    error_message "Failed to download disable-usb-storage.sh"
    exit 1
fi
if ! download_file "$USB_DLP_BASE_URL/alert-usb-hid.sh" "$TMP_FOLDER/alert-usb-hid.sh"; then
    error_message "Failed to download alert-usb-hid.sh"
    exit 1
fi

maybe_sudo cp "$TMP_FOLDER/disable-usb-storage.sh" "$AR_BIN_DIR/"
maybe_sudo cp "$TMP_FOLDER/alert-usb-hid.sh" "$AR_BIN_DIR/"

maybe_sudo chown root:wazuh "$AR_BIN_DIR/disable-usb-storage.sh" "$AR_BIN_DIR/alert-usb-hid.sh"
maybe_sudo chmod 750 "$AR_BIN_DIR/disable-usb-storage.sh" "$AR_BIN_DIR/alert-usb-hid.sh"

success_message "USB DLP Active Response scripts installed successfully."
info_message "Finished USB DLP setup step."

# Step 8: Setup Docker monitoring (only runs if Docker is installed)
info_message "Setting up Docker monitoring (if Docker is present)..."
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/macos/setup-docker.sh" "$TMP_FOLDER/setup-docker.sh"; then
    error_message "Failed to download setup-docker.sh"
else
    if ! (maybe_sudo env WAZUH_AGENT_REPO_REF="$WAZUH_AGENT_REPO_REF" bash "$TMP_FOLDER/setup-docker.sh" < /dev/null) 2>&1; then
        error_message "Failed to setup Docker monitoring"
    else
        info_message "Docker monitoring setup completed successfully."
    fi
fi

# Step 9: Download version file
info_message "Downloading version file..."
if ! download_file "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF/version.txt" "$OSSEC_ROOT/version.txt"; then
    error_message "Failed to download version file"
    exit 1
fi
info_message "Version file downloaded successfully."

success_message "Wazuh setup has been completed successfully."