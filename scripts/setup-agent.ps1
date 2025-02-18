# Set strict mode for script execution
Set-StrictMode -Version Latest

# Variables (default log level, app details, paths)
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.12" }
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "manager.wazuh.adorsys.team" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.10.1-1" }
$OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf"  # Adjust for Windows
$TEMP_DIR = [System.IO.Path]::GetTempPath()
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.2.0" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.0" }

# Global array to track installer files
$global:InstallerFiles = @()

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

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
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

# Cleanup function to remove installer files at the end
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "Removed installer file: $file"
        }
    }
}

# Step 0: Download dependency script and execute
function Install-Dependencies {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/fix-windows/issue-181/scripts/deps.ps1"  # Update the URL if needed
    $InstallerPath = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        Write-Host "Downloading and executing dependency script..."
        # Download dependency script
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        Write-Host "Dependency script downloaded successfully."
        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
    }
    catch {
        Write-Host "Error during dependency installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 1: Download and execute Wazuh agent script with error handling
function Install-WazuhAgent {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/fix-windows/issue-181/scripts/install.ps1"  # Update the URL if needed
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    try {
        Write-Host "Downloading and executing Wazuh agent script..."
        # Download Wazuh agent installer script
        Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
        Write-Host "Wazuh agent script downloaded successfully."
        # Execute the downloaded script
        & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Wazuh agent installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 2: Download and install wazuh-cert-oauth2-client with error handling
function Install-OAuth2Client {
    $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/heads/fix-windows/issue-181/scripts/install.ps1"  # Update the URL if needed
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    try {
        Write-Host "Downloading and executing wazuh-cert-oauth2-client script..."
        # Download the installer script
        Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
        Write-Host "wazuh-cert-oauth2-client script downloaded successfully."
        # Execute the downloaded script with required parameters
        & powershell.exe -ExecutionPolicy Bypass -File $OAuth2Script -ArgumentList "-LOG_LEVEL", $LOG_LEVEL, "-OSSEC_CONF_PATH", $OSSEC_CONF_PATH, "-APP_NAME", $APP_NAME, "-WOPS_VERSION", $WOPS_VERSION -ErrorAction Stop
    }
    catch {
        Write-Host "Error during wazuh-cert-oauth2-client installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 3: Download and install YARA with error handling
function Install-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/heads/fix/issue-181/scripts/install.ps1"  # Update the URL if needed
    $YaraScript = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $YaraScript

    try {
        Write-Host "Downloading and executing YARA installation script..."
        # Download the YARA installation script
        Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
        Write-Host "YARA installation script downloaded successfully."
        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $YaraScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during YARA installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 4: Download and install Snort with error handling
function Install-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/fix/issue-181/scripts/windows/snort.ps1"  # Update the URL if needed
    $SnortScript = "$env:TEMP\snort.ps1"
    $global:InstallerFiles += $SnortScript

    try {
        Write-Host "Downloading and executing Snort installation script..."
        # Download the Snort installation script
        Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
        Write-Host "Snort installation script downloaded successfully."
        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $SnortScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Snort installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 5: Download and install Wazuh Agent Status with error handling
function Install-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/heads/fix-windows/issue-181/scripts/install.ps1"  # Update the URL if needed
    $AgentStatusScript = "$env:TEMP\install-agent-status.ps1"
    $global:InstallerFiles += $AgentStatusScript

    try {
        Write-Host "Downloading and executing Wazuh Agent Status installation script..."
        # Download the Agent Status installation script
        Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
        Write-Host "Agent Status installation script downloaded successfully."
        # Execute the installation script
        & powershell.exe -ExecutionPolicy Bypass -File $AgentStatusScript -ErrorAction Stop
    }
    catch {
        Write-Host "Error during Agent Status installation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main Execution wrapped in a try-finally to ensure cleanup runs even if errors occur.
try {
    SectionSeparator "Installing Dependencies"
    Install-Dependencies
    SectionSeparator "Installing Wazuh Agent"
    Install-WazuhAgent
    SectionSeparator "Installing OAuth2Client"
    Install-OAuth2Client
    SectionSeparator "Installing Agent Status"
    Install-AgentStatus
    SectionSeparator "Installing Yara"
    Install-Yara
    SectionSeparator "Installing Snort"
    Install-Snort
}
finally {
    Write-Host "Cleaning up installer files..."
    Cleanup-Installers
    SuccessMessage "Wazuh Agent Setup Completed Successfully"
}
