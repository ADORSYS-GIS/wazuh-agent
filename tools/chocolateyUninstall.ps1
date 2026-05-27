$ErrorActionPreference = 'Stop'

# Chocolatey uninstall script for wazuh-agent-bundle
# This script runs when the package is uninstalled

$OSSEC_PATH = "C:\Program Files (x86)\ossec-agent"
$AR_BIN_DIR = Join-Path -Path $OSSEC_PATH -ChildPath "active-response\bin"

Write-Host "Running uninstallation tasks for wazuh-agent-bundle..."

# Remove USB DLP Active Response scripts
$usbStorageScript = Join-Path -Path $AR_BIN_DIR -ChildPath "disable-usb-storage.ps1"
if (Test-Path -Path $usbStorageScript) {
    Write-Host "Removing disable-usb-storage.ps1..."
    Remove-Item -Path $usbStorageScript -Force
}

$usbHidScript = Join-Path -Path $AR_BIN_DIR -ChildPath "alert-usb-hid.ps1"
if (Test-Path -Path $usbHidScript) {
    Write-Host "Removing alert-usb-hid.ps1..."
    Remove-Item -Path $usbHidScript -Force
}

# Remove version file
$VERSION_FILE_PATH = Join-Path -Path $OSSEC_PATH -ChildPath "version.txt"
if (Test-Path -Path $VERSION_FILE_PATH) {
    Write-Host "Removing version file..."
    Remove-Item -Path $VERSION_FILE_PATH -Force
}

Write-Host "Uninstallation completed successfully"
