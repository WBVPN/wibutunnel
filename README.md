# 🚀 Wibutunnel - VPN Multi-Protocol Management

<div align="center">

```
██╗    ██╗██╗██████╗ ██╗   ██╗████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗     
██║    ██║██║██╔══██╗██║   ██║╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║     
██║ █╗ ██║██║██████╔╝██║   ██║   ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║     
██║███╗██║██║██╔══██╗██║   ██║   ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║     
╚███╔███╔╝██║██████╔╝╚██████╔╝   ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗
 ╚══╝╚══╝ ╚═╝╚═════╝  ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝
```

![Version](https://img.shields.io/badge/version-4.0.1_Kurumi-blue?style=for-the-badge)
![License](https://img.shields.io/badge/license-Private-red?style=for-the-badge)
![Platform](https://img.shields.io/badge/Debian%20|%20Ubuntu-Compatible-orange?style=for-the-badge&logo=debian)
[![Tests](https://img.shields.io/badge/CI%2FCD-Automated_Testing-green?style=for-the-badge&logo=github-actions)](https://github.com/WBVPN/wibutunnel/actions)
![Quality](https://img.shields.io/badge/code_quality-shellcheck_passed-success?style=for-the-badge&logo=gnu-bash)

**🎯 Solusi All-in-One untuk Server VPN Tunneling dengan Automated Testing**

[Instalasi Cepat](#-instalasi-cepat) • [Fitur](#-fitur-unggulan) • [Testing](#-development--testing) • [Bot Telegram](#-setup-bot-telegram) • [Dokumentasi](#-penggunaan) • [Troubleshooting](#-troubleshooting)

</div>

---

## ✨ Fitur Unggulan

<table>
<tr>
<td width="50%">

### 🔐 Multi-Protocol Support
- **VLESS** (WebSocket + gRPC)
- **VMESS** (WebSocket + gRPC) 
- **Trojan** (WebSocket + gRPC)
- **SSH** (Dropbear Enhanced)

### 🤖 Manajemen Otomatis
- ✅ Auto-expiry user (cek setiap menit)
- ✅ Quota limit per-user (bandwidth)
- ✅ IP-sharing detection & auto-lock
- ✅ Trial account dengan batas waktu
- ✅ Notifikasi Telegram real-time

</td>
<td width="50%">

### 💼 Bot Telegram
- 🎮 Command interaktif
- 📊 Monitoring real-time
- 👥 User management via chat
- 🔔 Alert expired & quota
- 💾 Backup & restore otomatis

### 🛡️ Keamanan Enterprise
- 🔒 License validation system
- 🚫 Anti race-condition (flock)
- ✔️ Config validation guard
- 🔐 Encrypted backup (password)
- 📝 Audit trail lengkap

</td>
</tr>
</table>

---

## 🧪 Development & Testing

**Production-Ready dengan Comprehensive Testing Suite** ✨

Wibutunnel dilengkapi automated testing suite yang memastikan **zero errors sebelum deployment**:

### 🎯 Test Coverage
- ✅ **Smoke Test** - 2 detik quick validation (80% coverage)
- ✅ **Syntax Validation** - ShellCheck pada semua scripts
- ✅ **Integration Testing** - Full install/uninstall flow
- ✅ **Service Validation** - Xray, HAProxy, Dropbear, ws-stunnel
- ✅ **Regression Testing** - 10+ regression test cases
- ✅ **Ubuntu Fix Validation** - Kernel hold & crash prevention

### ⚡ Performance
```
CI/CD Pipeline: 50 min → 10-15 min (70-80% faster)
Docker Testing: 60 min → 30 min (parallel execution)
Quick Check: 30 min → 2 sec (smoke test)
GitHub Actions: 70% cost reduction (500 → 150 min/month)
```

### 🚀 Quick Test Commands

```bash
# Quick smoke test (2 seconds)
bash test/smoke_test.sh

# Full syntax validation
bash test/validate.sh

# Regression tests
bash test/test_regressions.sh

# Integration test (requires Docker)
bash test/integration_test.sh
```

### 📚 Developer Documentation
- **[TESTING_README.md](TESTING_README.md)** - Comprehensive testing guide
- **[PHASE1_CHANGELOG.md](PHASE1_CHANGELOG.md)** - Phase 1 optimizations
- **[PHASE23_CHANGELOG.md](PHASE23_CHANGELOG.md)** - Phase 2 & 3 optimizations
- **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - CI/CD setup guide

**🔗 Automated CI/CD:** Every push triggers automated testing via GitHub Actions untuk ensure code quality sebelum merge.

---

## 🚀 Instalasi Cepat

### Persyaratan Sistem

```
✓ OS       : Ubuntu 20.04+ / Debian 11+
✓ RAM      : Min 1GB (Rekomendasi 2GB)
✓ Storage  : Min 10GB free space
✓ curl     : Required untuk fetch installer
✓ git      : Required oleh installer script
✓ Domain   : Subdomain pointing ke server IP
✓ Port     : 80, 443 tersedia (tidak dipakai service lain)
✓ Lisensi  : IP VPS terdaftar di wibutunnel-izin repo
```

**Instalasi curl & git (jika belum ada):**
```bash
apt update && apt install -y curl git
```

### Install dalam 1 Command

**Untuk IP yang sudah terdaftar:**
```bash
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash
```

> **⚠️ Catatan Lisensi:** IP VPS harus terdaftar di `wibutunnel-izin/izin.txt`. Installer otomatis validasi via GitHub. Hubungi admin untuk registrasi IP.

**Setelah install, akses menu:**
```bash
menu
```

### Install Manual (dengan validasi lokal)

Jika ingin validasi lisensi lokal atau troubleshooting:

**1️⃣ Clone repository izin**
```bash
git clone https://github.com/WBVPN/wibutunnel-izin.git /root/wibutunnel-izin
```

**2️⃣ Cek lisensi IP Anda**
```bash
cd /root/wibutunnel-izin
grep "$(curl -s ipv4.icanhazip.com)" izin.txt
```

**3️⃣ Clone & install wibutunnel**
```bash
cd /root
git clone https://github.com/WBVPN/wibutunnel.git
cd wibutunnel
chmod +x setup.sh
./setup.sh
```

### Proses Instalasi

Installer akan:
1. ✅ Validasi lisensi IP VPS
2. ✅ Disable IPv6 (mencegah routing issues)
3. ✅ Install dependencies (haproxy, certbot, xray, dll)
4. ✅ Minta input domain Anda
5. ✅ Generate SSL certificate (Let's Encrypt)
6. ✅ Compile Dropbear SSH + badvpn-udpgw
7. ✅ Configure services (Xray, HAProxy, Dropbear)
8. ✅ Setup cron jobs (auto-expiry, watchdog)
9. ✅ Reboot otomatis

**Durasi:** ~10-15 menit (tergantung kecepatan compile)

---

## 🤖 Setup Bot Telegram

Bot Telegram opsional untuk manajemen VPN via chat.

### Langkah Setup

**1️⃣ Buat bot baru via [@BotFather](https://t.me/BotFather)**
```
/newbot
Nama: Wibu VPN Bot
Username: @wibu_vpn_bot (contoh)
```

Simpan **BOT_TOKEN** yang diberikan.

**2️⃣ Aktifkan bot di VPS**
```bash
menu → [8] Setting → [6] Telegram Bot
```

Masukkan:
- BOT_TOKEN dari BotFather
- ADMIN_ID (Telegram user ID Anda, dapatkan via [@userinfobot](https://t.me/userinfobot))

**3️⃣ Test bot**
Kirim `/start` ke bot Anda. Bot akan reply dengan menu.

### Command Bot Telegram

```
/start      - Menu utama
/create     - Buat akun baru
/renew      - Perpanjang akun
/delete     - Hapus akun
/check      - Cek info akun
/list       - List semua user
/backup     - Backup data VPS
/restore    - Restore dari backup
/status     - Status server & services
```

---

## 📊 Arsitektur Sistem

```
                    Internet
                       |
                  [HAProxy:443]
                  SSL Termination
                       |
           +-----------+-----------+
           |                       |
    [Xray:10085]            [Dropbear:109,143]
    VLESS/VMESS/Trojan        SSH Tunnel
           |                       |
    [ws-stunnel:10015]      [badvpn-udpgw]
    WebSocket Proxy         UDP Gateway
           |                       |
           +----------+------------+
                      |
                [Internet Gateway]
```

**Port Mapping:**
- `80` - HTTP (redirect ke HTTPS)
- `443` - HTTPS/TLS (HAProxy frontend)
- `143, 109` - Dropbear SSH (direct)
- `10015` - ws-stunnel (internal)
- `10085` - Xray API (internal)
- `7100-7600` - badvpn-udpgw (internal)

---

## 🎮 Penggunaan

### Menu Utama

Setelah instalasi, ketik `menu` untuk akses panel:

```
┌─────────────────────────────────────┐
│     WIBU TUNNELING MANAGEMENT       │
├─────────────────────────────────────┤
│  1. VLESS Menu                      │
│  2. VMESS Menu                      │
│  3. Trojan Menu                     │
│  4. SSH Menu                        │
│  5. Backup/Restore                  │
│  6. User Lock/Unlock                │
│  7. Check Traffic                   │
│  8. Setting                         │
│  9. Reboot VPS                      │
│  0. Exit                            │
└─────────────────────────────────────┘
```

### Operasi Umum

**Buat User VLESS:**
```bash
menu → [1] VLESS Menu → [1] Create Account
```

**Set Quota Bandwidth:**
```bash
menu → [1] VLESS Menu → [8] Set Quota
Username: alice
Quota: 10 (dalam GB)
```

**Lock User (IP Sharing):**
```bash
menu → [6] Lock/Unlock → [1] Lock User
Username: bob
Reason: Multi-login detected
```

**Cek Traffic:**
```bash
cek-trafik
# atau
menu → [7] Check Traffic
```

**Backup Data:**
```bash
menu → [5] Backup/Restore → [1] Backup
Password: (masukkan password enkripsi)
```

---

## 📁 Struktur File Penting

```
/etc/wibutunnel/
├── bot.conf                    # Telegram bot config
├── locked_users.db             # Daftar user yang di-lock
├── limit_ip.db                 # IP limit database
├── limit_bw.db                 # Bandwidth quota database
├── user_usage.db               # Usage tracking
├── ssh_pass.db                 # SSH password database
└── version                     # Installed version

/etc/xray/
├── config.json                 # Xray main config
├── vless_exp.conf              # VLESS user + expiry
├── vmess_exp.conf              # VMESS user + expiry
└── trojan_exp.conf             # Trojan user + expiry

/etc/haproxy/
├── haproxy.cfg                 # HAProxy config
└── certs/
    └── domain.pem              # SSL certificate

/usr/local/bin/
├── menu                        # Main menu
├── m-vless, m-vmess, m-trojan  # Protocol menus
├── m-ssh, m-setting, m-backup  # Management menus
├── xp                          # Auto-expiry checker
├── cek-trafik                  # Traffic monitor
└── common.sh                   # Shared functions

/usr/local/sbin/
├── algojo-wibu                 # Expiry executor
├── algojo-kuota                # Quota enforcer
├── lock-user, unlock-user      # Lock/unlock tools
└── unlocker-wibu               # Auto-unlocker (grace period)

/var/log/xray/
├── access.log                  # Xray access log
└── error.log                   # Xray error log

/root/wibutunnel/test/          # Testing suite (NEW)
├── smoke_test.sh               # 2s quick validation
├── validate.sh                 # ShellCheck syntax check
├── integration_test.sh         # Full integration test
├── docker_test_runner.sh       # Multi-OS testing
├── test_regressions.sh         # Regression test suite
├── test_config.sh              # Centralized test config
└── fixtures/                   # Test fixtures
    └── mock_license.txt        # Mock license data
```

---

## 🔧 Maintenance & Monitoring

### Cek Status Service

```bash
systemctl status xray haproxy dropbear ws-stunnel wibu-daemon
```

### View Logs

```bash
# Xray logs
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# HAProxy logs
journalctl -u haproxy -f

# Installer logs (troubleshooting)
tail -f /tmp/full_install_debug.log
```

### Restart Service

```bash
# Restart individual service
systemctl restart xray
systemctl restart haproxy

# Restart all
systemctl restart xray haproxy dropbear ws-stunnel
```

### Update Script

```bash
cd /root/wibutunnel
git pull
# Re-run installer jika ada perubahan config
./setup.sh
```

---

## 🐛 Troubleshooting

<details>
<summary><b>❌ Installer hang setelah "IPv6 berhasil dimatikan"</b></summary>

**Penyebab:** apt_selfheal testing mirrors (fixed di v4.0.1)

**Solusi:**
```bash
# v4.0.1+ sudah include timeout otomatis (max 5 menit)
# Jika masih terjadi di versi lama:
1. Tunggu max 5 menit (timeout otomatis)
2. Atau Ctrl+C dan update ke v4.0.1:
   cd /root/wibutunnel && git pull && ./setup.sh
```

**Status:** Fixed di v4.0.1 (2026-09-30)
</details>

<details>
<summary><b>❌ Error: "git: command not found"</b></summary>

**Penyebab:** git belum terinstall

**Solusi:**
```bash
apt update && apt install -y git
# Kemudian re-run installer
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | bash
```
</details>

<details>
<summary><b>❌ Error: "Gagal clone repo wibutunnel-izin"</b></summary>

**Penyebab:** Private repo membutuhkan autentikasi

**Solusi 1 - Setup Git Credentials:**
```bash
git config --global credential.helper store
echo "https://YOUR_GITHUB_TOKEN@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
```

**Solusi 2 - Manual Clone:**
```bash
git clone https://YOUR_GITHUB_TOKEN@github.com/WBVPN/wibutunnel-izin.git /root/wibutunnel-izin
```

Ganti `YOUR_GITHUB_TOKEN` dengan token akses GitHub Anda.
</details>

<details>
<summary><b>❌ Service Xray tidak start</b></summary>

```bash
# Test config syntax
xray run -test -c /usr/local/etc/xray/config.json

# Lihat error detail
journalctl -u xray --no-pager -n 50

# Restart
systemctl restart xray
```
</details>

<details>
<summary><b>❌ User tidak bisa connect</b></summary>

```bash
# Cek expired
grep "username" /etc/xray/vless_exp.conf

# Cek locked
grep "username" /etc/wibutunnel/locked_users.db

# Unlock manual
menu → [6] Lock/Unlock → [2] Unlock User
```
</details>

<details>
<summary><b>❌ Bot Telegram tidak respond</b></summary>

```bash
# Cek webhook status
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"

# Cek socket aktif
systemctl status telegram-webhook.socket

# Restart
systemctl restart telegram-webhook.socket wibu-daemon
```
</details>

<details>
<summary><b>❌ Port 443/80 sudah dipakai</b></summary>

```bash
# Cek service yang pakai port
ss -tlnp | grep -E ':(80|443) '

# Matikan service konflik (contoh: nginx)
systemctl stop nginx
systemctl disable nginx

# Restart HAProxy
systemctl restart haproxy
```
</details>

<details>
<summary><b>❌ Domain tidak resolve ke IP VPS</b></summary>

**Cek DNS:**
```bash
dig +short A your-domain.com
# Harus return IP VPS Anda
```

**Solusi:**
1. Login ke DNS provider (Cloudflare/Namecheap/dll)
2. Buat A record: `subdomain` → `IP_VPS`
3. Tunggu propagasi DNS (5-15 menit)
4. Retry installer
</details>

<details>
<summary><b>❌ SSL Certificate gagal (rate limit)</b></summary>

**Penyebab:** Terlalu banyak request ke Let's Encrypt

**Solusi:**
```bash
# Gunakan staging (test) dulu
certbot certonly --standalone --staging -d your-domain.com

# Setelah berhasil, hapus staging dan request real:
certbot delete --cert-name your-domain.com
certbot certonly --standalone -d your-domain.com
```

**Rate Limit Let's Encrypt:**
- 50 certificates per domain per week
- 5 failed validations per hour
</details>

<details>
<summary><b>❌ Testing gagal dengan error "shellcheck: command not found"</b></summary>

**Penyebab:** ShellCheck belum terinstall (required untuk syntax validation)

**Solusi:**
```bash
# Ubuntu/Debian
apt update && apt install -y shellcheck

# Verify installation
shellcheck --version

# Re-run validation
bash test/validate.sh
```
</details>

---

## 📈 Performance Tuning

### Rekomendasi VPS berdasarkan Jumlah User

| Users | RAM  | CPU | Storage | Bandwidth |
|-------|------|-----|---------|-----------|
| 1-50  | 1GB  | 1   | 10GB    | 500GB/mo  |
| 51-100| 2GB  | 2   | 20GB    | 1TB/mo    |
| 101-200| 4GB | 2   | 30GB    | 2TB/mo    |
| 201-500| 8GB | 4   | 50GB    | 5TB/mo    |
| 500+  | 16GB | 8   | 100GB   | 10TB/mo   |

### Optimasi Kernel (untuk >200 user)

Script installer sudah setup BBR + buffer tuning. Manual tweaking:

```bash
# Increase connection tracking
echo "net.netfilter.nf_conntrack_max = 262144" >> /etc/sysctl.conf

# Increase file descriptors
echo "fs.file-max = 2000000" >> /etc/sysctl.conf

# Apply
sysctl -p

# Restart services
systemctl restart xray haproxy
```

---

## 🔐 Model Lisensi

### Cara Kerja

1. **Registrasi IP:** Admin menambahkan IP VPS Anda ke `wibutunnel-izin/izin.txt`
2. **Format:**
   ```
   110.232.90.195 | username | LIFETIME
   203.0.113.45   | username | 2026-12-31
   ```
3. **Validasi:** Installer otomatis cek IP saat instalasi
4. **Token:** License token disimpan encrypted di `/etc/wibutunnel/izin_token`

### Keamanan Token

- Token tidak di-hardcode di script (anti leak)
- Passed via environment variable atau header
- Permission 600 (root only)
- Divalidasi setiap kali run menu/daemon

---

## 🛡️ Security Features

- **Anti-Torrent:** Deep packet inspection (BitTorrent strings)
- **Anti-DDoS:** Rate limiting per IP
- **SSH Brute-force Protection:** Fail2ban-like (max 10 conn/min)
- **Config Validation:** Syntax check sebelum reload
- **Audit Trail:** Semua operasi user di-log
- **File Permission:** 600 untuk sensitive files
- **Process Isolation:** Services run sebagai nobody/nogroup

---

## 📚 Command Reference

### User Management

```bash
# VLESS
m-vless                          # Menu VLESS
m-vless create user 30           # Create user, expire 30 hari
m-vless renew user 30            # Renew user 30 hari
m-vless delete user              # Hapus user
m-vless check user               # Info user
m-vless list                     # List semua user

# VMESS (sama seperti VLESS)
m-vmess create user 30

# Trojan (sama seperti VLESS)
m-trojan create user 30

# SSH
m-ssh create user password 30    # Create SSH user
```

### Lock/Unlock

```bash
lock-user username               # Lock user (block akses)
unlock-user username             # Unlock user
menu-lock                        # Lock menu
menu-unlock                      # Unlock menu
```

### Monitoring

```bash
cek-trafik                       # Traffic per user
cek-trafik username              # Traffic user specific
```

### Backup/Restore

```bash
m-backup                         # Menu backup
# Backup otomatis via bot: /backup
# Restore via bot: /restore <file>
```

### Daemon Control

```bash
systemctl status wibu-daemon     # Status daemon
systemctl restart wibu-daemon    # Restart daemon
journalctl -u wibu-daemon -f     # View logs
```

---

## 🔄 Changelog

### v4.0.1 Kurumi Hotfix (2026-09-30)
- 🐛 **Fix:** apt_selfheal indefinite hang on archive.debian.org sources
- ⏱️ **Add:** 5-minute timeout wrapper for automated installation
- ✅ **Test:** Verified on production Debian 11 VPS
- 📝 **Doc:** Update prerequisites (git, curl required)

### v4.0 Kurumi (2026-08-01)

**🔒 Security Improvements**
- Remove hardcoded license token dari public repo
- Token via `Authorization` header (anti `ps` leak)
- Exit-code guard prevent phantom user
- Symlink guard di restore backup
- Config xray permission 600

**🐛 Bug Fixes**
- Fix menu hang (license check bypass ke local)
- Fix bot webhook processing
- Fix concurrent edit race condition
- Fix trial permanent exploit

**⚡ Performance**
- Hash lookup O(1) untuk user search
- Protocol mapping optimization
- Cached geo lookup (10 menit)

**✨ Features**
- Multi-protocol (VLESS, VMESS, Trojan, SSH)
- Auto-expiry real-time (cek tiap menit)
- IP-sharing detection (grace 120s)
- Quota bandwidth limit
- Telegram bot + webhook
- One-click backup/restore

**🧪 Testing Suite (NEW - Oct 2026)**
- Comprehensive automated testing (Phase 1+2+3)
- CI/CD pipeline optimization (70-80% faster)
- Smoke test for quick validation (2 seconds)
- Integration & regression testing
- GitHub Actions automation

---

## 🆘 Support & Contribute

### Laporkan Bug

Buat issue: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)

**Template:**
```markdown
**Deskripsi:**
[jelaskan bug]

**Langkah Reproduksi:**
1. ...
2. ...

**OS & Version:**
- OS: Debian 11 / Ubuntu 22.04
- Wibutunnel: v4.0.1

**Log:**
```
[paste log dari /var/log/xray/error.log atau journalctl]
```
```

### Contribute

Kami welcome contributions! Check out:
- [TESTING_README.md](TESTING_README.md) - Testing guidelines
- [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) - CI/CD setup

**Development Workflow:**
1. Fork repository
2. Create feature branch
3. Run smoke test: `bash test/smoke_test.sh`
4. Run full validation: `bash test/validate.sh`
5. Submit pull request
6. Automated CI/CD akan run full test suite

### Kontak

- 📱 **Telegram**: [@wibuvpnstore](https://t.me/wibuvpnstore)
- 📞 **WhatsApp**: [+62 877-5731-5408](https://wa.me/6287757315408)
- 🐛 **Issues**: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)

---

## 🙏 Credits

### Built With

- [Xray-core](https://github.com/XTLS/Xray-core) - Core proxy engine
- [HAProxy](https://www.haproxy.org/) - Load balancer & SSL terminator
- [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - Lightweight SSH
- [badvpn](https://github.com/ambrop72/badvpn) - UDP gateway
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

### Testing & Quality Assurance

- [ShellCheck](https://www.shellcheck.net/) - Shell script static analysis
- [GitHub Actions](https://github.com/features/actions) - CI/CD automation
- Docker - Multi-OS testing (Ubuntu 22.04, 20.04, Debian 11, 12)

### License

Private License - IP registration required.  
© 2026 Wibu VPN Store. All rights reserved.

---

<div align="center">

**[⬆ Back to Top](#-wibutunnel---vpn-multi-protocol-management)**

Made with ❤️ by [WBVPN Team](https://github.com/WBVPN)

**Quality Assured • Automated Testing • Production Ready**

</div>
