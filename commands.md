
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/refs/heads/main/scripts/install.ps1' -OutFile 'install.ps1'


Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/refs/heads/3-Windows-Agent-Install-Script/scripts/install.ps1' -OutFile 'install-yara.ps1'

Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent-status/refs/heads/chore/issue-6/scripts/install.ps1' -OutFile 'install.ps1'

