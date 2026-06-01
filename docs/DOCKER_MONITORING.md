# Docker Monitoring Guide (Cross-Platform)

This document explains the technical implementation, requirements, and usage of Docker monitoring across Windows, Linux, and macOS within the ADORSYS Wazuh environment.

## 1. Unified Architecture

Wazuh monitoring for Docker is implemented using two distinct methods based on the host platform:

### 1.1 Linux & macOS (Official Wazuh Integration)

On Unix-based systems, we leverage the official Wazuh `docker-listener` module.

- **Communication**: Uses Unix Sockets (`/var/run/docker.sock`).
- **Permissions**: The `wazuh` user must be in the `docker` group to gain permission to read/write to the Docker socket.

### 1.2 Windows (Enhanced Custom Integration)

Since Wazuh lacks native Windows support, we use a custom Python listener.

- **Communication**: Uses Windows Named Pipes (`\\.\pipe\docker_engine`).
- **Permissions**: No group membership is required because the listener runs as the **`SYSTEM`** account via a Scheduled Task.
- **Bridging**: The listener writes events to a local JSON file (`docker_events.log`), which the Wazuh Agent monitors and ships to the Manager.

---

## 2. Security & Permissions Matrix

| Platform    | Running Account | Group Membership | Reason                                                       |
| :---------- | :-------------- | :--------------- | :----------------------------------------------------------- |
| **Windows** | `SYSTEM`        | **No**           | `SYSTEM` has inherent full access to the Docker Named Pipe.  |
| **Linux**   | `wazuh`         | **Yes**          | Standard security practice; required for Unix socket access. |
| **macOS**   | `wazuh`         | **Yes**          | Same architecture as Linux; required for socket access.      |

---

## 3. Installation & Usage

### 3.1 Requirements

- **Docker**: Engine must be running with accessible sockets/pipes.
- **Python 3 (Windows)**: Required for the custom listener script.

### 3.2 Deployment

#### Linux / macOS

```bash
export WAZUH_MANAGER="your-manager-ip"
export WAZUH_AGENT_REPO_REF="main"
curl -fsSL "https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/${WAZUH_AGENT_REPO_REF}/install.sh" | bash
```

#### Windows (PowerShell)

```powershell
$env:WAZUH_MANAGER = "your-manager-ip"
$env:WAZUH_AGENT_REPO_REF = "main"

# Optional: -CaptureDockerLogs enables real-time container log streaming
.\setup-agent.ps1 -CaptureDockerLogs
```

---

## 4. Verification & Troubleshooting

### 4.1 Monitoring Data Types

The integration produces two types of records:

1.  **Events (`data.type: event`)**: Lifecycle changes (start, stop, create, exec).
2.  **Logs (`data.type: log`)**: Actual `stdout`/`stderr` captured from inside the container (if Log Streaming is enabled).

### 4.2 Log Locations

- **Windows Listener Output**: `C:\Program Files (x86)\ossec-agent\logs\docker_events.log`
- **Agent Logs**:
  - Linux: `/var/ossec/logs/ossec.log`
  - macOS: `/Library/Ossec/logs/ossec.log`
  - Windows: `C:\Program Files (x86)\ossec-agent\ossec.log`

---

## 5. Summary of Implementation

By unifying the configuration scripts, we ensure that every agent—regardless of OS—provides a standard stream of Docker security events to the Wazuh Manager, allowing for centralized alerting and compliance monitoring.
