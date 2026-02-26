# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0](https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.6.0...v1.7.0) (2026-02-26)


### Features

* integrate pre update notification from wazuh agent status ([1a631ce](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1a631ce43cc10698edf647528f6ef6b11e09a177))
* **release:** add pull request trigger and add job steps to test install and setup-agent scripts on linux/macos in release workflow ([f36d57e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f36d57e57538a0779c56872b0919113346a02687))


### Bug Fixes

* add OSSEC_LOG_PATH variable and improve logging messages in install script ([2431031](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2431031b3c7a854d144309bad80730576918dd70))
* change cert-oauth2 install script branch ([359bde8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/359bde8b6b32216b2aa5204c8b3373307b1c932d))
* correct release-please RC config and manifest baseline ([7838123](https://github.com/ADORSYS-GIS/wazuh-agent/commit/78381234ff11e86e4c53599f0fa56db34493d543))
* correct release-please RC config, manifest baseline, and target branch ([ed9ba6a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ed9ba6a8dfa1a52ee8ff2f6a90349017f8bd1a02))
* correct URL typo in uninstall-agent.sh, reorder variables in setup-agent.ps1, and update help text to use variable values ([c6fbcd8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c6fbcd812b92e080af046952a41a53daadd7dfd0))
* improve macOS uninstall script to remove package receipt files ([219dcf2](https://github.com/ADORSYS-GIS/wazuh-agent/commit/219dcf2fef822bd4deb3b6459c5b7bbbb194b5ee)), closes [#101](https://github.com/ADORSYS-GIS/wazuh-agent/issues/101)
* pass WAZUH_MANAGER environment variable to install-wazuh-agent-status script ([99149e8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/99149e8461fe1975a04a03178cfcb4b09615ffb0))
* remove Create-Upgrade-Script function and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([ffcbf7f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ffcbf7f82c7ac9b5a3d77615ad5d87848954db23))
* remove creation of adorsys-update script and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([e3669f5](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e3669f57c86dcbe7aed1cf4adc978ee376ff35ec))
* **setup-agent.ps1:** change agent status script url to reference v0.3.3-user tag ([cbcb749](https://github.com/ADORSYS-GIS/wazuh-agent/commit/cbcb7495d6cbe25b34ca712e11bf4f772c75b9ea))
* **uninstall.ps1:** change  wazuh-agent to v4.12.0-1 ([0106a18](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0106a18577d1fa481e90ba2343d625499332de9e))
* **uninstall:** update script to completely purge after wazuh agent uninstallation on linux ([33c4918](https://github.com/ADORSYS-GIS/wazuh-agent/commit/33c4918d9f0a645309bb02797fd5901d85c64f98))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([388b99d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/388b99d798914cfc8e6ae1b41c18198a68b92fc4))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([00c1803](https://github.com/ADORSYS-GIS/wazuh-agent/commit/00c1803e0fd5653bd6fb1387acf07691437bfc17))
* update install script URL for Wazuh agent status to use user-main branch ([6a4e0c8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6a4e0c8448cf11bf0dddc42efac80c49a5cf0eb1))
* update install script URL for Wazuh agent status to use version tag ([8d9e06e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8d9e06edc8a7e549a76300bbebd91df70767575b))
* update uninstall script to use 'apt remove --purge' for Wazuh agent removal ([820dd2b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/820dd2beedde9d80a5c35cd3a56ecf24a2ff9996))
* update uninstall script to use 'apt-get purge' for Wazuh agent removal ([0f5d27d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0f5d27da07fd3f10c3ad3422395641bdc871b967))
* update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in uninstall scripts ([a431202](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a4312024649e3aa9801205b7117474dd3967740b))

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
