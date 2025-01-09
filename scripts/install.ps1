# Define text formatting
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[1;34m"
$BOLD = "`e[1m"
$NORMAL = "`e[0m"

# Function for logging with timestamp
function log {
    param (
        [string]$LEVEL,
        [string]$MESSAGE
    )
    $TIMESTAMP = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$TIMESTAMP [$LEVEL] $MESSAGE"
}

# Logging helpers
function info_message {
    param (
        [string]$MESSAGE
    )
    log "INFO" "$GREEN$MESSAGE$NORMAL"
}

function error_message {
    param (
        [string]$MESSAGE
    )
    log "ERROR" "$RED$MESSAGE$NORMAL"
}

# Function to install Wazuh Agent
function Install-Agent {

    # Global variables
    $OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    # Variables
    $WazuhManager = "events.dev.wazuh.adorsys.team"
    $WazuhRegistrationServer = "register.dev.wazuh.adorsys.team" # TODO Use this
    $AgentVersion = "4.9.2-1"
    $AgentFileName = "wazuh-agent-$AgentVersion.msi"
    $TempDir = $env:TEMP
    $DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$AgentVersion.msi"
    $MsiPath = Join-Path -Path $TempDir -ChildPath $AgentFileName

    # Check if system architecture is supported
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        error_message "Unsupported architecture. Only 64-bit systems are supported."
        return
    }

    # Download the Wazuh agent MSI package
    info_message "Downloading Wazuh agent version $AgentVersion..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -ErrorAction Stop
    } catch {
        error_message "Failed to download Wazuh agent: $($_.Exception.Message)"
        return
    }

    # Filling up MSI installer arguments
    $MsiArguments = @(
        "/i $MsiPath"
        "/q"
        "WAZUH_MANAGER=`"$WazuhManager`""
        "WAZUH_REGISTRATION_SERVER=`"$WazuhRegistrationServer`""
    )

    # Install the Wazuh agent
    info_message "Installing Wazuh agent..."
    try {
        Start-Process "msiexec.exe" -ArgumentList $MsiArguments -Wait -ErrorAction Stop
    } catch {
        error_message "Failed to install Wazuh agent: $($_.Exception.Message)"
        return
    }

    # Update the manager address in the configuration file
    try {
        [xml]$configXml = Get-Content -Path $OSSEC_CONF_PATH
        $configXml.ossec_config.client.server.address = $WazuhManager
        $configXml.Save($OSSEC_CONF_PATH)
        info_message "Manager address updated successfully in ossec.conf."
    } catch {
        error_message "Failed to update manager address: $($_.Exception.Message)"
        return
    }
    
    # Start the Wazuh service
    info_message "Starting Wazuh service..."
    try {
        Start-Service -Name "WazuhSvc" -ErrorAction Stop
        info_message "Wazuh service started successfully."
    } catch {
        error_message "Failed to start Wazuh service: $($_.Exception.Message)"
        return
    }

    info_message "Wazuh agent installed successfully."
}

function Create-Upgrade-Script {
    $UPGRADE_SCRIPT_PATH = "C:\Program Files (x86)\ossec-agent\adorsys-update.ps1"
    info_message "Creating update script at $UPGRADE_SCRIPT_PATH"

    # Temporary directory
    $TempFolder = New-TemporaryFile
    Remove-Item $TempFolder -Force
    New-Item -ItemType Directory -Path $TempFolder | Out-Null

    try {
        # Define upgrade script content
        $UpgradeScript = @'
# Upgrade script for Wazuh Agent
# This script downloads and updates the Wazuh agent

function Log {
    param (
        [string]$Level,
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp [$Level] $Message"
}

function info_message {
    param ([string]$Message)
    Log "INFO" $Message
}

function error_message {
    param ([string]$Message)
    Log "ERROR" $Message
}

function Cleanup {
    param ([string]$TempFolder)
    if (Test-Path $TempFolder) {
        Remove-Item -Path $TempFolder -Recurse -Force
        info_message "Temporary folder removed: $TempFolder"
    }
}

try {
    $TempFolder = New-TemporaryFile
    Remove-Item $TempFolder -Force
    New-Item -ItemType Directory -Path $TempFolder | Out-Null

    info_message "Starting Wazuh Agent Upgrade"

    # Download the setup script
    $SetupScriptURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.ps1"
    $SetupScriptPath = Join-Path -Path $TempFolder -ChildPath "setup-agent.ps1"
    Invoke-WebRequest -Uri $SetupScriptURL -OutFile $SetupScriptPath

    # Execute the setup script
    . $SetupScriptPath

    info_message "Wazuh Agent Upgrade Completed"
} catch {
    error_message "Wazuh Agent Upgrade Failed: $_"
    exit 1
} finally {
    Cleanup -TempFolder $TempFolder
}
'@

        # Save the script
        $UpgradeScript | Set-Content -Path $UPGRADE_SCRIPT_PATH -Force
        Set-ItemProperty -Path $UPGRADE_SCRIPT_PATH -Name IsReadOnly -Value $true
        info_message "Update script created successfully."
    } catch {
        error_message "Failed to create the upgrade script: $_"
    } finally {
        # Cleanup temporary directory
        if (Test-Path $TempFolder) {
            Remove-Item -Path $TempFolder -Recurse -Force
        }
    }
}


# Call the Install-Agent function to execute the installation
Install-Agent
Create-Upgrade-Script