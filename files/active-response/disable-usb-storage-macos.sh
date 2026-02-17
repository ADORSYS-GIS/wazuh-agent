#!/bin/bash
#
# Wazuh Active Response - Disable USB Mass Storage (macOS)
#
# Description:
#   This script disables USB mass storage devices on macOS when triggered by
#   Wazuh alert rules. It uses diskutil to unmount and eject USB devices.
#
# Note: macOS doesn't support kernel module unloading like Linux.
#   This script focuses on ejecting connected devices and logging.
#   For full USB blocking on macOS, MDM solutions are recommended.
#
# Usage:
#   Called automatically by Wazuh Active Response
#   Manual: ./disable-usb-storage-macos.sh add - - <alert_id> <rule_id>
#
# Rule IDs: 800161, 800162, 800163, 800170
# MITRE ATT&CK: T1052.001 (Exfiltration Over Physical Medium)
#

LOCAL=$(dirname $0)
LOGFILE="/Library/Ossec/logs/active-responses.log"
EVIDENCE_DIR="/Library/Ossec/logs/usb-evidence"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
FILE_TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

# Parse arguments
ACTION=$1
USER=$2
SRCIP=$3
ALERTID=$4
RULEID=$5

log_message() {
    echo "$TIMESTAMP - USB-DLP-macOS - $1" >> "$LOGFILE"
}

# Function to get external USB disks
get_external_disks() {
    diskutil list external 2>/dev/null | grep -E "^/dev/disk" | awk '{print $1}'
}

# Function to collect evidence
collect_evidence() {
    mkdir -p "$EVIDENCE_DIR"
    EVIDENCE_FILE="$EVIDENCE_DIR/usb_alert_$FILE_TIMESTAMP.txt"

    cat > "$EVIDENCE_FILE" << EOF
===========================================
USB STORAGE ALERT - FORENSIC EVIDENCE
===========================================
Timestamp: $TIMESTAMP
Alert ID: $ALERTID
Rule ID: $RULEID
Computer: $(hostname)
User: $(whoami)

--- EXTERNAL DISKS ---
$(diskutil list external 2>/dev/null)

--- USB DEVICES ---
$(system_profiler SPUSBDataType 2>/dev/null)

--- MOUNTED VOLUMES ---
$(mount | grep -v "^/dev/disk0\|^/dev/disk1")

--- DISK ARBITRATION HISTORY ---
$(log show --predicate 'subsystem == "com.apple.diskarbitrationd"' --last 1h 2>/dev/null | head -50)
EOF

    log_message "Evidence saved to: $EVIDENCE_FILE"
    echo "$EVIDENCE_FILE"
}

case "$ACTION" in
    add)
        log_message "ACTION: Processing USB Mass Storage alert (Rule: $RULEID, Alert: $ALERTID)"

        # Collect forensic evidence first
        EVIDENCE_FILE=$(collect_evidence)

        # Get list of external disks
        EXTERNAL_DISKS=$(get_external_disks)

        if [ -n "$EXTERNAL_DISKS" ]; then
            for disk in $EXTERNAL_DISKS; do
                log_message "Processing external disk: $disk"

                # Get disk info
                DISK_INFO=$(diskutil info "$disk" 2>/dev/null | grep -E "Device / Media Name|Volume Name|Removable Media")
                log_message "Disk info: $DISK_INFO"

                # Unmount all volumes on this disk
                log_message "Unmounting all volumes on $disk"
                diskutil unmountDisk "$disk" 2>/dev/null

                if [ $? -eq 0 ]; then
                    log_message "SUCCESS: Unmounted all volumes on $disk"

                    # Attempt to eject the disk
                    log_message "Ejecting $disk"
                    diskutil eject "$disk" 2>/dev/null

                    if [ $? -eq 0 ]; then
                        log_message "SUCCESS: Ejected $disk"
                    else
                        log_message "WARNING: Could not eject $disk"
                    fi
                else
                    log_message "WARNING: Could not unmount $disk - device may be in use"
                fi
            done
        else
            log_message "No external USB disks currently connected"
        fi

        # Create system log entry for audit
        /usr/bin/logger -t "Wazuh-DLP" "USB Mass Storage alert processed. Rule: $RULEID, Alert: $ALERTID. Evidence: $EVIDENCE_FILE"

        # Send notification to user (optional - requires terminal-notifier or osascript)
        if command -v osascript &> /dev/null; then
            osascript -e 'display notification "USB storage device detected and processed by security policy" with title "Wazuh Security Alert" subtitle "USB DLP"' 2>/dev/null
        fi

        log_message "SUCCESS: USB Mass Storage alert processed"
        ;;

    delete)
        log_message "ACTION: USB alert cleared (Rule: $RULEID)"
        /usr/bin/logger -t "Wazuh-DLP" "USB Mass Storage alert cleared. Rule: $RULEID"
        ;;

    *)
        log_message "ERROR: Unknown action: $ACTION"
        exit 1
        ;;
esac

exit 0
