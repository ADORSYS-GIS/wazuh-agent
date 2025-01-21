#!/bin/sh

# Set shell options

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP [$LEVEL] $MESSAGE"
}

# Logging helpers
info_message() {
    log INFO "$*"
}

error_message() {
    log ERROR "$*"
}

success_message() {
    log INFO "$*"
}

install_gnu_sed() {
    info_message "GNU sed not found. Downloading and installing..."
    SED_URL="https://ftp.gnu.org/gnu/sed/sed-4.9.tar.gz" 
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit
    curl -LO "$SED_URL"
    tar -xzf sed-*.tar.gz
    cd sed-* || exit
    ./configure --prefix=/usr/local
    make
    maybe_sudo make install
    success_message "GNU sed installed successfully."
}

install_jq() {
    info_message "jq not found. Downloading and installing..."
    JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" # Example version, update as needed
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit
    curl -LO "$JQ_URL"
    chmod +x jq-osx-amd64
    maybe_sudo mv jq-osx-amd64 /usr/local/bin/jq
    success_message "jq installed successfully."
}

# Function to download and install curl
install_curl() {
    info_message "curl not found. Downloading and installing..."
    CURL_URL="https://curl.se/download/curl-7.88.1.tar.gz" # Example version, update as needed
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit
    curl -LO "$CURL_URL"
    tar -xzf curl-*.tar.gz
    cd curl-* || exit
    ./configure --prefix=/usr/local
    make
    maybe_sudo make install
    success_message "curl installed successfully."
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

# Function to check if a command is installed
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS and install packages
OS_NAME=$(uname -s)

info_message "Detecting operating system..."

case "$OS_NAME" in
    "Linux")
        if command_exists apt-get; then
            info_message "Detected Debian/Ubuntu-based system"
            maybe_sudo apt-get update
            maybe_sudo apt-get install -y curl jq
        elif command_exists yum; then
            info_message "Detected Red Hat/CentOS-based system"
            maybe_sudo yum install -y curl jq
        elif command_exists apk; then
            info_message "Detected Alpine Linux system"
            maybe_sudo apk add --no-cache curl jq
        else
            error_message "Unsupported Linux distribution"
            exit 1
        fi
        ;;
    "Darwin")
        info_message "Detected macOS"
        if command_exists brew; then
            brew install curl jq gnu-sed
        else
            error_message "brew is missing. Install it and try again."
            exit 1
        fi
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

success_message "curl,jq and gsed installed successfully!"