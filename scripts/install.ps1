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

    # Function to install Wazuh agent
    function Install-WazuhAgent {
        # Variables
        $WAZUH_MANAGER = "master.dev.wazuh.adorsys.team"
        $WAZUH_AGENT_VERSION = "4.8.1-1"
        $WAZUH_AGENT_MSI = "wazuh-agent-${WAZUH_AGENT_VERSION}.msi"
        $TEMP_DIR = $env:TEMP

        # Determine package URL based on architecture
        if ([System.Environment]::Is64BitOperatingSystem) {
            $PACKAGE_URL = "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_AGENT_VERSION}.msi"
        } else {
            error_message "Unsupported architecture. Only 64-bit systems are supported."
            exit 1
        }

        # Download the package
        info_message "Downloading Wazuh agent..."
        $msiPath = Join-Path -Path $TEMP_DIR -ChildPath $WAZUH_AGENT_MSI
        try {
            Invoke-WebRequest -Uri $PACKAGE_URL -OutFile $msiPath -ErrorAction Stop
        } catch {
            error_message "Failed to download Wazuh agent: $_"
            exit 1
        }

        # Install the package
        info_message "Installing Wazuh agent..."
        $MSIArguments = @(
            "/i"
            "`"$msiPath`""   # Use backticks to escape the quotes in the path
            "/quiet"
            "/norestart"  # Prevent restart after installation
            "WAZUH_MANAGER=${WAZUH_MANAGER}"
        )

        try {
            Start-Process -FilePath "msiexec.exe" -ArgumentList $MSIArguments -Wait -ErrorAction Stop
        } catch {
            error_message "Failed to install Wazuh agent: $_"
            exit 1
        }

        # Clean up
        info_message "Cleaning up..."
        try {
            Remove-Item -Path $msiPath -ErrorAction Stop
        } catch {
            Write-Warning "Failed to clean up the downloaded MSI file: $_"
        }
        info_message "Wazuh agent installed successfully!"
    }

    # Call the Install-WazuhAgent function
    Install-WazuhAgent
}

# Call the Install-Agent function to execute the installation
Install-Agent
