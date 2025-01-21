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

case "$OS_NAME" in
    Linux)
        commands=("curl" "jq" "sed")
        ;;
    Darwin)
        commands=("curl" "jq" "gsed")
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
    esac

# Check all commands using &&&
if command_exists "${commands[0]}" && command_exists "${commands[1]}" && command_exists "${commands[2]}"; then
    info_message "All required commands: (${commands[*]}) are already installed."
else
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
fi

