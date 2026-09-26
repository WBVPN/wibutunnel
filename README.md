# 🚀 Wibutunnel VPN Management System

<div align="center">

![Version](https://img.shields.io/badge/version-4.0.2%20Kurumi-blue)
![License](https://img.shields.io/badge/license-Private-red)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange)
![Status](https://img.shields.io/badge/status-Production%20Ready-success)

**Multi-Protocol VPN Management Panel untuk Server Tunneling**

*Mendukung SSH, VLESS, VMESS, Trojan* — auto-expiry, quota limit, IP-sharing detection, notifikasi Telegram, dan bot manajemen.

[⚡ Fitur](#-fitur-utama) • [🔧 Instalasi](#-instalasi) • [🔑 Lisensi](#-model-lisensi--keamanan) • [🐛 Troubleshooting](#-troubleshooting)

---

## ⚡ Fitur Utama

### Multi-Protocol
| Protocol | WebSocket | gRPC | Port |
|----------|:---------:|:----:|------|
| VLESS | ✅ | ✅ | 10086-10088 |
| VMESS | ✅ | ✅ | 10089-10091 |
| Trojan | ✅ | ✅ | 10092-10093 |
| SSH | ✅ | ❌ | 143 (Dropbear) |

### Management
- User management: create / delete / renew / trial
- Auto-expiry (daemon cek tiap menit) + recovery
- Quota limit per-user (GB) & IP limit
- IP-sharing detection (grace period 120s, auto-lock)
- Notifikasi Telegram (bot + webhook)
- Backup & restore one-click

### Keamanan & Reliabilitas
- Lisensi via repo private, token via `Authorization` header (bukan URL)
- `flock` anti race condition; validator tolak config xray rusak (null-padding guard) sebelum restart
- Exit-code guard di semua edit config — DB tak ditulis bila config gagal (anti ghost/phantom user)
- Symlink guard di restore backup (anti write-through RCE)
- Validasi input: limit masa aktif & kuota numerik (anti trial permanen)
- Config xray permission 600 — UUID pelanggan tak terbaca user lokal

### Arsitektur
```
Internet → HAProxy :443/80
  ├→ [SSH-2.0]           → Dropbear :143
  ├→ [/vless*]           → Xray :10086-10088
  ├→ [/vmess*]           → Xray :10089-10091  
  ├→ [/trojan*]          → Xray :10092-10093
  ├→ [Websocket Upgrade] → WS-Stunnel :10015
  └→ [default HTTP]      → Apache :8080
```

**Stack:** Xray-core 1.8.24+ · HAProxy · Dropbear · Apache2 · Python3 (ws-stunnel) · Bash

---

## 📦 Instalasi

### Requirement
```
OS     : Ubuntu / Debian
RAM    : 1GB (2GB recommended)
Disk   : 10GB free
Domain : pointed to server IP (untuk SSL)
```

### Quick Install (one-liner)

```bash
curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash -s -- 'TOKEN_DARI_ADMIN'
```

> Ganti `TOKEN_DARI_ADMIN` dengan token lisensi (dapat dari admin setelah registrasi IP).

### Manual Install

```bash
curl -sL -o install.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh
sudo bash install.sh 'TOKEN_DARI_ADMIN'
```

Setelah selesai, masuk menu:
```bash
menu
```

---

## 🎮 Penggunaan

```bash
menu   # dashboard utama
```

```
[1] SSH Tunneling   [5] Setting Server
[2] VLESS           [6] Backup & Restore
[3] VMESS           [7] System Information
[4] Trojan          [0] Exit
```

Operasi umum (ada di tiap menu protokol):
- **Buat akun**: pilih [1] Create Akun
- **Cek user online**: pilih [7]/[9] Cek Login Online
- **Ganti limit kuota/IP**: pilih [6] Ganti Limit
- **Perpanjang / hapus / kunci**: pilih sesuai menu

---

## 🔧 Konfigurasi

| Component | File | Isi |
|-----------|------|-----|
| Xray | `/usr/local/etc/xray/config.json` | Inbound/outbound (mode 600) |
| User Expiry | `/etc/xray/{vless,vmess,trojan,ssh}_exp.conf` | Tanggal expired |
| Quota / IP limit | `/etc/wibutunnel/limit_bw.db`, `limit_ip.db` | Limit per-user |
| Bot Telegram | `/etc/wibutunnel/bot.conf` | BOT_TOKEN, CHAT_ID |
| Domain | `/etc/xray/domain` | Domain utama |

**Ganti domain / bot / update script:** `menu → [5] Setting Server`

---

## 📊 Monitoring & Maintenance

```bash
# Status semua service
systemctl is-active xray haproxy dropbear ws-stunnel wibu-daemon

# Log xray
tail -f /var/log/xray/access.log

# Log expiry & quota
journalctl -u cron | grep xp
journalctl -u wibu-daemon | grep algojo
```

Backup: `menu → [6] Backup & Restore`

Untuk >50 user, tuning sysctl (`somaxconn=1024`, `tcp_max_syn_backlog=2048`, `ip_local_port_range=10000 65535`) lalu `sysctl -p`.

---

## 🐛 Troubleshooting

**Service mati:**
```bash
xray run -test -c /usr/local/etc/xray/config.json   # cek syntax config
journalctl -u xray --no-pager -n 50                 # lihat error
systemctl restart xray haproxy
```

**User tak bisa connect:**
```bash
grep "username" /etc/xray/vless_exp.conf            # expired?
grep "username" /etc/wibutunnel/locked_users.db     # terkunci?
m-vless → [10] Lock / Unlock Akun                    # unlock manual
```

**Port bentrok:** `lsof -i :443` → kill PID, atau ganti port inbound config.

**SSL expired:** `certbot renew --force-renewal`

---

## 📈 Performance

| Users | CPU | RAM | Recommended VPS |
|-------|-----|-----|-----------------|
| 0-50 | <5% | <512MB | 1 vCPU, 1GB RAM |
| 50-200 | 5-15% | 512MB-1GB | 2 vCPU, 2GB RAM |
| 200-500 | 15-40% | 1-2GB | 4 vCPU, 4GB RAM |
| 500+ | 40%+ | 2GB+ | 8 vCPU, 8GB+ RAM |

Optimasi internal (hash lookup O(1), protocol map) sudah aktif sejak v4.0.1.

---

---

## 📚 Script Reference

| Script | Fungsi |
|--------|--------|
| `menu` | Main dashboard |
| `m-ssh` / `m-vless` / `m-vmess` / `m-trojan` | Manajemen per-protokol |
| `m-setting` | Setting server, domain, bot, update script |
| `m-backup` | Backup & restore |
| `xp` | Expiry checker (cron 1 menit) |
| `algojo-wibu` / `algojo-kuota` | IP-limit & quota enforcement |
| `bot-daemon` / `bot-webhook` | Telegram bot |

Semua ada di `/usr/local/bin/` (daemon: `/usr/local/sbin/`).

---

## 🆘 Support

Bug? Kumpulkan info ini sebelum lapor:
```bash
systemctl status xray haproxy wibu-daemon
bash -x /usr/local/bin/xp 2>&1 | tee /tmp/xp-debug.log   # trace
```
Lapor: https://github.com/WBVPN/wibutunnel/issues

---

## 📄 License

**Private License** — IP registrasi disimpan di repo private `WBVPN/wibutunnel-izin`.

```bash
# Cek status lisensi (tampil di dashboard menu utama)
menu
```

Detail cara kerja lisensi & aturan token ada di seksi **🔑 Model Lisensi & Keamanan** di bawah.

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
- 🔴 Hapus hardcoded license token dari installer publik (sebelumnya terbaca siapa saja)
- 🔴 Token lisensi via `Authorization` header, bukan URL (anti `ps` leak)
- 🔴 Exit-code guard di 5 titik edit config bot (anti phantom user: akun di DB tapi tak di config / sebaliknya)
- 🔴 Batas atas input trial (maks 1 thn) + tolak `exp_date` kosong (anti trial permanen)
- 🟠 Restore backup tolak symlink (anti write-through → RCE root)
- 🟠 Config xray 644 → 600 (UUID pelanggan tak terbaca user SSH lokal)
- 🟠 `pipefail` di pipe `curl|bash` installer xray (anti install gagal diam-diam)
- 🟠 Install ke-2x tak menimpa config bila ada klien aktif (anti hapus akun pelanggan)
- ✅ README: model lisensi & risiko keamanan didokumentasikan jujur

### v4.0.1 — Performance (hash lookup O(1), protocol map), bugfix ws-stunnel

### v4.0 — Rilis awal: multi-protocol, Telegram bot, auto-expiry, quota, IP-sharing detection

---

<div align="center">

**⭐ Star repo ini jika bermanfaat!**

Made with ❤️ for Indonesian VPN Community

</div>
