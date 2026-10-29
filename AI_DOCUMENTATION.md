# WIBUTUNNEL - AI Assistant Documentation

**Last Updated:** 2026-10-26  
**Version:** 4.0 KURUMI  
**HEAD Commit:** 74fa709a09925964810e4f520f31d0737042d1be

## Quick Context for AI Assistants

WIBUTUNNEL adalah VPN tunnel management system berbasis Xray dengan:
- Multi-protocol support (VLESS, VMESS, Trojan)
- Telegram bot integration untuk notifikasi
- Automated expiry management & recovery system
- Account locking/unlocking system
- Login tracking & quota management

---

## Repository Structure

```
wibutunnel-repo/
├── setup.sh                 # Master installer - entry point
├── uninstall.sh            # Clean removal script
├── common.sh               # Shared functions & variables
├── menu/                   # User interface scripts
│   ├── menu.sh            # Main menu
│   ├── m-vless.sh         # VLESS protocol management
│   ├── m-vmess.sh         # VMESS protocol management
│   ├── m-trojan.sh        # Trojan protocol management
│   ├── m-setting.sh       # System settings
│   ├── m-backup.sh        # Backup/restore
│   ├── xp.sh              # Expiry management UI
│   ├── menu-lock.sh       # Account locking UI
│   ├── menu-unlock.sh     # Account unlocking UI
│   ├── menu-recovery.sh   # Recovery system UI
│   ├── cek-trafik.sh      # Traffic monitoring
│   ├── bot-daemon.sh      # Telegram bot service
│   └── bot-webhook.sh     # Bot webhook handler
└── sbin/                   # System daemons
    ├── algojo-wibu         # Login tracking daemon
    ├── algojo-kuota        # Quota enforcement daemon
    ├── algojo-expired      # Expiry check (one-shot)
    ├── algojo-expired-daemon # Expiry daemon (systemd)
    ├── lock-user           # Lock account utility
    ├── unlock-user         # Unlock account utility
    └── unlocker-wibu       # Auto-unlock scheduler
```

---

## Installation Process

### Prerequisites
- Ubuntu/Debian VPS
- Root access
- Domain pointing to server IP
- Telegram bot token (optional but recommended)

### Install Command
```bash
bash setup.sh
```

### What setup.sh Does

1. **System Check** (lines 1-100)
   - Detect OS, check root permission
   - Verify internet connectivity

2. **Dependency Installation** (lines 100-400)
   - Install core packages: curl, jq, wget, netcat, etc
   - Setup Xray core (latest version from official source)
   - Configure nginx/HAProxy as frontend

3. **File Installation** (lines 500-800)
   - Download 20 files dari repo via `_need()` wrapper
   - Install ke /usr/local/{bin,sbin}
   - Set executable permissions

4. **Configuration** (lines 800-1000)
   - Prompt domain name
   - Generate SSL certificates (acme.sh)
   - **Prompt BOT_TOKEN & CHAT_ID** → /etc/wibutunnel/bot.conf
   - Setup Xray config.json with 3 protocols

5. **Systemd Services** (lines 1000-1200)
   - telegram-bot.service (bot-daemon.sh)
   - algojo-expired.service (expiry daemon)
   - Enable & start services

6. **Validation** (lines 1200-end)
   - **Check _dl_fail flag** - abort if any download failed
   - Verify Xray running
   - Display completion message

---

## Critical Bug Fixes (439ae73 → 74fa709)

### Bug #1: Download Failure Not Fatal (Fixed: cb0a882)
**Problem:** `download_menu` dipanggil 20+ kali tapi return code diabaikan. Install lanjut dengan file missing → crash.

**Fix:**
```bash
# Line 531-532
_dl_fail=0
_need() { download_menu "$1" "$2" || { echo -e "\e[31m[!] Gagal install $2\e[0m"; _dl_fail=1; }; }

# Line 778 - abort check
if [[ "${_dl_fail:-0}" == "1" ]]; then
    echo "Installation FAILED - some files missing"
    exit 1
fi
```

**Impact:** Installer sekarang abort safely bila download gagal, tidak lanjut dengan state broken.

---

### Bug #2: bot.conf Never Created (Fixed: cb0a882)
**Problem:** bot-daemon.sh expect `/etc/wibutunnel/bot.conf` tapi setup.sh tidak pernah buat file ini. Bot crash on startup.

**Fix:**
```bash
# Line 593
read -p "Enter BOT_TOKEN: " _bt
read -p "Enter CHAT_ID: " _bc
printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "$_bt" "$_bc" > /etc/wibutunnel/bot.conf
chmod 600 /etc/wibutunnel/bot.conf
```

**Impact:** Bot notifikasi sekarang work properly. User dapat monitoring via Telegram.

---

### Bug #3: Infinite Expiry Loop (Fixed: 74fa709)
**Problem:** Recovery flag line format: `user:<epoch>:0:EXPIRED`

`algojo-expired-daemon` parsing:
```bash
while IFS=: read -r user exp_str; do
    # exp_str jadi <epoch> (pure digit)
    exp_ts=$(date -d "$exp_str" +%s 2>/dev/null)  # BERHASIL! date -d <epoch> valid
    # Loop: anggap expired → hapus user → kirim notif → restart xray → tulis flag lagi
done
```

Setiap 5 detik: delete user → notify → restart → flag → repeat forever.

**Fix:**
```bash
# Line 19 - guard sebelum date parsing
[[ "$exp_str" =~ ^[0-9]+$ ]] && continue  # skip pure digit (epoch dari flag)
```

**Impact:** Recovery system stable. Flag line tidak trigger infinite loop lagi.

---

## Key Files Deep Dive

### setup.sh - Master Installer
**Critical sections:**
- Line 531-532: `_need()` wrapper untuk error tracking
- Line 593: bot.conf creation prompt
- Line 778: abort check sebelum service start
- Line 400-500: Xray installation & config generation

**Dependencies:** curl, jq, wget, nginx/haproxy, acme.sh

**Exit codes:**
- 0: success
- 1: general error / download failed
- 2: missing root permission

---

### sbin/algojo-expired-daemon
**Purpose:** Monitor user expiry setiap 5 detik, hapus expired users, kirim notif Telegram.

**Critical logic:**
```bash
# Line 15-30: Parse expiry files
for proto_file in /etc/xray/exp_{vless,vmess,trojan}; do
    while IFS=: read -r user exp_str; do
        [[ "$exp_str" == "Lifetime" ]] && continue
        [[ "$exp_str" =~ ^[0-9]+$ ]] && continue  # BUG FIX #3
        
        exp_ts=$(date -d "$exp_str" +%s 2>/dev/null) || continue
        [[ $NOW -le $exp_ts ]] && continue
        
        # User expired
        if [[ "$user" == trial-* ]]; then
            # Trial: delete immediately
            # Send notif, remove from config, restart xray
        else
            # Regular: create recovery file
            jq -c --arg u "$user" '{user:$u, client:...}' > /etc/wibutunnel/recovery/${user}.json
            # Send notif, remove from config, restart xray
            # Write flag: echo "$user:$NOW:0:EXPIRED" >> $proto_file
        fi
    done < "$proto_file"
done
```

**Recovery flag format:**
- Trial delete: (no flag, permanent removal)
- Regular expire: `username:1730000000:0:EXPIRED`
  - Field 1: username
  - Field 2: epoch when expired
  - Field 3: always 0
  - Field 4: marker "EXPIRED"

**Recovery process:** `menu-recovery.sh` read recovery JSON, restore user dengan expiry baru.

---

### menu/bot-daemon.sh
**Purpose:** Telegram bot untuk create/delete/check users via chat commands.

**Dependencies:**
- /etc/wibutunnel/bot.conf (BOT_TOKEN, CHAT_ID)
- Xray config.json di /etc/xray/config.json

**Commands:**
- `/create <proto> <user> <days>` - buat user baru
- `/delete <user>` - hapus user
- `/check <user>` - cek status & expiry
- `/list` - list all users
- `/traffic` - traffic stats

**Long polling:** daemon loop check Telegram getUpdates API setiap detik.

---

## Common Maintenance Tasks

### Add New User (CLI)
```bash
# VLESS
bash /usr/local/bin/m-vless
# Pilih option 1 (create), masukkan username & days

# VMESS  
bash /usr/local/bin/m-vmess

# Trojan
bash /usr/local/bin/m-trojan
```

### Check Expiry Status
```bash
# Manual check
cat /etc/xray/exp_vless
cat /etc/xray/exp_vmess
cat /etc/xray/exp_trojan

# Format: username:YYYY-MM-DD HH:MM:SS
# Or: username:Lifetime
```

### View Logs
```bash
# Xray logs
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# Bot daemon
journalctl -u telegram-bot -f

# Expiry daemon
journalctl -u algojo-expired -f
```

### Restart Services
```bash
systemctl restart xray
systemctl restart telegram-bot
systemctl restart algojo-expired
```

### Manual Backup
```bash
bash /usr/local/bin/m-backup
# Creates /root/backup-YYYYMMDD.tar.gz
# Includes: /etc/xray, /etc/wibutunnel, /usr/local/{bin,sbin}
```

---

## Configuration Files

### /etc/xray/config.json
Xray core configuration dengan 9 inbounds:
- [0] = Trojan TLS port 443
- [1] = VLESS TLS port 443
- [2] = VLESS gRPC
- [3] = VLESS HTTP/2
- [4] = VMESS TLS
- [5] = VMESS WS
- [6] = VMESS gRPC
- [7] = Trojan WS
- [8] = Trojan gRPC

**Edit with caution:** jq digunakan untuk atomic edit. Direct edit risk corruption.

```bash
# Safe edit pattern (digunakan di scripts)
safe_jq_edit_args() {
    local tmp=/tmp/xray-config-$$.json
    jq "$@" /etc/xray/config.json > "$tmp" && mv "$tmp" /etc/xray/config.json
}
```

### /etc/wibutunnel/bot.conf
```bash
BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
CHAT_ID=987654321
```

**Security:** chmod 600, hanya root read. Tidak boleh commit ke git.

### /etc/xray/domain
Plain text file berisi domain server. Digunakan untuk generate connection URLs.

```bash
cat /etc/xray/domain
# Output: vpn.example.com
```

---

## Troubleshooting Guide for AI

### Issue: "Bot not responding"
**Check:**
```bash
# Service status
systemctl status telegram-bot

# Config exists?
ls -la /etc/wibutunnel/bot.conf

# Token valid?
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq .
```

**Fix:**
```bash
# Recreate bot.conf
read -p "BOT_TOKEN: " token
read -p "CHAT_ID: " chat
printf "BOT_TOKEN=%s\nCHAT_ID=%s\n" "$token" "$chat" > /etc/wibutunnel/bot.conf
chmod 600 /etc/wibutunnel/bot.conf
systemctl restart telegram-bot
```

---

### Issue: "Users not expiring"
**Check:**
```bash
# Daemon running?
systemctl status algojo-expired

# Check logs
journalctl -u algojo-expired --since "1 hour ago"

# Manual test
bash /usr/local/sbin/algojo-expired
```

**Debug:**
```bash
# Check expiry file format
cat /etc/xray/exp_vless
# Valid: user123:2026-12-31 23:59:59
# Invalid: user123:1735689599 (pure epoch akan di-skip oleh bug fix)
```

---

### Issue: "Installation fails midway"
**Check:**
```bash
# Run with debug
bash -x setup.sh 2>&1 | tee install.log

# Look for download failures
grep "Gagal install" install.log

# Check _dl_fail abort
grep "_dl_fail" install.log
```

**Common causes:**
1. Network timeout → retry dengan koneksi stabil
2. GitHub API rate limit → tunggu 1 jam atau gunakan token
3. File missing dari repo → verify repo complete

---

## Portability Notes

### Hardcoded Values (NONE)
Installer sekarang tidak ada hardcoded:
- ✓ No hardcoded uid/gid (verified: 0 occurrences)
- ✓ No hardcoded domain (read from user input)
- ✓ No absolute paths khas VPS tertentu

### Dynamic Detection
- OS type: `grep -w ID /etc/os-release`
- Public IP: `curl -s ifconfig.me`
- Domain validation: `dig +short $domain`

### Fresh Install Requirements
Minimal VPS specs:
- OS: Ubuntu 18.04+ / Debian 9+
- RAM: 512MB minimum, 1GB recommended
- Disk: 2GB free space
- Network: Public IPv4, ports 80/443 open

---

## Testing & Validation

### Pre-deployment Checks
```bash
# 1. Syntax validation
find . -name "*.sh" -exec bash -n {} \; -print

# 2. Portability check
grep -r "uid=" --include="*.sh" | grep -v uuid=
grep -r "gid=" --include="*.sh" | grep -v guid=

# 3. Simulate install (isolated)
bash /tmp/sim-install.sh

# 4. Verify archive
unzip -t wibutunnel-source-*.zip
```

### Post-install Validation
```bash
# Services running?
systemctl is-active xray telegram-bot algojo-expired

# Xray listening?
netstat -tlnp | grep xray

# Config valid?
xray -test -config /etc/xray/config.json

# Bot responsive?
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe"
```

---

## Development Workflow

### Making Changes
1. **Edit files** di /root/wibutunnel-repo/
2. **Test locally:**
   ```bash
   bash -n <file>  # syntax check
   bash <file>     # test run
   ```
3. **Commit:**
   ```bash
   cd /root/wibutunnel-repo
   git add <files>
   git commit -m "Brief description"
   ```
4. **Verify portability:**
   ```bash
   # No hardcoded values
   grep -rn "uid=" . | grep -v uuid=
   grep -rn "domain=" . | grep -v "domain=\"\${" | grep -v "domain=\"\""
   ```
5. **Test install simulation:**
   ```bash
   bash /tmp/sim-install.sh
   ```
6. **Package:**
   ```bash
   cd /root
   zip -r wibutunnel-source-$(date +%Y%m%d-%H%M%S).zip wibutunnel-repo/ \
       -x "*.git*" -x "*node_modules*"
   ```

### Code Style
- Bash strict mode: `set -euo pipefail` (kecuali installer utama)
- Error handling: check return codes critical operations
- Atomic config edits: jq + temp file + mv
- Security: chmod 600 sensitive files (bot.conf)

---

## Known Limitations

1. **Single-server only** - tidak support cluster/multi-node
2. **No database** - state di flat files (/etc/xray/exp_*, config.json)
3. **Telegram only** - notifikasi hanya via Telegram, no email/webhook
4. **Manual domain setup** - DNS harus configured sebelum install
5. **No rate limiting** - bot commands tidak ada rate limit

---

## Future Improvements (Ponytail Comments)

```bash
# ponytail: add rate limiting, upgrade to Redis when bot hits 100 users/day
# ponytail: add database backend, upgrade when user count > 1000
# ponytail: add multi-server support, upgrade when need horizontal scaling
```

---

## Emergency Recovery

### Restore from Backup
```bash
# Extract backup
cd /root
tar -xzf backup-20261025.tar.gz

# Restore configs
cp -r backup/etc/xray/* /etc/xray/
cp -r backup/etc/wibutunnel/* /etc/wibutunnel/

# Restore scripts
cp -r backup/usr/local/bin/* /usr/local/bin/
cp -r backup/usr/local/sbin/* /usr/local/sbin/
chmod +x /usr/local/bin/* /usr/local/sbin/*

# Restart services
systemctl restart xray telegram-bot algojo-expired
```

### Clean Reinstall
```bash
# Backup user data first
cp -r /etc/xray /root/xray-backup-$(date +%s)

# Uninstall
bash /root/wibutunnel-repo/uninstall.sh

# Fresh install
cd /root/wibutunnel-repo
bash setup.sh

# Restore user data
cp /root/xray-backup-*/exp_* /etc/xray/
cp /root/xray-backup-*/config.json /etc/xray/
systemctl restart xray
```

---

## AI Assistant Quick Commands

When user says:

**"Install wibutunnel"**
```bash
cd /root/wibutunnel-repo && bash setup.sh
```

**"Check status"**
```bash
systemctl status xray telegram-bot algojo-expired | grep -E "(Active|Main PID)"
```

**"Add user"**
```bash
bash /usr/local/bin/m-vless  # or m-vmess, m-trojan
```

**"View logs"**
```bash
journalctl -u telegram-bot --since "10 minutes ago" -n 50
```

**"Restart all"**
```bash
systemctl restart xray telegram-bot algojo-expired
```

**"Backup now"**
```bash
bash /usr/local/bin/m-backup
```

**"Send source to telegram"**
```bash
source /etc/wibutunnel/bot.conf && \
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
  -F "chat_id=${CHAT_ID}" \
  -F "document=@/root/wibutunnel-source-latest.zip"
```

---

## Verification Commands for AI

Before claiming "installed successfully", run:
```bash
systemctl is-active xray && \
systemctl is-active telegram-bot && \
xray -test -config /etc/xray/config.json && \
echo "✓ All systems operational"
```

Before claiming "user created", verify:
```bash
jq '.inbounds[1].settings.clients[] | select(.email=="USERNAME")' /etc/xray/config.json && \
echo "✓ User exists in config"
```

Before claiming "backup created", verify:
```bash
ls -lh /root/backup-*.tar.gz && \
tar -tzf /root/backup-*.tar.gz | head -20 && \
echo "✓ Backup valid"
```

---

## Architecture Upgrades (v4.0.1)

1. **Zero-Downtime User Sync (`xray_sync_user` in `common.sh`)**
   - Dynamic client addition/removal via Xray gRPC HandlerService on `127.0.0.1:10085`.
   - Eliminates disruptive `systemctl restart xray` on create, trial, delete, lock, and unlock. Existing user sessions stay active.
   - Automatic fallback to restart if API port is unreachable.

2. **Atomic Flat-file DB Operations (`flock` in `common.sh`)**
   - `safe_sed_delete`, `db_set`, `db_append` protected by non-blocking/wait flock.
   - Eliminates race conditions and file wipeouts under concurrent bot/daemon executions.
   - Consolidated `db_get` and `db_has` helper routines.

3. **Elimination of Expiry Redundancy (`xp.sh` & `algojo-expired-daemon`)**
   - Real-time 5-second account expiration strictly delegated to `algojo-expired-daemon` systemd service.
   - `xp.sh` demoted from 1-minute crontab to daily midnight maintenance (`0 0 * * *`) for Xray/bot log truncation, temp file cleanup, and exp file deduplication.

4. **Lean Installer & Configurable Reboot (`setup.sh` & `m-setting.sh`)**
   - Stripped global `apt-get upgrade -y` from installer to prevent breakage of host packages and reduce install time to ~1 minute.
   - Replaced forced reboot with interactive prompt at the end of installation.
   - Auto-reboot crontab is now fully user-configurable (0-23 hours or 'off') via `m-setting` option [7].

5. **Bounded Telegram Bot Logging (`menu/bot-daemon.sh`)**
   - Removed stdout dumping of successful Telegram API responses (`{"ok":true}`) to `bot_error.log`.
   - Error logs strictly capped at 1MB with byte-based truncation (`tail -c 200000`).
   - Added manual log purge via `m-setting` options [2] and [6][4], plus daily truncation in `xp.sh`.

---

## Contact & Support

**Original Author:** wibuvpnstore@gmail.com  
**Version:** 4.0.1 KURUMI  
**Last Audit:** 2026-10-30 (5 architecture upgrades completed)  
**Verified Commit:** ac2379f1e0aa93e0f0f903cf522943265281c789

**AI Assistants:** This documentation updated untuk memudahkan context transfer antar session. Baca ini first sebelum perform operations.
