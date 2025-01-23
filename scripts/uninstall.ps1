$AgentVersion = "4.9.2-1"
$OssecPath = "C:\Program Files (x86)\ossec-agent"
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$AgentVersion.msi"
$TempFile = New-TemporaryFile


function Log {
    param (
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"  # Default color
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Timestamp $Level $Message" -ForegroundColor $Color
}

# Logging helpers with colors
function InfoMessage {
    param ([string]$Message)
    Log "[INFO]" $Message "White"
}

function WarnMessage {
    param ([string]$Message)
    Log "[WARNING]" $Message "Yellow"
}

function ErrorMessage {
    param ([string]$Message)
    Log "[ERROR]" $Message "Red"
}

function SuccessMessage {
    param ([string]$Message)
    Log "[SUCCESS]" $Message "Green"
}

function PrintStep {
    param (
        [int]$StepNumber,
        [string]$Message
    )
    Log "[STEP]" "Step ${StepNumber}: $Message" "White"
}

# Exit script with an error message
function ErrorExit {
    param ([string]$Message)
    ErrorMessage $Message
    exit 1
}


function Uninstall-Agent {



    # Download the Wazuh agent MSI package
    InfoMessage "Downloading Wazuh agent version $AgentVersion..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -ErrorAction Stop
    } catch {
        ErrorMessage "Failed to download Wazuh agent: $($_.Exception.Message)"
        return
    }

    $MsiArguments = @(
        "/x $TempFile"
        "/qn"
    )
    
    InfoMessage "Uninstalling Wazuh agent..."
    try {
        Start-Process "msiexec.exe" -ArgumentList $MsiArguments -Wait -ErrorAction Stop
    }
    catch {
        ErrorMessage "Failed to uninstall Wazuh Agent: $($_.Exception.Message)"
    }
}

function Stop-WazuhService {
    InfoMessage "Stopping Wazuh service if running"
    $service = Get-Service -Name WazuhSvc

    if ($service.Status -eq 'Running') {
        InfoMessage "Wazuh Service is Running. Stopping Service..."
        try {
            Stop-Service -Name WazuhSvc -ErrorAction Stop
            InfoMessage "Wazuh Service stopped succesfully"
        }
        catch {
            ErrorMessage "Failed to Stop Wazuh Service: $($_.Exception.Message)"
        }
    } else {
        InfoMessage "Wazuh Service is already stopped"
    }
}


function Cleanup-Files {
    InfoMessage "Cleaning up remain Wazuh files"
    try {
        Remove-Item -Path $OssecPath -Recurse -Force
        InfoMessage "Wazuh Files removed succesfully"
    }
    catch {
        ErrorMessage "Failed to Cleanup Files: $($_.Exception.Message)"
    }
    
}

Stop-WazuhService
Uninstall-Agent
Cleanup-Files

SuccessMessage "Wazuh Agent uninstallation completed successfully"