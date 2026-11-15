# 🦋 WIBUTUNNEL v4.0.6-fixed

Auto-install VPN panel berbasis Xray dengan Telegram bot monitoring. Satu command, VPN langsung jalan.

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)](https://github.com/WBVPN/wibutunnel)
[![Version](https://img.shields.io/badge/Version-v4.0.6-fixed-blue.svg)](https://github.com/WBVPN/wibutunnel)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)](https://github.com/WBVPN/wibutunnel)

---

## ✨ Fitur

- 🔐 **VLESS, VMESS, TROJAN, SSH** - 3 protokol VPN + SSH tunnel (Dropbear, WebSocket, Direct 80/443, Split Payload)
- 🛠️ **Auto-Repair** - Self-healing stack: basmi parasit port 80/443, fix SSL HAProxy, validasi Xray JSON, regenerate SSH keys
- ⚡ **Zero-Downtime Sync** - Tambah/hapus user live via gRPC API tanpa restart Xray
- 🤖 **Telegram Bot** - Kelola akun, lock/unlock, backup dari HP
- 🎯 **Auto Enforcement** - Kuota/expired = lock otomatis + notif real-time
- 🔄 **Recovery System** - User expired disimpan, bisa restore dengan limit baru

---

## 🚀 Instalasi

### Prerequisites
- Ubuntu 20.04+ / Debian 11+
- Domain dengan A record ke IP VPS
- Root access
- IP VPS terdaftar di `izin.txt` (hubungi @wibuvpn)

### One-Liner
```bash
curl -4 -fsSL -o setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/v4.0.6-fixed/setup.sh
sha256sum setup.sh     # harap: 08a33a87dac41fee39950fd0dca30e96db56fac3612f9efbf0671f9fa82bd1fe
bash setup.sh
```


`setup.sh` mengambil kode (`menu/*`, `sbin/*`, `common.sh`) dari **tag rilis** (bukan `main`) dan
memverifikasi sha256 setiap berkas terhadap `SHA256SUMS`; hash tidak cocok = instalasi DIHENTIKAN.
Ganti ref: `WIBU_REF=v4.0.6-fixed bash setup.sh` · bypass sadar: `WIBUTUNNEL_ALLOW_UNVERIFIED=1`.

> **Penting — VPS dengan IPv6 "blackhole" (umum di Indonesia):** perintah di atas sengaja memakai
> `curl -4` karena `wget` bisa **menggantung tanpa batas** dan `curl` tanpa `-4` menunggu ~24 detik
> per unduhan (installer ada 25 unduhan). Kalau GitHub mentok dari jaringanmu, pakai mirror:
> `https://cdn.jsdelivr.net/gh/WBVPN/wibutunnel@v4.0.6-fixed/setup.sh`.

**Instalasi versi rilis (terpin):** perintah di atas mengambil dari tag `v4.0.6-fixed`.
Bila ingin versi terbaru dari cabang `main`, ganti `v4.0.6-fixed` menjadi `main` (hash `setup.sh` akan berbeda).

> **Instalasi baru:** IP VPS harus terdaftar di `izin.txt` (hubungi @wibuvpn). Tanpa itu instalasi
> berhenti di pemeriksaan lisensi — perilaku normal, bukan error jaringan.
**Proses:** Install dependencies → SSL cert → Xray config → Telegram bot → Services. Waktu: ~5-10 menit.

---

## 📱 Telegram Bot

Bot pakai **long polling** (tidak perlu SSL/domain).

**Dapatkan Credentials:**
1. Token: Chat `/newbot` ke [@BotFather](https://t.me/BotFather)
2. Chat ID: Chat `/start` ke [@userinfobot](https://t.me/userinfobot)

**Menu:** VLESS/VMESS/TROJAN (create, delete, renew, cek login, limit IP/BW), CEK TRAFIK, BACKUP, INFO VPS.

**Trial Account:** Format `trial-xxxx`, expired 1 jam, quota 1GB, auto-delete permanen.

---

## 🔧 Command Line

### Menu Utama
```bash
menu              # Dashboard & status stack
m-vless           # Kelola VLESS
m-vmess           # Kelola VMESS
m-trojan          # Kelola TROJAN
m-ssh             # Kelola SSH (Cek Login: [9], Banner: [12], Respon WS: [13])
m-setting         # Settings (Auto-repair: [1], Update: [5])
m-backup          # Backup & restore (password wajib, validasi isi arsip)
cek-trafik        # Monitor trafik & IP per user
menu-lock         # Kunci massal
menu-unlock       # Buka kunci massal
menu-recovery     # Restore user dari recovery
xp                # Kelola masa aktif (add/reduce hari)
wibu-repair       # Diagnostic & repair stack
```

Daemon pendukung (dipasang di `/usr/local/sbin/`):
`algojo-wibu` `algojo-kuota` `algojo-ssh` `algojo-expired` `algojo-expired-daemon`
`lock-user` `unlock-user` `unlocker-wibu` `ws-stunnel` `wibu-repair` `wibu-daemon`

### Service
Unit yang dikelola panel (9):
```bash
systemctl status xray haproxy dropbear ws-stunnel telegram-bot \
                 algojo-expired wibu-daemon network-tune wibutunnel-firewall
journalctl -u telegram-bot -f
journalctl -u wibu-daemon --since "10 minutes ago"
tail -f /var/log/xray/access.log        # izin 0640 (tidak lagi terbaca semua user)
```
`wibutunnel-firewall` menegakkan ulang aturan "hanya root boleh ke API Xray (:10085)" setiap kali boot.

### File Penting
```
/usr/local/etc/xray/config.json     # Xray config (kanonik; /etc/xray/config.json = symlink)
/etc/wibutunnel/version             # Penanda versi (4.0.6-fixed)
/etc/wibutunnel/izin.txt            # Daftar lisensi lokal (opsional)
/etc/xray/{vless,vmess,trojan,ssh}_exp.conf   # User expiry
/etc/wibutunnel/bot.conf            # Telegram credentials
/etc/wibutunnel/limit_ip.db         # IP limit (sesi simultan)
/etc/wibutunnel/limit_bw.db         # Bandwidth limit (GB)
/etc/wibutunnel/locked_users.db     # Locked users
/etc/wibutunnel/recovery/           # Recovery JSON
/usr/local/sbin/algojo-*            # Enforcement daemons
/usr/local/sbin/wibu-repair         # Auto-repair engine
```

---

## 🛡️ Enforcement

| Daemon | Fungsi | Interval | Action |
|--------|--------|----------|--------|
| `algojo-ssh` | SSH session limit | 60s | Lock 15 min auto-unlock |
| `algojo-wibu` | IP limit (Xray) | 60s | Lock 15 min auto-unlock |
| `algojo-kuota` | Bandwidth limit | 60s | Delete + recovery (regular) / delete (trial) |
| `algojo-expired` | Expiry check | 5s | Delete + recovery (regular) / delete (trial) |

**Regular:** Lock temporary, recovery room saat expired/habis quota.  
**Trial:** Delete permanen, no recovery.

---

## 🔄 Recovery

User regular expired/habis quota masuk recovery room, bisa restore:
```bash
menu-recovery     # CLI
# Atau: Telegram bot → Protokol → Recovery
```
Input expiry baru, IP limit, bandwidth → restored + notif Telegram.

---

## 🔄 Update

```bash
m-setting   # Settings → [5] Update Script (verifikasi SHA256SUMS)
            # hash tidak cocok = update DITOLAK (fail-closed); cadangan disimpan
            # ke /usr/local/share/wibutunnel/backup/ sebelum menimpa
```

---

## 🗑️ Uninstall

```bash
curl -4 -fsSL -o uninstall.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/v4.0.6-fixed/uninstall.sh
sha256sum uninstall.sh   # harap: e4f8639b3b9eeba9ccd78f2246b2c7ae4d04a98099fb503fafd6be61bf548654
bash uninstall.sh
```

> Hindari `curl … | bash` untuk uninstall: skrip ini menghapus layanan/data, jadi periksa dulu.
> Installer Xray di dalam `uninstall.sh` juga diverifikasi sha256 sebelum dijalankan.
Backup otomatis ke `/root/wibutunnel-backup-YYYYMMDD-HHMMSS/` sebelum hapus.

---

## 🔐 Keamanan (4.0.6-fixed)

- **Rantai pasang diverifikasi.** `setup.sh` mengambil `menu/*`, `sbin/*`, `common.sh` dari **tag rilis**
  (bukan `main`) dan membandingkan sha256 setiap berkas dengan `SHA256SUMS`; tidak cocok = instalasi **dihentikan**.
  Installer Xray juga dipin hash-nya. Bypass sadar hanya `WIBUTUNNEL_ALLOW_UNVERIFIED=1` (dengan peringatan + log).
- **Update fail-closed.** `m-setting → [5]` memverifikasi manifest sebelum menimpa, dan menyimpan cadangan
  ke `/usr/local/share/wibutunnel/backup/`.
- **API Xray (:10085) hanya untuk root.** Aturan iptables `-m owner ! --uid-owner 0 … REJECT` + unit
  `wibutunnel-firewall` yang menegakkan ulang setelah reboot — mencegah satu pelanggan mengubah/menghapus user lain.
- **Izin berkas:** `/etc/wibutunnel` 700 · `*_exp.conf` 600 · `/etc/xray` 750 · `/var/log/xray` 750 dengan log 0640
  (daftar pelanggan & IP tidak lagi terbaca semua user lokal).
- **Token bot tidak lagi lewat `argv`** (dibaca `curl -K -`), jadi tidak terlihat di `ps` oleh user lokal.
- **Restore backup:** wajib `https`, wajib password, isi arsip divalidasi (tolak path absolut/`..`), ekstrak di `mktemp -d`.
- **Akun pelanggan tetap ber-shell** (perilaku produk). Ingin mode nologin? Pasang dengan `WIBU_SSH_NOLOGIN=1`.
- ⚠️ **Catatan lisensi:** pemeriksaan lisensi menerima juga `./izin.txt` atau `/etc/wibutunnel/izin.txt` yang memuat
  IP VPS — jadi gate ini **penghalang, bukan pengaman** (siapa pun yang punya root di VPS-nya bisa melewatinya).
  Rincian temuan & perbaikan: [`docs/SECURITY_FIXES.md`](docs/SECURITY_FIXES.md).

---

## 📊 Network

### Ports

| Port | Protocol | Path | Backend |
|------|----------|------|---------|
| 443/80 | VLESS | `/vless` | WS-TLS/WS |
| 443 | VLESS | `vless` | gRPC-TLS |
| 443/80 | VMESS | `/vmess` | WS-TLS/WS |
| 443 | VMESS | `vmess` | gRPC-TLS |
| 443 | TROJAN | `/trojan` | WS-TLS |
| 443 | TROJAN | `trojan` | gRPC-TLS |
| 443/80 | SSH Direct | `SSH-` | Dropbear :143 |
| 443/80 | SSH WS | `/` | ws-stunnel :10015 → Dropbear :109 |

### Architecture
```
Internet → HAProxy (80/443)
            ├→ Xray :10086-10093 (9 inbounds)
            ├→ Dropbear :143 (Direct SSH)
            └→ ws-stunnel :10015 → Dropbear :109 (SSH WS)
```

---

## 🧪 Pengujian

```bash
bash tests/test_hardening.sh        # 38 cek keamanan, non-destruktif (tidak menyentuh sistem)
sha256sum -c SHA256SUMS             # integritas seluruh berkas rilis
```

> ⚠️ Jangan jalankan suite lama (`tests/test_auto_repair.sh`, `test_xray_api_sync.sh`,
> `test_expiry_and_xp.sh`, dll) di VPS produksi — sebagian menulis `/etc` dan me-restart stack.
> Prosedur aman ada di [`docs/STAGING_TEST.md`](docs/STAGING_TEST.md).

---

## 🐛 Troubleshooting

### Auto-Repair
```bash
wibu-repair
# Atau: m-setting → [1]
```
Fix: Port parasit, SSL HAProxy, Xray JSON corrupt, SSH keys, service restart.

### Manual Debug

**Bot tidak respon:**
```bash
systemctl status telegram-bot
journalctl -u telegram-bot --since "5 minutes ago"
source /etc/wibutunnel/bot.conf
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq .
```

**User tidak bisa connect:**
```bash
systemctl status xray
xray -test -config /etc/xray/config.json
tail -50 /var/log/xray/error.log
jq '.inbounds[1].settings.clients[]? | .email' /etc/xray/config.json
```

**IP limit tidak jalan:**
```bash
jq '.log.loglevel' /etc/xray/config.json  # Harus "info"
tail -20 /var/log/xray/access.log | grep "accepted"
systemctl status wibu-daemon
```

**Trial tidak auto-delete:**
```bash
systemctl status algojo-expired
journalctl -u algojo-expired --since "1 minute ago"
cat /etc/xray/vless_exp.conf  # Format: username:YYYY-MM-DD HH:MM:SS
```

---

## 📝 Changelog

### v4.0.6-fixed (2026-11-15) - Patch keamanan
- Rantai pasang: `curl | bash` dihapus, ref dipin ke tag, semua unduhan diverifikasi `SHA256SUMS` (fail-closed)
- Update menu fail-closed + cadangan rollback
- API Xray `:10085` diblokir untuk non-root (iptables owner-match + unit firewall persisten)
- Token bot keluar dari `argv` (11 titik → `curl -K -`)
- Restore backup: password wajib + validasi entri + `mktemp`; backup pakai password acak
- Izin berkas diperketat (`*_exp.conf` 600, `/etc/xray` 750, log 0640)
- Tulis DB ber-`flock`, guard oktal `10#`, hitungan trafik diperbaiki, resolver indeks inbound via tag
- Penjaga EOF pada input domain (sebelumnya loop tanpa henti bila input habis)
- Alat baru: `SHA256SUMS`, `tests/test_hardening.sh` (38 cek non-destruktif), `docs/`

### v4.0.6 KURUMI (2026-11-02) - Production Ready

**🛠️ Auto-Repair & Diagnostic:**
- Self-healing stack: port parasit, SSL HAProxy, Xray JSON, SSH keys
- Anti-wipe safety guard: validasi backup ketat
- Dynamic HAProxy template (`${__DOMAIN__}`)

**⚡ Zero-Downtime & Enforcement:**
- User sync live via gRPC API (`127.0.0.1:10085`)
- Atomic DB locking (`flock -w 10`)
- Enforcement harmonization: reguler → recovery, trial → purge
- Auto-restore unlock dari sidecar JSON

**🔒 SSH Module:**
- Dropbear publik (109, 143) + dropbear lokal `127.0.0.1:2222` (backend HAProxy), ws-stunnel (10015),
  HAProxy multiplexer (80/443). Port 22 tetap sshd admin, dengan rate-limit anti-bruteforce
- Enhanced split-payload (`HTTP/ 69`)
- SSH session enforcement (akurat untuk relay loopback)
- Strict license validation

**📊 Dashboard:**
- Multi-service live monitor (`Online` / `Degraded`)
- Clean SSH menu (hapus opsi usang)
- 11 test suite lama

**🐛 Critical Fixes:**
- SSH-1: Parsing `ss` benar ($3/$5, PID via ps, filter dropbear|sshd)
- SSH-2: Metrik sesi aktif (bukan IP unik, akurat untuk relay 127.0.0.1)
- SSH-3: Oktal guard `10#` (08/09/010)
- SSH-4: Menu Cek Login SSH [9] pakai `ssh_session_count`
- REG-SSH: Auto-unlock regression (field3 timestamp > 0, bukan 0 permanen)

---

## 🤝 Contributing

Fork → Branch → Commit → Push → Pull Request

---

## 📄 License

MIT License - bebas pakai, modif, distribusi.  
**Disclaimer:** No warranty. Use at your own risk.

---

## 💬 Support

- 🐛 Issues: [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues)
- 💬 Telegram: [@wibuvpn](https://t.me/wibuvpn)
- 📧 Email: wibuvpnstore@gmail.com

---

<div align="center">

**Made with 💜 by WBVPN**

*"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya." - Haku*

⭐ Star this repo if you find it useful!

</div>


## 🔐 Patch keamanan (2026-11-15)
Rilis ini menutup temuan audit: rantai pasok (`curl|bash`) dipin+verifikasi hash, update fail-closed
(`SHA256SUMS`), API Xray 10085 diblokir untuk non-root, token bot keluar dari `argv`, restore backup
wajib password + validasi entri, izin berkas diperketat, dan tulis DB ber-`flock`.
Rincian + cara verifikasi: **`docs/SECURITY_FIXES.md`** · uji: `bash tests/test_hardening.sh`.
