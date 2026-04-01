param(
    [switch]$InstallSnort,
    [switch]$InstallSuricata,
    [switch]$CaptureDockerLogs,
    [switch]$Help
)

# Source shared utilities
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }

$UtilsTmp = Join-Path -Path $env:TEMP -ChildPath "wazuh_utils_$((Get-Date).Ticks)"
New-Item -ItemType Directory -Path $UtilsTmp -Force | Out-Null

try {
    $ChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/checksums.sha256"
    $UtilsUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/shared/utils.ps1"
    $global:ChecksumsPath = Join-Path $UtilsTmp "checksums.sha256"
    
    Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumsPath -ErrorAction Stop
    Invoke-WebRequest -Uri $UtilsUrl -OutFile "$UtilsTmp\utils.ps1" -ErrorAction Stop

    $ExpectedHash = (Select-String -Path $ChecksumsPath -Pattern "scripts/shared/utils.ps1").Line.Split(" ")[0]
    $ActualHash = (Get-FileHash -Path "$UtilsTmp\utils.ps1" -Algorithm SHA256).Hash.ToLower()

    if ([string]::IsNullOrWhiteSpace($ExpectedHash) -or $ExpectedHash -ne $ActualHash) {
        Write-Error "Checksum verification failed for utils.ps1"
        exit 1
    }
} catch {
    Write-Error "Failed to download or verify utils.ps1: $($_.Exception.Message)"
    exit 1
}

. "$UtilsTmp\utils.ps1"

# Set strict mode for script execution (after param declaration)
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.14.2-1" }
$TEMP_DIR = [System.IO.Path]::GetTempPath()
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.14" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.4.1-rc5-user" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.4.2" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.2.0" }
$WAZUH_AGENT_REPO_VERSION = if ($env:WAZUH_AGENT_REPO_VERSION) { $env:WAZUH_AGENT_REPO_VERSION } else { "1.9.0-rc.1" }
$WAZUH_AGENT_REPO_REF = if ($env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF } else { "refs/tags/v$WAZUH_AGENT_REPO_VERSION" }

# Additional repo ref variables for other components
$WAZUH_CERT_OAUTH2_REPO_REF = if ($env:WAZUH_CERT_OAUTH2_REPO_REF) { $env:WAZUH_CERT_OAUTH2_REPO_REF } else { "refs/tags/v$WOPS_VERSION" }
$WAZUH_YARA_REPO_REF = if ($env:WAZUH_YARA_REPO_REF) { $env:WAZUH_YARA_REPO_REF } else { "refs/tags/v$WAZUH_YARA_VERSION" }
$WAZUH_SNORT_REPO_REF = if ($env:WAZUH_SNORT_REPO_REF) { $env:WAZUH_SNORT_REPO_REF } else { "refs/tags/v$WAZUH_SNORT_VERSION" }
$WAZUH_SURICATA_REPO_REF = if ($env:WAZUH_SURICATA_REPO_REF) { $env:WAZUH_SURICATA_REPO_REF } else { "refs/tags/v$WAZUH_SURICATA_VERSION" }
$WAZUH_TRIVY_REPO_REF = if ($env:WAZUH_TRIVY_REPO_REF) { $env:WAZUH_TRIVY_REPO_REF } else { "main" }
$WAZUH_AGENT_STATUS_REPO_REF = if ($env:WAZUH_AGENT_STATUS_REPO_REF) { $env:WAZUH_AGENT_STATUS_REPO_REF } else { "refs/tags/v$WAZUH_AGENT_STATUS_VERSION" }
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"

# Global array to track installer files
$global:InstallerFiles = @()


# Cleanup function to remove installer files at the end
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed installer file: $file"
        }
    }
}

# Step 0: Download and execute core scripts
function Download-CoreScripts {
    $CoreScripts = @("deps.ps1", "install.ps1")
    $env:WAZUH_AGENT_REPO_REF = $WAZUH_AGENT_REPO_REF
    
    # We already have utils.ps1 verified in the bootstrap phase, let's copy it to TEMP
    Copy-Item -Path "$UtilsTmp\utils.ps1" -Destination "$env:TEMP\utils.ps1" -Force
    $global:InstallerFiles += "$env:TEMP\utils.ps1"

    foreach ($script in $CoreScripts) {
        $url = "$RepoUrl/scripts/windows/$script"
        $dest = "$env:TEMP\$script"
        $global:InstallerFiles += $dest

        if (-not (Download-And-VerifyFile -Url $url -Destination $dest -ChecksumPattern "scripts/windows/$script" -FileName $script)) {
            exit 1
        }
    }
}

# Step 0.1: Execute dependencies
function Install-Dependencies {
    $InstallerPath = "$env:TEMP\deps.ps1"
    try {
        InfoMessage "Installing dependencies..."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during dependency installation: $($_.Exception.Message)"
    }
}

# Step 1: Execute Wazuh agent script
function Install-WazuhAgent {
    $InstallerPath = "$env:TEMP\install.ps1"
    try {
        InfoMessage "Executing Wazuh agent installation script..."
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ArgumentList "-WAZUH_AGENT_VERSION", $WAZUH_AGENT_VERSION, "-WAZUH_MANAGER", $WAZUH_MANAGER -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Wazuh agent installation: $($_.Exception.Message)"
    }
}

# Step 2: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF/scripts/windows/install.ps1"
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    $OAuth2ChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/$WAZUH_CERT_OAUTH2_REPO_REF/checksums.sha256"

    try {
        if (-not (Download-And-VerifyFile -Url $OAuth2Url -Destination $OAuth2Script -ChecksumPattern "scripts/windows/install.ps1" -FileName "wazuh-cert-oauth2-client script" -ChecksumUrl $OAuth2ChecksumUrl)) {
            throw "Failed to download and verify OAuth2 client script"
        }
        
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)"
    }
}

# Step 3: Download and install YARA with error handling
function Install-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/$WAZUH_YARA_REPO_REF/scripts/windows/install.ps1"
    $YaraScript = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $YaraScript

    $YaraChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/$WAZUH_YARA_REPO_REF/checksums.sha256"

    try {
        if (-not (Download-And-VerifyFile -Url $YaraUrl -Destination $YaraScript -ChecksumPattern "scripts/windows/install.ps1" -FileName "YARA installation script" -ChecksumUrl $YaraChecksumUrl)) {
            throw "Failed to download and verify YARA installation script"
        }
        
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during YARA installation: $($_.Exception.Message)"
    }
}

# Step 4: Download and install Snort with error handling
function Install-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/scripts/windows/snort.ps1"
    $SnortScript = "$env:TEMP\snort.ps1"
    $global:InstallerFiles += $SnortScript

    $SnortChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/checksums.sha256"

    try {
        if (-not (Download-And-VerifyFile -Url $SnortUrl -Destination $SnortScript -ChecksumPattern "scripts/windows/snort.ps1" -FileName "Snort installation script" -ChecksumUrl $SnortChecksumUrl)) {
            throw "Failed to download and verify Snort installation script"
        }
        
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Snort installation: $($_.Exception.Message)"
    }
}

# Helper functions to uninstall Snort and Suricata
function Uninstall-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/scripts/windows/uninstall.ps1"
    $UninstallSnortScript = "$env:TEMP\uninstall_snort.ps1"
    $global:InstallerFiles += $UninstallSnortScript
    $TaskName = "SnortStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        try {
            $SnortChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/checksums.sha256"
            if (-not (Download-And-VerifyFile -Url $SnortUrl -Destination $UninstallSnortScript -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "Snort uninstallation script" -ChecksumUrl $SnortChecksumUrl)) {
                throw "Failed to download and verify Snort uninstallation script"
            }
            
            & powershell.exe -ExecutionPolicy Bypass -File $UninstallSnortScript -ErrorAction Stop
        }
        catch {
            ErrorMessage "Error during Snort uninstallation: $($_.Exception.Message)"
        }
    }
}

# Step 5: Download and install Suricata with error handling
function Install-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF/scripts/windows/install.ps1"
    $SuricataScript = "$env:TEMP\suricata.ps1"
    $global:InstallerFiles += $SuricataScript

    $SuricataChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF/checksums.sha256"

    try {
        if (-not (Download-And-VerifyFile -Url $SuricataUrl -Destination $SuricataScript -ChecksumPattern "scripts/windows/install.ps1" -FileName "Suricata installation script" -ChecksumUrl $SuricataChecksumUrl)) {
            throw "Failed to download and verify Suricata installation script"
        }
        
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Suricata installation: $($_.Exception.Message)"
    }
}

function Uninstall-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF/scripts/windows/uninstall.ps1"
    $UninstallSuricataScript = "$env:TEMP\uninstall_suricata.ps1"
    $global:InstallerFiles += $UninstallSuricataScript
    $TaskName = "SuricataStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        try {
            $SuricataChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF/checksums.sha256"
            if (-not (Download-And-VerifyFile -Url $SuricataUrl -Destination $UninstallSuricataScript -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "Suricata uninstallation script" -ChecksumUrl $SuricataChecksumUrl)) {
                throw "Failed to download and verify Suricata uninstallation script"
            }
            
            & powershell.exe -ExecutionPolicy Bypass -File $UninstallSuricataScript -ErrorAction Stop
        }
        catch {
            ErrorMessage "Error during Suricata uninstallation: $($_.Exception.Message)"
        }
    }
}

# Step 6: Download and install Wazuh Agent Status with error handling
function Install-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/$WAZUH_AGENT_STATUS_REPO_REF/scripts/windows/install.ps1"
    $AgentStatusScript = "$env:TEMP\install-agent-status.ps1"
    $global:InstallerFiles += $AgentStatusScript

    $AgentStatusChecksumUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/$WAZUH_AGENT_STATUS_REPO_REF/checksums.sha256"

    try {
        if (-not (Download-And-VerifyFile -Url $AgentStatusUrl -Destination $AgentStatusScript -ChecksumPattern "scripts/windows/install.ps1" -FileName "Agent Status installation script" -ChecksumUrl $AgentStatusChecksumUrl)) {
            throw "Failed to download and verify Agent Status installation script"
        }
        
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Agent Status installation: $($_.Exception.Message)"
    }
}

# Step 7: Install USB DLP Active Response scripts
function Install-USBDLPScripts {
    $AR_BIN_DIR = Join-Path -Path $OSSEC_PATH -ChildPath "active-response\bin"
    $USB_DLP_BASE_URL = "$RepoUrl/files/active-response/windows"

    try {
        InfoMessage "Installing USB DLP Active Response scripts..."

        # Create directory if it doesn't exist
        if (!(Test-Path -Path $AR_BIN_DIR)) {
            New-Item -ItemType Directory -Path $AR_BIN_DIR -Force | Out-Null
        }

        # Download USB storage blocking script
        $USBStorageScript = Join-Path -Path $AR_BIN_DIR -ChildPath "disable-usb-storage.ps1"
        if (-not (Download-And-VerifyFile -Url "$USB_DLP_BASE_URL/disable-usb-storage.ps1" -Destination $USBStorageScript -ChecksumPattern "files/active-response/windows/disable-usb-storage.ps1" -FileName "disable-usb-storage.ps1")) {
            throw "Failed to download and verify USB storage script"
        }

        # Download USB HID alerting script
        $USBHIDScript = Join-Path -Path $AR_BIN_DIR -ChildPath "alert-usb-hid.ps1"
        if (-not (Download-And-VerifyFile -Url "$USB_DLP_BASE_URL/alert-usb-hid.ps1" -Destination $USBHIDScript -ChecksumPattern "files/active-response/windows/alert-usb-hid.ps1" -FileName "alert-usb-hid.ps1")) {
            throw "Failed to download and verify USB HID script"
        }

        SuccessMessage "USB DLP Active Response scripts installed successfully."
        InfoMessage "  - $USBStorageScript"
        InfoMessage "  - $USBHIDScript"
    }
    catch {
        ErrorMessage "Error during USB DLP scripts installation: $($_.Exception.Message)"
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

# Step 8: Setup Docker monitoring (only runs if Docker is installed)
function Install-DockerListener {
    $DockerSetupUrl = "$RepoUrl/scripts/windows/setup-docker.ps1"
    $DockerSetupScript = "$env:TEMP\setup-docker.ps1"
    $global:InstallerFiles += $DockerSetupScript

    try {
        InfoMessage "Downloading and executing Docker listener setup script..."
        Invoke-WebRequest -Uri $DockerSetupUrl -OutFile $DockerSetupScript -ErrorAction Stop
        InfoMessage "Docker listener setup script downloaded successfully."
        $argList = @()
        if ($CaptureDockerLogs) { $argList += "-CaptureLogs" }
        $env:WAZUH_AGENT_REPO_REF = $WAZUH_AGENT_REPO_REF
        & powershell.exe -ExecutionPolicy Bypass -File $DockerSetupScript $argList -ErrorAction Stop
        InfoMessage "Docker monitoring setup completed successfully."
    }
    catch {
        ErrorMessage "Error during Docker listener setup: $($_.Exception.Message)"
    }
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
    SectionSeparator "Downloading Core Scripts"
    Download-CoreScripts
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

    SectionSeparator "Installing USB DLP Scripts"
    Install-USBDLPScripts

    SectionSeparator "Setting up Docker Monitoring"
    Install-DockerListener

    SectionSeparator "Downloading Version File"
    DownloadVersionFile
}
finally {
    InfoMessage "Cleaning up installer files..."
    Cleanup-Installers
    SuccessMessage "Wazuh Agent Setup Completed Successfully"
}
