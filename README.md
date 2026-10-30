# 🦋 WIBU TUNNELING v4.0.3 KURUMI

**Auto-install VPN script** berbasis Xray dengan Telegram bot monitoring. Satu command, VPN langsung jalan.

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)](https://github.com/WBVPN/wibutunnel)
[![Version](https://img.shields.io/badge/Version-v4.0.3%20KURUMI-blue.svg)](https://github.com/WBVPN/wibutunnel)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)](https://github.com/WBVPN/wibutunnel)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## ✨ Fitur Utama

- 🔐 **3 Protokol + SSH**: VLESS, VMESS, TROJAN (WS-TLS, WS-NTLS, gRPC) & SSH Tunnel (Dropbear, WebSocket, Direct Port 80/443, Enhanced Split Payload)
- 🤖 **Telegram Bot**: Buat/hapus akun, cek login, backup - semua dari HP
- 🎯 **Auto Enforcement**: Kuota habis/expired = auto lock/delete + notif
- 🛡️ **IP Tracking**: Deteksi multi-device login real-time via live socket
- ⚡ **Trial Account**: Hardcoded 1 jam, auto-delete setelah expire/habis kuota
- 🔄 **Recovery System**: User expired/habis kuota disimpan, bisa restore dengan limit baru
- 🌐 **HAProxy + Xray**: Port 80/443 langsung aktif
- 🔒 **Auto SSL**: Let's Encrypt via certbot, auto-renew

---

## 🚀 Quick Start (Fresh VPS)

### Prerequisites
- Ubuntu 20.04+ atau Debian 11+
- Domain aktif dengan A record pointing ke IP VPS
- VPS minimal 1 CPU / 512MB RAM
- Root access
- IP VPS harus didaftarkan oleh admin di `izin.txt` sebelum instalasi (hubungi @wibuvpn atau pastikan IP sudah terdaftar di `izin.txt`)

### Instalasi

```bash
apt update && apt install -y wget curl
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

Atau one-liner:
```bash
wget -qO setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh && bash setup.sh
```

Installer akan:
1. ✅ Install dependencies (curl, jq, haproxy, xray)
2. ✅ Setup SSL certificate (certbot)
3. ✅ Configure 3 protocols dengan 9 inbounds
4. ✅ Prompt Telegram bot token & chat ID
5. ✅ Install systemd services (xray, telegram-bot, enforcement daemons)
6. ✅ Validate installation & display status

**Total waktu:** ~5-10 menit tergantung internet.

---

## 📱 Telegram Bot Setup

Bot menggunakan **long polling** (bukan webhook), jadi tidak perlu SSL/domain untuk bot.

### Dapatkan Token & Chat ID

1. **Bot Token**: Chat `/newbot` ke [@BotFather](https://t.me/BotFather)
2. **Chat ID**: Chat `/start` ke [@userinfobot](https://t.me/userinfobot)

### Menu Bot

**Protokol Management:**
- `VLESS` → Create trial/reguler, delete, renew, cek login, set limit IP/BW
- `VMESS` → Same as VLESS
- `TROJAN` → Same as VLESS

**System:**
- `CEK TRAFIK` → Traffic global semua user
- `BACKUP` → Backup config & database
- `INFO VPS` → CPU, RAM, disk usage

**Trial Account:**  
Format username `trial-xxxx` otomatis:
- Expired: 1 jam
- Quota: 1 GB
- Auto-delete saat expired/habis quota + notif Telegram

---

## 🔧 Command Line Management

### Menu Utama
```bash
menu              # Dashboard utama
m-ssh             # Kelola SSH accounts & tunnel (Edit Banner SSH: [11])
m-vless           # Kelola VLESS accounts
m-vmess           # Kelola VMESS accounts
m-trojan          # Kelola TROJAN accounts
m-setting         # System settings, update script, bot config, banner SSH: [10]
m-backup          # Backup/restore manual
menu-recovery     # Restore user dari recovery room
menu-lock         # Lock user manual
menu-unlock       # Unlock user manual
```

### Service Management
```bash
# Status check
systemctl status xray telegram-bot algojo-expired wibu-daemon

# Restart services
systemctl restart xray
systemctl restart telegram-bot

# View logs
journalctl -u telegram-bot -f
journalctl -u algojo-expired -f
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log
```

### File Locations
```
/etc/xray/
  ├── config.json           # Xray main config
  ├── domain                # Your domain
  ├── vless_exp.conf        # VLESS user expiry
  ├── vmess_exp.conf        # VMESS user expiry
  └── trojan_exp.conf       # TROJAN user expiry

/etc/wibutunnel/
  ├── bot.conf              # Telegram credentials (chmod 600)
  ├── lock.conf             # Auto-lock duration (default 15 min)
  ├── limit_ip.db           # IP limit per user
  ├── limit_bw.db           # Bandwidth limit per user (GB)
  ├── user_usage.db         # Bandwidth usage tracking
  ├── locked_users.db       # Currently locked users
  └── recovery/             # Recovery JSON sidecars

/usr/local/sbin/
  ├── algojo-wibu           # IP limit enforcement daemon
  ├── algojo-kuota          # Bandwidth limit enforcement daemon
  ├── algojo-expired        # Expiry check (one-shot)
  └── algojo-expired-daemon # Expiry enforcement daemon

/var/log/xray/
  ├── access.log            # Connection logs
  └── error.log             # Error logs
```

---

## 🛡️ Enforcement System

### Daemons

| Daemon | Fungsi | Interval | Action |
|--------|--------|----------|--------|
| `algojo-wibu` | IP limit check | 60s | Lock 15 min (auto-unlock) |
| `algojo-kuota` | Bandwidth limit | 60s | Delete + recovery (regular) atau delete permanen (trial) |
| `algojo-expired` | Expiry check | 5s | Delete + recovery (regular) atau delete permanen (trial) |
| `algojo-expired-daemon` | 5s real-time expiry sweep | 5s | Delete + recovery (regular) atau delete permanen (trial) |
| `ws-stunnel` | Python WebSocket SSH proxy | Real-time | Raw TCP proxy & HTTP split payload sanitizer ke Dropbear :109 |

### Behavior

**Regular Account:**
- IP overload → Lock 15 menit (configurable)
- Bandwidth habis → Move to recovery room
- Expired → Move to recovery room
- Recovery → Admin bisa restore dengan limit/expiry baru

**Trial Account:**
- IP overload → Lock 15 menit
- Bandwidth habis → Delete permanen + notif
- Expired → Delete permanen + notif
- No recovery

### Lock Duration

Edit `/etc/wibutunnel/lock.conf`:
```bash
LOCK_DURATION=15  # Dalam menit
```

Atau via menu:
```bash
m-setting → [9] Atur Durasi Lock Otomatis
```

---

## 🔄 Recovery System

User regular yang expired atau habis quota tidak langsung dihapus permanen, tapi masuk **recovery room**.

### Akses Recovery
```bash
menu-recovery              # CLI menu
# Atau dari Telegram bot → Protokol menu → Recovery
```

### Restore User
1. Pilih user dari list recovery
2. Input expiry baru (hari)
3. Input IP limit baru
4. Input bandwidth limit baru (GB, 0=unlimited)
5. User restored + detail akun dikirim ke Telegram

### Delete All Recovery
Input: `deleteallusers` di menu recovery → hapus semua user + reset bandwidth history.

---

## 🔄 Update Script

### Via Menu
```bash
m-setting → [5] Update Script
```

### Manual
```bash
cd /root/wibutunnel-repo
git pull origin main
bash setup.sh    # Re-run aman, tidak hapus data user
```

---

## 🗑️ Uninstall

```bash
cd /root/wibutunnel-repo
bash uninstall.sh
```

**Yang dihapus:**
- ✅ Xray, HAProxy, nginx
- ✅ Systemd services (xray, telegram-bot, algojo-*)
- ✅ Cron jobs
- ✅ User data & config

**Backup otomatis** disimpan di `/root/wibutunnel-backup-YYYYMMDD-HHMMSS/` sebelum uninstall.

---

## 📊 Network Configuration

### Ports

| Port | Protocol | Path | Transport |
|------|----------|------|-----------|
| 443 | VLESS | `/vless` | WS-TLS |
| 80 | VLESS | `/vless-ntls` | WS |
| 443 | VLESS | `vless` | gRPC-TLS |
| 443 | VMESS | `/vmess` | WS-TLS |
| 80 | VMESS | `/vmess-ntls` | WS |
| 443 | VMESS | `vmess` | gRPC-TLS |
| 443 | TROJAN | `/trojan` | WS-TLS |
| 443 | TROJAN | `trojan` | gRPC-TLS |
| 443 | Direct SSH | - | `SSH-` direct to Dropbear :143 |
| 80 | Direct SSH | - | `SSH-` direct to Dropbear :143 |
| 80/443 | SSH WS / Enhanced | `/` or split payload | ws-stunnel :10015 -> Dropbear :109 |
| 109 | Dropbear | - | Dropbear WS internal target |
| 143 | Dropbear | - | Dropbear Direct multiplexed target |
| 2222 | Dropbear | - | Dropbear loopback |

### Architecture

```
Internet → HAProxy (80/443)
            ├→ Xray inbound[1] VLESS WS-TLS :10086
            ├→ Xray inbound[2] VLESS WS-NTLS :10087
            ├→ Xray inbound[3] VLESS gRPC :10088
            ├→ Xray inbound[4] VMESS WS-TLS :10089
            ├→ Xray inbound[5] VMESS WS-NTLS :10090
            ├→ Xray inbound[6] VMESS gRPC :10091
            ├→ Xray inbound[7] TROJAN WS-TLS :10092
            ├→ Xray inbound[8] TROJAN gRPC :10093
            ├→ Direct SSH (`SSH-`) → Dropbear :143
            └→ SSH WS / Enhanced Split Payload (`/` or split) → ws-stunnel :10015 → Dropbear :109
```

---

## 🐛 Troubleshooting

### Bot tidak respon
```bash
# Check service
systemctl status telegram-bot

# View logs
journalctl -u telegram-bot --since "5 minutes ago"

# Check config
cat /etc/wibutunnel/bot.conf

# Test bot token
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq .
```

### User tidak bisa connect
```bash
# Check xray status
systemctl status xray

# Test config syntax
xray -test -config /etc/xray/config.json

# View error log
tail -50 /var/log/xray/error.log

# Check user exists
jq '.inbounds[1].settings.clients[]? | .email' /etc/xray/config.json
```

### IP limit tidak jalan
```bash
# Check log level (harus "info")
jq '.log.loglevel' /etc/xray/config.json

# Check access log ada connection records
tail -20 /var/log/xray/access.log | grep "accepted"

# Check daemon running
systemctl status wibu-daemon

# Manual test
bash /usr/local/sbin/algojo-wibu
```

### Trial tidak auto-delete
```bash
# Check daemon
systemctl status algojo-expired

# View daemon logs
journalctl -u algojo-expired --since "1 minute ago"

# Check expiry file format
cat /etc/xray/vless_exp.conf
# Format harus: username:YYYY-MM-DD HH:MM:SS

# Manual test
bash /usr/local/sbin/algojo-expired
```

---

## 📝 Changelog

### v4.0 KURUMI (2026-10-26) - Latest

**🐛 Critical Bug Fixes:**
- ✅ **Setup abort on download failure** - Installer sekarang abort jika file gagal download, tidak lanjut dengan state broken
- ✅ **Bot.conf creation** - Setup otomatis create `/etc/wibutunnel/bot.conf`, bot tidak crash on startup
- ✅ **Infinite expiry loop fix** - Recovery flag line tidak trigger expiry check berulang (guard `exp_str =~ ^[0-9]+$`)

**🎨 New Features:**
- ✅ **Recovery notification to Telegram** - User restored dari recovery auto kirim detail akun (link, expiry, config) ke Telegram
- ✅ **Customer-ready format** - Notifikasi recovery format lengkap seperti akun baru (ISP, City, semua link, quote footer)
- ✅ **AI Documentation** - `AI_DOCUMENTATION.md` comprehensive guide untuk AI assistants

**🔧 Improvements:**
- ✅ Syntax validation semua shell files (bash -n)
- ✅ Portability check (0 hardcoded uid/gid/domain)
- ✅ Security audit (BOT_TOKEN hanya ke api.telegram.org)

### v4.0 Previous Updates
- ✅ Fix repo drift `algojo-expired` (trial notif hilang di fresh install)
- ✅ Daemon `algojo-expired` kirim notif Telegram pas trial expire
- ✅ `uninstall.sh` stop semua service + backup file sebelum hapus
- ✅ `setup.sh` syntax-check script sebelum install
- ✅ Bot state file auto-clear setiap callback (fix stale command)
- ✅ Bot abort create/delete kalau `jq` edit config gagal
- ✅ Xray log level `"info"` (default dulu `"warning"` → IP tracking mati)

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork this repo
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

---

## 📄 License

MIT License - bebas pakai, modif, distribusi. 

**⚠️ Disclaimer:** Tidak ada garansi. Use at your own risk. Author tidak bertanggung jawab atas penyalahgunaan script ini.

---

## 💬 Support & Contact

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)
- 💬 **Telegram**: [@wibuvpn](https://t.me/wibuvpn)
- 📧 **Email**: wibuvpnstore@gmail.com

---

<div align="center">

### Made with 💜 by **WBVPN**

*"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya." - Haku*

⭐ Star this repo if you find it useful!

</div>
