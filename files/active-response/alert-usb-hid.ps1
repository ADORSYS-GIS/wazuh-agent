<#
.SYNOPSIS
    Wazuh Active Response - USB HID Device Alert and Logging

.DESCRIPTION
    This script logs and alerts on USB HID device connections (potential BadUSB/Rubber Ducky).
    It collects detailed device information for forensic analysis and creates
    audit trail entries. Does NOT disable the device (would disable legitimate keyboards).

.NOTES
    Rule IDs: 800140, 800141, 800142
    MITRE ATT&CK: T1200 (Hardware Additions)

    This script focuses on detection and logging rather than prevention,
    as blocking HID devices would disable legitimate keyboards and mice.
#>

param (
    [string]$action,
    [string]$user,
    [string]$srcip,
    [string]$alertid,
    [string]$ruleid
)

$logFile = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"
$evidenceDir = "C:\Program Files (x86)\ossec-agent\active-response\usb-evidence"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

function Write-Log {
    param([string]$message)
    "$timestamp - USB-HID-DLP - $message" | Out-File -Append -FilePath $logFile
}

try {
    if ($action -eq "add") {
        Write-Log "ACTION: USB HID device alert triggered (Rule: $ruleid, Alert: $alertid)"

        # Create evidence directory if it doesn't exist
        if (-not (Test-Path $evidenceDir)) {
            New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
        }

        # Collect USB HID device information
        $hidDevices = Get-WmiObject Win32_PnPEntity | Where-Object {
            $_.DeviceID -match "HID" -or $_.DeviceID -match "USB\\VID"
        }

        # Collect keyboard devices specifically
        $keyboards = Get-WmiObject Win32_Keyboard

        # Save evidence to file
        $evidenceFile = "$evidenceDir\hid_alert_$fileTimestamp.txt"
        $evidenceContent = @"
===========================================
USB HID DEVICE ALERT - FORENSIC EVIDENCE
===========================================
Timestamp: $timestamp
Alert ID: $alertid
Rule ID: $ruleid
Computer: $env:COMPUTERNAME
User: $env:USERNAME

--- ALL HID DEVICES ---
$($hidDevices | Format-List DeviceID, Name, Description, Manufacturer, Status | Out-String)

--- KEYBOARD DEVICES ---
$($keyboards | Format-List DeviceID, Name, Description, Layout | Out-String)

--- USB DEVICE HISTORY (Registry) ---
"@

        # Get USB device history from registry
        $usbHistory = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\*" -ErrorAction SilentlyContinue |
            Select-Object PSChildName, DeviceDesc, Mfg, Service

        $evidenceContent += $usbHistory | Format-Table -AutoSize | Out-String

        $evidenceContent | Out-File -FilePath $evidenceFile -Encoding UTF8
        Write-Log "Evidence saved to: $evidenceFile"

        # Count HID devices for anomaly detection
        $hidCount = ($hidDevices | Measure-Object).Count
        $keyboardCount = ($keyboards | Measure-Object).Count

        Write-Log "DEVICE COUNT: $hidCount HID devices, $keyboardCount keyboards detected"

        # Alert on anomaly (more than expected keyboards)
        if ($keyboardCount -gt 2) {
            Write-Log "ANOMALY: Multiple keyboards ($keyboardCount) detected - possible BadUSB attack"
        }

        # Create Windows Event Log entry for SIEM/audit
        $eventMessage = @"
USB HID DEVICE SECURITY ALERT

A USB HID device connection was detected that may indicate a BadUSB or Rubber Ducky attack.

Alert Details:
- Rule ID: $ruleid
- Alert ID: $alertid
- Timestamp: $timestamp
- HID Devices: $hidCount
- Keyboards: $keyboardCount

RECOMMENDED ACTIONS:
1. Verify the USB device is authorized
2. Check for unexpected keyboard devices
3. Review the evidence file: $evidenceFile
4. If unauthorized, physically remove the device

Evidence has been collected for forensic analysis.
"@

        # Create event source if it doesn't exist
        if (-not [System.Diagnostics.EventLog]::SourceExists("Wazuh-ActiveResponse")) {
            New-EventLog -LogName Application -Source "Wazuh-ActiveResponse" -ErrorAction SilentlyContinue
        }

        $eventParams = @{
            LogName = 'Application'
            Source = 'Wazuh-ActiveResponse'
            EventId = 8003
            EntryType = 'Warning'
            Message = $eventMessage
        }
        Write-EventLog @eventParams -ErrorAction SilentlyContinue

        Write-Log "SUCCESS: USB HID alert processed and evidence collected"

    } elseif ($action -eq "delete") {
        Write-Log "ACTION: USB HID alert cleared (Rule: $ruleid)"
    }

    exit 0

} catch {
    Write-Log "ERROR: Failed to process USB HID alert - $($_.Exception.Message)"
    exit 1
}
