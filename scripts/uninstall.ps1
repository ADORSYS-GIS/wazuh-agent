# Source shared utilities
if (-not $env:WAZUH_AGENT_REPO_REF) { $env:WAZUH_AGENT_REPO_REF = "main" }
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/$($env:WAZUH_AGENT_REPO_REF)/scripts/utils.ps1" -OutFile "utils.ps1" -ErrorAction Stop
} catch {
    Write-Error "Failed to download utils.ps1: $($_.Exception.Message)"
    exit 1
}
. ./utils.ps1

$AgentVersion = "4.14.2-1"
$OssecPath = "C:\Program Files (x86)\ossec-agent"
$DownloadUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$AgentVersion.msi"
$TempFile = New-TemporaryFile

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


    InfoMessage "Removing msi executable $AgentVersion..."
    try {
        Remove-Item -Path $TempFile -Recurse -Force
        InfoMessage "Msi Executable $AgentVersion Removed"
    }
    catch {
        ErrorMessage "Failed to remove msi executable $AgentVersion : $($_.Exception.Message)"
    }
}

function Remove-WazuhService {
    InfoMessage "Stopping Wazuh service if running"
    $service = Get-Service -Name WazuhSvc -ErrorAction SilentlyContinue

    if ($service) {
        if ($service.Status -eq 'Running') {
            InfoMessage "Wazuh Service is Running. Stopping Service..."
            try {
                Stop-Service -Name WazuhSvc -ErrorAction Stop
                InfoMessage "Wazuh Service stopped successfully"
            }
            catch {
                ErrorMessage "Failed to Stop Wazuh Service: $($_.Exception.Message)"
            }
        } else {
            InfoMessage "Wazuh Service is already stopped"
        }

        # Removing the Wazuh service
        InfoMessage "Removing Wazuh service..."
        try {
            # Uninstall service using sc.exe or Remove-Service
            sc.exe delete WazuhSvc
            InfoMessage "Wazuh Service removed successfully"
        }
        catch {
            ErrorMessage "Failed to remove Wazuh Service: $($_.Exception.Message)"
        }
    } else {
        WarnMessage "Wazuh Service is not installed or not found"
    }
}





function Cleanup-Files {
    InfoMessage "Cleaning up remaining Wazuh files"
    
    # 1. Cleanup Docker Monitoring Task and Environment
    $dockerTask = "WazuhDockerListener"
    if (Get-ScheduledTask -TaskName $dockerTask -ErrorAction SilentlyContinue) {
        InfoMessage "Removing Docker Listener Scheduled Task..."
        Unregister-ScheduledTask -TaskName $dockerTask -Confirm:$false
    }
    
    $venvPath = "C:\wazuh-docker-env"
    if (Test-Path $venvPath) {
        InfoMessage "Removing Docker Python virtual environment..."
        Remove-Item -Path $venvPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 2. Cleanup ossec-agent directory
    if (Test-Path -Path $OssecPath) {
        try {
            Remove-Item -Path $OssecPath -Recurse -Force
            InfoMessage "Wazuh Files removed successfully"
        }
        catch {
            ErrorMessage "Failed to Cleanup Files: $($_.Exception.Message)"
        }
    } else {
        WarnMessage "Wazuh path does not exist. No files to remove."
    }
}


Remove-WazuhService
Uninstall-Agent
Cleanup-Files

SuccessMessage "Wazuh Agent uninstallation completed successfully"