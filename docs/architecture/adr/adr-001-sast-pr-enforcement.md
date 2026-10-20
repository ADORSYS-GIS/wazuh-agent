# ADR-001: Pre-Merge Static Application Security Testing (SAST) Enforcement

## Status
Accepted ✅

## Date
2026-10-20

## Deciders
SIEM Security Engineering Team

---

## Context
The `wazuh-agent` repository contains critical client-side automation and deployment logic spanning multiple scripting languages:
- **Bash** (`install.sh`, Linux/macOS agent configuration scripts)
- **PowerShell** (`Install.ps1`, Windows enrollment and service setup scripts)
- **Python** (Auxiliary integration and verification tools)

Historically, code quality was validated using scattered local scripts and manual review, leading to inconsistent security postures across platforms. Vulnerabilities such as unquoted variables in shell scripts, insecure command execution in PowerShell, or path traversal flaws could impact endpoint security across the entire infrastructure.

We required an automated, reproducible security verification gate that runs on every pull request, provides immediate inline feedback to contributors, and enforces compliance without hindering developer velocity.

---

## Decision
We enforce automated **Static Application Security Testing (SAST)** on all pull requests and pushes to `main` by consuming standardized reusable workflows from `ADORSYS-GIS/adorsys-ci-cd-templates`.

The enforcement mechanism operates via `.github/workflows/sast.yml`:
1. **Multi-Language Matrix Scanning**:
   - **ShellCheck** (`sast-shell.yml`): Analyzes `install.sh` and shell utilities.
   - **PSScriptAnalyzer** (`sast-powershell.yml`): Scans `Install.ps1` for PowerShell best practices and security rules.
   - **Bandit** (`sast-python.yml`): Scans all Python utilities for common security weaknesses.
2. **Reviewdog PR Annotations**:
   - SAST findings are surfaced directly on the GitHub Pull Request diff using `reviewdog`.
   - Requires explicit GitHub Actions workflow permissions: `contents: read`, `actions: read`, `checks: write`.
3. **Pre-Merge Quality Gate**:
   - PR checks must pass cleanly before code can be merged into protected branches.

---

## Alternatives Considered

### Alternative 1: Run scanners locally via pre-commit hooks only
- **Pros**: Catches issues before pushing to remote.
- **Cons**: Cannot be mechanically enforced; relies on developer discipline; cannot serve as auditable proof for ISO 27001 auditors.
- **Why rejected**: Lacks centralized enforcement and verification trails.

### Alternative 2: Bespoke scanner installation in repository CI
- **Pros**: Direct control over scanner versions in-repo.
- **Cons**: Redundant maintenance across 10+ Wazuh repositories; high drift risk.
- **Why rejected**: Standardizing on `adorsys-ci-cd-templates` ensures uniform security policies across the ecosystem.

---

## Consequences

### Positive
- ✅ Consistent, auditable static security checks across Linux, Windows, and macOS installation scripts.
- ✅ Immediate feedback directly on PR diffs via Reviewdog annotations.
- ✅ Satisfies ISO 27001 requirements for secure systems development and automated verification.

### Negative & Operational Considerations
- ⚠️ PR authors must address scanner warnings before merge.
- ⚠️ Workflow requires `checks: write` permissions for GitHub Actions to post review comments.

---

## References
- Reusable CI Templates: `ADORSYS-GIS/adorsys-ci-cd-templates`
- Master Security Specification: `wazuh-playbook/SOC-Documentation/sast-integration.md`
