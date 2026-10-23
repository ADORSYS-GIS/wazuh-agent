# Architecture Decision Records

Every architectural decision is recorded here as a numbered ADR: one file per
decision. The canonical writing guidance is the central ADR guide:
<https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/adr/GUIDE.md>
(read it before writing an ADR). The canonical template is:
<https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/adr/template.md>.

## Index

| ID | Title | Status | Date | Relations | Formerly |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [ADR-0001](0001-sast-pr-enforcement.md) | Pre-Merge Static Application Security Testing (SAST) Enforcement | `Accepted` | 2026-10-20 | - | - |
| [ADR-0002](0002-sonarqube-quality-gate.md) | SonarQube Centralized Quality Gate & Compliance Standards | `Accepted` | 2026-10-20 | - | - |

---

## Centralized Specifications

For comprehensive scanner details, rule profiles, and global SIEM security policies, refer to the master specifications:
- [Wazuh SAST Integration Guide (`wazuh-playbook`)](https://github.com/ADORSYS-GIS/wazuh-playbook/blob/main/SOC-Documentation/sast-integration.md)
- [SonarQube Scan Exclusions Guide (`wazuh-playbook`)](https://github.com/ADORSYS-GIS/wazuh-playbook/blob/main/SOC-Documentation/sonarqube-scan-exclusions.md)
