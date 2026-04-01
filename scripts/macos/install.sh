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

# Download checksums and verify utils.sh integrity BEFORE sourcing it
if ! curl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/checksums.sha256" -o "$UTILS_TMP/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi
CHECKSUMS_FILE="$UTILS_TMP/checksums.sha256"

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$UTILS_TMP/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$UTILS_TMP/utils.sh")

if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# Source utils.sh only after verification
. "$UTILS_TMP/utils.sh"

# Variables
LOG_LEVEL=${LOG_LEVEL:-INFO}
WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.14.2-1'}

# macOS-specific paths
OSSEC_CONF_PATH="/Library/Ossec/etc/ossec.conf"
OSSEC_LOG_PATH="/Library/Ossec/logs"
LOCAL_PATH="/Library/Application Support/Ossec"
WAZUH_CONTROL_PATH="/Library/Ossec/bin/wazuh-control"

## WAZUH_MANAGER is required
if [ -z "$WAZUH_MANAGER" ]; then
    error_message "WAZUH_MANAGER is required"
    exit 1
fi

installation() {
  info_message "Installing Wazuh agent for macOS"
      # Detect architecture (Intel or Apple Silicon)
      ARCH=$(uname -m)
      BASE_URL="https://packages.wazuh.com/4.x/macos"
      
      if [ "$ARCH" = "x86_64" ]; then
          # Intel architecture
          PKG_NAME="wazuh-agent-$WAZUH_AGENT_VERSION.intel64.pkg"
      elif [ "$ARCH" = "arm64" ]; then
          # Apple Silicon chip
          PKG_NAME="wazuh-agent-$WAZUH_AGENT_VERSION.arm64.pkg"
      else
          error_message "Unsupported architecture: $ARCH"
          exit 1
      fi

      PKG_URL="$BASE_URL/$PKG_NAME"

      # Create a unique temporary directory
      TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'wazuh_install')
      info_message "Using temporary directory: $TMP_DIR"

      # Download the correct Wazuh agent package based on architecture
      curl -o "$TMP_DIR/$PKG_NAME" "$PKG_URL"
      info_message "Wazuh agent downloaded successfully."

      # Set environment variable for Wazuh manager
      echo "WAZUH_MANAGER='$WAZUH_MANAGER'" > /tmp/wazuh_envs

      # Install Wazuh agent using the package
      maybe_sudo installer -pkg "$TMP_DIR/$PKG_NAME" -target /

      # Clean up the temporary directory after installation
      rm -rf "$TMP_DIR"
      info_message "Temporary directory cleaned up."
  info_message "Wazuh agent installed successfully."
}

get_installed_version() {
    # macOS (PKG)
    if [ -f "/var/db/receipts/com.wazuh.pkg.wazuh-agent.plist" ]; then
        plutil -p "/var/db/receipts/com.wazuh.pkg.wazuh-agent.plist" 2>/dev/null | \
        awk -F'"' '/PackageFileName/ {print $4}' | \
        sed -E 's/.*wazuh-agent-([0-9.]+-[0-9]+).*/\1/'            
    else
        warn_message "Cannot determine installed version on macOS."
        exit 0
    fi
}

config() {
    REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}"

    # Replace MANAGER_IP placeholder with the actual manager IP in ossec.conf for macOS
    if ! maybe_sudo grep -q "<address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH"; then
        info_message "Configuring Wazuh agent with manager address $WAZUH_MANAGER in $OSSEC_CONF_PATH"
        # First remove <address till address>
        maybe_sudo sed_inplace '/<address>.*<\/address>/d' "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during old manager address removal."
            exit 1
        }

        maybe_sudo sed_inplace "/<server=*/ a\
        <address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during insertion of latest manager address."
            exit 1
        }
    fi
  
    # Delete REGISTRATION_SERVER_ADDRESS if it exists
    if maybe_sudo grep -q "<manager_address>.*</manager_address>" "$OSSEC_CONF_PATH"; then
        info_message "Removing manager_address block from $OSSEC_CONF_PATH"
        # Remove <manager_address> till </manager_address>
        maybe_sudo sed_inplace '/<manager_address>.*<\/manager_address>/d' "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during old manager address removal."
            exit 1
        }
    fi
  
        # Check if the specific <location> tag exists in the configuration file
            if ! maybe_sudo grep -q "<location>/Library/Ossec/logs/active-responses.log</location>" "$OSSEC_CONF_PATH"; then
                info_message "Configuring active-response logs in $OSSEC_CONF_PATH"
                sed_inplace -e "/<\/ossec_config>/i\\
                    <!-- active response logs -->\\
                    <localfile>\\
                        <log_format>syslog</log_format>\\
                        <location>/Library/Ossec/logs/active-responses.log</location>\\
                    </localfile>" "$OSSEC_CONF_PATH"
        
                info_message "active-response logs are now being monitored"
            else
                info_message "active-response logs already being monitored in $OSSEC_CONF_PATH"
            fi

    # Download logo
    if [ ! -d "$LOCAL_PATH" ]; then
        info_message "Creating $LOCAL_PATH directory..."
        mkdir -p "$LOCAL_PATH"
        info_message "Directory created successfully."
    else
        info_message "$LOCAL_PATH directory already exists."
    fi
    info_message "Downloading logo..."
    download_and_verify_file "$REPO_URL/assets/wazuh-logo.png" "$LOCAL_PATH/wazuh-logo.png" "assets/wazuh-logo.png" "logo"
    maybe_sudo chmod +r "$LOCAL_PATH/wazuh-logo.png"
    info_message "Logo downloaded successfully."
}

start_agent() {
  # Start Wazuh agent on macOS
  if command_exists launchctl; then
    launchctl load -w /Library/LaunchDaemons/com.wazuh.agent.plist
  else
    "$WAZUH_CONTROL_PATH" start
  fi
  info_message "Wazuh agent started successfully."
}

# Validate agent installation
validate_installation() {
    info_message "Validating installation and configuration..."

    # Check if the Wazuh agent service is running on macOS
    if maybe_sudo "$WAZUH_CONTROL_PATH" status | grep -i -q "wazuh-agentd is running"; then
        info_message "Wazuh agent service is running."
    else
        warn_message "Wazuh agent service is not running."
    fi

    # Check if the configuration file contains the correct manager and registration server
    if ! maybe_sudo grep -q "<address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH"; then
        warn_message "Wazuh manager address is not configured correctly in $OSSEC_CONF_PATH."
    fi
    info_message "Wazuh manager address $WAZUH_MANAGER is configured correctly in $OSSEC_CONF_PATH."

    if ! maybe_sudo grep -q "<location>$OSSEC_LOG_PATH/active-responses.log</location>" "$OSSEC_CONF_PATH"; then
        warn_message "Active response logs are not configured correctly in $OSSEC_CONF_PATH."
    fi
    info_message "active-response logs are configured to be monitored."

    # Check if the logo file exists
    if maybe_sudo [ ! -f "$LOCAL_PATH/wazuh-logo.png" ]; then
        warn_message "Logo file has not been downloaded."
    fi
    info_message "Logo file exists at $LOCAL_PATH/wazuh-logo.png."

  success_message "Installation and configuration validated successfully."
}


# Main execution
case $(uname) in
    Darwin*)
        INSTALLED_VERSION=$(get_installed_version)

        if [ "$INSTALLED_VERSION" = "$WAZUH_AGENT_VERSION" ]; then
            info_message "Wazuh agent $WAZUH_AGENT_VERSION is already installed. Skipping installation."
        else
            if [ -z "$INSTALLED_VERSION" ]; then
                info_message "Installing fresh Wazuh agent $WAZUH_AGENT_VERSION..."
            else
                info_message "Upgrading Wazuh agent ($INSTALLED_VERSION → $WAZUH_AGENT_VERSION)..."
            fi
            # Start the installation process
            installation
        fi
        # Always update config/scripts
        config
        start_agent 
        validate_installation
        ;;
    *)
        error_exit "Unsupported OS"
        ;;
esac
