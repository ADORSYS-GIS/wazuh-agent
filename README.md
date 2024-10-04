# Wazuh Agent Setup

[![Docker Testing](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/test-script.yml/badge.svg)](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/test-script.yml)

This script automates the installation and setup of the Wazuh agent along with necessary dependencies and additional tools: **Yara** and **Snort**

## Supported Operating Systems
- **Ubuntu**
- **MacOS** 


## Installation
To run the script and install all these components, use the following command:
```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_AGENT_NAME=<change-your-name> bash
```