# Architecture Decision Records (ADRs)

This directory maintains the historical record of significant architectural and engineering decisions for `wazuh-agent`.

## ADR Index

| ID | Title | Status | Date | Decision Summary |
| :--- | :--- | :---: | :---: | :--- |
| **[ADR-001](adr-001-sast-pr-enforcement.md)** | Pre-Merge Static Application Security Testing (SAST) Enforcement | Accepted ✅ | 2026-10-20 | Integrate multi-language SAST checks (ShellCheck, PSScriptAnalyzer, Bandit) via GitHub Actions and Reviewdog on PRs. |
| **[ADR-002](adr-002-sonarqube-quality-gate.md)** | SonarQube Centralized Quality Gate & Compliance Standards | Accepted ✅ | 2026-10-20 | Enforce SonarQube Quality Gate compliance on `develop` and `main` branches prior to release tagging. |

---

## Centralized Specifications
For comprehensive scanner details, rule profiles, and global SIEM security policies, refer to the master specification:
- [Wazuh SAST Integration Guide (`wazuh-playbook`)](https://github.com/ADORSYS-GIS/wazuh-playbook/blob/main/SOC-Documentation/sast-integration.md)
