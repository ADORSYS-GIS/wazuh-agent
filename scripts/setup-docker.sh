#!/bin/sh

# Source shared utilities
# Source shared utilities
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ ! -f "$UTILS_PATH" ]; then
    # Fallback: Download utils.sh if not found locally
    curl -sSL "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/utils.sh" -o "$UTILS_PATH" || \
    wget -q "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/utils.sh" -O "$UTILS_PATH"
fi

if [ -f "$UTILS_PATH" ]; then
    # shellcheck source=scripts/utils.sh
    . "$UTILS_PATH"
else
    echo "[ERROR] Could not find or download utils.sh"
    exit 1
fi

# ==============================================================================
# Default Configuration
# ==============================================================================
WAZUH_USER="${WAZUH_USER:-wazuh}"
VENV_DIR="${VENV_DIR:-/opt/wazuh-docker-env}"

# Detect OS
OS_TYPE="$(uname -s)"

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
        sed_inplace "1s|.*|${EXPECTED_SHEBANG}|" "$DOCKER_LISTENER"
        info_message "DockerListener shebang updated to use venv Python."
    else
        info_message "DockerListener shebang already correct."
    fi
else
    info_message "DockerListener not found at $DOCKER_LISTENER. Skipping shebang update."
fi

success_message "Wazuh Docker listener environment is ready."
exit 0
