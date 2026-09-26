# 🚀 Wibutunnel VPN Management System

<div align="center">

![Version](https://img.shields.io/badge/version-4.0.2%20Kurumi-blue)
![License](https://img.shields.io/badge/license-Private-red)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04-orange)
![Status](https://img.shields.io/badge/status-Production%20Ready-success)

**Multi-Protocol VPN Management Panel untuk Server Tunneling**

*Mendukung SSH, VLESS, VMESS, Trojan dengan Web Management Interface*

[🌐 Demo](#-quick-start) • [📚 Dokumentasi](#-dokumentasi) • [⚡ Fitur](#-fitur-utama) • [🔧 Instalasi](#-instalasi)

</div>

---

## 📋 Deskripsi

**Wibutunnel** adalah sistem manajemen VPN terintegrasi yang mendukung multiple protokol (SSH, VLESS, VMESS, Trojan) dengan fitur monitoring real-time, quota management, auto-expiry, dan notifikasi Telegram. Dirancang untuk kemudahan deployment dan efisiensi operasional server tunneling.

### 🎯 Use Case
- **Server Tunneling Komersial** - Kelola ratusan user dengan mudah
- **VPN Multi-Protocol** - Satu panel untuk semua protokol
- **Automated Management** - Auto-expiry, quota limit, IP sharing detection
- **Telegram Integration** - Notifikasi otomatis ke admin & user

---

## ⚡ Fitur Utama

### 🔐 Multi-Protocol Support
| Protocol | WebSocket | gRPC | TLS/NTLS | Port |
|----------|-----------|------|----------|------|
| **VLESS** | ✅ | ✅ | ✅ | 10086-10088 |
| **VMESS** | ✅ | ✅ | ✅ | 10089-10091 |
| **Trojan** | ✅ | ✅ | ✅ | 10092-10093 |
| **SSH** | ✅ | ❌ | ✅ | 143 (Dropbear) |

### 🎮 Management Features
- **📊 Dashboard Interaktif** - Menu SSH dengan color-coded status
- **👤 User Management** - Create, delete, renew, trial accounts
- **⏰ Auto-Expiry System** - Background daemon check setiap menit
- **📈 Quota Enforcement** - Limit bandwidth per-user via iptables
- **🔒 IP Sharing Detection** - Grace period 120s, auto-lock
- **🤖 Telegram Bot** - Notifikasi expiry, quota, dan status
- **💾 Backup & Restore** - One-click backup semua konfigurasi
- **🔍 Online User Monitoring** - Real-time connection tracking

### 🛡️ Security & Reliability
- ✅ **License Validation** - IP registration via private repo, token via `Authorization` header (bukan URL)
- ✅ **File Locking (flock)** - Race condition protection
- ✅ **Null-Padding Guard** - Validator tolak config xray rusak sebelum restart
- ✅ **Exit-Code Guards** - Semua edit config dicek; DB tak ditulis jika config gagal
- ✅ **Symlink Guard** - Restore backup tolak entry symlink (anti write-through RCE)
- ✅ **Input Validation** - Limit masa aktif & kuota numerik (anti trial permanen)
- ✅ **Config Permission 600** - UUID/password pelanggan tak terbaca user lokal
- ✅ **Recovery System** - Auto-recovery expired users
- ✅ **Graceful Degradation** - Service continues on partial failure

### ⚙️ Architecture
```
Internet → HAProxy :443/80
  ├→ [SSH-2.0]           → Dropbear :143
  ├→ [/vless*]           → Xray :10086-10088
  ├→ [/vmess*]           → Xray :10089-10091  
  ├→ [/trojan*]          → Xray :10092-10093
  ├→ [Websocket Upgrade] → WS-Stunnel :10015
  └→ [default HTTP]      → Apache :8080
```

**Stack:**
- **Xray-core** (v1.8.24+) - Core VPN engine
- **HAProxy** - Frontend proxy & TLS termination
- **Dropbear** - Lightweight SSH server
- **Apache2** - Web backend
- **Python3** - WS-Stunnel service
- **Bash** - Management scripts

---

## 📦 Instalasi

### Requirement
```bash
OS: Ubuntu 22.04 LTS (Jammy)
RAM: 1GB minimum (2GB recommended)
CPU: 1 core minimum
Disk: 10GB free space
Domain: Pointed to server IP (for SSL)
```

### Quick Start

**One-Liner Install (Recommended):**

> ⚠️ **Token lisensi WAJIB** sebelum install. Dapatkan token dari admin (dikirim via
> Telegram/email setelah registrasi IP) — jangan pernah commit token ke repo manapun.

```bash
export IZIN_TOKEN='token_dari_admin'
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash
```

**Manual Install:**
```bash
# 1. Clone repository
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel

# 2. Set token lisensi (dari admin, lihat catatan lisensi di bawah)
export IZIN_TOKEN='token_dari_admin'

# 3. Jalankan installer
chmod +x setup.sh
sudo ./setup.sh
```

**Setup Steps:**
1. 🔑 Dapatkan `IZIN_TOKEN` dari admin (registrasi IP via Telegram)
2. 🌐 Input domain name saat installer prompt
3. 🤖 Input Telegram bot token & chat ID (optional)
4. ⏳ Tunggu instalasi selesai (~5-10 menit)
5. 🎮 Akses menu: `menu`

### Post-Installation
```bash
# Check all services
systemctl status xray haproxy dropbear ws-stunnel wibu-daemon

# View logs
journalctl -u xray -f
journalctl -u wibu-daemon -f

# SSL certificate (auto-installed via certbot)
certbot certificates
```

---

## 🎮 Penggunaan

### Akses Menu Utama
```bash
menu
```

**Menu Structure:**
```
┌─────────────────────────────────┐
│     WIBUTUNNEL MAIN MENU        │
├─────────────────────────────────┤
│ [1] Menu SSH Tunneling          │
│ [2] Menu VLESS                  │
│ [3] Menu VMESS                  │
│ [4] Menu Trojan                 │
│ [5] Setting Server              │
│ [6] Backup & Restore            │
│ [7] System Information          │
│ [0] Exit                        │
└─────────────────────────────────┘
```

### Membuat User SSH
```bash
m-ssh
# Pilih [1] Create Akun
# Input: username, password, masa aktif (hari)
```

### Membuat User VLESS
```bash
m-vless
# Pilih [1] Create Akun
# Input: username, masa aktif (hari)
# Output: Config + QR code
```

### Monitor User Online
```bash
m-ssh    # pilih [9] Cek Login Online
m-vless  # pilih [7] Cek Login Online
```

### Set Quota Limit
```bash
m-vless  # pilih [6] Ganti Limit Kuota GB
# Input: username, quota dalam GB
```

---

## 🔧 Konfigurasi

### File Locations
| Component | Config File | Description |
|-----------|-------------|-------------|
| Xray | `/usr/local/etc/xray/config.json` | Inbound/outbound rules |
| HAProxy | `/etc/haproxy/haproxy.cfg` | Frontend routing |
| User Expiry | `/etc/xray/{vless,vmess,trojan,ssh}_exp.conf` | Expiration dates |
| Quota Limits | `/etc/wibutunnel/limit_bw.db` | Bandwidth limits |
| Locked Users | `/etc/wibutunnel/locked_users.db` | Auto-locked accounts |
| Bot Config | `/etc/wibutunnel/bot.conf` | Telegram settings |

### Telegram Bot Setup
```bash
# Edit bot config
nano /etc/wibutunnel/bot.conf

# Format:
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
CHAT_ID=-1001234567890

# Restart bot daemon
systemctl restart bot-daemon
```

### Domain Change
```bash
menu → [5] Setting Server → [1] Ganti Domain
# Input domain baru, script akan regenerate SSL & config
```

---

## 📊 Monitoring & Maintenance

### Service Health Check
```bash
# Quick status
systemctl is-active xray haproxy dropbear ws-stunnel wibu-daemon

# Resource usage
ps aux | grep -E "xray|haproxy|dropbear" | awk '{print $11, $3, $4}'

# Port listeners
ss -tlnp | grep -E ":(80|443|143|10015|10086)"
```

### Logs
```bash
# Xray access log
tail -f /var/log/xray/access.log

# Expiry checker (xp) log
journalctl -u cron | grep xp

# Quota enforcement log
journalctl -u wibu-daemon | grep algojo-kuota

# HAProxy log
tail -f /var/log/haproxy.log
```

### Backup
```bash
menu → [6] Backup & Restore → [1] Backup
# Backup disimpan di /root/backup/
```

### Performance Tuning
```bash
# Untuk server dengan >50 users, edit /etc/sysctl.conf:
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 10000 65535

# Apply
sysctl -p
```

---

## 🐛 Troubleshooting

### Service Not Starting
```bash
# Check syntax
xray run -test -c /usr/local/etc/xray/config.json
haproxy -c -f /etc/haproxy/haproxy.cfg

# Check logs
journalctl -u xray --no-pager -n 50
journalctl -u haproxy --no-pager -n 50

# Restart services
systemctl restart xray haproxy
```

### User Can't Connect
```bash
# 1. Check if user exists in config
grep "username" /usr/local/etc/xray/config.json

# 2. Check if user expired
grep "username" /etc/xray/vless_exp.conf

# 3. Check if user locked
grep "username" /etc/wibutunnel/locked_users.db

# 4. Unlock user manually
m-vless → [10] Lock / Unlock Akun
```

### Port Already in Use
```bash
# Find process using port
lsof -i :443
lsof -i :10086

# Kill process
kill -9 <PID>

# Or change port di config
nano /usr/local/etc/xray/config.json
# Edit port inbound, lalu restart xray
```

### SSL Certificate Expired
```bash
# Renew manually
certbot renew --force-renewal

# Check renewal
certbot certificates

# Auto-renewal should work via cron:
cat /etc/cron.d/certbot
```

---

## 📈 Performance Optimization

### Version 4.0.1 Optimizations

**xp (Expiry Checker) - 40-60% faster**
```bash
# Old: O(n) pattern matching
[[ " $ACTIVE_USERS " == *" $user "* ]]

# New: O(1) hash lookup
declare -A active_map
for u in $ACTIVE_VLESS; do active_map[$u]=1; done
[[ -n "${active_map[$user]}" ]]
```

**algojo-kuota (Quota Enforcement) - 75% I/O reduction**
```bash
# Old: 3x file scans per user
db_has "$user" /etc/xray/vless_exp.conf
db_has "$user" /etc/xray/vmess_exp.conf
db_has "$user" /etc/xray/trojan_exp.conf

# New: Single protocol map
declare -A proto_map
while IFS=: read -r u _; do proto_map[$u]="VLESS"; done < /etc/xray/vless_exp.conf
proto="${proto_map[$user]:-UNKNOWN}"
```

### Capacity Planning
| Users | CPU Usage | RAM Usage | Recommended VPS |
|-------|-----------|-----------|-----------------|
| 0-50 | <5% | <512MB | 1 vCPU, 1GB RAM |
| 50-200 | 5-15% | 512MB-1GB | 2 vCPU, 2GB RAM |
| 200-500 | 15-40% | 1-2GB | 4 vCPU, 4GB RAM |
| 500+ | 40%+ | 2GB+ | 8 vCPU, 8GB+ RAM |

---

## 🔒 Security Best Practices

### ✅ Recommended
- ✅ Enable firewall (ufw/iptables) - allow only 80, 443, 22
- ✅ Rotate Telegram bot token quarterly
- ✅ Regular backup (weekly minimum)
- ✅ Monitor failed SSH attempts (fail2ban)
- ✅ Keep Xray-core updated
- ✅ Use strong passwords for user accounts
- ✅ Enable 2FA for server SSH access

### ❌ Avoid
- ❌ Expose Xray ports (10086-10093) directly to internet
- ❌ Share license token publicly
- ❌ Run as non-root without proper sudo config
- ❌ Disable IPv6 if using IPv6 clients
- ❌ Modify core scripts without backup

---

## 📚 Dokumentasi Lengkap

### Script Reference
| Script | Fungsi | Lokasi |
|--------|--------|--------|
| `menu` | Main dashboard | `/usr/local/bin/menu` |
| `xp` | Expiry checker (cron 1min) | `/usr/local/bin/xp` |
| `algojo-wibu` | IP sharing detector | `/usr/local/sbin/algojo-wibu` |
| `algojo-kuota` | Quota enforcement | `/usr/local/sbin/algojo-kuota` |
| `bot-daemon` | Telegram bot handler | `/usr/local/bin/bot-daemon` |
| `m-ssh` | SSH management | `/usr/local/bin/m-ssh` |
| `m-vless` | VLESS management | `/usr/local/bin/m-vless` |
| `m-vmess` | VMESS management | `/usr/local/bin/m-vmess` |
| `m-trojan` | Trojan management | `/usr/local/bin/m-trojan` |
| `m-setting` | Server settings | `/usr/local/bin/m-setting` |
| `m-backup` | Backup/restore | `/usr/local/bin/m-backup` |

### Common Functions (`/usr/local/bin/common.sh`)
```bash
check_license()        # Validate IP license
db_has()              # Check if user exists in file
db_lookup()           # Get user data from file
safe_jq_edit()        # Atomic JSON edit with flock
ssh_user_exists()     # Check if SSH user exists
notify_telegram()     # Send Telegram notification
```

---

## 🆘 Support

### Reporting Issues
Jika menemukan bug atau masalah:
1. Capture screenshot/log error
2. Jalankan diagnostic:
   ```bash
   bash -x /usr/local/bin/xp 2>&1 | tee /tmp/xp-debug.log
   ```
3. Check service status:
   ```bash
   systemctl status xray haproxy wibu-daemon
   ```
4. Create issue dengan informasi lengkap

### Community
- 📖 Wiki: [Coming Soon]
- 💬 Telegram Group: [Coming Soon]
- 🐛 Issues: https://github.com/WBVPN/wibutunnel/issues

---

## 📄 License

**Private License** - Requires IP registration in [wibutunnel-izin](https://github.com/WBVPN/wibutunnel-izin) repository.

### License Validation
```bash
# Check license status
grep "check_license" /usr/local/bin/common.sh

# View registered IP
cat /etc/wibutunnel/izin.txt

# License expires: Check in menu dashboard
menu  # View license info at top
```

---

## 🙏 Credits

**Developer:** WBVPN Team  
**Version:** 4.0.2 Kurumi  
**Based on:** Xray-core, HAProxy, Dropbear  

### Technologies
- [Xray-core](https://github.com/XTLS/Xray-core) - High-performance proxy
- [HAProxy](http://www.haproxy.org/) - Load balancer & proxy
- [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - Lightweight SSH
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

---

## 🔑 Model Lisensi & Keamanan

### Cara lisensi bekerja
1. Daftar IP pelanggan disimpan di repo **private** `WBVPN/wibutunnel-izin` (file `izin.txt`).
2. Format baris: `IP_PUBLIK NAMA EXPIRY IP_PUBLIK` (nama **tanpa spasi** — pakai `_` atau `-`).
3. Installer & menu membaca daftar itu pakai fine-grained PAT (read-only, scoped ke 1 repo).
4. VPS cocokkan IP publiknya; kalau tak terdaftar/expired → akses ditolak.

### Aturan token (WAJIB baca)
- ❌ **Jangan pernah** tulis token di file yang ada di repo publik.
- ❌ **Jangan pernah** kirim token via URL (`https://user:TOKEN@host`) — bocor ke `ps`/`/proc/*/cmdline`.
- ✅ Pakai header: `curl -H "Authorization: token $IZIN_TOKEN"`.
- ✅ Bikin PAT **fine-grained**: hanya repo `wibutunnel-izin`, permission `Contents: Read-only`, expiry pendek.
- ✅ Token lama (sebelum v4.0.2) ter-ekspose di git history publik — **wajib di-revoke**.

### Yang masih jadi risiko terbuka
- **Download tanpa checksum**: installer tarik binary xray & tool via `curl|bash`/direct download tanpa verifikasi sha256/GPG. Kompromi GitHub/CDN = RCE root. Mitigasi masa depan: pin commit hash + GPG sign.
- **Safe Update** (menu `[5]`) verifikasi magic bytes saja, bukan signature. Push ke repo utama = update ke seluruh armada. Batasi collaborator repo publik.
- **User SSH dapat shell `/bin/bash`** (memang diperlukan untuk tunneling) — kombinasi dengan service lain yang menulis ke `/tmp` bisa jadi tangga privilege escalation. Tetap audit.

---

## 🔄 Changelog

### v4.0.2 Kurumi (Latest) — Security Patch
- 🔒 **Critical:** Hapus hardcoded license token dari installer (sebelumnya terbaca di repo publik)
- 🔒 **Critical:** Token lisensi kini dikirim via `Authorization` header, bukan URL (anti `ps` leak)
- 🔒 **Critical:** Guard exit-code di 5 titik edit config Telegram bot (anti phantom user: akun di DB tapi tak di config / sebaliknya)
- 🔒 **Critical:** Batas atas input trial (maks 1 tahun) + tolak `exp_date` kosong (anti trial permanen)
- 🔒 **High:** Restore backup tolak entry symlink (anti write-through → RCE root)
- 🔒 **High:** Permission config xray 644 → 600 (UUID pelanggan tak terbaca user SSH lokal)
- 🔒 **High:** `pipefail` lokal di pipe `curl|bash` installer xray (anti install gagal diam-diam)
- 🔒 **High:** Install ke-2x tak lagi menimpa config bila ada klien aktif (anti hapus akun pelanggan)
- ✅ Dokumentasi keamanan & model lisensi dijelaskan jujur

### v4.0.1 Kurumi
- ✅ Performance: Associative arrays for O(1) lookup
- ✅ Performance: Protocol map (75% I/O reduction)
- ✅ Bug Fix: ws-stunnel ValueError handling
- ✅ Bug Fix: WebSocket RFC 7230 compliance
- ✅ Security: Enhanced license validation
- ✅ Stability: Grace period fixes

### v4.0 Kurumi
- ✅ Multi-protocol support (VLESS, VMESS, Trojan, SSH)
- ✅ Telegram bot integration
- ✅ Auto-expiry system
- ✅ Quota enforcement
- ✅ IP sharing detection
- ✅ Web management panel

---

<div align="center">

**⭐ Star repo ini jika bermanfaat!**

Made with ❤️ for Indonesian VPN Community

</div>
