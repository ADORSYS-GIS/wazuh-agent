#!/bin/bash
#
# Wazuh Active Response - USB HID Device Alert (macOS)
#
# Description:
#   This script logs and alerts on USB HID device connections that may indicate
#   BadUSB or Rubber Ducky attacks. It collects device information for forensic
#   analysis without disabling the device (which would disable legitimate keyboards).
#
# Usage:
#   Called automatically by Wazuh Active Response
#   Manual: ./alert-usb-hid.sh add - - <alert_id> <rule_id>
#
# Rule IDs: 800165, 800166
# MITRE ATT&CK: T1200 (Hardware Additions)
#

LOCAL=$(dirname $0)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
FILE_TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOGFILE="/Library/Ossec/logs/active-responses.log"
EVIDENCE_DIR="/Library/Ossec/logs/usb-evidence"
OS_TYPE="macOS"

# Parse arguments
ACTION=$1
USER=$2
SRCIP=$3
ALERTID=$4
RULEID=$5

log_message() {
    echo "$TIMESTAMP - USB-HID-DLP-$OS_TYPE - $1" >> "$LOGFILE"
}

# Function to collect HID device evidence on macOS
collect_macos_evidence() {
    cat << EOF
===========================================
USB HID DEVICE ALERT - FORENSIC EVIDENCE
===========================================
Timestamp: $TIMESTAMP
Alert ID: $ALERTID
Rule ID: $RULEID
Computer: $(hostname)
User: $(whoami)
OS: $OS_TYPE

--- USB DEVICES ---
$(system_profiler SPUSBDataType 2>/dev/null)

--- HID DEVICES ---
$(ioreg -p IOUSB -l 2>/dev/null | grep -A 10 "HID\|Keyboard")

--- INPUT DEVICES ---
$(hidutil list 2>/dev/null | head -50)

--- SYSTEM LOG HID EVENTS ---
$(log show --predicate 'eventMessage contains "HID" or eventMessage contains "keyboard"' --last 30m 2>/dev/null | head -50)
EOF
}

case "$ACTION" in
    add)
        log_message "ACTION: USB HID device alert triggered (Rule: $RULEID, Alert: $ALERTID)"

        # Create evidence directory
        mkdir -p "$EVIDENCE_DIR"
        EVIDENCE_FILE="$EVIDENCE_DIR/hid_alert_$FILE_TIMESTAMP.txt"

        # Collect evidence
        collect_macos_evidence > "$EVIDENCE_FILE"

        log_message "Evidence saved to: $EVIDENCE_FILE"

        # Count HID/keyboard devices for anomaly detection
        KEYBOARD_COUNT=$(system_profiler SPUSBDataType 2>/dev/null | grep -ci "keyboard")

        log_message "DEVICE COUNT: $KEYBOARD_COUNT keyboard-type devices detected"

        # Alert if multiple keyboards detected (anomaly)
        if [ "$KEYBOARD_COUNT" -gt 2 ]; then
            log_message "ANOMALY: Multiple keyboards ($KEYBOARD_COUNT) detected - possible BadUSB attack!"

            # Send high-priority syslog
            /usr/bin/logger -t "Wazuh-DLP" -p local0.alert "CRITICAL: Multiple USB keyboards detected ($KEYBOARD_COUNT) - possible BadUSB attack. Evidence: $EVIDENCE_FILE"
        else
            # Standard syslog entry
            /usr/bin/logger -t "Wazuh-DLP" "USB HID device alert. Rule: $RULEID, Alert: $ALERTID. Evidence: $EVIDENCE_FILE"
        fi

        # macOS notification (optional)
        if command -v osascript &> /dev/null; then
            osascript -e 'display notification "USB HID device detected - please verify authorized" with title "Wazuh Security Alert" subtitle "USB HID Detection"' 2>/dev/null
        fi

        log_message "SUCCESS: USB HID alert processed and evidence collected"
        ;;

    delete)
        log_message "ACTION: USB HID alert cleared (Rule: $RULEID)"
        ;;

    *)
        log_message "ERROR: Unknown action: $ACTION"
        exit 1
        ;;
esac

exit 0
