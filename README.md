# 🦋 WIBU TUNNELING v4.0 Kurumi 🦋

[![Version](https://img.shields.io/badge/Version-v4.0_Kurumi_Patched-blue.svg?style=for-the-badge&logo=appveyor)](https://github.com/WBVPN/wibutunnel)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg?style=for-the-badge&logo=ubuntu)](https://github.com/WBVPN/wibutunnel)
[![Status](https://img.shields.io/badge/Status-Stable%20%26%20Secure-success.svg?style=for-the-badge&logo=checkmarx)](https://github.com/WBVPN/wibutunnel)

**Ultimate Xray VPN Auto Script** dengan arsitektur paling ringan dan mutakhir. Dibangun khusus untuk memberikan performa maksimal pada VPS dengan perlindungan keamanan, manajemen memori tingkat lanjut, dan sistem limit otomatis (Algojo). Edisi spesial **Kurumi** 💜.

---

## 🔐 Security Patch & Bug Fix (Latest)

| Kategori | Perbaikan |
| :--- | :--- |
| 🛡️ **Race Condition** | Semua akses ke `config.json` kini melalui `flock` via `safe_jq_edit()` — mencegah data user hilang saat proses paralel |
| 🛡️ **Webhook Auth** | Telegram webhook dilindungi `X-Telegram-Bot-Api-Secret-Token` — cegah eksekusi command dari pihak luar |
| 🛡️ **IP Guard** | Pengecekan `MYIP` kosong di `common.sh` — cegah bypass lisensi saat curl gagal |
| 🔧 **Temp File Collision** | `algojo-wibu` & `algojo-kuota` pakai `mktemp` unik — tidak lagi saling timpa di `/tmp/xray.json` |
| 🔧 **Lock/Unlock Menu** | User yang terkunci kini tetap muncul di menu Lock/Unlock — admin bisa unlock langsung |
| 🔧 **Escape Functions** | `escape_sed()` & `escape_grep()` diperbaiki — user dengan titik (`.`) tidak salah match |
| 🔧 **sed → grep -v** | Semua `sed -i` dengan variabel user diganti `safe_sed_delete()` (fixed string match) |
| 🔧 **Uninstall Lengkap** | `uninstall.sh` membersihkan wibu-daemon, systemd overrides, logrotate, cron, `.profile` |
| 🔧 **Logrotate** | Berjalan sebagai `nobody:nogroup` dengan `create 0644` — permission aman untuk Xray |
| 🔧 **Config Permission** | `chmod 644` otomatis setelah setiap edit `config.json` — Xray (nobody) selalu bisa baca |
| 🔧 **Setup.sh Cleanup** | Heredoc lama dihapus, sbin scripts di-download dari repo (source of truth) |

---

## ✨ Fitur Unggulan

🚀 **100% Zero Disk I/O (RAM Disk Logging)**
Seluruh aktivitas log Xray diproses di RAM (`tmpfs`) — VPS super cepat dan kebal I/O wait.

🧠 **Otak Algojo Generasi Baru (Awk Engine V4 + Tac)**
Deteksi multilogin real-time via log terbalik (`tac`) dengan early exit AWK. Akurat 100% meski ribuan user aktif bersamaan.

🛡️ **Anti URL-Encoding (100% Koneksi Sukses)**
HAProxy kebal terhadap error copy-paste link klien (`%2F`, spasi, dll). Routing selalu sampai tanpa 503.

🔄 **Sistem Recovery Cerdas**
User limit/expired masuk "Ruang Recovery" (akses diblokir, bukan dihapus). Perpanjang → Unlock → langsung konek tanpa ganti link!

🤖 **Bot Telegram Super Admin**
Create, Renew, Delete, Lock, Cek Trafik, Cek Login — semua dari chat Telegram dengan layout premium.

🚫 **Auto IPv6 Disabler**
IPv6 otomatis mati via sysctl & GRUB. Kebal error `apt update` dan routing conflict.

🔒 **Atomic Config Editing**
Semua operasi edit `config.json` dilindungi file locking (`flock`) — aman dari race condition walau algojo, xp.sh, dan admin edit bersamaan.

---

## 📦 Protokol yang Didukung

| Protokol | Transport |
| :--- | :--- |
| **VLESS** | WebSocket TLS, WebSocket Non-TLS, gRPC |
| **VMESS** | WebSocket TLS, WebSocket Non-TLS, gRPC |
| **TROJAN** | WebSocket TLS, gRPC |

---

## ⚡ Instalasi Cepat (1-Click)

```bash
apt update -y && apt install -y curl wget && bash <(curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh)
```

> **Syarat:** VPS Ubuntu/Debian fresh (baru rebuild). Jalankan sebagai `root`.

---

## 📋 Daftar Menu

| Menu | Fitur |
| :--- | :--- |
| **Kelola VLESS** | Create, Delete, Renew, Trial, Limit IP, Limit Kuota |
| **Kelola VMESS** | Create, Delete, Renew, Trial, Limit IP, Limit Kuota |
| **Kelola TROJAN** | Create, Delete, Renew, Trial, Limit IP, Limit Kuota |
| **Recovery Center** | Lock, Unlock, Reaktivasi, Hapus Permanen |
| **Cek Trafik** | Monitor Real-Time IP & Bandwidth per user |
| **Settings** | Bot Telegram, Auto Reboot, Auto Backup, Speedtest |
| **Backup & Restore** | Backup/Restore via Telegram (File ID / Path) |

---

## 📁 Struktur File

```
wibutunnel/
├── setup.sh              # Master installer
├── common.sh             # Shared functions (flock, sanitize, license)
├── uninstall.sh          # Clean uninstaller
├── izin.txt              # License database
├── config/
│   ├── config.json       # Xray config template
│   └── haproxy.cfg       # HAProxy config template
├── menu/
│   ├── menu.sh           # Dashboard utama
│   ├── m-vless.sh        # Kelola VLESS
│   ├── m-vmess.sh        # Kelola VMESS
│   ├── m-trojan.sh       # Kelola TROJAN
│   ├── m-setting.sh      # Pengaturan server
│   ├── m-backup.sh       # Backup & Restore
│   ├── menu-recovery.sh  # Recovery Center
│   ├── menu-unlock.sh    # Unlock user
│   ├── menu-lock.sh      # Lock user
│   ├── xp.sh             # Auto expiry checker (cron)
│   ├── cek-trafik.sh     # Monitor trafik real-time
│   ├── bot-daemon.sh     # Telegram bot handler
│   └── bot-webhook.sh    # Webhook receiver (authenticated)
├── sbin/
│   ├── algojo-wibu       # Auto IP limit enforcer
│   ├── algojo-kuota      # Auto bandwidth limit enforcer
│   ├── lock-user         # Lock user ke blocked routing
│   ├── unlock-user       # Unlock user dari blocked routing
│   └── unlocker-wibu     # Auto unlock scheduler
└── etcwibutunnel/
    └── lock.conf         # Lock duration config
```

---

## 🤖 Cara Mengaktifkan Bot Telegram

1. Buka Telegram → cari **@BotFather** → `/newbot`
2. Dapatkan **HTTP API Token**
3. Dapatkan **Chat ID** via @userinfobot
4. Di VPS: `menu` → **Settings** → **Setup Bot Telegram**
5. Masukkan Token & Chat ID → Bot aktif 24/7!

---

## 🗑️ Uninstall (Hapus Bersih)

```bash
bash <(curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh)
```

---

## 📞 Support & Kontak

- **WhatsApp** : [087757315408](https://wa.me/6287757315408)
- **Telegram** : [t.me/wibuvpn](https://t.me/wibuvpn)

> **Developed by WIBU TUNNELING Team**
> **Versi:** v4.0 Kurumi Patched (2026)
