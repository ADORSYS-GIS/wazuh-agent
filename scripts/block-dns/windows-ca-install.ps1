# =============================================================================
# Company Root CA — Windows device installer
#
# Installs the Company Root CA (CN=root-ca, O=Company) into the Windows
# Certificate Store (Local Machine > Trusted Root Certification Authorities),
# which is the trust store used by Chrome, Edge and most system TLS consumers,
# and REMOVES any retired block-page root CA it finds there.
#
# Safety model:
#   * The expected SHA-256 fingerprint is PINNED below. The script refuses to
#     install anything that does not match it (fail-closed).
#   * The store is verified AFTER install — the fingerprint of what actually
#     landed in the store must match the pin.
#   * Retired CAs (old AdORSYS block-page root, previous company roots) are
#     removed by FINGERPRINT/SUBJECT, not by label, so they are always cleaned
#     up even if installed under a different name.
#   * Idempotent: re-running is a no-op when the pinned CA is already present.
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
#   .\windows-ca-install.ps1 -Check                       # validate only, no install
#
# Environment variables:
#   CA_BRANCH  — Git branch to fetch the cert from (default: main)
#   CA_CRT     — Path to a local .crt file (skips fetch if set)
# =============================================================================

param(
    [string]$CABranch = $env:CA_BRANCH,
    [string]$CACrt = $env:CA_CRT,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Die   { Write-Host "[ERROR] $args" -ForegroundColor Red; exit 1 }

# --- Pinned trust anchor -----------------------------------------------------
# SHA-256 fingerprint (lowercase, no colons) of the ONLY root CA we install.
# When the CA is rotated, update this pin AND add the old fingerprint to
# $RetiredSha256 below — the script then replaces old with new everywhere.
$ExpectedSha256 = "3bcd29906e384d66452171fc37f61d74b02ce22c407e5dcd6da85ce7dd2a5477"
$ExpectedCn = "root-ca"

# Retired block-page root CAs — removed from the store, by fingerprint.
$RetiredSha256 = @(
    "43623b8212aaedd1045317b7a17257f11082b36969e1d78ceeff76f3cfcc3885"  # AdORSYS Block Page Root CA
)
# Retired subjects (wildcard match) — belt & braces for CAs whose fingerprint
# is not in the list above.
$RetiredSubjects = @(
    "*AdORSYS Block Page Root CA*"
)

$GithubRawUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent"
$CertPathInRepo = "scripts/block-dns/company-root-ca.crt"

$CertStore = "Cert:\LocalMachine\Root"

# --- Admin check ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator - LocalMachine store writes require elevation."
    Write-Warn "Re-run this script from an elevated PowerShell (Run as Administrator)."
}

# --- Helpers -----------------------------------------------------------------
function Get-CertSha256 {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Cert.RawData)
        return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Test-IsCa {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    foreach ($ext in $Cert.Extensions) {
        if ($ext.Oid.Value -eq "2.5.29.19") {
            $bc = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]$ext
            if ($bc.CertificateAuthority) { return $true }
        }
    }
    return $false
}

function Test-Retired {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    $fp = Get-CertSha256 $Cert
    if ($RetiredSha256 -contains $fp) { return $true }
    foreach ($s in $RetiredSubjects) {
        if ($Cert.Subject -like $s) { return $true }
    }
    return $false
}

function Test-Pinned {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    return ((Get-CertSha256 $Cert) -eq $ExpectedSha256)
}

# Parse a PEM file into an X509Certificate2 (works on PS 5.1 / .NET Framework,
# whose constructor does not accept PEM directly).
function Get-CertFromPem {
    param([string]$Path)
    $pem = Get-Content $Path -Raw
    $b64 = ($pem -replace "-----BEGIN CERTIFICATE-----", "") -replace "-----END CERTIFICATE-----", ""
    $b64 = $b64 -replace "\s", ""
    $bytes = [Convert]::FromBase64String($b64)
    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
}

# --- Step 1: Obtain the CA certificate ---------------------------------------
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

        Write-Info "Certificate fetched successfully"
        $CertFile = $TempFile
    }

    # --- Step 2: Validate the certificate against the pin (fail-closed) ------
    $cert = Get-CertFromPem $CertFile
    $fp = Get-CertSha256 $cert

    if ($fp -ne $ExpectedSha256) {
        Write-Die "Fingerprint mismatch - refusing to install.`n  expected: $ExpectedSha256  ($ExpectedCn)`n  got     : $fp`nIf the CA was rotated, update ExpectedSha256 in this script."
    }
    if (-not (Test-IsCa $cert)) {
        Write-Die "Not a CA certificate (Basic Constraints CA:TRUE missing)."
    }
    Write-Info "Fingerprint verified: $fp"

    if ($Check) {
        Write-Info "OK - $CertFile is the pinned Company Root CA ($ExpectedCn)"
        exit 0
    }

    # --- Step 3: Remove retired CAs ------------------------------------------
    foreach ($c in @(Get-ChildItem $CertStore)) {
        if (Test-Retired $c) {
            Write-Warn "Removing retired CA: $($c.Subject) ($($c.Thumbprint))"
            Remove-Item "Cert:\LocalMachine\Root\$($c.Thumbprint)" -Force -ErrorAction SilentlyContinue
        }
    }

    # --- Step 4: Install (idempotent) ----------------------------------------
    $pinned = @(Get-ChildItem $CertStore | Where-Object { Test-Pinned $_ })
    if ($pinned.Count -gt 0) {
        Write-Info "Company Root CA already trusted - skipping import."
    }
    else {
        try {
            Import-Certificate -FilePath $CertFile -CertStoreLocation $CertStore | Out-Null
            Write-Info "Certificate imported."
        }
        catch {
            Write-Die "Failed to import certificate into $CertStore. Run as Administrator. Details: $($_.Exception.Message)"
        }
    }

    # --- Step 5: Verify AFTER install ----------------------------------------
    $pinned = @(Get-ChildItem $CertStore | Where-Object { Test-Pinned $_ })
    if ($pinned.Count -gt 0) {
        Write-Info "Verified in $CertStore (fingerprint match)."
    }
    else {
        Write-Die "Verification failed: The pinned CA is not present in the Trusted Root Certification Authorities store."
    }

    Write-Info "Company Root CA installed successfully"
}
finally {
    # Cleanup temp file
    if ($TempFile -and (Test-Path $TempFile)) {
        Remove-Item $TempFile -Force
    }
}