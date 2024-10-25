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
    $WazuhManager = "master.dev.wazuh.adorsys.team"
    $AgentVersion = "4.8.1-1"
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

    # Install the Wazuh agent
    info_message "Installing Wazuh agent..."
    try {
        Start-Process -FilePath "msiexec.exe" /i $MsiPath /q WAZUH_MANAGER=$WazuhManager -Wait -ErrorAction Stop
    } catch {
        error_message "Failed to install Wazuh agent: $($_.Exception.Message)"
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

# Call the Install-Agent function to execute the installation
Install-Agent
