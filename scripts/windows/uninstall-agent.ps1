# Parameters for Trivy and NetBird uninstallation
param(
    [switch]$UninstallTrivy,
    [switch]$UninstallNetBird,
    [switch]$Help
)

# Source shared utilities
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
# Create a secure temporary directory for utilities
$UtilsTmp = Join-Path $env:TEMP "wazuh-utils-$(Get-Random)"
New-Item -ItemType Directory -Path $UtilsTmp -Force | Out-Null

try {
    $ChecksumsURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/checksums.sha256"
    $UtilsURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/shared/utils.ps1"

    $global:ChecksumsPath = Join-Path $UtilsTmp "checksums.sha256"
    $UtilsPath = Join-Path $UtilsTmp "utils.ps1"

    Invoke-WebRequest -Uri $ChecksumsURL -OutFile $ChecksumsPath -ErrorAction Stop
    Invoke-WebRequest -Uri $UtilsURL -OutFile $UtilsPath -ErrorAction Stop

    # Verification function (bootstrap)
    function Get-FileChecksum-Bootstrap {
        param([string]$FilePath)
        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
    }

    $ExpectedHash = (Select-String -Path $ChecksumsPath -Pattern "scripts/shared/utils.ps1").Line.Split(" ")[0]
    $ActualHash = Get-FileChecksum-Bootstrap -FilePath $UtilsPath

    if ([string]::IsNullOrWhiteSpace($ExpectedHash) -or ($ActualHash -ne $ExpectedHash.ToLower())) {
        Write-Error "Checksum verification failed for utils.ps1"
        exit 1
    }

    . $UtilsPath
}
catch {
    Write-Error "Failed to initialize utilities: $($_.Exception.Message)"
    exit 1
}

# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.14" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.5" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.5.2" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.14.4-1" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.4.3" }
$WAZUH_AGENT_REPO_VERSION = if ($env:WAZUH_AGENT_REPO_VERSION) { $env:WAZUH_AGENT_REPO_VERSION } else { "1.8.1" }

# Repo ref variables for components
$WAZUH_CERT_OAUTH2_REPO_REF = if ($env:WAZUH_CERT_OAUTH2_REPO_REF) { $env:WAZUH_CERT_OAUTH2_REPO_REF } else { "refs/tags/v$WOPS_VERSION" }
$WAZUH_YARA_REPO_REF = if ($env:WAZUH_YARA_REPO_REF) { $env:WAZUH_YARA_REPO_REF } else { "refs/tags/v$WAZUH_YARA_VERSION" }
$WAZUH_SNORT_REPO_REF = if ($env:WAZUH_SNORT_REPO_REF) { $env:WAZUH_SNORT_REPO_REF } else { "main" }
$WAZUH_SURICATA_REPO_REF = if ($env:WAZUH_SURICATA_REPO_REF) { $env:WAZUH_SURICATA_REPO_REF } else { "refs/tags/v$WAZUH_SURICATA_VERSION" }
$WAZUH_TRIVY_REPO_REF = if ($env:WAZUH_TRIVY_REPO_REF) { $env:WAZUH_TRIVY_REPO_REF } else { "main" }
$WAZUH_AGENT_STATUS_REPO_REF = if ($env:WAZUH_AGENT_STATUS_REPO_REF) { $env:WAZUH_AGENT_STATUS_REPO_REF } else { "refs/tags/v$WAZUH_AGENT_STATUS_VERSION" }
$WAZUH_AGENT_REPO_REF = if ($env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF } elseif ($WAZUH_AGENT_REPO_VERSION -eq "main") { "main" } else { "refs/tags/v$WAZUH_AGENT_REPO_VERSION" }
# Global array to track uninstaller files
$global:UninstallerFiles = @()

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
    Write-Host "Usage:  .\uninstall-agent.ps1 [-UninstallTrivy] [-UninstallNetBird] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script automates the uninstallation of various Wazuh components and related tools." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -UninstallTrivy        : Optionally uninstalls the Trivy vulnerability scanner." -ForegroundColor Cyan
    Write-Host "  -UninstallNetBird       : Optionally uninstalls the NetBird VPN/mesh-network client." -ForegroundColor Cyan
    Write-Host "  -Help                  : Displays this help message." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment Variables (optional):" -ForegroundColor Cyan
    Write-Host "  LOG_LEVEL                : Sets the logging level (e.g., INFO, DEBUG). Default: INFO" -ForegroundColor Cyan
    Write-Host "  WAZUH_YARA_VERSION       : Sets the Wazuh YARA module version. Default: $WAZUH_YARA_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_SURICATA_VERSION   : Sets the Wazuh Suricata module version. Default: $WAZUH_SURICATA_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_STATUS_VERSION: Sets the Wazuh Agent Status module version. Default: $WAZUH_AGENT_STATUS_VERSION" -ForegroundColor Cyan
    Write-Host "  WAZUH_AGENT_VERSION      : Sets the Wazuh Agent version. Default: $WAZUH_AGENT_VERSION" -ForegroundColor Cyan
    Write-Host "  WOPS_VERSION             : Sets the WOPS client version. Default: $WOPS_VERSION" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\uninstall-agent.ps1 -Help" -ForegroundColor Cyan
    Write-Host "  $env:LOG_LEVEL='DEBUG'; .\uninstall-agent.ps1" -ForegroundColor Cyan
    Write-Host ""
}



# Show help if -Help is specified
if ($Help) {
    Show-Help
    exit 0
}

# Step 1: Download and Uninstall Wazuh Agent Status with error handling
function Uninstall-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/$WAZUH_AGENT_STATUS_REPO_REF/scripts/windows/uninstall.ps1"
    $AgentStatusScript = "$env:TEMP\uninstall-agent-status.ps1"
    $global:UninstallerFiles += $AgentStatusScript
    try {
        Download-And-VerifyFile -Url $AgentStatusUrl -Destination $AgentStatusScript -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "Wazuh Agent Status uninstall script" -ChecksumUrl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/$WAZUH_AGENT_STATUS_REPO_REF/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Agent Status Uninstallation: $($_.Exception.Message)"
    }
}

# Step 2: Download and Uninstall YARA with error handling
function Uninstall-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/$WAZUH_YARA_REPO_REF/scripts/uninstall.ps1"
    $YaraScript = "$env:TEMP\uninstall-yara.ps1"
    $global:UninstallerFiles += $YaraScript
    try {
        Download-File -Url $YaraUrl -Destination $YaraScript -Description "YARA uninstall script"
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during YARA Uninstallation: $($_.Exception.Message)"
    }
}

# Step 3: Download and Uninstall Snort with error handling
function Uninstall-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/scripts/windows/uninstall.ps1"
    $SnortScript = "$env:TEMP\uninstall-snort.ps1"
    $global:UninstallerFiles += $SnortScript
    try {
        Download-And-VerifyFile -Url $SnortUrl -Destination $SnortScript -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "Snort uninstall script" -ChecksumUrl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/$WAZUH_SNORT_REPO_REF/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Snort Uninstallation: $($_.Exception.Message)"
    }
}

# Step 4: Download and Uninstall Suricata with error handling
function Uninstall-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/$WAZUH_SURICATA_REPO_REF/scripts/uninstall.ps1"
    $SuricataScript = "$env:TEMP\uninstall-suricata.ps1"
    $global:UninstallerFiles += $SuricataScript
    try {
        Download-File -Url $SuricataUrl -Destination $SuricataScript -Description "Suricata uninstall script"
        & powershell.exe -ExecutionPolicy Bypass -File $SuricataScript -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Suricata Uninstallation: $($_.Exception.Message)"
    }
}

# Step 5: Download and Uninstall NetBird with error handling
function Uninstall-NetBird {
    if (-not $UninstallNetBird) { return }

    SectionSeparator "Uninstalling NetBird"
    # NetBird NSIS installer uses lowercase 'b' in registry key and install dir.
    $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Netbird"
    $uninstallExe = "C:\Program Files\Netbird\netbird_uninstall.exe"
    $detected = $false

    if (Test-Path $regKey) { $detected = $true }
    elseif (Test-Path $uninstallExe) { $detected = $true }

    if (-not $detected) {
        InfoMessage "NetBird not found; skipping."
        return
    }

    try {
        # Silent uninstall via the NSIS uninstaller (/S).
        # The uninstaller itself runs `netbird service stop` + `netbird service uninstall`.
        if (Test-Path $uninstallExe) {
            Start-Process -FilePath $uninstallExe -ArgumentList "/S" -Wait -ErrorAction Stop
        } else {
            # Fall back to the registry UninstallString
            $uninstallStr = (Get-ItemProperty $regKey).UninstallString
            if ($uninstallStr) { Start-Process -FilePath $uninstallStr -ArgumentList "/S" -Wait -ErrorAction Stop }
        }
        # Silent uninstall preserves C:\ProgramData\Netbird; purge explicitly.
        if (Test-Path "C:\ProgramData\Netbird") {
            Remove-Item -Recurse -Force "C:\ProgramData\Netbird" -ErrorAction SilentlyContinue
        }
        SuccessMessage "NetBird uninstalled successfully."
    }
    catch {
        ErrorMessage "Error during NetBird uninstallation: $($_.Exception.Message)"
    }
}

# Step 6: Download and execute Wazuh agent uninstall script with error handling
function Uninstall-WazuhAgent {
    $UninstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF/scripts/windows/uninstall.ps1"
    $UninstallerPath = "$env:TEMP\uninstall-wazuh-agent.ps1"
    $global:UninstallerFiles += $UninstallerPath
    try {
        Download-And-VerifyFile -Url $UninstallerURL -Destination $UninstallerPath -ChecksumPattern "scripts/windows/uninstall.ps1" -FileName "Wazuh agent uninstall script" -ChecksumUrl "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$WAZUH_AGENT_REPO_REF/checksums.sha256"
        & powershell.exe -ExecutionPolicy Bypass -File $UninstallerPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Error during Wazuh agent Uninstallation: $($_.Exception.Message)"
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
    Uninstall-NetBird
    SectionSeparator "Uninstalling Wazuh Agent"
    Uninstall-WazuhAgent
}
finally {
    InfoMessage "Cleaning up uninstaller files..."
    Cleanup-Uninstallers
    SuccessMessage "Wazuh Agent Uninstallation Completed Successfully"
}