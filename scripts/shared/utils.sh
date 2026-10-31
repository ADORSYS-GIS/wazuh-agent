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
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} ${level} ${message}"
}

# Logging helpers
info_message() { log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"; }
warn_message() { log "${YELLOW}${BOLD}[WARNING]${NORMAL}" "$*"; }
error_message() { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }
error_exit() { error_message "$*"; exit 1; }
print_step() {
    local step_number=$1
    local step_message=$2
    log "${BLUE}${BOLD}[STEP]${NORMAL}" "$step_number: $step_message"
    return 0
}

# Check if a command exists
command_exists() {
    local command_name=$1
    if [ -z "$command_name" ]; then
        error_message "No command name provided"
        return 1
    fi
    command -v "$command_name" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            sudo "$@"
        else
            error_exit "This script requires root privileges. Please run with sudo or as root."
        fi
    else
        "$@"
    fi
}

# Find a functional Python 3 binary
get_functional_python() {
    for cmd in python3 python; do
        # Verify it's actually functional (not a broken link or stub)
        if command_exists "$cmd" && "$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" >/dev/null 2>&1; then
            echo "$cmd"
            return 0
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
    local description="${3:-file}"
    local max_retries="${4:-3}"
    local retry_count=0

    info_message "Downloading $description..."

    if [ -z "$url" ] || [ -z "$dest" ]; then
        error_exit "Usage: download_file <url> <destination> [description] [max_retries]"
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        maybe_sudo mkdir -p "$dest_dir" || {
            error_exit "Failed to create destination directory: $dest_dir"
        }
    fi

    while [ "$retry_count" -lt "$max_retries" ]; do
        local use_sudo="false"
        if [ -f "$dest" ]; then
            [ ! -w "$dest" ] && use_sudo="true"
        else
            [ ! -w "$(dirname "$dest")" ] && use_sudo="true"
        fi

        if command_exists curl; then
            if [ "$use_sudo" = "false" ]; then
                if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 "$url" -o "$dest"; then
                    success_message "$description downloaded successfully"
                    return 0
                fi
            else
                if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 "$url" | maybe_sudo tee "$dest" > /dev/null; then
                    success_message "$description downloaded successfully"
                    return 0
                fi
            fi
        elif command_exists wget; then
            if [ "$use_sudo" = "false" ]; then
                if wget -q --tries=3 --wait=2 -O "$dest" "$url"; then
                    success_message "$description downloaded successfully"
                    return 0
                fi
            else
                if wget -q --tries=3 --wait=2 -O - "$url" | maybe_sudo tee "$dest" > /dev/null; then
                    success_message "$description downloaded successfully"
                    return 0
                fi
            fi
        else
            error_message "Neither curl nor wget is available"
            return 1
        fi
        retry_count=$((retry_count + 1))
        warn_message "Download failed, retrying (${retry_count}/${max_retries})..."
        sleep 2
    done

    error_message "Failed to download $description from $url after ${max_retries} attempts"
    return 1
}

# Download a file and verify its checksum against a checksums file.
# The checksums file (e.g. checksums.sha256) must follow the format:
#   <sha256hash>  <filename>
# where each line is: hash, two spaces (or a tab), then the filename.
# Example:
#   d41d8cd98f00b204e9800998ecf8427e  setup-agent.sh
download_and_verify_file() {
    local url="$1"
    local dest="$2"
    local pattern="$3"
    local name="${4:-Unknown file}"
    # Expected checksum file format: "sha256  filename" or "sha256 filename"
    local checksum_url="${5:-${CHECKSUMS_URL:-}}"
    local checksum_file="${6:-${CHECKSUMS_FILE:-}}"

    if ! download_file "$url" "$dest" "$name"; then
        error_exit "Failed to download $name from $url"
    fi

    if [ -n "$checksum_url" ]; then
        local temp_checksum_file
        temp_checksum_file=$(mktemp)
        if ! download_file "$checksum_url" "$temp_checksum_file" "checksum file for $name"; then
            error_exit "Failed to download external checksum file from $checksum_url"
        fi
        checksum_file="$temp_checksum_file"
    fi

    if [ -f "$checksum_file" ]; then
        local expected
        expected=$(grep -E "[[:space:]]${pattern}$" "$checksum_file" | awk '{print $1}')

        if [ -n "$expected" ]; then
            if ! verify_checksum "$dest" "$expected"; then
                error_exit "$name checksum verification failed"
            fi
            info_message "$name checksum verification passed."
        else
            error_exit "No checksum found for $name in $checksum_file using pattern $pattern"
        fi

        # Cleanup temporary checksum file if it was downloaded from a URL
        if [ -n "$checksum_url" ] && [ -f "$checksum_file" ]; then
            rm -f "$checksum_file"
        fi
    else
        error_exit "Checksum file not found at $checksum_file, cannot verify $name"
    fi

    success_message "$name downloaded and verified successfully."
    return 0
}


# Set the agent group(s) requested at enrollment.
# Agents in an OS group (macos/linux/windows) receive that group's shared
# agent.conf and SCA policies from the manager (see the wazuh-helm chart,
# charts/wazuh/files/configs/agents/). Only applies when the agent enrolls;
# agents that are already registered keep their current groups.
# The <enrollment> block is created with an <agent_name> line because the
# wazuh-cert-oauth2 installer (run afterwards) anchors its certificate paths on it.
# Usage: configure_enrollment_group <ossec_conf_path> <groups>
configure_enrollment_group() {
    conf="$1"
    groups="$2"

    [ -n "$groups" ] || return 0

    if maybe_sudo grep -q "<groups>$groups</groups>" "$conf"; then
        info_message "Enrollment group already set to '$groups' in $conf"
        return 0
    fi

    has_enrollment=no
    maybe_sudo grep -q "<enrollment>" "$conf" && has_enrollment=yes

    tmp_conf=$(mktemp)
    maybe_sudo cat "$conf" | awk -v g="$groups" -v has="$has_enrollment" '
        # Existing <enrollment>: drop any previous <groups>, add ours first.
        /<enrollment>/ { in_e = 1; print; print "      <groups>" g "</groups>"; next }
        /<\/enrollment>/ { in_e = 0 }
        in_e && /<groups>/ { next }
        { print }
        # No <enrollment> yet: add one right after the first </server>.
        has == "no" && !added && /<\/server>/ {
            print "    <enrollment>"
            print "      <agent_name></agent_name>"
            print "      <groups>" g "</groups>"
            print "    </enrollment>"
            added = 1
        }
    ' > "$tmp_conf" || {
        rm -f "$tmp_conf"
        error_exit "Failed to set enrollment group in $conf"
    }

    if ! grep -q "<groups>$groups</groups>" "$tmp_conf"; then
        rm -f "$tmp_conf"
        error_exit "Could not place <groups> in $conf (no <enrollment> or </server> found)"
    fi

    # cp (not mv) keeps the original file's owner and permissions.
    maybe_sudo cp "$tmp_conf" "$conf" || {
        rm -f "$tmp_conf"
        error_exit "Failed to write $conf"
    }
    rm -f "$tmp_conf"
    info_message "Enrollment group set to '$groups' in $conf"
}

# Allow command rules in SCA policies received from the manager.
# The manager ships company SCA policies (e.g. the adorsys disk encryption
# baseline) to the agent's etc/shared folder; without this option Wazuh
# ignores every 'c:' rule in them. Note: this lets the manager run SCA
# commands on the endpoint, so the manager must be trusted.
# Usage: enable_sca_remote_commands <local_internal_options_path>
enable_sca_remote_commands() {
    opts="$1"

    if maybe_sudo grep -q '^sca.remote_commands=1$' "$opts" 2>/dev/null; then
        info_message "sca.remote_commands already enabled in $opts"
        return 0
    fi

    if maybe_sudo [ -f "$opts" ]; then
        sed_inplace '/^sca\.remote_commands=/d' "$opts" || error_exit "Failed to update $opts"
    fi

    echo "sca.remote_commands=1" | maybe_sudo tee -a "$opts" > /dev/null || error_exit "Failed to update $opts"
    info_message "Enabled sca.remote_commands in $opts"
}
