# Wazuh Agent Enrollment Guide

This guide provides instructions to enroll Wazuh agents on various platforms, integrating them with the Wazuh Manager for enhanced monitoring and security. Additionally, it automates the installation of tools like Yara and Snort to augment security capabilities.

### Introduction

Wazuh agents collect and transmit security data from endpoints to the Wazuh Manager for analysis. Proper enrollment ensures seamless integration and secure communication. Refer to the respective guide:

- [Linux Enrollment Guide](/Agent%20Enrollment/linux-agent.md)
- [MacOS Enrollment Guide](/Agent%20Enrollment/macos-agent.md)
- [Windows Enrollment Guide](/Agent%20Enrollment/windows-agent.md)

## Quick Start Commands

### Linux
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

### macOS
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

### Windows (PowerShell)
```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1 | iex
```

## Direct Script Usage

You can also run OS-specific scripts directly:

### Linux
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
./scripts/linux/setup-agent.sh
```

### macOS
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
./scripts/macos/setup-agent.sh
```

### Windows
```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
.\scripts\windows\setup-agent.ps1
```