#!/bin/sh

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Variables
LOG_LEVEL=${LOG_LEVEL:-INFO}
OSSEC_CONF_PATH=${OSSEC_CONF_PATH:-"/var/ossec/etc/ossec.conf"}
WAZUH_MANAGER=${WAZUH_MANAGER:-'events.dev.wazuh.adorsys.team'}
WAZUH_REGISTRATION_SERVER=${WAZUH_REGISTRATION_SERVER:-'register.dev.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.9.2-1'}

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

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

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
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

sed_alternative() {
    if command_exists gsed; then
        gsed "$@"
    else
        sed "$@"
    fi
}

## WAZUH_MANAGER is required
if [ -z "$WAZUH_MANAGER" ]; then
    error_message "WAZUH_MANAGER is required"
    exit 1
fi

# Determine OS type and package manager or set for macOS
if [ "$(uname)" = "Darwin" ]; then
    OS="macOS"
    UPGRADE_SCRIPT_PATH=${UPGRADE_SCRIPT_PATH:-'/Library/Ossec/active-response/bin/adorsys-upgrade.sh'}
elif [ -f /etc/debian_version ]; then
    OS="Linux"
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    GPG_KEYRING="/usr/share/keyrings/wazuh.gpg"
    GPG_IMPORT_CMD="gpg --no-default-keyring --keyring $GPG_KEYRING --import"
    UPGRADE_SCRIPT_PATH=${UPGRADE_SCRIPT_PATH:-'/var/ossec/active-response/bin/adorsys-upgrade.sh'}
elif [ -f /etc/redhat-release ]; then
    OS="Linux"
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
    UPGRADE_SCRIPT_PATH=${UPGRADE_SCRIPT_PATH:-'/var/ossec/active-response/bin/adorsys-upgrade.sh'}
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    OS="Linux"
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
    UPGRADE_SCRIPT_PATH=${UPGRADE_SCRIPT_PATH:-'/var/ossec/active-response/bin/adorsys-upgrade.sh'}
else
    error_message "Unsupported OS"
    exit 1
fi

import_keys() {
  info_message "Importing GPG key and setting up the repository for $OS"
  # Import GPG key and set up the repository for Linux
  GPG_KEY_URL="https://packages.wazuh.com/key/GPG-KEY-WAZUH"
  if [ "$OS" = "Linux" ]; then
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
  fi
  info_message "GPG key and repository configured successfully."
}

installation() {
  info_message "Installing Wazuh agent for $OS"
  # Update and install Wazuh agent for Linux or download and install for macOS
  if [ "$OS" = "Linux" ]; then
      maybe_sudo $PACKAGE_MANAGER update
      WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_REGISTRATION_SERVER="$WAZUH_REGISTRATION_SERVER" $PACKAGE_MANAGER install wazuh-agent="$WAZUH_AGENT_VERSION"
  elif [ "$OS" = "macOS" ]; then
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
      installer -pkg "$TMP_DIR/$PKG_NAME" -target /

      # Clean up the temporary directory after installation
      rm -rf "$TMP_DIR"
      info_message "Temporary directory cleaned up."
  fi
  info_message "Wazuh agent installed successfully."
}



disable_repo() {
  # Disable Wazuh repository after installation for Linux
  if [ "$OS" = "Linux" ]; then
      if [ "$PACKAGE_MANAGER" = "apt" ]; then
          sed_alternative -i "s/^deb/#deb/" $REPO_FILE
      elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
          sed_alternative -i "s/^enabled=1/enabled=0/" $REPO_FILE
      fi
      info_message "Wazuh repository disabled successfully."
  fi
}

enable_repo() {
  if [ -f /etc/apt/sources.list.d/wazuh.list ]; then
    info_message "Should enable wazuh repository"
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
      sed_alternative -i "s/^#deb/deb/" $REPO_FILE
    elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
      sed_alternative -i "s/^enabled=0/enabled=1/" $REPO_FILE
    fi

    maybe_sudo $PACKAGE_MANAGER update
    info_message "Wazuh repository enabled successfully."
  fi
}

config() {
  # Replace MANAGER_IP placeholder with the actual manager IP in ossec.conf for Linux
  if ! maybe_sudo grep -q "<address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH"; then
    # First remove <address till address>
    maybe_sudo sed_alternative -i '/<address>.*<\/address>/d' "$OSSEC_CONF_PATH" || {
        error_message "Error occurred during Wazuh agent certificate configuration."
        exit 1
    }

    maybe_sudo sed_alternative -i "/<server=*/ a\
      <address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH" || {
        error_message "Error occurred during Wazuh agent certificate configuration."
        exit 1
    }
  fi

  if ! maybe_sudo grep -q "<manager_address>$WAZUH_REGISTRATION_SERVER</manager_address>" "$OSSEC_CONF_PATH"; then
    # First remove <manager_address till manager_address>
    maybe_sudo sed_alternative -i '/<manager_address>.*<\/manager_address>/d' "$OSSEC_CONF_PATH" || {
        error_message "Error occurred during Wazuh agent certificate configuration."
        exit 1
    }

    maybe_sudo sed_alternative -i "/<agent_name=*/ a\
      <manager_address>$WAZUH_REGISTRATION_SERVER</manager_address>" "$OSSEC_CONF_PATH" || {
        error_message "Error occurred during Wazuh agent certificate configuration."
        exit 1
    }
  fi
}

start_agent() {
  # Reload systemd daemon and enable/start services based on init system for Linux
  if [ "$OS" = "Linux" ]; then
      SYSTEMD_RUNNING=$(ps -C systemd > /dev/null 2>&1 && echo "yes" || echo "no")
      if [ "$SYSTEMD_RUNNING" = "yes" ]; then
          systemctl daemon-reload
          systemctl enable wazuh-agent
          systemctl start wazuh-agent
      elif [ -f /etc/init.d/wazuh-agent ]; then
          if [ "$PACKAGE_MANAGER" = "yum" ]; then
              chkconfig --add wazuh-agent
              service wazuh-agent start
          elif [ "$PACKAGE_MANAGER" = "apt" ]; then
              update-rc.d wazuh-agent defaults 95 10
              service wazuh-agent start
          fi
      else
          /var/ossec/bin/wazuh-control start
      fi
  elif [ "$OS" = "macOS" ]; then
      /Library/Ossec/bin/wazuh-control start
  fi
  info_message "Wazuh agent started successfully."
}

create_upgrade_script() {
    maybe_sudo cat << 'EOF' > "$UPGRADE_SCRIPT_PATH"
#!/bin/sh
# Upgrade script from ADORSYS.
# Copyright (C) 2024, ADORSYS Inc.

set -u

LOCAL=$(dirname $0)
cd $LOCAL
cd ../../
PWD=$(pwd)

echo "$(date) Starting wazuh upgrade..." >> ${PWD}/logs/active-responses.log
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | sh
echo "$(date) Wazuh upgrade finished with success" >> ${PWD}/logs/active-responses.log
EOF
    # Make the new script executable
    maybe_sudo chown root:wazuh "$UPGRADE_SCRIPT_PATH"
    maybe_sudo chmod 750 "$UPGRADE_SCRIPT_PATH"
    # Confirm creation
    info_message "Script created at $UPGRADE_SCRIPT_PATH"
}

# Main execution
import_keys
enable_repo
installation
disable_repo
config
create_upgrade_script
start_agent 

# End of script