# Wazuh Docker Listener Setup (Windows)
# Prepares Python environment for DockerListener safely and idempotently.
# Does nothing if Docker is not installed.

# Source shared utilities
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/utils.ps1" -OutFile "utils.ps1" -ErrorAction Stop
} catch {
    Write-Error "Failed to download utils.ps1: $($_.Exception.Message)"
    exit 1
}
. ./utils.ps1

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

# 5. Ensure DockerListener exists and is patched for Windows
if (-not (Test-Path $DOCKER_WODLE_DIR)) {
    InfoMessage "Creating Docker wodle directory at $DOCKER_WODLE_DIR"
    New-Item -ItemType Directory -Path $DOCKER_WODLE_DIR -Force | Out-Null
}

if (-not (Test-Path $DOCKER_LISTENER)) {
    $DockerListenerUrl = "https://raw.githubusercontent.com/wazuh/wazuh/main/wodles/docker-listener/DockerListener.py"
    InfoMessage "DockerListener not found. Downloading from Wazuh repository..."
    try {
        Invoke-WebRequest -Uri $DockerListenerUrl -OutFile $DOCKER_LISTENER -ErrorAction Stop
        
        # Patch: Remove the Windows-specific exit check
        InfoMessage "Patching DockerListener for Windows compatibility..."
        $scriptContent = Get-Content $DOCKER_LISTENER
        $patchedContent = @()
        $skip = $false
        foreach ($line in $scriptContent) {
            if ($line -match 'if sys\.platform == "win32":') { $skip = $true; continue }
            if ($skip -and ($line -match 'sys\.stderr\.write' -or $line -match 'sys\.exit\(1\)')) { continue }
            $skip = $false
            $patchedContent += $line
        }
        $patchedContent | Set-Content $DOCKER_LISTENER
    } catch {
        ErrorMessage "Failed to download or patch DockerListener: $($_.Exception.Message)"
        exit 0
    }
}

if (Test-Path $DOCKER_LISTENER) {
    $venvPython = Join-Path -Path $VENV_DIR -ChildPath "Scripts\python.exe"
    $expectedShebang = "#!$venvPython"
    $content = Get-Content $DOCKER_LISTENER
    $currentShebang = $content[0]

    if ($currentShebang -ne $expectedShebang) {
        $content[0] = $expectedShebang
        $content | Set-Content $DOCKER_LISTENER
        InfoMessage "DockerListener shebang updated to use venv Python."
    } else {
        InfoMessage "DockerListener shebang already correct."
    }
} else {
    InfoMessage "DockerListener not found at $DOCKER_LISTENER. Skipping shebang update."
}

SuccessMessage "Wazuh Docker listener environment is ready."
exit 0
