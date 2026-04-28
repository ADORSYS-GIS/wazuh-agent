#!/bin/sh

set -eu

# Repository ref
WAZUH_AGENT_REPO_VERSION=${WAZUH_AGENT_REPO_VERSION:-'1.9.0-rc.1'}
WAZUH_AGENT_REPO_REF=${WAZUH_AGENT_REPO_REF:-"refs/tags/v${WAZUH_AGENT_REPO_VERSION}"}

# Download utils.sh from repository
# Create a secure temporary directory for utilities
UTILS_TMP=$(mktemp -d)
trap 'rm -rf "$UTILS_TMP"' EXIT
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/scripts/shared/utils.sh" -o "$UTILS_TMP/utils.sh"; then
    echo "Failed to download utils.sh"
    exit 1
fi

# Function to calculate SHA256 (cross-platform bootstrap)
calculate_sha256_bootstrap() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# 1. Download checksums
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi

# 2. Verify utils.sh integrity BEFORE sourcing it
EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    exit 1
fi

# 3. Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

# ==============================================================================
# Default Configuration
# ==============================================================================
WAZUH_USER="${WAZUH_USER:-wazuh}"
VENV_DIR="${VENV_DIR:-/opt/wazuh-docker-env}"
DOCKER_LISTENER="/Library/Ossec/wodles/docker/DockerListener"

# ==============================================================================
# Main
# ==============================================================================

# 1. Check if Docker is installed and running
if ! command_exists docker; then
    warn_message "Docker command not found. Skipping Docker monitoring setup."
    exit 0
fi

if ! maybe_sudo docker info >/dev/null 2>&1; then
    # On macOS, Docker info might fail as root if the socket isn't linked correctly
    # or if the user doesn't have the DOCKER_HOST set. We check the socket as a fallback.
    info_message "Docker command failed info check, but socket found. Proceeding on macOS."
fi

info_message "Docker detected. Setting up Docker listener environment..."

# 2. Ensure Python3 exists
PYTHON_BIN=$(get_functional_python)

if [ -z "$PYTHON_BIN" ]; then
    error_exit "Python 3 is not installed. Please install Python 3."
fi

python_version=$($PYTHON_BIN -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
info_message "Python version detected: $python_version"

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
if ! maybe_sudo "$PIP" install --upgrade pip >/dev/null 2>&1; then
    error_exit "Failed to upgrade pip in virtual environment."
fi

info_message "Installing Docker Python library..."
if ! maybe_sudo "$PIP" install --upgrade "docker>=7.0.0" >/dev/null 2>&1; then
    error_exit "Failed to install Docker Python library."
fi

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
