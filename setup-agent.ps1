# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.1" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "master.dev.wazuh.adorsys.team" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.8.2-1" }
$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf" # Adjust for Windows
$TEMP_DIR = [System.IO.Path]::GetTempPath()

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

# Step 0: Ensure dependencies (for Windows, equivalent would be checking for curl & jq installation)
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

# Step 1: Download and execute Wazuh agent script with error handling
function Install-WazuhAgent {
    try {
        Write-Host "Downloading and executing Wazuh agent script..."

        $InstallerUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/wazuh-agent-win/scripts/install.ps1"  # Update the URL if needed
        $InstallerPath = "$env:TEMP\install.ps1"

        # Download Wazuh agent installer script
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent script downloaded successfully."

        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent script executed successfully."
    }
    catch {
        Write-Host "Error during Wazuh agent installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the installer file if it exists
        if (Test-Path $InstallerPath) {
            Remove-Item $InstallerPath -Force
            Write-Host "Installer file removed."
        }
    }
}


# Step 2: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    try {
        Write-Host "Downloading and executing wazuh-cert-oauth2-client script..."

        $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/heads/fix/scripts/install.ps1"  # Update the URL if needed
        $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"

        # Download the wazuh-cert-oauth2-client installer script
        Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
        Write-Host "wazuh-cert-oauth2-client script downloaded successfully."

        # Execute the downloaded script with required parameters
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
        Write-Host "wazuh-cert-oauth2-client installed successfully."
    }
    catch {
        Write-Host "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the installer file if it exists
        if (Test-Path $OAuth2Script) {
            Remove-Item $OAuth2Script -Force
            Write-Host "Installer file removed."
        }
    }
}


# Step 3: Download and install YARA with error handling
function Install-Yara {
    try {
        Write-Host "Downloading and executing YARA installation script..."

        $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/install.ps1"  # Update the URL if needed
        $YaraScript = "$env:TEMP\install.ps1"

        # Download the installation script
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        Write-Host "YARA installation script downloaded successfully."

        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
        Write-Host "YARA installed successfully."
    }
    catch {
        Write-Host "Error during YARA installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up the script if it exists
        if (Test-Path $YaraScript) {
            Remove-Item $YaraScript -Force
            Write-Host "Installer script removed."
        }
    }
}


# Step 4: Download and install Snort
function Install-Snort {
    Log-Info "Installing Snort"

    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/main/scripts/windows/snort.ps1"
    $SnortScript = "$TEMP_DIR\snort.ps1"

    # Download the installation script
    Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript

    # Execute the installation script
    & powershell.exe -File $SnortScript
    Log-Info "Snort installed successfully."

    # Clean up the script
    Remove-Item $SnortScript
}

# Main Execution
Ensure-Dependencies
Install-WazuhAgent
Install-OAuth2Client
Install-Yara
Install-Snort
