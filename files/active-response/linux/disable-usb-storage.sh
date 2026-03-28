#!/bin/bash
#
# Wazuh Active Response - Disable USB Mass Storage (Linux)
#
# Description:
#   This script disables USB mass storage devices when triggered by Wazuh
#   alert rules (800151, 800152, 800153, 800154). It can either:
#   - Unload the usb-storage kernel module (prevents new devices)
#   - Unmount and eject connected USB storage devices
#
# Usage:
#   Called automatically by Wazuh Active Response
#   Manual: ./disable-usb-storage.sh add - - <alert_id> <rule_id>
#
# Rule IDs: 800151, 800152, 800153, 800154, 800170
# MITRE ATT&CK: T1052.001 (Exfiltration Over Physical Medium)
#

LOCAL=$(dirname $0)
LOGFILE="/var/ossec/logs/active-responses.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Parse arguments
ACTION=$1
USER=$2
SRCIP=$3
ALERTID=$4
RULEID=$5

log_message() {
    echo "$TIMESTAMP - USB-DLP-Linux - $1" >> $LOGFILE
}

# Function to get list of USB storage devices
get_usb_storage_devices() {
    lsblk -o NAME,TRAN,MOUNTPOINT -n 2>/dev/null | grep "usb" | awk '{print $1}'
}

# Function to get USB mount points
get_usb_mounts() {
    mount | grep -E "/dev/sd[a-z]+[0-9]+" | grep -v "$(mount | grep -E 'sda|nvme')" | awk '{print $3}'
}

case "$ACTION" in
    add)
        log_message "ACTION: Disabling USB Mass Storage (Rule: $RULEID, Alert: $ALERTID)"

        # Method 1: Unmount any mounted USB storage
        USB_MOUNTS=$(get_usb_mounts)
        if [ -n "$USB_MOUNTS" ]; then
            for mount_point in $USB_MOUNTS; do
                log_message "Unmounting USB device at: $mount_point"
                umount "$mount_point" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "SUCCESS: Unmounted $mount_point"
                else
                    log_message "WARNING: Failed to unmount $mount_point - device may be in use"
                fi
            done
        fi

        # Method 2: Disable usb-storage kernel module (prevents new USB storage devices)
        # Check if module is loaded
        if lsmod | grep -q "usb_storage"; then
            log_message "Attempting to unload usb-storage kernel module"

            # Remove the module (may fail if devices are mounted)
            modprobe -r usb_storage 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "SUCCESS: usb-storage module unloaded"
            else
                log_message "WARNING: Could not unload usb-storage module - devices may be in use"
            fi
        fi

        # Method 3: Blacklist usb-storage module to prevent loading on next device connect
        if [ ! -f /etc/modprobe.d/wazuh-usb-block.conf ]; then
            echo "# Wazuh DLP - USB Storage blocked" > /etc/modprobe.d/wazuh-usb-block.conf
            echo "blacklist usb-storage" >> /etc/modprobe.d/wazuh-usb-block.conf
            echo "install usb-storage /bin/false" >> /etc/modprobe.d/wazuh-usb-block.conf
            log_message "SUCCESS: USB storage module blacklisted"
        fi

        # Method 4: Use udev rules to prevent USB storage (more persistent)
        UDEV_RULE="/etc/udev/rules.d/99-wazuh-usb-block.rules"
        if [ ! -f "$UDEV_RULE" ]; then
            cat > "$UDEV_RULE" << 'EOF'
# Wazuh DLP - Block USB Storage Devices
# To re-enable, remove this file and run: udevadm control --reload-rules
SUBSYSTEM=="usb", DRIVER=="usb-storage", ACTION=="add", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
SUBSYSTEM=="block", ATTRS{removable}=="1", ACTION=="add", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/device/authorized'"
EOF
            udevadm control --reload-rules
            log_message "SUCCESS: udev rules installed to block USB storage"
        fi

        # Log current USB devices for audit
        log_message "Current USB devices: $(lsusb 2>/dev/null | wc -l) devices"

        # Create syslog entry for SIEM
        logger -t "Wazuh-DLP" -p auth.warning "USB Mass Storage DISABLED by Wazuh. Rule: $RULEID, Alert: $ALERTID"

        log_message "SUCCESS: USB Mass Storage blocking enabled"
        ;;

    delete)
        log_message "ACTION: Re-enabling USB Mass Storage (Rule: $RULEID)"

        # Remove blacklist
        if [ -f /etc/modprobe.d/wazuh-usb-block.conf ]; then
            rm -f /etc/modprobe.d/wazuh-usb-block.conf
            log_message "Removed usb-storage blacklist"
        fi

        # Remove udev rules
        if [ -f /etc/udev/rules.d/99-wazuh-usb-block.rules ]; then
            rm -f /etc/udev/rules.d/99-wazuh-usb-block.rules
            udevadm control --reload-rules
            log_message "Removed udev blocking rules"
        fi

        # Reload usb-storage module
        modprobe usb_storage 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "SUCCESS: usb-storage module reloaded"
        fi

        logger -t "Wazuh-DLP" -p auth.info "USB Mass Storage RE-ENABLED by Wazuh. Rule: $RULEID"
        log_message "SUCCESS: USB Mass Storage re-enabled"
        ;;

    *)
        log_message "ERROR: Unknown action: $ACTION"
        exit 1
        ;;
esac

exit 0
