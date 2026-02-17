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
    irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1 | iex

    # Or download and run with options:
    .\Install.ps1 -InstallSuricata

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

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
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
        Write-LogError "Checksum verification FAILED!"
        Write-LogError "  Expected: $ExpectedHash"
        Write-LogError "  Got:      $actualHash"
        Write-LogError ""
        Write-LogError "The downloaded file may have been tampered with."
        Write-LogError "Please report this to the security team immediately."
        return $false
    }

    Write-LogSuccess "Checksum verified successfully"
    return $true
}

function Show-Help {
    Write-Host @"
Wazuh Agent Bootstrap Installer
================================

Usage:
  .\Install.ps1 [-InstallSuricata] [-InstallSnort] [-SkipVerify] [-Help]

  Or run directly from GitHub:
  irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1 | iex

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
  .\Install.ps1 -InstallSuricata

  # One-liner from web
  `$env:WAZUH_MANAGER = "wazuh.company.com"; irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/Install.ps1 | iex

"@ -ForegroundColor Cyan
}

# =============================================================================
# Main
# =============================================================================

if ($Help) {
    Show-Help
    exit 0
}

Write-LogInfo "Wazuh Agent Bootstrap Installer"
Write-LogInfo "================================"
Write-Host ""

# Check for WAZUH_MANAGER
$WazuhManager = $env:WAZUH_MANAGER
if ([string]::IsNullOrWhiteSpace($WazuhManager) -or $WazuhManager -eq "wazuh.example.com") {
    Write-LogWarning "WAZUH_MANAGER is not set or using default placeholder"
    Write-LogWarning "Please set WAZUH_MANAGER environment variable:"
    Write-LogWarning '  $env:WAZUH_MANAGER = "your-wazuh-manager.com"'
    Write-Host ""
}

# Create temporary directory
$TempDir = Join-Path $env:TEMP "wazuh-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-LogInfo "Using temporary directory: $TempDir"

try {
    # Determine URLs
    $scriptUrl = "$RepoUrl/$Version/scripts/$ScriptName"
    $checksumsUrl = "$RepoUrl/$Version/checksums.sha256"

    # Download checksums file
    Write-LogInfo "Downloading checksums..."
    $checksumsPath = Join-Path $TempDir $ChecksumsFile
    try {
        Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -ErrorAction Stop
    }
    catch {
        Write-LogWarning "Could not download checksums file: $($_.Exception.Message)"
        if (-not $SkipVerify) {
            Write-LogError "Verification required. Use -SkipVerify to bypass (not recommended)"
            exit 1
        }
    }

    # Download setup script
    Write-LogInfo "Downloading $ScriptName..."
    $scriptPath = Join-Path $TempDir $ScriptName
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
    }
    catch {
        Write-LogError "Failed to download ${ScriptName}: $($_.Exception.Message)"
        exit 1
    }

    # Verify checksum
    if ((Test-Path $checksumsPath) -and (-not $SkipVerify)) {
        Write-LogInfo "Verifying script integrity..."

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
            Write-LogWarning "No checksum found for $ScriptName in checksums file"
            Write-LogWarning "Proceeding without verification..."
        }
        else {
            if (-not (Test-Checksum -FilePath $scriptPath -ExpectedHash $expectedHash)) {
                Write-LogError "Aborting installation due to checksum mismatch"
                exit 1
            }
        }
    }
    elseif ($SkipVerify) {
        Write-LogWarning "Skipping verification (-SkipVerify specified)"
    }

    # Build arguments for setup script
    $setupArgs = @()
    if ($InstallSuricata) { $setupArgs += "-InstallSuricata" }
    if ($InstallSnort) { $setupArgs += "-InstallSnort" }

    # Execute setup script
    Write-LogInfo "Executing $ScriptName..."
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Magenta
    Write-Host ""

    # Run with elevated privileges if needed
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-LogWarning "Requesting administrator privileges..."
        $argString = if ($setupArgs.Count -gt 0) { $setupArgs -join ' ' } else { '' }
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $argString" -Verb RunAs -Wait
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
