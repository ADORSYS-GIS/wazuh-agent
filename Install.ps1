<#
.SYNOPSIS
    Wazuh Agent Bootstrap Installer for Windows

.DESCRIPTION
    Downloads, verifies, and executes the Wazuh Agent setup script.
    Ensures integrity of downloaded scripts using SHA256 checksum verification.

.PARAMETER InstallSuricata
    Install Suricata as the NIDS engine (default if no NIDS specified)

.PARAMETER InstallSnort
    Install Snort as the NIDS engine

.PARAMETER SkipVerify
    Skip checksum verification (not recommended)

.EXAMPLE
    # Run directly from GitHub:
    irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1 | iex

    # Or download and run with options:
    .\install.ps1 -InstallSuricata

.NOTES
    Environment Variables:
      WAZUH_MANAGER       - Wazuh Manager address (required)
      WAZUH_AGENT_VERSION - Agent version (default: 4.13.1-1)
#>

param(
    [switch]$InstallSuricata,
    [switch]$InstallSnort,
    [switch]$SkipVerify,
    [switch]$Help
)

# =============================================================================
# Configuration
# =============================================================================
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
$Version = if ($env:WAZUH_AGENT_REPO_VERSION) { $env:WAZUH_AGENT_REPO_VERSION } else { "main" }
$ScriptName = "setup-agent.ps1"
$ChecksumsFile = "checksums.sha256"

# =============================================================================
# Functions
# =============================================================================

function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage {
    param([string]$Message)
    Log "[INFO]" $Message "Cyan"
}

function SuccessMessage {
    param([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function WarningMessage {
    param([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function ErrorMessage {
    param([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function Get-FileChecksum {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

function Test-Checksum {
    param(
        [string]$FilePath,
        [string]$ExpectedHash
    )

    $actualHash = Get-FileChecksum -FilePath $FilePath

    if ($actualHash -ne $ExpectedHash.ToLower()) {
        ErrorMessage "Checksum verification FAILED!"
        ErrorMessage "  Expected: $ExpectedHash"
        ErrorMessage "  Got:      $actualHash"
        ErrorMessage ""
        ErrorMessage "The downloaded file may have been tampered with."
        ErrorMessage "Please report this to the security team immediately."
        return $false
    }

    SuccessMessage "Checksum verified successfully"
    return $true
}

function Show-Help {
    Write-Host @"
Wazuh Agent Bootstrap Installer
================================

Usage:
  .\install.ps1 [-InstallSuricata] [-InstallSnort] [-SkipVerify] [-Help]

  Or run directly from GitHub:
  irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1 | iex

Parameters:
  -InstallSuricata  Install Suricata as NIDS (default)
  -InstallSnort     Install Snort as NIDS
  -SkipVerify       Skip checksum verification (not recommended)
  -Help             Show this help message

Environment Variables:
  WAZUH_MANAGER       Wazuh Manager address (REQUIRED)
  WAZUH_AGENT_VERSION Agent version (default: 4.13.1-1)

Examples:
  # Set manager and run
  `$env:WAZUH_MANAGER = "wazuh.company.com"
  .\install.ps1 -InstallSuricata

  # One-liner from web
  `$env:WAZUH_MANAGER = "wazuh.company.com"; irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/install.ps1 | iex

"@ -ForegroundColor Cyan
}

# =============================================================================
# Main
# =============================================================================

if ($Help) {
    Show-Help
    exit 0
}

InfoMessage "Wazuh Agent Bootstrap Installer"
InfoMessage "================================"
Write-Host ""

# Check for WAZUH_MANAGER
$WazuhManager = $env:WAZUH_MANAGER
if ([string]::IsNullOrWhiteSpace($WazuhManager) -or $WazuhManager -eq "wazuh.example.com") {
    WarningMessage "WAZUH_MANAGER is not set or using default placeholder"
    WarningMessage "Please set WAZUH_MANAGER environment variable:"
    WarningMessage '  $env:WAZUH_MANAGER = "your-wazuh-manager.com"'
    Write-Host ""
}

# Create temporary directory
$TempDir = Join-Path $env:TEMP "wazuh-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
InfoMessage "Using temporary directory: $TempDir"

try {
    # Determine URLs
    $scriptUrl = "$RepoUrl/$Version/scripts/$ScriptName"
    $checksumsUrl = "$RepoUrl/$Version/checksums.sha256"

    # Download checksums file
    InfoMessage "Downloading checksums..."
    $checksumsPath = Join-Path $TempDir $ChecksumsFile
    try {
        Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -ErrorAction Stop
    }
    catch {
        WarningMessage "Could not download checksums file: $($_.Exception.Message)"
        if (-not $SkipVerify) {
            ErrorMessage "Verification required. Use -SkipVerify to bypass (not recommended)"
            exit 1
        }
    }

    # Download setup script
    InfoMessage "Downloading $ScriptName..."
    $scriptPath = Join-Path $TempDir $ScriptName
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
    }
    catch {
        ErrorMessage "Failed to download ${ScriptName}: $($_.Exception.Message)"
        exit 1
    }

    # Download utils.ps1
    InfoMessage "Downloading utils.ps1..."
    try {
        Invoke-WebRequest -Uri "$RepoUrl/$Version/scripts/utils.ps1" -OutFile (Join-Path $TempDir "utils.ps1") -ErrorAction Stop
    }
    catch {
        WarningMessage "Could not download utils.ps1: $($_.Exception.Message)"
    }

    # Verify checksum
    if ((Test-Path $checksumsPath) -and (-not $SkipVerify)) {
        InfoMessage "Verifying script integrity..."

        # Read checksums file and find our script
        $checksumLines = Get-Content $checksumsPath
        $expectedHash = $null

        foreach ($line in $checksumLines) {
            if ($line -match "scripts/$ScriptName") {
                $expectedHash = ($line -split '\s+')[0]
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($expectedHash)) {
            WarningMessage "No checksum found for $ScriptName in checksums file"
            WarningMessage "Proceeding without verification..."
        }
        else {
            if (-not (Test-Checksum -FilePath $scriptPath -ExpectedHash $expectedHash)) {
                ErrorMessage "Aborting installation due to checksum mismatch"
                exit 1
            }
        }
    }
    elseif ($SkipVerify) {
        WarningMessage "Skipping verification (-SkipVerify specified)"
    }

    # Build arguments for setup script
    $setupArgs = @()
    if ($InstallSuricata) { $setupArgs += "-InstallSuricata" }
    if ($InstallSnort) { $setupArgs += "-InstallSnort" }

    # Execute setup script
    InfoMessage "Executing $ScriptName..."
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Magenta
    Write-Host ""

    # Run with elevated privileges if needed
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        WarningMessage "Requesting administrator privileges..."
        $argString = if ($setupArgs.Count -gt 0) { $setupArgs -join ' ' } else { '' }
        # Pass WAZUH_AGENT_REPO_REF to the new process
        $envString = "[System.Environment]::SetEnvironmentVariable('WAZUH_AGENT_REPO_REF', '$($env:WAZUH_AGENT_REPO_REF)', 'Process');"
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -Command `"$envString & `"$scriptPath`" $argString`"" -Verb RunAs -Wait
    }
    else {
        & powershell.exe -ExecutionPolicy Bypass -File $scriptPath @setupArgs
    }
}
finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
