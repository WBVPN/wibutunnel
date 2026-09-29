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

![Version](https://img.shields.io/badge/version-4.0_Kurumi-blue?style=for-the-badge)
![License](https://img.shields.io/badge/license-Private-red?style=for-the-badge)
![Platform](https://img.shields.io/badge/Debian%20|%20Ubuntu-Compatible-orange?style=for-the-badge&logo=debian)

**🎯 Solusi All-in-One untuk Server VPN Tunneling**

[Instalasi Cepat](#-instalasi-cepat) • [Fitur](#-fitur-unggulan) • [Bot Telegram](#-setup-bot-telegram) • [Dokumentasi](#-penggunaan)

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

## 🚀 Instalasi Cepat

### Persyaratan Sistem

```
✓ OS       : Ubuntu 20.04+ / Debian 11+
✓ RAM      : Min 1GB (Rekomendasi 2GB)
✓ Storage  : Min 10GB free space
✓ Domain   : Subdomain pointing ke server IP
✓ Port     : 80, 443 available
```

### Install dalam 1 Command

**One-liner install:**
```bash
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash
```

> **⚠️ Catatan Lisensi:** IP VPS harus terdaftar di `wibutunnel-izin/izin.txt`. Installer otomatis validasi via GitHub. Hubungi admin untuk registrasi IP.

**Setelah install, akses menu:**
```bash
menu
```

### Install Manual (dengan validasi lokal)

Jika ingin validasi lisensi lokal:

**1️⃣ Clone repository izin**
```bash
git clone https://github.com/WBVPN/wibutunnel-izin.git /root/wibutunnel-izin
```

**2️⃣ Jalankan installer**
```bash
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash
```

**3️⃣ Masuk ke menu**
```bash
menu
```

> **⚠️ Catatan:** IP VPS harus terdaftar di `wibutunnel-izin/izin.txt`. Hubungi admin untuk registrasi.

---

## 🤖 Setup Bot Telegram

Bot Telegram memungkinkan manajemen VPS dari chat. Setup hanya butuh 2 menit:

### Langkah Setup

**1. Buat Bot di BotFather**
```
1. Chat @BotFather di Telegram
2. Kirim /newbot
3. Ikuti instruksi, dapatkan BOT_TOKEN
   Format: 123456789:AAExxx...
```

**2. Dapatkan Chat ID**
```
1. Chat @userinfobot di Telegram
2. Bot akan reply dengan ID kamu
   Format: 5851934765
```

**3. Input ke VPS**
```bash
menu → [5] Setting Server → [6] Setup Bot Telegram
```
Masukkan `BOT_TOKEN` dan `CHAT_ID` yang sudah didapat.

**4. Verifikasi**
Bot akan kirim pesan "🤖 Bot Wibu Tunneling Berhasil Terhubung!" otomatis. Kirim `/start` untuk melihat menu bot.

### Command Bot Telegram

| Command | Fungsi |
|---------|--------|
| `/start` | Menu utama bot |
| `/status` | Cek status server & service |
| `/users` | List semua user aktif |
| `/create` | Buat user baru |
| `/renew` | Perpanjang user |
| `/delete` | Hapus user |
| `/backup` | Backup manual ke Telegram |

---

## 📊 Arsitektur Sistem

```
Internet (Client)
      ↓
┌─────────────────────────────────────┐
│   HAProxy :443/80 (Load Balancer)  │
└─────────────────────────────────────┘
      ↓
      ├→ [SSH-2.0 Protocol]      → Dropbear :143
      ├→ [/vless*]               → Xray :10086-10088 (WS/gRPC)
      ├→ [/vmess*]               → Xray :10089-10091 (WS/gRPC)
      ├→ [/trojan*]              → Xray :10092-10093 (WS/gRPC)
      ├→ [/telehook]             → Bot Telegram :8443
      └→ [WebSocket Upgrade]     → WS-Stunnel :10015 → Dropbear :109
```

**Tech Stack:**
- **Xray-core 1.8.24+** - High-performance proxy engine
- **HAProxy** - Layer 4/7 load balancer & router
- **Dropbear** - Lightweight SSH server (enhanced)
- **Python3** - WS-stunnel handler
- **Bash** - System automation & menu

---

## 🎮 Penggunaan

### Menu Utama

```bash
menu  # Akses dashboard
```

```
╔═══════════════════════════════════════════════════╗
║          WIBU TUNNELING v4.0 Kurumi               ║
╠═══════════════════════════════════════════════════╣
║  [1] 🔐 Menu SSH                                  ║
║  [2] ⚡ Menu VLESS                                ║
║  [3] 🚀 Menu VMESS                                ║
║  [4] 🛡️  Menu TROJAN                              ║
║  [5] ⚙️  Setting Server                           ║
║  [6] 💾 Backup & Restore                          ║
║  [0] ❌ Exit                                       ║
╚═══════════════════════════════════════════════════╝
```

### Operasi Umum

**Buat User Baru**
```
Menu Protocol → [1] Create Akun
→ Input username, masa aktif, quota, IP limit
```

**Cek User Online**
```
Menu Protocol → [7]/[9] Cek Login Online
→ Tampil user yang sedang connect real-time
```

**Perpanjang User**
```
Menu Protocol → [4] Renew Akun
→ Input username + tambahan hari
```

**Ganti Limit**
```
Menu Protocol → [6] Ganti Limit
→ Ubah quota bandwidth atau IP limit
```

**Backup ke Telegram**
```
Menu → [6] Backup & Restore → [1] Backup Manual
→ File .zip terenkripsi dikirim ke bot Telegram
```

---

## 📁 Struktur File Penting

| Path | Deskripsi |
|------|-----------|
| `/usr/local/etc/xray/config.json` | Config Xray (inbound/outbound) |
| `/etc/xray/{vless,vmess,trojan}_exp.conf` | Database user & expiry date |
| `/etc/wibutunnel/limit_bw.db` | Quota bandwidth per-user |
| `/etc/wibutunnel/limit_ip.db` | IP limit per-user |
| `/etc/wibutunnel/locked_users.db` | User yang ter-lock |
| `/etc/wibutunnel/bot.conf` | Config bot Telegram |
| `/etc/xray/domain` | Domain VPS |
| `/usr/local/bin/menu` | Entry point menu utama |

---

## 🔧 Maintenance & Monitoring

### Cek Status Service

```bash
systemctl status xray haproxy dropbear ws-stunnel wibu-daemon
```

### View Logs

```bash
# Xray access log
tail -f /var/log/xray/access.log

# Expiry daemon
journalctl -u cron | grep xp

# Algojo (IP/quota enforcement)
journalctl -u wibu-daemon -f

# Bot Telegram
journalctl -u telegram-webhook@* -f
```

### Restart Service

```bash
menu → [5] Setting Server → [1] Restart Semua Service
```

Atau manual:
```bash
systemctl restart xray haproxy dropbear ws-stunnel
```

---

## 🐛 Troubleshooting

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
m-vless → [10] Lock/Unlock Akun
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
systemctl restart telegram-webhook.socket
```
</details>

<details>
<summary><b>❌ Port 443/80 sudah dipakai</b></summary>

```bash
# Cek proses yang pakai port
lsof -i :443

# Kill jika perlu
kill -9 <PID>

# Atau ganti port di config HAProxy
nano /etc/haproxy/haproxy.cfg
```
</details>

<details>
<summary><b>❌ SSL Certificate expired</b></summary>

```bash
# Renew manual
certbot renew --force-renewal

# Atau via menu
menu → [5] Setting → [8] Ganti Domain & Renew SSL
```
</details>

---

## 📈 Performance Tuning

### Rekomendasi VPS berdasarkan Jumlah User

| Users | CPU Usage | RAM Usage | Rekomendasi Spec |
|-------|-----------|-----------|------------------|
| 1-50 | <5% | <512MB | 1 vCPU, 1GB RAM |
| 50-150 | 5-15% | 512MB-1GB | 2 vCPU, 2GB RAM |
| 150-300 | 15-30% | 1-2GB | 2 vCPU, 4GB RAM |
| 300-500 | 30-50% | 2-3GB | 4 vCPU, 4GB RAM |
| 500+ | 50%+ | 3GB+ | 4+ vCPU, 8GB+ RAM |

### Optimasi Kernel (untuk >200 user)

Edit `/etc/sysctl.conf`:
```bash
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_fin_timeout = 15
```

Apply:
```bash
sysctl -p
```

---

## 🔐 Model Lisensi

### Cara Kerja

1. **Whitelist IP**: IP VPS terdaftar di repo private `WBVPN/wibutunnel-izin` (file `izin.txt`)
2. **Format**: `IP | CLIENT_NAME | EXPIRY_DATE`
   ```
   110.232.90.195 | Tulu | LIFETIME
   103.200.216.142 | nm_priasawit | 2026-12-31
   ```
3. **Validasi**: Installer & menu cek IP publik VPS vs daftar izin
4. **Token**: Akses repo pakai fine-grained PAT (read-only, 1 repo only)

### Keamanan Token

✅ **DO:**
- Pakai header `Authorization: token $TOKEN`
- Fine-grained PAT: Contents read-only, 1 repo
- Store di `/etc/wibutunnel/izin_token` (mode 600)

❌ **DON'T:**
- Hardcode token di repo publik
- Pakai token di URL (`https://user:TOKEN@github.com`)
- Share token via chat/email

---

## 🛡️ Security Features

- ✅ **Exit-code guard**: Config validation sebelum restart service
- ✅ **Flock anti race**: Prevent concurrent edit corruption
- ✅ **Input validation**: Reject invalid trial/quota input
- ✅ **Symlink guard**: Prevent write-through attack di restore
- ✅ **Config permission 600**: UUID tidak terbaca user SSH lokal
- ✅ **Encrypted backup**: Password = CHAT_ID Telegram
- ✅ **Webhook secret**: Token validation untuk bot endpoint

---

## 📚 Command Reference

| Command | Fungsi |
|---------|--------|
| `menu` | Dashboard utama |
| `m-ssh` | Menu SSH management |
| `m-vless` | Menu VLESS management |
| `m-vmess` | Menu VMESS management |
| `m-trojan` | Menu Trojan management |
| `m-setting` | Setting server (domain, bot, update) |
| `m-backup` | Backup & restore manual |
| `xp` | Expiry checker (auto via cron) |
| `algojo-wibu` | IP-limit enforcement daemon |
| `algojo-kuota` | Quota enforcement daemon |

---

## 🔄 Changelog

### v4.0 Kurumi (Current)

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

---

## 🆘 Support & Contribute

### Laporkan Bug

Sebelum lapor, kumpulkan informasi:
```bash
# System info
uname -a
cat /etc/os-release

# Service status
systemctl status xray haproxy wibu-daemon

# Debug trace
bash -x /usr/local/bin/xp 2>&1 | tee /tmp/xp-debug.log
```

Buat issue: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)

### Kontak

- 📱 **Telegram**: [@wibuvpnstore](https://t.me/wibuvpnstore)
- 📞 **WhatsApp**: [+62 877-5731-5408](https://wa.me/6287757315408)
- 💬 **Grup WA**: [FREE CONFIG By WIBUVPN](https://chat.whatsapp.com/La5nXNSOYQj8cZ5Ugyk3l8)

---

## 🙏 Credits

**Developed by:** WBVPN Team  
**Version:** 4.0 Kurumi  
**License:** Private (Registered IP Only)

### Built With

- [Xray-core](https://github.com/XTLS/Xray-core) - Next-gen proxy engine
- [HAProxy](http://www.haproxy.org/) - Reliable load balancer
- [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - Lightweight SSH
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
- [Telegram Bot API](https://core.telegram.org/bots/api) - Bot automation

---

<div align="center">

**⭐ Star repo ini jika membantu!**

```
╔═══════════════════════════════════════════════════════╗
║  💰 VPN PREMIUM 7K / 30 HARI                         ║
║  🎁 Trial tersedia via Telegram Bot                  ║
║  🚀 Server cepat & stabil di seluruh Indonesia       ║
╚═══════════════════════════════════════════════════════╝
```

Made with ❤️ for Indonesian VPN Community

[⬆️ Back to Top](#-wibutunnel---vpn-multi-protocol-management)

</div>
