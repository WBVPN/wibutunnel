# 🧱 WIBU TUNNELING v4.0 KURUMI

Script panel VPN all-in-one untuk VPS Linux (Ubuntu 20.04/22.04/Debian 11+).
Mendukung SSH Tunnel, VLESS, VMESS, TROJAN, dengan HAProxy sebagai single-entry
point di port 80 & 443, plus Telegram Bot untuk manajemen akun dari HP.

---

## ✨ FITUR UTAMA

### 🔗 Multi-Protokol (semua di port 80 & 443 via HAProxy)
- **SSH Tunnel** — Dropbear 2019.78 + WebSocket + SNI/SSH-over-TLS
- **VLESS** — WS TLS (443), WS non-TLS (80), gRPC
- **VMESS** — WS TLS (443), WS non-TLS (80), gRPC
- **TROJAN** — WS TLS (443), gRPC
- **UDP Gaming** — badvpn-udpgw port 7100-7600

### 💉 Mode Koneksi SSH
- **DIRECT** — tanpa payload (port 80)
- **SNI / SSH-over-TLS** — port 443
- **WEBSOCKET** — port 80 & 443
- **ENHANCED / DPI BYPASS** — payload PATCH + `[split]` untuk bypass DPI
  (terverifikasi jalan di port 80 & 443, termasuk lewat Cloudflare bug-host)

### 🤖 Telegram Bot
- Create / Trial / Renew / Delete / List akun semua protokol
- Cek login (IP online real-time), cek trafik global
- Detail link, ubah limit IP & kuota
- Backup VPS (kirim dokumen ke Telegram)
- **Notifikasi otomatis:**
  - 🔒 User dikunci karena melebihi limit IP (multi-login)
  - 🔒 User dikunci karena kuota habis
  - ⛔ User expired
- **Keamanan webhook:** validasi `X-Telegram-Bot-Api-Secret-Token`, fail-closed
  kalau secret belum dikonfigurasi (tidak ada orang yg bisa kontrol VPS tanpa token)

### 🛡️ Sistem Limit & Quota
- **Limit IP per akun** (SSH: batas sesi simultan; xray: deteksi IP unik dari log)
  → pelanggar dikunci otomatis 15 menit (bisa diatur)
- **Limit Kuota (GB) per akun** — tercatat per-user:
  - xray via API stats (`user>>>email>>>traffic`)
  - SSH via iptables `-m owner --uid-owner`
  → pelanggar dikunci permanen sampai limit dilonggarkan

### ⏱️ Auto-Expire & Recovery
- Akun expired otomatis: trial dihapus permanen, akun biasa dipindah ke Recovery
  Center (bisa diperpanjang lagi)
- Auto-reboot harian (bisa diatur jam)
- Auto-backup ke Telegram

### 🎨 Panel VPS
- Dashboard rapi: info ISP, kota, IP, domain, RAM, CPU, status service
- Manajemen akun per protokol
- Restart semua service, bersihkan cache/RAM
- Speedtest Ookla, cek bandwidth (vnStat)
- Edit banner SSH (HTML yg tampil sebelum prompt login)
- Ganti domain & renew SSL (Let's Encrypt) otomatis

---

## 🚀 CARA INSTALASI

Satu perintah di VPS baru (fresh install Ubuntu 20.04/22.04):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WBVPN/WIBUTUNNEL/main/setup.sh)
```

Atau manual:

```bash
apt-get update -y
apt-get install -y curl
curl -fsSL https://raw.githubusercontent.com/WBVPN/WIBUTUNNEL/main/setup.sh -o setup.sh
bash setup.sh
```

Setelah selesai, jalankan menu:

```bash
menu
```

### Setup Bot Telegram (setelah install)
1. Buat bot via [@BotFather](https://t.me/BotFather), ambil **BOT TOKEN**
2. Ambil **CHAT ID** kamu via [@userinfobot](https://t.me/userinfobot)
3. Di VPS: `menu` → **[5] Setting Server** → **[6] Setup Bot Telegram** → isi token & chat ID

Done. Bot langsung bisa dipakai dari Telegram.

---

## 📂 STRUKTUR REPO

```
setup.sh              # Installer utama
common.sh             # Fungsi bersama (user mgt, xray edit, safe helpers)
menu/
  menu.sh             # Dashboard utama
  m-ssh.sh            # Menu SSH
  m-vless.sh          # Menu VLESS
  m-vmess.sh          # Menu VMESS
  m-trojan.sh         # Menu TROJAN
  m-setting.sh        # Menu setting & monitor
  m-backup.sh         # Menu backup
  xp.sh               # Auto-expire engine
  bot-daemon.sh       # Telegram bot handler
  bot-webhook.sh      # Webhook receiver (systemd socket)
  menu-lock.sh        # Recovery Center (kunci)
  menu-unlock.sh      # Recovery Center (buka)
  menu-recovery.sh    # Daftar akun terkunci
  cek-trafik.sh       # Cek pemakaian kuota
sbin/
  algojo-wibu         # Daemon: limit IP & multi-login
  algojo-kuota        # Daemon: limit kuota
  lock-user           # Kunci user
  unlock-user         # Buka user
  unlocker-wibu       # Auto-unlock yg sudah lewat durasi
bin/
  ssh-tunnel-install  # Installer SSH stack (dropbear + ws + udpgw)
  ws-stunnel          # WebSocket → SSH bridge
config/
  haproxy.cfg         # Template config HAProxy
etcwibutunnel/        # File konfigurasi default
```

---

## 🔧 ARSITEKTUR SINGKAT

```
Client → HAProxy:80 / :443
           ├─ path /vless,/vmess,/trojan  → Xray (WS/gRPC)
           ├─ "SSH-2.0"                   → Dropbear (DIRECT)
           ├─ Upgrade: websocket          → ws-stunnel → Dropbear (WS-SSH)
           ├─ path /telehook              → Bot webhook
           └─ lainnya                     → ws-stunnel (raw, untuk ENHANCED payload)
```

Semua service dikelola systemd: `xray`, `haproxy`, `dropbear`, `ws-stunnel`,
`wibu-daemon` (algojo loop), `telegram-webhook.socket`.

---

## ⚠️ SYARAT

- VPS Linux: Ubuntu 20.04 / 22.04 / Debian 11+ (x86_64 atau aarch64)
- RAM minimal 512MB (rekomendasi 1GB+)
- Domain sudah di-A record ke IP VPS (untuk SSL & SNI)
- Port 80, 443, 109, 22 terbuka

---

## 📝 CATATAN UPDATE

Update script via menu: `menu` → **[5] Setting Server** → **[5] Update Script**.
Backup otomatis dibuat di `/etc/wibutunnel/backup/pre-update-*` sebelum update.

---

<p align="center">WIBU TUNNELING v4.0 KURUMI — Powered by WIBU VPN</p>
