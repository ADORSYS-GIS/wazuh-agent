# Wazuh Server Setup Script

This folder contains the **server-side** setup script for the Wazuh deployment framework.

| Script | Description |
| ------ | ----------- |
| `setup-server.sh` | Full server setup: Wazuh agent core + optional server-side components (Suricata IDS, Yara, Trivy, cert-oauth2, NetBird) |

## What it does

`setup-server.sh` automates the setup of a Wazuh server node. It always installs the core Wazuh agent and lets you opt into additional server-side components:

- **Core (always installed):** Wazuh agent
- **Optional components** (choose with flags):
  - `-c` — cert-oauth2 client
  - `-s` — Suricata (IDS mode)
  - `-y` — Yara (server mode)
  - `-t` — Trivy (vulnerability scanner)
  - `-b` — NetBird client (VPN / mesh-network)

The script downloads and verifies every component against the repository's `checksums.sha256` before running, so integrity is checked at each step.

## Usage

### Run remotely (recommended)

You can run the script directly from GitHub without downloading it first:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | sudo bash
```

> **Note:** `sudo` is required because the script installs system packages and configures the Wazuh agent under `/var/ossec`.

### Run locally

```bash
# Clone the repository
git clone https://github.com/ADORSYS-GIS/wazuh-agent.git
cd wazuh-agent

# Make it executable (if needed)
chmod +x scripts/server/setup-server.sh

# Run it
sudo ./scripts/server/setup-server.sh
```

### Examples

Core installation only:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | sudo bash
```

With Suricata (IDS) and Trivy:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | sudo bash -s -- -s -t
```

With all optional components:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | sudo bash -s -- -c -s -y -t -b
```

With NetBird automated enrollment using a setup key:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | \
  NETBIRD_SETUP_KEY='<your-setup-key>' sudo -E bash -s -- -b
```

## Environment variables

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `WAZUH_MANAGER` | Wazuh manager hostname or IP | `wazuh.example.com` |
| `WAZUH_AGENT_VERSION` | Wazuh agent version to install | `4.14.4-1` |
| `WAZUH_AGENT_REPO_VERSION` | Repository tag for agent scripts | `1.8.1` |
| `WAZUH_AGENT_REPO_REF` | Full repository reference | `refs/tags/v${WAZUH_AGENT_REPO_VERSION}` |
| `WOPS_VERSION` | cert-oauth2 client version | `0.4.3` |
| `WAZUH_CERT_OAUTH2_REPO_REF` | cert-oauth2 repository reference | `refs/tags/v${WOPS_VERSION}` |
| `WAZUH_SURICATA_VERSION` | Suricata version | `0.1.5` |
| `WAZUH_SURICATA_REPO_REF` | Suricata repository reference | `refs/tags/v${WAZUH_SURICATA_VERSION}` |
| `WAZUH_YARA_VERSION` | Yara version | `0.3.14` |
| `WAZUH_YARA_REPO_REF` | Yara repository reference | `refs/tags/v${WAZUH_YARA_VERSION}` |
| `WAZUH_TRIVY_REPO_REF` | Trivy repository reference | `main` |
| `INSTALL_CERT_OAUTH2` | Install cert-oauth2 (`TRUE`/`FALSE`) | `FALSE` |
| `INSTALL_SURICATA` | Install Suricata (`TRUE`/`FALSE`) | `FALSE` |
| `INSTALL_YARA` | Install Yara (`TRUE`/`FALSE`) | `FALSE` |
| `INSTALL_TRIVY` | Install Trivy (`TRUE`/`FALSE`) | `FALSE` |
| `INSTALL_NETBIRD` | Install NetBird (`TRUE`/`FALSE`) | `FALSE` |
| `NETBIRD_SETUP_KEY` | NetBird setup key for automated enrollment | *(empty)* |

You can pass either a tag (e.g. `1.8.1`) or a full repo ref (e.g. `refs/tags/v1.8.1` or `refs/heads/main`).

### Passing environment variables remotely

Environment variables are passed **before** the `sudo -E bash` part of the command so they reach the script:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | \
  WAZUH_MANAGER='wazuh.company.com' WAZUH_AGENT_VERSION='4.14.4-1' sudo -E bash
```

## Help

Show the full usage and options:

```bash
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/main/scripts/server/setup-server.sh | sudo bash -s -- -h
```
