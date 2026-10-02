# GitHub Actions CI/CD Setup Guide

## Overview
Automated testing workflow for wibutunnel repository using GitHub Actions.

## Workflow File
**Location:** `.github/workflows/test.yml`

## Test Matrix

### 1. ShellCheck Job
- **Purpose:** Syntax validation for all shell scripts
- **Runtime:** ~1 minute
- **Scripts checked:** install.sh, setup.sh, uninstall.sh, bin/common.sh, wibu_installer.sh
- **Trigger:** Every push/PR affecting .sh files

### 2. Integration Test - Ubuntu 22.04
- **Purpose:** Full installation flow test on Ubuntu
- **Runtime:** ~25-30 minutes
- **Coverage:**
  - Installation with WIBU_NO_REBOOT flag
  - Service validation (xray, haproxy, dropbear, ws-stunnel)
  - Binary verification
  - Clean uninstallation

### 3. Integration Test - Debian 11
- **Purpose:** Full installation flow test on Debian
- **Runtime:** ~20-25 minutes
- **Coverage:** Same as Ubuntu test
- **Environment:** Debian 11 container with systemd

### 4. Ubuntu Kernel Fix Validation
- **Purpose:** Verify commit b231ced (kernel/grub hold logic)
- **Runtime:** ~1 minute
- **Checks:**
  - apt-mark hold logic present for linux-image/grub
  - --without-new-pkgs flag in apt upgrade
  - Ubuntu OS detection logic

### 5. Test Summary
- **Purpose:** Aggregate all test results
- **Dependencies:** Waits for all other jobs
- **Output:** Pass/fail summary with status per job

## Setup Instructions

### 1. Create Workflow File
```bash
mkdir -p .github/workflows
cp /path/to/test.yml .github/workflows/
```

### 2. Configure GitHub Secrets
Navigate to: **Repository Settings → Secrets and variables → Actions**

Add secret:
- **Name:** `WIBU_TOKEN`
- **Value:** `ghp_YOUR_TOKEN_HERE`
- **Purpose:** Access private wibutunnel-izin repository

### 3. Commit & Push
```bash
git add .github/workflows/test.yml
git commit -m "Add CI/CD workflow for automated testing"
git push origin main
```

### 4. Verify Workflow
1. Go to **Actions** tab in GitHub repository
2. Should see "Wibutunnel CI/CD Tests" workflow
3. Click on latest run to view progress

## Triggers

### Automatic
- Push to `main` or `develop` branches (when .sh files change)
- Pull requests to `main` or `develop` (when .sh files change)

### Manual
- Go to **Actions** tab
- Select "Wibutunnel CI/CD Tests"
- Click **Run workflow** button

## Status Badge

Add to README.md:
```markdown
![Tests](https://github.com/WBVPN/wibutunnel/actions/workflows/test.yml/badge.svg)
```

## Expected Results

### ✅ Success
All jobs pass:
- ShellCheck: 0 errors
- Ubuntu 22.04: All services active, binaries present
- Debian 11: All services active, binaries present
- Ubuntu Fix: Logic verified
- Summary: All green

### ❌ Failure Scenarios

#### ShellCheck Fails
- **Cause:** Syntax errors in shell scripts
- **Fix:** Run `shellcheck <script>` locally and fix errors

#### Integration Test Fails - Services
- **Cause:** Service not starting (xray/haproxy/dropbear/ws-stunnel)
- **Fix:** Check service configuration, review setup.sh logs

#### Integration Test Fails - Installation Timeout
- **Cause:** Installation takes >30 minutes
- **Fix:** Investigate network issues or apt package delays

#### Ubuntu Fix Test Fails
- **Cause:** Kernel hold logic missing or modified
- **Fix:** Ensure commit b231ced logic intact in setup.sh

## Cost & Resource Usage

### GitHub Actions Minutes
- Free tier: 2,000 minutes/month
- Estimated per workflow run: ~50 minutes total (parallel jobs)
- Expected usage: ~10 runs/week = 500 minutes/week

### Recommendations
- Enable for main/develop branches only
- Skip CI on documentation-only changes
- Use `[skip ci]` in commit message when appropriate

## Troubleshooting

### Workflow Not Running
1. Check `.github/workflows/test.yml` is in main branch
2. Verify path filters match changed files
3. Check repository Actions settings enabled

### License Error
```
fatal: could not read Username for 'https://github.com'
```
**Fix:** Add WIBU_TOKEN secret (see Setup step 2)

### Container Issues (Debian test)
```
failed to create container: permission denied
```
**Fix:** Ensure `--privileged` option in container config

### Service Start Failures
Check workflow logs under "Verify services" step:
```bash
sudo systemctl status <service> --no-pager
```

## Local Testing

Test workflow locally before pushing:
```bash
# Install act (GitHub Actions local runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow
act -j shellcheck
act -j ubuntu-kernel-fix-test
```

Note: Full integration tests not recommended locally (require privileged containers).

## Maintenance

### Adding New Tests
1. Edit `.github/workflows/test.yml`
2. Add new job under `jobs:` section
3. Update `summary` job dependencies
4. Test with workflow_dispatch trigger

### Updating OS Versions
Update `runs-on:` or `container.image:` values:
- Ubuntu: `ubuntu-22.04`, `ubuntu-24.04`
- Debian: `debian:11`, `debian:12`

### Adjusting Timeouts
Default: 30 minutes per integration test

Increase if needed:
```yaml
- name: Run installation
  timeout-minutes: 45  # Increase from 30
```

## Related Files
- `/tmp/shellcheck_fixes/validate.sh` - Local shellcheck runner
- `/tmp/shellcheck_fixes/integration_test.sh` - Standalone integration test
- `/tmp/shellcheck_fixes/docker_test_runner.sh` - Docker-based multi-OS test
- `/tmp/shellcheck_fixes/TESTING.md` - Comprehensive testing documentation
