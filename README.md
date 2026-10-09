# 🚀 Wibutunnel v4.0 KURUMI

**Multi-protocol VPN tunneling system dengan Telegram bot integration**

Xray-based VPN management panel yang mudah digunakan, dilengkapi monitoring otomatis, quota enforcement, dan remote control via Telegram bot.

---

## ⚡ Quick Start

```bash
# Install (3 menit)
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

**Requirements:** Debian 12 / Ubuntu 20.04+, 1GB RAM, Domain pointing ke server IP

---

## ✨ Features

### 🔐 Multi-Protocol Support
- **VLESS** - TLS/XTLS, WebSocket, gRPC
- **VMess** - TLS, WebSocket  
- **Trojan** - TLS

### 🤖 Telegram Bot Integration
- Create/delete user via chat
- Check quota & traffic real-time
- Remote server management
- Auto-notification system

### 📊 Smart Management
- **IP Limit Enforcement** - Max connections per user
- **Bandwidth Quota** - Auto-lock when quota exceeded
- **Auto-Unlock** - Scheduled unlock for expired locks
- **Traffic Monitoring** - Real-time bandwidth tracking

### 🛠️ System Features
- Interactive menu system
- One-click backup/restore
- Auto SSL renewal (Let's Encrypt)
- Service auto-recovery
- Scheduled auto-reboot

---

## 📦 What's Included

| Component | Description |
|-----------|-------------|
| **Xray** | Core VPN protocol handler |
| **HAProxy** | Load balancer + SSL terminator |
| **Dropbear** | Lightweight SSH server (port 109) |
| **Telegram Bot** | Remote management interface |
| **Auto Enforcer** | Quota & IP limit daemon |

---

## 🎯 Installation

### Step 1: Prepare Domain
Point your domain A record to your VPS IP:
```
A    aku.yourdomain.com    →    123.45.67.89
```

### Step 2: Run Installer
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

**Installation will:**
1. ✅ Install Xray, HAProxy, Dropbear
2. ✅ Setup SSL certificate (Let's Encrypt)
3. ✅ Configure firewall rules
4. ✅ Setup Telegram bot (optional)
5. ✅ Create management menu

**Duration:** ~3 minutes

### Step 3: Access Menu
```bash
menu
```

---

## 🖥️ Menu Overview

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
           WIBU TUNNELING v4.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] VLESS Management      → Create/delete VLESS users
[2] VMess Management      → Create/delete VMess users  
[3] Trojan Management     → Create/delete Trojan users
[4] User Lock/Unlock      → Manual lock control
[5] Backup & Restore      → Telegram backup system
[6] Settings & Monitor    → System configuration
[7] Traffic Monitor       → Real-time bandwidth stats
[8] Check Expired Users   → Auto-cleanup expired accounts
```

---

## 📱 Telegram Bot Setup

### Get Bot Token
1. Chat dengan [@BotFather](https://t.me/BotFather) di Telegram
2. Kirim `/newbot` dan ikuti instruksi
3. Save bot token: `123456789:ABCdefGhIjKlmNoPqRsTuVwXyZ`

### Get Chat ID
1. Chat dengan [@userinfobot](https://t.me/userinfobot)
2. Bot akan reply dengan ID: `5851934765`

### Configure Bot
```bash
menu → [6] Settings → [6] Setup Bot Telegram
# Input bot token & chat ID
```

### Bot Commands
```
/start       → Show menu
/create      → Create new user
/delete      → Delete user
/check       → Check user quota
/list        → List all users
/backup      → Create backup
/restore     → Restore from backup
```

---

## 🔧 Common Tasks

### Create User
```bash
menu → [1] VLESS Management → [1] Create User
# Input: username, days, IP limit, quota (GB)
```

### Check Traffic
```bash
menu → [7] Traffic Monitor
# Real-time: download/upload speed
# Total: bandwidth since boot
```

### Backup to Telegram
```bash
menu → [5] Backup & Restore → [1] Backup Manual
# ZIP file sent to Telegram with File ID
```

### Restore from Backup
```bash
menu → [5] Backup & Restore → [2] Restore Data
# Input: Telegram File ID / URL / Local path
```

### Update Scripts
```bash
menu → [6] Settings → [5] Update Script (Safe Mode)
# Pull latest from GitHub, auto-backup old version
```

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
