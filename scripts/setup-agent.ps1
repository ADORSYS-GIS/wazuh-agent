param(
    [string]$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent",
    [string]$Ref = $env:WAZUH_AGENT_REPO_REF
)

if (-not $Ref) { $Ref = 'main' }

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Decide remote path depending on OS
$remotePath = 'scripts/windows/setup-agent.ps1'

# Create a temporary folder
$tmp = Join-Path -Path $env:TEMP -ChildPath "wazuh_setup_$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    $checksumsUrl = "$RepoUrl/$Ref/checksums.sha256"
    $scriptUrl = "$RepoUrl/$Ref/$remotePath"
    $checksumsPath = Join-Path $tmp 'checksums.sha256'
    $scriptPath = Join-Path $tmp 'remote_setup.ps1'

    # Download files
    Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop

    # Verify checksum
    $match = Select-String -Path $checksumsPath -Pattern $remotePath -SimpleMatch

    if ($null -eq $match) {
        Write-Error "Could not find checksum entry for $remotePath"
        exit 1
    }

    $expected = (
        $match | Select-Object -First 1
    ).Line -split '\s+' | Select-Object -First 1
    $expected = $expected.ToLower()

    $actual = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash.ToLower()

    Write-Host "Expected: $expected"
    Write-Host "Actual:   $actual"

    if ($expected -ne $actual) {
        Write-Error "Checksum verification failed for $remotePath"
        exit 1
    }

    # Execute the downloaded script
    & $scriptPath @args
} finally {
    # Clean up temporary folder
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
}
