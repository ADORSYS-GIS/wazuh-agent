# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf" # Adjust for Windows

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
function SectionSeparator {
    param (
        [string]$SectionName
    )
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  $SectionName" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

# Step 1: Download and execute Wazuh agent script with error handling
function Uninstall-WazuhAgent {
    try {
        Write-Host "Downloading and executing Wazuh agent uninstall script..."

        $UninstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/main/scripts/uninstall.ps1"  # Update the URL if needed
        $UninstallerPath = "$env:TEMP\uninstall.ps1"

        # Download Wazuh agent Uninstaller script
        Invoke-WebRequest -Uri $UninstallerUrl -OutFile $UninstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent uninstall script downloaded successfully."

        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $UninstallerPath -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Wazuh agent Uninstallation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the Uninstaller file if it exists
        if (Test-Path $UninstallerPath) {
            Remove-Item $UninstallerPath -Force
            Write-Host "Uninstall file removed."
        }
    }
}



# Step 3: Download and Uninstall YARA with error handling
function Uninstall-Yara {
    try {
        Write-Host "Downloading and executing YARA uninstall script..."

        $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/heads/main/scripts/uninstall.ps1"  # Update the URL if needed
        $YaraScript = "$env:TEMP\uninstall-yara.ps1"

        # Download the Uninstallation script
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        Write-Host "YARA Uninstallation script downloaded successfully."

        # Execute the Uninstallation script
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during YARA Uninstallation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $YaraScript) {
            Remove-Item $YaraScript -Force
            Write-Host "Uninstall script removed."
        }
    }
}

# Step 4: Download and Uninstall Snort with error handling
function Uninstall-Snort {
    try {
        Write-Host "Downloading and executing Snort uninstall script..."

        $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/heads/main/scripts/windows/uninstall.ps1"  # Update the URL if needed
        $SnortScript = "$env:TEMP\uninstall-snort.ps1"

        # Download the Uninstallation script
        Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
        Write-Host "Snort Uninstallation script downloaded successfully."

        # Execute the Uninstallation script
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Snort Uninstallation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $SnortScript) {
            Remove-Item $SnortScript -Force
            Write-Host "Uninstall script removed."
        }
    }
}

# Step 4: Download and Uninstall Wazuh Agent Status with error handling
function Uninstall-AgentStatus {
    try {
        Write-Host "Downloading and executing Wazuh Agent Status uninstall script..."

        $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/heads/main/scripts/uninstall.ps1"  # Update the URL if needed
        $AgentStatusScript = "$env:TEMP\uninstall-agent-status.ps1"

        # Download the Uninstallation script
        Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
        Write-Host "Agent Status Uninstallation script downloaded successfully."

        # Execute the Uninstallation script
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Agent Status Uninstallation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $AgentStatusScript) {
            Remove-Item $AgentStatusScript -Force
            Write-Host "Uninstall script removed."
        }
    }
}




# Main Execution
SectionSeparator "Uninstalling Wazuh Agent"
Uninstall-WazuhAgent
# SectionSeparator "Uninstalling OAuth2Client"
# Uninstall-OAuth2Client
SectionSeparator "Uninstalling Agent Status"
Uninstall-AgentStatus
SectionSeparator "Uninstalling Yara"
Uninstall-Yara
SectionSeparator "Uninstalling Snort"
Uninstall-Snort