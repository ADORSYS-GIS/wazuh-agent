# Common Paths
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$APP_DATA = "C:\ProgramData\ossec-agent\"

# Function for logging with timestamp
function Log {
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

function Download-File {
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
                WarnMessage "Download failed, retrying ($attempt/$MaxRetries)..."
                Start-Sleep -Seconds 2
            }
        }
    }

    ErrorExit "Failed to download $Description from $Url after $MaxRetries attempts"
}

function Download-And-VerifyFile {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ChecksumPattern,
        [string]$FileName = "Unknown file",
        [string]$ChecksumFile = $global:ChecksumsPath,
        [string]$ChecksumUrl = $global:ChecksumsURL
    )

    Download-File -Url $Url -Destination $Destination -Description $FileName

    # If a direct checksum URL is provided, download it and use it as the source of truth
    if (-not [string]::IsNullOrWhiteSpace($ChecksumUrl)) {
        $tempChecksumFile = Join-Path ([System.IO.Path]::GetTempPath()) "checksums-$([System.Guid]::NewGuid().ToString()).sha256"
        try {
            Download-File -Url $ChecksumUrl -Destination $tempChecksumFile -Description "checksum file"
            $ChecksumFile = $tempChecksumFile

            if (-not [string]::IsNullOrWhiteSpace($ChecksumFile) -and (Test-Path -Path $ChecksumFile)) {
                $expectedHash = (Select-String -Path $ChecksumFile -Pattern $ChecksumPattern).Line.Split(" ")[0].Trim()
                if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
                    if (-not (Test-Checksum -FilePath $Destination -ExpectedHash $expectedHash)) {
                        ErrorExit "$FileName checksum verification failed"
                    }
                    InfoMessage "$FileName checksum verification passed."
                } else {
                    ErrorExit "No checksum found for $FileName in $ChecksumFile using pattern $ChecksumPattern"
                }
            } else {
                ErrorExit "Checksum file not found at $ChecksumFile, cannot verify $FileName"
            }
        } finally {
            # Cleanup temporary checksum file if it was created
            if (Test-Path -Path $tempChecksumFile) {
                Remove-Item -Path $tempChecksumFile -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        if (-not [string]::IsNullOrWhiteSpace($ChecksumFile) -and (Test-Path -Path $ChecksumFile)) {
            $expectedHash = (Select-String -Path $ChecksumFile -Pattern $ChecksumPattern).Line.Split(" ")[0].Trim()
            if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
                if (-not (Test-Checksum -FilePath $Destination -ExpectedHash $expectedHash)) {
                    ErrorExit "$FileName checksum verification failed"
                }
                InfoMessage "$FileName checksum verification passed."
            } else {
                ErrorExit "No checksum found for $FileName in $ChecksumFile using pattern $ChecksumPattern"
            }
        } else {
            ErrorExit "Checksum file not found at $ChecksumFile, cannot verify $FileName"
        }
    }

    SuccessMessage "$FileName downloaded and verified successfully."
    return $true
}

# Ensure the script is running with administrator privileges
function EnsureAdmin {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        ErrorExit "This script requires administrative privileges. Please run it as Administrator."
    }
}