#!/bin/bash
#
# Wazuh Active Response - USB HID Device Alert (Linux)
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
# Rule IDs: 800155, 800156
# MITRE ATT&CK: T1200 (Hardware Additions)
#

LOCAL=$(dirname $0)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
FILE_TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOGFILE="/var/ossec/logs/active-responses.log"
EVIDENCE_DIR="/var/ossec/logs/usb-evidence"
OS_TYPE="Linux"

# Parse arguments
ACTION=$1
USER=$2
SRCIP=$3
ALERTID=$4
RULEID=$5

log_message() {
    echo "$TIMESTAMP - USB-HID-DLP-$OS_TYPE - $1" >> "$LOGFILE"
}

# Function to collect HID device evidence on Linux
collect_linux_evidence() {
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

--- INPUT DEVICES ---
$(cat /proc/bus/input/devices 2>/dev/null)

--- USB DEVICES ---
$(lsusb -v 2>/dev/null | grep -A 5 -i "HID\|keyboard\|mouse" | head -100)

--- HID DEVICES ---
$(ls -la /dev/hidraw* 2>/dev/null)

--- USB DEVICE TREE ---
$(lsusb -t 2>/dev/null)

--- DMESG USB EVENTS (last 50) ---
$(dmesg | grep -i "usb\|hid\|input" | tail -50)

--- XINPUT LIST ---
$(xinput list 2>/dev/null || echo "X not available")
EOF
}

case "$ACTION" in
    add)
        log_message "ACTION: USB HID device alert triggered (Rule: $RULEID, Alert: $ALERTID)"

        # Create evidence directory
        mkdir -p "$EVIDENCE_DIR"
        EVIDENCE_FILE="$EVIDENCE_DIR/hid_alert_$FILE_TIMESTAMP.txt"

        # Collect evidence
        collect_linux_evidence > "$EVIDENCE_FILE"

        log_message "Evidence saved to: $EVIDENCE_FILE"

        # Count HID/keyboard devices for anomaly detection
        KEYBOARD_COUNT=$(cat /proc/bus/input/devices 2>/dev/null | grep -ci "keyboard")

        log_message "DEVICE COUNT: $KEYBOARD_COUNT keyboard-type devices detected"

        # Alert if multiple keyboards detected (anomaly)
        if [ "$KEYBOARD_COUNT" -gt 2 ]; then
            log_message "ANOMALY: Multiple keyboards ($KEYBOARD_COUNT) detected - possible BadUSB attack!"

            # Send high-priority syslog
            logger -t "Wazuh-DLP" -p auth.alert "CRITICAL: Multiple USB keyboards detected ($KEYBOARD_COUNT) - possible BadUSB attack. Evidence: $EVIDENCE_FILE"
        else
            # Standard syslog entry
            logger -t "Wazuh-DLP" -p auth.warning "USB HID device alert. Rule: $RULEID, Alert: $ALERTID. Evidence: $EVIDENCE_FILE"
        fi

        # Linux desktop notification (optional)
        if command -v notify-send &> /dev/null; then
            notify-send -u critical "Wazuh Security Alert" "USB HID device detected - please verify authorized" 2>/dev/null
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
