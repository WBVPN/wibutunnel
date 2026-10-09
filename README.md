<div align="center">

# 🚀 Wibutunnel v4.0 KURUMI

**Multi-protocol VPN tunneling system dengan Telegram bot integration**

[![GitHub](https://img.shields.io/badge/GitHub-WBVPN-blue?logo=github)](https://github.com/WBVPN/wibutunnel)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%2012%20|%20Ubuntu%2020.04+-orange.svg)]()
[![Xray](https://img.shields.io/badge/Powered%20by-Xray--core-blueviolet)](https://github.com/XTLS/Xray-core)

Xray-based VPN management panel yang mudah digunakan, dilengkapi monitoring otomatis, quota enforcement, dan remote control via Telegram bot.

[Features](#-features) • [Installation](#-installation) • [Telegram Bot](#-telegram-bot-setup) • [Troubleshooting](#-troubleshooting) • [Uninstall](#-uninstallation)

</div>

---

## ⚡ Quick Start

### Option 1: wget (Recommended)
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

### Option 2: curl
```bash
curl -O https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

### Option 3: One-liner (Advanced)
```bash
# wget
wget -qO- https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash

# curl
curl -sSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash
```

> **⏱️ Installation time:** ~3 minutes  
> **📋 Requirements:** Debian 12 / Ubuntu 20.04+, 1GB RAM, Domain pointing to server IP

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🔐 Multi-Protocol Support
- ✅ **VLESS** - TLS/XTLS, WebSocket, gRPC
- ✅ **VMess** - TLS, WebSocket  
- ✅ **Trojan** - TLS
- ✅ Zero-config client templates
- ✅ QR code generation

### 🤖 Telegram Bot Integration
- 💬 Create/delete user via chat
- 📊 Check quota & traffic real-time
- 🎛️ Remote server management
- 🔔 Auto-notification system
- 📤 One-click backup to Telegram

</td>
<td width="50%">

### 📊 Smart Management
- 🚦 **IP Limit Enforcement** - Max connections per user
- 💾 **Bandwidth Quota** - Auto-lock when quota exceeded
- 🔓 **Auto-Unlock** - Scheduled unlock for expired locks
- 📈 **Traffic Monitoring** - Real-time bandwidth tracking
- 🗑️ **Auto-Cleanup** - Remove expired accounts

### 🛠️ System Features
- 🖥️ Interactive menu system
- 💾 One-click backup/restore
- 🔒 Auto SSL renewal (Let's Encrypt)
- 🔄 Service auto-recovery
- ⏰ Scheduled auto-reboot

</td>
</tr>
</table>

---

## 📦 What's Included

<div align="center">

| Component | Description | Status |
|-----------|-------------|--------|
| **Xray-core** | Core VPN protocol handler | ✅ Auto-installed |
| **HAProxy** | Load balancer + SSL terminator | ✅ Auto-configured |
| **Dropbear** | Lightweight SSH server (port 109) | ✅ Optional |
| **Telegram Bot** | Remote management interface | ✅ Optional |
| **Auto Enforcer** | Quota & IP limit daemon | ✅ Cron scheduled |
| **Let's Encrypt** | Free SSL certificates | ✅ Auto-renewal |

</div>

---

## 🎯 Installation

<details open>
<summary><b>📋 Pre-Installation Checklist</b></summary>

- ✅ VPS dengan Debian 12 / Ubuntu 20.04+
- ✅ Minimum 1GB RAM (2GB recommended)
- ✅ Root access ke server
- ✅ Domain atau subdomain (DNS sudah pointing ke server IP)
- ✅ Port 80 dan 443 tidak digunakan service lain

</details>

### Step 1: Prepare Domain

Point your domain A record to your VPS IP:

```dns
A    vpn.yourdomain.com    →    123.45.67.89
```

**Verify DNS:**
```bash
ping vpn.yourdomain.com
# Should return your VPS IP
```

### Step 2: Run Installer

**Choose your method:**

<table>
<tr>
<td width="50%">

**🔹 Method 1: wget (Recommended)**
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

</td>
<td width="50%">

**🔹 Method 2: curl**
```bash
curl -O https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

</td>
</tr>
</table>

**One-liner (Advanced):**
```bash
# wget version
wget -qO- https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash

# curl version
curl -sSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash
```

### Step 3: Installation Process

Installer will automatically:

1. ✅ Update system packages
2. ✅ Install Xray, HAProxy, Dropbear
3. ✅ Setup SSL certificate (Let's Encrypt)
4. ✅ Configure firewall rules
5. ✅ Setup Telegram bot (if credentials provided)
6. ✅ Create management menu
7. ✅ Schedule auto-backup & auto-reboot

> ⏱️ **Duration:** ~3 minutes on 1Gbps connection

### Step 4: Access Menu

```bash
menu
```

<div align="center">

**🎉 Installation Complete!**

</div>

---

## 🖥️ Menu Overview

<div align="center">

```
══════════════════════════════════════════════════
           WIBU TUNNELING v4.0 KURUMI
══════════════════════════════════════════════════
  Bot Telegram : ✅ Aktif (@wibutunnelbot)
  Auto Reboot  : ✅ 05:00 WIB
  Auto Backup  : ✅ 03:00 WIB
══════════════════════════════════════════════════

 [🔵 1] VLESS Management      → Create/delete VLESS users
 [🔵 2] VMess Management      → Create/delete VMess users  
 [🔵 3] Trojan Management     → Create/delete Trojan users
 
 [🟡 4] User Lock/Unlock      → Manual lock control
 [🟡 5] Backup & Restore      → Telegram backup system
 
 [🟢 6] Settings & Monitor    → System configuration
 [🟢 7] Traffic Monitor       → Real-time bandwidth stats
 [🟢 8] Check Expired Users   → Auto-cleanup expired accounts
 
 [🔴 0] Exit

══════════════════════════════════════════════════
```

</div>

---

## 📱 Telegram Bot Setup

<table>
<tr>
<td width="33%">

### 1️⃣ Get Bot Token
1. Chat dengan [@BotFather](https://t.me/BotFather)
2. Kirim `/newbot`
3. Ikuti instruksi
4. Save token:
```
123456789:ABCdefGhi...
```

</td>
<td width="33%">

### 2️⃣ Get Chat ID
1. Chat dengan [@userinfobot](https://t.me/userinfobot)
2. Bot reply dengan ID:
```
5851934765
```

</td>
<td width="34%">

### 3️⃣ Configure Bot
```bash
menu
↓
[6] Settings
↓
[6] Setup Bot
```
Input token & chat ID

</td>
</tr>
</table>

### 🤖 Bot Commands

<div align="center">

| Command | Description |
|---------|-------------|
| `/start` | Show main menu |
| `/create` | Create new user |
| `/delete` | Delete existing user |
| `/check` | Check user quota & traffic |
| `/list` | List all active users |
| `/backup` | Create backup to Telegram |
| `/restore` | Restore from backup |
| `/status` | Show server status |

</div>

> 💡 **Tip:** Bot commands juga bisa diakses via inline buttons untuk kemudahan.

---

## 🔧 Common Tasks

<details>
<summary><b>👤 Create User</b></summary>

```bash
menu → [1] VLESS Management → [1] Create User
```

**Input required:**
- Username: `john_doe`
- Expiry: `30` (days)
- IP Limit: `2` (max concurrent connections)
- Quota: `50` (GB)

**Output:** QR code + connection link generated

</details>

<details>
<summary><b>📊 Check Traffic</b></summary>

```bash
menu → [7] Traffic Monitor
```

**Shows:**
- ⚡ Real-time: Download/upload speed
- 📈 Total: Bandwidth since boot
- 👥 Per-user: Individual usage stats

</details>

<details>
<summary><b>💾 Backup to Telegram</b></summary>

```bash
menu → [5] Backup & Restore → [1] Backup Manual
```

**Process:**
1. Creates encrypted ZIP
2. Uploads to Telegram chat
3. Returns File ID for restore

**Included:** Xray configs, user database, bot config, SSL certs

</details>

<details>
<summary><b>🔄 Restore from Backup</b></summary>

```bash
menu → [5] Backup & Restore → [2] Restore Data
```

**Input options:**
- 📁 Telegram File ID: `BQACAgUAAxkDAAIDzGrIV...`
- 🔗 Telegram URL: `https://t.me/c/.../123`
- 💾 Local path: `/root/backup.zip`

**Auto-rollback on failure**

</details>

<details>
<summary><b>🔄 Update Scripts</b></summary>

```bash
menu → [6] Settings → [5] Update Script (Safe Mode)
```

**Process:**
1. Backup current scripts to `/root/script_backup_*`
2. Pull latest from GitHub
3. Verify syntax
4. Restart services

**Rollback available** if update fails

</details>

---

## 📊 System Architecture

```
Internet
   ↓
HAProxy (Port 80/443)
   ↓
Xray (Multi-protocol)
   ↓
User Connections
   ↓
Algojo (Enforcer) → Monitor IP/Quota → Auto-lock
```

**Auto Enforcement:**
- `algojo-wibu` runs every 2 min → check IP limit
- `algojo-kuota` runs every 5 min → check quota
- `unlocker-wibu` runs every 15 min → unlock expired locks

---

## 🗂️ File Structure

```
/usr/local/etc/xray/
├── config.json              # Xray main config
├── vless_exp.conf          # VLESS user database
├── vmess_exp.conf          # VMess user database
└── trojan_exp.conf         # Trojan user database

/etc/wibutunnel/
├── bot.conf                # Telegram credentials (chmod 600)
├── lock.conf               # Lock duration config
├── limit_ip.db             # IP limit database
├── limit_bw.db             # Bandwidth quota database
├── locked_users.db         # Locked users list
└── user_usage.db           # Traffic usage tracking

/usr/local/bin/
├── menu                    # Main menu
├── m-vless, m-vmess, m-trojan  # Protocol menus
├── m-setting               # Settings menu
├── m-backup                # Backup/restore menu
├── menu-lock, menu-unlock  # Lock management
└── cek-trafik              # Traffic monitor

/usr/local/sbin/
├── algojo-wibu             # IP enforcer (cron: */2 * * * *)
├── algojo-kuota            # Quota enforcer (cron: */5 * * * *)
└── unlocker-wibu           # Auto-unlock (cron: */15 * * * *)
```

---

## 🔒 Security Features

### Built-in Protection
- ✅ **Command injection prevention** - Input validation with regex
- ✅ **Path traversal protection** - Zip content verification
- ✅ **Credential encryption** - Bot token chmod 600
- ✅ **SSL/TLS enforcement** - Let's Encrypt auto-renewal
- ✅ **Rate limiting** - IP connection limits
- ✅ **Audit logging** - All actions logged

### Best Practices
```bash
# 1. Change default SSH port
nano /etc/ssh/sshd_config  # Port 22 → 2222
systemctl restart sshd

# 2. Setup UFW firewall
ufw allow 80,443,109,2222/tcp
ufw enable

# 3. Enable automatic updates
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades

# 4. Backup regularly (auto-scheduled)
# Already configured: daily backup at 3:00 AM WIB
```

---

## 🛠️ Troubleshooting

### Service Not Running
```bash
systemctl status xray haproxy dropbear
systemctl restart xray haproxy  # Restart services
journalctl -u xray -n 50        # Check logs
```

### User Cannot Connect
```bash
# Check if user locked
cat /etc/wibutunnel/locked_users.db | grep username

# Check quota
cat /etc/wibutunnel/limit_bw.db | grep username

# Check Xray logs
tail -f /var/log/xray/access.log
```

### Domain Not Working
```bash
# Verify DNS resolution
nslookup yourdomain.com

# Check SSL certificate
certbot certificates

# Renew SSL manually
systemctl stop haproxy
certbot renew --force-renewal
systemctl start haproxy
```

### Bot Not Responding
```bash
# Check bot config
cat /etc/wibutunnel/bot.conf

# Test bot API
BOT_TOKEN="your_token"
curl "https://api.telegram.org/bot${BOT_TOKEN}/getMe"

# Restart bot webhook
systemctl restart telegram-webhook.socket
systemctl status telegram-webhook.socket
```

### Menu Not Loading
```bash
# Update scripts
cd /tmp
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/menu/menu.sh
mv menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu
```

---

## 🗑️ Uninstallation

### Complete Removal (VPS kembali seperti fresh install)
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall-complete.sh
bash uninstall-complete.sh
# Type: YES
# reboot
```

**This will remove:**
- ❌ All services (xray, haproxy, dropbear, telegram-bot)
- ❌ All configs & databases
- ❌ SSL certificates
- ❌ All cron jobs (with backup to /tmp)
- ❌ Installed packages (xray, haproxy, certbot, vnstat)
- ❌ Source files & backups

### Partial Removal (Keep packages)
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh
bash uninstall.sh
```

⚠️ **Backup first:** `menu → [5] Backup & Restore → [1] Backup Manual`

---

## 📈 Performance Tips

### Optimize Xray
```bash
# Edit /usr/local/etc/xray/config.json
"policy": {
  "levels": {
    "0": {
      "handshake": 4,
      "connIdle": 300,
      "uplinkOnly": 2,
      "downlinkOnly": 5
    }
  }
}
```

### Monitor Resources
```bash
# CPU/RAM usage
htop

# Network bandwidth
menu → [6] Settings → [4] Cek Bandwidth VPS

# Disk space
df -h
```

### Database Maintenance
```bash
# Clean expired users (auto-runs daily)
/usr/local/bin/xp

# Manual cleanup
menu → [8] Check Expired Users
```

---

## 🔄 Updates

**Auto-update from menu:**
```bash
menu → [6] Settings → [5] Update Script (Safe Mode)
# Pulls latest from GitHub
# Creates backup: /root/script_backup_*
```

**Manual update:**
```bash
cd /tmp
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel
bash setup.sh  # Re-run installer (safe, keeps configs)
```

---

## 📋 FAQ

**Q: Apakah gratis?**  
A: Ya, open source dan gratis selamanya.

**Q: Support OS apa saja?**  
A: Debian 12 (Bookworm) dan Ubuntu 20.04+ (tested).

**Q: Butuh domain berbayar?**  
A: Bisa pakai subdomain gratis (FreeDNS, DuckDNS, dll).

**Q: Berapa user maksimal?**  
A: Tergantung RAM VPS. 1GB RAM → ~50-100 users.

**Q: Bisa multi-server?**  
A: Ya, install di masing-masing VPS dengan bot yang sama.

**Q: Backup otomatis kemana?**  
A: Telegram chat (encrypted ZIP), scheduled daily 3AM.

**Q: Uninstall bersih 100%?**  
A: Ya, gunakan `uninstall-complete.sh` → VPS kembali fresh.

---

## 🤝 Contributing

Contributions welcome! Fork repo ini dan submit pull request.

**Development:**
```bash
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel
# Edit scripts
bash -n menu/menu.sh  # Syntax check
# Test on VPS
git commit -m "fix: your changes"
git push
```

---

## 📜 License

MIT License - bebas digunakan untuk personal maupun komersial.

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

---

<p align="center">
  <strong>Made with ❤️ by WBVPN Team</strong>
</p>

<p align="center">
  <a href="https://github.com/WBVPN/wibutunnel">⭐ Star us on GitHub!</a>
</p>
