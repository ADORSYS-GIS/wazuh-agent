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
NC='\033[0m' # No Color

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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
        log_error "No SHA256 tool available (sha256sum or shasum required)"
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
        log_error "Checksum verification FAILED!"
        log_error "  Expected: $expected"
        log_error "  Got:      $actual"
        log_error ""
        log_error "The downloaded file may have been tampered with."
        log_error "Please report this to the security team immediately."
        return 1
    fi

    log_success "Checksum verified successfully"
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
        log_error "Neither curl nor wget is available"
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
    log_info "Wazuh Agent Bootstrap Installer"
    log_info "================================"
    echo ""

    # Check for WAZUH_MANAGER
    if [ -z "$WAZUH_MANAGER" ] || [ "$WAZUH_MANAGER" = "wazuh.example.com" ]; then
        log_warning "WAZUH_MANAGER is not set or using default placeholder"
        log_warning "Please set WAZUH_MANAGER environment variable:"
        log_warning "  export WAZUH_MANAGER=\"your-wazuh-manager.com\""
        echo ""
    fi

    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    log_info "Using temporary directory: $TMP_DIR"

    # Determine URLs
    local script_url="${REPO_URL}/${VERSION}/scripts/${SCRIPT_NAME}"
    local checksums_url="${REPO_URL}/${VERSION}/checksums.sha256"

    # Download checksums file
    log_info "Downloading checksums..."
    if ! download_file "$checksums_url" "$TMP_DIR/$CHECKSUMS_FILE"; then
        log_warning "Could not download checksums file"
        if [ "$SKIP_VERIFY" != "true" ]; then
            log_error "Verification required. Set SKIP_VERIFY=true to bypass (not recommended)"
            exit 1
        fi
    fi

    # Download setup script
    log_info "Downloading ${SCRIPT_NAME}..."
    if ! download_file "$script_url" "$TMP_DIR/$SCRIPT_NAME"; then
        log_error "Failed to download ${SCRIPT_NAME}"
        exit 1
    fi

    # Verify checksum
    if [ -f "$TMP_DIR/$CHECKSUMS_FILE" ] && [ "$SKIP_VERIFY" != "true" ]; then
        log_info "Verifying script integrity..."

        # Extract expected checksum for setup-agent.sh
        local expected_hash
        expected_hash=$(grep "scripts/${SCRIPT_NAME}" "$TMP_DIR/$CHECKSUMS_FILE" | awk '{print $1}')

        if [ -z "$expected_hash" ]; then
            log_warning "No checksum found for ${SCRIPT_NAME} in checksums file"
            log_warning "Proceeding without verification..."
        else
            if ! verify_checksum "$TMP_DIR/$SCRIPT_NAME" "$expected_hash"; then
                log_error "Aborting installation due to checksum mismatch"
                exit 1
            fi
        fi
    elif [ "$SKIP_VERIFY" = "true" ]; then
        log_warning "Skipping verification (SKIP_VERIFY=true)"
    fi

    # Make executable
    chmod +x "$TMP_DIR/$SCRIPT_NAME"

    # Execute with any passed arguments
    log_info "Executing ${SCRIPT_NAME}..."
    echo ""
    echo "=============================================="
    echo ""

    # Run the script with sudo if not root
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo -E bash "$TMP_DIR/$SCRIPT_NAME" "$@"
        else
            log_error "This script requires root privileges. Please run with sudo."
            exit 1
        fi
    else
        bash "$TMP_DIR/$SCRIPT_NAME" "$@"
    fi
}

main "$@"
