# USB DLP Active Response Scripts

These scripts are automatically deployed to Wazuh agents by the `setup-agent.sh` (Linux/macOS) and `setup-agent.ps1` (Windows) installation scripts.

## Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `disable-usb-storage.ps1` | Windows | Blocks USB mass storage devices via registry |
| `disable-usb-storage.sh` | Linux | Blocks USB storage via kernel module and udev rules |
| `disable-usb-storage-macos.sh` | macOS | Ejects USB storage devices via diskutil |
| `alert-usb-hid.ps1` | Windows | Collects USB HID device forensic evidence |
| `alert-usb-hid.sh` | Linux/macOS | Collects USB HID device forensic evidence |
| `linux/block-c2.sh` | Linux | Drops traffic to and from the remote end of malware / C2 traffic (iptables, or nft) until the manager's timeout |

## Installation Locations

After agent setup completes, scripts are installed to:

| Platform | Directory |
|----------|-----------|
| Windows | `C:\Program Files (x86)\ossec-agent\active-response\bin\` |
| Linux | `/var/ossec/active-response/bin/` |
| macOS | `/Library/Ossec/active-response/bin/` |

## Triggered By

These scripts are triggered by Wazuh Manager Active Response rules when USB devices are detected:

**USB Mass Storage (Data Exfiltration Prevention):**
- Windows: Rules 800131, 800132, 800133
- Linux: Rules 800151, 800152, 800153, 800154
- macOS: Rules 800161, 800162, 800163

**USB HID (BadUSB/Rubber Ducky Detection):**
- Windows: Rules 800140, 800141, 800142
- Linux: Rules 800155, 800156
- macOS: Rules 800165, 800166

## MITRE ATT&CK Coverage

- **T1052.001**: Exfiltration Over Physical Medium (USB)
- **T1200**: Hardware Additions (BadUSB/Rubber Ducky)

## Manager Configuration Required

The Wazuh Manager must have the corresponding Active Response commands and rule bindings configured. See the Wazuh Helm chart `template.config.conf.xml` for the required configuration.

## Manual Verification

After installation, verify scripts are in place:

**Linux:**
```bash
ls -la /var/ossec/active-response/bin/disable-usb-storage.sh
ls -la /var/ossec/active-response/bin/alert-usb-hid.sh
```

**macOS:**
```bash
ls -la /Library/Ossec/active-response/bin/disable-usb-storage-macos.sh
ls -la /Library/Ossec/active-response/bin/alert-usb-hid.sh
```

**Windows:**
```powershell
Test-Path "C:\Program Files (x86)\ossec-agent\active-response\bin\disable-usb-storage.ps1"
Test-Path "C:\Program Files (x86)\ossec-agent\active-response\bin\alert-usb-hid.ps1"
```

## Network containment (block-c2)

`linux/block-c2.sh` runs on Suricata rule 100013 (malware or command-and-control traffic). Suricata alerts carry
`data.src_ip` / `data.dest_ip`, which the stock `firewall-drop` does not read, so this script picks the public end of
the flow itself. It never blocks private, CGNAT/NetBird (100.64.0.0/10), loopback, link-local or multicast addresses,
the default gateway, or the DNS servers in `/etc/resolv.conf`. It uses the Wazuh 4.2+ JSON protocol (stdin,
`check_keys`), and the manager removes the block when its timeout expires. Activity is logged to
`/var/ossec/logs/active-responses.log`. Tests: `scripts/tests/test-block-c2.bats`.
