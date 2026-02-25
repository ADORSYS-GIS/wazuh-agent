#
# Download Verification Module
# Provides checksum verification for secure script downloads
#

function Test-FileChecksum {
    <#
    .SYNOPSIS
        Verifies SHA256 checksum of a file
    .PARAMETER FilePath
        Path to the file to verify
    .PARAMETER ExpectedHash
        Expected SHA256 hash value
    .RETURNS
        $true if checksum matches, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$ExpectedHash
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }

    $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

    if ($actualHash -ne $ExpectedHash.ToUpper()) {
        Write-Error "Checksum verification failed for $FilePath"
        Write-Error "  Expected: $ExpectedHash"
        Write-Error "  Got:      $actualHash"
        return $false
    }

    return $true
}

function Invoke-VerifiedDownload {
    <#
    .SYNOPSIS
        Downloads a file and optionally verifies its checksum
    .PARAMETER Url
        URL to download from
    .PARAMETER Destination
        Local path to save the file
    .PARAMETER ExpectedHash
        Optional SHA256 hash to verify (skip verification if not provided)
    .RETURNS
        $true if download and verification succeed, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$false)]
        [string]$ExpectedHash
    )

    try {
        # Download the file
        Invoke-WebRequest -Uri $Url -OutFile $Destination -ErrorAction Stop

        # Verify checksum if provided
        if ($ExpectedHash) {
            if (-not (Test-FileChecksum -FilePath $Destination -ExpectedHash $ExpectedHash)) {
                Remove-Item -Path $Destination -Force -ErrorAction SilentlyContinue
                return $false
            }
        }

        return $true
    }
    catch {
        Write-Error "Failed to download $Url : $($_.Exception.Message)"
        return $false
    }
}

function Get-RemoteChecksum {
    <#
    .SYNOPSIS
        Fetches checksum from remote checksums file
    .PARAMETER ChecksumsUrl
        URL of the checksums file
    .PARAMETER Filename
        Name of the file to look up
    .RETURNS
        The checksum string if found, $null otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ChecksumsUrl,

        [Parameter(Mandatory=$true)]
        [string]$Filename
    )

    try {
        $checksums = Invoke-WebRequest -Uri $ChecksumsUrl -ErrorAction Stop
        $lines = $checksums.Content -split "`n"

        foreach ($line in $lines) {
            if ($line -match $Filename) {
                $parts = $line -split '\s+'
                return $parts[0]
            }
        }

        return $null
    }
    catch {
        Write-Warning "Failed to fetch checksums from $ChecksumsUrl"
        return $null
    }
}

function Test-WazuhManagerAddress {
    <#
    .SYNOPSIS
        Validates WAZUH_MANAGER address format
    .PARAMETER Manager
        Manager address (hostname or IP)
    .RETURNS
        $true if valid, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Manager
    )

    if ([string]::IsNullOrWhiteSpace($Manager)) {
        Write-Error "WAZUH_MANAGER is required"
        return $false
    }

    # Check for default placeholder
    if ($Manager -eq "wazuh.example.com") {
        Write-Warning "WAZUH_MANAGER is set to default placeholder 'wazuh.example.com'"
        Write-Warning "Please set WAZUH_MANAGER to your actual Wazuh manager address"
    }

    # Validate hostname pattern
    $hostnamePattern = "^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$"
    # Validate IP pattern
    $ipPattern = "^(\d{1,3}\.){3}\d{1,3}$"

    if ($Manager -match $hostnamePattern -or $Manager -match $ipPattern) {
        return $true
    }

    Write-Error "WAZUH_MANAGER has invalid format: $Manager"
    Write-Error "Must be a valid hostname or IP address"
    return $false
}

function Test-VersionFormat {
    <#
    .SYNOPSIS
        Validates version string format
    .PARAMETER Version
        Version string (e.g., 4.13.1-1, 0.3.11)
    .RETURNS
        $true if valid, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    $pattern = "^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$"

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Error "Version is required"
        return $false
    }

    if ($Version -notmatch $pattern) {
        Write-Error "Invalid version format: $Version"
        Write-Error "Expected format: X.Y.Z or X.Y.Z-N"
        return $false
    }

    return $true
}

function Test-HostConnectivity {
    <#
    .SYNOPSIS
        Checks network connectivity to a host
    .PARAMETER Host
        Hostname or IP to check
    .PARAMETER TimeoutSeconds
        Connection timeout in seconds (default: 5)
    .RETURNS
        $true if reachable, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostAddress,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 5
    )

    # Try TCP connection to common Wazuh ports
    $ports = @(1514, 1515, 443)

    foreach ($port in $ports) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $asyncResult = $tcpClient.BeginConnect($HostAddress, $port, $null, $null)
            $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)

            if ($wait -and $tcpClient.Connected) {
                $tcpClient.Close()
                return $true
            }
            $tcpClient.Close()
        }
        catch {
            # Continue to next port
        }
    }

    # Try ping as fallback
    try {
        $ping = Test-Connection -ComputerName $HostAddress -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction Stop
        if ($ping) {
            return $true
        }
    }
    catch {
        # Ping may be blocked
    }

    Write-Warning "Cannot verify connectivity to $HostAddress"
    return $false
}

# Export functions
Export-ModuleMember -Function Test-FileChecksum, Invoke-VerifiedDownload, Get-RemoteChecksum, Test-WazuhManagerAddress, Test-VersionFormat, Test-HostConnectivity
