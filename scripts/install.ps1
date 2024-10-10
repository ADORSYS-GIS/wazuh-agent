# Function to install Wazuh Agent
function Install-Agent {

    # Global variables
    $YARA_SH_PATH = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara.bat"
    $OSSEC_CONF_PATH = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    # Function to install Wazuh agent
    function Install-WazuhAgent {
        # Variables
        $WAZUH_MANAGER = "master.wazuh.adorsys.team"
        $WAZUH_AGENT_VERSION = "4.8.1-1"
        $WAZUH_AGENT_MSI = "wazuh-agent-${WAZUH_AGENT_VERSION}.msi"
        $TEMP_DIR = $env:TEMP

        # Get the agent name from environment variable
        $WAZUH_AGENT_NAME = $env:WAZUH_AGENT_NAME
        if (-not $WAZUH_AGENT_NAME) {
            Write-Error "WAZUH_AGENT_NAME environment variable is not set."
            exit 1
        }

        # Determine package URL based on architecture
        $ARCH = [System.Environment]::Is64BitOperatingSystem

        if ($ARCH) {
            $PACKAGE_URL = "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_AGENT_VERSION}-1.msi"
        } else {
            Write-Output "Unsupported architecture"
            exit 1
        }

        # Download the package
        Write-Output "Downloading Wazuh agent..."
        try {
            Invoke-WebRequest -Uri $PACKAGE_URL -OutFile ${env.tmp}\wazuh-agent
        } catch {
            Write-Error "Failed to download Wazuh agent: $_"
            exit 1
        }

        # Define the path to the MSI file
        $msiPath = "${env.tmp}\wazuh-agent"
        $MSIArguments = @(
            "/i"
            "${env.tmp}\wazuh-agent"
            "/q"
            "WAZUH_MANAGER=${WAZUH_MANAGER}"
            "WAZUH_AGENT_NAME=${WAZUH_AGENT_NAME}"
        )

        # Install the package
        Write-Output "Installing Wazuh agent..."
        try {
            Start-Process msiexec.exe -ArgumentList $MSIArguments -Wait
        } catch {
            Write-Error "Failed to install Wazuh agent: $_"
            exit 1
        }

        # Clean up
        Write-Output "Cleaning up..."
        try {
            Remove-Item -Path ${env.tmp}\wazuh-agent -ErrorAction Stop
        } catch {
            Write-Warning "Failed to clean up the downloaded MSI file: $_"
        }
        Write-Output "Wazuh agent installed successfully!"
    }
}
