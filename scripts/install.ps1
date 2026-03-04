# Dot-source shared utilities
# Robust utility sourcing
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/utils.ps1" -OutFile "utils.ps1"
. ./utils.ps1

$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.14.2-1" }

# Variables
$AgentFileName = "wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$TempDir = $env:TEMP
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.msi"
$MsiPath = Join-Path -Path $TempDir -ChildPath $AgentFileName

$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"

$APP_LOGO_URL = "$RepoUrl/assets/wazuh-logo.png"
$APP_LOGO_PATH = Join-Path -Path $APP_DATA -ChildPath "wazuh-logo.png"

# Exit script with an error message

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
