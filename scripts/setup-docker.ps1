param(
    [switch]$CaptureLogs
)

# Wazuh Docker Listener Setup (Windows)

# Source shared utilities
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/utils.ps1" -OutFile "utils.ps1" -ErrorAction Stop
} catch {
    Write-Error "Failed to download utils.ps1: $($_.Exception.Message)"
    exit 1
}
. ./utils.ps1

$RepoUrl = if ($RepoUrl) { $RepoUrl } else { "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)" }

Set-StrictMode -Version Latest

# ==============================================================================
# Configuration
# ==============================================================================
$VENV_DIR = if ($env:VENV_DIR) { $env:VENV_DIR } else { "C:\wazuh-docker-env" }
$DOCKER_WODLE_DIR = Join-Path -Path $OSSEC_PATH -ChildPath "wodles\docker"
$DOCKER_LISTENER = Join-Path -Path $DOCKER_WODLE_DIR -ChildPath "DockerListener"

# ==============================================================================
# Main
# ==============================================================================

# 1. Exit silently if Docker is not installed or not running
$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    WarningMessage "Docker command not found. Skipping Docker monitoring setup."
    exit 0
}

try {
    # Check if daemon is running
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker daemon is not running." }
} catch {
    WarningMessage "Docker command found, but daemon is not running. Please start Docker."
    WarningMessage "Skipping Docker monitoring setup."
    exit 0
}

InfoMessage "Docker detected. Setting up Docker listener environment..."

# 2. Ensure Python3 exists
$pythonInfo = Get-FunctionalPythonPath
if (-not $pythonInfo) {
    ErrorMessage "Python 3 is not installed or not found in PATH."
    ErrorMessage "Please install Python 3 from https://www.python.org/downloads/"
    ErrorMessage "IMPORTANT: Ensure 'Add Python to PATH' is checked during installation."
    exit 0
}

$PYTHON_BIN = $pythonInfo.Path
$pythonVersion = $pythonInfo.Version
InfoMessage "Python version detected: $pythonVersion"

# 3. Create or repair virtual environment
if (-not (Test-Path $VENV_DIR)) {
    InfoMessage "Creating virtual environment at $VENV_DIR"
    & $PYTHON_BIN -m venv $VENV_DIR
    if ($LASTEXITCODE -ne 0) {
        ErrorMessage "Failed to create virtual environment."
        exit 0
    }
} else {
    $pipPath = Join-Path -Path $VENV_DIR -ChildPath "Scripts\pip.exe"
    if (-not (Test-Path $pipPath)) {
        InfoMessage "Existing venv is broken (no pip). Recreating..."
        Remove-Item -Recurse -Force $VENV_DIR
        & $PYTHON_BIN -m venv $VENV_DIR
        if ($LASTEXITCODE -ne 0) {
            ErrorMessage "Failed to recreate virtual environment."
            exit 0
        }
    } else {
        InfoMessage "Virtual environment already exists at $VENV_DIR"
    }
}

# 4. Install required Python packages
$PIP = Join-Path -Path $VENV_DIR -ChildPath "Scripts\pip.exe"
InfoMessage "Upgrading pip..."
& $PIP install --upgrade pip 2>&1 | Out-Null

InfoMessage "Installing Docker Python library..."
& $PIP install --upgrade "docker>=7.0.0" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    ErrorMessage "Failed to install Docker Python library."
    exit 0
}

# 5. Ensure DockerListener exists
if (-not (Test-Path $DOCKER_WODLE_DIR)) {
    InfoMessage "Creating Docker wodle directory at $DOCKER_WODLE_DIR"
    New-Item -ItemType Directory -Path $DOCKER_WODLE_DIR -Force | Out-Null
}

$customScriptSource = "$RepoUrl/files/wodles/docker/DockerListener.py"
InfoMessage "Installing custom Windows DockerListener from $customScriptSource"
try {
    Invoke-WebRequest -Uri $customScriptSource -OutFile $DOCKER_LISTENER -ErrorAction Stop
} catch {
    ErrorMessage "Failed to install custom DockerListener: $($_.Exception.Message)"
    exit 0
}

# 6. Configure Wazuh Agent to monitor the Docker events log
$dockerLogPath = "C:\Program Files (x86)\ossec-agent\logs\docker_events.log"
if (Test-Path $OSSEC_CONF_PATH) {
    [xml]$xml = Get-Content $OSSEC_CONF_PATH
    $alreadyConfigured = $xml.ossec_config.localfile | Where-Object { $_.location -eq $dockerLogPath }
    
    if (-not $alreadyConfigured) {
        InfoMessage "Adding Docker log monitoring to ossec.conf..."
        $newLocalFile = $xml.CreateElement("localfile", "http://www.ossec.net/ossec")
        $location = $xml.CreateElement("location", "http://www.ossec.net/ossec")
        $location.InnerText = $dockerLogPath
        $logFormat = $xml.CreateElement("log_format", "http://www.ossec.net/ossec")
        $logFormat.InnerText = "syslog"
        $label = $xml.CreateElement("label", "http://www.ossec.net/ossec")
        $label.SetAttribute("key", "source")
        $label.InnerText = "docker"
        
        $newLocalFile.AppendChild($location) | Out-Null
        $newLocalFile.AppendChild($logFormat) | Out-Null
        $newLocalFile.AppendChild($label) | Out-Null
        
        $xml.ossec_config.AppendChild($newLocalFile) | Out-Null
        $xml.Save($OSSEC_CONF_PATH)
        SuccessMessage "ossec.conf updated with Docker log monitoring."
    } else {
        InfoMessage "Docker log monitoring already configured in ossec.conf."
    }
}

# 7. Create/Update Scheduled Task for background execution
$taskName = "WazuhDockerListener"
$venvPython = Join-Path -Path $VENV_DIR -ChildPath "Scripts\python.exe"

# We use a PowerShell wrapper to set the environment variable for the listener
$captureLogsVal = if ($CaptureLogs) { "True" } else { "False" }
$logStreamingStatus = if ($CaptureLogs) { "ENABLED" } else { "DISABLED" }
InfoMessage "Container log streaming will be $logStreamingStatus"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"`$env:CAPTURE_DOCKER_LOGS='$captureLogsVal'; & '$venvPython' '$DOCKER_LISTENER'`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    InfoMessage "Updating existing Scheduled Task: $taskName"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

InfoMessage "Registering Scheduled Task: $taskName (Runs as SYSTEM at startup)"
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $taskName

SuccessMessage "Wazuh Docker listener for Windows is installed and running."
exit 0
