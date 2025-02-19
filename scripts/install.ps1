$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "manager.wazuh.adorsys.team" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.10.1-1" }

# Define text formatting
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[1;34m"
$BOLD = "`e[1m"
$NORMAL = "`e[0m"

# Global variables
$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$APP_DATA = "C:\ProgramData\ossec-agent\"

# Variables

$AgentFileName = "wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$TempDir = $env:TEMP
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$MsiPath = Join-Path -Path $TempDir -ChildPath $AgentFileName

$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/feat/ota-update"

$APP_LOGO_URL = "$RepoUrl/assets/wazuh-logo.png"
$APP_LOGO_PATH = Join-Path -Path $APP_DATA -ChildPath "wazuh-logo.png"

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

function warn_message {
    param (
        [string]$MESSAGE
    )
    log "INFO" "$YELLOW$MESSAGE$NORMAL"
}

function error_message {
    param (
        [string]$MESSAGE
    )
    log "ERROR" "$RED$MESSAGE$NORMAL"
}

# Function to install Wazuh Agent
function Install-Agent {



    # Check if system architecture is supported
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        error_message "Unsupported architecture. Only 64-bit systems are supported."
        return
    }

    # Download the Wazuh agent MSI package
    info_message "Downloading Wazuh agent version $WAZUH_AGENT_VERSION..."
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
        "WAZUH_MANAGER=`"$WAZUH_MANAGER`""
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
        $configXml.ossec_config.client.server.address = $WAZUH_MANAGER
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
    Write-Output "$Timestamp [$Level] $Message"
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
        info_message "Temporary folder removed: $TempFolder" | tee -a "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
    }
}

try {
    $TempFolder = New-TemporaryFile
    Remove-Item $TempFolder -Force
    New-Item -ItemType Directory -Path $TempFolder | Out-Null

    info_message "Starting Wazuh Agent Upgrade" | tee -a "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"

    # Download the setup script
    $SetupScriptURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/setup-agent.ps1"
    $SetupScriptPath = Join-Path -Path $TempFolder -ChildPath "setup-agent.ps1"
    Invoke-WebRequest -Uri $SetupScriptURL -OutFile $SetupScriptPath

    # Execute the setup script
    . $SetupScriptPath | tee -a "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"

    info_message "Wazuh Agent Upgrade Completed" | tee -a "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
} catch {
    error_message "Wazuh Agent Upgrade Failed: $_" | tee -a "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
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

function Config {
    info_message "Downloading app logo..."

    if (!(Test-Path -Path $APP_DATA)) {
        New-Item -ItemType Directory -Path $APP_DATA -Force | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $APP_LOGO_URL -OutFile $APP_LOGO_PATH -ErrorAction Stop
    } catch {
        error_message "Failed to download App logo: $($_.Exception.Message)"
        return
    } finally {
        info_message "App logo downloaded successfully"
    }
}

function Cleanup {
    info_message "Removing msi executable $AgentVersion..."
    try {
        Remove-Item -Path $MsiPath -Recurse -Force
        info_message "Msi Executable $AgentVersion Removed"
    }
    catch {
        error_message "Failed to remove msi executable $AgentVersion : $($_.Exception.Message)"
    }
}

# Call the Install-Agent function to execute the installation
Install-Agent
Create-Upgrade-Script
Config
Cleanup