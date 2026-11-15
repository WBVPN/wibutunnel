# Hasil Uji Nyata di VPS (v4.0.6-fixed)

Diuji pada VPS kosong **Ubuntu 20.04** (1 vCPU / 965 MB), domain `test.priasawit.web.id`,
IP terdaftar di `izin.txt` sampai 2026-12-15. Semua temuan di bawah ditemukan karena
menjalankan installer & suite tes di VPS sungguhan, bukan di mock.

## 1. Instalasi mengikuti README

| Langkah | Hasil |
|---|---|
| `curl -4 -fsSL -o setup.sh .../v4.0.6-fixed/setup.sh` | 0,6 dtk; sha256 **cocok** dengan yang tertulis di README |
| Gerbang lisensi instalasi | lolos dengan IP terdaftar |
| Instalasi selesai | dashboard `HAProxy [ON] Xray [ON] SSH [ON] WS [ON]`, penanda `4.0.6-fixed` |
| Layanan | 8/8 `active` + 8/8 `enabled` |
| Port | 80/443 (HAProxy) · 109/143 dropbear publik · 2222 lokal · 22 sshd · 10015 ws-stunnel · 10085-10093 API Xray (lokal) |
| Config Xray | `xray -test` → `Configuration OK` |
| Uninstall | bersih + backup otomatis, 0 sisa layanan |

## 2. Verifikasi keamanan (di VPS, bukan asumsi)

| Item | Bukti |
|---|---|
| **API Xray :10085 root-only** | root → `statsquery` berhasil; non-root (`nobody`) → `failed to dial 127.0.0.1:10085` |
| Aturan firewall | `-A OUTPUT -d 127.0.0.1/32 -p tcp -m owner ! --uid-owner 0 -m tcp --dport 10085 -j REJECT` |
| Ketahanan reboot | unit `wibutunnel-firewall` **enabled** + `ExecMainStatus=0`; `/etc/iptables/rules.v4` tersimpan |
| Izin berkas | `*_exp.conf` 600 · `/etc/xray` 750 · config Xray 640 · `/etc/wibutunnel/*.conf` 600 |
| Unduhan terverifikasi | 25 berkas diverifikasi `SHA256SUMS` saat instalasi & saat update |
| Banner SSH | tampil saat login dropbear |
| IPv4 dipaksa | `wget` tanpa `-4` **menggantung** (exit 124) vs `detect_myip()` **0,018 dtk** |

## 3. Bug nyata yang ditemukan & diperbaiki

| # | Bug | Akibat sebelum diperbaiki | PR |
|---|---|---|---|
| 1 | Installer Xray dipanggil `bash file -s -- install` (bentuk pipa) | Xray gagal pasang → `chown: invalid user: 'xray:adm'` → instalasi berhenti | #6 |
| 2 | `! -m owner --uid-owner 0` (sintaks iptables) | mitigasi API **tidak terpasang** | #2 |
| 3 | README memakai `wget` tanpa `-4` | di VPS IPv6-blackhole: unduhan menggantung; cek lisensi bisa menolak lisensi sah | #5 |
| 4 | Loop prompt domain tanpa penjaga EOF | 1.425.877 baris log dalam <2 menit | #2 |
| 5 | 18 berkas runtime tanpa `-4` (`menu/*`, `common.sh`, `sbin/*`) | IP publik bisa **kosong** → config akun salah → klien tak bisa konek | #8 |
| 6 | Aturan firewall API berganda tiap boot | `iptables -C` tak mengenali aturan hasil restore `rules.v4` | #8 |
| 7 | 4 aturan `CLASSIFY` gagal tiap menit | journal spam + QoS diam-diam mati | #7 |
| 8 | Gerbang lisensi memakai `./izin.txt` lokal | `printf 'x lifetime <IP>' > izin.txt` = bypass | #9 |
| 9 | Pencocokan IP `grep -w` + cache tanpa IP | pencocokan kabur; IP yang dihapus masih lolos ≤1 jam | #9 |
| 10 | `wibu-repair`: cadangan dicari di `/etc/xray/*.bak` | cadangan installer (`/usr/local/etc/xray/*.bak`) **tak pernah ketemu** → config rusak tak pulih | #11 |
| 11 | `wibu-repair`: `chmod 644` pada `*_exp.conf` & config | izin 600/640 **kembali longgar** tiap repair (terbukti: 600 → 644 di VPS) | #11 |
| 12 | `wibu-repair`: host key `ed25519 \|\| true` | Dropbear 20.04 tak dukung ed25519 → gagal diam-diam, host key tak dibuat | #10 |
| 13 | `tests/test_license_enforcement.sh` vendor | hanya mengulang logikanya sendiri (tautologi) → tak membuktikan apa pun | #9 |
| 14 | `tests/test_auto_repair.sh` vendor | tak memulihkan berkas uji → VPS kehilangan host key saat test gagal | #10 |
| 15 | `tests/test_setup_flow.sh` langkah 7 | menuntut `bind *:443` (basi setelah perubahan ke `0.0.0.0`) | #10 |

## 4. Hasil akhir seluruh suite (di VPS)

```
test_algojo_ssh.sh            OK      test_expiry_and_xp.sh        OK
test_auto_repair.sh           OK      test_hardening.sh            OK (61 cek)
test_bot_lock_unlock.sh       OK      test_license_enforcement.sh  OK (12 cek)
test_bot_log_cleanup.sh       OK      test_setup_flow.sh           OK
test_db_flock.sh              OK      test_ssh_integration.sh      OK
test_deep_audit_fixes.sh      OK      test_xray_api_sync.sh        OK
```
Sebelum perbaikan: 2 suite GAGAL (`auto_repair`, `setup_flow`).

## 5. Gerbang lisensi (perilaku yang sudah diverifikasi di VPS)

```
IP terdaftar & aktif   -> check_license() = LOLOS: STAGING exp 2026-12-15
Lisensi kedaluwarsa    -> "LISENSI KEDALUWARSA"  (menu/aksi akun/bot ditolak)
IP tidak terdaftar     -> "AKSES DITOLAK"
Offline                -> salinan resmi /etc/wibutunnel/izin.txt atau cache, maks 7 hari
```

## 6. Update di VPS yang sudah berjalan

Menu **[5] Update Script (Safe Mode)** diuji langsung: **25/25 berkas sukses**, tiap berkas
melalui unduh → verifikasi `SHA256SUMS` (fail-closed) → `bash -n` → cadangan ke
`/usr/local/share/wibutunnel/backup/` → pasang. Tidak ada berkas yang berubah tanpa verifikasi.

## 6b. Update menu [5] sesudahnya: 27 berkas + temuan CDN

Berkas firewall & network-tune dijadikan berkas repo (bukan heredoc) supaya bisa dikirim lewat update.

| Uji | Hasil |
|---|---|
| Update menu (daftar 27) | **27 sukses / 0 gagal**; verifikasi akhir sha256 tiap berkas: **27 cocok / 0 beda** |
| Symlink kompatibilitas | `/usr/local/sbin/wibutunnel-firewall.sh -> wibutunnel-firewall` (unit lama tetap jalan) |
| `network-tune` | probe CLASSIFY ada; `iptables: Invalid argument` = **0** (sebelumnya 4 tiap boot) |
| `wibutunnel-firewall` | dedupe ada; aturan `:10085` = **1** |
| Izin | exp **600** - config **640** - izin.txt **600** |
| Lisensi | `LOLOS STAGING exp 2026-12-15` |

**Temuan penting: CDN `raw.githubusercontent.com` menyajikan `SHA256SUMS` LAMA untuk tag yang dipindah.**

```
raw.githubusercontent.com/<tag>/SHA256SUMS?cb=<unik>   -> 55 entri  (LAMA)
api.github.com/.../contents/SHA256SUMS?ref=<tag>       -> 57 entri  (benar)
berkas terpisah lewat raw                              -> sudah baru
```

Update fail-closed jadi **menolak berkas yang sebenarnya sudah ada**. Cache-buster `?cb=` **tidak menolong**
(CDN mengabaikan query untuk path itu). Perbaikan akhir: `SHA256SUMS` diambil **dari API GitHub lebih dulu**,
raw hanya cadangan; bila hash berkas tidak cocok, berkas diunduh ulang lewat API lalu diverifikasi lagi.

## 6c. Backup & pindah VPS (diuji)

Backup berpassword (`zip -P`) dikirim ke Telegram; caption memuat **file_id + password** (jadi restore cukup dari chat).
Isi arsip (13 entri): `config.json`, 4 berkas `*_exp.conf`, 5 DB (`ssh_pass`, `limit_ip`,
`limit_bw`, `locked_users`, `user_usage`), `recovery/`, `domain`, `bot.conf`.

Uji yang dijalankan di VPS:

| Langkah | Hasil |
|---|---|
| Buat akun penanda `uji-backup-1` (exp 2030-12-31, limit_ip 2) lalu backup | zip 3.6 KB terkirim, `Auto backup SUCCESS` |
| **Hapus seluruh data pelanggan** (setara VPS baru) | klien non-dummy = 0, `*_exp.conf` kosong, DB kosong |
| Restore lewat menu [2] (file_id + password) | `[+] Backup valid. Mengembalikan data...` lalu `RESTORE BERHASIL!` |
| Periksa hasil | akun + `exp 2030-12-31` + `limit_ip 2` kembali **persis**, `xray -test` = OK |
| Menu setelah restore | keluar rapi (perbaikan EOF bekerja; tanpa itu menu berputar tanpa henti) |

**Bug yang ketangkap:** setelah restore, `config.json` menjadi `640 root:root`. Zip tidak menyimpan pemilik grup dan
`cp -a` mempertahankan `root:root`, sedangkan Xray berjalan sebagai user `xray` ->
`failed to load config: permission denied` dan **`xray.service` GAGAL** (semua akun mati walau datanya "berhasil" dipulihkan).
Diperbaiki di `do_restore`: `chown root:xray` + `chmod 640` + `chown -R xray:xray /var/log/xray` + `chmod 600` exp.

### Memindahkan ke VPS baru - urutan yang benar

1. **Daftarkan IP VPS baru** di `izin.txt` (repo ini) - tanpa itu instalasi DITOLAK (gerbang lisensi, fail-closed).
2. Pasang panel di VPS baru dengan perintah README.
3. Restore backup (menu **Backup & Restore -> [2]**) memakai **file_id + password** dari caption Telegram.
4. Yang **tidak** ikut di backup dan perlu diulang: **sertifikat SSL** (installer menerbitkannya untuk domain baru),
   dan setelan auto-reboot/cron lain di luar panel.
5. Bersihkan akun sisa bila arsip berasal dari VPS yang pernah dipakai menjalankan `tests/*.sh`.

## 7. Sisa yang belum diuji

- **Siklus reboot nyata** setelah perbaikan dedupe firewall (bukti statis + uji jalankan-2× sudah ada).
- **Koneksi klien dari perangkat nyata** (VLESS/VMESS/Trojan/SSH) — pemilik VPS melaporkan akun sudah konek.
- **Layanan bot Telegram** hanya diuji dengan satu bot uji (`@bansoswibu_bot`).
- **Siklus reboot** setelah semua perbaikan (butuh akses root di VPS uji).


---

## 7. Uji lapangan: Debian 12 (bookworm) - 2026-11-15

VPS: `103.150.60.84` di-rebuild ke Debian 12 (kernel 6.1, 973 MB RAM, 18 GB disk), instalasi dari
aset Release GitHub (tag v4.1.3) tanpa penyesuaian manual apa pun.

| Pemeriksaan | Hasil |
|---|---|
| Penjaga OS | `[+] OS terdeteksi: Debian GNU/Linux 12 (bookworm) (12)` |
| Validasi domain | `[+] Pointing Sukses!` (A record -> IP VPS, tanpa AAAA) |
| Galat apt/dpkg | **0** (semua 21 paket terpasang: haproxy 2.6.12, certbot 2.1.0, dropbear 2022.83, iptables-persistent 1.0.20, rsyslog 8.2302, python3 3.11.2) |
| HAProxy | `haproxy -c`: **Configuration file is valid** (2.6.12; konfigurasi 2.x-compatible terbukti) |
| Sertifikat | certbot 2.1.0 menerbitkan `test.priasawit.web.id`, berlaku s/d 2027-02-13 |
| syslog | `/dev/log -> /run/systemd/journal/dev-log`, `rsyslog active`, HAProxy menulis log |
| Waktu | `systemd-timesyncd active`, `System clock synchronized: yes` |
| Layanan | 8/8 `active` **dan** `enabled` (xray, haproxy, dropbear, ws-stunnel, algojo-expired, wibu-daemon, wibutunnel-firewall, network-tune) |
| Port | 80, 443, 143, 109 (publik) + 10015, 10085 (lokal) |
| Xray | `Configuration OK`, 9 inbound |
| Keamanan | config 640 `root:xray`, `*_exp.conf` 600, `/etc/wibutunnel` 700, aturan `:10085` = 1, non-root ke API **DITOLAK**, lisensi **LOLOS** |
| Akun uji | `staging-1` (VLESS, exp 2026-12-15, limit IP 2), audit bersih |
| **Koneksi klien nyata** | **BERHASIL** - pemilik menghubungkan akun `staging-1` dari perangkatnya ke `test.priasawit.web.id` (2026-11-15). Rantai penuh terbukti: installer -> HAProxy 2.6 -> Xray -> akun -> klien. |

**Temuan yang diperbaiki sebelum uji ini (dari analisis statis bookworm):** `rsyslog` tidak ada di
instalasi minimal (log HAProxy hilang), paket `ntp` tidak ada (waktu tidak sinkron), pesan penjaga OS
tidak menyebut versi.
**Temuan saat uji:** `systemctl status dropbear/haproxy` sempat menampilkan `failed` karena percobaan
start dengan konfigurasi bawaan paket sebelum installer menulis konfigurnya -> ditambahkan
`systemctl reset-failed` (v4.1.4). Pembacaan `is-active` harus dilakukan setelah layanan tenang.

**Batas yang belum diuji:** beban banyak klien paralel (load test). Reboot VPS Debian 12 **sudah** diuji:
BOOT_ID berubah, 8/8 layanan naik sendiri, aturan `:10085` tetap 1, sertifikat & akun utuh.


---

## 8. Uji lapangan: Ubuntu 22.04 (jammy) - 2026-11-15

VPS: `103.150.60.84` di-rebuild ke Ubuntu 22.04.5 LTS (kernel 5.15, 957 MB RAM, 18 GB disk), instalasi dari
aset Release (tag v4.1.7/v4.1.8) tanpa penyesuaian manual.

| Pemeriksaan | Hasil |
|---|---|
| Penjaga OS | `[+] OS terdeteksi: Ubuntu 22.04.5 LTS (22.04)` |
| Galat apt/dpkg | **0** |
| HAProxy | **2.4.30** - `Configuration file is valid`, 0 baris mencurigakan di config |
| certbot | **1.21.0**, sertifikat berlaku s/d 2027-02-13 |
| dropbear 2020.81 | **0 kegagalan start** (tambahan `NO_START` sebelum apt bekerja; bandingkan Debian 12: 3-14) |
| Layanan | 8/8 `active` + `enabled`; port 80/443/143/109 (+10015/10085 lokal) |
| Reboot | BOOT_ID berubah, 8/8 naik sendiri, aturan `:10085` tetap 1, akun & sertifikat utuh |
| Keamanan | config 640 root:xray, exp 600, dir 700, non-root ke API ditolak, lisensi LOLOS |
| **Koneksi klien nyata** | **BERHASIL** - akun `uji-vless` dihubungkan pemilik dari perangkatnya |
| Uji klien internal | Xray sebagai klien (VLESS TLS+WS, path `/vless`, SNI domain) -> `curl` lewat SOCKS keluar sukses |

**Temuan khas jammy:** image minimal tidak menyertakan `systemd-timesyncd` (NTP tidak aktif, jam tidak sinkron).
Diperbaiki: dipasang lebih dulu bila belum ada, **non-fatal** agar konflik paket `ntp`/`chrony` tidak membatalkan
instalasi. Sesudah perbaikan: `System clock synchronized: yes` dan bertahan setelah reboot.


---

## 9. Uji lapangan: Debian 11 (bullseye) - 2026-11-15

VPS `103.150.60.84` di-rebuild ke Debian 11 (kernel 5.10, 978 MB RAM, 18 GB disk), instalasi dari aset Release.

| Pemeriksaan | Hasil |
|---|---|
| Penjaga OS | `[+] OS terdeteksi: Debian GNU/Linux 11 (bullseye) (11)` |
| Galat apt/dpkg | **0** (sesudah repo dialihkan ke arsip) |
| Berkas gagal unduh | **0** |
| HAProxy | **2.2.9** - `Configuration file is valid` |
| certbot | **1.12.0**, sertifikat Let's Encrypt s/d 2027-02-13 |
| Layanan | 8/8 `active` + `enabled`; port 80/443/143/109 |
| Reboot | BOOT_ID berubah, 8/8 naik sendiri, aturan `:10085` = 1 di iptables **dan** rules.v4, akun & sertifikat utuh |
| Keamanan | config 640 root:xray, exp 600, dir 750, API 10085 root-only, lisensi LOLOS |
| Jam | tersinkron setelah paket `systemd-timesyncd` terpasang (installer mencoba best-effort) |
| Uji klien | Xray sebagai klien VLESS TLS+WS -> keluar sukses, HTTP via tunnel 200 |

**Temuan khas Debian 11 (semuanya diperbaiki di installer):**
1. `dig` tidak ada -> validasi domain gagal -> instalasi berhenti (v4.1.13: resolver rantai, getent sebagai jaring terakhir).
2. bullseye **EOL**: `security.debian.org` menjawab **404** untuk seluruh pool + mirror pihak ketiga rusak
   (`mr.heru.id/debian bullseye-backports` tanpa Release file) -> apt mustahil (v4.1.14: alih otomatis ke `archive.debian.org`).
3. `awk` = **mawk 1.3.4** tidak mendukung interval `{64}` -> manifest dinilai tidak sah -> semua berkas ditolak
   (v4.1.15: regex portabel `length($1) == 64 && $1 ~ /^[0-9a-f]+$/`).
