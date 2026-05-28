$ErrorActionPreference = 'Stop'

# Chocolatey install script for wazuh-agent-bundle
# This script runs after the package dependencies are installed

$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent"
$AR_BIN_DIR = Join-Path -Path $OSSEC_PATH -ChildPath "active-response\bin"

Write-Host "Running post-installation tasks for wazuh-agent-bundle..."

# Create active-response bin directory if it doesn't exist
if (-not (Test-Path -Path $AR_BIN_DIR)) {
    Write-Host "Creating directory: $AR_BIN_DIR"
    New-Item -ItemType Directory -Path $AR_BIN_DIR -Force | Out-Null
}

# Copy USB DLP Active Response scripts (bundled in the package)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Copy disable-usb-storage.ps1
$usbStorageScript = Join-Path -Path $scriptDir -ChildPath "files\disable-usb-storage.ps1"
if (Test-Path -Path $usbStorageScript) {
    Write-Host "Installing disable-usb-storage.ps1..."
    Copy-Item -Path $usbStorageScript -Destination $AR_BIN_DIR -Force
} else {
    Write-Warning "disable-usb-storage.ps1 not found in package"
}

# Copy alert-usb-hid.ps1
$usbHidScript = Join-Path -Path $scriptDir -ChildPath "files\alert-usb-hid.ps1"
if (Test-Path -Path $usbHidScript) {
    Write-Host "Installing alert-usb-hid.ps1..."
    Copy-Item -Path $usbHidScript -Destination $AR_BIN_DIR -Force
} else {
    Write-Warning "alert-usb-hid.ps1 not found in package"
}

# Write version file
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
if ($env:ChocolateyPackageVersion) {
    Write-Host "Writing version file: $env:ChocolateyPackageVersion"
    Set-Content -Path $VERSION_FILE_PATH -Value $env:ChocolateyPackageVersion
} else {
    Write-Warning "ChocolateyPackageVersion not set, skipping version file"
}

Write-Host "Post-installation completed successfully"
