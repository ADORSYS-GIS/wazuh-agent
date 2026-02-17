# Wazuh Agent Setup

[![CI/CD Pipeline](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/release.yaml/badge.svg?branch=main)](https://github.com/ADORSYS-GIS/wazuh-agent/actions/workflows/release.yaml)

This repository provides an automated, **verified** setup script for installing the Wazuh Agent along with essential security tools. The installer verifies script integrity using SHA256 checksums before execution.

## Key Features

- **Verified Downloads:** SHA256 checksum verification protects against tampering
- **Automated Installation:** One-command setup of Wazuh agent and all dependencies
- **Cross-Platform Support:** Compatible with Linux, macOS, and Windows
- **Security Tools Integration:** Pre-configured with Yara and Suricata/Snort for enhanced threat detection
- **USB DLP Protection:** Active Response scripts for USB device control

## Supported Operating Systems

| Platform | Versions |
|----------|----------|
| **Linux** | Ubuntu, Debian, RHEL, CentOS, Alpine, openSUSE |
| **macOS** | Intel (x86_64) and Apple Silicon (arm64) |
| **Windows** | Windows 10/11, Windows Server 2016+ |

---

## Quick Start

### Linux / macOS

```bash
# Set your Wazuh Manager address
export WAZUH_MANAGER="wazuh.your-company.com"

# Run the verified installer
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

**With options:**
```bash
# Install with Suricata in IPS mode
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ips

# Install with Snort instead of Suricata
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -n

# Install with Trivy vulnerability scanner
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ids -t
```

### Windows (PowerShell)

```powershell
# Set your Wazuh Manager address
$env:WAZUH_MANAGER = "wazuh.your-company.com"

# Run the verified installer
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1 | iex
```

**Or download and run with options:**
```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1" -OutFile Install.ps1
.\Install.ps1 -InstallSuricata
```

---

## How Verification Works

The installer automatically:

1. Downloads `checksums.sha256` from the repository
2. Downloads the setup script
3. Verifies the SHA256 checksum matches
4. Only executes if verification passes

```
┌─────────────────────────────────────────────────────────┐
│                  VERIFICATION FLOW                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  You run: curl .../install.sh | bash                    │
│                    │                                     │
│                    ▼                                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 1. Download checksums.sha256                     │   │
│  │ 2. Download setup-agent.sh                       │   │
│  │ 3. Calculate SHA256 of downloaded script         │   │
│  │ 4. Compare with expected checksum                │   │
│  │                                                   │   │
│  │    ✓ Match → Execute script                      │   │
│  │    ✗ Mismatch → Abort + Alert                    │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Installation Options

### Command Line Options (Linux/macOS)

| Option | Description |
|--------|-------------|
| `-s ids` | Install Suricata in IDS mode (detection only) |
| `-s ips` | Install Suricata in IPS mode (detection + prevention) |
| `-n` | Install Snort instead of Suricata |
| `-t` | Also install Trivy vulnerability scanner |
| `-h` | Show help message |

### PowerShell Parameters (Windows)

| Parameter | Description |
|-----------|-------------|
| `-InstallSuricata` | Install Suricata as NIDS (default) |
| `-InstallSnort` | Install Snort as NIDS |
| `-SkipVerify` | Skip checksum verification (not recommended) |
| `-Help` | Show help message |

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WAZUH_MANAGER` | **Yes** | `wazuh.example.com` | Wazuh Manager hostname or IP |
| `WAZUH_AGENT_VERSION` | No | `4.13.1-1` | Wazuh Agent version |
| `WAZUH_AGENT_NAME` | No | `$(hostname)` | Agent registration name |

See [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) for the complete reference.

---

## What Gets Installed

### Core Components (Always)
- **Wazuh Agent** - Endpoint monitoring and data collection
- **Wazuh Cert OAuth2** - Certificate-based authentication
- **Wazuh Agent Status** - Agent health monitoring
- **Yara** - Malware signature scanning
- **USB DLP Scripts** - Active Response for USB device control

### Network IDS (Choose One)
- **Suricata** (default) - IDS/IPS with multi-threading
- **Snort** - Classic lightweight IDS

### Optional
- **Trivy** - Container vulnerability scanning

---

## Detailed Enrollment Guides

For step-by-step instructions with screenshots:

- [Linux Enrollment Guide](Agent%20Enrollment/linux-agent.md)
- [macOS Enrollment Guide](Agent%20Enrollment/macos-agent.md)
- [Windows Enrollment Guide](Agent%20Enrollment/windows-agent.md)

---

## Scripts Overview

| Script | Platform | Description |
|--------|----------|-------------|
| `install.sh` | Linux/macOS | **Bootstrap installer** - downloads, verifies, executes |
| `Install.ps1` | Windows | **Bootstrap installer** - downloads, verifies, executes |
| `scripts/setup-agent.sh` | Linux/macOS | Full agent setup with all components |
| `scripts/setup-agent.ps1` | Windows | Full agent setup with all components |
| `scripts/install.sh` | Linux/macOS | Core Wazuh agent installation only |
| `scripts/install.ps1` | Windows | Core Wazuh agent installation only |
| `scripts/deps.sh` | Linux/macOS | Dependency installation |
| `scripts/deps.ps1` | Windows | Dependency installation |
| `scripts/uninstall-agent.sh` | Linux/macOS | Complete uninstallation |
| `scripts/uninstall-agent.ps1` | Windows | Complete uninstallation |

---

## Security Features

### USB Data Loss Prevention

The installer deploys Active Response scripts that:
- **Block USB mass storage** devices (prevents data exfiltration)
- **Detect BadUSB/Rubber Ducky** attacks (HID device monitoring)
- **Collect forensic evidence** for security analysis

MITRE ATT&CK Coverage:
- T1052.001: Exfiltration Over Physical Medium
- T1200: Hardware Additions

### Integrity Verification

All downloaded components are verified using SHA256 checksums:
- Protects against man-in-the-middle attacks
- Detects compromised or tampered files
- Ensures you run exactly what was released

---

## Troubleshooting

### Common Issues

**"WAZUH_MANAGER is not set"**
```bash
export WAZUH_MANAGER="your-manager-address.com"
```

**Checksum verification failed**
- This could indicate tampering - do NOT proceed
- Report to your security team
- Try downloading from a different network

**Permission denied**
```bash
# Linux/macOS: Run with sudo
sudo bash install.sh

# Windows: Run PowerShell as Administrator
```

### Logs Location

| Platform | Log Path |
|----------|----------|
| Linux | `/var/ossec/logs/ossec.log` |
| macOS | `/Library/Ossec/logs/ossec.log` |
| Windows | `C:\Program Files (x86)\ossec-agent\ossec.log` |

---

## Uninstallation

### Linux/macOS
```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.sh | sudo bash
```

### Windows (PowerShell as Admin)
```powershell
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.ps1 | iex
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License.
