# Parameters for Trivy uninstallation only
param(
    [switch]$UninstallTrivy,
    [switch]$Help
)


# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.11" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.3.3" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.18" }

# Global array to track uninstaller files
$global:UninstallerFiles = @()

# Function to log messages with a timestamp and color
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage { param([string]$Message) Log "[INFO]" $Message "Cyan" }
function WarningMessage { param([string]$Message) Log "[WARNING]" $Message "Yellow" }
function SuccessMessage { param([string]$Message) Log "[SUCCESS]" $Message "Green" }
function ErrorMessage { param([string]$Message) Log "[ERROR]" $Message "Red" }
function SectionSeparator {
    param ([string]$SectionName)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  $SectionName" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

# Cleanup function to remove uninstaller files at the end
function Cleanup-Uninstallers {
    foreach ($file in $global:UninstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed uninstaller file: $file"
        }
    }
}

# Help Function
function Show-Help {
    Write-Host "Usage:  .\uninstall-agent.ps1 [-UninstallTrivy] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script automates the uninstallation of various Wazuh components and related tools." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Help                  : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL                : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  WAZUH_YARA_VERSION       : Sets the Wazuh YARA module version. Default: 0.3.4" -ForegroundColor Cyan
    Write-Host "  WAZUH_SNORT_VERSION      : Sets the Wazuh Snort module version. Default: 0.2.2" -ForegroundColor Cyan
    Write-Host "  WAZUH_SURICATA_VERSION   : Sets the Wazuh Suricata module version. Default: 0.1.0" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_STATUS_VERSION: Sets the Wazuh Agent Status module version. Default: 0.3.2" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_VERSION      : Sets the Wazuh Agent version. Default: 4.12.0-1" -ForegroundColor Cyan
    Write-Host "  WOPS_VERSION             : Sets the WOPS client version. Default: 0.2.18" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\uninstall-agent.ps1 -Help" -ForegroundColor Cyan
    Write-Host "  $env:LOG_LEVEL='DEBUG'; .\uninstall-agent.ps1" -ForegroundColor Cyan
    Write-Host ""
}



# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Step 1: Download and execute Wazuh agent uninstall script with error handling
function Uninstall-WazuhAgent {
    $UninstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/uninstall.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-wazuh-agent.ps1"
    $global:UninstallerFiles += $UninstallerPath
    try {
        InfoMessage "Downloading and executing Wazuh agent uninstall script..."
        Invoke-WebRequest -Uri $UninstallerURL -OutFile $UninstallerPath -ErrorAction Stop
        InfoMessage "Wazuh agent uninstall script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $UninstallerPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Wazuh agent Uninstallation: $($_.Exception.Message)"
    }
}

# Step 2: Download and Uninstall Wazuh Agent Status with error handling
function Uninstall-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION/scripts/uninstall.ps1"
    $AgentStatusScript = "$env:TEMP\uninstall-agent-status.ps1"
    $global:UninstallerFiles += $AgentStatusScript
    try {
        InfoMessage "Downloading and executing Wazuh Agent Status uninstall script..."
        Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
        InfoMessage "Agent Status Uninstallation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Agent Status Uninstallation: $($_.Exception.Message)"
    }
}

# Step 3: Download and Uninstall YARA with error handling
function Uninstall-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/uninstall.ps1"
    $YaraScript = "$env:TEMP\uninstall-yara.ps1"
    $global:UninstallerFiles += $YaraScript
    try {
        InfoMessage "Downloading and executing YARA uninstall script..."
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        InfoMessage "YARA Uninstallation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during YARA Uninstallation: $($_.Exception.Message)"
    }
}

# Step 4: Download and Uninstall Snort with error handling
function Uninstall-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/uninstall.ps1"
    $SnortScript = "$env:TEMP\uninstall-snort.ps1"
    $global:UninstallerFiles += $SnortScript
    try {
        InfoMessage "Downloading and executing Snort uninstall script..."
        Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
        InfoMessage "Snort Uninstallation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Snort Uninstallation: $($_.Exception.Message)"
    }
}

# Step 5: Download and Uninstall Suricata with error handling
function Uninstall-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.ps1"
    $SuricataScript = "$env:TEMP\uninstall-suricata.ps1"
    $global:UninstallerFiles += $SuricataScript
    try {
        InfoMessage "Downloading and executing Suricata uninstall script..."
        Invoke-WebRequest -Uri $SuricataUrl -OutFile $SuricataScript -ErrorAction Stop
        InfoMessage "Suricata Uninstallation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Suricata Uninstallation: $($_.Exception.Message)"
    }
}

# Helper functions to check if Snort/Suricata are installed
function Is-SnortInstalled {
    $TaskName = "SnortStartup"
    return (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}
function Is-SuricataInstalled {
    $TaskName = "SuricataStartup"
    return (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}

# Main Execution wrapped in a try-finally to ensure cleanup runs even if errors occur.
try {
    SectionSeparator "Uninstalling Wazuh Agent"
    Uninstall-WazuhAgent
    SectionSeparator "Uninstalling Agent Status"
    Uninstall-AgentStatus
    SectionSeparator "Uninstalling Yara"
    Uninstall-Yara
    if (Is-SnortInstalled) {
        SectionSeparator "Uninstalling Snort"
        Uninstall-Snort
    }
    if (Is-SuricataInstalled) {
        SectionSeparator "Uninstalling Suricata"
        Uninstall-Suricata
    }
}
finally {
    InfoMessage "Cleaning up uninstaller files..."
    Cleanup-Uninstallers
    SuccessMessage "Wazuh Agent Uninstallation Completed Successfully"
}