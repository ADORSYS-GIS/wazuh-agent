param(
    [switch]$InstallSnort,
    [switch]$InstallSuricata,
    [switch]$Help
)

# Set strict mode for script execution (after param declaration)
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.13.1-1" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$TEMP_DIR = [System.IO.Path]::GetTempPath()
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.14" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.4.0-user" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.3.0" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }
$WAZUH_AGENT_REPO_VERSION = if ($env:WAZUH_AGENT_REPO_VERSION) { $env:WAZUH_AGENT_REPO_VERSION } else { "1.7.0" }
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/tags/v$WAZUH_AGENT_REPO_VERSION"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"

# Global array to track installer files
$global:InstallerFiles = @()

# Function to log messages with a timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"  # Default color
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "Cyan"
}

function WarningMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
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

# Cleanup function to remove installer files at the end
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed installer file: $file"
        }
    }
}

# Step 0: Download dependency script and execute
function Install-Dependencies {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/tags/v$WAZUH_AGENT_REPO_VERSION/scripts/deps.ps1"
    $InstallerPath = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing dependency script..."
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        InfoMessage "Dependency script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during dependency installation: $($_.Exception.Message)"
    }
}

# Step 1: Download and execute Wazuh agent script with error handling
function Install-WazuhAgent {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/tags/v$WAZUH_AGENT_REPO_VERSION/scripts/install.ps1"
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        InfoMessage "Downloading and executing Wazuh agent script..."
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        InfoMessage "Wazuh agent script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Wazuh agent installation: $($_.Exception.Message)"
    }
}

# Step 2: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.ps1"
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    try {
        InfoMessage "Downloading and executing wazuh-cert-oauth2-client script..."
        Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
        InfoMessage "wazuh-cert-oauth2-client script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)"
    }
}

# Step 3: Download and install YARA with error handling
function Install-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.ps1"
    $YaraScript = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $YaraScript

    try {
        InfoMessage "Downloading and executing YARA installation script..."
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        InfoMessage "YARA installation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during YARA installation: $($_.Exception.Message)"
    }
}

# Step 4: Download and install Snort with error handling
function Install-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/snort.ps1"
    $SnortScript = "$env:TEMP\snort.ps1"
    $global:InstallerFiles += $SnortScript

    try {
        InfoMessage "Downloading and executing Snort installation script..."
        Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
        InfoMessage "Snort installation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Snort installation: $($_.Exception.Message)"
    }
}

# Helper functions to uninstall Snort and Suricata
function Uninstall-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/uninstall.ps1"
    $UninstallSnortScript = "$env:TEMP\uninstall_snort.ps1"
    $global:InstallerFiles += $UninstallSnortScript
    $TaskName = "SnortStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        try {
            InfoMessage "Downloading and executing Snort uninstallation script..."
            Invoke-WebRequest -Uri $SnortUrl -OutFile $UninstallSnortScript -ErrorAction Stop
            InfoMessage "Snort uninstallation script downloaded successfully."
            & powershell.exe -ExecutionPolicy Bypass -File $UninstallSnortScript -ErrorAction Stop
        }
        catch {
            ErrorMessage "Error during Snort uninstallation: $($_.Exception.Message)"
        }
    }
}

# Step 5: Download and install Suricata with error handling
function Install-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/install.ps1"
    $SuricataScript = "$env:TEMP\suricata.ps1"
    $global:InstallerFiles += $SuricataScript

    try {
        InfoMessage "Snort is installed. Downloading and executing Suricata installation script..."
        Invoke-WebRequest -Uri $SuricataUrl -OutFile $SuricataScript -ErrorAction Stop
        InfoMessage "Suricata installation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Suricata installation: $($_.Exception.Message)"
    }
}

function Uninstall-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.ps1"
    $UninstallSuricataScript = "$env:TEMP\uninstall_suricata.ps1"
    $global:InstallerFiles += $UninstallSuricataScript
    $TaskName = "SuricataStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        try {
            InfoMessage "Suricata is installed. Downloading and executing Suricata uninstallation script..."
            Invoke-WebRequest -Uri $SuricataUrl -OutFile $UninstallSuricataScript -ErrorAction Stop
            InfoMessage "Suricata uninstallation script downloaded successfully."
            & powershell.exe -ExecutionPolicy Bypass -File $UninstallSuricataScript -ErrorAction Stop
        }
        catch {
            ErrorMessage "Error during Suricata uninstallation: $($_.Exception.Message)"
        }
    }
}

# Step 6: Download and install Wazuh Agent Status with error handling
function Install-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION/scripts/install.ps1"
    $AgentStatusScript = "$env:TEMP\install-agent-status.ps1"
    $global:InstallerFiles += $AgentStatusScript

    try {
        InfoMessage "Downloading and executing Wazuh Agent Status installation script..."
        Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
        InfoMessage "Agent Status installation script downloaded successfully."
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Agent Status installation: $($_.Exception.Message)"
    }
}

function DownloadVersionFile {
    InfoMessage "Downloading version file..."
    if (!(Test-Path -Path $OSSEC_PATH)) {
        WarningMessage "ossec-agent folder does not exist. Skipping."
    }
    else {
        try {
            Invoke-WebRequest -Uri $VERSION_FILE_URL -OutFile $VERSION_FILE_PATH -ErrorAction Stop
        } catch {
            ErrorMessage "Failed to download version file: $($_.Exception.Message)"
        } finally {
            InfoMessage "Version file downloaded successfully"
        }
    }
}

function Show-Help {
    Write-Host "Usage:  .\setup-agent.ps1 [-InstallSnort] [-InstallSuricata] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script automates the installation of various Wazuh components and related tools." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -InstallSnort      : Installs Snort. Cannot be used with -InstallSuricata." -ForegroundColor Cyan
    Write-Host "  -InstallSuricata   : Installs Suricata. Cannot be used with -InstallSnort." -ForegroundColor Cyan
    Write-Host "  -Help              : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL          : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  APP_NAME           : Sets the application name. Default: wazuh-cert-oauth2-client" -ForegroundColor Cyan
    Write-Host "  WAZUH_MANAGER      : Sets the Wazuh Manager address. Default: wazuh.example.com" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_VERSION: Sets the Wazuh Agent version. Default: $WAZUH_AGENT_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_YARA_VERSION : Sets the Wazuh YARA module version. Default: $WAZUH_YARA_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_SNORT_VERSION: Sets the Wazuh Snort module version. Default: $WAZUH_SNORT_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_SURICATA_VERSION: Sets the Wazuh Suricata module version. Default: $WAZUH_SURICATA_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_STATUS_VERSION: Sets the Wazuh Agent Status module version. Default: $WAZUH_AGENT_STATUS_VERSION" -ForegroundColor Cyan
    Write-Host "  WOPS_VERSION       : Sets the WOPS client version. Default: $WOPS_VERSION" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\setup-agent.ps1 -InstallSnort" -ForegroundColor Cyan
    Write-Host "  .\setup-agent.ps1 -InstallSuricata" -ForegroundColor Cyan
    Write-Host "  .\setup-agent.ps1 -Help" -ForegroundColor Cyan
    Write-Host "  $env:LOG_LEVEL='DEBUG'; .\setup-agent.ps1 -InstallSuricata" -ForegroundColor Cyan
    Write-Host ""
}

# Show help if -Help is specified
if ($Help) {
    Show-Help
    Exit 0
}

# Provide a non-interactive default for NIDS selection (default: Suricata)
if (-not $InstallSnort -and -not $InstallSuricata) {
    InfoMessage "No NIDS selected, defaulting to: Suricata. Use -InstallSuricata or -InstallSnort to override."
    $InstallSuricata = $true
}

# Validate Snort and Suricata choice
if ($InstallSnort -and $InstallSuricata) {
    ErrorMessage "Cannot install both Snort and Suricata. Please choose one."
    Show-Help
    Exit 1
}

# Main Execution wrapped in a try-finally to ensure cleanup runs even if errors occur.
try {
    SectionSeparator "Installing Dependencies"
    Install-Dependencies
    SectionSeparator "Installing Wazuh Agent"
    Install-WazuhAgent
    SectionSeparator "Installing OAuth2Client"
    Install-OAuth2Client
    SectionSeparator "Installing Agent Status"
    Install-AgentStatus
    SectionSeparator "Installing Yara"
    Install-Yara

    # Install Snort or Suricata based on user choice
    if ($InstallSnort) {
        Uninstall-Suricata
        SectionSeparator "Installing Snort"
        Install-Snort
    }
    elseif ($InstallSuricata) {
        Uninstall-Snort
        SectionSeparator "Installing Suricata"
        Install-Suricata
    }
    else {
        WarningMessage "Neither Snort nor Suricata selected for installation. Skipping."
    }

    SectionSeparator "Downloading Version File"
    DownloadVersionFile
}
finally {
    InfoMessage "Cleaning up installer files..."
    Cleanup-Installers
    SuccessMessage "Wazuh Agent Setup Completed Successfully"
}
