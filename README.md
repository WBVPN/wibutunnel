# 🦋 WIBUTUNNEL v4.0.6 KURUMI

Auto-install VPN panel berbasis Xray dengan Telegram bot monitoring. Satu command, VPN langsung jalan.

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)](https://github.com/WBVPN/wibutunnel)
[![Version](https://img.shields.io/badge/Version-v4.0.6%20KURUMI-blue.svg)](https://github.com/WBVPN/wibutunnel)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)](https://github.com/WBVPN/wibutunnel)

---

## ✨ Fitur

- 🔐 **VLESS, VMESS, TROJAN, SSH** - 3 protokol VPN + SSH tunnel (Dropbear, WebSocket, Direct 80/443, Split Payload)
- 🛠️ **Auto-Repair** - Self-healing stack: basmi parasit port 80/443, fix SSL HAProxy, validasi Xray JSON, regenerate SSH keys
- ⚡ **Zero-Downtime Sync** - Tambah/hapus user live via gRPC API tanpa restart Xray
- 🤖 **Telegram Bot** - Kelola akun, lock/unlock, backup dari HP
- 🎯 **Auto Enforcement** - Kuota/expired = lock otomatis + notif real-time
- 🔄 **Recovery System** - User expired disimpan, bisa restore dengan limit baru

---

## 🚀 Instalasi

### Prerequisites
- Ubuntu 20.04+ / Debian 11+
- Domain dengan A record ke IP VPS
- Root access
- IP VPS terdaftar di `izin.txt` (hubungi @wibuvpn)

### One-Liner
```bash
wget -qO setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh && bash setup.sh
```

**Proses:** Install dependencies → SSL cert → Xray config → Telegram bot → Services. Waktu: ~5-10 menit.

---

## 📱 Telegram Bot

Bot pakai **long polling** (tidak perlu SSL/domain).

**Dapatkan Credentials:**
1. Token: Chat `/newbot` ke [@BotFather](https://t.me/BotFather)
2. Chat ID: Chat `/start` ke [@userinfobot](https://t.me/userinfobot)

**Menu:** VLESS/VMESS/TROJAN (create, delete, renew, cek login, limit IP/BW), CEK TRAFIK, BACKUP, INFO VPS.

**Trial Account:** Format `trial-xxxx`, expired 1 jam, quota 1GB, auto-delete permanen.

---

## 🔧 Command Line

### Menu Utama
```bash
menu              # Dashboard & status stack
m-vless           # Kelola VLESS
m-vmess           # Kelola VMESS
m-trojan          # Kelola TROJAN
m-ssh             # Kelola SSH (Edit Banner: [12], Respon WS: [13])
m-setting         # Settings (Auto-repair: [1], Update: [5])
menu-recovery     # Restore user dari recovery
wibu-repair       # Diagnostic & repair stack
```

### Service
```bash
systemctl status xray telegram-bot algojo-expired wibu-daemon
journalctl -u telegram-bot -f
tail -f /var/log/xray/access.log
```

### File Penting
```
/etc/xray/config.json               # Xray config
/etc/xray/{vless,vmess,trojan,ssh}_exp.conf   # User expiry
/etc/wibutunnel/bot.conf            # Telegram credentials
/etc/wibutunnel/limit_ip.db         # IP limit (sesi simultan)
/etc/wibutunnel/limit_bw.db         # Bandwidth limit (GB)
/etc/wibutunnel/locked_users.db     # Locked users
/etc/wibutunnel/recovery/           # Recovery JSON
/usr/local/sbin/algojo-*            # Enforcement daemons
/usr/local/sbin/wibu-repair         # Auto-repair engine
```

---

## 🛡️ Enforcement

| Daemon | Fungsi | Interval | Action |
|--------|--------|----------|--------|
| `algojo-ssh` | SSH session limit | 60s | Lock 15 min auto-unlock |
| `algojo-wibu` | IP limit (Xray) | 60s | Lock 15 min auto-unlock |
| `algojo-kuota` | Bandwidth limit | 60s | Delete + recovery (regular) / delete (trial) |
| `algojo-expired` | Expiry check | 5s | Delete + recovery (regular) / delete (trial) |

**Regular:** Lock temporary, recovery room saat expired/habis quota.  
**Trial:** Delete permanen, no recovery.

---

## 🔄 Recovery

User regular expired/habis quota masuk recovery room, bisa restore:
```bash
menu-recovery     # CLI
# Atau: Telegram bot → Protokol → Recovery
```
Input expiry baru, IP limit, bandwidth → restored + notif Telegram.

---

## 🔄 Update

```bash
m-setting → [5] Update Script
# Atau manual:
cd /root/wibutunnel-repo && git pull origin main && bash setup.sh
```

---

## 🗑️ Uninstall

```bash
curl -sS -L https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh | bash
```
Backup otomatis ke `/root/wibutunnel-backup-YYYYMMDD-HHMMSS/` sebelum hapus.

---

## 📊 Network

### Ports

| Port | Protocol | Path | Backend |
|------|----------|------|---------|
| 443/80 | VLESS | `/vless` | WS-TLS/WS |
| 443 | VLESS | `vless` | gRPC-TLS |
| 443/80 | VMESS | `/vmess` | WS-TLS/WS |
| 443 | VMESS | `vmess` | gRPC-TLS |
| 443 | TROJAN | `/trojan` | WS-TLS |
| 443 | TROJAN | `trojan` | gRPC-TLS |
| 443/80 | SSH Direct | `SSH-` | Dropbear :143 |
| 443/80 | SSH WS | `/` | ws-stunnel :10015 → Dropbear :109 |

### Architecture
```
Internet → HAProxy (80/443)
            ├→ Xray :10086-10093 (9 inbounds)
            ├→ Dropbear :143 (Direct SSH)
            └→ ws-stunnel :10015 → Dropbear :109 (SSH WS)
```

---

## 🐛 Troubleshooting

### Auto-Repair
```bash
wibu-repair
# Atau: m-setting → [1]
```
Fix: Port parasit, SSL HAProxy, Xray JSON corrupt, SSH keys, service restart.

### Manual Debug

**Bot tidak respon:**
```bash
systemctl status telegram-bot
journalctl -u telegram-bot --since "5 minutes ago"
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq .
```

**User tidak bisa connect:**
```bash
systemctl status xray
xray -test -config /etc/xray/config.json
tail -50 /var/log/xray/error.log
jq '.inbounds[1].settings.clients[]? | .email' /etc/xray/config.json
```

**IP limit tidak jalan:**
```bash
jq '.log.loglevel' /etc/xray/config.json  # Harus "info"
tail -20 /var/log/xray/access.log | grep "accepted"
systemctl status wibu-daemon
```

**Trial tidak auto-delete:**
```bash
systemctl status algojo-expired
journalctl -u algojo-expired --since "1 minute ago"
cat /etc/xray/vless_exp.conf  # Format: username:YYYY-MM-DD HH:MM:SS
```

---

## 📝 Changelog

### v4.0.6 KURUMI (2026-11-02) - Production Ready

**🛠️ Auto-Repair & Diagnostic:**
- Self-healing stack: port parasit, SSL HAProxy, Xray JSON, SSH keys
- Anti-wipe safety guard: validasi backup ketat
- Dynamic HAProxy template (`${__DOMAIN__}`)

**⚡ Zero-Downtime & Enforcement:**
- User sync live via gRPC API (`127.0.0.1:10085`)
- Atomic DB locking (`flock -w 10`)
- Enforcement harmonization: reguler → recovery, trial → purge
- Auto-restore unlock dari sidecar JSON

**🔒 SSH Module:**
- Dropbear (109, 143, 2222), ws-stunnel (10015), HAProxy multiplexer (80/443)
- Enhanced split-payload (`HTTP/ 69`)
- SSH session enforcement (akurat untuk relay loopback)
- Strict license validation

**📊 Dashboard:**
- Multi-service live monitor (`Online` / `Degraded`)
- Clean SSH menu (hapus opsi usang)
- 11 test suites automated

**🐛 Critical Fixes:**
- SSH-1: Parsing `ss` benar ($3/$5, PID via ps, filter dropbear|sshd)
- SSH-2: Metrik sesi aktif (bukan IP unik, akurat untuk relay 127.0.0.1)
- SSH-3: Oktal guard `10#` (08/09/010)
- SSH-4: Menu Cek Login SSH [9] pakai `ssh_session_count`
- REG-SSH: Auto-unlock regression (field3 timestamp > 0, bukan 0 permanen)

---

## 🤝 Contributing

Fork → Branch → Commit → Push → Pull Request

---

## 📄 License

MIT License - bebas pakai, modif, distribusi.  
**Disclaimer:** No warranty. Use at your own risk.

---

## 💬 Support

- 🐛 Issues: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)
- 💬 Telegram: [@wibuvpn](https://t.me/wibuvpn)
- 📧 Email: wibuvpnstore@gmail.com

---

<div align="center">

**Made with 💜 by WBVPN**

*"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya." - Haku*

⭐ Star this repo if you find it useful!

</div>
