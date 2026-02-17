# Wazuh Agent Installation Runbook

This runbook provides step-by-step instructions for installing the Wazuh Agent on your machine. The installation process uses a verified bootstrap installer that ensures script integrity before execution.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
- [How Verification Works](#how-verification-works)
- [Post-Installation: Agent Enrollment](#post-installation-agent-enrollment)
- [Validation](#validation)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

---

## Overview

The Wazuh Agent installer automatically:

1. Downloads a checksums file from GitHub
2. Downloads the setup script
3. Verifies the SHA256 checksum matches
4. Only executes if verification passes
5. Installs all security components

**Components Installed:**
- Wazuh Agent - Endpoint monitoring
- OAuth2 Authentication Client - Secure enrollment
- Wazuh Agent Status - System tray health monitor
- Yara - Malware signature scanning
- Suricata or Snort - Network intrusion detection
- USB DLP Scripts - USB device control (Active Response)

---

## Prerequisites

### All Platforms
- Internet connectivity
- Administrator/sudo privileges
- Wazuh Manager address (provided by your security team)

### Linux
- `curl` installed (`sudo apt install -y curl` or equivalent)

### macOS
- Homebrew installed
- `curl` installed (`brew install curl`)

### Windows
- PowerShell 5.1 or later
- Run PowerShell as Administrator

---

## Installation Steps

### Linux

**Step 1: Open Terminal**

**Step 2: Set Environment Variable**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
```
> Replace `wazuh.your-company.com` with your actual Wazuh Manager address.

**Step 3: Run the Installer**
```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

**Optional: Install with Specific Options**
```bash
# With Suricata in IPS mode (detection + prevention)
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ips

# With Snort instead of Suricata
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -n

# With Trivy vulnerability scanner (for containers)
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -t

# Show all options
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -h
```

---

### macOS

**Step 1: Open Terminal**

**Step 2: Set Environment Variable**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
```

**Step 3: Run the Installer**
```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

**Optional: Install with Specific Options**
```bash
# With Suricata in IPS mode
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ips

# With Snort instead of Suricata
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -n
```

---

### Windows

**Step 1: Open PowerShell as Administrator**
- Right-click on PowerShell
- Select "Run as Administrator"

**Step 2: Set Execution Policy (First Time Only)**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
When prompted, respond with `A` (Yes to All).

**Step 3: Set Environment Variable**
```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
```

**Step 4: Run the Installer**
```powershell
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1 | iex
```

**Alternative: Download and Run with Options**
```powershell
# Download the installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1" -OutFile "$env:TEMP\Install.ps1"

# Run with Suricata
& "$env:TEMP\Install.ps1" -InstallSuricata

# Or run with Snort
& "$env:TEMP\Install.ps1" -InstallSnort

# Show help
& "$env:TEMP\Install.ps1" -Help
```

**Note for Windows:** During installation, a pop-up for GNU sed will appear. Follow the on-screen prompts to complete the installation.

---

## How Verification Works

The bootstrap installer protects you from tampered or malicious scripts:

```
┌─────────────────────────────────────────────────────────────────┐
│  You run: curl .../install.sh | bash                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Bootstrap script (install.sh) downloads                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Downloads checksums.sha256 from repository                 │
│     Contains expected hashes for all scripts                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Downloads scripts/setup-agent.sh                           │
│     (the full installation script)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Calculates SHA256 hash of downloaded script                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. VERIFICATION CHECK                                         │
│                                                                 │
│     ✓ Hash matches   → Proceed with installation               │
│     ✗ Hash mismatch  → STOP and show security warning          │
└─────────────────────────────────────────────────────────────────┘
```

**What You See on Success:**
```
[INFO] Wazuh Agent Bootstrap Installer
[INFO] ================================
[INFO] Downloading checksums...
[INFO] Downloading setup-agent.sh...
[INFO] Verifying script integrity...
[SUCCESS] Checksum verified successfully
[INFO] Executing setup-agent.sh...
```

**What You See if Tampering is Detected:**
```
[ERROR] Checksum verification FAILED!
[ERROR]   Expected: abc123def456...
[ERROR]   Got:      xyz789bad000...
[ERROR]
[ERROR] The downloaded file may have been tampered with.
[ERROR] Please report this to the security team immediately.
```

> **If you see a checksum failure:** DO NOT proceed. Contact your security team immediately.

---

## Post-Installation: Agent Enrollment

After installation completes, you must enroll the agent with the Wazuh Manager.

### Step 1: Generate Enrollment URL

**Linux:**
```bash
sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2
```

**macOS:**
```bash
sudo /Library/Ossec/bin/wazuh-cert-oauth2-client o-auth2
```

**Windows:**
```powershell
& 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe' o-auth2
```

This generates a URL. Copy it and open in your web browser.

### Step 2: Authenticate via Browser

1. **Login:** Use your Active Directory credentials (Adorsys GIS or adorsys GmbH & CO KG)
2. **Two-Factor Authentication:** Complete 2FA if prompted (first-time logins)
3. **Token Generation:** After authentication, a token is displayed

### Step 3: Complete Enrollment

Return to the terminal/PowerShell and paste the token when prompted.

### Step 4: Reboot

Reboot your device to apply all changes.

---

## Validation

After reboot, verify the installation was successful:

### Check Agent Status

**System Tray:** Look for the Wazuh icon - it should show "Active" and "Connected"

**Command Line:**

Linux:
```bash
sudo systemctl status wazuh-agent
```

macOS:
```bash
sudo /Library/Ossec/bin/wazuh-control status
```

Windows:
```powershell
Get-Service -Name "Wazuh"
```

### Check Logs

Linux:
```bash
sudo tail -20 /var/ossec/logs/ossec.log
```

macOS:
```bash
sudo tail -20 /Library/Ossec/logs/ossec.log
```

Windows:
```powershell
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
```

### Verify Security Tools

**Yara:**
```bash
yara -v
```

**Suricata/Snort:**
```bash
suricata -V
# or
snort -V
```

### Confirm with Admin

Contact your security administrator to confirm the agent appears in the Wazuh Manager dashboard.

---

## Troubleshooting

### "WAZUH_MANAGER is not set"

Set the environment variable before running the installer:
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
```

### Checksum Verification Failed

**This is a security warning. DO NOT proceed.**

1. Report to your security team immediately
2. Try downloading from a different network
3. Wait for confirmation before retrying

### Permission Denied

**Linux/macOS:**
```bash
# Run with sudo if needed
sudo bash -c 'export WAZUH_MANAGER="wazuh.your-company.com" && curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash'
```

**Windows:**
- Ensure PowerShell is running as Administrator

### Agent Not Connecting

1. Check internet connectivity
2. Verify the WAZUH_MANAGER address is correct
3. Check firewall rules (port 1514/1515 must be open)
4. Review logs for specific errors

### Enrollment URL Fails to Generate

1. Check internet connectivity
2. Verify the OAuth2 client was installed correctly
3. Check script permissions

---

## Uninstallation

### Linux/macOS

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.sh | sudo bash
```

Options:
- `-s` - Uninstall Suricata
- `-n` - Uninstall Snort

Reboot after uninstallation.

### Windows

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.ps1' -OutFile "$env:TEMP\uninstall-agent.ps1"
& "$env:TEMP\uninstall-agent.ps1" -UninstallSuricata
```

Use `-UninstallSnort` for Snort or `-UninstallSuricata` for Suricata.

Reboot after uninstallation.

### Remove from Wazuh Manager

Contact your security administrator to remove the agent from the Wazuh Manager database:
```bash
/var/ossec/bin/manage_agents -r <AGENT_ID>
```

---

## Additional Resources

- [Environment Variables Reference](ENVIRONMENT_VARIABLES.md)
- [Wazuh Official Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html)
- [Linux Enrollment Guide (with screenshots)](../Agent%20Enrollment/linux-agent.md)
- [macOS Enrollment Guide (with screenshots)](../Agent%20Enrollment/macos-agent.md)
- [Windows Enrollment Guide (with screenshots)](../Agent%20Enrollment/windows-agent.md)

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the agent logs
3. Contact your security team
4. Open an issue on the [GitHub repository](https://github.com/ADORSYS-GIS/wazuh-agent/issues)
