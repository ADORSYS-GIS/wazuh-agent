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

function Install-GnuSed {
    # Define the source URL and destination path
    $SourceUrl = "https://downloads.sourceforge.net/project/gnuwin32/sed/4.2.1/sed-4.2.1-setup.exe?ts=gAAAAABnihwyfyy8CnXn7cxMYUNSQkpG2f2dUMFeiIGE8dM6A4aJ9G6yYtMvnuqpFQ658BS-pINAAB2fnD6SQOVdenwjEcrf0w%3D%3D&r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fgnuwin32%2Ffiles%2Fsed%2F4.2.1%2Fsed-4.2.1-setup.exe%2Fdownload%3Fuse_mirror%3Ddeac-fra%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fgnuwin32%252Ffiles%252Fsed%252F4.2.1%252Fsed-4.2.1-setup.exe%252Fdownload%253Fuse_mirror%253Dnetcologne%2522"
    $DestinationPath = "$env:TEMP\sed-4.2.1-setup.exe"

    # Define a test command to check if GNU sed is installed
    $TestCommand = "sed --version"
    $DefaultInstallPath = "C:\Program Files (x86)\GnuWin32\bin"

    try {
        # Check if GNU sed is already installed
        Write-Host "Checking if GNU sed is already installed..."
        $versionOutput = & cmd /c $TestCommand 2>&1
        if ($versionOutput -match "GNU sed") {
            Write-Host "GNU sed is already installed." -ForegroundColor Green
            return
        }
    } catch {
        Write-Host "GNU sed is not installed. Proceeding with download and installation..." -ForegroundColor Yellow
    }

    try {
        # Download the installer using BITS
        Write-Host "Downloading GNU sed setup file to $DestinationPath..."
        Start-BitsTransfer -Source $SourceUrl -Destination $DestinationPath

        Write-Host "Download completed. Starting installation..." -ForegroundColor Green
        
        # Run the installer silently
        Start-Process -FilePath $DestinationPath -ArgumentList "/silent" -Wait

        Write-Host "GNU sed installed successfully." -ForegroundColor Green

        # Check if the installation path exists
        if (-Not (Test-Path $DefaultInstallPath)) {
            Write-Host "Installation directory not found. Please verify the installation." -ForegroundColor Red
            return
        }

        # Add sed to the system PATH if it's not already included
        Write-Host "Checking if sed is in the PATH..."
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
        if ($currentPath -notlike "*$DefaultInstallPath*") {
            Write-Host "Adding GNU sed to the system PATH..." -ForegroundColor Yellow
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$DefaultInstallPath", [System.EnvironmentVariableTarget]::Machine)
            Write-Host "GNU sed added to the system PATH. Restart your terminal to apply changes." -ForegroundColor Green
        } else {
            Write-Host "GNU sed is already in the PATH." -ForegroundColor Green
        }
    } catch {
        # Catch and display any errors
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
    Remove-Item -Path $DestinationPath
}




# Function to check if Visual C++ Redistributable is installed
function IsVCppInstalled {
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

IsPythonInstalled
IsVCppInstalled
Ensure-Dependencies

    # Ensure valhallaAPI module is installed
$moduleName = "valhallaAPI"
if (Is-ModuleInstalled -ModuleName $moduleName) {
    Write-Host "$moduleName is installed."
} else {
    Write-Host "$moduleName is not installed."
    pip install $moduleName
}


