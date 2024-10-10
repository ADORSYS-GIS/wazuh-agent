# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables
$LOG_LEVEL = $env:LOG_LEVEL -or 'INFO'
$OSSEC_CONF_PATH = $env:OSSEC_CONF_PATH -or "C:\Program Files (x86)\ossec-agent\ossec.conf"
$WAZUH_MANAGER = $env:WAZUH_MANAGER -or 'master.dev.wazuh.adorsys.team'
$WAZUH_AGENT_VERSION = $env:WAZUH_AGENT_VERSION -or '4.8.1-1'
$TEMP_DIR = [System.IO.Path]::GetTempPath()

# Text formatting (Powershell doesn't handle color formatting in the same way as Linux)
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

# Check if WAZUH_MANAGER is provided
if (-not $WAZUH_MANAGER) {
    Log-Error "WAZUH_MANAGER is required"
    exit 1
}

# Import GPG Key for Wazuh repository (equivalent for Windows via Chocolatey or manual package download)
function Import-Keys {
    Log-Info "Importing Wazuh GPG key and setting up the repository for Windows"
    $WazuhKeyUrl = "https://packages.wazuh.com/key/GPG-KEY-WAZUH"
    
    # Download the GPG key (Windows won't use this in the same way, but good to track it)
    Invoke-WebRequest -Uri $WazuhKeyUrl -OutFile "$TEMP_DIR\WazuhGPGKey.asc"
    Log-Info "Wazuh GPG key downloaded successfully."
}

# Install Wazuh agent on Windows
function Install-WazuhAgent {
    Log-Info "Installing Wazuh agent version $WAZUH_AGENT_VERSION on Windows"

    # Download the Wazuh Agent installer
    $Arch = if ([System.Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
    $InstallerUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"
    $InstallerPath = "$TEMP_DIR\wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"
    
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
    Log-Info "Wazuh agent installer downloaded to $InstallerPath"

    # Install the Wazuh Agent MSI package
    Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" /quiet /norestart" -Wait
    Log-Info "Wazuh agent installed successfully."
}

# Configure Wazuh agent by setting the manager IP in the ossec.conf file
function Configure-Agent {
    Log-Info "Configuring Wazuh manager IP in $OSSEC_CONF_PATH"
    
    # Modify the ossec.conf to include the Wazuh manager IP
    (Get-Content $OSSEC_CONF_PATH) -replace 'MANAGER_IP', $WAZUH_MANAGER | Set-Content $OSSEC_CONF_PATH
    Log-Info "Wazuh manager IP configured successfully."
}

# Start Wazuh agent service on Windows
function Start-WazuhAgent {
    Log-Info "Starting Wazuh agent service on Windows"
    
    Start-Service -Name 'wazuh-agent'
    Log-Info "Wazuh agent started successfully."
}

# Main execution
Import-Keys
Install-WazuhAgent
Configure-Agent
Start-WazuhAgent

# Clean up
Remove-Item "$TEMP_DIR\WazuhGPGKey.asc" -ErrorAction SilentlyContinue
Log-Info "Temporary files cleaned up."
