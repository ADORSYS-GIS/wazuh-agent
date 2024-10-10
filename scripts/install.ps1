# Set strict mode for script execution
Set-StrictMode -Version Latest

param (
    [string]$WAZUH_AGENT_VERSION = "4.8.1-1",  # Default version
    [string]$WAZUH_MANAGER = "master.dev.wazuh.adorsys.team",                   # Wazuh manager IP or hostname
    [string]$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf"  # Default configuration path
)

# Function to format log messages
function Format-LogMessage {
    param (
        [string]$Level,
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp [$Level] $Message"
}

# Logging helpers
function Log-Info {
    param ([string]$Message)
    Write-Host (Format-LogMessage -Level "INFO" -Message $Message)
}

function Log-Error {
    param ([string]$Message)
    Write-Host (Format-LogMessage -Level "ERROR" -Message $Message) -ForegroundColor Red
}

# Validate WAZUH_MANAGER
if (-not $WAZUH_MANAGER) {
    Log-Error "WAZUH_MANAGER is required"
    exit 1
}

# Validate OSSEC_CONF_PATH
if (-not (Test-Path $OSSEC_CONF_PATH)) {
    Log-Error "OSSEC configuration file not found at $OSSEC_CONF_PATH"
    exit 1
}

# Import GPG Key for Wazuh repository
function Import-Keys {
    Log-Info "Importing Wazuh GPG key and setting up the repository for Windows"
    $WazuhKeyUrl = "https://packages.wazuh.com/key/GPG-KEY-WAZUH"
    $TEMP_DIR = [System.IO.Path]::GetTempPath()

    # Download the GPG key
    Invoke-WebRequest -Uri $WazuhKeyUrl -OutFile "$TEMP_DIR\WazuhGPGKey.asc"
    Log-Info "Wazuh GPG key downloaded successfully."
}

# Install Wazuh agent on Windows
function Install-WazuhAgent {
    Log-Info "Installing Wazuh agent version $WAZUH_AGENT_VERSION on Windows"
    $TEMP_DIR = [System.IO.Path]::GetTempPath()

    # Download the Wazuh Agent installer
    $Arch = if ([System.Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
    $InstallerUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"
    $InstallerPath = "$TEMP_DIR\wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"

    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
    if ($?) {
        Log-Info "Wazuh agent installer downloaded to $InstallerPath"
    } else {
        Log-Error "Failed to download Wazuh agent installer from $InstallerUrl"
        exit 1
    }

    # Install the Wazuh Agent MSI package
    Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" /quiet /norestart" -Wait
    if ($?) {
        Log-Info "Wazuh agent installed successfully."
    } else {
        Log-Error "Failed to install Wazuh agent."
        exit 1
    }
}

# Configure Wazuh agent by setting the manager IP in the ossec.conf file
function Configure-Agent {
    Log-Info "Configuring Wazuh manager IP in $OSSEC_CONF_PATH"
    
    # Modify the ossec.conf to include the Wazuh manager IP
    (Get-Content $OSSEC_CONF_PATH) -replace 'MANAGER_IP', $WAZUH_MANAGER | Set-Content $OSSEC_CONF_PATH
    Log-Info "Wazuh manager IP configured successfully."
}

# Start Wazuh agent service
function Start-WazuhAgentService {
    Log-Info "Starting Wazuh agent service on Windows"
    
    # Check if the service exists before starting it
    if (Get-Service -Name 'wazuh-agent' -ErrorAction SilentlyContinue) {
        Start-Service -Name 'wazuh-agent'
        if ($?) {
            Log-Info "Wazuh agent started successfully."
        } else {
            Log-Error "Failed to start Wazuh agent service."
            exit 1
        }
    } else {
        Log-Error "Wazuh agent service does not exist."
        exit 1
    }
}

# Clean up temporary files
function Clean-Up {
    Log-Info "Cleaning up temporary files."
    $TEMP_DIR = [System.IO.Path]::GetTempPath()
    Remove-Item -Path "$TEMP_DIR\WazuhGPGKey.asc" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$TEMP_DIR\wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi" -Force -ErrorAction SilentlyContinue
    Log-Info "Temporary files cleaned up."
}

# Call the functions
Import-Keys
Install-WazuhAgent
Configure-Agent
Start-WazuhAgentService
Clean-Up
