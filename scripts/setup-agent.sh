#!/bin/sh

set -eu

# Wrapper that downloads and verifies the OS-specific setup script from the
# repository and executes it. Designed to work when the script has been
# downloaded to a temporary location and is executed remotely.

REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
REF="${WAZUH_AGENT_REPO_REF:-main}"

SCRIPT_NAME="setup-agent.sh"

OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Darwin)
        REMOTE_PATH="scripts/macos/${SCRIPT_NAME}"
        ;;
    Linux)
        REMOTE_PATH="scripts/linux/${SCRIPT_NAME}"
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE" >&2
        exit 2
        ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CHECKSUMS_URL="$REPO_URL/$REF/checksums.sha256"
SCRIPT_URL="$REPO_URL/$REF/$REMOTE_PATH"
CHECKSUMS_FILE="$TMP_DIR/checksums.sha256"
SCRIPT_FILE="$TMP_DIR/remote_setup.sh"

download() {
    local url="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    else
        echo "Neither curl nor wget available" >&2
        return 1
    fi
}

calculate_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

echo "Downloading checksums..."
download "$CHECKSUMS_URL" "$CHECKSUMS_FILE"

echo "Downloading script: $REMOTE_PATH"
download "$SCRIPT_URL" "$SCRIPT_FILE"

EXPECTED_HASH=$(awk -v path="$REMOTE_PATH" '$0 ~ path {print $1; exit}' "$CHECKSUMS_FILE" || true)
if [ -z "$EXPECTED_HASH" ]; then
    echo "Warning: expected checksum for $REMOTE_PATH not found; aborting" >&2
    exit 3
fi

ACTUAL_HASH=$(calculate_sha256 "$SCRIPT_FILE")
if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Checksum mismatch for $REMOTE_PATH" >&2
    echo "  Expected: $EXPECTED_HASH" >&2
    echo "  Actual:   $ACTUAL_HASH" >&2
    exit 4
fi

chmod +x "$SCRIPT_FILE"
# Prefer bash for execution (many scripts use bash-specific constructs like [[ ]])
if command -v bash >/dev/null 2>&1; then
    exec bash "$SCRIPT_FILE" "$@"
else
    exec sh "$SCRIPT_FILE" "$@"
fi

