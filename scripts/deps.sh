#!/bin/sh

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Source shared utilities
: "${WAZUH_AGENT_REPO_REF:=main}"
if ! curl -sSLf "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/utils.sh" -o utils.sh; then
    echo "Error: Failed to download utils.sh" >&2
    exit 1
fi
. ./utils.sh

LOGGED_IN_USER=""

if [ "$(uname -s)" = "Darwin" ]; then
    LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')
fi

#Get the logged-in user on macOS
brew_command() {
    sudo -u "$LOGGED_IN_USER" -i brew "$@"
}

# Detect OS and install packages
OS_NAME=$(uname -s)
case "$OS_NAME" in
    "Linux")
        if command_exists apt-get; then
            info_message "Detected Debian/Ubuntu-based system"
            maybe_sudo apt-get update
            maybe_sudo apt-get install -y curl jq python3-venv python3-pip
        elif command_exists yum; then
            info_message "Detected Red Hat/CentOS-based system"
            maybe_sudo yum install -y curl jq python3-pip
        elif command_exists apk; then
            info_message "Detected Alpine Linux system"
            maybe_sudo apk add --no-cache curl jq python3 py3-pip
        else
            error_message "Unsupported Linux distribution"
            exit 1
        fi
        ;;
    "Darwin")
        info_message "Detected macOS"
        brew_command install jq gsed bash python3
        ;;
    *)
        error_message "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

success_message "Dependencies installed successfully!"