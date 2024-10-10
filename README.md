# Wazuh Agent Setup

[![Docker Testing](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/test-script.yml/badge.svg)](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/test-script.yml)

This script automates the installation and setup of the Wazuh agent along with necessary dependencies and additional tools: **Yara** and **Snort**

## Supported Operating Systems
- **Ubuntu**
- **MacOS** 
- **Windows**


## Installation
To run the script and install all these components, use the following command:
```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_AGENT_NAME=test bash
```
### Windows Installation

For Windows, you can download and run the PowerShell script to install the Wazuh agent:

```powershell
# Set the environment variable
$env:WAZUH_AGENT_NAME = "test"

# Download and execute the installation script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/wazuh-agent-win/scripts/install.ps1' -OutFile 'install.ps1'
# Execute the script
& .\install.ps1
```
