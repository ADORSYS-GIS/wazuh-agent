#!/bin/sh

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

info_message() { log INFO "$*"; }
error_message() { log ERROR "$*"; }
success_message() { log SUCCESS "$*"; }

# Function to ensure root privileges
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

# Function to create a temporary directory and clean up
create_tmp_dir() {
    TMP_DIR=$(mktemp -d) || { error_message "Failed to create temp directory"; exit 1; }
    echo "$TMP_DIR"
}

install_gnu_sed() {
    info_message "Installing GNU sed..."
    local TMP_DIR
    TMP_DIR=$(create_tmp_dir)
    cd "$TMP_DIR" || exit 1
    curl -LO "https://ftp.gnu.org/gnu/sed/sed-4.9.tar.gz"
    tar -xzf sed-4.9.tar.gz
    cd sed-* || exit 1
    ./configure --prefix=/usr/local
    make
    maybe_sudo make install
    success_message "GNU sed installed successfully."
}

install_jq() {
    info_message "Installing jq..."
    local TMP_DIR
    TMP_DIR=$(create_tmp_dir)
    cd "$TMP_DIR" || exit 1
    curl -LO "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64"
    chmod +x jq-osx-amd64
    maybe_sudo mv jq-osx-amd64 /usr/local/bin/jq
    success_message "jq installed successfully."
}

install_curl() {
    info_message "Installing curl..."
    local TMP_DIR
    TMP_DIR=$(create_tmp_dir)
    cd "$TMP_DIR" || exit 1
    curl -LO "https://curl.se/download/curl-7.88.1.tar.gz"
    tar -xzf curl-7.88.1.tar.gz
    cd curl-* || exit 1
    ./configure --prefix=/usr/local
    make
    maybe_sudo make install
    success_message "curl installed successfully."
}

# Detect OS and install required packages
OS_NAME=$(uname -s)
ARCH=$(uname -m)
info_message "Detecting operating system..."

case "$OS_NAME" in
    Linux)
        if command_exists apt-get; then
            info_message "Detected Debian/Ubuntu-based system"
            maybe_sudo apt-get update && maybe_sudo apt-get install -y curl jq
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
    Darwin)
        info_message "Detected macOS"
        if command_exists brew; then
            brew install curl jq gnu-sed
        else
            commands=(curl jq gsed)
            install_functions=(install_curl install_jq install_gnu_sed)
            for i in "${!commands[@]}"; do
                cmd="${commands[$i]}"
                install_func="${install_functions[$i]}"
                if command_exists "$cmd"; then
                    success_message "$cmd is already installed."
                else
                    info_message "$cmd is missing. Installing now..."
                    "$install_func"
                fi
            done
        fi
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

success_message "Installation process completed successfully."
