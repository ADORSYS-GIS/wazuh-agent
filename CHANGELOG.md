# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0](https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.6.0...v1.7.0) (2026-02-20)


### Features

* add USB DLP Active Response scripts ([08767bc](https://github.com/ADORSYS-GIS/wazuh-agent/commit/08767bc9967f3e0d799224f2aeebc7d50aa5c706))
* add verified bootstrap installer with SHA256 checksum verification ([c345771](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c345771e8d1a5edc8ed232f82f37c2448fa95459))
* add version compatibility matrix and automatic changelog generation ([d9ab49f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d9ab49fa1ae9b98deb61e7b7a3ebbb75ee9c7e76))
* integrate pre update notification from wazuh agent status ([1a631ce](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1a631ce43cc10698edf647528f6ef6b11e09a177))
* integrate Renovate for automatic dependency updates ([fb81930](https://github.com/ADORSYS-GIS/wazuh-agent/commit/fb81930964fbde0acd12d9f77b49b99d2292db98))
* **linux agent:** added automatic config conflict resolution to install script ([2919ff3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2919ff356989a8ffc5e4bf6c00df5cd64c7f83a1))
* **linux agent:** added automatic config conflict resolution to install script ([0576232](https://github.com/ADORSYS-GIS/wazuh-agent/commit/057623299f8ec2de59d63a4954086f563c78f773))
* **release:** add pull request trigger and add job steps to test install and setup-agent scripts on linux/macos in release workflow ([f36d57e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f36d57e57538a0779c56872b0919113346a02687))


### Bug Fixes

* add OSSEC_LOG_PATH variable and improve logging messages in install script ([2431031](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2431031b3c7a854d144309bad80730576918dd70))
* address P0 security and CI gaps ([81804fb](https://github.com/ADORSYS-GIS/wazuh-agent/commit/81804fb59144c9c31cef243890b9d8921172a53f))
* address P0 security and CI gaps ([bedbd42](https://github.com/ADORSYS-GIS/wazuh-agent/commit/bedbd42435090652e6d258feeeb567c878fe01e5))
* correct URL typo in uninstall-agent.sh, reorder variables in setup-agent.ps1, and update help text to use variable values ([c6fbcd8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c6fbcd812b92e080af046952a41a53daadd7dfd0))
* pass WAZUH_MANAGER environment variable to install-wazuh-agent-status script ([99149e8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/99149e8461fe1975a04a03178cfcb4b09615ffb0))
* remove Create-Upgrade-Script function and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([ffcbf7f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ffcbf7f82c7ac9b5a3d77615ad5d87848954db23))
* remove creation of adorsys-update script and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([e3669f5](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e3669f57c86dcbe7aed1cf4adc978ee376ff35ec))
* **uninstall:** update script to completely purge after wazuh agent uninstallation on linux ([33c4918](https://github.com/ADORSYS-GIS/wazuh-agent/commit/33c4918d9f0a645309bb02797fd5901d85c64f98))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([388b99d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/388b99d798914cfc8e6ae1b41c18198a68b92fc4))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([00c1803](https://github.com/ADORSYS-GIS/wazuh-agent/commit/00c1803e0fd5653bd6fb1387acf07691437bfc17))
* update install script URL for Wazuh agent status to use user-main branch ([6a4e0c8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6a4e0c8448cf11bf0dddc42efac80c49a5cf0eb1))
* update install script URL for Wazuh agent status to use version tag ([8d9e06e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8d9e06edc8a7e549a76300bbebd91df70767575b))
* update uninstall script to use 'apt remove --purge' for Wazuh agent removal ([820dd2b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/820dd2beedde9d80a5c35cd3a56ecf24a2ff9996))
* update uninstall script to use 'apt-get purge' for Wazuh agent removal ([0f5d27d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0f5d27da07fd3f10c3ad3422395641bdc871b967))
* update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in uninstall scripts ([a431202](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a4312024649e3aa9801205b7117474dd3967740b))
* use PAT for release-please to bypass org restrictions ([c7d449c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c7d449c77e215923393291dc34432f6ab7c0b534))


### Documentation

* add installation runbook with step-by-step instructions ([6ddd919](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6ddd919ea1342a2b2866d5416ba63f719e294a67))

## [Unreleased]

### Added
- Verified bootstrap installer with SHA256 checksum verification
- Installation runbook documentation
- Version compatibility matrix (`versions.json`)
- Automatic changelog generation

### Changed
- Updated installation documentation for all platforms

### Security
- Download verification protects against MITM attacks

---

## [1.6.0] - 2026-02-15

### Added
- USB-DLP Active Response scripts for data exfiltration prevention
- MITRE ATT&CK T1052.001 (Exfiltration Over Physical Medium) coverage
- MITRE ATT&CK T1200 (Hardware Additions) coverage
- Trivy vulnerability scanner integration (`-t` flag)
- Suricata IPS mode support (`-s ips` flag)
- Environment variables reference documentation

### Changed
- Improved cross-platform installation scripts
- Enhanced error handling in setup scripts

### Fixed
- Non-interactive Debian package upgrades

---

## [1.5.0] - 2026-01-20

### Added
- OAuth2 certificate-based authentication
- Wazuh Agent Status system tray application
- Yara malware scanning integration
- Snort/Suricata NIDS selection

### Changed
- Modular script architecture
- Platform-specific enrollment guides with screenshots

---

## [1.4.0] - 2025-12-15

### Added
- Initial cross-platform support (Linux, macOS, Windows)
- Automated Wazuh Agent installation
- Basic documentation

---

[Unreleased]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/ADORSYS-GIS/wazuh-agent/releases/tag/v1.4.0
