#!/bin/sh

set -eu

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

# Logging helpers
info_message() { log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"; }
warn_message() { log "${YELLOW}${BOLD}[WARNING]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }
print_step() { log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"; }
error_exit() { error_message "$*"; exit 1; }

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

# Find a functional Python 3 binary
get_functional_python() {
    for cmd in python3 python; do
        if command_exists "$cmd"; then
            # Verify it's actually functional (not a broken link or stub)
            if "$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" >/dev/null 2>&1; then
                echo "$cmd"
                return 0
            fi
        fi
    done
    return 1
}

# Calculate SHA256 hash (cross-platform)
calculate_sha256() {
    local file="$1"
    if command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        error_message "No SHA256 tool available (sha256sum or shasum required)"
        return 1
    fi
}

# Verify file checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local actual
    actual=$(calculate_sha256 "$file")

    if [ "$actual" != "$expected" ]; then
        error_message "Checksum verification FAILED for $file!"
        error_message "  Expected: $expected"
        error_message "  Got:      $actual"
        return 1
    fi
    return 0
}

# In-place sed that works on both Linux (GNU) and macOS (BSD)
sed_inplace() {
    if command_exists gsed; then
        maybe_sudo gsed -i "$@"
    elif [ "$(uname)" = "Darwin" ]; then
        maybe_sudo sed -i '' "$@"
    else
        maybe_sudo sed -i "$@"
    fi
}

# Download file with improved error handling
# Usage: download_file <url> <destination>
download_file() {
    local url="$1"
    local dest="$2"
    local max_retries="${3:-3}"
    local retry_count=0
    
    # Validate arguments
    if [ -z "$url" ] || [ -z "$dest" ]; then
        error_message "Usage: download_file <url> <destination> [max_retries]"
        return 1
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" || {
            error_message "Failed to create destination directory: $dest_dir"
            return 1
        }
    fi
    
    # Attempt download with retries
    while [ $retry_count -lt "$max_retries" ]; do
        retry_count=$((retry_count + 1))
        
        if command_exists curl; then
            # Use curl with better error handling and progress
            if curl -fsSL --connect-timeout 30 --max-time 300 "$url" -o "$dest" 2>/dev/null; then
                # Verify we got a non-empty file
                if [ -s "$dest" ]; then
                    return 0
                else
                    warn_message "Downloaded file is empty, retrying... (attempt $retry_count/$max_retries)"
                    rm -f "$dest"
                fi
            fi
        elif command_exists wget; then
            # Use wget as fallback
            if wget -q --timeout=30 --tries=1 "$url" -O "$dest" 2>/dev/null; then
                if [ -s "$dest" ]; then
                    return 0
                else
                    warn_message "Downloaded file is empty, retrying... (attempt $retry_count/$max_retries)"
                    rm -f "$dest"
                fi
            fi
        else
            error_message "Neither curl nor wget is available. Please install one of them."
            return 1
        fi
        
        # Small delay before retry
        sleep 2
    done
    
    error_message "Failed to download $url after $max_retries attempts"
    return 1
}
