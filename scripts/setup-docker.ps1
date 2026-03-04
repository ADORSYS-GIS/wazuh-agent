# Wazuh Docker Listener Setup (Windows)
# Prepares Python environment for DockerListener safely and idempotently.
# Does nothing if Docker is not installed.

# Dot-source shared utilities
# Robust utility sourcing
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/utils.ps1" -OutFile "utils.ps1"
. ./utils.ps1

Set-StrictMode -Version Latest

# ==============================================================================
# Configuration
# ==============================================================================
$VENV_DIR = if ($env:VENV_DIR) { $env:VENV_DIR } else { "C:\wazuh-docker-env" }
$DOCKER_LISTENER = Join-Path -Path $OSSEC_PATH -ChildPath "wodles\docker\DockerListener"

# ==============================================================================
# Main
# ==============================================================================

# 1. Exit silently if Docker is not installed
$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    exit 0
}

InfoMessage "Docker detected. Setting up Docker listener environment..."

# 2. Ensure Python3 exists
$pythonPath = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonPath) {
    $pythonPath = Get-Command python3 -ErrorAction SilentlyContinue
}

if (-not $pythonPath) {
    ErrorMessage "Python is not installed. Please install Python 3 from https://www.python.org/downloads/"
    ErrorMessage "Ensure 'Add Python to PATH' is checked during installation."
    exit 0
}

$PYTHON_BIN = $pythonPath.Source
$pythonVersion = & $PYTHON_BIN -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
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

# 5. Update DockerListener shebang if present
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
