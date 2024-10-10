# Set strict mode for script execution
Set-StrictMode -Version Latest

# Define default values for variables
[string]$WAZUH_AGENT_VERSION = "4.8.1-1"  # Updated version
[string]$WAZUH_MANAGER = "master.dev.wazuh.adorsys.team"  # Default manager

# Function to log information
function Log-Info {
	param (
		[string]$Message
	)
	Write-Host "[INFO] $Message"
}

# Function to log errors
function Log-Error {
	param (
		[string]$Message
	)
	Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Import GPG Key for Wazuh repository
function Import-Keys {
	Log-Info "Importing Wazuh GPG key and setting up the repository for Windows"
	$WazuhKeyUrl = "https://packages.wazuh.com/key/GPG-KEY-WAZUH"
	$TEMP_DIR = [System.IO.Path]::GetTempPath()

	# Download the GPG key
	Invoke-WebRequest -Uri $WazuhKeyUrl -OutFile "$TEMP_DIR\WazuhGPGKey.asc"
	Log-Info "Wazuh GPG key downloaded successfully."
}

# Install Wazuh agent on Windows
function Install-WazuhAgent {
	Log-Info "Installing Wazuh agent version $WAZUH_AGENT_VERSION on Windows"
	$TEMP_DIR = [System.IO.Path]::GetTempPath()

	# Download the Wazuh Agent installer
	$Arch = if ([System.Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
	$InstallerUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"
	$InstallerPath = "$TEMP_DIR\wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi"

	Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath
	if ($?) {
		Log-Info "Wazuh agent installer downloaded to $InstallerPath"
	} else {
		Log-Error "Failed to download Wazuh agent installer from $InstallerUrl"
		exit 1
	}

	# Install the Wazuh Agent MSI package
	Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" /quiet /norestart" -Wait
	if ($?) {
		Log-Info "Wazuh agent installed successfully."
	} else {
		Log-Error "Failed to install Wazuh agent."
		exit 1
	}
}

# Configure Wazuh agent to connect to the manager
function Configure-WazuhAgent {
	Log-Info "Configuring Wazuh agent to connect to manager $WAZUH_MANAGER"
	$ConfigFilePath = "C:\Program Files (x86)\ossec-agent\ossec.conf"

	if (Test-Path $ConfigFilePath) {
		[xml]$Config = Get-Content $ConfigFilePath
		$ManagerNode = $Config.ossec_config.client.server

		if ($ManagerNode) {
			$ManagerNode.address = $WAZUH_MANAGER
			$Config.Save($ConfigFilePath)
			Log-Info "Wazuh agent configuration updated successfully."
		} else {
			Log-Error "Failed to find the server node in the configuration file."
			exit 1
		}
	} else {
		Log-Error "Configuration file not found at $ConfigFilePath"
		exit 1
	}
}

# Start Wazuh agent service
function Start-WazuhAgentService {
	Log-Info "Starting Wazuh agent service"
	$ServiceName = "WazuhSvc"

	if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
		Start-Service -Name $ServiceName
		if ($?) {
			Log-Info "Wazuh agent service started successfully."
		} else {
			Log-Error "Failed to start Wazuh agent service."
			exit 1
		}
	} else {
		Log-Error "Wazuh agent service does not exist."
		exit 1
	}
}

# Clean up temporary files
function Clean-Up {
	Log-Info "Cleaning up temporary files."
	$TEMP_DIR = [System.IO.Path]::GetTempPath()
	Remove-Item -Path "$TEMP_DIR\WazuhGPGKey.asc" -Force -ErrorAction SilentlyContinue
	Remove-Item -Path "$TEMP_DIR\wazuh-agent-$WAZUH_AGENT_VERSION.$Arch.msi" -Force -ErrorAction SilentlyContinue
	Log-Info "Temporary files cleaned up."
}

# Call the functions
Import-Keys
Install-WazuhAgent
Configure-WazuhAgent
Start-WazuhAgentService
Clean-Up

