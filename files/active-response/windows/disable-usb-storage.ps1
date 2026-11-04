<#
.SYNOPSIS
    Wazuh Active Response - Disable USB Mass Storage

.DESCRIPTION
    This script disables USB mass storage devices when triggered by Wazuh
    alert rules (800131, 800132, 800133). It modifies registry settings
    to prevent USB storage devices from functioning.

.NOTES
    Rule IDs: 800131, 800132, 800133
    MITRE ATT&CK: T1052.001 (Exfiltration Over Physical Medium)

    To restore USB access, run: Set-ItemProperty -Path $usbStorPath -Name "Start" -Value 3
#>

# The $user and $srcip parameters are part of the Wazuh active-response
# positional argument contract (action, user, srcip, alertid, ruleid).
# They must remain so that $alertid and $ruleid bind to the correct positions.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
param (
    [string]$action,
    [string]$user,
    [string]$srcip,
    [string]$alertid,
    [string]$ruleid
)

$logFile = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-AgentLog {
    param([string]$message)
    "$timestamp - USB-DLP - $message" | Out-File -Append -FilePath $logFile
}

# Registry path for USB storage
$usbStorPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

try {
    if ($action -eq "add") {
        Write-AgentLog "ACTION: Disabling USB Mass Storage (Rule: $ruleid, Alert: $alertid)"

        # Disable USB Storage by setting Start value to 4 (Disabled)
        Set-ItemProperty -Path $usbStorPath -Name "Start" -Value 4 -ErrorAction Stop

        # Log the action
        Write-AgentLog "SUCCESS: USB Mass Storage disabled via registry"

        # Get list of current USB storage devices
        $usbDevices = Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -eq "USB" }

        foreach ($device in $usbDevices) {
            Write-AgentLog "WARNING: USB Storage device present: $($device.Model) - $($device.DeviceID)"

            # Attempt to eject the device (optional - requires additional tools)
            # Note: Full ejection requires third-party tools or device-specific commands
        }

        # Create Windows Event Log entry for audit trail
        $eventParams = @{
            LogName = 'Application'
            Source = 'Wazuh-ActiveResponse'
            EventId = 8001
            EntryType = 'Warning'
            Message = "USB Mass Storage DISABLED by Wazuh DLP. Rule: $ruleid, Alert: $alertid"
        }

        # Create event source if it doesn't exist
        if (-not [System.Diagnostics.EventLog]::SourceExists("Wazuh-ActiveResponse")) {
            New-EventLog -LogName Application -Source "Wazuh-ActiveResponse" -ErrorAction SilentlyContinue
        }
        Write-EventLog @eventParams -ErrorAction SilentlyContinue

    } elseif ($action -eq "delete") {
        Write-AgentLog "ACTION: Re-enabling USB Mass Storage (Rule: $ruleid)"

        # Re-enable USB Storage by setting Start value to 3 (Manual/Enabled)
        Set-ItemProperty -Path $usbStorPath -Name "Start" -Value 3 -ErrorAction Stop

        Write-AgentLog "SUCCESS: USB Mass Storage re-enabled via registry"

        # Create Windows Event Log entry
        $eventParams = @{
            LogName = 'Application'
            Source = 'Wazuh-ActiveResponse'
            EventId = 8002
            EntryType = 'Information'
            Message = "USB Mass Storage RE-ENABLED by Wazuh DLP. Rule: $ruleid"
        }
        Write-EventLog @eventParams -ErrorAction SilentlyContinue
    }

    exit 0

} catch {
    Write-AgentLog "ERROR: Failed to modify USB settings - $($_.Exception.Message)"
    exit 1
}
