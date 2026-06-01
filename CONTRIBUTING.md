# Contributing to Wazuh Agent Setup

Thank you for your interest in contributing to the Wazuh Agent Setup project! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Convention](#commit-convention)
- [Creating Pre-Releases](#creating-pre-releases)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Code Review](#code-review)

## Code of Conduct

Please be respectful and professional in all interactions. We aim to maintain a welcoming and inclusive environment for all contributors.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/wazuh-agent.git
   cd wazuh-agent
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ADORSYS-GIS/wazuh-agent.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Branch Strategy

- `main` - Stable production releases
- `develop` - Integration branch for features (no automatic releases)
- `feature/*` - Feature development branches
- `hotfix/*` - Emergency fixes for production

### Making Changes

1. Keep your fork's `develop` branch up to date:
   ```bash
   git checkout develop
   git pull upstream develop
   ```

2. Create a feature branch from `develop`:
   ```bash
   git checkout -b feature/your-feature
   ```

3. Make your changes and commit using conventional commits (see below)

4. Push to your fork:
   ```bash
   git push origin feature/your-feature
   ```

5. Open a Pull Request to the `develop` branch

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification. Each commit message should be structured as:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(install): add support for Rocky Linux` |
| `fix` | Bug fix | `fix(verify): correct checksum validation logic` |
| `security` | Security improvement | `security(deps): update vulnerable dependencies` |
| `perf` | Performance improvement | `perf(install): optimize package installation` |
| `docs` | Documentation changes | `docs(readme): update installation instructions` |
| `refactor` | Code refactoring | `refactor(setup): extract common functions` |
| `test` | Test additions/changes | `test(verify): add unit tests for validation` |
| `chore` | Maintenance tasks | `chore(deps): update dependencies` |
| `ci` | CI/CD changes | `ci(workflow): add security scanning` |

### Examples

```bash
# Feature
git commit -m "feat(install): add Alpine Linux support"

# Bug fix
git commit -m "fix(setup): resolve agent registration timeout"

# Security fix
git commit -m "security(install): validate download URLs before fetch"

# Documentation
git commit -m "docs(contributing): add pre-release creation guide"

# Breaking change
git commit -m "feat(install)!: change default Suricata mode to IPS

BREAKING CHANGE: Suricata now defaults to IPS mode instead of IDS.
Users can opt-in to IDS mode using -s ids flag."
```

## Creating Pre-Releases

Pre-releases (release candidates, beta versions) are created **manually** by pushing tags. The CI/CD pipeline will automatically detect the pre-release suffix and mark the GitHub release appropriately.

### When to Create a Pre-Release

- Before merging to `main` for final release
- To test features in production-like environment
- To share experimental builds with testers
- For milestone checkpoints during development

### Pre-Release Naming Convention

Tags should follow semantic versioning with pre-release identifiers:

- **Release Candidate**: `v1.9.0-rc.1`, `v1.9.0-rc.2`, etc.
- **Beta**: `v1.9.0-beta.1`, `v1.9.0-beta.2`, etc.
- **Alpha**: `v1.9.0-alpha.1`, `v1.9.0-alpha.2`, etc.

### Step-by-Step: Creating a Release Candidate

1. **Ensure develop branch is ready**:
   ```bash
   git checkout develop
   git pull upstream develop
   ```

2. **Verify all tests pass locally** (optional but recommended):
   ```bash
   # Run shellcheck on bash scripts
   find scripts lib -name "*.sh" -type f | xargs shellcheck

   # Test PowerShell syntax
   pwsh -Command "Get-ChildItem -Path scripts,lib -Filter '*.ps1' -Recurse | ForEach-Object { \$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content \$_.FullName -Raw), [ref]\$null) }"
   ```

3. **Create and push the tag**:
   ```bash
   # Create the tag locally
   git tag v1.9.0-rc.1 -m "Release Candidate 1 for v1.9.0"

   # Push the tag to trigger CI/CD
   git push upstream v1.9.0-rc.1
   ```

   > **Note**: Replace `v1.9.0-rc.1` with your desired version

4. **What happens automatically**:
   - ✅ All tests run (lint, security, Unix, Windows, integration)
   - ✅ GitHub release is created
   - ✅ Release is automatically marked as **pre-release**
   - ✅ Checksums are generated and uploaded
   - ✅ Release notes are generated from commits

5. **Monitor the CI/CD pipeline**:
   - Visit the [Actions tab](https://github.com/ADORSYS-GIS/wazuh-agent/actions)
   - Wait for the workflow to complete
   - Verify the release appears in [Releases](https://github.com/ADORSYS-GIS/wazuh-agent/releases)

### Testing a Pre-Release

Users can test pre-releases by specifying the tag:

```bash
# Linux/macOS
export WAZUH_AGENT_REPO_REF=refs/tags/v1.9.0-rc.1
curl -fsSL https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/v1.9.0-rc.1/install.sh | bash

# Windows
$env:WAZUH_AGENT_REPO_REF = "refs/tags/v1.9.0-rc.1"
irm https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-agent/v1.9.0-rc.1/install.ps1 | iex
```

### Incrementing RC Versions

If you need to create additional release candidates:

```bash
# RC 2
git tag v1.9.0-rc.2 -m "Release Candidate 2 for v1.9.0"
git push upstream v1.9.0-rc.2

# RC 3
git tag v1.9.0-rc.3 -m "Release Candidate 3 for v1.9.0"
git push upstream v1.9.0-rc.3
```

### Promoting RC to Stable Release

Once testing is complete, merge to `main` for automatic stable release:

1. Create PR from `develop` to `main`
2. Get approvals and merge
3. Release Please will automatically create a stable release PR
4. Merge the Release Please PR to create the stable release

## Pull Request Process

### Before Submitting

- [ ] Run all tests locally
- [ ] Update documentation if needed
- [ ] Add tests for new functionality
- [ ] Follow the commit convention
- [ ] Rebase on latest `develop` branch

### PR Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Security improvement
- [ ] Documentation update
- [ ] Code refactoring

## Testing
- [ ] Tested on Linux
- [ ] Tested on macOS
- [ ] Tested on Windows
- [ ] All CI/CD checks pass

## Related Issues
Closes #123
```

### Review Process

1. At least one maintainer approval required
2. All CI/CD checks must pass
3. Code should follow existing style conventions
4. Changes should include appropriate tests

## Testing Requirements

### Automated Tests

All PRs must pass:
- **Linting**: ShellCheck (bash) and PSScriptAnalyzer (PowerShell)
- **Security Scanning**: Trivy filesystem scan and secret detection
- **Platform Tests**: Ubuntu, macOS, Windows syntax and functionality
- **Integration Tests**: Cross-platform verification

### Manual Testing

When adding new features, test on:
- Ubuntu (latest)
- macOS (Intel and Apple Silicon if possible)
- Windows 10/11

### Testing Checklist

- [ ] Scripts execute without errors
- [ ] Wazuh agent installs correctly
- [ ] Agent connects to manager
- [ ] Security tools (Yara, Suricata/Snort) install properly
- [ ] Checksums verify correctly
- [ ] Uninstall script removes all components

## Code Review

### What Reviewers Look For

- **Correctness**: Does the code work as intended?
- **Security**: Are there any security vulnerabilities?
- **Maintainability**: Is the code readable and well-structured?
- **Testing**: Are changes adequately tested?
- **Documentation**: Is documentation updated?

### Responding to Feedback

- Be open to suggestions and constructive criticism
- Make requested changes promptly
- Ask for clarification if feedback is unclear
- Mark conversations as resolved once addressed

## Questions?

If you have questions about contributing:

- Open a [GitHub Discussion](https://github.com/ADORSYS-GIS/wazuh-agent/discussions)
- Review existing [Issues](https://github.com/ADORSYS-GIS/wazuh-agent/issues)
- Check the [README](README.md) for project overview

Thank you for contributing! 🙏
