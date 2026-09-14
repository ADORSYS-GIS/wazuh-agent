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
OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.14.4-1'}
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.8.1'}
WOPS_VERSION=${WOPS_VERSION:-'0.4.3'}
APP_NAME=${APP_NAME:-'wazuh-cert-oauth2-client'}
WAZUH_SURICATA_VERSION=${WAZUH_SURICATA_VERSION:-'0.1.5'}
WAZUH_YARA_VERSION=${WAZUH_YARA_VERSION:-'0.3.14'}

# Repository references (can be overridden for testing)
if [ "${WAZUH_AGENT_REPO_VERSION}" = "main" ]; then
    WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"main"}
else
    WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}
fi
WAZUH_SURICATA_REPO_REF=${WAZUH_SURICATA_REPO_REF:-"refs/tags/v${WAZUH_SURICATA_VERSION}"}
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
WAZUH_YARA_REPO_REF=${WAZUH_YARA_REPO_REF:-"refs/tags/v${WAZUH_YARA_VERSION}"}
WAZUH_CERT_OAUTH2_REPO_REF=${WAZUH_CERT_OAUTH2_REPO_REF:-"refs/tags/v${WOPS_VERSION}"}

# Repository URLs
WAZUH_AGENT_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF"
WAZUH_SURICATA_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF"
WAZUH_TRIVY_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/$WAZUH_TRIVY_REPO_REF"
WAZUH_YARA_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/$WAZUH_YARA_REPO_REF"
WAZUH_CERT_OAUTH2_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF"

# Installation choice variables (can be set via environment variables or command-line flags)
INSTALL_TRIVY="${INSTALL_TRIVY:-FALSE}"
INSTALL_CERT_OAUTH2="${INSTALL_CERT_OAUTH2:-FALSE}"
INSTALL_SURICATA="${INSTALL_SURICATA:-FALSE}"
INSTALL_YARA="${INSTALL_YARA:-FALSE}"
INSTALL_NETBIRD="${INSTALL_NETBIRD:-FALSE}"
# NetBird setup key for automated enrollment (optional, used when installing NetBird)
NETBIRD_SETUP_KEY=${NETBIRD_SETUP_KEY:-""}

# Parse command line options (overrides environment variables if both are set)
while getopts ":hcsytb" opt; do
  case $opt in
    c) INSTALL_CERT_OAUTH2="TRUE"
    ;;
    h) echo "Usage: $0 [-c] [-s] [-y] [-t] [-b] [-h]"
       echo ""
       echo "Streamlined Wazuh Server installation for Linux"
       echo ""
       echo "Options:"
       echo "  -c    Install cert-oauth2 client (optional)"
       echo "  -s    Install Suricata (optional, IDS mode)"
       echo "  -y    Install Yara (optional, server mode)"
       echo "  -t    Install Trivy (optional)"
       echo "  -b    Install NetBird client (optional, VPN/mesh-network)"
       echo "  -h    Show this help message"
       echo ""
       echo "Environment Variables:"
       echo "  INSTALL_CERT_OAUTH2      Set to 'TRUE' to install cert-oauth2 (default: false)"
       echo "  INSTALL_SURICATA         Set to 'TRUE' to install Suricata (default: false)"
       echo "  INSTALL_YARA             Set to 'TRUE' to install Yara (default: false)"
       echo "  INSTALL_TRIVY            Set to 'TRUE' to install Trivy (default: false)"
       echo "  INSTALL_NETBIRD          Set to 'TRUE' to install NetBird (default: false)"
       echo "  NETBIRD_SETUP_KEY        NetBird setup key for automated enrollment (optional)"
       echo "  WAZUH_MANAGER              Wazuh manager hostname (default: wazuh.example.com)"
       echo "  WAZUH_AGENT_VERSION        Wazuh agent version (default: 4.14.4-1)"
       echo "  WAZUH_AGENT_REPO_VERSION   Repository tag for agent scripts (default: 1.8.1)"
       echo "  WAZUH_AGENT_REPO_REF       Full repository reference (default: refs/tags/v\${WAZUH_AGENT_REPO_VERSION})"
       echo "  WOPS_VERSION               cert-oauth2 client version (default: 0.4.3)"
       echo "  WAZUH_CERT_OAUTH2_REPO_REF cert-oauth2 repository reference (default: refs/tags/v\${WOPS_VERSION})"
       echo "  WAZUH_SURICATA_VERSION     Suricata version (default: 0.1.5)"
       echo "  WAZUH_SURICATA_REPO_REF    Suricata repository reference (default: refs/tags/v\${WAZUH_SURICATA_VERSION})"
       echo "  WAZUH_YARA_VERSION         Yara version (default: 0.3.14)"
       echo "  WAZUH_YARA_REPO_REF        Yara repository reference (default: refs/tags/v\${WAZUH_YARA_VERSION})"
       echo "  WAZUH_TRIVY_REPO_REF       Trivy repository reference (default: main)"
       echo ""
       echo "  Note: You can pass either tags (e.g., '1.8.1') or full repo refs"
       echo "        (e.g., 'refs/tags/v1.8.1' or 'refs/heads/main')"
       echo ""
       echo "Examples:"
       echo "  $0                    # Core installation only"
       echo "  $0 -c                 # With cert-oauth2"
       echo "  $0 -s                 # With Suricata (IDS)"
       echo "  $0 -y                 # With Yara (server)"
       echo "  $0 -t                 # With Trivy"
       echo "  $0 -b                 # With NetBird"
       echo "  $0 -c -s -y -t -b     # With all optional components"
       echo "  WAZUH_MANAGER='my-wazuh.com' $0 -c"
       echo "  INSTALL_CERT_OAUTH2=TRUE INSTALL_SURICATA=TRUE $0"
       echo "  NETBIRD_SETUP_KEY='<key>' $0 -b"
       echo ""
       exit 0
    ;;
    s) INSTALL_SURICATA="TRUE"
    ;;
    t) INSTALL_TRIVY="TRUE"
    ;;
    y) INSTALL_YARA="TRUE"
    ;;
    b) INSTALL_NETBIRD="TRUE"
    ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        echo "Use -h for help"
        exit 1
    ;;
  esac
done

# Check for extra arguments
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  echo "Error: Extra arguments provided: $*"
  echo "Use -h for help"
  exit 1
fi

# Create a secure temporary directory for utilities
TMP_FOLDER=$(mktemp -d)

# Download utils.sh from repository
trap 'rm -rf "$TMP_FOLDER"' EXIT
if ! curl "$WAZUH_AGENT_REPO_URL/scripts/shared/utils.sh" -o "$TMP_FOLDER/utils.sh"; then
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
if ! curl "$WAZUH_AGENT_REPO_URL/checksums.sha256" -o "$TMP_FOLDER/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$TMP_FOLDER/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$TMP_FOLDER/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$TMP_FOLDER/utils.sh"

# ==============================================================================
# Main Installation Logic
# ==============================================================================

info_message "Starting setup. Using temporary directory: \"$TMP_FOLDER\""
info_message "Options: INSTALL_CERT_OAUTH2=$INSTALL_CERT_OAUTH2 INSTALL_SURICATA=$INSTALL_SURICATA INSTALL_TRIVY=$INSTALL_TRIVY INSTALL_YARA=$INSTALL_YARA INSTALL_NETBIRD=$INSTALL_NETBIRD"

# Step -1: Download all core scripts
info_message "Downloading core component scripts..."

# Download and verify deps.sh
download_and_verify_file "$WAZUH_AGENT_REPO_URL/scripts/linux/deps.sh" "$TMP_FOLDER/deps.sh" "scripts/linux/deps.sh" "deps.sh" "$WAZUH_AGENT_REPO_URL/checksums.sha256"

# Download and verify install.sh
download_and_verify_file "$WAZUH_AGENT_REPO_URL/scripts/linux/install.sh" "$TMP_FOLDER/install.sh" "scripts/linux/install.sh" "install.sh" "$WAZUH_AGENT_REPO_URL/checksums.sha256"

# Step 0: Install dependencies
info_message "Installing dependencies"
if ! (maybe_sudo env WAZUH_AGENT_REPO_REF="$WAZUH_AGENT_REPO_REF" bash "$TMP_FOLDER/deps.sh") 2>&1; then
    error_message "Failed to install dependencies"
    exit 1
fi

# Step 1: Download and install Wazuh agent
info_message "Installing Wazuh agent"
if ! (maybe_sudo env OSSEC_CONF_PATH="$OSSEC_CONF_PATH" WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_AGENT_VERSION="$WAZUH_AGENT_VERSION" WAZUH_AGENT_REPO_REF="$WAZUH_AGENT_REPO_REF" bash "$TMP_FOLDER/install.sh") 2>&1; then
    error_message "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Install components if the flag is set

# Install Trivy if the flag is set
if [ "$INSTALL_TRIVY" = "TRUE" ]; then
    info_message "Downloading Trivy installation script..."
    download_and_verify_file "$WAZUH_TRIVY_REPO_URL/scripts/linux/install.sh" "$TMP_FOLDER/install-trivy.sh" "scripts/linux/install.sh" "trivy install script" "$WAZUH_TRIVY_REPO_URL/checksums.sha256"
    if ! (maybe_sudo env WAZUH_TRIVY_REPO_REF="$WAZUH_TRIVY_REPO_REF" bash "$TMP_FOLDER/install-trivy.sh") 2>&1; then
        error_message "Failed to install trivy"
        exit 1
    fi
fi

# Install cert-oauth2 if the flag is set
if [ "$INSTALL_CERT_OAUTH2" = "TRUE" ]; then
    info_message "Downloading cert-oauth2 installation script..."
    download_and_verify_file "$WAZUH_CERT_OAUTH2_REPO_URL/scripts/linux/install.sh" "$TMP_FOLDER/install-cert-oauth2.sh" "scripts/linux/install.sh" "cert-oauth2 install script" "$WAZUH_CERT_OAUTH2_REPO_URL/checksums.sha256"
    if ! (maybe_sudo env OSSEC_CONF_PATH="$OSSEC_CONF_PATH" APP_NAME="$APP_NAME" WOPS_VERSION="$WOPS_VERSION" bash "$TMP_FOLDER/install-cert-oauth2.sh") 2>&1; then
        error_message "Failed to install cert-oauth2"
        exit 1
    fi
fi

# Install Suricata if the flag is set
if [ "$INSTALL_SURICATA" = "TRUE" ]; then
    info_message "Downloading Suricata installation script..."
    download_and_verify_file "$WAZUH_SURICATA_REPO_URL/scripts/linux/install.sh" "$TMP_FOLDER/install-suricata.sh" "scripts/linux/install.sh" "suricata install script" "$WAZUH_SURICATA_REPO_URL/checksums.sha256"
    if ! (maybe_sudo env WAZUH_SURICATA_VERSION="$WAZUH_SURICATA_VERSION" bash "$TMP_FOLDER/install-suricata.sh" --mode ids) 2>&1; then
        error_message "Failed to install Suricata"
        exit 1
    fi
fi

# Install Yara if the flag is set
if [ "$INSTALL_YARA" = "TRUE" ]; then
    info_message "Downloading Yara installation script..."
    download_and_verify_file "$WAZUH_YARA_REPO_URL/scripts/linux/install.sh" "$TMP_FOLDER/install-yara-server.sh" "scripts/linux/install.sh" "yara install script" "$WAZUH_YARA_REPO_URL/checksums.sha256"
    if ! (maybe_sudo env INSTALLATION_TYPE="server" WAZUH_YARA_VERSION="$WAZUH_YARA_VERSION" bash "$TMP_FOLDER/install-yara-server.sh") 2>&1; then
        error_message "Failed to install Yara"
        exit 1
    fi
fi

# Install NetBird client if the flag is set
if [ "$INSTALL_NETBIRD" = "TRUE" ]; then
    info_message "Installing NetBird client..."
    if command_exists netbird; then
        success_message "NetBird client is already installed."
    else
        if ! download_file "https://pkgs.netbird.io/install.sh" "$TMP_FOLDER/netbird-install.sh" "NetBird install script"; then
            error_message "Failed to download NetBird install script"
            exit 1
        fi
        if [ -n "$NETBIRD_SETUP_KEY" ]; then
            info_message "Enrolling NetBird with the provided setup key..."
            if ! (maybe_sudo env USE_BIN_INSTALL=true NETBIRD_SETUP_KEY="$NETBIRD_SETUP_KEY" sh "$TMP_FOLDER/netbird-install.sh") 2>&1; then
                error_message "Failed to install and enroll NetBird client"
                exit 1
            fi
        else
            if ! (maybe_sudo env USE_BIN_INSTALL=true sh "$TMP_FOLDER/netbird-install.sh") 2>&1; then
                error_message "Failed to install NetBird client"
                exit 1
            fi
        fi
        success_message "NetBird client installed successfully."
    fi
fi

# Step 6: Download version file
info_message "Downloading version file..."
download_and_verify_file "$WAZUH_AGENT_REPO_URL/version.txt" "$TMP_FOLDER/version.txt" "version.txt" "version file" "$WAZUH_AGENT_REPO_URL/checksums.sha256"

success_message "Wazuh setup has been completed successfully."
