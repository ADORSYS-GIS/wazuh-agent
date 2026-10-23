# ADR-0002: SonarQube Centralized Quality Gate & Compliance Standards

> Enforce centralized SonarQube Quality Gate compliance on protected branches via adorsys-ci-cd-templates, because decentralized linters cannot provide continuous cross-branch trend analysis or auditable compliance reporting.

## Metadata

| Field | Value |
| :--- | :--- |
| **Document ID** | ADR-0002 |
| **Status** | `Accepted` |
| **Date** | 2026-10-20 |
| **Recorded** | 2026-10-20 |
| **Deciders** | SIEM Security Engineering Team |
| **Governs** | `.github/workflows/sonarqube.yml`, `sonar-project.properties` |
| **Amends** | N/A |
| **Amended by** | N/A |
| **Supersedes** | N/A |
| **Superseded by** | N/A |

## Context

While pre-merge SAST catches immediate syntax and language-specific security flaws, we need a unified platform to track long-term code quality, identify architectural code smells, enforce security hotspot reviews, and monitor test coverage trends across branches.

For our compliance roadmap (including ISO 27001 / TÜV Hessen certifications), auditors require demonstrable proof of centralized static analysis and quality gate enforcement across releases.

## Decision

We will integrate `wazuh-agent` into the centralized SonarQube instance (`https://sonarqube.sol-adorsys.com`) using the reusable SonarQube workflow from `ADORSYS-GIS/adorsys-ci-cd-templates`.

The enforcement mechanism operates via `.github/workflows/sonarqube.yml`:
1. **Target Branches**:
   - Analysis runs on all pushes to `develop` and `main`, as well as manual triggers (`workflow_dispatch`).
2. **Quality Gate Compliance**:
   - The repository must maintain a **Passing Quality Gate** on `main` prior to release tagging.
   - Enforces zero open vulnerabilities, zero open security hotspots, and code smell remediation.
3. **Central Secret Management**:
   - Authentication is governed via GitHub Secrets (`SONAR_HOST_URL`, `SONAR_TOKEN`), executing on self-hosted runners (`arc-runner-set`).

## Options considered

| Option | Verdict | Why (one line) |
| :--- | :--- | :--- |
| Centralized SonarQube via `adorsys-ci-cd-templates` | Adopted | Centralized dashboard, historical metrics, and audit-ready ISO 27001 / OWASP compliance mapping. |
| Rely solely on SAST linter checks (Reviewdog) | Rejected | No centralized dashboard, no cross-branch historical tracking, and lacks unified compliance reporting required by external auditors. |

## Consequences

**Not part of this decision:** Test coverage gate percentage enforcement (governed under Master Epic #2190).

### Impact

**Benefits**
- Centralized dashboard providing auditable evidence of code security for external audits.
- Automated quality gate blocks releases if severe vulnerabilities or hotspots are detected.
- Standardized integration shared with other core Wazuh repositories.

**Costs**
- Requires active availability of internal SonarQube server and valid runner secrets.
- Requires ongoing maintenance of project keys and scanner exclusion properties.

**Risks**
- Runner or SonarQube server downtime delaying CI; handled via timeout configurations.

### Accepted limits

- Analysis runs post-merge on protected branches (`develop`, `main`) rather than as a prerequisite check on all external forks.

### Done when

- [x] `.github/workflows/sonarqube.yml` configured and active.
- [x] Runner secrets `SONAR_HOST_URL` and `SONAR_TOKEN` mapped.
- [x] Scans reporting to `https://sonarqube.sol-adorsys.com` project `wazuh-agent`.

### Revisit when

- Annually during ISO 27001 review or when SonarQube server is upgraded.

## Rollback

Nothing to roll back.

## Evidence

| Claim | Where |
| :--- | :--- |
| SonarQube instance | `https://sonarqube.sol-adorsys.com` |
| Project key registration | SonarQube project `wazuh-agent` |

## References

- Workflow Definition: [`.github/workflows/sonarqube.yml`](../../.github/workflows/sonarqube.yml)
- SonarQube Server: [https://sonarqube.sol-adorsys.com](https://sonarqube.sol-adorsys.com)
- Master Security Specification: [Wazuh SAST Integration Guide](https://github.com/ADORSYS-GIS/wazuh-playbook/blob/main/SOC-Documentation/sast-integration.md)

## Solution implementation

| Kind | Tracking | Status | What it covers |
| :--- | :--- | :--- | :--- |
| Issue | ADORSYS-GIS/wazuh-agent#265 | Open | Audit-readiness: Implement SAST & SonarQube ADRs with Central Playbook Integration |
| PR | ADORSYS-GIS/wazuh-agent#266 | Open | In-repo ADRs, visual evidence, and documentation standard alignment |
