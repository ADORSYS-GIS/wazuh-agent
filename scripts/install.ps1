$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }


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

# Call the Install-Agent function to execute the installation
Install-Agent
Config
Cleanup
