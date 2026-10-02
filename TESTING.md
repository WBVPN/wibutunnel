# Integration Test Suite Documentation

## Overview
Automated integration test suite for wibutunnel - validates full installation flow, service functionality, and clean uninstallation.

## Files
- `integration_test.sh` - Main integration test script (runs on target system)
- `docker_test_runner.sh` - Docker-based test runner (runs tests in isolated containers)
- `validate.sh` - ShellCheck syntax validation

## Test Coverage

### Phase 1: Prerequisites Check
- ✓ Root privilege verification
- ✓ OS compatibility (Ubuntu/Debian)
- ✓ Network connectivity to GitHub

### Phase 2: Installation Test
- ✓ Domain configuration
- ✓ Repository cloning (with license)
- ✓ Full setup.sh execution (30min timeout)
- ✓ WIBU_NO_REBOOT flag prevents reboot

### Phase 3: Service Validation
Required services must be active:
- `xray` - VPN core service
- `haproxy` - Proxy & routing
- `dropbear` - SSH server
- `ws-stunnel` - WebSocket tunnel

### Phase 4: Binary Validation
- `/usr/local/bin/xray` - Core binary
- `/usr/local/bin/menu` - Management menu
- `/usr/local/bin/m-backup` - Backup script
- `/usr/local/bin/m-restore` - Restore script

### Phase 5: Configuration Validation
- `/usr/local/etc/xray/config.json` - Xray config (JSON validation)
- `/etc/haproxy/haproxy.cfg` - HAProxy config
- `/etc/wibutunnel/bot.conf` - Telegram bot config
- `/etc/xray/domain` - Domain file

### Phase 6: Uninstallation Test
- ✓ uninstall.sh execution
- ✓ Services stopped
- ✓ Binaries removed

## Usage

### Direct Test (on target VPS)
```bash
# As root
export GITHUB_TOKEN="ghp_xxxxx"
export TEST_DOMAIN="test.example.com"
bash integration_test.sh
```

### Docker Test (isolated, multi-OS)
```bash
# Requires Docker installed & running
export GITHUB_TOKEN="ghp_xxxxx"
bash docker_test_runner.sh
```

Tested OS:
- Ubuntu 22.04
- Debian 11

### Syntax Validation Only
```bash
bash validate.sh /path/to/wibutunnel
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_TOKEN` | No | - | GitHub PAT for private repos |
| `TEST_DOMAIN` | No | test.example.com | Domain for installation |
| `INSTALL_TIMEOUT` | No | 1800 | Installation timeout (seconds) |

## Exit Codes

- `0` - All tests passed
- `1` - Test failure (check logs)

## Logs

Integration test log: `/tmp/wibutunnel_integration_test.log`

View during execution:
```bash
tail -f /tmp/wibutunnel_integration_test.log
```

## CI/CD Integration

### GitHub Actions (recommended)
See `.github/workflows/test.yml` for full workflow.

```yaml
- name: Run Integration Tests
  run: |
    chmod +x docker_test_runner.sh
    ./docker_test_runner.sh
  env:
    GITHUB_TOKEN: ${{ secrets.WIBU_TOKEN }}
```

### Manual Scheduled Testing
```bash
# Add to crontab (weekly test)
0 2 * * 0 /path/to/docker_test_runner.sh | mail -s "Wibutunnel Test Report" admin@example.com
```

## Troubleshooting

### Test hangs during installation
- Check `/tmp/wibutunnel_integration_test.log`
- Default timeout: 30 minutes
- Increase with `INSTALL_TIMEOUT=3600`

### Service validation fails
- Verify OS compatibility (Ubuntu 22/20, Debian 11/12)
- Check network access to GitHub
- Review systemd service logs: `journalctl -u <service>`

### Docker test fails
- Ensure Docker daemon running: `docker info`
- Privileged mode required for systemd
- Check container logs: `docker logs <container_name>`

## Known Limitations

1. **No SSL certificate testing** - Tests use self-signed certs (Let's Encrypt requires real domain)
2. **Bot functionality not tested** - Requires valid Telegram token + real domain with SSL
3. **Network-dependent** - Requires GitHub access for cloning
4. **Time-intensive** - Full test takes ~25-30 minutes per OS

## Future Enhancements

- [ ] Add performance benchmarks
- [ ] Test SSL certificate generation (staging)
- [ ] Validate bot webhook functionality
- [ ] Add load testing (concurrent connections)
- [ ] Test backup/restore functionality
- [ ] Add security scanning (CVE checks)
