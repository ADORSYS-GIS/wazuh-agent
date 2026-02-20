# Environment Variables Reference

This document describes all environment variables used by the Wazuh Agent installation scripts.

## Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `WAZUH_MANAGER` | Hostname or IP address of the Wazuh Manager | `wazuh.company.com` |

## Core Agent Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WAZUH_MANAGER` | `wazuh.example.com` | Wazuh Manager address (hostname or IP) |
| `WAZUH_AGENT_VERSION` | `4.13.1-1` | Wazuh Agent version to install |
| `WAZUH_AGENT_NAME` | `$(hostname)` | Agent registration name |
| `WAZUH_AGENT_GROUP` | *(none)* | Agent group for enrollment |

## Component Versions

| Variable | Default | Description |
|----------|---------|-------------|
| `WAZUH_AGENT_REPO_VERSION` | `1.7.0` | Version of this installer repository |
| `WOPS_VERSION` | `0.3.0` | Wazuh Cert OAuth2 client version |
| `WAZUH_AGENT_STATUS_VERSION` | `0.3.3` | Wazuh Agent Status tool version |
| `WAZUH_YARA_VERSION` | `0.3.11` | Wazuh Yara integration version |
| `WAZUH_SNORT_VERSION` | `0.2.4` | Wazuh Snort integration version |
| `WAZUH_SURICATA_VERSION` | `0.1.4` | Wazuh Suricata integration version |

## Application Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `wazuh-cert-oauth2-client` | OAuth2 client application name |
| `LOG_LEVEL` | `INFO` | Logging verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |

## Path Configuration

| Variable | Default (Linux) | Default (macOS) | Default (Windows) |
|----------|-----------------|-----------------|-------------------|
| `OSSEC_PATH` | `/var/ossec/etc` | `/Library/Ossec/etc` | `C:\Program Files (x86)\ossec-agent\` |
| `OSSEC_CONF_PATH` | `/var/ossec/etc/ossec.conf` | `/Library/Ossec/etc/ossec.conf` | `C:\Program Files (x86)\ossec-agent\ossec.conf` |

## User/Group Configuration (Linux/macOS)

| Variable | Default | Description |
|----------|---------|-------------|
| `USER` | `root` | User for file ownership |
| `GROUP` | `wazuh` | Group for file ownership |

## Usage Examples

### Basic Installation (Linux/macOS)

```bash
export WAZUH_MANAGER="wazuh.mycompany.com"
./scripts/setup-agent.sh
```

### Custom Version Installation

```bash
export WAZUH_MANAGER="wazuh.mycompany.com"
export WAZUH_AGENT_VERSION="4.12.0-1"
export WAZUH_YARA_VERSION="0.3.10"
./scripts/setup-agent.sh
```

### Debug Mode Installation

```bash
export WAZUH_MANAGER="wazuh.mycompany.com"
export LOG_LEVEL="DEBUG"
./scripts/setup-agent.sh
```

### Windows Installation (PowerShell)

```powershell
$env:WAZUH_MANAGER = "wazuh.mycompany.com"
$env:WAZUH_AGENT_VERSION = "4.13.1-1"
.\scripts\setup-agent.ps1 -InstallSuricata
```

### With Specific NIDS Configuration

```bash
# Install with Suricata in IPS mode
export WAZUH_MANAGER="wazuh.mycompany.com"
./scripts/setup-agent.sh -s ips

# Install with Snort
export WAZUH_MANAGER="wazuh.mycompany.com"
./scripts/setup-agent.sh -n

# Install with Trivy vulnerability scanner
export WAZUH_MANAGER="wazuh.mycompany.com"
./scripts/setup-agent.sh -s ids -t
```

## Validation Rules

### WAZUH_MANAGER

- **Required:** Yes
- **Format:** Valid hostname or IPv4 address
- **Examples:**
  - Valid: `wazuh.company.com`, `192.168.1.100`, `wazuh-manager.local`
  - Invalid: `http://wazuh.company.com`, `wazuh:1514`, `wazuh manager`

### Version Strings

- **Format:** `X.Y.Z` or `X.Y.Z-N` where X, Y, Z, N are integers
- **Examples:**
  - Valid: `4.13.1-1`, `0.3.11`, `1.0.0`
  - Invalid: `v4.13.1`, `4.13`, `latest`

### LOG_LEVEL

- **Valid values:** `DEBUG`, `INFO`, `WARNING`, `ERROR`
- **Case sensitive:** No (converted to uppercase internally)

## Security Considerations

1. **Never hardcode credentials** in environment variables for production
2. **Use secrets management** (HashiCorp Vault, AWS Secrets Manager) for sensitive values
3. **Clear sensitive variables** after installation:
   ```bash
   unset WAZUH_MANAGER
   ```

## Troubleshooting

### Variable Not Being Applied

1. Ensure export is used (bash):
   ```bash
   export WAZUH_MANAGER="value"  # Correct
   WAZUH_MANAGER="value"         # Only works in same shell
   ```

2. Check for typos in variable names

3. Verify variable is set:
   ```bash
   echo $WAZUH_MANAGER
   ```

### Invalid Manager Address Error

```
ERROR: WAZUH_MANAGER has invalid format: http://wazuh.company.com
```

**Solution:** Remove protocol prefix, use only hostname or IP:
```bash
export WAZUH_MANAGER="wazuh.company.com"  # Correct
```

### Version Format Error

```
ERROR: Invalid version format: v4.13.1
```

**Solution:** Remove 'v' prefix:
```bash
export WAZUH_AGENT_VERSION="4.13.1-1"  # Correct
```
