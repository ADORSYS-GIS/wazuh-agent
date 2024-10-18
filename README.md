# Wazuh Agent Setup

[![Release Client](https://github.com/ADORSYS-GIS/wazuh-cert-oauth2/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/ADORSYS-GIS/wazuh-cert-oauth2/actions/workflows/release.yml)


This script automates the installation and setup of the Wazuh agent along with necessary dependencies and additional tools: **Yara** and **Snort**

## Supported Operating Systems
- **Ubuntu**
- **MacOS** 
- **Windows**


## Installation

**Remark:** 
This script will enroll the Wazuh agent on the **dev** cluster by default, you should meet a member of the wazuh team if you want to enroll it elsewhere 

### Linux/MacOS Installation

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
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/main/scripts/setup-agent.ps1' -OutFile 'setup-agent.ps1'
# Execute the script
& .\setup-agent.ps1
```
https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/main/scripts/setup-agent.ps1