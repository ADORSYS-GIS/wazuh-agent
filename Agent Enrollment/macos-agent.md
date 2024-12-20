# MacOS enrollment Guide
 This guide walks you through the process of enrolling a MacOS system with the Wazuh Manager. By following these steps, you will install and configure necessary components, ensuring secure communication between the Wazuh Agent and the Wazuh Manager.

 ### Prerequisites

- **Administrator Privileges:** Ensure you have sudo access.

- **Internet Connectivity:** Verify that the system is connected to the internet.



## Step by step process 
### Step 1: Download and Run the Setup Script
   Download the setup script from the repository and run it to configure the Wazuh agent with the necessary parameters for secure communication with the Wazuh Manager.
   
   ```bash
   curl -SL --progress-bar https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.sh | WAZUH_MANAGER=events.wazuh.adorsys.team WAZUH_REGISTRATION_SERVER=register.wazuh.adorsys.team bash
   ```
   ### Step 2:
   #### 1. Generate the Enrollment URL
   Run the following command to start the enrollment process:

   ```bash
   sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2
   ```
   This command will generate a URL. Copy the link and paste it into your web browser.

 
  <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-26-25.png" width="600" height="200">

  #### 2. Authentication via browser

  - **i. Login:** You will be prompted to log in page,Log in using **Active  directories: `Adorsys GIS `or `adorsys GmbH & CO KG`**, which will  generate an authentication token using Keycloak.
  
<img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-14.png" width="600" height="200">

  - **ii. Two-Factor Authentication:** For first-time logins, authentication via an authenticator is required.
  
<img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-29-08.png" width="600" height="200">

  - **iii. Token generation:** After a successful authentication a token will be generated.
   
<img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-28-45.png" width="600" height="200">

  #### 3. Complete the Enrollment 
  Return to the command line and complete the enrollment process using the generated token.
  <img src="/Agent Enrollment/images/linux/Screenshot from 2024-12-20 08-30-06.png" width="600" height="200">

  #### 4. Reboot your Device
  Reboot your device to apply the changes. 