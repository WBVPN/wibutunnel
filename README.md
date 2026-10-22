# WIBU TUNNELING v4.0 Kurumi

Lightweight Xray VPN script for Ubuntu/Debian VPS with automated user management, quota control, and security patches.

## Features

- Multi-protocol support: VMess, VLess, Trojan
- Automated user expiry and quota enforcement (Algojo)
- Telegram bot integration for remote management
- Race condition protection with file locking
- Webhook authentication and IP validation
- Memory-efficient architecture
- Backup and recovery tools

## Installation

```bash
apt update && apt install -y wget && wget -qO- https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash
```

## IP Registration (License System)

This script uses IP-based license verification. To register your VPS IP:

1. Create `izin.txt` file in the repository root with format:
   ```
   ### USERNAME EXPIRY_DATE IP_ADDRESS
   ```

2. Example:
   ```
   ### MYSERVER 2027-12-31 203.0.113.45
   ### TESTSERVER lifetime 198.51.100.10
   ```

3. Keep `izin.txt` local only (already in .gitignore for security)

Contact admin for IP registration: [@Iqbalzxc](https://t.me/Iqbalzxc)

## Security Patches (v4.0)

- **Race condition fix**: All `config.json` access uses `flock` via `safe_jq_edit()`
- **Webhook auth**: Telegram webhook protected with `X-Telegram-Bot-Api-Secret-Token`
- **IP validation**: Empty `MYIP` check prevents license bypass
- **Temp file collision**: `algojo-wibu` and `algojo-kuota` use unique `mktemp`
- **User matching**: Fixed escape functions for usernames with special characters
- **Complete uninstall**: Removes daemon, systemd overrides, logrotate, cron entries
- **Logrotate security**: Runs as `nobody:nogroup` with safe permissions

## Requirements

- Ubuntu 18.04+ or Debian 9+
- Fresh VPS installation recommended
- Minimum 512MB RAM
- Valid license from seller

## Support

Contact: [@Iqbalzxc](https://t.me/Iqbalzxc)
