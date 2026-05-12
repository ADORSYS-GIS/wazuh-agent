param(
    [string]$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent",
    [string]$Ref = $env:WAZUH_AGENT_REPO_REF
)

if (-not $Ref) { $Ref = 'main' }

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Decide remote path depending on OS
$remotePath = 'scripts/windows/setup-agent.ps1'

$tmp = Join-Path -Path $env:TEMP -ChildPath "wazuh_setup_$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $checksumsUrl = "$RepoUrl/$Ref/checksums.sha256"
    $scriptUrl = "$RepoUrl/$Ref/$remotePath"
    $checksumsPath = Join-Path $tmp 'checksums.sha256'
    $scriptPath = Join-Path $tmp 'remote_setup.ps1'

    Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop

    $expected = (Select-String -Path $checksumsPath -Pattern [regex]::Escape($remotePath) -SimpleMatch).Line.Split(' ')[0]
    $actual = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash.ToLower()

    if ([string]::IsNullOrWhiteSpace($expected) -or $expected -ne $actual) {
        Write-Error "Checksum verification failed for $remotePath"
        exit 1
    }

    & $scriptPath @args
} finally {
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
}
