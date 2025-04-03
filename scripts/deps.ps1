
# Function to log messages with a timestamp
function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"  # Default color
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

# Logging helpers with colors
function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "White"
}

function WarnMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function PrintStep {
    param (
        [int]$StepNumber,
        [string]$Message
    )
    Log "[STEP]" "Step ${StepNumber}: $Message" "White"
}

# Exit script with an error message
function ErrorExit {
    param ([string]$Message)
    ErrorMessage $Message
    exit 1
}

function Ensure-Dependencies {
    InfoMessage "Ensuring dependencies are installed (curl, jq)"   

    # Check if curl is available
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        InfoMessage "curl is not installed. Installing curl..."
        Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1_2/curl-7.79.1_2-win64-mingw.zip" -OutFile "$TEMP_DIR\curl.zip"
        Expand-Archive -Path "$TEMP_DIR\curl.zip" -DestinationPath "$TEMP_DIR\curl"
        Move-Item -Path "$TEMP_DIR\curl\curl-7.79.1_2-win64-mingw\bin\curl.exe" -Destination "C:\Program Files\curl.exe"
        Remove-Item -Path "$TEMP_DIR\curl.zip" -Recurse
        Remove-Item -Path "$TEMP_DIR\curl" -Recurse
        InfoMessage "curl installed successfully."

        # Add curl to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        InfoMessage "curl added to PATH environment variable."
    }

    # Check if jq is available
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        InfoMessage "jq is not installed. Installing jq..."
        Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" -OutFile "C:\Program Files\jq.exe"
        InfoMessage "jq installed successfully."

        # Add jq to the PATH environment variable
        $env:Path += ";C:\Program Files"
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        InfoMessage "jq added to PATH environment variable."
    }
}


function Install-BurntToastModule {
    [CmdletBinding()]
    param()

    try {
        # Check if the NuGet provider is installed (minimum version 2.8.5.201) without using a variable.
        if (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue) {
            Write-Output "NuGet provider is already installed."
        }
        else {
            Write-Output "NuGet provider not found. Installing NuGet provider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
            Write-Output "NuGet provider installed successfully."
        }

        # Check if the BurntToast module is already installed.
        if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
            Write-Output "Module 'BurntToast' is already installed."
        }
        else {
            Write-Output "Installing module 'BurntToast'..."
            Install-Module -Name BurntToast -Force -Confirm:$false -ErrorAction Stop
            Write-Output "Module 'BurntToast' installed successfully."
        }

        # Import the BurntToast module to ensure commands like New-BurntToastNotification are recognized.
        Write-Output "Importing module 'BurntToast'..."
        Import-Module BurntToast -ErrorAction Stop
        Write-Output "Module 'BurntToast' imported successfully."
    }
    catch {
        Write-Error "Failed to install or import module 'BurntToast'. Error details: $_"
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
        InfoMessage "Checking if GNU sed is already installed..."
        $versionOutput = & cmd /c $TestCommand 2>&1
        if ($versionOutput -match "GNU sed") {
            InfoMessage "GNU sed is already installed." 
            return
        }
    } catch {
        WarnMessage "GNU sed is not installed. Proceeding with download and installation..." 
    }

    try {
        # Download the installer using BITS
        InfoMessage "Downloading GNU sed setup file to $DestinationPath..."
        Start-BitsTransfer -Source $SourceUrl -Destination $DestinationPath

        InfoMessage "Download completed. Starting installation..." 
        
        # Run the installer silently
        Start-Process -FilePath $DestinationPath  -Wait

        SuccessMessage "GNU sed installed successfully." 

        # Check if the installation path exists
        if (-Not (Test-Path $DefaultInstallPath)) {
            ErrorMessage "Installation directory not found. Please verify the installation." 
            return
        }

        # Add sed to the system PATH if it's not already included
        InfoMessage "Checking if sed is in the PATH..."
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
        if ($currentPath -notlike "*$DefaultInstallPath*") {
            WarnMessage "Adding GNU sed to the system PATH..." 
            
            $env:Path += ";C:\Program Files (x86)\GnuWin32\bin"
            [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
            SuccessMessage "GNU sed added to the system PATH. Restart your terminal to apply changes." 
        } else {
            SuccessMessage "GNU sed is already in the PATH." 
        }
    } catch {
        # Catch and display any errors
        ErrorMessage "An error occurred: $($_.Exception.Message)" 
    }
    Remove-Item -Path $DestinationPath
}




# Function to check if Visual C++ Redistributable is installed
function IsVCppInstalled {
    $vcppKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $vcppKey) {
        $vcppInstalled = Get-ItemProperty -Path $vcppKey
        if ($vcppInstalled -and $vcppInstalled.Installed -eq 1) {
            SuccessMessage "Visual C++ Redistributable is installed." 
            return $true
        }
    }
    WarnMessage "Visual C++ Redistributable is not installed. Installing Visual C++ Redistributable..." 
    Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "$env:TEMP\vc_redist.x64.exe"
    Start-Process -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/quiet /install" -Wait
    Remove-Item -Path "$env:TEMP\vc_redist.x64.exe"
}




IsVCppInstalled
Install-GnuSed
Ensure-Dependencies
Install-BurntToastModule


