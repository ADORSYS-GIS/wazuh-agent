# Wazuh Agent Setup

[![Release Client](https://github.com/ADORSYS-GIS/wazuh-cert-oauth2/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/ADORSYS-GIS/wazuh-cert-oauth2/actions/workflows/release.yml)


This repository provides an automated setup script for installing the Wazuh Agent along with essential security tools, **Yara** and **Snort**. This setup enables real-time monitoring, intrusion detection, and malware scanning, integrating Wazuh with powerful security utilities.

## Key Features
- **Automated Installation:** Quick setup of Wazuh agent and dependencies.

- **Cross-Platform Support:** Compatible with Ubuntu, macOS, and Windows.

- **Security Tools Integration:** Pre-configured with Yara and Snort for enhanced threat detection.

## Supported Operating Systems
- **Ubuntu**
- **MacOS** 
- **Windows**


## Installation

### Wazuh Agent Enrollment Guide
This guide provides instructions to enroll Wazuh agents on various platforms, integrating them with the Wazuh Manager for enhanced monitoring and security. Additionally, it automates the installation of tools like Yara and Snort to augment security capabilities.

### Introduction
Wazuh agents collect and transmit security data from endpoints to the Wazuh Manager for analysis. Proper enrollment ensures seamless integration and secure communication. Refer to the respective guide:

- [Linux Enrollment Guide](/Agent%20Enrollment/linux-agent.md)
- [MacOS Enrollment Guide](/Agent%20Enrollment/macos-agent.md)
- [Windows Enrollment Guide](/Agent%20Enrollment/windows-agent.md)

## Additional Notes
### Scripts Overview
This repository includes several scripts for configuring and deploying Wazuh and additional security components:

- **deps.sh:** Installs dependencies required for the Wazuh Agent, Yara, and Snort on Linux/macOS, ensuring all necessary packages and configurations are in place for a smooth installation.

- **deps.ps1:** Installs required dependencies on Windows, ensuring that Yara, Snort, and the Wazuh Agent have all prerequisites met for a seamless setup.

- **install.sh:** Sets up the core Wazuh Agent on Linux/macOS, including necessary configuration files and establishing integration with the Wazuh management server.

- **setup-agent.sh:** Combines both dependency installation and agent setup into a single streamlined process, allowing you to set up everything with one command on Linux/macOS.

- **setup-agent.ps1:** Installs the Wazuh Agent, Yara, and Snort on Windows. It configures the agent to communicate with the Wazuh Manager and integrates essential logging and alerting functions.

- **install.ps1:** Manages the entire Wazuh Agent installation process on Windows, including error-handling and logging. This script checks dependencies and manages the full setup process, from configuration to package management.

### Wazuh Integration with Additional Tools

- **Yara:** Scans files for malware signatures, forwarding results to the Wazuh Manager for correlation and alerting.

- **Snort:** Monitors network traffic to identify potential intrusions, with alerts sent to Wazuh for comprehensive threat analysis.

### Troubleshooting
Ensure the necessary environment variables (e.g., WAZUH_AGENT_NAME) are set correctly before running the scripts to avoid installation issues or misconfigurations. Proper configurations will help ensure reliable and secure operation across different environments.



