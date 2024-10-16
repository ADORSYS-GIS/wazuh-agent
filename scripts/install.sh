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
WAZUH_MANAGER=${WAZUH_MANAGER:-'master.dev.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.8.1-1'}

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

## WAZUH_MANAGER is required
if [ -z "$WAZUH_MANAGER" ]; then
    error_message "WAZUH_MANAGER is required"
    exit 1
fi

# Determine OS type and package manager or set for macOS
if [ "$(uname)" = "Darwin" ]; then
    OS="macOS"
elif [ -f /etc/debian_version ]; then
    OS="Linux"
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    GPG_KEYRING="/usr/share/keyrings/wazuh.gpg"
    GPG_IMPORT_CMD="gpg --no-default-keyring --keyring $GPG_KEYRING --import"
elif [ -f /etc/redhat-release ]; then
    OS="Linux"
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    OS="Linux"
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
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
      $PACKAGE_MANAGER update
      WAZUH_MANAGER="$WAZUH_MANAGER" $PACKAGE_MANAGER install wazuh-agent="$WAZUH_AGENT_VERSION"
  elif [ "$OS" = "macOS" ]; then
      # Detect architecture (Intel or Apple Silicon)
      ARCH=$(uname -m)
      BASE_URL="https://packages.wazuh.com/4.x/macos"
      
      if [ "$ARCH" = "x86_64" ]; then
          # Intel architecture
          PKG_NAME="wazuh-agent-$WAZUH_AGENT_VERSION.intel64.pkg"
      elif [ "$ARCH" = "arm64" ]; then
          # Apple Silicon (M1/M2)
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
          sed -i "s/^deb/#deb/" $REPO_FILE
      elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
          sed -i "s/^enabled=1/enabled=0/" $REPO_FILE
      fi
      info_message "Wazuh repository disabled successfully."
  fi
}

config() {
  # Replace MANAGER_IP placeholder with the actual manager IP in ossec.conf for Linux
  if [ "$OS" = "Linux" ] && [ -n "$WAZUH_MANAGER" ]; then
      sed -i "s/MANAGER_IP/$WAZUH_MANAGER/" "$OSSEC_CONF_PATH"
      info_message "Wazuh manager IP configured successfully."
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

# Main execution
import_keys
installation
disable_repo
config
start_agent 

# End of script
