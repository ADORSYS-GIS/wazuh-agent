# ADR-002: SonarQube Centralized Quality Gate & Compliance Standards

## Status
Accepted ✅

## Date
2026-10-20

## Deciders
SIEM Security Engineering Team

---

## Context
While pre-merge SAST catches immediate syntax and language-specific security flaws, we need a unified platform to track long-term code quality, identify architectural code smells, enforce security hotspot reviews, and monitor test coverage trends across branches.

For our compliance roadmap (including ISO 27001 / TÜV Hessen certifications), auditors require demonstrable proof of centralized static analysis and quality gate enforcement across releases.

---

## Decision
Integrate `wazuh-agent` into the centralized SonarQube instance (`https://sonarqube.sol-adorsys.com`) using the reusable SonarQube workflow from `ADORSYS-GIS/adorsys-ci-cd-templates`.

The enforcement mechanism operates via `.github/workflows/sonarqube.yml`:
1. **Target Branches**:
   - Analysis runs on all pushes to `develop` and `main`, as well as manual triggers (`workflow_dispatch`).
2. **Quality Gate Compliance**:
   - The repository must maintain a **Passing Quality Gate** on `main` prior to release tagging.
   - Enforces zero open vulnerabilities, zero open security hotspots, and code smell remediation.
3. **Central Secret Management**:
   - Authentication is governed via GitHub Secrets (`SONAR_HOST_URL`, `SONAR_TOKEN`), executing on self-hosted runners (`arc-runner-set`).

---

## Alternatives Considered

### Alternative 1: Rely solely on SAST linter checks (Reviewdog)
- **Pros**: Simpler pipeline; no external server dependency.
- **Cons**: No centralized dashboard; no cross-branch historical tracking; lacks unified compliance reporting required by external auditors.
- **Why rejected**: Fails auditor demand for demonstrable quality gate history.

---

## Consequences

### Positive
- ✅ Centralized dashboard providing auditable evidence of code security for external audits.
- ✅ Automated quality gate blocks releases if severe vulnerabilities or hotspots are detected.
- ✅ Standardized integration shared with other core Wazuh repositories.

### Negative & Operational Considerations
- ⚠️ Requires active availability of internal SonarQube server and valid runner secrets.
- ⚠️ Requires ongoing maintenance of project keys and scanner exclusion properties.

---

## References
- Workflow Definition: [`.github/workflows/sonarqube.yml`](../../../.github/workflows/sonarqube.yml)
- SonarQube Server: [https://sonarqube.sol-adorsys.com](https://sonarqube.sol-adorsys.com)
- Master Security Specification: [Wazuh SAST Integration Guide](https://github.com/ADORSYS-GIS/wazuh-playbook/blob/main/SOC-Documentation/sast-integration.md)
