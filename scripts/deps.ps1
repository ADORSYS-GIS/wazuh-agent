# Function to log messages with a timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp [$Level] $Message"
}

# Logging helpers
function Log-Info {
    param ([string]$Message)
    Log "INFO" $Message
}

function Log-Error {
    param ([string]$Message)
    Log "ERROR" $Message
}

#Function to check if pip module is installed
function Is-ModuleInstalled {
    param (
        [string]$ModuleName
    )
    $result = pip show $ModuleName 2>&1
    if ($result -match "Name:") {
        return $true
    } else {
        return $false
    }
}

function Ensure-Dependencies {
    Log-Info "Ensuring dependencies are installed (curl, jq)"   

    # Check if curl is available
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        Log-Info "curl is not installed. Installing curl..."
        Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1_2/curl-7.79.1_2-win64-mingw.zip" -OutFile "$TEMP_DIR\curl.zip"
        Expand-Archive -Path "$TEMP_DIR\curl.zip" -DestinationPath "$TEMP_DIR\curl"
        Move-Item -Path "$TEMP_DIR\curl\curl-7.79.1_2-win64-mingw\bin\curl.exe" -Destination "C:\Program Files\curl.exe"
        Remove-Item -Path "$TEMP_DIR\curl.zip" -Recurse
        Remove-Item -Path "$TEMP_DIR\curl" -Recurse
        Log-Info "curl installed successfully."

        # Add curl to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        Log-Info "curl added to PATH environment variable."
    }

    # Check if jq is available
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Log-Info "jq is not installed. Installing jq..."
        Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" -OutFile "C:\Program Files\jq.exe"
        Log-Info "jq installed successfully."

        # Add jq to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        Log-Info "jq added to PATH environment variable."
    }
}

function Check-PythonInstalled {
    try {
        $pythonVersion = & python --version 2>&1
        if ($pythonVersion -match "Python (\d+)\.(\d+)\.(\d+)") {
            $majorVersion = [int]$matches[1]
            $minorVersion = [int]$matches[2]
            $patchVersion = [int]$matches[3]
            
            if ($majorVersion -ge 3 -and $minorVersion -ge 9) {
                Write-Host "Python $majorVersion.$minorVersion.$patchVersion is installed and is a recent version." -ForegroundColor Green
                return $true
            } else {
                Write-Host "Python version is $majorVersion.$minorVersion.$patchVersion. Please install Python 3.9 or later and run the script again." -ForegroundColor Red
                exit
            }
        } else {
            throw "Python is not installed or not properly configured."
        }
    } catch {
        Write-Host "Python is not installed or not properly configured. Installing Python..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.0/python-3.9.0-amd64.exe" -OutFile "$env:TEMP\python-3.9.0-amd64.exe"
        Start-Process -FilePath "$env:TEMP\python-3.9.0-amd64.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        Remove-Item -Path "$env:TEMP\python-3.9.0-amd64.exe"

        # Update environment variables
        [System.Environment]::SetEnvironmentVariable("Path", [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Program Files\Python39", "Process")

        # Update pip to the latest version
        try {
            & python -m pip install --upgrade pip
        } catch {
            Write-Error "Failed to update pip: $_"
            exit 1
        }
    }
}



# Function to check if Visual C++ Redistributable is installed
function Check-VCppInstalled {
    $vcppKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $vcppKey) {
        $vcppInstalled = Get-ItemProperty -Path $vcppKey
        if ($vcppInstalled -and $vcppInstalled.Installed -eq 1) {
            Write-Host "Visual C++ Redistributable is installed." -ForegroundColor Green
            return $true
        }
    }
    Write-Host "Visual C++ Redistributable is not installed. Installing Visual C++ Redistributable..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "$env:TEMP\vc_redist.x64.exe"
    Start-Process -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/quiet /install" -Wait
    Remove-Item -Path "$env:TEMP\vc_redist.x64.exe"
}

Check-PythonInstalled
Check-VCppInstalled
Ensure-Dependencies

    # Ensure valhallaAPI module is installed
$moduleName = "valhallaAPI"
if (Is-ModuleInstalled -ModuleName $moduleName) {
    Write-Host "$moduleName is installed."
} else {
    Write-Host "$moduleName is not installed."
    pip install $moduleName
}


