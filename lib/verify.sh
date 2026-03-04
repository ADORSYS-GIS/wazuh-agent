#!/bin/sh
#
# Download Verification Library
# Provides checksum verification for secure script downloads
#

# Verify SHA256 checksum of a file
# Arguments:
#   $1 - File path to verify
#   $2 - Expected SHA256 hash
# Returns:
#   0 if checksum matches, 1 otherwise
verify_checksum() {
    local file="$1"
    local expected_hash="$2"
    local actual_hash=""

    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi

    # Calculate hash based on available tool
    if command -v sha256sum >/dev/null 2>&1; then
        actual_hash=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        echo "ERROR: No SHA256 tool available (sha256sum or shasum required)" >&2
        return 1
    fi

    if [ "$actual_hash" != "$expected_hash" ]; then
        echo "ERROR: Checksum verification failed for $file" >&2
        echo "  Expected: $expected_hash" >&2
        echo "  Got:      $actual_hash" >&2
        return 1
    fi

    return 0
}

# Download a file and verify its checksum
# Arguments:
#   $1 - URL to download
#   $2 - Destination path
#   $3 - Expected SHA256 hash (optional - skip verification if empty)
# Returns:
#   0 if download and verification succeed, 1 otherwise
download_and_verify() {
    local url="$1"
    local dest="$2"
    local expected_hash="$3"

    # Download the file
    if ! curl -SL -s "$url" -o "$dest"; then
        echo "ERROR: Failed to download $url" >&2
        return 1
    fi

    # Verify checksum if provided
    if [ -n "$expected_hash" ]; then
        if ! verify_checksum "$dest" "$expected_hash"; then
            rm -f "$dest"
            return 1
        fi
    fi

    return 0
}

# Fetch checksums from remote checksums file
# Arguments:
#   $1 - Base URL for checksums file
#   $2 - Filename to look up
# Returns:
#   Prints the checksum if found, empty if not
fetch_remote_checksum() {
    local checksums_url="$1"
    local filename="$2"
    local checksum=""

    checksum=$(curl -SL -s "$checksums_url" 2>/dev/null | grep "$filename" | awk '{print $1}')
    echo "$checksum"
}

# Validate input parameters
# Arguments:
#   $1 - Parameter name
#   $2 - Parameter value
#   $3 - Validation regex pattern
# Returns:
#   0 if valid, 1 otherwise
validate_input() {
    local name="$1"
    local value="$2"
    local pattern="$3"

    if [ -z "$value" ]; then
        echo "ERROR: $name is required but not set" >&2
        return 1
    fi

    if [ -n "$pattern" ]; then
        if ! echo "$value" | grep -qE "$pattern"; then
            echo "ERROR: $name has invalid format: $value" >&2
            return 1
        fi
    fi

    return 0
}

# Validate WAZUH_MANAGER address format
# Arguments:
#   $1 - Manager address (hostname or IP)
# Returns:
#   0 if valid, 1 otherwise
validate_manager_address() {
    local manager="$1"

    # Check for empty
    if [ -z "$manager" ]; then
        echo "ERROR: WAZUH_MANAGER is required" >&2
        return 1
    fi

    # Check for default placeholder
    if [ "$manager" = "wazuh.example.com" ]; then
        echo "WARNING: WAZUH_MANAGER is set to default placeholder 'wazuh.example.com'" >&2
        echo "WARNING: Please set WAZUH_MANAGER to your actual Wazuh manager address" >&2
    fi

    # Validate format (hostname or IP)
    # Hostname: alphanumeric with dots and hyphens
    # IP: four octets separated by dots
    local hostname_pattern="^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$"
    local ip_pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if echo "$manager" | grep -qE "$hostname_pattern"; then
        return 0
    elif echo "$manager" | grep -qE "$ip_pattern"; then
        return 0
    else
        echo "ERROR: WAZUH_MANAGER has invalid format: $manager" >&2
        echo "ERROR: Must be a valid hostname or IP address" >&2
        return 1
    fi
}

# Validate version string format
# Arguments:
#   $1 - Version string (e.g., 4.13.1-1, 0.3.11)
# Returns:
#   0 if valid, 1 otherwise
validate_version() {
    local version="$1"
    local pattern="^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$"

    if [ -z "$version" ]; then
        echo "ERROR: Version is required" >&2
        return 1
    fi

    if ! echo "$version" | grep -qE "$pattern"; then
        echo "ERROR: Invalid version format: $version" >&2
        echo "ERROR: Expected format: X.Y.Z or X.Y.Z-N" >&2
        return 1
    fi

    return 0
}

# Check network connectivity to host
# Arguments:
#   $1 - Hostname or IP to check
#   $2 - Timeout in seconds (default: 5)
# Returns:
#   0 if reachable, 1 otherwise
check_connectivity() {
    local host="$1"
    local timeout="${2:-5}"

    # Try ping first (may be blocked)
    if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        return 0
    fi

    # Try TCP connection to common Wazuh ports
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w "$timeout" "$host" 1514 2>/dev/null || \
           nc -z -w "$timeout" "$host" 1515 2>/dev/null || \
           nc -z -w "$timeout" "$host" 443 2>/dev/null; then
            return 0
        fi
    fi

    # Try curl to HTTPS
    if curl -s --connect-timeout "$timeout" "https://$host" >/dev/null 2>&1; then
        return 0
    fi

    echo "WARNING: Cannot verify connectivity to $host" >&2
    return 1
}
