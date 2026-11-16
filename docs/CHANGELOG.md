# 📝 Changelog WIBUTUNNEL

Riwayat rilis. Versi terbaru di atas. Tiap rilis punya tag + aset di https://github.com/WBVPN/wibutunnel/releases

---

### v4.1.23 (2026-11-16)

- **Mode webhook bot DICABUT total** (keputusan pemilik): panel kembali ke satu cara kerja bot —
  **polling**. Dibuang: `sbin/bot-webhook-server`, `sbin/wibu-units`, menu [5] Mode Bot, antrean
  `tmp/bot_webhook_queue.jsonl`, penanda `tmp/bot_mode`, rute haproxy `/telehook` + backend 8443.
- **Ganti token bot tetap aman**: menu Setting [1] melepas webhook token lama & token baru;
  `bot-daemon` menghapus sendiri webhook yang masih nyangkut saat start maupun saat error 409.
- **`config/haproxy.cfg` yang dikirim (dipakai Auto-Repair) disamakan** dengan config terverifikasi:
  rantai `send-proxy-v2`/`accept-proxy` kembali ada (tanpa ini xray melihat klien dari 127.0.0.1 →
  IP pelanggan tak terdeteksi), sisa rute webhook dibuang. Dijaga oleh `tests/test_udpgw.sh` TEST 6b.
- **README dirapikan** (changelog pindah ke berkas ini), tes integrasi yang butuh panel terpasang
  kini **melewati diri sendiri** dengan pesan jelas bila dijalankan di luar VPS panel.

---

### v4.1.22 (2026-11-16)

- **`config/haproxy.cfg` yang dikirim (dipakai Auto-Repair bila repo ada di
  `/root/wibutunnel-repo`) disamakan** dengan konfigurasi VPS yang terverifikasi: rantai
  **PROXY protocol v2** (`send-proxy-v2` di `ws_tunnel`/`hub443`/`hub80` + `accept-proxy` pada
  bind 8444/8445) kini ada di berkas itu. Tanpa ini, Auto-Repair akan mengembalikan bug lama:
  xray melihat klien dari `127.0.0.1` sehingga IP pelanggan tak terdeteksi.
- Sisa rute `/telehook` + `backend webhook_server` di berkas itu **dibuang** (kelanjutan
  pencabutan mode webhook di v4.1.21).
- `tests/test_udpgw.sh` **TEST 6b** menjaga keduanya.

### v4.1.21 (2026-11-16)

- **Mode webhook bot Telegram DIBATALKAN** (keputusan pemilik: "biar ke depan tidak bingung").
  Panel kembali ke satu cara kerja bot: **polling**. Penanganan aman saat ganti token tetap:
  webhook token lama & baru dilepas, dan `bot-daemon` menghapus sendiri webhook yang masih
  nyangkut saat start maupun saat error 409. Rute `/telehook` dan layanan penerima webhook
  dihapus dari panel.

### v4.1.20 (2026-11-16)

- **Ganti token bot tidak lagi "membuat bot mati".** Saat token diganti, webhook milik
  **token lama** dilepas dan mode menyesuaikan: webhook -> `setWebhook` ulang untuk token
  baru; polling -> `deleteWebhook` + penanda mode dipastikan `polling`. (Gejala lama:
  `getUpdates` dijawab **409 Conflict** karena webhook masih terpasang, bot tampak mati.)
- **Rekonsiliasi otomatis di daemon**: saat mode polling tapi Telegram masih menyimpan
  webhook untuk token itu, `bot-daemon` membersihkannya sendiri di awal (dan saat error 409).

### v4.1.19 (2026-11-16)

- **UDP gateway (badvpn-udpgw) benar-benar dipasang.** Pesan akun SSH sudah lama
  mengiklankan `UDPGW 7100-7600`, tapi layanannya belum pernah ada — klien yang
  mengaktifkan UDP (game/DNS/QUIC) gagal. Kini `sbin/wibu-udpgw` membangun badvpn-udpgw
  dari sumber resmi (hanya target udpgw) dan menghidupkan unit templated
  `badvpn-udpgw@<port>.service` untuk 6 port.
- **Mode webhook untuk bot Telegram.** `sbin/bot-webhook-server` menerima update dari
  Telegram lewat rute `/telehook` (haproxy -> 127.0.0.1:8443), memvalidasi header
  `X-Telegram-Bot-Api-Secret-Token` **fail-closed**, lalu menaruh update di antrean yang
  dikonsumsi `bot-daemon` (tanpa `getUpdates`, jadi tidak bentrok 409). Ganti mode dari
  menu Setting -> Bot Telegram -> **[5] Mode Bot**.
- **Toleransi IP 600 detik** (`WIBU_IP_TTL`, sebelumnya 120) supaya pelanggan yang
  berpindah jaringan/roaming tidak salah dianggap lepas atau salah terkunci.
- Menu SSH **[14] Pasang / Perbaiki UDP Gateway** untuk memasang ulang stack UDP.

### v4.1.18 (2026-11-16)

- **Deteksi user SSH diperbaiki (akurat).** Pemilik socket sesi adalah dropbear yang jalan
  sebagai `root`; user sebenarnya ada di keturunan proses. Akibat bug lama: sesi tak pernah
  dihitung sehingga limit IP SSH tak pernah terpicu, dan daftar IP aktif menampilkan IP klien lain.
- **IP klien asli untuk sesi lewat WS (443/80).** `ws-stunnel` membaca header
  `CF-Connecting-IP`/`X-Forwarded-For` **dan** header PROXY protocol v2 dari haproxy.
- **Deteksi user XRAY diperbaiki.** Rantai haproxy hanya mengirim PROXY protocol di hop terakhir,
  jadi xray melihat `127.0.0.1` dan baris itu dibuang panel -> **daftar user xray online selalu
  kosong** dan limit IP xray tak pernah terpicu. Kini `send-proxy-v2` diteruskan sejak frontend.
- **Nama user ber-titik/`@`** (mis. `roodyz.prem`) tak lagi salah dipangkas saat dibaca dari log.
- **User sistem `sshd`** (privsep) tak lagi terhitung sebagai sesi pelanggan.

### v4.1.17 (2026-11-16)
Perbaikan daftar lisensi + tampilan masa aktif:

- **Daftar lisensi diambil dari API GitHub lebih dulu** (`Accept: application/vnd.github.raw`); `raw.githubusercontent`
  dan jsDelivr hanya cadangan. Sebabnya terukur: setelah entri lisensi baru di-push ke `main`, raw **masih
  menyajikan `izin.txt` versi lama** (cache-buster tak menolong) sehingga **IP yang sah tertolak**.
- **Validasi isi daftar:** balasan yang bukan daftar lisensi (halaman galat/terpotong) tidak lagi diperlakukan
  sebagai daftar, jadi tidak membuat IP sah ikut tertolak.
- **Dashboard:** masa aktif `lifetime` dicetak apa adanya; entri bertanggal ditampilkan sebagai **`30 Hari`**
  (sisa hari, dibulatkan ke bawah). Tanggal tetap jadi sumber kebenaran di `izin.txt`/cache, hanya tak dipajang.
- **Uji:** `test_setup_flow` & `test_deep_audit_fixes` tidak lagi mengunci jalur absolut `/root/wibutunnel-repo`.

### v4.1.16 (2026-11-15)
Dua masalah Ubuntu 24.04, keduanya bisa menggagalkan instalasi total:

- **`/tmp` = tmpfs `noexec`.** Ubuntu 24.04 memasang `/tmp` sebagai tmpfs tanpa izin eksekusi. Installer resmi
  Xray menjalankan biner pemeriksa versi dari `/tmp` -> `error: Local Xray binary cannot run`. Installer kini
  mengarahkan `TMPDIR` ke `/usr/local/src` sebelum memanggil installer resmi.
- **Installer resmi Xray butuh kuota API GitHub** (`Failed to get release list`, HTTP **403** saat kuota
  anonim 60/jam habis - mudah terjadi karena verifikasi berkas juga memakai API). Kini ada **jalur cadangan**:
  unduh langsung `Xray-linux-64.zip` dari aset rilis versi terpin (**tanpa API**), verifikasi **hash biner**,
  pasang biner + geodata + user + unit systemd sendiri. Bila jalur utama gagal, instalasi **tidak berhenti**.
- Rantai unduhan berkas juga berhenti memakai API setelah menerima 403/429.

### v4.1.15 (2026-11-15)
- **Regex awk portabel (penyebab instalasi setengah jadi di Debian 11).** Validasi manifest memakai
  `$1 ~ /^[0-9a-f]{64}$/`. Debian 11 memakai **mawk 1.3.4** yang **tidak mendukung interval `{64}`**,
  sehingga manifest yang isinya benar dinilai tidak sah:
  `[!] Manifest SHA256SUMS (ref ...) tidak dapat diambil.` -> semua berkas `hash tidak cocok` -> ditolak
  -> `[!] Ada file yang gagal diunduh`. Terukur di VPS: bentuk `{64}` = **0** baris sah, bentuk
  `length($1)==64` = **59** baris sah. Sekarang memakai bentuk portabel (`length($1) == 64 && $1 ~ /^[0-9a-f]+$/`)
  dan ada cek harness agar pola ber-interval tidak kembali.

### v4.1.14 (2026-11-15)
- **Debian 11 (EOL) sekarang bisa dipasang.** Bullseye sudah EOL: `security.debian.org` menjawab **404**
  untuk seluruh paket, dan image VPS umumnya menambah mirror pihak ketiga yang rusak. Hasilnya
  `apt-get install` mustahil berhasil (diuji: 47 paket gagal 404). Installer kini mendeteksi bullseye dan
  mengalihkan repo ke arsip resmi `archive.debian.org` (+ `Acquire::Check-Valid-Until "false"` karena
  arsip memang kedaluwarsa), serta menonaktifkan sumber `*backports*` yang tidak ada di arsip.
  `sources.list` lama dicadangkan ke `/etc/apt/sources.list.bak.wibutunnel`.

### v4.1.13 (2026-11-15)
- **Debian 11 bisa dipasang (temuan lapangan).** Image minimal bullseye **tidak punya `dig`**; validasi
  domain bergantung padanya, dan percobaan memasang `dnsutils` di tahap itu bisa gagal (apt tanpa pemaksaan
  IPv4, tepat sesudah IPv6 dimatikan). Akibatnya domain yang BENAR ditolak:
  `dig: command not found` -> `[!] Domain tidak valid!` -> `[!] Input berakhir (EOF)` -> instalasi berhenti
  sebelum apa pun terpasang.
  Sekarang resolver memakai rantai tanpa ketergantungan paket: **dig -> host -> nslookup -> `getent ahostsv4`**
  (getent selalu ada karena bagian glibc), dan pemasangan `dnsutils` dibuat best-effort dengan pemaksaan IPv4.

### v4.1.12 (2026-11-15)
- **Cache manifest per ref + divalidasi.** Cache `wibu-manifest` (satu berkas, tanpa nama ref) membuat
  rilis berikutnya memverifikasi berkas baru terhadap **manifest lama** - gejala lapangan: `hash tidak cocok`
  untuk berkas yang baru diubah padahal sumbernya benar, lalu berkas ditolak dan instalasi tidak lengkap.
  Sekarang nama cache memuat ref, isinya wajib berbentuk manifest (`sha256  nama`, >= 10 baris) dan
  diambil ulang bila tidak sah (respons JSON/HTML tidak lagi bisa dipakai sebagai manifest).

### v4.1.11 (2026-11-15)
Dua bug ditemukan saat memasang di VPS pelanggan nyata (Ubuntu 20.04):

- **Instalasi/update tidak lengkap karena CDN basi.** `raw.githubusercontent.com` bisa menyajikan isi **lama**
  dengan HTTP 200 untuk tag yang baru dibuat; hash tidak cocok lalu berkas **ditolak** (fail-closed bekerja),
  tetapi tidak ada sumber cadangan - akhirnya menu/skrip tetap versi lama dan muncul
  `[!] Ada file yang gagal diunduh` di akhir. Sekarang setiap berkas dicoba berurutan:
  **raw -> API GitHub (otoritatif, tanpa CDN) -> jsDelivr -> raw lagi**, dan **hash diperiksa di setiap sumber**
  sebelum dipakai. Jatah API hanya terpakai kalau hash memang tidak cocok.
- **Reinstall/update menghapus SEMUA akun pelanggan.** Config baru ditulis dengan `clients: []` dan
  `/etc/xray/vless_exp.conf` + `vmess_exp.conf` **ditimpa** daftar dummy. Sekarang: daftar masa aktif hanya
  dibuat bila berkas belum ada, dan daftar klien lama disimpan sebelum config baru ditulis lalu
  **dipasang kembali** (digabung, dedupe per id) - akun pelanggan selamat dari update.

### v4.1.10 (2026-11-15)
- **Nama ISP pendek.** Sebelumnya menu & pesan akun menampilkan mentah dari `ip-api.com`, contoh:
  `Shenzhen Tencent Computer Systems Company Limited`. Sekarang diringkas otomatis (`Tencent Cloud`,
  `AWS`, `Alibaba Cloud`, `Contabo`, `Contabo`, `Hetzner`, ...).
- **Bisa ditimpa manual** (menang atas deteksi otomatis):
  ```bash
  echo "WIBU Cloud" > /etc/wibutunnel/isp.txt     # boleh nama brand sendiri
  ```
  Berguna kalau mau menampilkan brand toko sendiri di info akun pelanggan.

### v4.1.9 (2026-11-15)
- **Tahan batas laju Let's Encrypt.** Let's Encrypt membatasi 5 sertifikat / 7 hari per domain; pelanggan yang
  memasang ulang beberapa kali akan kena dan sebelumnya **instalasi langsung berhenti** (`SSL GAGAL`).
  Sekarang: sertifikat **sementara** dipasang supaya layanan tetap jalan, plus **penjadwal otomatis**
  (`wibutunnel-ssl-ulang.timer`) yang menerbitkan sertifikat resmi begitu kuota pulih, lalu mengganti
  sertifikat sementara + reload HAProxy - tanpa perlu pelanggan melakukan apa pun.
- Skrip `wibu-ssl-ulang` + unit systemd-nya ikut dibersihkan saat uninstall.

### v4.1.8 (2026-11-15)
- **Ubuntu 22.04 (jammy) teruji lapangan**: HAProxy 2.4.30 `Configuration file is valid`, certbot 1.21.0 menerbitkan
  sertifikat, dropbear **0 kegagalan start** (tambalan `NO_START` bekerja), 8/8 layanan, reboot bersih.
- Temuan jammy: image minimal **tidak menyertakan `systemd-timesyncd`** sehingga jam tidak tersinkron. Sekarang
  dipasang lebih dulu bila belum ada - **non-fatal**, supaya konflik paket `ntp`/`chrony` tidak pernah membatalkan instalasi.

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
