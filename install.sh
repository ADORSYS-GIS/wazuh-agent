#!/bin/bash
#
# Wazuh Agent Bootstrap Installer
#
# This script downloads, verifies, and executes the Wazuh Agent setup script.
# It ensures integrity of the downloaded script using SHA256 checksum verification.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
#
#   Or with options:
#   curl -sL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ids
#
# Environment Variables:
#   WAZUH_MANAGER       - Wazuh Manager address (required)
#   WAZUH_AGENT_VERSION - Agent version (default: 4.13.1-1)
#   SKIP_VERIFY         - Set to "true" to skip checksum verification (not recommended)
#

set -e

# =============================================================================
# Configuration
# =============================================================================
REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
VERSION="${WAZUH_AGENT_REPO_VERSION:-main}"
SCRIPT_NAME="setup-agent.sh"
CHECKSUMS_FILE="checksums.sha256"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# =============================================================================
# Functions
# =============================================================================

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[INFO]${NC}" "$*"; }
warn_message() { log "${YELLOW}${BOLD}[WARNING]${NC}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NC}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NC}" "$*"; }

# Detect OS type
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Calculate SHA256 hash
calculate_hash() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        error_message "No SHA256 tool available (sha256sum or shasum required)"
        return 1
    fi
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected="$2"

    local actual
    actual=$(calculate_hash "$file")

    if [ "$actual" != "$expected" ]; then
        error_message "Checksum verification FAILED!"
        error_message "  Expected: $expected"
        error_message "  Got:      $actual"
        error_message ""
        error_message "The downloaded file may have been tampered with."
        error_message "Please report this to the security team immediately."
        return 1
    fi

    success_message "Checksum verified successfully"
    return 0
}

# Download file
download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    else
        error_message "Neither curl nor wget is available"
        return 1
    fi
}

# Cleanup on exit
cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

# =============================================================================
# Main
# =============================================================================

main() {
    info_message "Wazuh Agent Bootstrap Installer"
    info_message "================================"
    echo ""

    # Check for WAZUH_MANAGER
    if [ -z "$WAZUH_MANAGER" ] || [ "$WAZUH_MANAGER" = "wazuh.example.com" ]; then
        warn_message "WAZUH_MANAGER is not set or using default placeholder"
        warn_message "Please set WAZUH_MANAGER environment variable:"
        warn_message "  export WAZUH_MANAGER=\"your-wazuh-manager.com\""
        echo ""
    fi

    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    info_message "Using temporary directory: $TMP_DIR"

    # Determine URLs
    local script_url="${REPO_URL}/${VERSION}/scripts/${SCRIPT_NAME}"
    local checksums_url="${REPO_URL}/${VERSION}/checksums.sha256"

    # Download checksums file
    info_message "Downloading checksums..."
    if ! download_file "$checksums_url" "$TMP_DIR/$CHECKSUMS_FILE"; then
        warn_message "Could not download checksums file"
        if [ "$SKIP_VERIFY" != "true" ]; then
            error_message "Verification required. Set SKIP_VERIFY=true to bypass (not recommended)"
            exit 1
        fi
    fi

    # Download setup script
    info_message "Downloading ${SCRIPT_NAME}..."
    if ! download_file "$script_url" "$TMP_DIR/$SCRIPT_NAME"; then
        error_message "Failed to download ${SCRIPT_NAME}"
        exit 1
    fi

    # Download utils.sh
    info_message "Downloading utils.sh..."
    if ! download_file "${REPO_URL}/${VERSION}/scripts/utils.sh" "$TMP_DIR/utils.sh"; then
        warn_message "Could not download utils.sh. Scripts might fail if not run from a full repository check-out."
    fi

    # Verify checksum
    if [ -f "$TMP_DIR/$CHECKSUMS_FILE" ] && [ "$SKIP_VERIFY" != "true" ]; then
        info_message "Verifying script integrity..."

        # Extract expected checksum for setup-agent.sh
        local expected_hash
        expected_hash=$(grep "scripts/${SCRIPT_NAME}" "$TMP_DIR/$CHECKSUMS_FILE" | awk '{print $1}')

        if [ -z "$expected_hash" ]; then
            warn_message "No checksum found for ${SCRIPT_NAME} in checksums file"
            warn_message "Proceeding without verification..."
        else
            if ! verify_checksum "$TMP_DIR/$SCRIPT_NAME" "$expected_hash"; then
                error_message "Aborting installation due to checksum mismatch"
                exit 1
            fi
        fi
    elif [ "$SKIP_VERIFY" = "true" ]; then
        warn_message "Skipping verification (SKIP_VERIFY=true)"
    fi

    # Make executable
    chmod +x "$TMP_DIR/$SCRIPT_NAME"

    # Execute with any passed arguments
    info_message "Executing ${SCRIPT_NAME}..."
    echo ""
    echo "=============================================="
    echo ""

    # Run the script with sudo if not root
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo -E bash "$TMP_DIR/$SCRIPT_NAME" "$@"
        else
            error_message "This script requires root privileges. Please run with sudo."
            exit 1
        fi
    else
        bash "$TMP_DIR/$SCRIPT_NAME" "$@"
    fi
}

main "$@"
