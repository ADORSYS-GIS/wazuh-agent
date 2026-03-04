# Windows Enrollment Guide

This guide walks you through the process of enrolling a Windows system with the Wazuh Manager. By following these steps, you will install and configure necessary components, ensuring secure communication between the Wazuh Agent and the Wazuh Manager.

## Prerequisites

- **Internet Connectivity:** Verify that the system is connected to the internet.
- **Administrator Privileges:** Ensure you open PowerShell in Administrator Mode

## Step by Step Process

### Step 0: Set Execution Policy

Set Execution Policy to Remote Signed to allow PowerShell scripts to run.

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

When prompted, respond with A [Yes to All], to enable the execution policy.

### Step 1: Download and Run the Verified Installer

The installer automatically verifies script integrity using SHA256 checksums before execution.

```powershell
# Set your Wazuh Manager address
$env:WAZUH_MANAGER = "wazuh.your-company.com"

# Run the verified installer
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1 | iex
```

**What happens:**
1. Downloads the checksums file
2. Downloads the setup script
3. Verifies the SHA256 checksum matches
4. Only executes if verification passes

#### Alternative: Download and Run with Options

```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1" -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1" -InstallSuricata
```

**With Snort instead of Suricata:**
```powershell
$env:WAZUH_MANAGER = "wazuh.your-company.com"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1" -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1" -InstallSnort
```

**Show all options:**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1" -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1" -Help
```

### Step 2: GNU Sed Installation

During the dependency installation, a pop-up for GNU sed installation will appear.

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-11.png">


**Please choose the options shown in the images below to install GNU sed**

   #### i. Accept GNU's license agreement
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-16.png">

   #### ii. Install sed in the default location (C:\Program Files (x86)\GnuWin32)
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-20.png">

   #### iii. Select Full Installation with both binaries and documentation
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-24.png">

   #### iv. Click Next
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-28.png">

   #### v. Uncheck both additional icon options
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-20 13-47-35.png">

   #### vi. GNU Sed installation complete
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-21 16-29-27.png">

**The installation will now continue**
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-36-39.png">


### Step 3: Suricata/Snort Installation

For Snort, a pop-up window will appear for installation. Follow these steps:

   #### i. Click OK to continue and install Npcap
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-35-09.png">

   #### ii. Click Finish once Npcap installation is complete
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-35-15.png">

   #### iii. Installation will continue
   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 13-39-23.png">


### Step 4: Restart PowerShell

**Important:** Restart your PowerShell terminal in Administrator mode. The installation will not work properly if this step is skipped.


### Step 5: Enroll Agent with cert-oauth2

#### 1. Generate the Enrollment URL

Run the following command to start the enrollment process:

```powershell
& 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe' o-auth2
```

This command will generate a URL. Copy the link and paste it into your web browser.


#### 2. Authentication via browser

- **i. Login:** Log in using **Active directories: `Adorsys GIS` or `adorsys GmbH & CO KG`**, which will generate an authentication token using Keycloak.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-14.png">

- **ii. Two-Factor Authentication:** For first-time logins, authentication via an authenticator is required.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-29-08.png">

- **iii. Token generation:** After successful authentication, a token will be generated.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-45.png">


#### 3. Complete the Enrollment

Return to the command line and complete the enrollment process using the generated token.


#### 4. Reboot your Device

Reboot your device to apply the changes.


### Step 6: Validate the Installation

After completing the agent enrollment, verify that the agent is properly connected and functioning:

#### 1. Check the Agent Status:

Look for the Wazuh icon in the system tray to confirm that the agent is running and connected.

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 14-44-53.png">


#### 2. Verify Agent Logs:

Check the Wazuh agent logs to ensure there are no errors:

```powershell
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 20
```


#### 3. Check Agent Service:

```powershell
Get-Service -Name "Wazuh"
```

   <img src="/Agent Enrollment/images/windows/Screenshot from 2025-01-07 14-54-19.png">


#### 4. Validate USB DLP Scripts:

```powershell
Test-Path 'C:\Program Files (x86)\ossec-agent\active-response\bin\disable-usb-storage.ps1'
Test-Path 'C:\Program Files (x86)\ossec-agent\active-response\bin\alert-usb-hid.ps1'
```


#### 5. Check the Wazuh Manager Dashboard:

Ping an admin for confirmation that the agent appears in the Wazuh Manager dashboard.


## Components Installed

### Dependencies
- [Visual C++ Redistributable](https://www.microsoft.com/en-us/download/details.aspx?id=48145)
- [GNU sed](https://www.gnu.org/software/sed/)
- [jq](https://jqlang.github.io/jq/)

### Security Components
- **Wazuh Agent** - Endpoint monitoring and data collection
- **OAuth2 Authentication Client** - Certificate-based secure communications
- **Wazuh Agent Status** - Real-time health monitoring
- **Yara** - Malware signature scanning
- **Suricata/Snort** - Network intrusion detection
- **USB DLP Scripts** - USB device control (Active Response)


## Troubleshooting

### Checksum Verification Failed

If you see "Checksum verification FAILED":
- **Do NOT proceed** - this could indicate tampering
- Report to your security team immediately
- Try downloading from a different network
- Contact IT support

### Other Issues

- If the enrollment URL fails to generate, check internet connectivity and script permissions.

- For errors during authentication, ensure Active Directory credentials are correct and two-factor authentication is set up.

- Check Wazuh logs for detailed error messages:
  ```powershell
  Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 50
  ```

### Validation Commands

- YARA
```powershell
yara64 -v
```

- Suricata/Snort
```powershell
suricata -V
# or
snort -V
```

- Agent Status
```powershell
Get-Service -Name "Wazuh"
```


## Uninstallation Guide

### Step 1: Download and Run the Uninstall Script

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.ps1' `
  -UseBasicParsing -OutFile "$env:TEMP\uninstall-agent.ps1"
& "$env:TEMP\uninstall-agent.ps1" -UninstallSuricata
```

**NB:** Use `-UninstallSnort` for **Snort** or `-UninstallSuricata` for **Suricata**.

- Reboot the user's machine


### Additional Resources

- [Wazuh Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html#wazuh-agent)
- [Environment Variables Reference](/docs/ENVIRONMENT_VARIABLES.md)
