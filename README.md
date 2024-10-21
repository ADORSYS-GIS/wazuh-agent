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

For Windows, Please follow this step by step process to setup the windows wazuh agent.

### 1. Open powershell in administrator mode.

### 2. Run the command to set execution policy. Please respond with "[A] Yes to All"
```powershell


# Set Execution Policy to be able to run powershell script
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
### 3. Run the following commands to download dependecy script and execute it
```powershell
#Download Dependency script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/feat/3-Windows-Agent-Install-Script/scripts/deps.ps1' -OutFile 'deps.ps1'

# Run dependency script
.\deps.ps1
```

### 3. Please close your powershell terminal and re-open in administrator mode again.

### 4. Setup your Agent Name and Run the following commands to complete the installation.
```powershell
#Please replace "test" with your agent name.
$env:WAZUH_AGENT_NAME = "test"

# Download Setup-agent script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/feat/3-Windows-Agent-Install-Script/scripts/setup-agent.ps1' -OutFile 'setup-agent.ps1'

#Run Setup-agent script
.\setup-agent.ps1

```




