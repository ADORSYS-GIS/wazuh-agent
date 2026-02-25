# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
