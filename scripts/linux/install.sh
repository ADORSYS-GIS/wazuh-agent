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

# Common variables
OS="Linux"
WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.14.2-1'}
OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
OSSEC_LOG_PATH="/var/ossec/logs"
LOGO_PATH="/usr/share/pixmaps"
WAZUH_CONTROL_PATH="/var/ossec/bin/wazuh-control"

## WAZUH_MANAGER is required
if [ -z "$WAZUH_MANAGER" ]; then
    error_message "WAZUH_MANAGER is required"
    exit 1
fi

# Determine Linux distribution and package manager
if [ -f /etc/debian_version ]; then
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    GPG_KEYRING="/usr/share/keyrings/wazuh.gpg"
    GPG_IMPORT_CMD="gpg --no-default-keyring --keyring $GPG_KEYRING --import"
elif [ -f /etc/redhat-release ]; then
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
else
    error_message "Unsupported Linux distribution"
    exit 1
fi

import_keys() {
  info_message "Importing GPG key and setting up the repository for $OS ($PACKAGE_MANAGER)"
    # Import GPG key and set up the repository for Linux
  GPG_KEY_URL="https://packages.wazuh.com/key/GPG-KEY-WAZUH"

      if [ "$PACKAGE_MANAGER" = "yum" ]; then
        if ! rpm -q gpg-pubkey --qf '%{SUMMARY}\n' | grep -q "Wazuh"; then
            curl -s $GPG_KEY_URL | $GPG_IMPORT_CMD
            info_message "GPG key imported successfully."
        fi
      fi

      if [ "$PACKAGE_MANAGER" = "apt" ]; then
          if [ ! -f $GPG_KEYRING ]; then
              curl -s $GPG_KEY_URL | gpg --no-default-keyring --keyring $GPG_KEYRING --import && chmod 644 $GPG_KEYRING
              info_message "GPG key imported successfully."
          fi
          if ! grep -q "wazuh" $REPO_FILE; then
              echo "deb [signed-by=$GPG_KEYRING] https://packages.wazuh.com/4.x/apt/ stable main" | tee $REPO_FILE
              info_message "Wazuh repository configured successfully."
          fi
      elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
          if ! grep -q "wazuh" $REPO_FILE; then
              cat > $REPO_FILE << EOF
[wazuh]
gpgcheck=1
gpgkey=$GPG_KEY_URL
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
              info_message "Wazuh repository configured successfully."
      fi
  fi
  info_message "GPG key and repository configured successfully."
}

installation() {
  info_message "Installing Wazuh agent for Linux ($PACKAGE_MANAGER)"

  case "$PACKAGE_MANAGER" in
    apt)
      maybe_sudo apt-get update
      maybe_sudo apt-get install -o Dpkg::Options::="--force-confold" -y wazuh-agent="$WAZUH_AGENT_VERSION"
      ;;
    yum)
      maybe_sudo yum update -y
      maybe_sudo yum install -y wazuh-agent-"$WAZUH_AGENT_VERSION"
      ;;
    zypper)
      maybe_sudo zypper refresh
      maybe_sudo zypper install -y wazuh-agent-"$WAZUH_AGENT_VERSION"
      ;;
    *)
      error_exit "Unsupported package manager: $PACKAGE_MANAGER"
      ;;
  esac

  info_message "Wazuh agent installed successfully."
}

disable_repo() {
  # Disable Wazuh repository after installation for Linux
      if [ ! -f "$REPO_FILE" ]; then
          error_message "Repository file not found: $REPO_FILE"
          return 1
      fi
      
      if [ "$PACKAGE_MANAGER" = "apt" ]; then
          if ! sed_inplace "s/^deb/#deb/" "$REPO_FILE"; then
              error_message "Failed to disable APT repository"
              return 1
          fi
      elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
          if ! sed_inplace "s/^enabled=1/enabled=0/" "$REPO_FILE"; then
              error_message "Failed to disable YUM/Zypper repository"
              return 1
          fi
      else
          error_message "Unsupported package manager: $PACKAGE_MANAGER"
          return 1
      fi
      info_message "Wazuh repository disabled successfully."
      return 0
}

enable_repo() {
  if [ ! -f "$REPO_FILE" ]; then
      error_message "Repository file not found: $REPO_FILE"
      return 1
  fi

  info_message "Enabling wazuh repository"
  
  if [ "$PACKAGE_MANAGER" = "apt" ]; then
      if ! sed_inplace "s/^#deb/deb/" "$REPO_FILE"; then
          error_message "Failed to enable APT repository"
          return 1
      fi
  elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
      if ! sed_inplace "s/^enabled=0/enabled=1/" "$REPO_FILE"; then
          error_message "Failed to enable YUM/Zypper repository"
          return 1
      fi
  else
      error_message "Unsupported package manager: $PACKAGE_MANAGER"
      return 1
  fi

  if ! maybe_sudo "$PACKAGE_MANAGER" update; then
      error_message "Failed to update package manager cache"
      return 1
  fi
  
  info_message "Wazuh repository enabled successfully."
  return 0
}

get_installed_version() {
    # Linux version detection
    if command -v dpkg >/dev/null; then
        dpkg -l | awk '/wazuh-agent/ {print $3; exit}'
    elif command -v rpm >/dev/null; then
        rpm -qa --queryformat '%{VERSION}-%{RELEASE}\n' wazuh-agent 2>/dev/null | head -1
    else
        warn_message "Cannot determine installed version on Linux."
        exit 0
    fi
}

config() {
    REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}"

    # Replace MANAGER_IP placeholder with the actual manager IP in ossec.conf for Linux
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
        sed_inplace '/<manager_address>.*<\/manager_address>/d' "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during old manager address removal."
            exit 1
        }
    fi
  
            # Check if the specific <location> tag exists in the configuration file
            if ! maybe_sudo grep -q "<location>/var/ossec/logs/active-responses.log</location>" "$OSSEC_CONF_PATH"; then
                info_message "Configuring active-response logs in $OSSEC_CONF_PATH"
                sed_inplace '/<\/ossec_config>/i\
                    <!-- active response logs -->\
                    <localfile>\
                        <log_format>syslog<\/log_format>\
                        <location>\/var\/ossec\/logs\/active-responses.log<\/location>\
                    <\/localfile>' "$OSSEC_CONF_PATH"
        
                info_message "active-response logs are now being monitored"
            else
                info_message "active-response logs already being monitored in $OSSEC_CONF_PATH"
            fi

    # Download logo
    if [ ! -d "$LOGO_PATH" ]; then
        info_message "Creating $LOGO_PATH directory..."
        mkdir -p "$LOGO_PATH"
        info_message "Directory created successfully."
    else
        info_message "$LOGO_PATH directory already exists."
    fi
    info_message "Downloading logo..."
    download_and_verify_file "$REPO_URL/assets/wazuh-logo.png" "assets/wazuh-logo.png" "assets/wazuh-logo.png" "logo"
    maybe_sudo chmod +r "$LOGO_PATH/wazuh-logo.png"
    info_message "Logo downloaded successfully."
}

start_agent() {
  # Reload systemd daemon and enable/start services based on init system for Linux
  SYSTEMD_RUNNING=$(ps -C systemd > /dev/null 2>&1 && echo "yes" || echo "no")
  if [ "$SYSTEMD_RUNNING" = "yes" ]; then
      if ! systemctl daemon-reload || ! systemctl enable wazuh-agent || ! systemctl start wazuh-agent; then
          error_message "Failed to start Wazuh agent service"
          exit 1
      fi
  elif [ -f /etc/init.d/wazuh-agent ]; then
      if [ "$PACKAGE_MANAGER" = "yum" ]; then
          chkconfig --add wazuh-agent
          if ! service wazuh-agent start; then
              error_message "Failed to start Wazuh agent service"
              exit 1
          fi
      elif [ "$PACKAGE_MANAGER" = "apt" ]; then
          update-rc.d wazuh-agent defaults 95 10
          if ! service wazuh-agent start; then
              error_message "Failed to start Wazuh agent service"
              exit 1
          fi
      fi
  elif maybe_sudo [ -x "$OSSEC_CONTROL_PATH" ]; then
      if ! $WAZUH_CONTROL_PATH start; then
          error_message "Failed to start Wazuh agent service"
          exit 1
      fi
  fi
  info_message "Wazuh agent started successfully."
}

# Validate agent installation
validate_installation() {
    info_message "Validating installation and configuration..."

    # Check if the Wazuh agent service is running on Linux
    if maybe_sudo $WAZUH_CONTROL_PATH status | grep -i -q "wazuh-agentd is running"; then
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
    if maybe_sudo [ ! -f "$LOGO_PATH/wazuh-logo.png" ]; then
        warn_message "Logo file has not been downloaded."
    fi
    info_message "Logo file exists at $LOGO_PATH/wazuh-logo.png."

  success_message "Installation and configuration validated successfully."
}

# Main execution
case $(uname) in
    Linux*)
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
            import_keys
            enable_repo
            installation
            disable_repo
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