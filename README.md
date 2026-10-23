# 🦋 WIBU TUNNELING v4.0

**Auto-install VPN script** berbasis Xray dengan Telegram bot monitoring. Satu command, VPN langsung jalan.

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)](https://github.com/WBVPN/wibutunnel)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)](https://github.com/WBVPN/wibutunnel)

---

## ✨ Fitur Utama

- **3 Protokol**: VLESS, VMESS, TROJAN (WS-TLS, WS-NTLS, gRPC)
- **Telegram Bot**: Buat/hapus akun, cek login, backup, semua dari HP
- **Auto Limit**: Kuota habis/expired = auto lock/delete
- **IP Tracking**: Deteksi multi-device login real-time
- **Trial Account**: Hardcoded 1 jam, auto-delete setelah expire/habis kuota
- **HAProxy + Xray**: Port 80/443 langsung aktif
- **Auto SSL**: Let's Encrypt via certbot, auto-renew

---

## 🚀 Instalasi (Fresh VPS)

```bash
# 1. Ambil domain dulu (A record ke IP VPS)
# 2. Login VPS sebagai root
# 3. Jalankan:

apt update && apt install -y wget curl
wget -O setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
bash setup.sh
```

**Butuh:**
- Ubuntu 20.04+ atau Debian 11+
- Domain aktif (untuk SSL)
- VPS minimal 1 CPU / 512 MB RAM

Setup nanya domain, Telegram bot token, dan chat ID — sisanya otomatis.

---

## 📱 Telegram Bot

Setup otomatis install bot polling. **Token & Chat ID wajib** diisi waktu install.

**Menu utama:**
- `VLESS / VMESS / TROJAN` → Buat, hapus, renew, cek login
- `SYSTEM` → Cek trafik global, info VPS, backup

**Trial account:**  
Format user `trial-xxxx` otomatis dapat 1 jam + 1 GB. Expired/habis = auto-delete + notif Telegram.

---

## 🔧 Manajemen

**SSH Menu:**
```bash
menu              # Menu utama
m-vless           # Kelola VLESS
m-vmess           # Kelola VMESS
m-trojan          # Kelola TROJAN
m-setting         # Update script, restart, setting bot
m-backup          # Backup/restore manual
```

**Service:**
```bash
systemctl status xray telegram-bot wibu-daemon algojo-expired
journalctl -u telegram-bot -f   # Log bot real-time
```

**Lokasi file:**
- Config: `/usr/local/etc/xray/config.json`
- Expiry: `/etc/xray/{vless,vmess,trojan}_exp.conf`
- Limit: `/etc/wibutunnel/limit_ip.db`, `limit_bw.db`
- Log: `/var/log/xray/access.log`, `error.log`

---

## 🛡️ Limit & Enforcement

| Daemon | Fungsi | Interval |
|--------|--------|----------|
| `algojo-wibu` | Limit IP | 60 detik |
| `algojo-kuota` | Limit bandwidth | 60 detik |
| `algojo-expired` | Delete expired | 5 detik |

User yang kena limit = auto-lock 15 menit, lalu unlock otomatis. Trial yang kena = langsung dihapus permanen.

**Lock config:** `/etc/wibutunnel/lock.conf` → ubah `LOCK_DURATION=15` (dalam menit)

---

## 🔄 Update

```bash
m-setting → [5] Update Script
# Download versi terbaru dari GitHub, overwrite file lokal, restart service
```

Atau manual:
```bash
cd /root/wibutunnel-repo
git pull origin main
bash setup.sh    # Re-run setup (aman, tidak hapus data user)
```

---

## 🗑️ Uninstall

```bash
cd /root/wibutunnel-repo
bash uninstall.sh
```

Hapus semua: xray, haproxy, bot, daemon, cron, service. **Backup disimpan** di `/root/wibutunnel-backup-YYYYMMDD-HHMMSS/` sebelum dihapus.

---

## 📊 Port & Protocol

| Port | Protocol | Path |
|------|----------|------|
| 443 | VLESS WS-TLS | `/vless` |
| 80 | VLESS WS-NTLS | `/vless-ntls` |
| 443 | VLESS gRPC | `vless` |
| 443 | VMESS WS-TLS | `/vmess` |
| 80 | VMESS WS-NTLS | `/vmess-ntls` |
| 443 | VMESS gRPC | `vmess` |
| 443 | TROJAN WS-TLS | `/trojan` |
| 443 | TROJAN gRPC | `trojan` |

HAProxy listen di 80/443, forward ke Xray di 10086-10092.

---

## 🐛 Troubleshooting

**Bot tidak respon:**
```bash
systemctl status telegram-bot
journalctl -u telegram-bot --since "5 minutes ago"
```

**User tidak bisa konek:**
```bash
systemctl status xray
xray -test -config /usr/local/etc/xray/config.json
tail -50 /var/log/xray/error.log
```

**Limit IP tidak jalan:**
- Cek `/var/log/xray/access.log` ada isi koneksi user (bukan cuma `[api -> api]`)
- Cek log level: `jq '.log.loglevel' /usr/local/etc/xray/config.json` harus `"info"`

**Trial tidak auto-delete:**
```bash
systemctl status algojo-expired
journalctl -u algojo-expired --since "1 minute ago"
```

---

## 📝 Changelog (v4.0 Latest)

- ✅ Fix repo drift `algojo-expired` (trial notif hilang di fresh install)
- ✅ Daemon `algojo-expired` kirim notif Telegram pas trial expire
- ✅ `uninstall.sh` stop semua service + backup file sebelum hapus
- ✅ `setup.sh` syntax-check script sebelum install (cegah install broken)
- ✅ Bot state file auto-clear setiap callback (fix stale command)
- ✅ Bot abort create/delete kalau `jq` edit config gagal (no zombie account)
- ✅ Xray log level `"info"` (default dulu `"warning"` → IP tracking mati)

---

## 📄 License

MIT — bebas pakai, modif, distribusi. Tapi **tidak ada garansi** — use at your own risk.

**Support:**
- 🐛 Issues: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)
- 💬 Telegram: [@wibuvpn](https://t.me/wibuvpn)

---

Made with 💜 by **WBVPN**
