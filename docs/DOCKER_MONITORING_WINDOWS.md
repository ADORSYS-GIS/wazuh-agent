# Wazuh Docker Monitoring for Windows

This document explains the technical challenges, our custom implementation, and the usage of Docker monitoring on Windows within the ADORSYS Wazuh Agent environment.

## The Challenge

Wazuh officially supports Docker monitoring via the `docker-listener` wodle on Linux and macOS. However, Windows support is missing from the official agent for several technical reasons:

1.  **Platform Check**: The official Wazuh `DockerListener.py` contains a hardcoded check that explicitly prevents it from running on Windows (`sys.platform == "win32"`).
2.  **Communication Mismatch**:
    - **Linux**: Uses Unix Sockets (`/var/run/docker.sock`) to talk to Docker.
    - **Windows**: Uses Named Pipes (`\\.\pipe\docker_engine`).
3.  **Wazuh Queue Lack**: The official listener attempts to send events to a Unix Domain Socket at `/var/ossec/queue/sockets/queue`, which is not available on Windows.

## Our Custom Solution

To provide professional Docker monitoring for Windows, we have implemented a native, multi-threaded **Windows Docker Listener**.

### Key Features

- **Named Pipe Connectivity**: Uses the `docker-py` library to communicate natively with the Windows Docker Engine via Named Pipes.
- **Dual-Mode Capture**:
- **Events**: Captures all container lifecycle events (start, stop, exec, etc.).
  - **Logs (Optional)**: Real-time `stdout`/`stderr` streaming from all containers.
- **Rule Compatibility**: Automatically maps modern Docker fields (like `Action`) to legacy fields (like `status`) to ensure all built-in Wazuh rules trigger correctly.
- **Wazuh Integration**: Writes events to a local JSON log file which the Wazuh Agent monitors as a "bridge" to the manager.
- **Process Persistence**: Automatically managed as a **Windows Scheduled Task** (`WazuhDockerListener`) running as `SYSTEM`.

## Installation & Usage

### 1. Requirements

- Python 3 installed on the Windows host.
- Docker Desktop or Docker Engine running with the Windows Named Pipe enabled (default).
- **Note**: Unlike Linux/macOS, you do **not** need to add the agent or user to a "docker" group. The listener runs as a Scheduled Task under the `SYSTEM` account, which has native, unrestricted access to the Docker Named Pipe (`\\.\pipe\docker_engine`).
### 2. Standard Installation

By default, the installer only captures **Events** (to minimize noise):

```powershell
.\setup-agent.ps1
```

### 3. Enhanced Installation (with Logs)

To enable real-time **Container Log Streaming**, use the `-CaptureDockerLogs` flag:

```powershell
.\setup-agent.ps1 -CaptureDockerLogs
```

### 4. Verification

You can verify the listener is running by checking its operational log:

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\logs\docker_listener.log"
```

The captured Docker data can be found here:

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\logs\docker_events.log"
```

## Management & Troubleshooting

- **Service Management**: Use Task Scheduler to start/stop the `WazuhDockerListener` task.
- **Agent Configuration**: The installer adds this block to `ossec.conf` to bridge the logs:
  ```xml
  <localfile>
    <location>C:\Program Files (x86)\ossec-agent\logs\docker_events.log</location>
    <log_format>syslog</log_format>
    <label key="source">docker</label>
  </localfile>
  ```
- **Cleanup**: Running `uninstall.ps1` fully removes the listener, task, and virtual environment.
