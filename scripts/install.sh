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

# Variables
LOG_LEVEL=${LOG_LEVEL:-INFO}
WAZUH_MANAGER=${WAZUH_MANAGER:-'master.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.8.2-1'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-}

# Check if WAZUH_AGENT_NAME is set; if not, exit with an error
if [ -z "${WAZUH_AGENT_NAME}" ]; then
    error_message "WAZUH_AGENT_NAME is not set. Please set this variable before running the script."
    exit 1
fi

# Detect OS and architecture
OS_NAME=$(uname -s)
ARCH=$(uname -m)

# Package details based on OS and architecture
case "$OS_NAME" in
    Linux)
        if command -v apt &> /dev/null; then
            PACKAGE_MANAGER="apt/pool/main/w/wazuh-agent"
            PACKAGE_FILE="wazuh-agent_${WAZUH_AGENT_VERSION}_$( [ "$ARCH" = "x86_64" ] && echo "amd64" || echo "arm64" ).deb"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
            PACKAGE_FILE="wazuh-agent-${WAZUH_AGENT_VERSION}.$( [ "$ARCH" = "x86_64" ] && echo "x86_64" || echo "aarch64" ).rpm"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
            PACKAGE_FILE="wazuh-agent-${WAZUH_AGENT_VERSION}.$( [ "$ARCH" = "x86_64" ] && echo "x86_64" || echo "aarch64" ).rpm"
        elif command -v zypper &> /dev/null; then
            PACKAGE_MANAGER="zypper"
            PACKAGE_FILE="wazuh-agent-${WAZUH_AGENT_VERSION}.$( [ "$ARCH" = "x86_64" ] && echo "x86_64" || echo "aarch64" ).rpm"
        else
            error_message "Unsupported package manager"
            exit 1
        fi
        PACKAGE_URL="https://packages.wazuh.com/4.x/${PACKAGE_MANAGER}/${PACKAGE_FILE}"
        ;;
    Darwin)
        PACKAGE_MANAGER="installer"
        PACKAGE_FILE="wazuh-agent-${WAZUH_AGENT_VERSION}.$( [ "$ARCH" = "x86_64" ] && echo "intel64" || echo "arm64" ).pkg"
        PACKAGE_URL="https://packages.wazuh.com/4.x/macos/${PACKAGE_FILE}"
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

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

init_wazuh_agent() {
    info_message "Initializing Wazuh agent..."

    if [ "$OS_NAME" = "Linux" ]; then
        if command -v systemctl >/dev/null 2>&1; then
            maybe_sudo systemctl daemon-reload
            maybe_sudo systemctl enable wazuh-agent
            maybe_sudo systemctl start wazuh-agent
        elif command -v service >/dev/null 2>&1; then
            maybe_sudo update-rc.d wazuh-agent defaults 95 10
            maybe_sudo service wazuh-agent start
        else
            maybe_sudo /var/ossec/bin/wazuh-control start
        fi
    elif [ "$OS_NAME" = "Darwin" ]; then
        maybe_sudo /Library/Ossec/bin/wazuh-control start
    else
        error_message "Unsupported operating system."
    fi
}

info_message "Starting Wazuh agent installation..."

# Create a temporary directory and ensure it is cleaned up on exit
TEMP_DIR=$(mktemp -d) || { error_message "Failed to create a temporary directory"; exit 1; }
trap 'rm -rf "$TEMP_DIR"' EXIT

# Download the package to the temporary directory using curl with a progress bar
download_package() {
    info_message "Downloading Wazuh agent from $PACKAGE_URL..."
    HTTP_STATUS=$(curl -w "%{http_code}" -L --progress-bar -o "$TEMP_DIR/$PACKAGE_FILE" "$PACKAGE_URL")
    if [ "$HTTP_STATUS" -ne 200 ]; then
        log ERROR "Failed to download Wazuh agent package. HTTP Status: $HTTP_STATUS. Aborting..."
        exit 1
    fi
    success_message "Wazuh agent downloaded successfully"
}

download_package

# Install the package
info_message "Installing Wazuh agent..."
PACKAGE_PATH="$TEMP_DIR/$PACKAGE_FILE"
case "$PACKAGE_MANAGER" in
    "apt")
        maybe_sudo dpkg -i "$PACKAGE_PATH"
        maybe_sudo apt-get install -f -y
        ;;
    "yum" | "dnf" | "zypper")
        maybe_sudo $PACKAGE_MANAGER install -y "$PACKAGE_PATH"
        ;;
    "installer")
        echo "WAZUH_MANAGER=$WAZUH_MANAGER" > /tmp/wazuh_envs
        echo "WAZUH_AGENT_NAME=$WAZUH_AGENT_NAME" >> /tmp/wazuh_envs
        maybe_sudo installer -pkg "$PACKAGE_PATH" -target /
        ;;
esac

# Check installation status
if [ $? -ne 0 ]; then
    error_message "Failed to install Wazuh agent package. Aborting..."
    exit 1
fi
success_message "Wazuh agent installed successfully"

init_wazuh_agent || true # TODO: Fix this

# The cleanup will be automatically done due to the trap
info_message "Temporary files cleaned up."