<div align="center">

# 🧱 WIBU TUNNELING
### Panel VPN All-in-One untuk VPS Linux

**v4.0 KURUMI** · Ubuntu 20.04/22.04 · Debian 11+

SSH Tunnel · VLESS · VMESS · TROJAN · UDP Gaming · Telegram Bot

[![Status](https://img.shields.io/badge/Status-Production-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-4.0%20KURUMI-blue)]()
[![Protocols](https://img.shields.io/badge/Protocols-SSH%20%7C%20VLESS%20%7C%20VMESS%20%7C%20TROJAN-orange)]()

</div>

---

## 📋 Daftar Isi

- [✨ Fitur](#-fitur)
- [🚀 Instalasi](#-instalasi)
- [🤖 Setup Telegram Bot](#-setup-telegram-bot)
- [📂 Struktur Repo](#-struktur-repo)
- [🔧 Arsitektur](#-arsitektur)
- [🛡️ Limit & Quota](#-limit--quota)
- [📦 Update & Backup](#-update--backup)
- [🧩 Uninstall](#-uninstall)
- [⚠️ Syarat](#-syarat)

---

## ✨ Fitur

### 🔗 Multi-Protokol — semua di port 80 & 443 (HAProxy)

| Protokol | Mode | Port |
|---|---|---|
| **SSH Tunnel** | Dropbear 2019.78 + WebSocket + SNI/SSH-over-TLS | 80, 443, 109, 143 |
| **VLESS** | WS TLS · WS non-TLS · gRPC | 443, 80 |
| **VMESS** | WS TLS · WS non-TLS · gRPC | 443, 80 |
| **TROJAN** | WS TLS · gRPC | 443 |
| **UDP Gaming** | badvpn-udpgw | 7100–7600 |

### 💉 Mode Koneksi SSH

- **DIRECT** — tanpa payload (port 80)
- **SNI / SSH-over-TLS** — port 443
- **WEBSOCKET** — port 80 & 443
- **ENHANCED / DPI BYPASS** — payload `PATCH` + `[split]` untuk bypass DPI
  (terverifikasi di port 80 & 443, termasuk lewat bug-host Cloudflare)

### 🤖 Telegram Bot

Manajemen akun langsung dari HP — tanpa SSH ke VPS:

- **Akun:** Create · Trial · Renew · Delete · List (semua protokol)
- **Monitoring:** cek IP online real-time, cek trafik global
- **Konfigurasi:** detail link, ubah limit IP & kuota
- **Backup:** kirim backup VPS langsung ke chat Telegram

**Notifikasi otomatis:**

- 🔒 User dikunci — melebihi limit IP (multi-login)
- 🔒 User dikunci — kuota habis
- ⛔ User expired

**Keamanan webhook:** setiap request divalidasi lewat `X-Telegram-Bot-Api-Secret-Token` dengan kebijakan **fail-closed** — kalau secret belum dikonfigurasi, semua request ditolak. Tidak ada satu pun yang bisa mengendalikan VPS tanpa token.

### 🎨 Panel VPS

- Dashboard: info ISP, kota, IP, domain, RAM, CPU, status service real-time
- Restart semua service · bersihkan cache/RAM
- Speedtest Ookla · cek bandwidth (vnStat)
- Edit banner SSH (HTML tampil sebelum prompt login)
- Ganti domain & renew SSL (Let's Encrypt) otomatis

---

## 🚀 Instalasi

**Satu perintah** di VPS baru (fresh Ubuntu 20.04/22.04):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh)
```

Atau cara manual:

```bash
apt-get update -y && apt-get install -y curl
curl -fsSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh -o setup.sh
bash setup.sh
```

Setelah selesai, masuk ke menu:

```bash
menu
```

> 💡 Installer otomatis memasang: Xray-core, HAProxy, Dropbear 2019.78,
> badvpn-udpgw, ws-stunnel (WebSocket bridge), jq, certbot, vnStat, dan
> semua menu/service pendukung.

---

## 🤖 Deploy dengan AI (Codex / agent)

Perintah singkat untuk agent AI agar bisa memasang ulang proyek ini dari nol:

```text
1. clone repo: git clone https://github.com/WBVPN/wibutunnel /opt/wibutunnel
2. jalankan installer utama sebagai root: bash /opt/wibutunnel/setup.sh
3. installer bersifat idempoten — aman dijalankan ulang untuk memperbaiki
   komponen yg gagal (dropbear, ws-stunnel, badvpn-udpgw, haproxy, xray).
4. per komponen bisa di-reinstall sendiri via /usr/local/bin/ssh-tunnel-install
   (stack SSH) atau menu [5] Setting Server.
5. cek kesehatan: systemctl is-active haproxy xray dropbear
   badvpn-udpgw@7100 ; log build udpgw di /var/log/wibutunnel-udpgw-build.log
6. masuk menu interaktif: menu
```

Catatan untuk AI: host key dropbear HARUS format dropbear asli (dropbearkey /
dropbearconvert) — bukan OpenSSH/PEM. Installer sudah memvalidasi ini otomatis.

---

## 🤖 Setup Telegram Bot

Lakukan setelah instalasi selesai:

1. Buat bot via [@BotFather](https://t.me/BotFather) → salin **BOT TOKEN**
2. Dapatkan **CHAT ID** kamu via [@userinfobot](https://t.me/userinfobot)
3. Di VPS jalankan `menu` → **[5] Setting Server** → **[6] Setup Bot Telegram**
4. Masukkan token & chat ID — token divalidasi langsung ke API Telegram,
   token salah akan ditolak sebelum disimpan

Selesai. Bot langsung aktif dan bisa dipakai dari Telegram.

---

## 📂 Struktur Repo

```
setup.sh                  # Installer utama
uninstall.sh              # Uninstaller lengkap
common.sh                 # Fungsi bersama (user mgt, xray edit, safe helpers)
izin.txt                  # Lisensi/izin penggunaan
├── menu/
│   ├── menu.sh           # Dashboard utama
│   ├── m-ssh.sh          # Menu SSH Tunnel
│   ├── m-vless.sh        # Menu VLESS
│   ├── m-vmess.sh        # Menu VMESS
│   ├── m-trojan.sh       # Menu TROJAN
│   ├── m-setting.sh      # Menu setting & monitoring
│   ├── m-backup.sh       # Menu backup
│   ├── xp.sh             # Auto-expire engine (cron)
│   ├── bot-daemon.sh     # Handler Telegram bot
│   ├── bot-webhook.sh    # Webhook receiver (systemd socket)
│   ├── menu-lock.sh      # Recovery Center: kunci
│   ├── menu-unlock.sh    # Recovery Center: buka
│   ├── menu-recovery.sh  # Daftar akun terkunci
│   └── cek-trafik.sh     # Cek pemakaian kuota
├── sbin/
│   ├── algojo-wibu       # Daemon: limit IP & multi-login
│   ├── algojo-kuota      # Daemon: limit kuota per-user
│   ├── lock-user         # Kunci user
│   ├── unlock-user       # Buka user
│   └── unlocker-wibu     # Auto-unlock setelah durasi habis
├── bin/
│   ├── ssh-tunnel-install# Installer SSH stack (dropbear + ws + udpgw)
│   └── ws-stunnel        # WebSocket → SSH bridge (Python)
izin.txt                  # Lisensi/izin penggunaan (cek IP VPS)
```

---

## 🔧 Arsitektur

Semua protokol dilayani dari **satu titik masuk** — HAProxy di port 80 & 443:

```
Client ──► HAProxy :80 / :443
              ├─ path /vless,/vmess,/trojan  ──► Xray (WS / gRPC)
              ├─ "SSH-2.0"                   ──► Dropbear (DIRECT)
              ├─ Upgrade: websocket          ──► ws-stunnel ──► Dropbear (WS-SSH)
              ├─ path /telehook              ──► Bot webhook (systemd socket)
              └─ lainnya                     ──► ws-stunnel (raw, ENHANCED payload)
```

**Service systemd:**

| Service | Fungsi |
|---|---|
| `xray` | VLESS / VMESS / TROJAN |
| `haproxy` | Single-entry port 80 & 443 |
| `dropbear` | SSH tunnel (109, 143) |
| `ws-stunnel` | WebSocket → SSH bridge |
| `wibu-daemon` | Loop algojo (limit IP + kuota, tiap 10 detik) |
| `telegram-webhook.socket` | Penerima webhook bot |

**Cron:** auto-expire (`xp`, tiap menit) · auto-unlock (`unlocker-wibu`) ·
watchdog · renew SSL · auto-reboot harian.

---

## 🛡️ Limit & Quota

| Fitur | Mekanisme | Sanksi |
|---|---|---|
| **Limit IP** | SSH: batas sesi simultan · xray: deteksi IP unik | Kunci otomatis (default 15 menit, dapat diatur) |
| **Limit Kuota (GB)** | xray: API stats `user>>>email>>>traffic` · SSH: iptables `-m owner --uid-owner` | Kunci permanen sampai limit dilonggarkan |
| **Auto-Expire** | Trial dihapus permanen · akun biasa masuk Recovery Center | Bisa diperpanjang lagi |

Akun yang melanggar dipindahkan ke rule `blocked` di routing Xray — koneksi
aktif diputus langsung (`pkill`), dan notifikasi dikirim ke Telegram.

---

## 📦 Update & Backup

**Update script:**

```
menu ──► [5] Setting Server ──► [5] Update Script (Safe Mode)
```

Sebelum update, **semua** file di `/usr/local/bin`, `/usr/local/sbin`, dan
config Xray di-backup otomatis ke `/etc/wibutunnel/backup/pre-update-*`.
Download divalidasi: file kosong atau tanpa shebang (404/429) akan ditolak.

**Backup berkala:** bisa dijadwalkan dari menu backup — hasil dikirim ke chat
Telegram.

---

## 🧩 Uninstall

Menghapus total instalasi beserta jejaknya (service, config, cron, user VPN,
swap, rule iptables, file biner):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh)
```

> ⚠️ Tindakan ini tidak dapat dibatalkan. Backup data penting dulu.

---

## ⚠️ Syarat

- **OS:** Ubuntu 20.04 / 22.04 / Debian 11+ (x86_64 atau aarch64)
- **RAM:** minimal 512 MB (rekomendasi 1 GB+)
- **Domain:** sudah di-A record ke IP VPS (untuk SSL & SNI)
- **Port terbuka:** 80, 443, 109, 143, 22
- **Akses root**

---

<div align="center">

**WIBU TUNNELING v4.0 KURUMI** — Powered by WIBU VPN

Jika proyek ini membantu, ⭐️ repo ini di GitHub.

</div>
