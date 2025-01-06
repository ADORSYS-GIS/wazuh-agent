# Linux enrollment Guide
 This guide walks you through the process of enrolling a Linux system with the Wazuh Manager. By following these steps, you will install and configure necessary components, ensuring secure communication between the Wazuh Agent and the Wazuh Manager.

 ### Prerequisites

- **Administrator Privileges:** Ensure you have sudo access.

- **Internet Connectivity:** Verify that the system is connected to the internet.



## Step by step process 
### Step 1: Download and Run the Setup Script
   Download the setup script from the repository and run it to configure the Wazuh agent with the necessary parameters for secure communication with the Wazuh Manager.
   
   ```bash
   curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_MANAGER=events.wazuh.adorsys.team WAZUH_REGISTRATION_SERVER=register.wazuh.adorsys.team bash
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

   **5. Snort:**
   Adds network intrusion detection capabilities to monitor suspicious traffic.

   <img src="/Agent Enrollment/images/linux/Screenshot%20from%202024-12-16%2012-58-37.png" width="500" height="200">


### Step 2:
  #### 1. Generate the Enrollment URL
   Run the following command to start the enrollment process:

   ```bash
   sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2
   ```
   This command will generate a URL. Copy the link and paste it into your web browser.

 
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-26-25.png" width="500" height="180">

  #### 2. Authentication via browser

   - **i. Login:** You will be prompted to log in page,Log in using **Active  directories: `Adorsys GIS `or `adorsys GmbH & CO KG`**, which will  generate an authentication token using Keycloak.
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-14.png" width="400" height="300">

   - **ii. Two-Factor Authentication:** For first-time logins, authentication via an authenticator is required.
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-29-08.png" width="400" height="300">

   - **iii. Token generation:** After a successful authentication a token will be generated.
   
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-45.png" width="400" height="300">

  #### 3. Complete the Enrollment 
   Return to the command line and complete the enrollment process using the generated token.
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-30-06.png" width="600" height="250">

  #### 4. Reboot your Device
   Reboot your device to apply the changes. 

### Step 3: Validate the Installation
   After completing the agent enrollment, verify that the agent is properly connected and functioning:

  #### 1. Check the Agent Status:
   Look for the Wazuh icon in the system tray to confirm that the agent is running and connected.

  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 09-47-27.png" width="400" height="200">


  #### 2. Verify Agent Logs:
   Check the Wazuh agent logs to ensure there are no errors:

   ```bash
   sudo tail -f /var/ossec/logs/ossec.log
   ```
   Check the Wazuh agent logs to ensure there are no errors:
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2025-01-06 12-04-15.png" width="500" height="200">


  #### 3. Check Agent service
   Run the following command:
   ```bash
   sudo systemctl status wazuh-agent
   ``` 
  
   <img src="/Agent Enrollment/images/linux/Screenshot from 2025-01-06 12-04-56.png" width="500" height="200">


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
   ```bash
    $ yara -v 
    $ sudo ls -l /var/ossec/ruleset/yara/rules
   ``` 
    
   - Snort
   ```bash
    $ snort -V
   ```
   - Agent Status
   ```bash
    $ sudo /var/ossec/bin/wazuh-control status 
   ```

  **4. Installation Validation:**
   - Test registration successful
   - Logs reviewed for errors
   - Cleanup Completed

## Troubleshooting

- If the enrollment URL fails to generate, check internet connectivity and script permissions.

- For errors during authentication, ensure Active Directory credentials are correct and two-factor authentication is set up.

- Consult the Wazuh logs (/var/ossec/logs/ossec.log) for detailed error messages.

### Additional Resources
- [Wazuh Documentation](https://documentation.wazuh.com/current/user-manual/agent/index.html#wazuh-agent)