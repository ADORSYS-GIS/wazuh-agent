#requires -version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- Elevate ----
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb      = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Administrator approval is required. Exiting.","Wazuh Agent Installer",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        exit 1
    }
}

Set-StrictMode -Version Latest

# ---- Configuration Variables ----
$LOG_LEVEL = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WAZUH_MANAGER = "" # Will be set based on user selection
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.13.1-1" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.14" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.4.0" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.4.0" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }

# ---- Globals ----
$AppName = "Wazuh Agent"
$LogDir  = "C:\ProgramData\wazuh\logs"
New-Item -ItemType Directory -Force -Path $LogDir -ErrorAction SilentlyContinue | Out-Null
$LogPath = Join-Path $LogDir "setup-agent.log"
$global:InstallerFiles = @()
$global:CurrentStep = 1
$global:InstallationComplete = $false

# ---- Logging ----
function Append-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] [$Level] $Message"
    $LogBox.AppendText($line + [Environment]::NewLine)
    $LogBox.ScrollToCaret()

    # Write to setup-agent.log
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}

    [System.Windows.Forms.Application]::DoEvents()
}

function InfoMessage {
    param ([string]$Message)
    Append-Log $Message "INFO"
}

function WarnMessage {
    param ([string]$Message)
    Append-Log $Message "WARNING"
}

function SuccessMessage {
    param ([string]$Message)
    Append-Log $Message "SUCCESS"
}

function ErrorMessage {
    param ([string]$Message)
    Append-Log $Message "ERROR"
}

function SectionSeparator {
    param ([string]$SectionName)
    Append-Log "=================================================="
    Append-Log "  $SectionName"
    Append-Log "=================================================="
}

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Action,
        [int]$Weight = 10
    )
    InfoMessage "[START] $Name"
    $StatusLabel.Text = "Step: $Name"
    try {
        & $Action
        SuccessMessage "[OK] $Name"
    } catch {
        ErrorMessage "[FAIL] $Name : $($_.Exception.Message)"
        throw
    } finally {
        $ProgressBar.Value = [Math]::Min($ProgressBar.Value + $Weight, $ProgressBar.Maximum)
    }
}

# ---- Cleanup ----
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            InfoMessage "Removed installer file: $file"
        }
    }
}

# ---- Environment PATH Refresh ----
function Refresh-EnvironmentPath {
    <#
    .SYNOPSIS
    Refreshes the current session's PATH from the registry to pick up newly installed tools.

    .DESCRIPTION
    When dependencies like gsed are installed and added to the Machine PATH,
    the current PowerShell session doesn't automatically pick up these changes.
    This function reloads the PATH from both Machine and User registry locations,
    ensuring all child processes inherit the updated PATH.
    #>
    try {
        InfoMessage "Refreshing environment PATH from registry..."

        # Get Machine PATH from registry
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

        # Get User PATH from registry
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)

        # Combine them (User paths take precedence over Machine paths)
        $combinedPath = $userPath + ";" + $machinePath

        # Update the current process environment
        $env:Path = $combinedPath

        SuccessMessage "Environment PATH refreshed successfully. All child processes will inherit updated PATH."
    } catch {
        WarnMessage "Failed to refresh environment PATH: $($_.Exception.Message)"
    }
}

# ---- Installation Functions ----
function Install-Dependencies {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/deps.ps1"
    $InstallerPath = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $InstallerPath

    InfoMessage "Downloading dependency script..."
    Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
    InfoMessage "Executing dependency script..."

    # Capture all output streams
    $output = & powershell.exe -ExecutionPolicy Bypass -File $InstallerPath 2>&1
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            ErrorMessage $line.ToString()
        } else {
            InfoMessage $line.ToString()
        }
    }

    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Dependency script failed with exit code $LASTEXITCODE"
    }

    # Refresh PATH to ensure gsed and other dependencies are available
    # This is critical for cert-oauth2 to properly replace agent name in ossec.conf
    Refresh-EnvironmentPath
}

function Install-WazuhAgent {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.ps1"
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    InfoMessage "Downloading Wazuh agent script..."
    Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
    InfoMessage "Installing Wazuh agent..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$InstallerPath`" -WAZUH_AGENT_VERSION `"$WAZUH_AGENT_VERSION`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\wazuh_output.log" -RedirectStandardError "$env:TEMP\wazuh_error.log" -Wait
    
    if (Test-Path "$env:TEMP\wazuh_output.log") {
        Get-Content "$env:TEMP\wazuh_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\wazuh_output.log" -Force
    }
    if (Test-Path "$env:TEMP\wazuh_error.log") {
        Get-Content "$env:TEMP\wazuh_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\wazuh_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "Wazuh agent installation failed with exit code $($process.ExitCode)"
    }
}

function Install-OAuth2Client {
    $OAuth2Url = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.ps1"
    $OAuth2Script = "$env:TEMP\wazuh-cert-oauth2-client-install.ps1"
    $global:InstallerFiles += $OAuth2Script

    InfoMessage "Downloading OAuth2 client script..."
    Invoke-WebRequest -Uri $OAuth2Url -OutFile $OAuth2Script -ErrorAction Stop
    InfoMessage "Installing OAuth2 client..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$OAuth2Script`" -LOG_LEVEL `"$LOG_LEVEL`" -OSSEC_CONF_PATH `"$OSSEC_CONF_PATH`" -APP_NAME `"$APP_NAME`" -WOPS_VERSION `"$WOPS_VERSION`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\oauth2_output.log" -RedirectStandardError "$env:TEMP\oauth2_error.log" -Wait
    
    if (Test-Path "$env:TEMP\oauth2_output.log") {
        Get-Content "$env:TEMP\oauth2_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\oauth2_output.log" -Force
    }
    if (Test-Path "$env:TEMP\oauth2_error.log") {
        Get-Content "$env:TEMP\oauth2_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\oauth2_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "OAuth2 client installation failed with exit code $($process.ExitCode)"
    }
}

function Install-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.ps1"
    $YaraScript = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $YaraScript

    InfoMessage "Downloading YARA script..."
    Invoke-WebRequest -Uri $YaraUrl -OutFile $YaraScript -ErrorAction Stop
    InfoMessage "Installing YARA..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$YaraScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\yara_output.log" -RedirectStandardError "$env:TEMP\yara_error.log" -Wait
    
    if (Test-Path "$env:TEMP\yara_output.log") {
        Get-Content "$env:TEMP\yara_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\yara_output.log" -Force
    }
    if (Test-Path "$env:TEMP\yara_error.log") {
        Get-Content "$env:TEMP\yara_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\yara_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "YARA installation failed with exit code $($process.ExitCode)"
    }
}

function Test-YaraInstalled {
    $activeResponseBinDir = "C:\Program Files (x86)\ossec-agent\active-response\bin"
    $yaraExePath = Join-Path -Path $activeResponseBinDir -ChildPath "yara\yara64.exe"
    $yaraBatPath = Join-Path -Path $activeResponseBinDir -ChildPath "yara.bat"

    foreach ($path in @($yaraExePath, $yaraBatPath)) {
        if (Test-Path $path) {
            InfoMessage "Detected existing YARA installation at: $path"
            return $true
        }
    }

    try {
        $yaraCmd = Get-Command yara64 -ErrorAction SilentlyContinue
        if ($yaraCmd) {
            InfoMessage "Detected YARA in system PATH: $($yaraCmd.Source)"
            return $true
        }
    } catch {}

    return $false
}

function Uninstall-Yara {
    $YaraUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/uninstall.ps1"
    $UninstallYaraScript = "$env:TEMP\uninstall_yara.ps1"
    $global:InstallerFiles += $UninstallYaraScript

    # Check if YARA is installed before attempting uninstall
    if (Test-YaraInstalled) {
        InfoMessage "Removing existing YARA installation..."
        Invoke-WebRequest -Uri $YaraUrl -OutFile $UninstallYaraScript -ErrorAction Stop

        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$UninstallYaraScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\uninstall_yara_output.log" -RedirectStandardError "$env:TEMP\uninstall_yara_error.log" -Wait

        if (Test-Path "$env:TEMP\uninstall_yara_output.log") {
            Get-Content "$env:TEMP\uninstall_yara_output.log" | ForEach-Object { InfoMessage $_ }
            Remove-Item "$env:TEMP\uninstall_yara_output.log" -Force
        }
        if (Test-Path "$env:TEMP\uninstall_yara_error.log") {
            Get-Content "$env:TEMP\uninstall_yara_error.log" | ForEach-Object { ErrorMessage $_ }
            Remove-Item "$env:TEMP\uninstall_yara_error.log" -Force
        }

        if ($process.ExitCode -ne 0) {
            WarningMessage "YARA uninstall completed with exit code $($process.ExitCode)"
        }
    } else {
        InfoMessage "YARA is not installed. Skipping uninstall."
    }
}

function Install-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/snort.ps1"
    $SnortScript = "$env:TEMP\snort.ps1"
    $global:InstallerFiles += $SnortScript

    InfoMessage "Downloading Snort script..."
    Invoke-WebRequest -Uri $SnortUrl -OutFile $SnortScript -ErrorAction Stop
    InfoMessage "Installing Snort..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$SnortScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\snort_output.log" -RedirectStandardError "$env:TEMP\snort_error.log" -Wait
    
    if (Test-Path "$env:TEMP\snort_output.log") {
        Get-Content "$env:TEMP\snort_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\snort_output.log" -Force
    }
    if (Test-Path "$env:TEMP\snort_error.log") {
        Get-Content "$env:TEMP\snort_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\snort_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "Snort installation failed with exit code $($process.ExitCode)"
    }
}

function Uninstall-Snort {
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/uninstall.ps1"
    $UninstallSnortScript = "$env:TEMP\uninstall_snort.ps1"
    $global:InstallerFiles += $UninstallSnortScript
    $TaskName = "SnortStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        InfoMessage "Removing existing Snort installation..."
        Invoke-WebRequest -Uri $SnortUrl -OutFile $UninstallSnortScript -ErrorAction Stop
        
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$UninstallSnortScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\uninstall_snort_output.log" -RedirectStandardError "$env:TEMP\uninstall_snort_error.log" -Wait
        
        if (Test-Path "$env:TEMP\uninstall_snort_output.log") {
            Get-Content "$env:TEMP\uninstall_snort_output.log" | ForEach-Object { InfoMessage $_ }
            Remove-Item "$env:TEMP\uninstall_snort_output.log" -Force
        }
        if (Test-Path "$env:TEMP\uninstall_snort_error.log") {
            Get-Content "$env:TEMP\uninstall_snort_error.log" | ForEach-Object { ErrorMessage $_ }
            Remove-Item "$env:TEMP\uninstall_snort_error.log" -Force
        }
        
        if ($process.ExitCode -ne 0) {
            WarningMessage "Snort uninstall completed with exit code $($process.ExitCode)"
        }
    }
}

function Install-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/install.ps1"
    $SuricataScript = "$env:TEMP\suricata.ps1"
    $global:InstallerFiles += $SuricataScript

    InfoMessage "Downloading Suricata script..."
    Invoke-WebRequest -Uri $SuricataUrl -OutFile $SuricataScript -ErrorAction Stop
    InfoMessage "Installing Suricata..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$SuricataScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\suricata_output.log" -RedirectStandardError "$env:TEMP\suricata_error.log" -Wait
    
    if (Test-Path "$env:TEMP\suricata_output.log") {
        Get-Content "$env:TEMP\suricata_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\suricata_output.log" -Force
    }
    if (Test-Path "$env:TEMP\suricata_error.log") {
        Get-Content "$env:TEMP\suricata_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\suricata_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "Suricata installation failed with exit code $($process.ExitCode)"
    }
}

function Uninstall-Suricata {
    $SuricataUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.ps1"
    $UninstallSuricataScript = "$env:TEMP\uninstall_suricata.ps1"
    $global:InstallerFiles += $UninstallSuricataScript
    $TaskName = "SuricataStartup"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        InfoMessage "Removing existing Suricata installation..."
        Invoke-WebRequest -Uri $SuricataUrl -OutFile $UninstallSuricataScript -ErrorAction Stop
        
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$UninstallSuricataScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\uninstall_suricata_output.log" -RedirectStandardError "$env:TEMP\uninstall_suricata_error.log" -Wait
        
        if (Test-Path "$env:TEMP\uninstall_suricata_output.log") {
            Get-Content "$env:TEMP\uninstall_suricata_output.log" | ForEach-Object { InfoMessage $_ }
            Remove-Item "$env:TEMP\uninstall_suricata_output.log" -Force
        }
        if (Test-Path "$env:TEMP\uninstall_suricata_error.log") {
            Get-Content "$env:TEMP\uninstall_suricata_error.log" | ForEach-Object { ErrorMessage $_ }
            Remove-Item "$env:TEMP\uninstall_suricata_error.log" -Force
        }
        
        if ($process.ExitCode -ne 0) {
            WarningMessage "Suricata uninstall completed with exit code $($process.ExitCode)"
        }
    }
}

function Install-AgentStatus {
    $AgentStatusUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/heads/fix/agent-status-update-launcher/scripts/install.ps1"
    $AgentStatusScript = "$env:TEMP\install-agent-status.ps1"
    $global:InstallerFiles += $AgentStatusScript

    InfoMessage "Downloading Agent Status script..."
    Invoke-WebRequest -Uri $AgentStatusUrl -OutFile $AgentStatusScript -ErrorAction Stop
    InfoMessage "Installing Agent Status..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$AgentStatusScript`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\agentstatus_output.log" -RedirectStandardError "$env:TEMP\agentstatus_error.log" -Wait
    
    if (Test-Path "$env:TEMP\agentstatus_output.log") {
        Get-Content "$env:TEMP\agentstatus_output.log" | ForEach-Object { InfoMessage $_ }
        Remove-Item "$env:TEMP\agentstatus_output.log" -Force
    }
    if (Test-Path "$env:TEMP\agentstatus_error.log") {
        Get-Content "$env:TEMP\agentstatus_error.log" | ForEach-Object { ErrorMessage $_ }
        Remove-Item "$env:TEMP\agentstatus_error.log" -Force
    }
    
    if ($process.ExitCode -ne 0) {
        throw "Agent Status installation failed with exit code $($process.ExitCode)"
    }
}

function DownloadVersionFile {
    if (!(Test-Path -Path $OSSEC_PATH)) {
        WarningMessage "ossec-agent folder does not exist. Skipping version file."
    } else {
        InfoMessage "Downloading version file..."
        Invoke-WebRequest -Uri $VERSION_FILE_URL -OutFile $VERSION_FILE_PATH -ErrorAction Stop
        InfoMessage "Version file downloaded successfully"
    }
}

# ---- Main Installation Process ----
function Do-Install {
    # Validate that manager address is not empty
    $managerAddress = $ManagerTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($managerAddress)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a Wazuh Manager address.","Manager Address Required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }

    # Validate manager address format to prevent XML injection and malicious input
    # Allow only: alphanumeric, dots, hyphens, and underscores (valid hostname/FQDN/IP characters)
    if ($managerAddress -notmatch '^[a-zA-Z0-9.-]+$') {
        [System.Windows.Forms.MessageBox]::Show("Invalid manager address format. Only alphanumeric characters, dots, hyphens, and underscores are allowed.","Invalid Input",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        ErrorMessage "Invalid manager address attempted: $managerAddress"
        return
    }

    # Additional check: Prevent XML special characters that could be used for injection
    $xmlSpecialChars = @('<', '>', '&', '"', "'", '`')
    foreach ($char in $xmlSpecialChars) {
        if ($managerAddress.Contains($char)) {
            [System.Windows.Forms.MessageBox]::Show("Invalid characters detected in manager address. XML special characters are not allowed.","Security Validation Failed",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            ErrorMessage "XML injection attempt detected in manager address"
            return
        }
    }

    # Validate length to prevent buffer overflow attacks
    if ($managerAddress.Length -gt 253) {  # Max FQDN length per RFC 1035
        [System.Windows.Forms.MessageBox]::Show("Manager address is too long. Maximum length is 253 characters.","Invalid Input",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }

    # Set WAZUH_MANAGER from text box input
    $script:WAZUH_MANAGER = $managerAddress
    InfoMessage "Using Wazuh Manager: $script:WAZUH_MANAGER"

    # Set environment variable for child scripts
    $env:WAZUH_MANAGER = $script:WAZUH_MANAGER

    $InstallBtn.Enabled = $false
    $NextBtn.Enabled = $false
    $SnortRadio.Enabled = $false
    $SuricataRadio.Enabled = $false
    $YaraCheckbox.Enabled = $false
    $ManagerTextBox.Enabled = $false
    $ProgressBar.Value = 0
    $ProgressBar.Maximum = 100

    SectionSeparator "INSTALLATION START"

    try {
        # Calculate weights based on selected components
        $yaraWeight = if ($YaraCheckbox.Checked) { 13 } else { 0 }
        $nidsRemoveWeight = 10
        $nidsInstallWeight = 15
        
        # Calculate total weight and adjustment factor to reach 100%
        $totalWeight = 12 + 15 + 13 + 12 + $yaraWeight + $nidsRemoveWeight + $nidsInstallWeight + 10
        $weightFactor = 100 / $totalWeight
        
        # Adjust weights to ensure they sum to 100%
        $depsWeight = [math]::Round(12 * $weightFactor, 0)
        $agentWeight = [math]::Round(15 * $weightFactor, 0)
        $oauthWeight = [math]::Round(13 * $weightFactor, 0)
        $statusWeight = [math]::Round(12 * $weightFactor, 0)
        $yaraWeight = [math]::Round($yaraWeight * $weightFactor, 0)
        $nidsRemoveWeight = [math]::Round($nidsRemoveWeight * $weightFactor, 0)
        $nidsInstallWeight = [math]::Round($nidsInstallWeight * $weightFactor, 0)
        $versionWeight = 100 - ($depsWeight + $agentWeight + $oauthWeight + $statusWeight + $yaraWeight + $nidsRemoveWeight + $nidsInstallWeight)
        
        # Execute steps with adjusted weights
        Invoke-Step -Name "Installing Dependencies" -Weight $depsWeight -Action { Install-Dependencies }
        Invoke-Step -Name "Installing Wazuh Agent" -Weight $agentWeight -Action { Install-WazuhAgent }
        Invoke-Step -Name "Installing OAuth2 Client" -Weight $oauthWeight -Action { Install-OAuth2Client }
        Invoke-Step -Name "Installing Agent Status" -Weight $statusWeight -Action { Install-AgentStatus }
        
        if ($YaraCheckbox.Checked) {
            Invoke-Step -Name "Installing YARA" -Weight $yaraWeight -Action { Install-Yara }
        } else {
            Invoke-Step -Name "Removing YARA (if present)" -Weight $yaraWeight -Action { Uninstall-Yara }
        }

        # Install selected NIDS
        if ($SnortRadio.Checked) {
            Invoke-Step -Name "Removing Suricata (if present)" -Weight $nidsRemoveWeight -Action { Uninstall-Suricata }
            Invoke-Step -Name "Installing Snort" -Weight $nidsInstallWeight -Action { Install-Snort }
        } elseif ($SuricataRadio.Checked) {
            Invoke-Step -Name "Removing Snort (if present)" -Weight $nidsRemoveWeight -Action { Uninstall-Snort }
            Invoke-Step -Name "Installing Suricata" -Weight $nidsInstallWeight -Action { Install-Suricata }
        }

        Invoke-Step -Name "Downloading Version File" -Weight $versionWeight -Action { DownloadVersionFile }

        InfoMessage "Cleaning up installer files..."
        Cleanup-Installers
        SectionSeparator "INSTALLATION END"

        $global:InstallationComplete = $true
        SuccessMessage "Installation completed successfully! Click 'Next' to configure OAuth2."

        # Enable Next button and update UI
        $NextBtn.Enabled = $true
        $NextBtn.Visible = $true
        $InstallBtn.Enabled = $false

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Installation failed: $($_.Exception.Message)","Installation Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        $InstallBtn.Enabled = $true
    } finally {
        $SnortRadio.Enabled = $true
        $SuricataRadio.Enabled = $true
        $YaraCheckbox.Enabled = $true
        $ManagerTextBox.Enabled = $true
        $StatusLabel.Text = "Installation Complete"
    }
}

# ---- OAuth2 Configuration ----
function Do-OAuth2Config {
    $ConfigureBtn.Enabled = $false
    $NextBtn.Enabled = $false
    $BackBtn.Enabled = $false

    SectionSeparator "OAUTH2 CONFIGURATION"

    $OAuth2BinPath = 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe'

    if (-not (Test-Path $OAuth2BinPath)) {
        ErrorMessage "OAuth2 binary not found at: $OAuth2BinPath"
        [System.Windows.Forms.MessageBox]::Show("OAuth2 binary not found. Installation may have failed.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        $ConfigureBtn.Enabled = $true
        $BackBtn.Enabled = $true
        return
    }

    InfoMessage "Starting OAuth2 configuration..."
    InfoMessage "A NEW PowerShell window will open. Please follow the instructions to complete authentication."
    InfoMessage "The wizard will continue automatically when OAuth2 configuration is complete."

    try {
        # Launch cert-oauth2 in a COMPLETELY NEW PowerShell instance (not a child process)
        # This ensures it reads the PATH directly from the registry, picking up gsed
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command `"& '$OAuth2BinPath' o-auth2; exit `$LASTEXITCODE`""
        $psi.UseShellExecute = $true  # Launch as separate process, not child
        $psi.Verb = "runas"  # Run elevated to ensure proper permissions
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal

        InfoMessage "Launching OAuth2 in new PowerShell instance with fresh environment..."
        $process = [System.Diagnostics.Process]::Start($psi)

        # Wait for process to complete while keeping UI responsive
        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        if ($process.ExitCode -eq 0) {
            SuccessMessage "OAuth2 configuration completed successfully!"
            SectionSeparator "OAUTH2 CONFIGURATION END"
            $NextBtn.Enabled = $true
        } else {
            ErrorMessage "OAuth2 configuration failed with exit code: $($process.ExitCode)"
            [System.Windows.Forms.MessageBox]::Show("OAuth2 configuration failed. Exit code: $($process.ExitCode)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $ConfigureBtn.Enabled = $true
            $BackBtn.Enabled = $true
        }
    } catch {
        ErrorMessage "Failed to run OAuth2 binary: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed to run OAuth2 binary: $($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        $ConfigureBtn.Enabled = $true
        $BackBtn.Enabled = $true
    }
}

# ---- Step Navigation ----
function Show-Step {
    param([int]$StepNumber)

    $global:CurrentStep = $StepNumber

    # Hide all step panels
    $Step1Panel.Visible = $false
    $Step2Panel.Visible = $false
    $Step3Panel.Visible = $false

    # Update title and show appropriate panel
    switch ($StepNumber) {
        1 {
            $Title.Text = "Step 1: Installation"
            $Step1Panel.Visible = $true
            $BackBtn.Visible = $false
            $NextBtn.Visible = $true
            $NextBtn.Enabled = $global:InstallationComplete
            $InstallBtn.Enabled = -not $global:InstallationComplete
        }
        2 {
            $Title.Text = "Step 2: OAuth2 Configuration"
            $Step2Panel.Visible = $true
            $BackBtn.Visible = $true
            $BackBtn.Enabled = $true
            $NextBtn.Visible = $true
            $NextBtn.Enabled = $false
            $ConfigureBtn.Enabled = $true
        }
        3 {
            $Title.Text = "Step 3: Setup Complete"
            $Step3Panel.Visible = $true
            $BackBtn.Visible = $false
            $NextBtn.Visible = $false
        }
    }
}

function Next-Step {
    if ($global:CurrentStep -eq 1) {
        if (-not $global:InstallationComplete) {
            [System.Windows.Forms.MessageBox]::Show("Please complete the installation first.","Not Ready",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        Show-Step 2
    } elseif ($global:CurrentStep -eq 2) {
        Show-Step 3
    }
}

function Previous-Step {
    if ($global:CurrentStep -eq 2) {
        Show-Step 1
    }
}

# ---- UI Creation ----
$form = New-Object System.Windows.Forms.Form
$form.Text = "$AppName Setup Wizard"
$form.Size = New-Object System.Drawing.Size(750,750)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Title Label
$Title = New-Object System.Windows.Forms.Label
$Title.Text = "Step 1: Installation"
$Title.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$Title.AutoSize = $true
$Title.Location = New-Object System.Drawing.Point(15,15)
$form.Controls.Add($Title)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.AutoSize = $true
$StatusLabel.Location = New-Object System.Drawing.Point(18,55)
$form.Controls.Add($StatusLabel)

# Close button (top right)
$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "Close"
$CloseBtn.Size = New-Object System.Drawing.Size(80,30)
$CloseBtn.Location = New-Object System.Drawing.Point(640,15)
$CloseBtn.Add_Click({ $form.Close() })
$form.Controls.Add($CloseBtn)

# Shared Log Box (visible across all steps)
$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Multiline = $true
$LogBox.ReadOnly = $true
$LogBox.ScrollBars = "Vertical"
$LogBox.Font = New-Object System.Drawing.Font("Consolas",9)
$LogBox.Size = New-Object System.Drawing.Size(700,280)
$LogBox.Location = New-Object System.Drawing.Point(18,85)
$form.Controls.Add($LogBox)

# Progress Bar (shared)
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Size = New-Object System.Drawing.Size(700,22)
$ProgressBar.Location = New-Object System.Drawing.Point(18,375)
$form.Controls.Add($ProgressBar)

# ===== STEP 1 PANEL: Installation =====
$Step1Panel = New-Object System.Windows.Forms.Panel
$Step1Panel.Size = New-Object System.Drawing.Size(700,230)
$Step1Panel.Location = New-Object System.Drawing.Point(18,405)
$form.Controls.Add($Step1Panel)

# Wazuh Manager Selection Group
$ManagerGroup = New-Object System.Windows.Forms.GroupBox
$ManagerGroup.Text = "Wazuh Manager Address"
$ManagerGroup.Size = New-Object System.Drawing.Size(320,100)
$ManagerGroup.Location = New-Object System.Drawing.Point(10,10)
$Step1Panel.Controls.Add($ManagerGroup)

$ManagerLabel = New-Object System.Windows.Forms.Label
$ManagerLabel.Text = "Enter Manager Address:"
$ManagerLabel.Location = New-Object System.Drawing.Point(15,25)
$ManagerLabel.AutoSize = $true
$ManagerGroup.Controls.Add($ManagerLabel)

$ManagerTextBox = New-Object System.Windows.Forms.TextBox
$ManagerTextBox.Location = New-Object System.Drawing.Point(15,50)
$ManagerTextBox.Size = New-Object System.Drawing.Size(290,25)
$ManagerTextBox.Font = New-Object System.Drawing.Font("Segoe UI",9)
$ManagerTextBox.Text = ""
$ManagerGroup.Controls.Add($ManagerTextBox)

# NIDS Selection Group
$NidsGroup = New-Object System.Windows.Forms.GroupBox
$NidsGroup.Text = "Network IDS Selection"
$NidsGroup.Size = New-Object System.Drawing.Size(320,90)
$NidsGroup.Location = New-Object System.Drawing.Point(340,10)
$Step1Panel.Controls.Add($NidsGroup)

$SnortRadio = New-Object System.Windows.Forms.RadioButton
$SnortRadio.Text = "Install Snort"
$SnortRadio.Location = New-Object System.Drawing.Point(15,30)
$SnortRadio.AutoSize = $true
$NidsGroup.Controls.Add($SnortRadio)

$SuricataRadio = New-Object System.Windows.Forms.RadioButton
$SuricataRadio.Text = "Install Suricata"
$SuricataRadio.Location = New-Object System.Drawing.Point(15,60)
$SuricataRadio.AutoSize = $true
$SuricataRadio.Checked = $true
$NidsGroup.Controls.Add($SuricataRadio)

# Optional Components Group
$OptionalGroup = New-Object System.Windows.Forms.GroupBox
$OptionalGroup.Text = "Optional Components"
$OptionalGroup.Size = New-Object System.Drawing.Size(320,55)
$OptionalGroup.Location = New-Object System.Drawing.Point(340,110)
$Step1Panel.Controls.Add($OptionalGroup)

$YaraCheckbox = New-Object System.Windows.Forms.CheckBox
$YaraCheckbox.Text = "Install YARA"
$YaraCheckbox.Location = New-Object System.Drawing.Point(15,15)
$YaraCheckbox.AutoSize = $true
$YaraCheckbox.Checked = $false
$OptionalGroup.Controls.Add($YaraCheckbox)

$InstallBtn = New-Object System.Windows.Forms.Button
$InstallBtn.Text = "Start Installation"
$InstallBtn.Size = New-Object System.Drawing.Size(150,35)
$InstallBtn.Location = New-Object System.Drawing.Point(170,175)
$InstallBtn.Add_Click({ Do-Install })
$Step1Panel.Controls.Add($InstallBtn)

$OpenLogBtn = New-Object System.Windows.Forms.Button
$OpenLogBtn.Text = "Open Log"
$OpenLogBtn.Size = New-Object System.Drawing.Size(150,35)
$OpenLogBtn.Location = New-Object System.Drawing.Point(330,175)
$OpenLogBtn.Add_Click({
    if (Test-Path $LogPath) {
        Start-Process notepad.exe $LogPath
    } else {
        InfoMessage "No log file found at $LogPath"
    }
})
$Step1Panel.Controls.Add($OpenLogBtn)

# ===== STEP 2 PANEL: OAuth2 Configuration =====
$Step2Panel = New-Object System.Windows.Forms.Panel
$Step2Panel.Size = New-Object System.Drawing.Size(700,140)
$Step2Panel.Location = New-Object System.Drawing.Point(18,405)
$Step2Panel.Visible = $false
$form.Controls.Add($Step2Panel)

$OAuth2InfoLabel = New-Object System.Windows.Forms.Label
$OAuth2InfoLabel.Text = "Click 'Configure OAuth2' to run the authentication setup.`nYou will be prompted to enter your token."
$OAuth2InfoLabel.AutoSize = $false
$OAuth2InfoLabel.Size = New-Object System.Drawing.Size(680,50)
$OAuth2InfoLabel.Location = New-Object System.Drawing.Point(10,10)
$OAuth2InfoLabel.Font = New-Object System.Drawing.Font("Segoe UI",9)
$Step2Panel.Controls.Add($OAuth2InfoLabel)

$ConfigureBtn = New-Object System.Windows.Forms.Button
$ConfigureBtn.Text = "Configure OAuth2"
$ConfigureBtn.Size = New-Object System.Drawing.Size(150,40)
$ConfigureBtn.Location = New-Object System.Drawing.Point(10,70)
$ConfigureBtn.Add_Click({ Do-OAuth2Config })
$Step2Panel.Controls.Add($ConfigureBtn)

# ===== STEP 3 PANEL: Completion =====
$Step3Panel = New-Object System.Windows.Forms.Panel
$Step3Panel.Size = New-Object System.Drawing.Size(700,140)
$Step3Panel.Location = New-Object System.Drawing.Point(18,405)
$Step3Panel.Visible = $false
$form.Controls.Add($Step3Panel)

$CompletionLabel = New-Object System.Windows.Forms.Label
$CompletionLabel.Text = "Setup Complete!`n`nThe Wazuh Agent has been installed and configured.`nA system reboot is recommended to apply all changes."
$CompletionLabel.AutoSize = $false
$CompletionLabel.Size = New-Object System.Drawing.Size(680,70)
$CompletionLabel.Location = New-Object System.Drawing.Point(10,5)
$CompletionLabel.Font = New-Object System.Drawing.Font("Segoe UI",10)
$Step3Panel.Controls.Add($CompletionLabel)

$RebootNowBtn = New-Object System.Windows.Forms.Button
$RebootNowBtn.Text = "Reboot Now"
$RebootNowBtn.Size = New-Object System.Drawing.Size(130,40)
$RebootNowBtn.Location = New-Object System.Drawing.Point(10,85)
$RebootNowBtn.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to reboot now?","Confirm Reboot",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        InfoMessage "Initiating system reboot..."
        Start-Process shutdown.exe -ArgumentList "/r /t 5" -NoNewWindow
        $form.Close()
    }
})
$Step3Panel.Controls.Add($RebootNowBtn)

$RebootLaterBtn = New-Object System.Windows.Forms.Button
$RebootLaterBtn.Text = "Reboot Later"
$RebootLaterBtn.Size = New-Object System.Drawing.Size(130,40)
$RebootLaterBtn.Location = New-Object System.Drawing.Point(150,85)
$RebootLaterBtn.Add_Click({
    InfoMessage "Setup complete. Please remember to reboot your system."
    [System.Windows.Forms.MessageBox]::Show("Setup complete. Please remember to reboot your system to apply all changes.","Setup Complete",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    $form.Close()
})
$Step3Panel.Controls.Add($RebootLaterBtn)

# ===== NAVIGATION BUTTONS =====
$BackBtn = New-Object System.Windows.Forms.Button
$BackBtn.Text = "< Back"
$BackBtn.Size = New-Object System.Drawing.Size(100,40)
$BackBtn.Location = New-Object System.Drawing.Point(410,650)
$BackBtn.Visible = $false
$BackBtn.Add_Click({ Previous-Step })
$form.Controls.Add($BackBtn)

$NextBtn = New-Object System.Windows.Forms.Button
$NextBtn.Text = "Next >"
$NextBtn.Size = New-Object System.Drawing.Size(100,40)
$NextBtn.Location = New-Object System.Drawing.Point(560,650)
$NextBtn.Enabled = $false
$NextBtn.Visible = $true
$NextBtn.Add_Click({ Next-Step })
$form.Controls.Add($NextBtn)

# ---- Startup Log ----
InfoMessage "Wazuh Agent Setup Wizard v2.0"
InfoMessage "Running as Administrator: $IsAdmin"
InfoMessage "Log file: $LogPath"
InfoMessage "Agent Version: $WAZUH_AGENT_VERSION"
InfoMessage "Please enter your Wazuh Manager address in the text box"
InfoMessage "Default NIDS: Suricata (use radio buttons to change)"
InfoMessage "Ready to install. Click 'Start Installation' to begin."

# Show Step 1
Show-Step 1

[void]$form.ShowDialog()
