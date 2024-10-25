# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.8" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "master.dev.wazuh.adorsys.team" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.8.1-1" }
$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf" # Adjust for Windows
$TEMP_DIR = [System.IO.Path]::GetTempPath()

# Function to log messages with a timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp [$Level] $Message"
}

# Logging helpers
function Log-Info {
    param ([string]$Message)
    Log "INFO" $Message
}

function Log-Error {
    param ([string]$Message)
    Log "ERROR" $Message
}


# Step 0: Ensure dependencies (for Windows, equivalent would be checking for curl & jq installation)
function Install-Dependencies {
    try{
        Write-Host "Downloading and executing Dependencies Script..."

        $DependenciesUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/feat/3-Windows-Agent-Install-Script/scripts/deps.ps1"  # Update the URL if needed
        $DependenciesPath = "$env:TEMP\deps.ps1"

        # Download Wazuh agent installer script
        Invoke-WebRequest -Uri $DependenciesUrl -OutFile $DependenciesPath -ErrorAction Stop
        Write-Host "Dependencies script downloaded successfully."

        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $DependenciesPath -ErrorAction Stop
        Write-Host "Dependencies script executed successfully."
    }
    catch {
        Write-Host "Error during Dependencies installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the installer file if it exists
        if (Test-Path $DependenciesPath) {
            Remove-Item $DependenciesPath -Force
            Write-Host "Installer file removed."
        }
    }
}

# Step 1: Download and execute Wazuh agent script with error handling
function Install-WazuhAgent {
    try {
        Write-Host "Downloading and executing Wazuh agent script..."

        $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/main/scripts/install.ps1"  # Update the URL if needed
        $InstallerPath = "$env:TEMP\install.ps1"

        # Download Wazuh agent installer script
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent script downloaded successfully."

        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent script executed successfully."
    }
    catch {
        Write-Host "Error during Wazuh agent installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the installer file if it exists
        if (Test-Path $InstallerPath) {
            Remove-Item $InstallerPath -Force
            Write-Host "Installer file removed."
        }
    }
}


# Step 2: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    try {
        Write-Host "Downloading and executing wazuh-cert-oauth2-client script..."

        $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/heads/3-Windows-Agent-Install-Script/scripts/install.ps1"  # Update the URL if needed
        $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"

        # Download the wazuh-cert-oauth2-client installer script
        Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
        Write-Host "wazuh-cert-oauth2-client script downloaded successfully."

        #Supposed to remove the execution/ compare to .sh version
        # Execute the downloaded script with required parameters
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
        Write-Host "wazuh-cert-oauth2-client installed successfully."
    }
    catch {
        Write-Host "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the installer file if it exists
        if (Test-Path $OAuth2Script) {
            Remove-Item $OAuth2Script -Force
            Write-Host "Installer file removed."
        }
    }
}


# Step 3: Download and install YARA with error handling
function Install-Yara {
    try {
        Write-Host "Downloading and executing YARA installation script..."

        $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/heads/3-Windows-Agent-Install-Script/scripts/install.ps1"  # Update the URL if needed
        $YaraScript = "$env:TEMP\install.ps1"

        # Download the installation script
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        Write-Host "YARA installation script downloaded successfully."

        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
        Write-Host "YARA installed successfully."
    }
    catch {
        Write-Host "Error during YARA installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $YaraScript) {
            Remove-Item $YaraScript -Force
            Write-Host "Installer script removed."
        }
    }
}

# Step 4: Download and install Snort with error handling
function Install-Snort {
    try {
        Write-Host "Downloading and executing Snort installation script..."

        $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/windows/snort.ps1"  # Update the URL if needed
        $SnortScript = "$env:TEMP\snort.ps1"

        # Download the installation script
        Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
        Write-Host "Snort installation script downloaded successfully."

        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
        Write-Host "Snort installed successfully."
    }
    catch {
        Write-Host "Error during Snort installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $SnortScript) {
            Remove-Item $SnortScript -Force
            Write-Host "Installer script removed."
        }
    }
}

# Step 4: Download and install Wazuh Agent Status with error handling
function Install-AgentStatus {
    try {
        Write-Host "Downloading and executing Wazuh Agent Status installation script..."

        $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/heads/chore/issue-6/scripts/install.ps1"  # Update the URL if needed
        $AgentStatusScript = "$env:TEMP\install-agent-status.ps1"

        # Download the installation script
        Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
        Write-Host "Agent Status installation script downloaded successfully."

        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
        Write-Host "Agent Status installed successfully."
    }
    catch {
        Write-Host "Error during Agent Status installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $AgentStatusScript) {
            Remove-Item $AgentStatusScript -Force
            Write-Host "Installer script removed."
        }
    }
}




# Main Execution
Install-Dependencies
Install-WazuhAgent
Install-OAuth2Client
Install-Yara
Install-Snort
Install-AgentStatus