# Hasil Uji Nyata di VPS

> Jejak uji dari v4.0.6 sampai v4.1.31 — bagian terbaru di bawah. Semua angka di sini berasal dari eksekusi nyata, bukan perkiraan.

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

> Angka di blok ini berasal dari rilis **v4.0.6-fixed** (keadaan saat itu). Suite kini lebih besar:
> `test_hardening.sh` **120 cek**, `test_license_enforcement.sh` **15 cek**, semuanya lulus.

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

## 7b. Uji lapangan: Debian 12 (bookworm) - 2026-11-15

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


---

## 10. Uji lapangan: Ubuntu 24.04 (noble) - 2026-11-15

VPS `103.150.60.84` di-rebuild ke Ubuntu 24.04.1 LTS (kernel 6.8, 961 MB RAM, 13 GB disk).
Ini OS terakhir dalam matriks; sekaligus penutup uji portabilitas 5 OS.

| Pemeriksaan | Hasil |
|---|---|
| Penjaga OS | `[+] OS terdeteksi: Ubuntu 24.04.1 LTS (24.04)` |
| Galat apt/dpkg · berkas gagal | **0** · **0** |
| HAProxy | **2.8.30** - `Configuration file is valid` |
| certbot | **2.9.0**, sertifikat Let's Encrypt s/d 2027-02-13 (jalur flag certbot 2.x) |
| Xray | **26.11.9** - dipasang lewat **jalur cadangan** (installer resmi gagal karena 403 API) |
| Layanan | 8/8 `active` + `enabled`; port 80/443/143/109 + API 127.0.0.1:10085 |
| Reboot | BOOT_ID berubah, 8/8 naik sendiri, aturan `:10085` = 1 di iptables **dan** rules.v4 |
| Keamanan | config 640 root:xray, exp 600, dir 750, API root-only (gRPC `statsquery` jalan), lisensi LOLOS |
| Jam | `systemd-timesyncd` aktif dan tersinkron |
| Uji klien | Xray sebagai klien VLESS TLS+WS -> keluar sukses, HTTP via tunnel 200 |

**Dua temuan khas Ubuntu 24.04 (keduanya diperbaiki di v4.1.16):**
1. **`/tmp` = tmpfs `noexec`** (`tmpfs /tmp rw,nosuid,nodev,noexec`) - installer resmi Xray menjalankan biner
   pemeriksa versi dari `/tmp` -> `error: Local Xray binary cannot run` (terbukti: biner sama jalan dari
   `/root` dan `/usr/local/bin`, gagal dari `/tmp`). Perbaikan: `TMPDIR=/usr/local/src` sebelum installer resmi.
2. **Installer resmi Xray butuh kuota API GitHub** - terukur `core: limit 60, remaining 0, used 60`
   (verifikasi berkas juga memakai API) -> `Failed to get release list`, HTTP **403** -> `[FATAL] Xray gagal
   terpasang`. Perbaikan: **jalur cadangan tanpa API** (unduh `Xray-linux-64.zip` dari aset rilis versi terpin,
   verifikasi hash biner `e87bce58...a66d`, pasang biner + geodata + user + unit systemd) + rantai unduhan
   berhenti memakai API setelah 403/429. Jalur cadangan ini benar-benar terpakai saat uji ulang.

---

## 11. Deteksi sesi SSH: atribusi user & IP klien jalur WS (2026-11-16)

Ditemukan dari laporan pemilik: "bikin akun SSH, konek direct, user aktifnya tak kebaca".

| Yang diperiksa | Temuan sebelum perbaikan |
|---|---|
| Pemilik socket sesi (`ss -tnp`) | Proses dropbear yang **masih jalan sebagai root**; shell user (`bash`) adalah **anak** dari proses itu |
| Atribusi lama (`ps -o user= -p <pid socket>`) | Selalu `root` -> user tak ada di `ssh_exp.conf` -> **sesi tak pernah dihitung, limit IP SSH tak pernah terpicu** |
| `ssh_active_ips()` | Mengabaikan argumen user; mengembalikan **IP milik klien lain** (contoh terukur: `162.158.102.133 172.64.198.32` padahal sesi berasal dari satu IP saja) |
| Sesi lewat WS (443) | IP klien hilang di hop ws-stunnel; `ss` hanya melihat `127.0.0.1` |
| User sistem `sshd` (uid 105, privsep 24.04) | Koneksi brute-force port 22 terbaca seolah **sesi milik user "sshd"** |
| `last` (wtmp) | Kosong untuk akun SSH -> **tidak ada riwayat login** di panel; dropbear tidak menulis wtmp |

**Perbaikan (v4.1.18):**

1. `ssh_pid_session_user()` — menelusuri **keturunan** proses sampai menemukan akun nyata
   (**uid >= 1000**), jadi root/sshd/privsep tak pernah dianggap pelanggan.
2. `ssh_sessions_snapshot()` — satu sumber kebenaran untuk `ssh_session_count()`, `ssh_active_ips()`,
   dan `algojo-ssh`.
3. `ws-stunnel` mencatat IP klien dari handshake: **`CF-Connecting-IP` > `X-Forwarded-For` > IP peer**,
   dipetakan lewat **port lokal soket ke dropbear** ke `ws_client_ip.log` (500 baris terakhir,
   TTL 3600 s) -> panel bisa menampilkan IP asli walau klien lewat Cloudflare.
4. `algojo-ssh` memakai snapshot yang sama (bukan parsing sendiri).

**Bukti uji di VPS uji (103.150.60.84, Ubuntu 24.04, panel v4.1.17 + pratinjau):**

| Uji | Hasil |
|---|---|
| SSH langsung (port 109) sebagai akun panel | `trial-rno8  43.156.147.95` — user & IP asli terbaca |
| SSH lewat WS/443 (TLS + handshake WS, header `CF-Connecting-IP: 203.0.113.9`) | `trial-rno8  203.0.113.9` — IP dari header, bukan `127.0.0.1` |
| `algojo-ssh` sebelum perbaikan pada sesi yang sama | tak menghitung sesi apa pun (user = root) |
| Baris user sistem `sshd` di daftar online | **0** setelah perbaikan |

**Belum akurat / batas yang disadari:** sesi WS yang **tidak** mengirim header IP (klien tanpa CF, langsung ke
IP VPS dengan TLS) akan tercatat sebagai IP peer haproxy jika haproxy sendirilah yang menjadi peer — dalam
praktik langsung-ke-IP memberi IP klien sebenarnya karena haproxy melihat socket asli; yang residual hanya
sesi WS yang datang lewat proxy pihak ketiga tanpa header IP sama sekali (jatuh ke `via-WS`).

---

## 12. Deteksi user XRAY: rantai PROXY protocol v2 putus (2026-11-16)

Keluhan: "cek juga untuk user xray beneran kebaca akurat tak". Hasil: **tidak** — user xray
**tak pernah** terdeteksi online, dan penyebabnya bukan di panel tapi di rantai haproxy.

**Rantai sebelum perbaikan:**

```
klien -> ssl_sni(:443, mode tcp) --TANPA proxy--> bk_hub443 -> hub(:8444, mode http didalam haproxy)
       -> xray(:10086, acceptProxyProtocol) <-- send-proxy-v2 (tapi isinya 127.0.0.1!)
```

Karena dua hop pertama tidak membawa PROXY protocol, `send-proxy-v2` milik hop terakhir
mengirim **alamat peer hop sebelumnya**, yaitu `127.0.0.1` (haproxy sendiri). Bukti dari log
xray sebelum perbaikan, pada koneksi klien LUAR (IP publik 43.156.147.95):

```
2026/11/16 12:57:27 from 127.0.0.1:45350 accepted tcp:api.ipify.org:443 [vless-ws-tls >> direct] email: staging-1
```

Akibat berantai:
- `live_ip_pairs()` membuang baris ber-IP `127.0.0.1` (memang benar: itu bukan IP pelanggan)
  -> **daftar user xray online selalu kosong**;
- `algojo-wibu` mengambil `LOGIN_DATA=$(live_ip_pairs)` -> **limit IP xray tak pernah terpicu**.

Bug kedua di parser: `email=$NF` + `gsub(/[^a-zA-Z0-9_-]/,"")` membuang titik dan `@`, padahal
nama user xray boleh memuat `._@-` (mis. `roodyz.prem`) -> user ber-titik juga tak pernah terbaca.

**Perbaikan (v4.1.18):**

1. `setup.sh` template haproxy: `send-proxy-v2` pada `ws_tunnel`, `bk_hub443`, `bk_hub80`;
   `accept-proxy` pada bind hub `127.0.0.1:8444` dan `127.0.0.1:8445`. Klien asli kini terbawa
   sampai xray.
2. `ws-stunnel` membaca header PROXY protocol v2 (dan menanganinya bila tidak ada), sehingga
   jalur SSH lewat WS (443/80) juga mendapat IP klien asli, bukan `127.0.0.1`.
3. `live_ip_pairs()`: ambil token setelah literal `email:`, jangan buang `.`/`@`, buang bracket IPv6,
   jendela `LIVE_IP_WINDOW` (default 120 s), log bisa dialihkan untuk uji (`XRAY_ACCESS_LOG`).

**Bukti uji ulang (klien luar, sama, setelah perbaikan):**

| Uji | Sebelum | Sesudah |
|---|---|---|
| Log xray (klien vless/ws/TLS 443 dari 43.156.147.95) | `from 127.0.0.1:45350 ... email: staging-1` | `from 43.156.147.95:44050 ... email: staging-1` |
| `live_ip_pairs` | kosong | `staging-1 43.156.147.95` |
| `LOGIN_DATA` di `algojo-wibu` | kosong | `staging-1 43.156.147.95` |
| SSH lewat WS tanpa header IP apa pun | catatan `127.0.0.1` | catatan `43.156.147.95` (dari PROXY v2) |
| Sesi pelanggan asli (bukan uji) di `ws_client_ip.log` | `127.0.0.1` | `45.138.12.58` (IP asli) |

**Batas yang disadari:** `live_ip_pairs()` murni dari log, jadi perangkat yang benar-benar idle
lebih lama dari `LIVE_IP_WINDOW` lepas dari hitungan walau socket-nya masih terbuka; bila klien
lewat CDN pihak ketiga yang tidak mengirim `CF-Connecting-IP`/`X-Forwarded-For`, IP yang tercatat
adalah IP edge CDN (bukan pengguna akhir).

---

## 13. Akurasi KUOTA / PEMAKAIAN (SSH + xray) — 2026-11-16

Diminta pemilik: script akan dijual, jadi "pengecekan login IP sama bandwidth-nya harus akurat".
Hasil audit: kuota punya empat cacat, semuanya sudah diperbaiki dan diukur dengan trafik nyata.

**Cacat 1 — kuota SSH tak pernah diukur.** `algojo-kuota` hanya membaca statistik xray;
`limit_bw.db` untuk akun SSH tersimpan tapi pemakaiannya selalu 0 -> akun dengan kuota 10 GB
bisa dipakai ratusan GB tanpa terkunci.

**Cacat 2 — kuota SSH tak akan pernah terkunci walau diukur.** Cabang lock menjalankan
`jq -e ... index($u) != null` pada konfigurasi xray lebih dulu; akun SSH tidak pernah ada di sana,
jadi user dilewati sebelum kode lock dijalankan.

**Cacat 3 — arah trafik & statistik salah.** Parser lama hanya menghitung `downlink`
(unggahan besar "gratis") dan ikut memasukkan statistik per-inbound (mis. `vless-ws-tls`) sebagai
kalau itu user. Nama user ber-titik juga dipangkas sehingga tidak pernah cocok.

**Cacat 4 — sesi TANPA shell tidak terlihat.** `ssh -N -D` / `-L` (pola paling umum untuk VPN)
tidak meninggalkan proses shell, jadi atribusi uid gagal: user dianggap offline, dan
pemakaiannya nol. Kuncinya ada di log dropbear (dijalankan `-E` -> journald, **auth.log kosong**):
`dropbear[PID]: Password auth succeeded for 'user' from IP:port`.

**Perbaikan:**

1. **Akuntansi SSH dari counter kernel per-soket** (`ss -tie`: `bytes_sent + bytes_received`
   pada soket sesi) — bukan `iptables -m owner` (trafik pelanggan diproksikan proses root,
   dan hook INPUT memang ditolak backend nft). Semua forward SSH lewat soket sesi itu.
   Ledger per-soket (`pid.port`) membuat pembacaan berulang idempoten.
2. **xray: unggah+unduh dijumlah**, hanya baris `user>>>`, nama user utuh (`.`/`@` dijaga).
3. **Atribusi fallback dari log dropbear** -> sesi tanpa shell terdeteksi (login IP + kuota).
4. **Kuota SSH benar-benar mengunci**: cabang SSH dipindah SEBELUM guard konfigurasi xray
   (`lock_ssh_user user QUOTA_EXCEEDED`).
5. **Renew mereset pemakaian** (`usage_reset` di `renew_ssh_user`) — akun yang diperpanjang
   tidak langsung terkunci lagi; ledger soket tetap dipertahankan agar soket hidup tak dihitung ulang.
6. **`wibu-kuota`** (menu SSH [4] / `wibu-kuota SSH|VLESS|VMESS|TROJAN`): laporan
   user · protokol · terpakai · limit · sisa — angka dari sumber yang sama dengan penegakan.

**Bukti ukur (VPS uji, trafik sungguhan lewat tunnel):**

| Uji | Hasil |
|---|---|
| SSH: 2 × unduh 20.000.000 byte lewat SOCKS (`ssh -N -D`) | tercatat 40.196.968 byte (+0,49% overhead protokol) |
| SSH: `algojo-kuota` dijalankan ulang tanpa trafik baru | +0 byte (idempoten) |
| SSH: pemakaian 1.074.769.419 > limit 1 GiB | akun jadi `L` (locked) + `uji-bw:...:QUOTA_EXCEEDED` |
| SSH: sesi `ssh -N -D` (tanpa shell) | terdeteksi: `count=1`, IP `43.156.147.95` |
| xray: unduh 20.000.000 byte lewat vless/ws/TLS | pemakaian naik 20.034.479 byte (+0,17%) |
| Laporan `wibu-kuota SSH` | `uji-bw  SSH  0.04 GB  1 GB  0.96 GB` |

**Batas yang disadari:** angka SSH diambil dari byte pada soket sesi, jadi sesi yang hidup
lebih singkat daripada jeda `algojo-kuota` (~1 menit) bisa terlewat sebagian; sesi mati pun
tetap terhitung karena totalnya sudah tersimpan di `user_usage.db`.

---

## 14. UDP gateway, mode webhook bot, toleransi IP (v4.1.19)

Tiga hal yang diporting dari paket kerabat `v4.0-KURUMI`, dikerjakan ulang untuk struktur
repo ini, plus empat bug OTA yang ketemu justru saat memasangnya di VPS uji.

**1) UDP gateway (badvpn-udpgw).** Pesan akun SSH sudah lama mengiklankan `UDPGW 7100-7600`,
tetapi layanannya tidak pernah ada — pelanggan yang mengaktifkan UDP (game/DNS/QUIC) gagal
tanpa pesan. Kini `sbin/wibu-udpgw` membangun badvpn-udpgw dari sumber resmi
(`-DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1`, tanpa OpenSSL) dan menghidupkan unit
templated `badvpn-udpgw@<port>.service` untuk 6 port.

**Pelurusan protokol (dua hal yang membuat uji pertama gagal — catat baik-baik):**

1. Badan TCP dibingkai **PacketProto**: `[u16 panjang little-endian][paket udpgw]`.
   Tanpa bingkai ini, 2 byte pertama (flags+conid) dibaca sebagai panjang → paket dibuang.
2. Di dalam paket udpgw: `[u8 flags][u16 conid LE][alamat][u16 port]` — **port pada blok
   alamat memakai urutan NETWORK (big-endian)**, bukan little-endian seperti `conid`.
   Memakai little-endian di sini mengirim datagram ke **port acak** tanpa error apa pun.

**Bukti (klien uji nyata, tiga penyedia DNS, lewat sesi SSH pelanggan):**

| Uji | Hasil |
|---|---|
| `udpgw 7300 -> 1.1.1.1:53` (query DNS) | balasan 61 byte, `rcode=0`, 2 jawaban |
| `udpgw 7300 -> 8.8.8.8:53` | balasan 47 byte, `rcode=0`, 1 jawaban |
| `udpgw 7300 -> 1.0.0.1:53` | balasan 44 byte, `rcode=0`, 1 jawaban |
| Port listen | `127.0.0.1:7100 7200 7300 7400 7500 7600` (6/6 unit aktif) |
| Log server saat paket diterima | `connection 0: initialized` + `connection 0: from client N bytes` |

Tes ini ikut dikirim sebagai `tests/test_udpgw_live.sh` (dijalankan di VPS panel).

**2) Mode webhook bot Telegram — DIBATALKAN di v4.1.21 (keputusan pemilik, 2026-11-16).**
Fitur ini sempat dibuat lengkap (`sbin/bot-webhook-server` + antrean + menu [5] Mode Bot,
rute haproxy `/telehook` → `127.0.0.1:8443`, secret fail-closed, dan uji HTTP 503/403/400/200),
lalu **dicabut seluruhnya** supaya panel hanya punya satu cara kerja bot yang sederhana:
**polling**. Pemilik sebelumnya pernah tertahan masalah "ganti token bot lalu bot mati" yang
berakar pada ketidakcocokan state webhook; polling menghapus kelas masalah itu.

**Catatan kejujuran bukti (penting):** uji webhook yang sah hanyalah uji **lokal** di
`127.0.0.1:8443` (200 di `/health`, 503 tanpa secret, 403 secret salah, 400 body bukan JSON,
200 + masuk antrean) — itu respons server kita sendiri. Uji lewat domain **tidak** bisa
membedakan `503` milik server webhook dari `503` milik hub haproxy "tanpa backend untuk path
ini" (keduanya 503), jadi angka dari internet itu tidak dipakai sebagai bukti fail-closed.
Setelah rute `/telehook` dicabut, `POST https://<domain>/telehook` tetap menjawab 503 — kali
ini pasti dari hub haproxy karena tidak ada lagi ACL/backend untuk path tersebut dan tidak ada
yang mendengarkan `127.0.0.1:8443` (`ss` = 0).

Yang **tetap** ada setelah pencabutan (semua demi keamanan ganti token, bukan fitur webhook):
- ganti token di menu Setting **[1]** melepas webhook token lama **dan** token baru
  (`deleteWebhook` untuk keduanya);
- `bot-daemon` memanggil `bot_selfheal_polling()` saat start dan saat error **409**, yang
  menghapus webhook yang masih terpasang pada token ini (kalau ada sisa dari percobaan lama);
- berkas `sbin/bot-webhook-server`, `sbin/wibu-units`, rute `/telehook`, dan menu **[5] Mode Bot**
  sudah tidak ada lagi — kalau ke depan ada yang mencarinya, memang sengaja dibuang.

**3) Toleransi IP 600 detik** (`WIBU_IP_TTL`, sebelumnya 120): IP 5 menit lalu masih
dianggap terhubung (uji), IP 2 jam lalu diabaikan, dan nilainya bisa disetel.

**Empat bug OTA yang ketemu saat pemasangan (semua sudah diperbaiki + ada tesnya):**

1. **Unit systemd baru tidak ikut Update Script.** Menu [5] hanya menyelaraskan berkas,
   jadi `bot-webhook.service` (unit baru) terpasang 0 byte dan systemd menganggapnya
   *masked*. Ditambah `sbin/wibu-units` (tulis unit idempoten + unmask + daemon-reload)
   yang dipanggil setup.sh **dan** Update Script.
2. **Daftar update dibaca dari berkas yang sedang diganti.** Berkas baru
   (`sbin/wibu-udpgw`, `sbin/bot-webhook-server`, `sbin/wibu-units`) tidak ikut terpasang
   pada putaran itu → ditambah pass kedua yang membaca daftar dari m-setting yang baru.
3. **Modul tak pernah bisa lewat OTA.** `sbin/wibu-isp` dan `sbin/wibu-ssl-ulang` ada di
   setup.sh tetapi tidak ada di daftar Update Script. Kini ada penjaga paritas yang
   membandingkan kedua daftar (TEST 9) supaya kasus ini tidak terulang.
4. **Kuota API GitHub habis.** Tanpa token kuotanya 60/jam sedangkan satu putaran update
   meminta 30+ berkas → putaran ketiga gagal (terukur: `remaining=0`) dan verifikasi turun
   ke CDN sehingga satu berkas ditolak walau isinya benar. Manifest kini diambil **sekali**
   per putaran (API → jsDelivr → raw).

---

## v4.1.24 → v4.1.26 — "bot tahan reboot" dan harga sebuah klaim yang kurang teliti

Rangkaian ini berawal dari satu temuan saat audit VPS uji: `telegram-bot.service` **aktif 22 jam**
tetapi **`disabled`**. Artinya bot hidup hanya karena pernah di-`start` manual — satu reboot lagi
dan ia mati, tanpa error, tanpa jejak, sementara panel tetap jalan.

### Akar masalah (dibaca dari kode, bukan tebakan)

`setup.sh` meng-`enable` unit hanya saat instalasi **dan** hanya kalau token sudah ada. Menu
Setting → [6] hanya memanggil `systemctl start`/`restart`. Jadi urutan yang paling umum di lapangan
— pasang dulu, isi token belakangan — selalu berakhir dengan unit `disabled`.

### Tiga putaran rilis, dua di antaranya karena reviewer membantah

| Versi | Isi | Kenapa berubah |
|---|---|---|
| v4.1.24 | `bot_enable_guard()` dipanggil di semua jalur yang menyalakan bot; menu menampilkan status boot; Stop ikut `disable` | perbaikan awal |
| v4.1.25 | penanda `/etc/wibutunnel/bot_off` (Stop dihormati), repair `disable`+`reset-failed`, tes jadi behavioral | reviewer menemukan: Stop dibatalkan oleh update/repair, dan tes lama bisa **false-green** |
| v4.1.26 | gerbang `bot_boleh_jalan` untuk **start/restart** (bukan cuma `enable`), predikat `bot_conf_lengkap()` seragam, restore menulis penanda, tes 8 bagian | reviewer menemukan: `systemctl restart` menyalakan unit mati **walau** `disabled` — gejala yang sama, arah berlawanan |

Bukti bahwa temuan itu nyata, bukan teoretis — dijalankan di VPS dengan `systemctl` sungguhan:

| Keadaan | Hasil terukur |
|---|---|
| penanda `bot_off` ADA, lalu jalur Update Script | bot `inactive`, unit `disabled` (Stop bertahan) |
| penanda dihapus, jalur yang sama | bot `active`, unit `enabled` |
| konfigurasi tanpa `CHAT_ID` | tidak di-enable (tidak ada `failed` tiap boot) |

### Mutasi sebagai bukti tes bukan hiasan

Kritik "tes hanya hijau karena tidak mengukur apa pun" dijawab dengan tiga mutasi pada salinan
repo di `/tmp`. Ketiganya **memerahkan** suite, jadi asersinya benar-benar menjaga perilaku:

| Mutasi | Bagian yang gagal |
|---|---|
| hapus `touch /etc/wibutunnel/bot_off` di cabang Stop | [3/8] produsen penanda |
| buat `wibu-repair` `enable`+`restart` saat penanda ada | [5/8] perilaku repair |
| masukkan lagi `telegram-bot` ke restart massal | [2/8] gerbang restart |

Satu cacat harness juga ketemu di jalan: `mktemp -d` tanpa pemeriksaan membuat `"$TMP/etc/..."`
menjadi `"/etc/..."` — sebagai root itu berarti menulis `/etc` dan **memotong `/bin/systemctl`**.
Kini divalidasi (`-n` + `-d`) sebelum satu berkas pun ditulis.

### Angka akhir di VPS uji (4.1.26)

- OTA dua pass: **32/32 berkas, 0 gagal**; versi `4.1.23 → 4.1.26`
- hash terpasang == manifest untuk `menu/m-setting.sh`, `sbin/wibu-repair`, `menu/m-backup.sh`
- **0 failed unit**; haproxy/xray/dropbear/ws-stunnel/telegram-bot/wibu-daemon semua `active`+`enabled`
- suite offline: **10 suite hijau / 0 merah** (hardening 120 PASS, lisensi 15 PASS)
- `tools/verify-release.sh`: 13 pemeriksaan OK; 4 aset rilis diunduh ulang dan **byte-identik**
- residu akun uji `trial-7qys` dibersihkan sampai **0 jejak** di `/etc/xray` + `/etc/wibutunnel`

### Pelajaran yang dibawa ke skill

1. Menghormati "Stop" butuh gerbang pada `start`/`restart`; `enable` saja tidak cukup.
2. Predikat konfigurasi harus satu untuk semua berkas, kalau tidak menu dan repair saling bantah.
3. Tes konsumen tanpa tes produsen adalah hijau palsu; buktikan dengan mutasi.

### v4.1.27 dan v4.1.28 — dua jalur terakhir, dan satu pelajaran tak terduga

| Temuan | Bukti | Perbaikan |
|---|---|---|
| `setup.sh` langsung `enable`+`restart` saat konfigurasi lengkap → menjalankan ulang installer membatalkan `Stop` | cabang penanda tidak ada di blok itu | cabang `bot_off` diperiksa lebih dulu: stop + disable + `reset-failed` |
| `wibu-repair` memakai `source`, menu/installer memakai `grep` pola `KEY="…"` → berkas berkutip tunggal membuat **menu bilang belum diatur, repair menghidupkan bot** | parsing berbeda atas berkas yang sama | repair memakai `grep` yang sama; `source` dihapus |

**Pelajaran tak terduga di v4.1.28.** Harness tes memakai stub `systemctl` lewat `PATH`. Di VPS panel,
`bash -c` memuat lingkungan yang menimpa `PATH`, sehingga stub **tidak terpakai** dan blok yang diuji
memanggil `systemctl` sungguhan — terukur: bot berhenti dan ter-`disable` hanya karena menjalankan tes.
Perbaikannya: stub menjadi **fungsi bash yang di-export** + **sentinel** yang wajib tercatat sebelum
skenario dijalankan (fail-closed). Bukti sesudahnya, diukur di VPS panel:

| Keadaan | Sebelum tes | Sesudah tes |
|---|---|---|
| `telegram-bot` | `active/enabled` | `active/enabled` (15 PASS / 0 FAIL) |

Artinya suite ini sekarang benar-benar non-destruktif — bukan karena tujuannya begitu, tetapi karena
dibuktikan dengan membandingkan keadaan layanan sebelum dan sesudah.

### v4.1.29 — bug yang ditemukan justru oleh tes yang baru dibuat

Reviewer terakhir menemukan sesuatu yang tidak terlihat oleh delapan bagian sebelumnya: **`setup.sh`
menulis `bot.conf` tanpa tanda kutip**, sedangkan semua predikat membaca pola `^BOT_TOKEN="…"`.
Instalasi baru yang mengisi token saat instalasi karena itu jatuh ke cabang "belum diatur": unit
di-`disable`, bot di-`stop`, dan layar mengatakan bot belum diatur — padahal admin baru saja mengisinya.
Bila nanti dinyalakan lewat menu [2], `systemctl start` jalan tetapi guard menolak `enable`: bot hidup
sampai reboot lalu mati. Gejala v4.1.24, datang dari arah lain.

Perbaikannya bukan sekadar menambah kutip: penulis diseragamkan **dan** predikat dibuat toleran
(`^KEY="?[^"]+"?`) supaya berkas lama di VPS yang sudah jalan tidak tiba-tiba dinilai kosong.
Dijaga oleh bagian tes **[9/9]** yang menjalankan baris `printf` milik installer lalu menguji hasilnya
dengan predikat yang sebenarnya. Mutasi "kembalikan keadaan v4.1.28" memerahkan tiga asersi:

```
FAIL  predikat menu bilang belum lengkap tapi repair menghidupkan bot
FAIL  installer menulis format yang DITOLAK predikatnya sendiri (isi: BOT_TOKEN=111:AAA … )
FAIL  berkas tanpa kutip (format lama) ditolak -> upgrade mematikan bot yang tadinya jalan
```

Pelajaran: **uji penulis dan pembaca bersama-sama.** Delapan bagian sebelumnya menguji pembaca
(predikat, repair, gerbang) dan semuanya hijau — cacatnya ada di penulis yang tidak pernah dijalankan
tes mana pun.

---

## v4.1.30 → v4.1.31 — siklus penuh: uninstall, lalu pasang dari nol

Uji yang paling jujur: hapus panel dari VPS, lalu pasang lagi lewat jalur yang dipakai pengguna
(`install.sh` dari Release, token diisi saat instalasi). Dua bug muncul, keduanya tidak akan
terlihat dari suite offline.

### v4.1.30 — "uninstall bersih" ternyata tidak bersih

Setelah `uninstall.sh` selesai dan mengucapkan "VPS sudah bersih", kenyataannya:

| Sisa | Bukti |
|---|---|
| `wibu-kuota`, `wibu-udpgw` | masih ada di `/usr/local/{bin,sbin}` |
| unit `badvpn-udpgw@.service` | masih `enabled` |
| biner `/usr/sbin/badvpn-udpgw` + `/usr/local/src/badvpn-src` | masih ada |
| **6 proses** `badvpn-udpgw` | masih mendengarkan `127.0.0.1:7100-7600` |

Perbaikan: kedua skrip masuk daftar hapus; UDPGW dibersihkan (stop per-instance, disable, hapus
unit + biner + direktori build, `pkill`). Ditambah **invarian** di `test_hardening.sh`: setiap
berkas `sbin/*` dan `menu/*.sh` wajib disebut `uninstall.sh`. Sesudah perbaikan, diulang di VPS:

```
berkas tersisa: 0 | unit: 0 | proses udpgw: 0 | port 7100-7600: 0 | sshd port 22: OK
```

### v4.1.31 — instalasi baru ABORT karena pin Xray basi

Percobaan install pertama berhenti di tengah:

```
HASH TIDAK COCOK (dapat=91fd40e9… harap=a562d128…)
[FATAL] Hash instaleler Xray tidak cocok/kosong. ABORT
```

Fail-closed bekerja persis seperti desainnya — dan justru itu yang membuktikan instalasi baru
**tidak mungkin** dilakukan sebelum pin diperbarui. Pin diganti setelah inspeksi isi skrip upstream
(34.831 byte, `#!/usr/bin/env bash`, 176 rujukan `xray`, memasang `/usr/local/bin/xray` + unit),
bukan sekadar menyalin angka. Nilai baru dipakai `setup.sh` **dan** `uninstall.sh`, dengan tes baru
yang mewajibkan keduanya identik.

### Hasil instalasi bersih (v4.1.31, VPS kosong)

`bash install.sh test.priasawit.web.id` → **EXIT=0**, panel tampil, lisensi `STAGING` 29 hari.

| Pemeriksaan | Hasil |
|---|---|
| Versi terpasang | `4.1.31` (sama dengan judul README) |
| Unit | 9/9 `active` + `enabled` (xray, haproxy, dropbear, ws-stunnel, telegram-bot, algojo-expired, wibu-daemon, network-tune, wibutunnel-firewall) |
| UDPGW | 6/6 instance jalan; port 7100-7600 lokal |
| Port publik | 22, 80, 109, 143, 443 — sesuai tabel README |
| Port lokal | 10015 + 10085-10093 semuanya listen (sesuai tabel README) |
| Config | `haproxy -c` valid · `xray -test` OK · stats API menjawab |
| Perintah README | 15/15 ada (`menu`, `m-vless`, … `wibu-audit-akun`) |
| Failed unit / error log | 0 / 0 baris |

**Regresi yang dikunci oleh siklus ini** — bug v4.1.29 hanya bisa dibuktikan lewat instalasi baru:
`setup.sh` menulis `bot.conf` ber-kutip, dan hasilnya di VPS:

```
BOT_TOKEN="8905724783:***"     <- ber-kutip, ditulis installer
CHAT_ID="5851934765"
unit: active/enabled            <- guard menerima formatnya sendiri
webhook: ""                     <- murni polling
```

Sebelum v4.1.29, berkas ini ditulis tanpa kutip, dibaca oleh predikat yang menuntut kutip, dan bot
tidak akan pernah `enabled` — persis yang tidak terlihat pada VPS yang sudah berjalan.
