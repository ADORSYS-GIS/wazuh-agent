# Common Paths
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$APP_DATA = "C:\ProgramData\ossec-agent\"

# Function for logging with timestamp
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
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    $success = $false
    
    while ($retryCount -lt $MaxRetries -and -not $success) {
        $retryCount++
        try {
            # Ensure destination directory exists
            $destDir = Split-Path -Path $Destination
            if (-not (Test-Path -Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Invoke-WebRequest -Uri $Url -OutFile $Destination -ErrorAction Stop
            
            # Verify file is not empty
            if ((Get-Item $Destination).Length -gt 0) {
                $success = $true
            } else {
                WarningMessage "Downloaded file is empty, retrying... (attempt $retryCount/$MaxRetries)"
                Remove-Item -Path $Destination -Force
            }
        }
        catch {
            if ($retryCount -lt $MaxRetries) {
                WarningMessage "Failed to download $Url, retrying... (attempt $retryCount/$MaxRetries): $($_.Exception.Message)"
                Start-Sleep -Seconds 2
            } else {
                ErrorMessage "Failed to download $Url after $MaxRetries attempts: $($_.Exception.Message)"
            }
        }
    }
    
    return $success
}

function Download-And-VerifyFile {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ChecksumPattern,
        [string]$FileName = "Unknown file",
        [string]$ChecksumFile = $global:ChecksumsPath,
        [string]$ChecksumUrl = $null
    )
    
    if (-not (Download-File -Url $Url -Destination $Destination)) {
        ErrorExit "Failed to download $FileName from $Url"
    }
    
    # If a direct checksum URL is provided, download it and use it as the source of truth
    if (-not [string]::IsNullOrWhiteSpace($ChecksumUrl)) {
        $tempChecksumFile = Join-Path ([System.IO.Path]::GetTempPath()) "checksums-$([System.Guid]::NewGuid().ToString()).sha256"
        if (-not (Download-File -Url $ChecksumUrl -Destination $tempChecksumFile)) {
            ErrorExit "Failed to download external checksum file from $ChecksumUrl"
        }
        $ChecksumFile = $tempChecksumFile
    }
    
    if (-not [string]::IsNullOrWhiteSpace($ChecksumFile) -and (Test-Path -Path $ChecksumFile)) {
        $expectedHash = (Select-String -Path $ChecksumFile -Pattern $ChecksumPattern).Line.Split(" ")[0]
        if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
            if (-not (Test-Checksum -FilePath $Destination -ExpectedHash $expectedHash)) {
                ErrorExit "$FileName checksum verification failed"
            }
            InfoMessage "$FileName checksum verification passed."
        } else {
            ErrorExit "No checksum found for $FileName in $ChecksumFile using pattern $ChecksumPattern"
        }
        
        # Cleanup temporary checksum file if it was downloaded from a URL
        if (-not [string]::IsNullOrWhiteSpace($ChecksumUrl) -and (Test-Path -Path $ChecksumFile)) {
            Remove-Item -Path $ChecksumFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        ErrorExit "Checksum file not found at $ChecksumFile, cannot verify $FileName"
    }
    
    SuccessMessage "$FileName downloaded and verified successfully."
    return $true
}