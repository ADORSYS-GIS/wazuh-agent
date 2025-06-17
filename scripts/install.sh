#!/bin/sh

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Variables
LOG_LEVEL=${LOG_LEVEL:-INFO}
WAZUH_MANAGER=${WAZUH_MANAGER:-'wazuh.example.com'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.11.1-1'}

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
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

# Logging helpers
info_message() {
    log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"
}

warn_message() {
    log "${YELLOW}${BOLD}[WARNING]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"
}

print_step() {
    log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"
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

create_file() {
    local filepath="$1"
    local content="$2"
    maybe_sudo bash -c "cat > \"$filepath\" <<EOF
$content
EOF"
    info_message "Created file: $filepath"
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
    UPGRADE_SCRIPT_PATH="/Library/Ossec/active-response/bin/adorsys-update.sh"
    OSSEC_CONF_PATH="/Library/Ossec/etc/ossec.conf"
    OSSEC_PATH="/Library/Ossec/etc"
    LOCAL_PATH="/Library/Application Support/Ossec"
elif [ -f /etc/debian_version ]; then
    OS="Linux"
    PACKAGE_MANAGER="apt"
    REPO_FILE="/etc/apt/sources.list.d/wazuh.list"
    GPG_KEYRING="/usr/share/keyrings/wazuh.gpg"
    GPG_IMPORT_CMD="gpg --no-default-keyring --keyring $GPG_KEYRING --import"
    UPGRADE_SCRIPT_PATH="/var/ossec/active-response/bin/adorsys-update.sh"
    OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
    OSSEC_PATH="/var/ossec/etc"
    LOCAL_PATH="/usr/share/pixmaps"
elif [ -f /etc/redhat-release ]; then
    OS="Linux"
    PACKAGE_MANAGER="yum"
    REPO_FILE="/etc/yum.repos.d/wazuh.repo"
    UPGRADE_SCRIPT_PATH="/var/ossec/active-response/bin/adorsys-update.sh"
    OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
    OSSEC_PATH="/var/ossec/etc"
    LOCAL_PATH="/usr/share/pixmaps"
elif [ -f /etc/SuSE-release ] || [ -f /etc/zypp/repos.d ]; then
    OS="Linux"
    PACKAGE_MANAGER="zypper"
    REPO_FILE="/etc/zypp/repos.d/wazuh.repo"
    UPGRADE_SCRIPT_PATH="/var/ossec/active-response/bin/adorsys-update.sh"
    OSSEC_CONF_PATH="/var/ossec/etc/ossec.conf"
    OSSEC_PATH="/var/ossec/etc"
    LOCAL_PATH="/usr/share/pixmaps"
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
      $PACKAGE_MANAGER install wazuh-agent="$WAZUH_AGENT_VERSION"
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
      maybe_sudo installer -pkg "$TMP_DIR/$PKG_NAME" -target /

      # Clean up the temporary directory after installation
      rm -rf "$TMP_DIR"
      info_message "Temporary directory cleaned up."
  fi
  info_message "Wazuh agent installed successfully."
}



disable_repo() {
  # Disable Wazuh repository after installation for Linux
  if [ "$OS" = "Linux" ]; then
      if [ ! -f "$REPO_FILE" ]; then
          error_message "Repository file not found: $REPO_FILE"
          return 1
      fi
      
      if [ "$PACKAGE_MANAGER" = "apt" ]; then
          if ! sed_alternative -i "s/^deb/#deb/" "$REPO_FILE"; then
              error_message "Failed to disable APT repository"
              return 1
          fi
      elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
          if ! sed_alternative -i "s/^enabled=1/enabled=0/" "$REPO_FILE"; then
              error_message "Failed to disable YUM/Zypper repository"
              return 1
          fi
      else
          error_message "Unsupported package manager: $PACKAGE_MANAGER"
          return 1
      fi
      info_message "Wazuh repository disabled successfully."
      return 0
  fi
}

enable_repo() {
  if [ "$OS" != "Linux" ]; then
      return 0
  fi

  if [ ! -f "$REPO_FILE" ]; then
      error_message "Repository file not found: $REPO_FILE"
      return 1
  fi

  info_message "Enabling wazuh repository"
  
  if [ "$PACKAGE_MANAGER" = "apt" ]; then
      if ! sed_alternative -i "s/^#deb/deb/" "$REPO_FILE"; then
          error_message "Failed to enable APT repository"
          return 1
      fi
  elif [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "zypper" ]; then
      if ! sed_alternative -i "s/^enabled=0/enabled=1/" "$REPO_FILE"; then
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
    case "$(uname -s)" in
        Linux*)
            # Ubuntu/Debian
            if command -v dpkg >/dev/null; then
                dpkg -l | grep wazuh-agent | awk '{print $3}'
            # RHEL/CentOS
            elif command -v rpm >/dev/null; then
                rpm -qa --queryformat '%{VERSION}-%{RELEASE}\n' wazuh-agent | head -1
            fi
            ;;
        Darwin*)
            # macOS (PKG)
            plutil -p /var/db/receipts/com.wazuh.pkg.wazuh-agent.plist | grep PackageFileName | sed -E 's/.*wazuh-agent-([0-9.]+-[0-9]+)\..*/\1/'
            ;;
    esac
}

config() {
    REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"

    # Replace MANAGER_IP placeholder with the actual manager IP in ossec.conf for unix systems
    if ! maybe_sudo grep -q "<address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH"; then
        # First remove <address till address>
        maybe_sudo sed_alternative -i '/<address>.*<\/address>/d' "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during old manager address removal."
            exit 1
        }

        maybe_sudo sed_alternative -i "/<server=*/ a\
        <address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during insertion of latest manager address."
            exit 1
        }
    fi
  
    # Delete REGISTRATION_SERVER_ADDRESS if it exists
    if ! maybe_sudo grep -q "<manager_address>.*</manager_address>" "$OSSEC_CONF_PATH"; then
        # First remove <address till address>
        maybe_sudo sed_alternative -i '/<manager_address>.*<\/manager_address>/d' "$OSSEC_CONF_PATH" || {
            error_message "Error occurred during old manager address removal."
            exit 1
        }
    fi
  
    case "$(uname)" in
        Linux*)
            # Check if the specific <location> tag exists in the configuration file
            if ! maybe_sudo grep -q "<location>/var/ossec/logs/active-responses.log</location>" "$OSSEC_CONF_PATH"; then
                
                sed_alternative -i '/<\/ossec_config>/i\
                    <!-- active response logs -->\
                    <localfile>\
                        <log_format>syslog<\/log_format>\
                        <location>\/var\/ossec\/logs\/active-responses.log<\/location>\
                    <\/localfile>' "$OSSEC_CONF_PATH"
            
        
                info_message "active-response logs are now being monitored"
            else
                info_message "The active response already exists in $OSSEC_CONF_PATH"
            fi
            info_message "Wazuh agent certificate configuration completed successfully."
            ;;
        Darwin*)
            if ! maybe_sudo grep -q "<location>/Library/Ossec/logs/active-responses.log</location>" "$OSSEC_CONF_PATH"; then
        
                sed_alternative -i -e "/<\/ossec_config>/i\\
                    <!-- active response logs -->\\
                    <localfile>\\
                        <log_format>syslog</log_format>\\
                        <location>/Library/Ossec/logs/active-responses.log</location>\\
                    </localfile>" "$OSSEC_CONF_PATH"
            
        
                info_message "active-response logs are now being monitored"
            else
                info_message "The active response already exists in $OSSEC_CONF_PATH"
            fi
            info_message "Wazuh agent certificate configuration completed successfully."
            ;;
        esac

    # Download logo
    if [ ! -d "$LOCAL_PATH" ]; then
        info_message "Creating $LOCAL_PATH directory..."
        mkdir -p "$LOCAL_PATH"
        info_message "Directory created successfully."
    else
        info_message "$LOCAL_PATH directory already exists."
    fi
    info_message "Downloading logo..."
    maybe_sudo curl "$REPO_URL/assets/wazuh-logo.png" -o "$LOCAL_PATH/wazuh-logo.png"
    maybe_sudo chmod +r "$LOCAL_PATH/wazuh-logo.png"
    info_message "Logo downloaded successfully."

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
    maybe_sudo cat << EOF > "$UPGRADE_SCRIPT_PATH"
#!/bin/sh
# Upgrade script from ADORSYS.
# Copyright (C) 2024, ADORSYS GmbH & CO KG.

# Check if we're running in bash; if not, adjust behavior
if [ -n "\$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Default log level and application details
LOG_LEVEL=\${LOG_LEVEL:-'INFO'}
WAZUH_MANAGER="$WAZUH_MANAGER"

# Define the log file path
if [ "\$(uname)" = "Darwin" ]; then
    LOG_FILE='/Library/Ossec/logs/active-responses.log'
    ARCH=\$(uname -m)
    if [ "\$ARCH" = "x86_64" ]; then
        BIN_FOLDER='/usr/local/bin'
    else
        BIN_FOLDER='/opt/homebrew/bin'
    fi
else
    LOG_FILE='/var/ossec/logs/active-responses.log'
    BIN_FOLDER='/usr/bin'
fi

# Create a temporary directory
TMP_FOLDER="\$(mktemp -d)"

# Define text formatting
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[1;34m'
BOLD='\\033[1m'
NORMAL='\\033[0m'

# Function for logging with timestamp
log() {
    local LEVEL="\$1"
    shift
    local MESSAGE="\$*"
    local TIMESTAMP
    TIMESTAMP=\$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\${TIMESTAMP} \${LEVEL} \${MESSAGE}" >> "\$LOG_FILE"
}

# Logging helpers
info_message() {
    log "\${BLUE}\${BOLD}[INFO]\${NORMAL}" "\$*"
}

error_message() {
    log "\${RED}\${BOLD}[ERROR]\${NORMAL}" "\$*"
}

cleanup() {
    # Remove temporary folder
    if [ -d "\$TMP_FOLDER" ]; then
        rm -rf "\$TMP_FOLDER"
    fi
}

send_notification() {
    local message="\$1"
    local title="Wazuh Update"
    local iconPath="/usr/share/pixmaps/wazuh-logo.png"

    if [ "\$(uname)" = "Darwin" ]; then
        osascript -e "display dialog \"\$message\" buttons {\"Dismiss\"} default button \"Dismiss\" with title \"\$title\""
    elif [ "\$(uname)" = "Linux" ]; then
        # Get the logged-in user
        USER=\$(who | awk '{print \$1}' | head -n 1)
        USER_UID=\$(id -u "\$USER")
        DBUS_PATH="/run/user/\$USER_UID/bus"

        if [ -f "\$iconPath" ]; then
             sudo -u "\$USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=\$DBUS_PATH" \\
                notify-send --app-name=Wazuh -u critical "\$title" "\$message" -i "\$iconPath"
        else
             sudo -u "\$USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=\$DBUS_PATH" \\
                notify-send --app-name=Wazuh -u critical  "\$title" "\$message"
        fi
    else
        error_message "Unsupported OS for notifications: \$(uname)"
    fi
    info_message "Notification sent: \$message"
}

trap cleanup EXIT

# Log environment info
info_message "Starting Wazuh agent upgrade..."

info_message "Adding bin directory: \$BIN_FOLDER to PATH environment"
export PATH="\$BIN_FOLDER:\$PATH"

info_message "Current PATH: \$PATH"

info_message "Starting setup. Using temporary directory: \$TMP_FOLDER"

# Download scripts
info_message "Downloading setup script..."
SCRIPT_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh"

if ! curl -SL -s "\$SCRIPT_URL" -o "\$TMP_FOLDER/setup-agent.sh" >> "\${LOG_FILE}"; then
    error_message "Failed to download setup-agent.sh"
    send_notification "Update failed: For more details go to file \${LOG_FILE}"
    exit 1
fi

chmod +x "\$TMP_FOLDER/setup-agent.sh"

if ! sudo WAZUH_MANAGER="\$WAZUH_MANAGER" bash "\$TMP_FOLDER/setup-agent.sh" >> "\${LOG_FILE}"; then
    error_message "Failed to setup wazuh agent"
    send_notification "Update failed: For more details go to file \${LOG_FILE}"
    exit 1
fi

send_notification "Update completed successfully!"
EOF
    # Make the new script executable
    maybe_sudo chown root:wazuh "$UPGRADE_SCRIPT_PATH"
    maybe_sudo chmod 750 "$UPGRADE_SCRIPT_PATH"
    # Confirm creation
    info_message "Script created at $UPGRADE_SCRIPT_PATH"
}

# Validate agent installation
validate_installation() {
    info_message "Validating installation and configuration..."

    # Check if the Wazuh agent service is running
    if [ "$OS" = "Linux" ]; then
        if maybe_sudo /var/ossec/bin/wazuh-control status | grep -i "wazuh-agentd is running"; then
            success_message "Wazuh agent service is running."
        else
            error_message "Wazuh agent service is not running."
        fi
    elif [ "$OS" = "macOS" ]; then
        if maybe_sudo /Library/Ossec/bin/wazuh-control status | grep -i "wazuh-agentd is running"; then
            success_message "Wazuh agent service is running."
        else
            error_message "Wazuh agent service is not running."
        fi
    fi

    # Check if the configuration file contains the correct manager and registration server
    if ! maybe_sudo grep -q "<address>$WAZUH_MANAGER</address>" "$OSSEC_CONF_PATH"; then
        warn_message "Wazuh manager address is not configured correctly in $OSSEC_CONF_PATH."
    fi

    # Check if the logo file exists
    if maybe_sudo [ ! -f "$LOCAL_PATH/wazuh-logo.png" ]; then
        warn_message "Logo file has not been downloaded."
    fi

  success_message "Installation and configuration validated successfully."
}

# Main execution
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
    validate_installation
fi
# Always update config/scripts
config
create_upgrade_script
start_agent 
# End of script
