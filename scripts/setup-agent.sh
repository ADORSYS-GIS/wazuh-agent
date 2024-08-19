#!/bin/sh

# Default log level and application details
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
APP_NAME=${APP_NAME:-"wazuh-cert-oauth2-client"}
WOPS_VERSION=${WOPS_VERSION:-"0.1.5"}
OSSEC_CONF_PATH=${OSSEC_CONF_PATH:-"/var/ossec/etc/ossec.conf"}
USER=${USER:-"root"}
GROUP=${GROUP:-"wazuh"}

WAZUH_MANAGER=${WAZUH_MANAGER:-'master.wazuh.adorsys.team'}
WAZUH_AGENT_VERSION=${WAZUH_AGENT_VERSION:-'4.8.0-1'}
WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME:-}

# Step 0: Ensure Curl and JQ are installed
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh/main/scripts/deps.sh | sh) >/dev/null 2>&1; then
    echo "Failed to ensure deps"
    exit 1
fi

# Step 1: Download and install Wazuh agent
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh/main/scripts/install.sh | sh) >/dev/null 2>&1; then
    echo "Failed to install wazuh-agent"
    exit 1
fi

# Step 2: Download and install wazuh-cert-oauth2-client
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/main/scripts/install.sh | sh) >/dev/null 2>&1; then
    echo "Failed to install 'wazuh-cert-oauth2-client'"
    exit 1
fi

# Step 3: Download and install yara
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/install.sh | sh) >/dev/null 2>&1; then
    echo "Failed to install 'yara'"
    exit 1
fi

# Step 4: Download and install snort
if ! (curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/install.sh | sh) >/dev/null 2>&1; then
    echo "Failed to install 'snort'"
    exit 1
fi