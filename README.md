# 🦋 WIBUTUNNEL v4.0.8

Panel VPN Xray **auto-install** + bot Telegram. Satu perintah, VPN langsung jalan.

![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)
![Version](https://img.shields.io/badge/Version-v4.0.8-blue.svg)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)

---

## ⚡ Instalasi — satu baris

```bash
curl -4 -fsSL https://wibu.loli.web.id/i | bash
```

Cek dulu isi skripnya (disarankan):

```bash
curl -4 -fsSL https://wibu.loli.web.id/i | less
curl -4 -fsSL https://wibu.loli.web.id/sha         # hash rilis
```

Skrip pendek itu mengunduh `setup.sh` dari **tag rilis v4.0.8**, **memverifikasi sha256-nya**, baru menjalankan.
Hash tidak cocok = berhenti sebelum memasang apa pun. `WIBU_BOOTSTRAP_ONLY=1` untuk sekadar verifikasi.

| Syarat | |
|---|---|
| OS | Ubuntu 20.04+ / Debian 11+ |
| Domain | A record mengarah ke IP VPS *(tanpa AAAA)* |
| Akses | root |
| Lisensi | IP VPS terdaftar di `izin.txt` ([@wibuvpn](https://t.me/wibuvpn)) |

**Murni GitHub (tanpa link pendek)** — sama-sama satu baris, aset dari Release resmi:

```bash
curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash
```

<details>
<summary>🔐 Cara manual (unduh → verifikasi → pasang) — atau kalau link pendek mati</summary>

**Pasang**

```bash
curl -4 -fsSL -o setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/v4.0.8/setup.sh
sha256sum setup.sh     # harap: 403f001787db4a2a6978195b128f354e0139fff3c9b0694e98c5fb476e59035d
bash setup.sh
```

**Hapus**

```bash
curl -4 -fsSL -o uninstall.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/v4.0.8/uninstall.sh
sha256sum uninstall.sh   # harap: 310e0fa29f3bcac3d74ac76b86cfa05edd99a7c5c6078398f26112663823eebe
bash uninstall.sh        # cadangan otomatis ke /root/wibutunnel-backup-*/
```

</details>

- Semua berkas diambil dari **tag rilis `v4.0.8`** (bukan `main`) supaya kode yang kamu pasang tidak berubah di tengah jalan.
- `setup.sh` memverifikasi sha256 tiap berkas terhadap `SHA256SUMS` dari tag yang sama; tidak cocok = instalasi DIHENTIKAN.
- Tag lain: `WIBU_REF=v4.0.7 bash setup.sh` · bypass sadar: `WIBUTUNNEL_ALLOW_UNVERIFIED=1`.
- **Update menu ([5]) mengikuti rilis terbaru** (`main`) + verifikasi sha256 - jadi perbaikan setelah rilis tetap sampai; installer tetap memakai tag beku agar reproducible.

> ⏱️ ~5-10 menit. **VPS IPv6 "blackhole" (umum di Indonesia):** semua perintah memakai `curl -4`;
> `wget` bisa menggantung tanpa batas. GitHub mentok? Link pendek otomatis pakai mirror jsDelivr.
>
> **Instalasi baru:** IP VPS harus terdaftar di `izin.txt` (hubungi @wibuvpn). Tanpa itu instalasi
> berhenti di pemeriksaan lisensi - perilaku normal, bukan error jaringan.

## ✨ Fitur

| | |
|---|---|
| 🔐 **4 protokol** | VLESS · VMESS · TROJAN · SSH (Dropbear, WS, Direct 80/443, split payload) |
| ⚡ **Live sync** | Tambah/hapus akun tanpa restart Xray (gRPC API) |
| 🎯 **Enforcement** | Kuota / expired / limit IP → kunci otomatis + notifikasi |
| 💾 **Recovery** | Akun expired disimpan, bisa dipulihkan dengan limit baru |
| 🛠️ **Auto-repair** | Bersihkan parasit port, SSL, config Xray, host key SSH |
| 🤖 **Bot Telegram** | Kelola akun, backup, cek trafik dari HP |
| 🕵️ **Audit akun** | Deteksi akun tanpa masa aktif (gratis selamanya) |

---

## 🤖 Bot Telegram

Metode: **long polling** (tanpa webhook / SSL tambahan).

1. Token → `/newbot` ke [@BotFather](https://t.me/BotFather)
2. Chat ID → `/start` ke [@userinfobot](https://t.me/userinfobot)
3. Pasang: `menu` → Setting → **[6] Setup Bot Telegram**

Trial: format `trial-xxxx` · 1 jam · 1 GB · hapus permanen saat habis.

---

## 🧰 Perintah

| Perintah | Fungsi |
|---|---|
| `menu` | Dashboard & status stack |
| `m-vless` `m-vmess` `m-trojan` | Kelola akun per protokol |
| `m-ssh` | SSH (cek login [9], banner [12], respon WS [13]) |
| `m-setting` | Setting (auto-repair [1], update [5], bot [6]) |
| `m-backup` | Backup & restore (password wajib) |
| `cek-trafik` | Trafik & IP per akun |
| `menu-lock` `menu-unlock` | Kunci / buka kunci massal |
| `menu-recovery` | Pulihkan akun dari recovery |
| `xp` | Tambah / kurangi masa aktif |
| `wibu-repair` | Diagnosa & perbaikan stack |
| `wibu-audit-akun` | Audit akun tanpa masa aktif (`--fix` = karantina) |

**Daemon** (`/usr/local/sbin/`): `algojo-wibu` `algojo-kuota` `algojo-ssh` `algojo-expired`
`algojo-expired-daemon` `lock-user` `unlock-user` `unlocker-wibu` `ws-stunnel` `wibu-daemon` `wibu-repair`

---

## ⚙️ Enforcement

| Daemon | Cek | Aksi |
|---|---|---|
| `algojo-ssh` | limit sesi SSH | kunci 15 menit (auto-unlock) |
| `algojo-wibu` | limit IP Xray | kunci 15 menit (auto-unlock) |
| `algojo-kuota` | kuota bandwidth | akun biasa → recovery · trial → hapus |
| `algojo-expired` | masa aktif | akun biasa → recovery · trial → hapus |

---

## 🩺 Service & Berkas

```bash
systemctl status xray haproxy dropbear ws-stunnel telegram-bot \
                 algojo-expired wibu-daemon network-tune wibutunnel-firewall
journalctl -u telegram-bot -f
wibu-audit-akun                      # akun tanpa masa aktif
tail -f /var/log/xray/access.log
```

```
/usr/local/etc/xray/config.json   # config Xray (kanonik; /etc/xray/config.json = symlink)
/etc/xray/*_exp.conf              # masa aktif akun (600)
/etc/wibutunnel/bot.conf          # token bot (600)
/etc/wibutunnel/limit_ip.db       # limit IP · limit_bw.db = kuota · locked_users.db = terkunci
/etc/wibutunnel/recovery/         # sidik akun expired (bisa dipulihkan)
/etc/wibutunnel/izin.txt          # salinan lisensi resmi (cadangan saat offline)
```

---

## 🌐 Port & Alur

| Port | Untuk |
|---|---|
| 443 / 80 | HAProxy → VLESS · VMESS · TROJAN · SSH direct · SSH WS |
| 143 · 109 | Dropbear (SSH publik) |
| 22 | sshd admin (rate-limit anti-bruteforce) |
| 10015 | ws-stunnel (lokal) |
| 10085–10093 | API & inbound Xray (**lokal, hanya root**) |

```
Internet → HAProxy (80/443)
             ├→ Xray (inbound 10086–10093)
             ├→ Dropbear 143            (SSH direct)
             └→ ws-stunnel 10015 → Dropbear 109  (SSH via WS)
```

---

## 🔐 Keamanan

- **Rantai pasang terverifikasi.** Semua berkas diambil dari **tag rilis** + dicek `SHA256SUMS`; gagal = berhenti.
- **Update fail-closed.** Manifest diambil dari **API GitHub** (CDN raw bisa menyajikan versi lama) + cadangan sebelum menimpa.
- **API Xray `:10085` hanya root.** Aturan iptables + unit & timer yang menegakkan ulang setiap boot.
- **Izin ketat:** `*_exp.conf` 600 · config 640 `root:xray` · `/etc/wibutunnel` 700 · log 0640.
- **Lisensi:** IP tak terdaftar → ditolak · lisensi exp → **menu tidak bisa dibuka** · offline maks 7 hari.
- **Backup:** wajib `https` + password, isi arsip divalidasi, `bot.conf` ikut (restore mematikan bot agar token tidak bentrok).
- **Token bot** tidak lewat `argv` (tidak terlihat di `ps`); gagal polling (401/409) kini tercatat di log.

> Jujur soal batasnya: pemegang **root** di VPS bisa menambal kode lokal — gerbang lisensi adalah penghalang + penegak masa aktif, bukan pengaman kriptografis.

Detail: [`docs/SECURITY_FIXES.md`](docs/SECURITY_FIXES.md) · hasil uji nyata di VPS: [`docs/HASIL_UJI_VPS.md`](docs/HASIL_UJI_VPS.md) · rancangan API: [`docs/RENCANA_API.md`](docs/RENCANA_API.md)

---

## 🧪 Uji

```bash
bash tests/test_hardening.sh            # 82 cek keamanan (non-destruktif)
bash tests/test_license_enforcement.sh  # 12 kasus lisensi (fungsi asli)
sha256sum -c SHA256SUMS                 # integritas berkas
```

> ⚠️ Suite lama (`test_auto_repair`, `test_xray_api_sync`, `test_expiry_and_xp`, …) **jangan** di VPS produksi —
> sebagian menulis `/etc` dan me-restart layanan. Jalankan di VPS uji: [`docs/STAGING_TEST.md`](docs/STAGING_TEST.md)

---

## 🔧 Troubleshooting

| Gejala | Cek |
|---|---|
| Bot tidak menjawab | `journalctl -u telegram-bot` · `/etc/wibutunnel/tmp/bot_error.log` → **401** token salah · **409** token dipakai VPS lain |
| Akun tidak bisa connect | `systemctl status xray` · `xray -test -config /usr/local/etc/xray/config.json` |
| Limit IP tidak jalan | `jq '.log.loglevel' /usr/local/etc/xray/config.json` (harus `info`) · `systemctl status wibu-daemon` |
| Trial tidak terhapus | `journalctl -u algojo-expired --since "1 minute ago"` |
| Umum | `wibu-repair` atau `m-setting` → [1] Auto-Repair |

---

## 🔄 Update & Hapus

```bash
m-setting          # [5] Update Script (verifikasi SHA256, cadangan otomatis)
wibu-audit-akun    # akun tanpa masa aktif (--fix = karantina)
```

```bash
curl -4 -fsSL https://wibu.loli.web.id/u | bash     # cadangan otomatis ke /root/wibutunnel-backup-*/
```

---

## 📝 Changelog

### v4.0.8 (2026-11-15)
- **Instalasi 1 baris:** `curl -4 -fsSL https://wibu.loli.web.id/i | bash` (bootstrap verifikasi hash dulu) + `install.sh`
- **Update menu mengikuti rilis terbaru** (bukan tag beku) supaya perbaikan setelah rilis tetap sampai ke VPS
- **Audit akun** menampilkan jumlah catatan `dummy-*` bawaan installer (dulu senyap)
- Cek hash README diperkuat: jalur absolut + menolak placeholder hash yang tersisa (sebelumnya bisa lolos palsu)

### v4.0.7 (2026-11-15) — hasil uji nyata di VPS
- **Keamanan:** rantai pasang & update terverifikasi hash (fail-closed) · API Xray root-only · izin 600/640 · token bot keluar dari `argv`
- **Lisensi:** IP wajib terdaftar, lisensi exp → menu ditolak · pencocokan IP persis · cache ber-IP · offline maks 7 hari
- **Jaringan:** semua unduhan paksa IPv4 (VPS IPv6 *blackhole*) · HAProxy IPv4-only
- **Update:** berkas firewall & network-tune jadi berkas repo (ikut ter-update) · manifest dari API GitHub
- **Backup:** restore memperbaiki pemilik config (Xray sempat gagal start) · `bot.conf` ikut · bot dimatikan agar token tidak bentrok
- **Baru:** `wibu-audit-akun` (audit akun tanpa masa aktif) · timer firewall idempoten · `tools/update-xray-pin.sh`
- **Perbaikan:** menu tidak lagi berputar saat stdin EOF · `wibu-repair` tidak melonggarkan izin · 19 bug nyata dari uji VPS

### v4.0.6 KURUMI (2026-11-02)
Auto-repair, live sync gRPC, enforcement kuota/expired, modul SSH, dashboard monitor.

---

## 💬 Support

🐛 [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues) · 💬 [@wibuvpn](https://t.me/wibuvpn) · 📧 wibuvpnstore@gmail.com

MIT License — bebas pakai, tanpa jaminan.

<div align="center">

**Made with 💜 by WBVPN**

</div>
