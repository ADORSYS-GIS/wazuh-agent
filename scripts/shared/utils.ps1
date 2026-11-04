# Common Paths
# NOTE: $OSSEC_PATH, $OSSEC_CONF_PATH and $APP_DATA are intentionally exported as
# script-scope variables. They are consumed by other scripts in this repo that
# dot-source this file (setup-agent.ps1, install.ps1, setup-docker.ps1), so they
# are NOT unused even though PSScriptAnalyzer cannot see the cross-file usage.
# The suppression below is scoped to the variables only.
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$APP_DATA = "C:\ProgramData\ossec-agent\"

# Function for logging with timestamp
# Write-Host is intentional here for colored console output; suppression below.
function Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param (
        [Parameter(Mandatory)]
        [string]$Level,
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

function InfoMessage {
    param ([string]$Message)
    Log -Level "[INFO]" -Message $Message -Color "Cyan"
}

function WarningMessage {
    param ([string]$Message)
    Log -Level "[WARNING]" -Message $Message -Color "Yellow"
}

function SuccessMessage {
    param ([string]$Message)
    Log -Level "[SUCCESS]" -Message $Message -Color "Green"
}

function ErrorMessage {
    param ([string]$Message)
    Log -Level "[ERROR]" -Message $Message -Color "Red"
}

# [Diagnostics.CodeAnalysis.SuppressMessageAttribute] removed for compatibility
# Write-Host is intentional here for colored section separators; suppression below.
function SectionSeparator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param (
        [string]$SectionName
    )
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  $SectionName" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

function ErrorExit {
    param ([string]$Message)
    ErrorMessage $Message
    exit 1
}

function Get-FunctionalPythonPath {
    $candidates = @("python", "python3")
    foreach ($cmd in $candidates) {
        $p = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($p) {
            try {
                # Execute a simple command. Stubs/Aliases often fail or print to stderr
                # with exit code 0 or 1. We check if we can actually get the version.
                $output = & $p.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                if ($LASTEXITCODE -eq 0 -and $output -match "^3\.") {
                    return @{ Path = $p.Source; Version = $output }
                }
            } catch {
                continue
            }
        }
    }
    return $null
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
        ErrorMessage "Checksum verification FAILED for $FilePath!"
        ErrorMessage "  Expected: $ExpectedHash"
        ErrorMessage "  Got:      $actualHash"
        return $false
    }
    return $true
}

# Function name kept for compatibility with dot-sourcing callers; verb not renamed.
function Download-File {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description = "file",
        [int]$MaxRetries = 3
    )

    InfoMessage "Downloading $Description..."

    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
            SuccessMessage "$Description downloaded successfully"
            return
        } catch {
            $attempt++
            if ($attempt -lt $MaxRetries) {
                WarningMessage "Download failed, retrying ($attempt/$MaxRetries)..."
                Start-Sleep -Seconds 2
            }
        }
    }

    ErrorExit "Failed to download $Description from $Url after $MaxRetries attempts"
}

# Function name kept for compatibility with dot-sourcing callers; verb not renamed.
function Verify-FileChecksumWithPattern {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    param(
        [string]$Destination,
        [string]$ChecksumFile,
        [string]$ChecksumPattern,
        [string]$FileName
    )
    if ([string]::IsNullOrWhiteSpace($ChecksumFile) -or -not (Test-Path -Path $ChecksumFile)) {
        ErrorExit "Checksum file not found at $ChecksumFile, cannot verify $FileName"
    }

    $expectedHash = (Select-String -Path $ChecksumFile -Pattern $ChecksumPattern).Line.Split(" ")[0].Trim()
    if ([string]::IsNullOrWhiteSpace($expectedHash)) {
        ErrorExit "No checksum found for $FileName in $ChecksumFile using pattern $ChecksumPattern"
    }

    if (-not (Test-Checksum -FilePath $Destination -ExpectedHash $expectedHash)) {
        ErrorExit "$FileName checksum verification failed"
    }
    InfoMessage "$FileName checksum verification passed."
}

# Function name kept for compatibility with dot-sourcing callers; verb not renamed.
function Download-And-VerifyFile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ChecksumPattern,
        [string]$FileName = "Unknown file",
        [string]$ChecksumFile = $script:ChecksumsPath,
        [string]$ChecksumUrl = $script:ChecksumsURL
    )

    Download-File -Url $Url -Destination $Destination -Description $FileName

    # If a direct checksum URL is provided, download it and use it as the source of truth
    if (-not [string]::IsNullOrWhiteSpace($ChecksumUrl)) {
        $tempChecksumFile = Join-Path ([System.IO.Path]::GetTempPath()) "checksums-$([System.Guid]::NewGuid().ToString()).sha256"
        try {
            Download-File -Url $ChecksumUrl -Destination $tempChecksumFile -Description "checksum file"
            Verify-FileChecksumWithPattern -Destination $Destination -ChecksumFile $tempChecksumFile -ChecksumPattern $ChecksumPattern -FileName $FileName
        } finally {
            if (Test-Path -Path $tempChecksumFile) {
                Remove-Item -Path $tempChecksumFile -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Verify-FileChecksumWithPattern -Destination $Destination -ChecksumFile $ChecksumFile -ChecksumPattern $ChecksumPattern -FileName $FileName
    }

    SuccessMessage "$FileName downloaded and verified successfully."
    return $true
}

# Ensure the script is running with administrator privileges
function EnsureAdmin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        ErrorExit "This script requires administrative privileges. Please run it as Administrator."
    }
}