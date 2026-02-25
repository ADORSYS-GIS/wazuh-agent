# Linux Enrollment Guide

This guide walks you through the process of enrolling a Linux system with the Wazuh Manager. By following these steps, you will install and configure necessary components, ensuring secure communication between the Wazuh Agent and the Wazuh Manager.

## Prerequisites

- **Administrator Privileges:** Ensure you have sudo access.

- **Dependencies**: Have **curl** installed. You can install it with:

  ```bash
  sudo apt install -y curl
  ```

## Step by Step Process

### Step 1: Download and Run the Verified Installer

The installer automatically verifies script integrity using SHA256 checksums before execution.

```bash
# Set your Wazuh Manager address
export WAZUH_MANAGER="wazuh.your-company.com"

# Run the verified installer
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

**What happens:**
1. Downloads the checksums file
2. Downloads the setup script
3. Verifies the SHA256 checksum matches
4. Only executes if verification passes

#### Installation Options

**Default installation (Suricata IDS mode):**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash
```

**With Suricata in IPS mode (detection + prevention):**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -s ips
```

**With Snort instead of Suricata:**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -n
```

**With Trivy for container vulnerability scanning:**
```bash
export WAZUH_MANAGER="wazuh.your-company.com"
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -t
```

**Show all options:**
```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.sh | bash -s -- -h
```

#### Components Installed by the Script:

**1. Wazuh Agent:**
Monitors your endpoint and sends data to the Wazuh Manager.
The agent is installed and configured to connect to the specified manager (WAZUH_MANAGER).

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-11-23.png" width="500" height="200">

**2. OAuth2 Authentication Client:** Adds certificate-based OAuth2 authentication for secure communications.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-12-06.png" width="500" height="200">

**3. Wazuh Agent Status:** Provides real-time health and connection status of the agent.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-13-06.png" width="500" height="200">

**4. Yara:** Enables advanced file-based malware detection by integrating Yara rules into Wazuh.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-14-00.png" width="500" height="200">

**5. Suricata (or Snort):**
Adds network intrusion detection capabilities to monitor suspicious traffic.

   <img src="/Agent Enrollment/images/linux/Screenshot%20from%202024-12-16%2012-58-37.png" width="500" height="200">

**6. USB DLP Scripts:**
Active Response scripts for USB device control (mass storage blocking, BadUSB detection).


### Step 2: Enroll Agent to Manager

#### 1. Generate the Enrollment URL

Run the following command to start the enrollment process:

```bash
sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2
```

This command will generate a URL. Copy the link and paste it into your web browser.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-26-25.png" width="500" height="180">

#### 2. Authentication via browser

- **i. Login:** You will be prompted to log in page, Log in using **Active directories: `Adorsys GIS` or `adorsys GmbH & CO KG`**, which will generate an authentication token using Keycloak.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-14.png" width="400" height="300">

- **ii. Two-Factor Authentication:** For first-time logins, authentication via an authenticator is required.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-29-08.png" width="400" height="300">

- **iii. Token generation:** After a successful authentication, a token will be generated. Copy the token and return to the command line.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-45.png" width="400" height="300">

#### 3. Complete the Enrollment

Return to the command line, paste the token, and follow the prompts to complete the enrollment process.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-30-06.png" width="600" height="250">

#### 4. Reboot your Device

Reboot your device to apply the changes.


### Step 3: Validate the Installation

After completing the agent enrollment, verify that the agent is properly connected and functioning:

#### 1. Check the Agent Status:

Look for the Wazuh icon in the system tray to confirm that the agent is running and connected.

   <img src="/Agent Enrollment/images/linux/Screenshot from 2025-01-10 11-56-49.png" width="400" height="200">

#### 2. Validate Other Tools Installation

- YARA

```bash
yara -v
sudo ls -l /var/ossec/ruleset/yara/rules
```

- Suricata (or Snort)

```bash
suricata -V
# or
snort -V
```

- USB DLP Scripts

```bash
ls -la /var/ossec/active-response/bin/disable-usb-storage.sh
ls -la /var/ossec/active-response/bin/alert-usb-hid.sh
```

#### 3. Check the Wazuh Manager Dashboard:

Ping an admin for confirmation that the agent appears in the Wazuh Manager dashboard.


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

- If the **wazuh agent status app** doesn't show you as `Active` and `Connected`, check the logs for examination

   ```bash
   sudo tail -f /var/ossec/logs/ossec.log
   ```


## Uninstall Agent

### 1. Uninstall on User's Machine:

- Use this command to uninstall

  ```bash
  curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall-agent.sh | sudo bash
  ```
  **NB:** Use the `-n` option for **Snort** or the `-s` for **Suricata**. For Suricata, you do not need to specify a mode; the uninstall script will remove all Suricata components regardless of mode.

- Reboot the user's machine

### 2. Remove Agent from Wazuh Manager:

Shell into the **master manager node** and use this command to remove agent from wazuh manager's database

  ```bash
  /var/ossec/bin/manage_agents -r <AGENT_ID>
  ```


### Additional Resources

- [Wazuh Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html#wazuh-agent)
- [Environment Variables Reference](/docs/ENVIRONMENT_VARIABLES.md)
