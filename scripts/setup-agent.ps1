<#
.SYNOPSIS
    Wazuh Agent Setup Wizard / Upgrade Assistant.

.DESCRIPTION
    NORMAL MODE (default):
      3-step wizard: Install -> OAuth2 Config -> Reboot.
      Fresh install flow. Fails gracefully if not admin.

    UPDATE MODE (-Update):
      2-step wizard: Install -> Reboot.
      Auto-elevates to admin. Auto-detects installed IDS,
      YARA, and Manager address from ossec.conf.
      Skips OAuth2 config wizard (still installs the binary).

    Place a "logo.png" in the same directory for branding.
    Source: https://github.com/ADORSYS-GIS/wazuh-agent/blob/main/assets/wazuh-logo.png

.PARAMETER Update
    Launch in Update/Upgrade mode with auto-detection and 2-step flow.

.NOTES
    Requires: PowerShell 5.1+ / Windows / Run as Administrator
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Update,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

#requires -version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest

# -------------------------------------------------
# Resolve script/exe path (works both as .ps1 and compiled .exe)
# -------------------------------------------------
$ScriptExePath = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} elseif ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName -and
          [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName -notmatch 'powershell|pwsh') {
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
} else {
    $null
}
$ScriptDir = if ($ScriptExePath) { Split-Path -Parent $ScriptExePath } else { $PWD.Path }

# -------------------------------------------------
# Configuration (loaded early so -Help can display versions)
# -------------------------------------------------
$LOG_LEVEL             = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$APP_NAME              = if ($env:APP_NAME) { $env:APP_NAME } else { "wazuh-cert-oauth2-client" }
$WAZUH_MANAGER         = if ($env:WAZUH_MANAGER) { $env:WAZUH_MANAGER } else { "" }
$WAZUH_AGENT_VERSION   = if ($env:WAZUH_AGENT_VERSION) { $env:WAZUH_AGENT_VERSION } else { "4.13.1-1" }
$OSSEC_PATH            = "C:\Program Files (x86)\ossec-agent\"
$OSSEC_CONF_PATH       = Join-Path -Path $OSSEC_PATH -ChildPath "ossec.conf"
$RepoUrl               = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main"
$VERSION_FILE_URL      = "$RepoUrl/version.txt"
$VERSION_FILE_PATH     = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
$WAZUH_YARA_VERSION    = if ($env:WAZUH_YARA_VERSION) { $env:WAZUH_YARA_VERSION } else { "0.3.14" }
$WAZUH_SNORT_VERSION   = if ($env:WAZUH_SNORT_VERSION) { $env:WAZUH_SNORT_VERSION } else { "0.2.4" }
$WAZUH_AGENT_STATUS_VERSION = if ($env:WAZUH_AGENT_STATUS_VERSION) { $env:WAZUH_AGENT_STATUS_VERSION } else { "0.4.1-rc3" }
$WOPS_VERSION          = if ($env:WOPS_VERSION) { $env:WOPS_VERSION } else { "0.4.0" }
$WAZUH_SURICATA_VERSION = if ($env:WAZUH_SURICATA_VERSION) { $env:WAZUH_SURICATA_VERSION } else { "0.1.4" }

# -------------------------------------------------
# Help screen (-Help does NOT require admin)
# -------------------------------------------------
if ($Help) {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Detect what is currently installed
    $ossecInstalled    = Test-Path "C:\Program Files (x86)\ossec-agent\ossec-agent.exe"
    $oauth2Installed   = Test-Path "C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe"
    $yaraExeExists     = Test-Path "C:\Program Files (x86)\ossec-agent\active-response\bin\yara\yara64.exe"
    $yaraBatExists     = Test-Path "C:\Program Files (x86)\ossec-agent\active-response\bin\yara.bat"
    $yaraInstalled     = $yaraExeExists -or $yaraBatExists
    $snortTask         = Get-ScheduledTask -TaskName "SnortStartup" -ErrorAction SilentlyContinue
    $suricataTask      = Get-ScheduledTask -TaskName "SuricataStartup" -ErrorAction SilentlyContinue
    $versionFile       = "C:\Program Files (x86)\ossec-agent\version.txt"
    $installedVersion  = if (Test-Path $versionFile) { (Get-Content $versionFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim() } else { "N/A" }

    # Read manager from ossec.conf
    $currentManager = "N/A"
    if (Test-Path $OSSEC_CONF_PATH) {
        try {
            [xml]$conf = Get-Content $OSSEC_CONF_PATH -ErrorAction Stop
            $addr = $conf.ossec_config.client.server.address
            if ($addr) { $currentManager = $addr }
        } catch {}
    }

    $statusIcon = { param($installed) if ($installed) { "Installed" } else { "Not installed" } }

    $infoText = @"
WAZUH AGENT SETUP WIZARD
========================

USAGE:
  .\setup-agent.ps1              Fresh install (3-step wizard)
  .\setup-agent.ps1 -Update      Upgrade mode (2-step, auto-detect)
  .\setup-agent.ps1 -Help        Show this help screen

CONFIGURED VERSIONS (what will be installed):
  Wazuh Agent ............. $WAZUH_AGENT_VERSION
  OAuth2 Client (wops) ... v$WOPS_VERSION
  YARA ................... v$WAZUH_YARA_VERSION
  Snort .................. v$WAZUH_SNORT_VERSION
  Suricata ............... v$WAZUH_SURICATA_VERSION
  Agent Status ........... v$WAZUH_AGENT_STATUS_VERSION

CURRENT INSTALLATION STATUS:
  Installed Version ...... $installedVersion
  Wazuh Agent ............ $(& $statusIcon $ossecInstalled)
  OAuth2 Client .......... $(& $statusIcon $oauth2Installed)
  YARA ................... $(& $statusIcon $yaraInstalled)
  Snort (scheduled task) . $(& $statusIcon ($null -ne $snortTask))
  Suricata (sched. task) . $(& $statusIcon ($null -ne $suricataTask))
  Manager Address ........ $currentManager

ENVIRONMENT OVERRIDES:
  Set these env vars before running to override defaults:
    WAZUH_AGENT_VERSION, WOPS_VERSION, WAZUH_YARA_VERSION,
    WAZUH_SNORT_VERSION, WAZUH_SURICATA_VERSION,
    WAZUH_AGENT_STATUS_VERSION, WAZUH_MANAGER, LOG_LEVEL

REQUIREMENTS:
  - PowerShell 5.1 or later
  - Windows (x64)
  - Run as Administrator (except -Help)
"@

    # Themed help window
    $helpForm = New-Object System.Windows.Forms.Form -Property @{
        Text          = "Wazuh Agent Setup - Help"
        Size          = New-Object System.Drawing.Size(620, 640)
        StartPosition = "CenterScreen"
        BackColor     = [System.Drawing.Color]::White
        ForeColor     = [System.Drawing.Color]::Black
        Font          = New-Object System.Drawing.Font("Segoe UI", 10)
        FormBorderStyle = "FixedDialog"
        MaximizeBox   = $false
    }
    try { $helpForm.Icon = [System.Drawing.SystemIcons]::Information } catch {}

    $helpHeader = New-Object System.Windows.Forms.Panel -Property @{
        Height = 55; Dock = "Top"
        BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    }
    $helpForm.Controls.Add($helpHeader)

    $helpTitleX = 16
    $helpLogoPath = Join-Path $ScriptDir "logo.png"
    if (Test-Path $helpLogoPath) {
        try {
            $helpLogoImg = [System.Drawing.Image]::FromFile($helpLogoPath)
            $s = [Math]::Min(40 / $helpLogoImg.Width, 40 / $helpLogoImg.Height)
            $helpLogoPb = New-Object System.Windows.Forms.PictureBox -Property @{
                Size = New-Object System.Drawing.Size(([int]($helpLogoImg.Width * $s)), ([int]($helpLogoImg.Height * $s)))
                Location = New-Object System.Drawing.Point(16, 8)
                SizeMode = "Zoom"; Image = $helpLogoImg
                BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
            }
            $helpHeader.Controls.Add($helpLogoPb)
            $helpTitleX = $helpLogoPb.Location.X + $helpLogoPb.Width + 10
        } catch {}
    }

    $helpTitleLbl = New-Object System.Windows.Forms.Label -Property @{
        Text = "Wazuh Agent Setup - Help & Status"
        Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        AutoSize = $true; Location = New-Object System.Drawing.Point($helpTitleX, 14)
        BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    }
    $helpHeader.Controls.Add($helpTitleLbl)

    $helpTextBox = New-Object System.Windows.Forms.RichTextBox -Property @{
        Text = $infoText
        Font = New-Object System.Drawing.Font("Cascadia Mono,Consolas,Courier New", 9)
        ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
        BorderStyle = "None"; ReadOnly = $true; WordWrap = $false
        ScrollBars = "Vertical"
        Location = New-Object System.Drawing.Point(16, 65)
        Size = New-Object System.Drawing.Size(572, 480)
    }
    $helpForm.Controls.Add($helpTextBox)

    $helpCloseBtn = New-Object System.Windows.Forms.Button -Property @{
        Text = "Close"; FlatStyle = "Flat"
        Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        ForeColor = [System.Drawing.Color]::White
        BackColor = [System.Drawing.Color]::FromArgb(53, 149, 249)
        Size = New-Object System.Drawing.Size(100, 36)
        Location = New-Object System.Drawing.Point(488, 555)
        Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    $helpCloseBtn.FlatAppearance.BorderSize = 0
    $helpCloseBtn.Add_Click({ $helpForm.Close() })
    $helpForm.Controls.Add($helpCloseBtn)

    $helpForm.ShowDialog() | Out-Null
    $helpForm.Dispose()
    exit
}

# -------------------------------------------------
# Admin handling
# -------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    if ($Update) {
        # Update mode: auto-elevate
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($ScriptExePath -and $ScriptExePath -match '\.exe$') {
            $psi.FileName  = $ScriptExePath
            $psi.Arguments = "-Update"
        } else {
            $psi.FileName  = (Get-Process -Id $PID).Path
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptExePath`" -Update"
        }
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Administrator approval is required. Exiting.",
                "Wazuh Agent Upgrade Assistant", "OK", "Warning"
            ) | Out-Null
            exit 1
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "This installer must be run as Administrator.`n`nPlease right-click and select 'Run as Administrator'.",
            "Wazuh Agent Setup", "OK", "Error"
        ) | Out-Null
        exit 1
    }
}

# -------------------------------------------------
# Globals
# -------------------------------------------------
$AppName = if ($Update) { "Wazuh Agent Upgrade Assistant" } else { "Wazuh Agent Setup Wizard" }
$global:InstallerFiles = @()
$global:CurrentStep = 1
$global:InstallationComplete = $false

# -------------------------------------------------
# Theme (#3595F9 blue, black text, white bg)
# -------------------------------------------------
$Theme = @{
    BgDark       = [System.Drawing.Color]::White
    BgPanel      = [System.Drawing.Color]::FromArgb(240, 240, 240)
    BgInput      = [System.Drawing.Color]::FromArgb(250, 250, 250)
    BgLog        = [System.Drawing.Color]::FromArgb(245, 245, 245)
    FgPrimary    = [System.Drawing.Color]::Black
    FgDim        = [System.Drawing.Color]::FromArgb(100, 100, 100)
    FgLog        = [System.Drawing.Color]::FromArgb(40, 40, 40)
    Accent       = [System.Drawing.Color]::FromArgb(53, 149, 249)
    AccentHover  = [System.Drawing.Color]::FromArgb(30, 120, 220)
    Success      = [System.Drawing.Color]::FromArgb(30, 150, 80)
    Warning      = [System.Drawing.Color]::FromArgb(180, 130, 0)
    Error        = [System.Drawing.Color]::FromArgb(200, 50, 50)
    Border       = [System.Drawing.Color]::FromArgb(53, 149, 249)
}

$FontFamily = "Segoe UI"
$MonoFamily = "Cascadia Mono,Consolas,Courier New"

# -------------------------------------------------
# Logo
# -------------------------------------------------
$LogoPath = Join-Path $ScriptDir "logo.png"

$script:LogoImage = $null
if (Test-Path $LogoPath) {
    try { $script:LogoImage = [System.Drawing.Image]::FromFile($LogoPath) } catch {}
}

# =========================================================
# BUILD FORM
# =========================================================
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form -Property @{
    Text            = $AppName
    Size            = New-Object System.Drawing.Size(780, 820)
    MinimumSize     = New-Object System.Drawing.Size(700, 720)
    StartPosition   = "CenterScreen"
    BackColor       = $Theme.BgDark
    ForeColor       = $Theme.FgPrimary
    Font            = New-Object System.Drawing.Font($FontFamily, 10)
    FormBorderStyle = "Sizable"
}
try { $form.Icon = [System.Drawing.SystemIcons]::Shield } catch {}

# --- Header ---
$pnlHeader = New-Object System.Windows.Forms.Panel -Property @{
    Height = 70; Dock = "Top"; BackColor = $Theme.BgPanel
}
$form.Controls.Add($pnlHeader)

$headerTextX = 16
if ($null -ne $script:LogoImage) {
    $srcW = $script:LogoImage.Width; $srcH = $script:LogoImage.Height
    $scale = [Math]::Min(50 / $srcW, 50 / $srcH)
    $logoPb = New-Object System.Windows.Forms.PictureBox -Property @{
        Size = New-Object System.Drawing.Size(([int]($srcW * $scale)), ([int]($srcH * $scale)))
        Location = New-Object System.Drawing.Point(16, 10)
        SizeMode = "Zoom"; Image = $script:LogoImage; BackColor = $Theme.BgPanel
    }
    $pnlHeader.Controls.Add($logoPb)
    $headerTextX = $logoPb.Location.X + $logoPb.Width + 12
}

$lblTitle = New-Object System.Windows.Forms.Label -Property @{
    Text = "Step 1: Installation"
    Font = New-Object System.Drawing.Font($FontFamily, 16, [System.Drawing.FontStyle]::Bold)
    ForeColor = $Theme.FgPrimary; BackColor = $Theme.BgPanel
    AutoSize = $true; Location = New-Object System.Drawing.Point($headerTextX, 10)
}
$pnlHeader.Controls.Add($lblTitle)

$lblStatus = New-Object System.Windows.Forms.Label -Property @{
    Text = "Ready"
    Font = New-Object System.Drawing.Font($FontFamily, 9)
    ForeColor = $Theme.FgDim; BackColor = $Theme.BgPanel
    AutoSize = $true; Location = New-Object System.Drawing.Point(($headerTextX + 2), 42)
}
$pnlHeader.Controls.Add($lblStatus)

# --- Log Box ---
$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{
    Location = New-Object System.Drawing.Point(16, 78)
    Font = New-Object System.Drawing.Font($MonoFamily, 9)
    ForeColor = $Theme.FgLog; BackColor = $Theme.BgLog
    BorderStyle = "None"; ReadOnly = $true; WordWrap = $true
    ScrollBars = "Vertical"; Anchor = "Top,Bottom,Left,Right"
}
$form.Controls.Add($LogBox)

# --- Progress Bar ---
$ProgressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
    Style = "Continuous"; Value = 0
    Location = New-Object System.Drawing.Point(16, 370)
    Height = 6; Anchor = "Bottom,Left,Right"
}
$form.Controls.Add($ProgressBar)

# =========================================================
# STEP 1 PANEL: Installation options
# =========================================================
$Step1Panel = New-Object System.Windows.Forms.Panel -Property @{
    Location = New-Object System.Drawing.Point(16, 385)
    Anchor = "Bottom,Left,Right"; BackColor = $Theme.BgDark
}
$form.Controls.Add($Step1Panel)

# Manager Address
$ManagerGroup = New-Object System.Windows.Forms.GroupBox -Property @{
    Text = "Wazuh Manager Address"; ForeColor = $Theme.FgPrimary
    Size = New-Object System.Drawing.Size(330, 100)
    Location = New-Object System.Drawing.Point(0, 5)
}
$Step1Panel.Controls.Add($ManagerGroup)

$ManagerLabel = New-Object System.Windows.Forms.Label -Property @{
    Text = "Enter Manager Address (hostname or IP):"
    AutoSize = $true; Location = New-Object System.Drawing.Point(12, 28)
    ForeColor = $Theme.FgDim
}
$ManagerGroup.Controls.Add($ManagerLabel)

$ManagerTextBox = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(12, 55)
    Size = New-Object System.Drawing.Size(300, 25)
    Font = New-Object System.Drawing.Font($MonoFamily, 10)
    ForeColor = $Theme.FgPrimary; BackColor = $Theme.BgInput
    BorderStyle = "FixedSingle"
}
$ManagerGroup.Controls.Add($ManagerTextBox)

# NIDS
$NidsGroup = New-Object System.Windows.Forms.GroupBox -Property @{
    Text = "Network IDS Selection"; ForeColor = $Theme.FgPrimary
    Size = New-Object System.Drawing.Size(330, 100)
    Location = New-Object System.Drawing.Point(340, 5)
    Anchor = "Top,Left,Right"
}
$Step1Panel.Controls.Add($NidsGroup)

$SnortRadio = New-Object System.Windows.Forms.RadioButton -Property @{
    Text = "Install Snort"; AutoSize = $true
    Location = New-Object System.Drawing.Point(12, 32); ForeColor = $Theme.FgPrimary
}
$NidsGroup.Controls.Add($SnortRadio)

$SuricataRadio = New-Object System.Windows.Forms.RadioButton -Property @{
    Text = "Install Suricata"; AutoSize = $true
    Location = New-Object System.Drawing.Point(12, 62); Checked = $true
    ForeColor = $Theme.FgPrimary
}
$NidsGroup.Controls.Add($SuricataRadio)

# YARA
$YaraCheckbox = New-Object System.Windows.Forms.CheckBox -Property @{
    Text = "Install YARA (optional)"; AutoSize = $true
    Location = New-Object System.Drawing.Point(12, 115); ForeColor = $Theme.FgPrimary
}
$Step1Panel.Controls.Add($YaraCheckbox)

# Install button
$InstallBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "Start Installation"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    ForeColor = [System.Drawing.Color]::White; BackColor = $Theme.Accent
    Size = New-Object System.Drawing.Size(180, 42)
    Location = New-Object System.Drawing.Point(0, 150)
    Cursor = [System.Windows.Forms.Cursors]::Hand
}
$InstallBtn.FlatAppearance.BorderSize = 0
$InstallBtn.FlatAppearance.MouseOverBackColor = $Theme.AccentHover
$Step1Panel.Controls.Add($InstallBtn)

# =========================================================
# STEP 2 PANEL: OAuth2 (Install mode only)
# =========================================================
$Step2Panel = New-Object System.Windows.Forms.Panel -Property @{
    Location = New-Object System.Drawing.Point(16, 385)
    Anchor = "Bottom,Left,Right"; BackColor = $Theme.BgDark; Visible = $false
}
$form.Controls.Add($Step2Panel)

$OAuth2InfoLabel = New-Object System.Windows.Forms.Label -Property @{
    Text = "Click 'Configure OAuth2' to run the authentication setup.`nA new PowerShell window will open. Follow the prompts to complete authentication."
    AutoSize = $false; Size = New-Object System.Drawing.Size(700, 50)
    Location = New-Object System.Drawing.Point(0, 5); ForeColor = $Theme.FgPrimary
}
$Step2Panel.Controls.Add($OAuth2InfoLabel)

$ConfigureBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "Configure OAuth2"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    ForeColor = [System.Drawing.Color]::White; BackColor = $Theme.Accent
    Size = New-Object System.Drawing.Size(180, 40)
    Location = New-Object System.Drawing.Point(0, 65)
    Cursor = [System.Windows.Forms.Cursors]::Hand
}
$ConfigureBtn.FlatAppearance.BorderSize = 0
$ConfigureBtn.FlatAppearance.MouseOverBackColor = $Theme.AccentHover
$Step2Panel.Controls.Add($ConfigureBtn)

# =========================================================
# STEP 3 (or 2 in Update) PANEL: Complete
# =========================================================
$Step3Panel = New-Object System.Windows.Forms.Panel -Property @{
    Location = New-Object System.Drawing.Point(16, 385)
    Anchor = "Bottom,Left,Right"; BackColor = $Theme.BgDark; Visible = $false
}
$form.Controls.Add($Step3Panel)

$CompletionLabel = New-Object System.Windows.Forms.Label -Property @{
    Text = "Setup Complete!`n`nThe Wazuh Agent has been installed and configured.`nA system reboot is recommended to apply all changes."
    AutoSize = $false; Size = New-Object System.Drawing.Size(700, 70)
    Location = New-Object System.Drawing.Point(0, 5)
    Font = New-Object System.Drawing.Font($FontFamily, 11); ForeColor = $Theme.FgPrimary
}
$Step3Panel.Controls.Add($CompletionLabel)

$RebootNowBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "Reboot Now"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    ForeColor = [System.Drawing.Color]::White; BackColor = $Theme.Accent
    Size = New-Object System.Drawing.Size(140, 40)
    Location = New-Object System.Drawing.Point(0, 85)
    Cursor = [System.Windows.Forms.Cursors]::Hand
}
$RebootNowBtn.FlatAppearance.BorderSize = 0
$RebootNowBtn.FlatAppearance.MouseOverBackColor = $Theme.AccentHover
$Step3Panel.Controls.Add($RebootNowBtn)

$RebootLaterBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "Reboot Later"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 10)
    ForeColor = $Theme.FgPrimary; BackColor = $Theme.BgPanel
    Size = New-Object System.Drawing.Size(140, 40)
    Location = New-Object System.Drawing.Point(150, 85)
    Cursor = [System.Windows.Forms.Cursors]::Hand
}
$RebootLaterBtn.FlatAppearance.BorderSize = 1
$RebootLaterBtn.FlatAppearance.BorderColor = $Theme.Border
$Step3Panel.Controls.Add($RebootLaterBtn)

# --- Navigation ---
$BackBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "< Back"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 10)
    ForeColor = $Theme.FgPrimary; BackColor = $Theme.BgPanel
    Size = New-Object System.Drawing.Size(100, 38); Visible = $false
    Anchor = "Bottom,Right"; Cursor = [System.Windows.Forms.Cursors]::Hand
}
$BackBtn.FlatAppearance.BorderSize = 1
$BackBtn.FlatAppearance.BorderColor = $Theme.Border
$form.Controls.Add($BackBtn)

$NextBtn = New-Object System.Windows.Forms.Button -Property @{
    Text = "Next >"; FlatStyle = "Flat"
    Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    ForeColor = [System.Drawing.Color]::White; BackColor = $Theme.Accent
    Size = New-Object System.Drawing.Size(100, 38); Enabled = $false
    Anchor = "Bottom,Right"; Cursor = [System.Windows.Forms.Cursors]::Hand
}
$NextBtn.FlatAppearance.BorderSize = 0
$NextBtn.FlatAppearance.MouseOverBackColor = $Theme.AccentHover
$form.Controls.Add($NextBtn)

# -------------------------------------------------
# Layout
# -------------------------------------------------
$layoutHandler = {
    $w = $form.ClientSize.Width
    $h = $form.ClientSize.Height

    $bottomReserved = 300
    $logHeight = $h - $bottomReserved - 78
    if ($logHeight -lt 60) { $logHeight = 60 }

    $LogBox.Size          = New-Object System.Drawing.Size(($w - 32), $logHeight)
    $ProgressBar.Width    = $w - 32
    $ProgressBar.Location = New-Object System.Drawing.Point(16, (78 + $logHeight + 6))

    $panelY = 78 + $logHeight + 20
    $panelW = $w - 32
    $panelH = 230
    $Step1Panel.Location = New-Object System.Drawing.Point(16, $panelY)
    $Step1Panel.Size     = New-Object System.Drawing.Size($panelW, $panelH)
    $Step2Panel.Location = New-Object System.Drawing.Point(16, $panelY)
    $Step2Panel.Size     = New-Object System.Drawing.Size($panelW, $panelH)
    $Step3Panel.Location = New-Object System.Drawing.Point(16, $panelY)
    $Step3Panel.Size     = New-Object System.Drawing.Size($panelW, $panelH)

    $NidsGroup.Width = $panelW - $NidsGroup.Location.X

    $BackBtn.Location = New-Object System.Drawing.Point(($w - 230), ($h - 50))
    $NextBtn.Location = New-Object System.Drawing.Point(($w - 120), ($h - 50))
}
$form.Add_Resize($layoutHandler)
$form.Add_Shown($layoutHandler)

# =========================================================
# LOGGING
# =========================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "INFO"    { "[INFO]    " }
        "SUCCESS" { "[OK]      " }
        "WARNING" { "[WARN]    " }
        "ERROR"   { "[ERROR]   " }
    }
    $color = switch ($Level) {
        "INFO"    { $Theme.FgLog }
        "SUCCESS" { $Theme.Success }
        "WARNING" { $Theme.Warning }
        "ERROR"   { $Theme.Error }
    }
    $LogBox.SelectionStart  = $LogBox.TextLength
    $LogBox.SelectionLength = 0
    $LogBox.SelectionColor  = $Theme.FgDim
    $LogBox.AppendText("$timestamp ")
    $LogBox.SelectionStart  = $LogBox.TextLength
    $LogBox.SelectionColor  = $color
    $LogBox.AppendText("$prefix$Message`r`n")
    $LogBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function InfoMessage    { param([string]$Message) Write-Log $Message "INFO" }
function SuccessMessage { param([string]$Message) Write-Log $Message "SUCCESS" }
function WarnMessage    { param([string]$Message) Write-Log $Message "WARNING" }
function ErrorMessage   { param([string]$Message) Write-Log $Message "ERROR" }

function SectionSeparator {
    param([string]$SectionName)
    Write-Log "==================================================" "INFO"
    Write-Log "  $SectionName" "INFO"
    Write-Log "==================================================" "INFO"
}

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Action
    )
    InfoMessage "[START] $Name"
    $lblStatus.Text = "Step: $Name"
    [System.Windows.Forms.Application]::DoEvents()
    try {
        & $Action
        SuccessMessage "[OK] $Name"
    } catch {
        ErrorMessage "[FAIL] $Name : $($_.Exception.Message)"
        throw
    }
}

# =========================================================
# DETECTION FUNCTIONS (Update mode)
# =========================================================
function Test-SnortInstalled {
    $paths = @(
        "C:\Snort\bin\snort.exe",
        "C:\Program Files\Snort\bin\snort.exe",
        "C:\Program Files (x86)\Snort\bin\snort.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { InfoMessage "Detected Snort at: $p"; return $true }
    }
    try {
        $cmd = Get-Command snort -ErrorAction SilentlyContinue
        if ($cmd) { InfoMessage "Detected Snort in PATH: $($cmd.Source)"; return $true }
    } catch {}
    return $false
}

function Test-SuricataInstalled {
    $paths = @(
        "C:\Program Files\Suricata\suricata.exe",
        "C:\Program Files (x86)\Suricata\suricata.exe",
        "C:\Suricata\suricata.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { InfoMessage "Detected Suricata at: $p"; return $true }
    }
    try {
        $cmd = Get-Command suricata -ErrorAction SilentlyContinue
        if ($cmd) { InfoMessage "Detected Suricata in PATH: $($cmd.Source)"; return $true }
    } catch {}
    return $false
}

function Test-YaraInstalled {
    $arDir = "C:\Program Files (x86)\ossec-agent\active-response\bin"
    $yaraExe = Join-Path $arDir "yara\yara64.exe"
    $yaraBat = Join-Path $arDir "yara.bat"
    foreach ($p in @($yaraExe, $yaraBat)) {
        if (Test-Path $p) { InfoMessage "Detected YARA at: $p"; return $true }
    }
    try {
        $cmd = Get-Command yara64 -ErrorAction SilentlyContinue
        if ($cmd) { InfoMessage "Detected YARA in PATH: $($cmd.Source)"; return $true }
    } catch {}
    return $false
}

function Get-CurrentWazuhManager {
    if (Test-Path $OSSEC_CONF_PATH) {
        try {
            [xml]$conf = Get-Content -Path $OSSEC_CONF_PATH -ErrorAction Stop
            $addr = $conf.ossec_config.client.server.address
            if ($addr) { InfoMessage "Detected Manager in ossec.conf: $addr"; return $addr }
            else { WarnMessage "Manager address not found in ossec.conf"; return $null }
        } catch {
            WarnMessage "Failed to parse ossec.conf: $($_.Exception.Message)"; return $null
        }
    } else {
        WarnMessage "ossec.conf not found at: $OSSEC_CONF_PATH"; return $null
    }
}

function Set-DefaultIDS {
    InfoMessage "Detecting installed IDS..."
    $snort = Test-SnortInstalled
    $suricata = Test-SuricataInstalled

    if ($snort -and $suricata) {
        InfoMessage "Both detected. Defaulting to Suricata."
        $SuricataRadio.Checked = $true
    } elseif ($snort) {
        InfoMessage "Snort detected."
        $SnortRadio.Checked = $true; $SuricataRadio.Checked = $false
    } elseif ($suricata) {
        InfoMessage "Suricata detected."
        $SuricataRadio.Checked = $true
    } else {
        InfoMessage "No IDS detected. Defaulting to Suricata."
        $SuricataRadio.Checked = $true
    }
}

# =========================================================
# CLEANUP & PATH REFRESH
# =========================================================
function Cleanup-Installers {
    foreach ($file in $global:InstallerFiles) {
        if (Test-Path $file) { Remove-Item $file -Force; InfoMessage "Removed: $file" }
    }
}

function Refresh-EnvironmentPath {
    try {
        InfoMessage "Refreshing environment PATH..."
        $m = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
        $u = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        $env:Path = $u + ";" + $m
        SuccessMessage "PATH refreshed."
    } catch { WarnMessage "Failed to refresh PATH: $($_.Exception.Message)" }
}

# =========================================================
# INSTALLATION FUNCTIONS
# =========================================================
function Install-Dependencies {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/deps.ps1"
    $path = "$env:TEMP\deps.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading dependency script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Executing dependency script..."

    $output = & powershell.exe -ExecutionPolicy Bypass -File $path 2>&1
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) { ErrorMessage $line.ToString() }
        else { InfoMessage $line.ToString() }
    }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Dependency script failed (exit $LASTEXITCODE)" }
    Refresh-EnvironmentPath
}

function Install-WazuhAgent {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/install.ps1"
    $path = "$env:TEMP\install.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading Wazuh agent script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing Wazuh agent..."

    $process = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$path`" -WAZUH_AGENT_VERSION `"$WAZUH_AGENT_VERSION`"" `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput "$env:TEMP\wazuh_out.log" `
        -RedirectStandardError  "$env:TEMP\wazuh_err.log" -Wait

    if (Test-Path "$env:TEMP\wazuh_out.log") { Get-Content "$env:TEMP\wazuh_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\wazuh_out.log" -Force }
    if (Test-Path "$env:TEMP\wazuh_err.log") { Get-Content "$env:TEMP\wazuh_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\wazuh_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "Wazuh agent install failed (exit $($process.ExitCode))" }
}

function Install-OAuth2Client {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-cert-oauth2/refs/tags/v$WOPS_VERSION/scripts/install.ps1"
    $path = "$env:TEMP\wazuh-cert-oauth2-install.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading OAuth2 client script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing OAuth2 client..."

    $process = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$path`" -LOG_LEVEL `"$LOG_LEVEL`" -OSSEC_CONF_PATH `"$OSSEC_CONF_PATH`" -APP_NAME `"$APP_NAME`" -WOPS_VERSION `"$WOPS_VERSION`"" `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput "$env:TEMP\oauth2_out.log" `
        -RedirectStandardError  "$env:TEMP\oauth2_err.log" -Wait

    if (Test-Path "$env:TEMP\oauth2_out.log") { Get-Content "$env:TEMP\oauth2_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\oauth2_out.log" -Force }
    if (Test-Path "$env:TEMP\oauth2_err.log") { Get-Content "$env:TEMP\oauth2_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\oauth2_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "OAuth2 client install failed (exit $($process.ExitCode))" }
}

function Install-Yara {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/install.ps1"
    $path = "$env:TEMP\install_yara.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading YARA script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing YARA..."

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
        -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\yara_out.log" -RedirectStandardError "$env:TEMP\yara_err.log" -Wait

    if (Test-Path "$env:TEMP\yara_out.log") { Get-Content "$env:TEMP\yara_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\yara_out.log" -Force }
    if (Test-Path "$env:TEMP\yara_err.log") { Get-Content "$env:TEMP\yara_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\yara_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "YARA install failed (exit $($process.ExitCode))" }
}

function Uninstall-Yara {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/tags/v$WAZUH_YARA_VERSION/scripts/uninstall.ps1"
    $path = "$env:TEMP\uninstall_yara.ps1"
    $global:InstallerFiles += $path

    if (Test-YaraInstalled) {
        InfoMessage "Removing existing YARA..."
        Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
            -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\unyara_out.log" -RedirectStandardError "$env:TEMP\unyara_err.log" -Wait
        if (Test-Path "$env:TEMP\unyara_out.log") { Get-Content "$env:TEMP\unyara_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\unyara_out.log" -Force }
        if (Test-Path "$env:TEMP\unyara_err.log") { Get-Content "$env:TEMP\unyara_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\unyara_err.log" -Force }
        if ($process.ExitCode -ne 0) { WarnMessage "YARA uninstall exit code $($process.ExitCode)" }
    } else { InfoMessage "YARA not installed. Skipping." }
}

function Install-Snort {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/snort.ps1"
    $path = "$env:TEMP\snort.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading Snort script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing Snort..."

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
        -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\snort_out.log" -RedirectStandardError "$env:TEMP\snort_err.log" -Wait

    if (Test-Path "$env:TEMP\snort_out.log") { Get-Content "$env:TEMP\snort_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\snort_out.log" -Force }
    if (Test-Path "$env:TEMP\snort_err.log") { Get-Content "$env:TEMP\snort_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\snort_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "Snort install failed (exit $($process.ExitCode))" }
}

function Uninstall-Snort {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-snort/refs/tags/v$WAZUH_SNORT_VERSION/scripts/windows/uninstall.ps1"
    $path = "$env:TEMP\uninstall_snort.ps1"
    $global:InstallerFiles += $path

    $task = Get-ScheduledTask -TaskName "SnortStartup" -ErrorAction SilentlyContinue
    if ($task) {
        InfoMessage "Removing existing Snort..."
        Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
            -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\unsnort_out.log" -RedirectStandardError "$env:TEMP\unsnort_err.log" -Wait
        if (Test-Path "$env:TEMP\unsnort_out.log") { Get-Content "$env:TEMP\unsnort_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\unsnort_out.log" -Force }
        if (Test-Path "$env:TEMP\unsnort_err.log") { Get-Content "$env:TEMP\unsnort_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\unsnort_err.log" -Force }
        if ($process.ExitCode -ne 0) { WarnMessage "Snort uninstall exit code $($process.ExitCode)" }
    }
}

function Install-Suricata {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/install.ps1"
    $path = "$env:TEMP\suricata.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading Suricata script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing Suricata..."

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
        -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\suricata_out.log" -RedirectStandardError "$env:TEMP\suricata_err.log" -Wait

    if (Test-Path "$env:TEMP\suricata_out.log") { Get-Content "$env:TEMP\suricata_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\suricata_out.log" -Force }
    if (Test-Path "$env:TEMP\suricata_err.log") { Get-Content "$env:TEMP\suricata_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\suricata_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "Suricata install failed (exit $($process.ExitCode))" }
}

function Uninstall-Suricata {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-suricata/refs/tags/v$WAZUH_SURICATA_VERSION/scripts/uninstall.ps1"
    $path = "$env:TEMP\uninstall_suricata.ps1"
    $global:InstallerFiles += $path

    $task = Get-ScheduledTask -TaskName "SuricataStartup" -ErrorAction SilentlyContinue
    if ($task) {
        InfoMessage "Removing existing Suricata..."
        Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
            -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\unsuricata_out.log" -RedirectStandardError "$env:TEMP\unsuricata_err.log" -Wait
        if (Test-Path "$env:TEMP\unsuricata_out.log") { Get-Content "$env:TEMP\unsuricata_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\unsuricata_out.log" -Force }
        if (Test-Path "$env:TEMP\unsuricata_err.log") { Get-Content "$env:TEMP\unsuricata_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\unsuricata_err.log" -Force }
        if ($process.ExitCode -ne 0) { WarnMessage "Suricata uninstall exit code $($process.ExitCode)" }
    }
}

function Install-AgentStatus {
    $url  = "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/tags/v$WAZUH_AGENT_STATUS_VERSION-user/scripts/install.ps1"
    $path = "$env:TEMP\install-agent-status.ps1"
    $global:InstallerFiles += $path

    InfoMessage "Downloading Agent Status script..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    InfoMessage "Installing Agent Status..."

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" `
        -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\status_out.log" -RedirectStandardError "$env:TEMP\status_err.log" -Wait

    if (Test-Path "$env:TEMP\status_out.log") { Get-Content "$env:TEMP\status_out.log" | ForEach-Object { InfoMessage $_ }; Remove-Item "$env:TEMP\status_out.log" -Force }
    if (Test-Path "$env:TEMP\status_err.log") { Get-Content "$env:TEMP\status_err.log" | ForEach-Object { ErrorMessage $_ }; Remove-Item "$env:TEMP\status_err.log" -Force }
    if ($process.ExitCode -ne 0) { throw "Agent Status install failed (exit $($process.ExitCode))" }
}

function DownloadVersionFile {
    if (!(Test-Path -Path $OSSEC_PATH)) {
        WarnMessage "ossec-agent folder not found. Skipping version file."
    } else {
        InfoMessage "Downloading version file..."
        Invoke-WebRequest -Uri $VERSION_FILE_URL -OutFile $VERSION_FILE_PATH -ErrorAction Stop
        InfoMessage "Version file downloaded."
    }
}

# =========================================================
# MAIN INSTALL
# =========================================================
function Do-Install {
    # Validate manager address
    $managerAddress = $ManagerTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($managerAddress)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a Wazuh Manager address.", "Required", "OK", "Warning") | Out-Null
        return
    }
    if ($managerAddress -notmatch '^[a-zA-Z0-9.\-]+$') {
        [System.Windows.Forms.MessageBox]::Show("Invalid address. Only alphanumeric, dots, and hyphens allowed.", "Invalid", "OK", "Warning") | Out-Null
        return
    }
    if ($managerAddress.Length -gt 253) {
        [System.Windows.Forms.MessageBox]::Show("Address too long (max 253 chars).", "Invalid", "OK", "Warning") | Out-Null
        return
    }

    $script:WAZUH_MANAGER = $managerAddress
    $env:WAZUH_MANAGER    = $managerAddress
    InfoMessage "Using Wazuh Manager: $managerAddress"

    # Lock UI
    $InstallBtn.Enabled = $false; $NextBtn.Enabled = $false
    $SnortRadio.Enabled = $false; $SuricataRadio.Enabled = $false
    $YaraCheckbox.Enabled = $false; $ManagerTextBox.Enabled = $false

    $ProgressBar.Style = "Marquee"; $ProgressBar.MarqueeAnimationSpeed = 30

    SectionSeparator "INSTALLATION START"

    try {
        Invoke-Step -Name "Installing Dependencies"   -Action { Install-Dependencies }
        Invoke-Step -Name "Installing Wazuh Agent"    -Action { Install-WazuhAgent }
        Invoke-Step -Name "Installing OAuth2 Client"  -Action { Install-OAuth2Client }
        Invoke-Step -Name "Installing Agent Status"   -Action { Install-AgentStatus }

        if ($YaraCheckbox.Checked) {
            Invoke-Step -Name "Installing YARA" -Action { Install-Yara }
        } else {
            Invoke-Step -Name "Removing YARA (if present)" -Action { Uninstall-Yara }
        }

        if ($SnortRadio.Checked) {
            Invoke-Step -Name "Removing Suricata (if present)" -Action { Uninstall-Suricata }
            Invoke-Step -Name "Installing Snort"               -Action { Install-Snort }
        } elseif ($SuricataRadio.Checked) {
            Invoke-Step -Name "Removing Snort (if present)" -Action { Uninstall-Snort }
            Invoke-Step -Name "Installing Suricata"         -Action { Install-Suricata }
        }

        Invoke-Step -Name "Downloading Version File" -Action { DownloadVersionFile }

        InfoMessage "Cleaning up..."
        Cleanup-Installers
        SectionSeparator "INSTALLATION COMPLETE"

        $global:InstallationComplete = $true

        $ProgressBar.Style = "Continuous"; $ProgressBar.Value = $ProgressBar.Maximum
        $NextBtn.Enabled = $true
        $lblStatus.Text  = "Installation Complete"

        if ($Update) {
            SuccessMessage "Upgrade completed! Click 'Next' for reboot options."
        } else {
            SuccessMessage "Installation completed! Click 'Next' to configure OAuth2."
        }

    } catch {
        $ProgressBar.Style = "Continuous"; $ProgressBar.Value = 0
        [System.Windows.Forms.MessageBox]::Show("Installation failed: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
        $InstallBtn.Enabled = $true
        $SnortRadio.Enabled = $true; $SuricataRadio.Enabled = $true
        $YaraCheckbox.Enabled = $true; $ManagerTextBox.Enabled = $true
        $lblStatus.Text = "Installation failed"
    }
}

# =========================================================
# OAUTH2 CONFIG (Install mode only)
# =========================================================
function Do-OAuth2Config {
    $ConfigureBtn.Enabled = $false; $NextBtn.Enabled = $false; $BackBtn.Enabled = $false

    SectionSeparator "OAUTH2 CONFIGURATION"

    $bin = 'C:\Program Files (x86)\ossec-agent\wazuh-cert-oauth2-client.exe'

    if (-not (Test-Path $bin)) {
        ErrorMessage "OAuth2 binary not found at: $bin"
        [System.Windows.Forms.MessageBox]::Show("OAuth2 binary not found.", "Error", "OK", "Error") | Out-Null
        $ConfigureBtn.Enabled = $true; $BackBtn.Enabled = $true
        return
    }

    InfoMessage "Launching OAuth2 configuration..."

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName    = "powershell.exe"
        $psi.Arguments   = "-NoProfile -Command `"& '$bin' o-auth2; exit `$LASTEXITCODE`""
        $psi.UseShellExecute = $true
        $psi.Verb        = "runas"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal

        $process = [System.Diagnostics.Process]::Start($psi)

        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        if ($process.ExitCode -eq 0) {
            SuccessMessage "OAuth2 configuration completed!"
            SectionSeparator "OAUTH2 CONFIGURATION END"
            $NextBtn.Enabled = $true
        } else {
            ErrorMessage "OAuth2 failed (exit $($process.ExitCode))"
            [System.Windows.Forms.MessageBox]::Show("OAuth2 failed (exit $($process.ExitCode)).", "Error", "OK", "Error") | Out-Null
            $ConfigureBtn.Enabled = $true; $BackBtn.Enabled = $true
        }
    } catch {
        ErrorMessage "Failed to run OAuth2: $($_.Exception.Message)"
        $ConfigureBtn.Enabled = $true; $BackBtn.Enabled = $true
    }
}

# =========================================================
# STEP NAVIGATION
# =========================================================
function Show-Step {
    param([int]$StepNumber)
    $global:CurrentStep = $StepNumber

    $Step1Panel.Visible = $false
    $Step2Panel.Visible = $false
    $Step3Panel.Visible = $false

    if ($Update) {
        # Update mode: Step 1 = Install, Step 2 = Complete (skip OAuth2)
        switch ($StepNumber) {
            1 {
                $lblTitle.Text      = "Step 1: Upgrade"
                $Step1Panel.Visible = $true
                $BackBtn.Visible    = $false
                $NextBtn.Visible    = $true
                $NextBtn.Enabled    = $global:InstallationComplete
                $InstallBtn.Enabled = -not $global:InstallationComplete
            }
            2 {
                $lblTitle.Text      = "Upgrade Complete"
                $Step3Panel.Visible = $true
                $BackBtn.Visible    = $false
                $NextBtn.Visible    = $false
                $CompletionLabel.Text = "Upgrade Complete!`n`nThe Wazuh Agent has been upgraded successfully.`nA system reboot is recommended to apply all changes."
            }
        }
    } else {
        # Normal mode: Step 1 = Install, Step 2 = OAuth2, Step 3 = Complete
        switch ($StepNumber) {
            1 {
                $lblTitle.Text      = "Step 1: Installation"
                $Step1Panel.Visible = $true
                $BackBtn.Visible    = $false
                $NextBtn.Visible    = $true
                $NextBtn.Enabled    = $global:InstallationComplete
                $InstallBtn.Enabled = -not $global:InstallationComplete
            }
            2 {
                $lblTitle.Text        = "Step 2: OAuth2 Configuration"
                $Step2Panel.Visible   = $true
                $BackBtn.Visible      = $true; $BackBtn.Enabled = $true
                $NextBtn.Visible      = $true; $NextBtn.Enabled = $false
                $ConfigureBtn.Enabled = $true
            }
            3 {
                $lblTitle.Text      = "Step 3: Setup Complete"
                $Step3Panel.Visible = $true
                $BackBtn.Visible    = $false
                $NextBtn.Visible    = $false
            }
        }
    }
    $lblStatus.Text = "Ready"
}

function Next-Step {
    if ($Update) {
        if ($global:CurrentStep -eq 1 -and $global:InstallationComplete) { Show-Step 2 }
    } else {
        if ($global:CurrentStep -eq 1) {
            if (-not $global:InstallationComplete) {
                [System.Windows.Forms.MessageBox]::Show("Please complete installation first.", "Not Ready", "OK", "Warning") | Out-Null
                return
            }
            Show-Step 2
        } elseif ($global:CurrentStep -eq 2) {
            Show-Step 3
        }
    }
}

function Previous-Step {
    if (-not $Update -and $global:CurrentStep -eq 2) { Show-Step 1 }
}

# =========================================================
# WIRE EVENTS
# =========================================================
$InstallBtn.Add_Click({ Do-Install })
$ConfigureBtn.Add_Click({ Do-OAuth2Config })
$BackBtn.Add_Click({ Previous-Step })
$NextBtn.Add_Click({ Next-Step })

$RebootNowBtn.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Reboot now?", "Confirm", "YesNo", "Question")
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        InfoMessage "Rebooting..."
        Start-Process shutdown.exe -ArgumentList "/r /t 5" -NoNewWindow
        $form.Close()
    }
})

$RebootLaterBtn.Add_Click({
    InfoMessage "Please reboot when convenient."
    [System.Windows.Forms.MessageBox]::Show("Please reboot to apply all changes.", "Complete", "OK", "Information") | Out-Null
    $form.Close()
})

# =========================================================
# STARTUP
# =========================================================
InfoMessage "$AppName"
InfoMessage "Running as Administrator: $IsAdmin"
InfoMessage "Agent Version: $WAZUH_AGENT_VERSION"

if ($Update) {
    InfoMessage "Mode: UPGRADE"

    # Auto-detect Manager
    $detected = Get-CurrentWazuhManager
    if ($detected) { $ManagerTextBox.Text = $detected }

    # Auto-detect IDS
    Set-DefaultIDS

    # Auto-detect YARA
    InfoMessage "Detecting YARA..."
    if (Test-YaraInstalled) {
        $YaraCheckbox.Checked = $true
        InfoMessage "YARA detected. Checkbox ON."
    } else {
        $YaraCheckbox.Checked = $false
        InfoMessage "YARA not detected. Checkbox OFF."
    }

    $InstallBtn.Text = "Start Upgrade"
} else {
    InfoMessage "Mode: FRESH INSTALL"
    InfoMessage "Default NIDS: Suricata"
}

InfoMessage "Ready. Enter Manager address and click '$($InstallBtn.Text)'."

Show-Step 1

$form.ShowDialog() | Out-Null
$form.Dispose()