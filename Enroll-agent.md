## Wazuh Agent Enrollment Guide

This guide provides step-by-step instructions for enrolling Wazuh agents, ensuring seamless integration for monitoring and security purposes. It also installs and integrates additional tools like Yara and Snort for enhanced security capabilities.

### 1. Introduction

Wazuh agents collect security data from your systems and communicate with the Wazuh Manager for analysis. This guide walks you through the process of enrolling Wazuh agents to ensure they are properly connected to the manager and functioning as intended.

**Supported Platforms:**

- Linux

- macOS

- Windows

## Step by step process 
### Step 1:
Download the setup script from the repository and run the script:
#### For Linux and MacOS
 ```bash
curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_MANAGER=events.wazuh.adorsys.team WAZUH_REGISTRATION_SERVER=register.wazuh.adorsys.team bash
 ```


### Components Installed by the Script

**1. Wazuh Agent:**
Monitors your endpoint and sends data to the Wazuh Manager.
The agent is installed and configured to connect to the specified manager (WAZUH_MANAGER).
![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-08-20.png)


**2. OAuth2 Authentication Client:** Adds certificate-based OAuth2 authentication for secure communications.

![Successful installaton](/images/Screenshot%20from%202024-12-16%2012-57-12.png)

**3. Wazuh Agent Status:** Provides real-time health and connection status of the agent.

![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-00-01.png)

**4. Yara:** Enables advanced file-based malware detection by integrating Yara rules into Wazuh.
![Successful installaton](/images/Screenshot%20from%202024-12-16%2012-59-15.png)

**5. Snort:**
Adds network intrusion detection capabilities to monitor suspicious traffic.

![Successful installaton](/images/Screenshot%20from%202024-12-16%2012-58-37.png)


### Step 2:
#### 1. Enroll the agent to the wazuh prod cluster, run the enrollment command:

```bash
sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2
```
This command will generate a URL. Copy the link and paste it into your web browser.

![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-14-06.png)

#### 2. Authentication
For first-time logins, authentication via an authenticator is required.
![Successful installaton](/images/Screenshot%20from%202024-12-16%2016-03-47.png)

You will be prompted to log in page,Log in using **Active directories: `Adorsys GIS `or `adorsys GmbH & CO KG`**, which will generate an authentication token using Keycloak.

![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-15-14.png)

![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-15-27.png)

#### 3. Complete the Enrollment 
Once the token is generated, you can return to the command line to complete the enrollment process.
![Successful installaton](/images/Screenshot%20from%202024-12-16%2013-17-10.png)

### Step 3: Validation
After completing the agent enrollment, verify that the agent is properly connected and functioning:

#### 1. Check the Agent Status:
Check the system tray icon on your screen and click on the Wazuh icon to confirm that the agent is running and connected

![icon image](/images/Screenshot%20from%202024-12-16%2013-01-32.png)


#### 2. Verify Agent Logs:
Check the Wazuh agent logs to ensure there are no errors or issues with the enrollment:

```bash
sudo tail -f /var/ossec/logs/ossec.log
```
Look for any log entries indicating successful communication with the Wazuh Manager or any error messages that might need attention.

![icon image](/images/Screenshot%20from%202024-12-16%2016-22-18.png)


#### 3. Check the wazuh agent status
Run the following command:
```bash
sudo systemctl status wazuh-agent
``` 
![icon image](/images/Screenshot%20from%202024-12-16%2016-19-46.png)


#### 4. Check the Wazuh Manager Dashboard:
Ping an admin for confirmation that the agent appears in the Wazuh Manager dashboard.


### Step 4:
#### Checklist of elements to be installed and configured at agent enrollment 
**1. Pre-Requisites:**
- Supported OS confirmed
- Internet connectivity checked

 **2. Downloaded Scripts:**
- Dependencies script
- Installation scripts (Wazuh Agent, OAuth2, YARA, Snort, Agent Status):
  - Dependencies Installed
  - Wazuh Agent Installed and Configured
  - OAuth2 Client Installed

**3. Tools Installed:**
 - YARA
 - Snort
 - Agent Status

**4. Installation Validation:**
 - Test registration successful
 - Logs reviewed for errors
 - Cleanup Completed
