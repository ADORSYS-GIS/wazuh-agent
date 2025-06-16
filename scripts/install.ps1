$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.11.1-1" }


# Global variables
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$APP_DATA = "C:\ProgramData\ossec-agent\"

# Variables
$AgentFileName = "wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$TempDir = $env:TEMP
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$MsiPath = Join-Path -Path $TempDir -ChildPath $AgentFileName

$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"

$APP_LOGO_URL = "$RepoUrl/assets/wazuh-logo.png"
$APP_LOGO_PATH = Join-Path -Path $APP_DATA -ChildPath "wazuh-logo.png"

# Function for logging with timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"  # Default color
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

# Logging helpers with colors
function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "White"
}

function WarnMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function PrintStep {
    param (
        [int]$StepNumber,
        [string]$Message
    )
    Log "[STEP]" "Step ${StepNumber}: $Message" "White"
}

# Exit script with an error message
function ErrorExit {
    param ([string]$Message)
    ErrorMessage $Message
    exit 1
}

# Version Check Functions
function Get-InstalledAgentVersion {
    try {
        # Check via WMI (works for MSI installations)
        $wazuhProduct = Get-WmiObject -Class Win32_Product | 
                        Where-Object { $_.Name -match 'wazuh-agent' } |
                        Select-Object -First 1
        
        if ($wazuhProduct) {
            return $wazuhProduct.Version
        }

        # Fallback check in registry (for non-MSI installations)
        $uninstallPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $wazuhEntry = Get-ItemProperty $uninstallPath | 
                      Where-Object { $_.DisplayName -match 'wazuh-agent' } |
                      Select-Object -First 1

        if ($wazuhEntry) {
            return $wazuhEntry.DisplayVersion
        }

        return $null
    } catch {
        ErrorMessage "Failed to check installed version: $_"
        return $null
    }
}

# Function to install Wazuh Agent
function Install-Agent {



    # Check if system architecture is supported
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        ErrorMessage "Unsupported architecture. Only 64-bit systems are supported."
        return
    }

    # Download the Wazuh agent MSI package
    InfoMessage "Downloading Wazuh agent version $WAZUH_AGENT_VERSION..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -ErrorAction Stop
    } catch {
        ErrorMessage "Failed to download Wazuh agent: $($_.Exception.Message)"
        return
    }

    # Filling up MSI installer arguments
    $MsiArguments = @(
        "/i $MsiPath"
        "/q"
        "WAZUH_MANAGER=`"$WAZUH_MANAGER`""
    )

    # Install the Wazuh agent
    InfoMessage "Installing Wazuh agent..."
    try {
        Start-Process "msiexec.exe" -ArgumentList $MsiArguments -Wait -ErrorAction Stop
    } catch {
        ErrorMessage "Failed to install Wazuh agent: $($_.Exception.Message)"
        return
    }

    # Update the manager address in the configuration file
    try {
        [xml]$configXml = Get-Content -Path $OSSEC_CONF_PATH
        $configXml.ossec_config.client.server.address = $WAZUH_MANAGER
        $configXml.Save($OSSEC_CONF_PATH)
        InfoMessage "Manager address updated successfully in ossec.conf."
    } catch {
        ErrorMessage "Failed to update manager address: $($_.Exception.Message)"
        return
    }
    
    # Start the Wazuh service
    InfoMessage "Starting Wazuh service..."
    try {
        Start-Service -Name "WazuhSvc" -ErrorAction Stop
        InfoMessage "Wazuh service started successfully."
    } catch {
        ErrorMessage "Failed to start Wazuh service: $($_.Exception.Message)"
        return
    }

    InfoMessage "Wazuh agent installed successfully."
}


function Create-Upgrade-Script {
    $UPGRADE_SCRIPT_PATH = "C:\Program Files (x86)\ossec-agent\adorsys-update.ps1"
    InfoMessage "Creating update script at $UPGRADE_SCRIPT_PATH"

    # Temporary directory
    $TempFolder = New-TemporaryFile
    Remove-Item $TempFolder -Force
    New-Item -ItemType Directory -Path $TempFolder | Out-Null

    try {
        # Define upgrade script content
        $UpgradeScript = @'
# Upgrade script from ADORSYS.
# Copyright (C) 2024, ADORSYS GmbH & CO KG.

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
        InfoMessage "Update script created successfully."
    } catch {
        ErrorMessage "Failed to create the upgrade script: $_"
    } finally {
        # Cleanup temporary directory
        if (Test-Path $TempFolder) {
            Remove-Item -Path $TempFolder -Recurse -Force
        }
    }
}

function Config {
    InfoMessage "Downloading app logo..."

    if (!(Test-Path -Path $APP_DATA)) {
        New-Item -ItemType Directory -Path $APP_DATA -Force | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $APP_LOGO_URL -OutFile $APP_LOGO_PATH -ErrorAction Stop
    } catch {
        ErrorMessage "Failed to download App logo: $($_.Exception.Message)"
        return
    } finally {
        InfoMessage "App logo downloaded successfully"
    }
}

function Cleanup {
    InfoMessage "Removing msi executable $AgentVersion..."
    try {
        Remove-Item -Path $MsiPath -Recurse -Force
        InfoMessage "Msi Executable $AgentVersion Removed"
        SuccessMessage "Wazuh Installed Successfully"
    }
    catch {
        ErrorMessage "Failed to remove msi executable $AgentVersion : $($_.Exception.Message)"
    }
}

# Main execution

$currentVersion = Get-InstalledAgentVersion

if ($currentVersion -and ($currentVersion -eq $WAZUH_AGENT_VERSION)) {
    InfoMessage "[INFO] Wazuh agent $WAZUH_AGENT_VERSION is already installed. Skipping."
    exit 0
}
elseif ($currentVersion) {
    InfoMessage "[INFO] Current version: $currentVersion, Target version: $WAZUH_AGENT_VERSION"
}

# YOUR EXISTING INSTALLATION CODE BELOW (keep everything exactly as is)
Install-Agent
Create-Upgrade-Script
Config
Cleanup