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
WAZUH_USER="${WAZUH_USER:-wazuh}"
VENV_DIR="${VENV_DIR:-/opt/wazuh-docker-env}"

# Detect OS
OS_TYPE="$(uname -s)"

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# ==============================================================================
# Helper Functions
# ==============================================================================
log() {
    LEVEL="$1"
    shift
    MESSAGE="$*"
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

info_message() { log "${BLUE}${BOLD}[============> INFO]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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

# ==============================================================================
# Main
# ==============================================================================

# 1. Exit silently if Docker is not installed
if ! command_exists docker; then
    exit 0
fi

info_message "Docker detected. Setting up Docker listener environment..."

# 2. Ensure Python3 exists
PYTHON_BIN=""
if command_exists python3; then
    PYTHON_BIN="python3"
elif command_exists python; then
    PYTHON_BIN="python"
else
    error_message "Python is not installed. Cannot set up Docker listener."
    exit 0
fi

info_message "Using Python: $PYTHON_BIN"

# 3. Create or repair virtual environment
if [ ! -d "$VENV_DIR" ]; then
    info_message "Creating virtual environment at $VENV_DIR"
    maybe_sudo "$PYTHON_BIN" -m venv "$VENV_DIR"
else
    if [ ! -f "$VENV_DIR/bin/pip" ]; then
        info_message "Existing venv is broken (no pip). Recreating..."
        maybe_sudo rm -rf "$VENV_DIR"
        maybe_sudo "$PYTHON_BIN" -m venv "$VENV_DIR"
    else
        info_message "Virtual environment already exists at $VENV_DIR"
    fi
fi

# 4. Install required Python packages
PIP="$VENV_DIR/bin/pip"
info_message "Upgrading pip..."
maybe_sudo "$PIP" install --upgrade pip >/dev/null 2>&1

info_message "Installing Docker Python library..."
maybe_sudo "$PIP" install --upgrade "docker>=7.0.0" >/dev/null 2>&1

# 5. Update DockerListener shebang
DOCKER_LISTENER="/var/ossec/wodles/docker/DockerListener"
if [ -f "$DOCKER_LISTENER" ]; then
    VENV_PYTHON="$VENV_DIR/bin/python3"
    EXPECTED_SHEBANG="#!${VENV_PYTHON}"
    CURRENT_SHEBANG=$(head -n1 "$DOCKER_LISTENER")

    if [ "$CURRENT_SHEBANG" != "$EXPECTED_SHEBANG" ]; then
        case "$OS_TYPE" in
            Darwin)
                maybe_sudo sed -i '' "1s|.*|${EXPECTED_SHEBANG}|" "$DOCKER_LISTENER"
                ;;
            *)
                maybe_sudo sed -i "1s|.*|${EXPECTED_SHEBANG}|" "$DOCKER_LISTENER"
                ;;
        esac
        info_message "DockerListener shebang updated to use venv Python."
    else
        info_message "DockerListener shebang already correct."
    fi
else
    info_message "DockerListener not found at $DOCKER_LISTENER. Skipping shebang update."
fi

success_message "Wazuh Docker listener environment is ready."
exit 0
