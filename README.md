# 🦋 WIBUTUNNEL v4.1.7

Panel VPN Xray **auto-install** + bot Telegram. Satu perintah, VPN langsung jalan.

![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)
![Version](https://img.shields.io/badge/Version-v4.1.7-blue.svg)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)

---

## ⚡ Instalasi

```bash
curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash
```

Aset dari **Release resmi GitHub**. Skrip itu mengunduh `setup.sh` dari tag rilis, **memverifikasi sha256-nya**,
baru menjalankan. Hash tidak cocok = berhenti sebelum memasang apa pun.

| Syarat | |
|---|---|
| OS | Ubuntu 20.04 / 22.04 / 24.04 · Debian 11 / 12 |
| Domain | A record mengarah ke IP VPS *(tanpa AAAA)* |
| Akses | root |
| Lisensi | IP VPS terdaftar di `izin.txt` ([@wibuvpn](https://t.me/wibuvpn)) |

<details>
<summary>🔧 Cara manual (unduh → verifikasi → pasang)</summary>

**Tanpa perantara sama sekali** (unduh -> verifikasi -> pasang; dari branch `main`, hash selalu sinkron dengan repo):

```bash
curl -4 -fsSL -o setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
sha256sum setup.sh     # harap: 368b958f83bc2c016f46a7291593d06474e65b36dd18f1ec0f8558a155d8a59e
bash setup.sh
```

**Hapus** (cadangan otomatis ke `/root/wibutunnel-backup-*/`):

```bash
curl -4 -fsSL -o uninstall.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh
sha256sum uninstall.sh   # harap: a9962e71a9ac5b83757101d76c5163a8825e785433f7a1639fa44dfa022ba46d
bash uninstall.sh
```

</details>

> ⏱️ ~5-10 menit. Instalasi baru: IP VPS harus terdaftar di `izin.txt`, kalau tidak berhenti di pemeriksaan lisensi
> (memang begitu, bukan error jaringan). Semua perintah memakai `curl -4` karena VPS IPv6 "blackhole" umum di Indonesia.

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
curl -4 -fsSL https:///u | bash     # cadangan otomatis ke /root/wibutunnel-backup-*/
```

---

## 📝 Changelog

### v4.1.7 (2026-11-15)
- **KRITIS: v4.1.5 & v4.1.6 DITARIK.** Tambalan validasi HAProxy di kedua rilis itu **nyasar masuk ke dalam heredoc**
  konfigurasi sehingga berkas `haproxy.cfg` berisi baris kode shell (`unknown keyword 'rm' out of section`)
  dan HAProxy tidak bisa start. Rilis ini mengembalikan `setup.sh` ke versi **v4.1.4 yang sudah teruji di VPS**,
  lalu menerapkan kelima tambalan portabilitas dengan penyisipan berbasis baris + verifikasi integritas heredoc.
- Cek harness baru: blok heredoc konfigurasi HAProxy harus bebas dari kode shell (mengunci kelas bug ini).

### v4.1.6 (2026-11-15) - DITARIK
- **KRITIS:** `apt-get` sekarang memakai `-o Dpkg::Options::=--force-confold`. Sebabnya: installer menulis
  `/etc/default/dropbear` LEBIH DULU (agar dropbear tidak merebut port 22) sehingga dpkg bertanya soal conffile -
  dan karena stdin tidak interaktif, jawabannya EOF -> `end of file on stdin at conffile prompt` -> seluruh apt gagal.
  Kesalahan ini ditemukan oleh uji-regresi di Debian 12, bukan oleh pemeriksaan hash.
- Pesan gagal apt sekarang menyertakan cara memulihkan paket setengah terpasang (`dpkg --configure -a`).

### v4.1.5 (2026-11-15)
**Persiapan agar kelima OS didukung** (hasil pelajaran Ubuntu 20.04 + Debian 12):
- **dropbear tidak lagi start otomatis saat apt memasangnya** (paket Debian/Ubuntu mendengarkan port 22; kalau menang balapan dengan sshd, admin bisa kehilangan akses SSH). `NO_START=1` ditulis lebih dulu.
- **Konfigurasi HAProxy divalidasi (`haproxy -c`) dan otomatis diturunkan ke versi minimal** kalau ada direktif yang tidak dikenal versi HAProxy di OS itu (rentang 2.0 s/d 2.8).
- **Fallback AppArmor**: kalau Ubuntu memblokir haproxy (profil enforce), profil diubah ke complain mode lalu dicoba ulang.
- **Laporan versi paket** (haproxy/certbot/dropbear/python/openssl) + peringatan kalau `/dev/log` tidak ada.

### v4.1.4 (2026-11-15)
- **Debian 12 (bookworm) teruji nyata** di VPS: HAProxy 2.6 `Configuration file is valid`, certbot 2.1.0 menerbitkan sertifikat, `rsyslog` + `/dev/log` jalan, `systemd-timesyncd` sinkron, 8/8 layanan aktif **dan enabled**, port 80/443/143/109 dengar.
- Sisa status `failed` dari percobaan start dengan konfigurasi bawaan paket dibersihkan (`systemctl reset-failed`), jadi `systemctl status` tidak menyesatkan setelah instalasi.

### v4.1.3 (2026-11-15)
- **Persiapan Debian 12 (bookworm):** `rsyslog` ikut dipasang (agar `/dev/log` ada dan log HAProxy tidak hilang - instalasi minimal bookworm tidak punya syslog), NTP pakai `systemd-timesyncd` lebih dulu (`paket ntp` tidak ada di bookworm minimal), penjaga OS kini menyebut versi yang didukung + menampilkan OS/versi yang terdeteksi.
- Ke-21 paket yang dipakai dipastikan tersedia di bookworm (dicek satu per satu di indeks paket Debian).

### v4.1.2 (2026-11-15)
- Tautan unduh di README memakai `releases/latest/download/...` supaya tidak bisa menunjuk versi lama.
- `systemctl reset-failed` untuk unit bot (status bersih saat token belum diisi).

### v4.1.1 (2026-11-15)
- `wibu-audit-akun` kini **ikut dipasang** oleh installer (sebelumnya hanya lewat update menu - instalasi baru tidak punya).
- Unit bot tidak lagi "failed" pada instalasi yang belum diisi token (tidak diaktifkan sampai token ada).
- Penanda versi **ditulis ulang di akhir** instalasi supaya tidak ketimpa data lama dari backup.

### v4.1.0 (2026-11-15)
- **KRITIS (2):** `dropbear` gagal `--configure` karena sisa konfigurasi banner `wibutunnel` -> apt error ->
  instalasi berhenti. Ditutup dari dua sisi: banner disiapkan **sebelum** apt, dan `uninstall.sh` membersihkan
  rujukan banner. Ditemukan hanya lewat **instalasi penuh di VPS**.
- apt kini `DEBIAN_FRONTEND=noninteractive` (tidak menggantung di prompt debconf tanpa TTY).

### v4.0.9 (2026-11-15)
- **KRITIS:** `-4` nyasar di daftar paket apt + di `command -v curl -4` membuat **seluruh apt-get gagal** ->
  haproxy/certbot/jq tidak terpasang -> "Failed to enable services". Ditemukan saat uji instalasi penuh (bukan dari hash).
- apt gagal sekarang **fatal** (berhenti jelas, tidak lanjut setengah jalan) + menyebut layanan mana yang tidak aktif.
- Cek harness baru: `-4` hanya boleh jadi argumen pertama `curl`/`wget`/`ip`.

### v4.0.8 (2026-11-15)
- **Instalasi 1 baris** dari aset Release GitHub (`install.sh` verifikasi hash dulu)
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
