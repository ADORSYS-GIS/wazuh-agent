# ADR-0005: Automate Dependency Updates with Dependabot

> We introduce GitHub Dependabot configuration to automate GitHub Actions workflow updates on a weekly schedule with pull request limits and cool-down buffers.

## Metadata

| Field             | Value                                              |
| :---------------- | :------------------------------------------------- |
| **Document ID**   | ADR-0005                                           |
| **Status**        | `Accepted`                                         |
| **Date**          | 2026-11-06                                         |
| **Deciders**      | SIEM Security Engineering Team                     |
| **Governs**       | `.github/dependabot.yml`                           |
| **Amends**        | N/A                                                |
| **Amended by**    | N/A                                                |
| **Supersedes**    | N/A                                                |
| **Superseded by** | N/A                                                |

## Context

The `wazuh-agent` repository maintains installation, configuration, testing, and active response automation for Wazuh agents across Linux, macOS, and Windows. While the repository contains shell and PowerShell scripts, its CI/CD pipeline in `.github/workflows/` relies heavily on third-party GitHub Actions (`actions/checkout`, `actions/upload-artifact`, `actions/download-artifact`, `dtolnay/rust-toolchain`, SonarSource scanner actions, etc.).

Previously, GitHub Actions action version updates were handled manually. This introduces operational and security risks:
- GitHub Actions runners regularly deprecate older runtimes (e.g. Node.js 16/20 deprecations), causing CI pipelines to fail if actions are not kept updated.
- Security updates and bug fixes published by action maintainers are delayed until manual reviews happen.
- Org-wide standardization under Epic ADORSYS-GIS/wazuh#2354 establishes automated dependency management across all active repositories using Dependabot, modeled after `wazuh-cert-oauth2`.

The deciding forces are:
- Keep CI/CD action references secure and compatible with GitHub-hosted runners.
- Automate updates without cluttering PR queues.
- Standardize configuration across organizational repositories.

## Decision

We will configure GitHub Dependabot in `.github/dependabot.yml` for the `github-actions` ecosystem:

1. **Schedule**:
   - `package-ecosystem: github-actions`: Scans `.github/workflows` on a `weekly` schedule at `08:00` UTC.

2. **Throttling & Buffering**:
   - `open-pull-requests-limit: 10`: Prevents automated pull request flooding.
   - `cooldown.default-days: 7`: Enforces a 7-day stabilization buffer before opening non-critical update PRs.

## Options considered

| Option                                              | Verdict  | Why (one line)                                                                    |
| :-------------------------------------------------- | :------- | :-------------------------------------------------------------------------------- |
| Manual workflow action updates (status quo)         | Rejected | Inefficient and prone to missed runner deprecations or security advisories.       |
| Daily action update scanning                        | Rejected | Generates unnecessary noise for CI workflow actions that update infrequently.     |
| Weekly Dependabot scanning with cooldown (Adopted)  | Adopted  | Balances prompt security updates with minimal notification noise and stability.   |

## Consequences

**Not part of this decision:** Automatic merging of Dependabot PRs. All action updates must pass existing CI test matrices (`Test Unix`, `Test Windows`, `Integration Tests`, `SonarQube`) and undergo review.

### Impact

**Benefits**

- Workflow actions stay current and avoid runner runtime deprecation breakage.
- Security vulnerabilities in CI actions are surfaced automatically.
- Weekly cadence prevents alert fatigue.

**Costs**

- Maintainers review and merge automated version update pull requests.

### Done when

- [x] `.github/dependabot.yml` is committed with `github-actions` configuration.
- [x] Weekly interval, PR limit of 10, and 7-day cooldown are verified.
- [x] ADR-0005 is documented and indexed in `docs/adr/README.md`.

## Rollback

Delete or revert `.github/dependabot.yml`. Dependabot will stop scanning and cease opening PRs.

## Evidence

| Claim                                                                 | Where                                                          |
| :-------------------------------------------------------------------- | :------------------------------------------------------------- |
| Organization reference convention                                     | `ADORSYS-GIS/wazuh-cert-oauth2/.github/dependabot.yml`         |
| Sub-issue scope definition                                            | `ADORSYS-GIS/wazuh-agent#280`                                  |
| Organization epic tracking                                            | `ADORSYS-GIS/wazuh#2354`                                       |

## References

- [GitHub Dependabot Configuration Options](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [ADR template](https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/adr/template.md)
- [ADR writing guide](https://github.com/ADORSYS-GIS/wazuh/blob/main/docs/adr/GUIDE.md)

## Solution implementation

| Kind   | Tracking                                                                                   | Status | What it covers                                |
| :----- | :----------------------------------------------------------------------------------------- | :----- | :-------------------------------------------- |
| Issue  | [ADORSYS-GIS/wazuh-agent#280](https://github.com/ADORSYS-GIS/wazuh-agent/issues/280)       | Open   | Add dependabot configuration to wazuh-agent   |
| PR     | [ADORSYS-GIS/wazuh-agent#281](https://github.com/ADORSYS-GIS/wazuh-agent/pull/281)         | Open   | Adds .github/dependabot.yml and ADR-0005      |
