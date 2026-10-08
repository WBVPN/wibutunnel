# 🚀 Wibutunnel v4.0 - Xray VPN Management System

<p align="center">
  <strong>Multi-protocol VPN tunneling system dengan monitoring otomatis dan quota enforcement</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#usage">Usage</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

## ✨ Features

- 🔐 **Multi-Protocol Support**: VLESS, VMess, Trojan
- 📊 **Automatic Monitoring**: Real-time service health checks
- 💾 **Quota Management**: Bandwidth limit enforcement per user
- 🛡️ **IP Enforcement**: Connection limit per user IP
- 🔄 **Auto-Recovery**: Automatic service restart on failure
- 📱 **Telegram Bot**: Remote management via Telegram
- 🌐 **HAProxy Integration**: Load balancing and SSL termination
- 🔧 **User-Friendly Menu**: Interactive management interface

---

## 📋 Requirements

### VPS Requirements
- **OS**: Debian 12 (Bookworm) or Ubuntu 20.04+
- **RAM**: Minimum 512 MB (1GB+ recommended)
- **CPU**: 1 core minimum
- **Storage**: 10 GB+ free space
- **Network**: Public IPv4 address
- **Access**: Root privileges

### Domain Requirements
- Valid domain or subdomain
- DNS A record pointing to your server IP
- Must resolve before installation

### Required Ports
| Port | Service | Protocol |
|------|---------|----------|
| 80   | HAProxy | HTTP     |
| 443  | HAProxy | HTTPS    |
| 109  | Dropbear| SSH      |

---

## 🚀 Installation

### Quick Install (One Command)
```bash
curl -fsSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh | bash
```

### Manual Installation
```bash
wget https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
chmod +x setup.sh
./setup.sh
```

### What Happens During Installation?

The installer automatically:

1. ✅ Checks system requirements and compatibility
2. 📦 Installs dependencies (xray, haproxy, jq, curl, dos2unix)
3. ⚙️ Configures core services (xray, haproxy)
4. 🌐 Sets up domain and generates SSL certificates
5. 🤖 Configures Telegram bot integration (optional)
6. 📊 Enables automatic monitoring and enforcement
7. 🔄 Schedules cron jobs for auto-recovery

**Installation Time**: Approximately 5-10 minutes

**During installation you will be prompted for:**
- Domain name (e.g., vpn.yourdomain.com)
- Telegram bot token (optional, can be configured later)

---

## ✅ Post-Installation Verification

After installation completes, verify all services are running:

```bash
# Check service status
systemctl status xray haproxy dropbear

# Or use individual checks
systemctl is-active xray      # Should output: active
systemctl is-active haproxy   # Should output: active
systemctl is-active dropbear  # Should output: active
```

### Verify Ports
```bash
# Check if services are listening on required ports
ss -tulpn | grep -E ':(80|443|109)'
# Should show haproxy on 80, 443 and dropbear on 109
```

---

## 🎯 Access Management Menu

Access the interactive management interface:

```bash
menu
```

**Menu Options:**
- **[1] Menu VLESS**: Manage VLESS protocol users
- **[2] Menu VMESS**: Manage VMess protocol users
- **[3] Menu TROJAN**: Manage Trojan protocol users
- **[4] Setting Server**: Server configuration and bot setup
- **[5] Backup & Restore**: Data backup and recovery tools
- **[0] Exit**: Exit menu system

---

## 🔧 Service Management

### Check Service Status
```bash
# Check all services
systemctl status xray haproxy dropbear

# Restart specific service
systemctl restart xray
systemctl restart haproxy
```

### View Service Logs
```bash
# Xray logs
journalctl -u xray -f

# HAProxy logs
journalctl -u haproxy -f

# View last 50 lines
journalctl -u xray -n 50
```

### Manual Service Control
```bash
# Start services
systemctl start xray
systemctl start haproxy

# Stop services
systemctl stop xray
systemctl stop haproxy

# Enable autostart on boot
systemctl enable xray
systemctl enable haproxy
```

---

## 👥 User Management

### Create New User

Use the interactive menu system:

```bash
menu
# Select protocol menu (1/2/3)
# Choose "Add User" option
# Enter username, expiry date, IP limit, quota
```

### Delete User
```bash
menu
# Select protocol menu (1/2/3)
# Choose "Delete User" option
# Select user from list
```

### Renew User
```bash
menu
# Select protocol menu (1/2/3)
# Choose "Renew User" option
# Select user and enter new expiry date
```

### Lock/Unlock User
```bash
menu
# Select "Setting Server" (option 4)
# Choose lock/unlock user options
```

---

## 🔍 Troubleshooting

### Installation Issues

#### Installation Fails

**Check system requirements:**
```bash
# Verify OS version
cat /etc/os-release

# Check available RAM
free -h

# Check available disk space
df -h
```

**Check internet connectivity:**
```bash
ping -c 4 8.8.8.8
curl -I https://github.com
```

**Check if ports are already in use:**
```bash
ss -tulpn | grep -E ':(80|443|109)'
# Should be empty before installation
```

#### Domain Resolution Issues
```bash
# Test domain resolution
dig +short yourdomain.com

# Should return your server IP
# If not, check your DNS A record
```

#### Services Not Starting

**Check service logs:**
```bash
journalctl -u xray -n 50
journalctl -u haproxy -n 50
```

**Common issues:**
- Port already in use: `ss -tulpn | grep :443`
- Configuration error: `xray test -config /usr/local/etc/xray/config.json`
- Permission issues: `ls -la /usr/local/etc/xray/`

**Restart services:**
```bash
systemctl restart xray
systemctl restart haproxy
systemctl status xray haproxy
```

#### User Cannot Connect

**Verify user account status:**
```bash
menu
# Check user list in respective protocol menu
# Verify expiry date hasn't passed
# Check if user is locked
```

**Check user configuration:**
```bash
# View user config file
cat /usr/local/etc/xray/vless-tls-[username].json
# or vmess-tls-[username].json
# or trojan-tls-[username].json
```

**Verify network connectivity:**
```bash
# Check if xray is listening
ss -tulpn | grep xray

# Check haproxy status
systemctl status haproxy
```

**Test from client side:**
- Verify correct server address
- Check client configuration matches server
- Test with different network (mobile data vs WiFi)

---

## 📁 Files and Directories

### Configuration Files
```
/usr/local/etc/xray/
├── config.json              # Main xray config
├── bot.conf                 # Telegram bot credentials (chmod 600)
├── vless-tls-*.json        # VLESS user configs
├── vmess-tls-*.json        # VMess user configs
└── trojan-tls-*.json       # Trojan user configs
```

### Script Locations
```
/usr/local/sbin/
├── algojo-wibu              # IP limit enforcer (runs every 2 min)
├── algojo-kuota             # Quota enforcer (runs every 5 min)
├── lock-user                # Lock user account
├── unlock-user              # Unlock user account
└── unlocker-wibu            # Auto-unlock expired locks
```

### Menu Scripts
```
/usr/local/bin/
├── menu                     # Main menu
├── menu-vless              # VLESS management
├── menu-vmess              # VMess management
├── menu-trojan             # Trojan management
├── m-setting               # Server settings
└── m-backup                # Backup/restore
```

### Log Files
```
/var/log/
├── xray/                   # Xray access/error logs
└── haproxy.log            # HAProxy logs
```

---

## 🗑️ Uninstallation

To completely remove Wibutunnel from your system:

```bash
cd /root/wibutunnel
bash uninstall.sh
```

**This will:**
- ❌ Stop all services (xray, haproxy, dropbear)
- 📦 Remove installed packages
- 🗂️ Delete configuration files
- ⏰ Remove cron jobs
- 🧹 Clean up temporary files

⚠️ **Warning**: This action cannot be undone. Backup your data first.

---

## 🔒 Security Notes

- 🔐 Bot credentials stored in `/usr/local/etc/xray/bot.conf` (chmod 600)
- 🔄 SSL certificates auto-renewed via Let's Encrypt
- 🛡️ Automatic IP and quota enforcement enabled
- 📝 Failed login attempts logged for audit
- 🔑 Use strong passwords for Telegram bot token
- 🚫 Command injection protection implemented

### Best Practices
- Change default SSH port (currently 109 for dropbear)
- Use SSH key authentication instead of passwords
- Enable UFW firewall (allow only ports 80, 443, 109, 22)
- Regularly update system: `apt update && apt upgrade`
- Monitor logs for suspicious activity
- Backup configurations regularly

---

## 🆘 Support

Need help?

1. 📖 Check the [Troubleshooting](#troubleshooting) section
2. 📋 Review service logs: `journalctl -u xray -n 50`
3. 💬 Open an issue on [GitHub](https://github.com/WBVPN/wibutunnel/issues)

---

## 📜 License

This project is licensed under the **MIT License**.

---

<p align="center">
  Made with ❤️ by WBVPN Team
</p>

<p align="center">
  <a href="https://github.com/WBVPN/wibutunnel">⭐ Star us on GitHub</a>
</p>
