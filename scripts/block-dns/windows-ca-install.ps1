# =============================================================================
# AdORSYS Block-Page CA — Windows device installer
#
# Installs the AdORSYS Block Page Root CA into the Windows Certificate Store
# (Local Machine > Trusted Root Certification Authorities), which is the trust
# store used by Chrome, Edge and most system TLS consumers.
#
# NOTE: Firefox is NOT supported for now (not allowed in the company).
# Firefox uses its own NSS store and would need separate handling — revisit later.
#
# Requirements:
#   - Windows PowerShell 5.1+ (or PowerShell 7+)
#   - Administrator privileges (for LocalMachine store writes)
#
# Usage (run as Administrator):
#   .\windows-ca-install.ps1
#   $env:CA_BRANCH = "dns-block"; .\windows-ca-install.ps1
#   .\windows-ca-install.ps1 -CABranch dns-block
#   .\windows-ca-install.ps1 -CACrt C:\path\to\ca.crt   # override: local file
#
# Environment variables:
#   CA_BRANCH  — Git branch to fetch the cert from (default: main)
#   CA_CRT     — Path to a local .crt file (skips fetch if set)
# =============================================================================

param(
    [string]$CABranch = $env:CA_BRANCH,
    [string]$CACrt = $env:CA_CRT
)

$ErrorActionPreference = 'Stop'

function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Die   { Write-Host "[ERROR] $args" -ForegroundColor Red; exit 1 }

# GitHub raw content base URL for the certificate
$GithubRawUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
$CertPathInRepo = "scripts/block-dns/adorsys-block-page-ca.crt"

$CertStore = "Cert:\LocalMachine\Root"
$CertLabel = "AdORSYS Block Page Root CA"

# --- Admin check ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator - LocalMachine store writes require elevation."
    Write-Warn "Re-run this script from an elevated PowerShell (Run as Administrator)."
}

# --- Step 1: Obtain the CA certificate ---
if (-not $CABranch) { $CABranch = "main" }

$CertFile = $null
$TempFile = $null

try {
    if ($CACrt) {
        # User provided a local file - use it directly
        Write-Info "Using local certificate file: $CACrt"
        $CertFile = $CACrt
        if (-not (Test-Path $CertFile)) { Write-Die "CA file not found: $CertFile" }
    }
    else {
        # Fetch from GitHub
        $FetchUrl = "$GithubRawUrl/$CABranch/$CertPathInRepo"
        Write-Info "Fetching certificate from GitHub (branch: $CABranch)..."
        Write-Info "URL: $FetchUrl"

        $TempFile = [System.IO.Path]::GetTempFileName() + ".crt"
        try {
            Invoke-WebRequest -Uri $FetchUrl -OutFile $TempFile -UseBasicParsing
        }
        catch {
            Write-Die "Failed to fetch certificate. Check branch '$CABranch' and try again."
        }

        # Validate the downloaded file
        $content = Get-Content $TempFile -Raw
        if (-not $content.Contains("BEGIN CERTIFICATE")) {
            Write-Die "Downloaded file is not a valid PEM certificate."
        }

        Write-Info "Certificate fetched successfully"
        Write-Info "Stored temporarily at: $TempFile"
        $CertFile = $TempFile
    }

    # --- Step 2: Validate it looks like a certificate ---
    $content = Get-Content $CertFile -Raw
    if (-not $content.Contains("BEGIN CERTIFICATE")) {
        Write-Die "File does not look like a certificate: $CertFile"
    }

    # --- Step 3: Install into Local Machine > Trusted Root Certification Authorities ---
    Write-Info "Installing into $CertStore using certutil..."

    # Remove any previous copy to avoid duplicates
    try {
        # We suppress errors here because if the cert isn't found, certutil will output an error which is fine
        & certutil.exe -delstore root $CertLabel *>&1 | Out-Null
    } catch {}

    # Import the certificate into the store
    $importOutput = & certutil.exe -addstore root $CertFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Die "Failed to import certificate: $importOutput"
    }

    Write-Info "Certificate successfully imported."

    # --- Step 4: Verify ---
    $verifyOutput = & certutil.exe -store root $CertLabel 2>&1
    if ($LASTEXITCODE -eq 0 -and $verifyOutput -match $CertLabel) {
        Write-Info "Verified in $CertStore : $CertLabel"
    }
    else {
        Write-Die "Verification failed: The CA is not present in the Trusted Root Certification Authorities store."
    }

    Write-Info "AdORSYS Block-Page CA installed successfully"
}
finally {
    # Cleanup temp file
    if ($TempFile -and (Test-Path $TempFile)) {
        Remove-Item $TempFile -Force
    }
}