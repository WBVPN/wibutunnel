# 🦋 WIBUTUNNEL v4.1.49

Panel VPN **Xray + SSH** auto-install dengan **bot Telegram**. Satu perintah, VPN langsung jalan.

![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)
![Version](https://img.shields.io/badge/Version-v4.1.49-blue.svg)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)

**[Instalasi](#-instalasi)** · **[Fitur](#-fitur)** · **[Bot Telegram](#-bot-telegram)** · **[Perintah](#-perintah)** · **[Port](#-port--alur)** · **[Keamanan](#-keamanan)** · **[Uji](#-uji)** · **[Troubleshooting](#-troubleshooting)** · **[Changelog](docs/CHANGELOG.md)**

---

## ⚡ Instalasi

Satu perintah. Domain (dan token bot) ditanyakan **di tengah proses** — tidak perlu ditulis di command:

```bash
bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
```

`install.sh` = bootstrap dari **Release GitHub**: mengunduh `setup.sh` dari **tag rilis tetap**
(cadangan jsDelivr bila GitHub mentok), **memverifikasi sha256**, baru menjalankannya. Hash tidak cocok →
berhenti sebelum menyentuh apa pun.

Bentuk ini juga jalan dan sama-sama menanyakan domain (installer menyerahkan terminalnya ke `setup.sh`):

```bash
curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash
```

<details>
<summary>Otomasi tanpa terminal (cron/CI) & cek hash tanpa memasang</summary>

Tanpa terminal tidak ada yang bisa menjawab pertanyaan domain, jadi domain **wajib** jadi argumen —
kalau tidak, installer berhenti dengan pesan jelas sebelum apt/konfigurasi disentuh:

```bash
curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash -s -- vpn.domain-anda.com
```

Cek tag + hash tanpa memasang apa pun (`exit 0` bila cocok):

```bash
WIBU_BOOTSTRAP_ONLY=1 bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
```

Contoh keluaran: `tag rilis : v4.1.49` → `hash : OK` → `[i] WIBU_BOOTSTRAP_ONLY=1 — instalasi tidak dijalankan.`

</details>

| Syarat | |
|---|---|
| OS | Ubuntu 20.04 / 22.04 / 24.04 · Debian 11 / 12 |
| Domain | A record → IP VPS (tanpa AAAA) |
| Akses | root |
| Lisensi | IP VPS terdaftar di `izin.txt` ([@wibuvpn](https://t.me/wibuvpn)) |

> ⏱️ ~5–10 menit. Kalau berhenti di pemeriksaan lisensi, artinya IP VPS belum terdaftar — bukan error
> jaringan. Semua perintah memakai `curl -4` karena IPv6 sering "blackhole" di Indonesia.

<details>
<summary>🔧 Cara manual (unduh → verifikasi → pasang) & hapus</summary>

```bash
# pasang (langsung dari repo, tanpa perantara)
curl -4 -fsSL -o setup.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh
sha256sum setup.sh     # harap: 1f454fa50326d84a0d226cfb757b6c66c4803deb61315bf8793a421e7dff5387
bash setup.sh

# hapus (cadangan otomatis ke /root/wibutunnel-backup-*/)
curl -4 -fsSL -o uninstall.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh
sha256sum uninstall.sh   # harap: 7c47b985abd29cd9222056cdabcd82fcfe89042c7ed63ef5c391a1b50ac0726d
bash uninstall.sh
```

</details>

---

## ✨ Fitur

| | |
|---|---|
| 🔐 **4 protokol** | VLESS · VMESS · TROJAN · SSH (Dropbear, WS, Direct 80/443, split payload) |
| ⚡ **Live sync** | Tambah/hapus akun tanpa restart Xray (gRPC API) |
| 🎯 **Enforcement** | Kuota · masa aktif · limit IP · limit sesi SSH → kunci otomatis + notifikasi |
| 📊 **Kuota akurat** | Pemakaian diukur dari counter kernel per-soket (`ss -tie`), bukan perkiraan |
| 💾 **Recovery** | Akun expired disimpan, bisa dipulihkan dengan limit baru |
| 🛠️ **Auto-repair** | Bersihkan parasit port, SSL, config Xray, host key SSH |
| 📡 **UDP gateway** | `badvpn-udpgw` port 7100–7600 (game/DNS/QUIC di klien) |
| 🤖 **Bot Telegram** | Kelola akun, backup, cek trafik dari HP |
| 🕵️ **Audit akun** | Deteksi akun tanpa masa aktif ("gratis selamanya") |

---

## 🤖 Bot Telegram

Metode: **long polling saja** (tanpa webhook / SSL tambahan — dipilih supaya sesederhana mungkin).

1. Token → `/newbot` ke [@BotFather](https://t.me/BotFather)
2. Chat ID → `/start` ke [@userinfobot](https://t.me/userinfobot)
3. Pasang: `menu` → Setting → **[6] Setup Bot Telegram**

Ganti token kapan saja lewat Setting **[1]**: webhook token lama **dan** token baru dilepas otomatis, dan
daemon membersihkan sendiri webhook yang masih nyangkut (penyebab lama: `getUpdates` dijawab **409**
sehingga bot tampak mati).

Trial: format `trial-xxxx` · 1 jam · 1 GB · terhapus otomatis saat habis.

---

## 🧰 Perintah

| Perintah | Fungsi |
|---|---|
| `menu` | Dashboard & status stack |
| `m-vless` `m-vmess` `m-trojan` | Kelola akun per protokol |
| `m-ssh` | SSH — cek login [9], banner [12], respon WS [13], UDP gateway [14] |
| `m-setting` | Setting — auto-repair [1], ganti token bot [1], update [5], setup bot [6] |
| `m-backup` | Backup & restore (password wajib) |
| `cek-trafik` | Trafik & IP per akun |
| `wibu-kuota` | Tabel kuota: USER · PROTO · TERPAKAI · LIMIT · SISA |
| `menu-lock` `menu-unlock` | Kunci / buka kunci massal |
| `menu-recovery` | Pulihkan akun dari recovery |
| `xp` | Tambah / kurangi masa aktif |
| `wibu-repair` | Diagnosa & perbaikan stack |
| `wibu-audit-akun` | Audit akun tanpa masa aktif (`--fix` = karantina) |
| `wibu-udpgw` | UDP gateway: `status` · `ports` · `install` |

**Daemon** (`/usr/local/sbin/`): `algojo-wibu` `algojo-kuota` `algojo-ssh` `algojo-expired`
`algojo-expired-daemon` `lock-user` `unlock-user` `unlocker-wibu` `ws-stunnel` `wibu-daemon` `wibu-repair`
`wibu-isp` `wibu-ssl-ulang` `wibu-kuota` `wibu-udpgw` `network-tune.sh` `wibutunnel-firewall.sh`

**Unit**: `xray` `haproxy` `dropbear` `ws-stunnel` `telegram-bot` `algojo-expired` `algojo-expired-daemon`
`wibu-daemon` `network-tune` `wibutunnel-firewall` `wibu-acct` `badvpn-udpgw@<port>`

---

## ⚙️ Enforcement

| Daemon | Cek | Aksi |
|---|---|---|
| `algojo-ssh` | limit sesi SSH | kunci 15 menit (auto-unlock) |
| `algojo-wibu` | limit IP Xray (jendela 60 dtk, IP CDN dibuang) | kunci 15 menit (auto-unlock) |
| `algojo-kuota` | kuota bandwidth (jalur lambat, ~60 dtk) | akun biasa → recovery · trial → hapus |
| `algojo-expired` | masa aktif | akun biasa → recovery · trial → hapus |
| `wibu-acct` | sampler byte SSH tiap **0,5 dtk** + kuota SSH jalur cepat tiap **5 dtk** (`WIBU_QUOTA_EVERY`) | kunci seketika (≤5 dtk) + notifikasi |

Jalur cepat `wibu-acct` memeriksa **hanya akun SSH** (tanpa `statsquery` xray, tanpa tulis config), ber-`flock`,
dan idempoten lewat `locked_users.db` — jadi tidak bisa dobel-hitung/dobel-kunci dengan `algojo-kuota` yang
tetap jalan tiap ~60 dtk. Teks pesan penguncian dibangun satu fungsi (`kuota_ssh_lock_message()`), dipakai
jalur cepat maupun jalur lambat.

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
/etc/wibutunnel/user_usage.db     # ledger pemakaian (idempoten per soket)
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
| 7100–7600 | UDP gateway `badvpn-udpgw` (lokal) |

```
Internet → HAProxy (80/443)
             ├→ Xray (inbound 10086–10093)
             ├→ Dropbear 143            (SSH direct)
             └→ ws-stunnel 10015 → Dropbear 109  (SSH via WS)
```

---

## 🔐 Keamanan

- **Rantai pasang terverifikasi.** Semua berkas diambil dari **tag rilis** + dicek `SHA256SUMS`; gagal = berhenti.
- **Update fail-closed.** Manifest diambil sekali per putaran dari **API GitHub** (CDN raw bisa menyajikan
  versi lama) + cadangan **jsDelivr**; berkas yang hash-nya tidak cocok tidak dipasang.
- **API Xray `:10085` hanya root.** Aturan iptables + unit & timer yang menegakkan ulang setiap boot.
- **Izin ketat:** `*_exp.conf` 600 · config 640 `root:xray` · `/etc/wibutunnel` 700 · log 0640.
- **Lisensi:** IP tak terdaftar → ditolak · lisensi exp → **menu tidak bisa dibuka** · offline maks 7 hari.
- **Backup:** wajib `https` + password, isi arsip divalidasi, `bot.conf` ikut (restore mematikan bot agar token tidak bentrok).
- **Token bot** tidak lewat `argv` (tidak terlihat di `ps`); gagal polling (401/409) tercatat di log.
- **Bot tanpa webhook:** tidak ada layanan HTTP tambahan maupun rute publik untuk update Telegram.

> Jujur soal batasnya: pemegang **root** di VPS bisa menambal kode lokal — gerbang lisensi adalah penghalang
> + penegak masa aktif, bukan pengaman kriptografis.

Detail: [`docs/SECURITY_FIXES.md`](docs/SECURITY_FIXES.md) · hasil uji nyata di VPS:
[`docs/HASIL_UJI_VPS.md`](docs/HASIL_UJI_VPS.md) · matriks OS:
[`docs/KOMPATIBILITAS_OS.md`](docs/KOMPATIBILITAS_OS.md)

---

## 🧪 Uji

```bash
bash tools/verify-release.sh            # rantai instalasi: link rilis + hash aset
bash tests/test_hardening.sh            # keamanan & kesesuaian README (non-destruktif)
bash tests/test_license_enforcement.sh  # kasus lisensi (pakai fungsi asli)
sha256sum -c SHA256SUMS                 # integritas berkas
```

Tes yang tidak mengubah sistem bisa dijalankan di mana saja. Tes integrasi (`test_ssh_integration`,
`test_xray_api_sync`, `test_expiry_and_xp`, `test_bot_lock_unlock`, `test_bot_log_cleanup`,
`test_auto_repair`) butuh **panel terpasang**; di luar VPS panel mereka **melewati diri sendiri** dengan
pesan jelas. Protokol lengkap: [`docs/STAGING_TEST.md`](docs/STAGING_TEST.md)

---

## 🔧 Troubleshooting

| Gejala | Cek |
|---|---|
| Bot tidak menjawab | `journalctl -u telegram-bot` · `/etc/wibutunnel/tmp/bot_error.log` → **401** token salah · **409** token dipakai VPS lain |
| Akun tidak bisa connect | `systemctl status xray` · `xray -test -config /usr/local/etc/xray/config.json` |
| Limit IP tidak jalan | `jq '.log.loglevel' /usr/local/etc/xray/config.json` (harus `info`) · `systemctl status wibu-daemon` |
| Kuota tidak bertambah | `systemctl status algojo-kuota` · `wibu-kuota` (lihat manual) |
| Trial tidak terhapus | `journalctl -u algojo-expired --since "1 minute ago"` |
| UDP/QoS di klien mati | `wibu-udpgw status` → menu `m-ssh` [14] |
| Umum | `wibu-repair`, atau `m-setting` → [1] Auto-Repair |

---

## 🔄 Update & Hapus

```bash
m-setting          # [5] Update Script — verifikasi SHA256 per berkas, cadangan otomatis
```

```bash
curl -4 -fsSL -o uninstall.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/uninstall.sh
bash uninstall.sh  # cadangan otomatis ke /root/wibutunnel-backup-*/
```

Uninstall menghapus seluruh bagian panel — termasuk **UDPGW** (unit `badvpn-udpgw@*`, biner
`/usr/sbin/badvpn-udpgw`, direktori build, dan proses yang masih mendengarkan port 7100-7600).
Akses SSH (port 22) tidak disentuh.

Riwayat rilis: [`docs/CHANGELOG.md`](docs/CHANGELOG.md) · Rilis & aset: https://github.com/WBVPN/wibutunnel/releases

---

## 💬 Support

🐛 [GitHub Issues](https://github.com/WBVPN/wibutunnel/issues) · 💬 [@wibuvpn](https://t.me/wibuvpn) · 📧 wibuvpnstore@gmail.com

MIT License — bebas pakai, tanpa jaminan.

<div align="center">

**Made with 💜 by WBVPN**

</div>
