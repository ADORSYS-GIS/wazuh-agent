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
$WAZUH_MANAGER = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "wazuh.example.com" }
$WAZUH_AGENT_VERSION = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.12.0-1" }
$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent\" 
$OSSEC_CONF_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$RepoUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"
$VERSION_FILE_URL = "$RepoUrl/version.txt"
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
$WAZUH_YARA_VERSION = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.11" }
$WAZUH_SNORT_VERSION = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.3.3" }
$WOPS_VERSION = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.2.18" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }

# ---- Globals ----
$AppName = "Wazuh Agent"
$LogDir  = Join-Path $env:ProgramData "WazuhAgentInstaller"
New-Item -ItemType Directory -Force -Path $LogDir -ErrorAction SilentlyContinue | Out-Null
$LogPath = Join-Path $LogDir "installer.log"
$global:InstallerFiles = @()

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
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
    [System.Windows.Forms.Application]::DoEvents()
}

function InfoMessage {
    param ([string]$Message)
    Append-Log $Message "INFO"
}

function WarningMessage {
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
}

function Install-WazuhAgent {
    $InstallerURL = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.ps1"
    $InstallerPath = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $InstallerPath

    InfoMessage "Downloading Wazuh agent script..."
    Invoke-WebRequest -Uri $InstallerURL -OutFile $InstallerPath -ErrorAction Stop
    InfoMessage "Installing Wazuh agent..."
    
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$InstallerPath`"" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\wazuh_output.log" -RedirectStandardError "$env:TEMP\wazuh_error.log" -Wait
    
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
    $SnortUrl = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/uninstall.ps1"
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
    $InstallBtn.Enabled = $false
    $CloseBtn.Enabled = $false
    $SnortRadio.Enabled = $false
    $SuricataRadio.Enabled = $false
    $ProgressBar.Value = 0
    $ProgressBar.Maximum = 100
    
    SectionSeparator "INSTALLATION START"
    
    try {
        Invoke-Step -Name "Installing Dependencies" -Weight 12 -Action { Install-Dependencies }
        Invoke-Step -Name "Installing Wazuh Agent" -Weight 15 -Action { Install-WazuhAgent }
        Invoke-Step -Name "Installing OAuth2 Client" -Weight 13 -Action { Install-OAuth2Client }
        Invoke-Step -Name "Installing Agent Status" -Weight 12 -Action { Install-AgentStatus }
        Invoke-Step -Name "Installing YARA" -Weight 13 -Action { Install-Yara }
        
        # Install selected NIDS
        if ($SnortRadio.Checked) {
            Invoke-Step -Name "Removing Suricata (if present)" -Weight 10 -Action { Uninstall-Suricata }
            Invoke-Step -Name "Installing Snort" -Weight 15 -Action { Install-Snort }
        } elseif ($SuricataRadio.Checked) {
            Invoke-Step -Name "Removing Snort (if present)" -Weight 10 -Action { Uninstall-Snort }
            Invoke-Step -Name "Installing Suricata" -Weight 15 -Action { Install-Suricata }
        }
        
        Invoke-Step -Name "Downloading Version File" -Weight 10 -Action { DownloadVersionFile }
        
        [System.Windows.Forms.MessageBox]::Show("Wazuh Agent installation completed successfully!","Installation Complete",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Installation failed: $($_.Exception.Message)","Installation Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } finally {
        InfoMessage "Cleaning up installer files..."
        Cleanup-Installers
        SectionSeparator "INSTALLATION END"
        $InstallBtn.Enabled = $true
        $CloseBtn.Enabled = $true
        $SnortRadio.Enabled = $true
        $SuricataRadio.Enabled = $true
        $StatusLabel.Text = "Ready"
    }
}

# ---- UI Creation ----
$form = New-Object System.Windows.Forms.Form
$form.Text = "$AppName Installer"
$form.Size = New-Object System.Drawing.Size(750,550)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "$AppName Installer"
$Title.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$Title.AutoSize = $true
$Title.Location = New-Object System.Drawing.Point(15,15)
$form.Controls.Add($Title)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.AutoSize = $true
$StatusLabel.Location = New-Object System.Drawing.Point(18,50)
$form.Controls.Add($StatusLabel)

# NIDS Selection Group
$NidsGroup = New-Object System.Windows.Forms.GroupBox
$NidsGroup.Text = "Network IDS Selection"
$NidsGroup.Size = New-Object System.Drawing.Size(200,80)
$NidsGroup.Location = New-Object System.Drawing.Point(500,15)
$form.Controls.Add($NidsGroup)

$SnortRadio = New-Object System.Windows.Forms.RadioButton
$SnortRadio.Text = "Install Snort"
$SnortRadio.Location = New-Object System.Drawing.Point(10,25)
$SnortRadio.AutoSize = $true
$NidsGroup.Controls.Add($SnortRadio)

$SuricataRadio = New-Object System.Windows.Forms.RadioButton
$SuricataRadio.Text = "Install Suricata"
$SuricataRadio.Location = New-Object System.Drawing.Point(10,50)
$SuricataRadio.AutoSize = $true
$SuricataRadio.Checked = $true
$NidsGroup.Controls.Add($SuricataRadio)

$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Multiline = $true
$LogBox.ReadOnly = $true
$LogBox.ScrollBars = "Vertical"
$LogBox.Font = New-Object System.Drawing.Font("Consolas",9)
$LogBox.Size = New-Object System.Drawing.Size(700,330)
$LogBox.Location = New-Object System.Drawing.Point(18,105)
$form.Controls.Add($LogBox)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Size = New-Object System.Drawing.Size(700,22)
$ProgressBar.Location = New-Object System.Drawing.Point(18,445)
$form.Controls.Add($ProgressBar)

$OpenLogBtn = New-Object System.Windows.Forms.Button
$OpenLogBtn.Text = "Open Log"
$OpenLogBtn.Size = New-Object System.Drawing.Size(100,30)
$OpenLogBtn.Location = New-Object System.Drawing.Point(18,475)
$OpenLogBtn.Add_Click({ 
    if (Test-Path $LogPath) { 
        Start-Process notepad.exe $LogPath 
    } else { 
        InfoMessage "No log file found at $LogPath" 
    } 
})
$form.Controls.Add($OpenLogBtn)

$InstallBtn = New-Object System.Windows.Forms.Button
$InstallBtn.Text = "Install"
$InstallBtn.Size = New-Object System.Drawing.Size(100,30)
$InstallBtn.Location = New-Object System.Drawing.Point(608,475)
$InstallBtn.Add_Click({ Do-Install })
$form.Controls.Add($InstallBtn)

$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "Close"
$CloseBtn.Size = New-Object System.Drawing.Size(100,30)
$CloseBtn.Location = New-Object System.Drawing.Point(618,15)
$CloseBtn.Add_Click({ $form.Close() })
$form.Controls.Add($CloseBtn)

# ---- Startup Log ----
InfoMessage "Wazuh Agent Installer v1.0"
InfoMessage "Running as Administrator: $IsAdmin"
InfoMessage "Log file: $LogPath"
InfoMessage "Wazuh Manager: $WAZUH_MANAGER"
InfoMessage "Agent Version: $WAZUH_AGENT_VERSION"
InfoMessage "Default NIDS: Suricata (use radio buttons to change)"
InfoMessage "Ready to install. Click 'Install' to begin."

[void]$form.ShowDialog()
