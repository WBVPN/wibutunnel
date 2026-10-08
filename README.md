# Wibutunnel v4.0 - Xray VPN Management System

Multi-protocol VPN tunneling system with Telegram bot integration, user management, and automatic quota enforcement.

## Features

- **Multi-Protocol Support**: VLESS, VMess, Trojan
- **Automatic Enforcement**: IP limit and bandwidth quota enforcement
- **Telegram Bot Integration**: User management via Telegram commands
- **Web Management**: Menu-driven interface for server administration
- **SSL/TLS Support**: Automatic certificate management with Let's Encrypt
- **User Management**: Add, delete, renew, lock/unlock users
- **Traffic Monitoring**: Real-time bandwidth tracking and limits
- **Recovery Tools**: Backup/restore and emergency recovery features

## Requirements

### VPS Requirements
- **OS**: Debian 12 (Bookworm) or Ubuntu 20.04+
- **RAM**: Minimum 512MB (1GB+ recommended)
- **CPU**: 1 core minimum
- **Storage**: 10GB+ free space
- **Network**: Public IPv4 address
- **Root Access**: Required

### Domain Requirements
- Valid domain or subdomain
- DNS A record pointing to VPS IP
- Must resolve before installation (checked during setup)

### Network Requirements
- Ports 80, 443, 109 must be available
- Outbound internet access (for package downloads)
- No firewall blocking required ports

## Installation

### Method 1: Automatic Installation (Recommended)

```bash
# Download and run installer
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh -o setup.sh
chmod +x setup.sh
bash setup.sh
```

**During installation you will be prompted for:**
1. Domain name (e.g., vpn.yourdomain.com)
2. Installation will proceed automatically

**Installation time:** 5-10 minutes depending on internet speed

### Method 2: Manual Installation

```bash
# 1. Clone repository
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel

# 2. Run setup script
bash setup.sh
```

### Post-Installation

After installation completes:

```bash
# Access main menu
menu

# Check service status
systemctl status xray haproxy dropbear

# View logs
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log
```

## Service Verification

Verify all services are running correctly:

```bash
# Check services are active
systemctl is-active xray      # Should output: active
systemctl is-active haproxy   # Should output: active
systemctl is-active dropbear  # Should output: active

# Check ports are listening
ss -tulpn | grep -E ':(80|443|109)'
# Should show haproxy on 80, 443 and dropbear on 109

# Test xray stats API
curl -s http://127.0.0.1:10085 || echo "Stats API running"
```

## Configuration

### Telegram Bot Setup (Optional)

Edit bot configuration after installation:

```bash
nano /etc/wibutunnel/bot.conf
```

Add your bot token and chat ID:
```bash
BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"
```

Restart bot service:
```bash
systemctl restart telegram-webhook
```

### User Limits Configuration

Edit enforcement limits:

```bash
# IP limits per user
nano /etc/wibutunnel/limit_ip.db

# Bandwidth limits per user (in GB)
nano /etc/wibutunnel/limit_bw.db

# Lock duration
nano /etc/wibutunnel/lock.conf
```

## Usage

### Main Menu

Access the main menu:
```bash
menu
```

Available options:
- **VLESS Management** - Add/delete/renew VLESS users
- **VMess Management** - Add/delete/renew VMess users  
- **Trojan Management** - Add/delete/renew Trojan users
- **Settings** - System settings and configuration
- **Backup/Restore** - Backup and restore configuration
- **Recovery** - Emergency recovery tools

### User Management

#### Add New User
```bash
# Via menu
menu → Protocol Menu → Add User

# Set username, expiry days, IP limit, bandwidth limit
```

#### Delete User
```bash
menu → Protocol Menu → Delete User
```

#### Renew User
```bash
menu → Protocol Menu → Renew User
```

#### Check User Info
```bash
menu → Protocol Menu → Check User
```

### Automatic Enforcement

The system automatically enforces limits via cron:

- **IP Limit Enforcement** (algojo-wibu): Runs every 2 minutes
- **Bandwidth Quota Enforcement** (algojo-kuota): Runs every 5 minutes
- **Auto Unlock** (unlocker-wibu): Runs every 1 minute
- **Expiry Check** (xp): Runs every 1 minute

View cron jobs:
```bash
crontab -l
```

## Troubleshooting

### Installation Fails

**Issue**: Xray installation failed
```bash
# Check internet connection
ping -c 3 github.com

# Retry installation
bash setup.sh
```

**Issue**: Domain doesn't resolve
```bash
# Check DNS propagation
dig yourdomain.com +short

# Wait 5-10 minutes for DNS propagation
# Retry installation
```

**Issue**: Port already in use
```bash
# Check what's using ports
ss -tulpn | grep -E ':(80|443|109)'

# Stop conflicting services
systemctl stop nginx apache2
# Then retry installation
```

### Services Not Starting

**Xray service fails:**
```bash
# Check xray config syntax
xray run --test -c /usr/local/etc/xray/config.json

# Check logs
journalctl -u xray -n 50

# Restart xray
systemctl restart xray
```

**HAProxy fails:**
```bash
# Check haproxy config
haproxy -c -f /etc/haproxy/haproxy.cfg

# Check logs
journalctl -u haproxy -n 50

# Restart haproxy
systemctl restart haproxy
```

### User Can't Connect

**Check user exists:**
```bash
# Check VLESS users
cat /etc/xray/vless_exp.conf

# Check VMess users
cat /etc/xray/vmess_exp.conf

# Check Trojan users
cat /etc/xray/trojan_exp.conf
```

**Check user is not locked:**
```bash
cat /etc/wibutunnel/locked_users.db | grep username
```

**Check user not expired:**
```bash
cat /etc/xray/vless_exp.conf | grep username
# Check expiry date
```

### Performance Issues

**High CPU usage:**
```bash
# Check for log file size
du -h /var/log/xray/

# Truncate if too large (>100MB)
> /var/log/xray/access.log
systemctl restart xray
```

**Memory issues:**
```bash
# Check memory usage
free -h

# Restart services
systemctl restart xray haproxy
```

## Files and Directories

### Important Paths

**Configuration:**
- `/usr/local/etc/xray/config.json` - Xray main config
- `/etc/haproxy/haproxy.cfg` - HAProxy config
- `/etc/wibutunnel/bot.conf` - Telegram bot config (chmod 600)

**User Data:**
- `/etc/xray/vless_exp.conf` - VLESS user database
- `/etc/xray/vmess_exp.conf` - VMess user database
- `/etc/xray/trojan_exp.conf` - Trojan user database
- `/etc/wibutunnel/limit_ip.db` - IP limit database
- `/etc/wibutunnel/limit_bw.db` - Bandwidth limit database
- `/etc/wibutunnel/locked_users.db` - Locked users database

**Logs:**
- `/var/log/xray/access.log` - Xray access log
- `/var/log/xray/error.log` - Xray error log

**Scripts:**
- `/usr/local/bin/menu` - Main menu script
- `/usr/local/bin/m-vless` - VLESS management
- `/usr/local/bin/m-vmess` - VMess management
- `/usr/local/bin/m-trojan` - Trojan management
- `/usr/local/sbin/algojo-wibu` - IP enforcement daemon
- `/usr/local/sbin/algojo-kuota` - Quota enforcement daemon
- `/usr/local/sbin/unlocker-wibu` - Auto-unlock daemon

## Uninstallation

```bash
cd /root/wibutunnel
bash uninstall.sh
```

This will:
- Stop all services (xray, haproxy, dropbear)
- Remove installed packages and configs
- Remove user data and databases
- Clean up cron jobs

## Security Notes

- **Bot credentials**: Stored in `/etc/wibutunnel/bot.conf` with permissions 600 (root-only)
- **User passwords**: Not stored in plaintext for SSH (use key-based auth recommended)
- **SSL certificates**: Auto-renewed via certbot every 60 days
- **API access**: Xray stats API only accessible via localhost (127.0.0.1:10085)

## Updates

Check for updates:
```bash
cd /root/wibutunnel
git pull origin main
# Review changes before re-running setup
```

## Support

- **GitHub Issues**: https://github.com/WBVPN/wibutunnel/issues
- **Documentation**: See docs in repository
- **Logs**: Check `/var/log/xray/` for debugging

## Credits

- **Xray-core**: https://github.com/XTLS/Xray-core
- **HAProxy**: http://www.haproxy.org/

## License

See LICENSE file in repository.

---

**Version**: 4.0 Kurumi  
**Last Updated**: 2026-10-09  
**Tested On**: Debian 12 (Bookworm)
