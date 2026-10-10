<div align="center">

# 🚀 Wibutunnel v4.0 KURUMI

**Multi-protocol VPN tunneling system dengan Telegram bot integration**

[![GitHub](https://img.shields.io/badge/GitHub-WBVPN-blue?logo=github)](https://github.com/WBVPN/wibutunnel)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%2012%20|%20Ubuntu%2020.04+-orange.svg)]()
[![Xray](https://img.shields.io/badge/Powered%20by-Xray--core-blueviolet)](https://github.com/XTLS/Xray-core)
[![Tested](https://img.shields.io/badge/Tested-100%25-success.svg)]()

Xray-based VPN management panel yang mudah digunakan, dilengkapi monitoring otomatis, quota enforcement, dan remote control via Telegram bot.

**✨ NEW:** Bot Polling Mode • Manual Lock/Unlock • Username Uniqueness • 100% Tested

[Features](#-features) • [Installation](#-installation) • [What's New](#-whats-new) • [Bot Setup](#-telegram-bot-setup) • [Troubleshooting](#-troubleshooting)

</div>

---

## ⚡ Quick Start

```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

> **⏱️ Installation:** ~3 minutes | **📋 Requirements:** Debian 12 / Ubuntu 20.04+, 1GB RAM, Domain pointing to VPS | **🔒 License:** IP-based validation

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🔐 Multi-Protocol Support
- ✅ **VLESS** - TLS/XTLS, WebSocket, gRPC
- ✅ **VMess** - TLS, WebSocket  
- ✅ **Trojan** - TLS
- ✅ QR code generation

### 🤖 Telegram Bot
- 💬 Create/delete user via chat
- 📊 Real-time quota & traffic
- 🎛️ Remote server control
- 🔔 Auto notifications
- 📤 Backup to Telegram
- 🔒 **NEW:** Manual lock/unlock
- 🚀 **NEW:** Polling mode (stable)

</td>
<td width="50%">

### 📊 Smart Management
- 🚦 IP Limit Enforcement
- 💾 Bandwidth Quota
- 🔓 Auto-Unlock (scheduled)
- 📈 Real-time Traffic Monitor
- 🗑️ Auto-Cleanup expired users
- 🔐 **NEW:** Username uniqueness
- 💽 **NEW:** Bandwidth preserved

### 🛠️ System
- 🖥️ Interactive menu
- 💾 One-click backup/restore
- 🔒 Auto SSL renewal
- 🔄 Service auto-recovery
- ✅ **100% Tested** (19 reports)

</td>
</tr>
</table>

---

## 🆕 What's New (October 2026)

### Bot Polling Migration
- ✅ Webhook → Polling (more stable & reliable)
- ✅ No webhook config needed
- ✅ Auto-restart on failure
- 📄 [Docs](docs/BOT_WEBHOOK_TO_POLLING.md)

### Manual Lock/Unlock Feature
- 🔒 Lock user per protocol (VLESS/VMESS/TROJAN)
- 🔓 Unlock preserves bandwidth history
- 🛡️ Username uniqueness enforcement (cross-protocol)
- 🚫 Auto-unlock prevention for manual locks
- 📊 Bandwidth tracking continues during lock
- 📄 [Feature Docs](docs/MANUAL_LOCK_UNLOCK_FEATURE.md) | [Test Report](docs/testing-reports/manual_lock_unlock_testing.md)

### Testing & Quality Assurance
- ✅ VLESS Menu: 10/10 tests
- ✅ Settings Menu: 9/9 tests  
- ✅ Enforcement System: Verified
- ✅ Bot Cek Login: 100% accuracy (15 users)
- ✅ Manual Lock/Unlock: 6/6 tests
- 📁 [All Test Reports](docs/testing-reports/)

---

## 🚀 Installation

### Prerequisites
- Debian 12 / Ubuntu 20.04+
- Domain pointing to VPS IP
- Root access
- IP registered in license

### Install
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

Follow prompts → SSL auto-issued → Services configured → Done

### Access Menu
```bash
menu
```

---

## 🤖 Telegram Bot Setup

1. **Get Bot Token:** Chat [@BotFather](https://t.me/botfather) → `/newbot`
2. **Get Chat ID:** Chat [@userinfobot](https://t.me/userinfobot)
3. **Configure:** `menu → [4] Settings → [1] Change Bot Token`
4. **Test:** Open bot → `/start` → Menu appears

### Bot Features
- Create/delete/renew users
- Check online users
- Set IP & bandwidth limits
- **Lock/unlock users manually**
- View traffic stats
- Backup to Telegram
- Server monitoring

---

## 📖 Usage

### Main Menu
```bash
menu
```

### Create User
```bash
menu → [1] VLESS → [1] Create
# or via Telegram bot
```

### Manual Lock/Unlock
```
Telegram Bot → Protocol Menu → 🔒 Lock User
→ Enter username → Locked (bandwidth tracking continues)

→ 🔓 Unlock User → Username → Unlocked (history preserved)
```

### Backup/Restore
```bash
menu → [5] Backup & Restore → [1] Backup
# Encrypted ZIP sent to Telegram
```

---

## 🛡️ Security

### License Validation
- IP-based check via GitHub
- Validated on install & script execution
- Invalid IP/expired = access denied
- License file: [izin.txt](https://github.com/WBVPN/wibutunnel/blob/main/izin.txt)

### SSL Certificate
- Auto-issued via Let's Encrypt
- Auto-renewed via cron

---

## 📊 Monitoring

### Check Services
```bash
systemctl status xray haproxy telegram-bot-polling
```

### View Logs
```bash
tail -f /var/log/xray/access.log
tail -f /var/log/telegram-bot.log
journalctl -u xray -f
```

---

## 🔄 Updates

```bash
menu → [6] Update Script
# Safe mode: auto-backup, pulls latest from GitHub
```

---

## 🗑️ Uninstall

```bash
cd /root/wibutunnel
bash uninstall-complete.sh
# Complete removal → VPS returns to fresh state
```

---

## 🐛 Troubleshooting

### Bot Not Responding
```bash
systemctl status telegram-bot-polling
systemctl restart telegram-bot-polling
tail -f /var/log/telegram-bot-error.log
```

### Xray Not Starting
```bash
/usr/local/bin/xray -test -config /usr/local/etc/xray/config.json
journalctl -u xray -n 50
systemctl restart xray
```

### License Rejected
```bash
# Check current IP
curl ipv4.icanhazip.com

# Check license
curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt | grep "$(curl -s ipv4.icanhazip.com)"

# Contact admin for registration
```

---

## 📋 FAQ

**Q: Apakah gratis?**  
A: Ya, open source. Butuh IP terdaftar di license.

**Q: Support OS?**  
A: Debian 12, Ubuntu 20.04+ (tested).

**Q: Domain berbayar?**  
A: Bisa subdomain gratis (FreeDNS, DuckDNS).

**Q: User maksimal?**  
A: 1GB RAM → ~50-100 users.

**Q: Polling vs Webhook?**  
A: Polling (current) lebih stable.

**Q: Bandwidth saat locked?**  
A: Tracking continues, preserved after unlock.

---

## 📜 Changelog

### v4.0 KURUMI (October 2026)
- ✅ Bot Polling Migration (webhook → polling)
- ✅ Manual Lock/Unlock per protocol
- ✅ Username uniqueness (cross-protocol)
- ✅ Testing suite (19 reports, 100% pass)
- ✅ Bot Cek Login accuracy (100% verified)

### v4.0 Initial
- Multi-protocol (VLESS, VMess, Trojan)
- Telegram bot integration
- IP & bandwidth enforcement
- Auto backup/restore
- SSL auto-renewal

---

## 🤝 Contributing

```bash
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel
# Edit, test, commit
```

All features must pass testing before merge. See [testing reports](docs/testing-reports/).

---

## 📜 License

MIT License - free for personal & commercial use.

---

## 🙏 Credits

- **Xray-core** - https://github.com/XTLS/Xray-core
- **HAProxy** - https://www.haproxy.org/
- **Let's Encrypt** - https://letsencrypt.org/

---

## 📞 Support

- 🐛 **Issues:** https://github.com/WBVPN/wibutunnel/issues
- 💬 **Discussions:** https://github.com/WBVPN/wibutunnel/discussions
- 📧 **Email:** wibuvpnstore@gmail.com
- 📁 **Test Reports:** [docs/testing-reports/](docs/testing-reports/)

---

<p align="center">
  <strong>Made with ❤️ by WBVPN Team</strong><br>
  <a href="https://github.com/WBVPN/wibutunnel">⭐ Star us on GitHub!</a>
</p>
