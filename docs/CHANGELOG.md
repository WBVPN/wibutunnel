# 📝 Changelog WIBUTUNNEL

Riwayat rilis. Versi terbaru di atas. Tiap rilis punya tag + aset di https://github.com/WBVPN/wibutunnel/releases

---

### v4.1.45 (2026-11-20)

**Status online yang bisa dibuktikan (VLESS · VMESS · TROJAN · SSH).** Permintaan user: "on ya tercatat,
off ya tidak". Versi lama hanya punya satu sinyal — ada baris `accepted` di `access.log` dalam 60 detik
terakhir — sehingga pelanggan yang tersambung tapi idle hilang dari daftar, sementara yang sudah
disconnect masih tampil sampai satu menit.

- `common.sh`: `xray_presence()` menggabungkan **dua** sinyal — socket ESTABLISHED ke `:80/:443` dari
  IP user (bukti paling kuat: selama socket terbuka user tetap online walau idle), dan aktivitas nyata
  di `access.log` bila socket tak terlihat (jalur CDN). Keluaran `user|state|age|ip,ip`.
- Umur memakai **aktivitas terbaru**, bukan yang tertua, dan dihitung relatif terhadap baris terbaru
  di log + lamanya berkas tidak ditulis — supaya log yang tidak monoton atau beda zona waktu (xray UTC,
  panel lokal) tidak membuat semua pelanggan tampak offline.
- Edge Cloudflare bukan identitas pelanggan: bila user punya IP asli, IP edge dibuang dari laporan;
  bila hanya terlihat edge, kolom IP dikosongkan dan statusnya `Online via CDN`.
- `menu/cek-trafik.sh`: status `Online` / `Terakhir terlihat N lalu`; IP hanya dihitung saat user
  benar-benar online, sehingga tidak ada lagi `MELANGGAR LIMIT IP` dari koneksi yang sudah tertutup.
- `menu/bot-daemon.sh`: `/online` memakai presence yang sama — bot dan menu tidak bisa berbeda pendapat.
- `tests/test_presence.sh` (baru, 20 asersi) mengunci kasus yang sebelumnya lolos: format `ss` asli
  4 kolom, socket hanya di `:22` tidak dihitung, log tidak monoton, log bergeser 8 jam, user dua IP,
  IP CDN historis, dan TTL.

Dua bug ditemukan reviewer sebelum rilis dan diperbaiki di rilis yang sama: `ss` dengan filter `state`
mengeluarkan 4 kolom sehingga `peer=$5` selalu kosong (sinyal socket mati total) → sekarang `$NF` +
filter port; dan `continue` pada TTL tidak mengeluarkan user dari daftar sehingga muncul `online|0` palsu.

Bukti di VPS uji: `adminwibu|online|5|140.213.58.222,140.213.219.37` dan menu menampilkan
`Status: Aktif / Online`, `IP Aktif: 2 IP`. Jalur SSH (`ssh_session_count`, berbasis socket):
saat sesi hidup `1`, setelah logout `0`.

Suite: `test_ip_cdn` 18/18 · `test_ip_live` 13/13 · `test_kuota_latency` 15/15 ·
`test_presence` 20/20 · `test_hardening` 149 PASS / 0 FAIL.

---

### v4.1.44 (2026-11-20)

**IP asli pelanggan di balik Cloudflare.** Laporan user: akun VLESS aktif dipakai, tapi menu
"ONLINE USERS (LIVE)" kosong dan IP-nya tidak terlihat. Penyebabnya bukan akunnya: semua paket
datang dari edge Cloudflare (`162.158.x`, `172.64.x`, `104.23.x`), dan panel membuang IP CDN demi
menjaga limit-IP. Padahal Cloudflare sudah mengirim IP asli client di header `CF-Connecting-IP`.

- HAProxy (`http_hub80` & `http_hub443`) menjalankan `http-request set-src hdr(CF-Connecting-IP)`
  sehingga sambungan ke Xray membawa IP asli lewat PROXY protocol v2 (sudah dipakai semua backend).
  Xray pun mencatat IP asli, bukan IP edge.
- Header **hanya** dipercaya bila sambungan datang dari rentang Cloudflare (`acl from_cf src -f
  /etc/haproxy/cf-ip.lst`); daftar 22 rentang diunduh dari cloudflare.com dan divalidasi CIDR-nya,
  dengan daftar bawaan sebagai cadangan. Tanpa pagar ini, siapa pun bisa memalsukan header dan
  lolos dari limit IP.
- `cek-trafik.sh` kini memakai `live_ip_pairs()` — sumber tunggal yang sama dengan `algojo-wibu` —
  bukan logika sendiri (dulu: jendela 3 menit, tanpa filter CDN). Efek nyata: menu sempat
  melaporkan "MELANGGAR LIMIT IP 87 IP" padahal penegaknya melihat 1 IP. Pengguna yang hanya
  terlihat lewat CDN kini berstatus "Aktif via CDN (IP asli tidak terlihat)", bukan hilang.

Verifikasi di VPS uji: setelah reload, 12 sambungan berturut-turut tercatat `from 140.213.42.251`
(IP asli, bukan edge CF), menu menampilkan `Status: Aktif / Online`, `IP Aktif: 1 IP (Limit: 10 IP)`.

---

### v4.1.43 (2026-11-19)

**Tampilan uninstaller.** Tidak ada perubahan logika penghapusan — yang berubah hanya keluarannya,
karena versi v4.1.42 mencetak progress meter `curl` di tengah proses dan baris `[i]`/`[!]` yang
berserakan sehingga terlihat seperti script setengah jadi.

- Progress meter hilang: unduhan uninstaller resmi Xray memakai `curl -sS` (diam, tapi pesan error
  tetap tampil). Dulu `% Total % Received … Dload Upload` ikut tercetak di antara langkah-langkah.
- Keluaran berformat langkah: `[1/7] Menghentikan layanan panel` … `[7/7] Sisa sistem` dengan centang
  per langkah, bukan baris `[i]`/`[!]` tanpa konteks.
- Header menyebut **domain & versi** panel yang sedang dihapus (dibaca sebelum `/etc/wibutunnel`
  dihapus), dan ringkasan akhir menyebut path backup, jumlah akun yang dihapus, keputusan swap,
  penegasan bahwa port 22 tidak disentuh, plus perintah pasang ulang.
- `tests/test_hardening.sh` tidak berubah jumlahnya (134 asersi); `README` hash `setup.sh` +
  `uninstall.sh` diperbarui, `SHA256SUMS` dibuat ulang.

Verifikasi suite: `test_ip_cdn` 18/18 · `test_ip_live` 13/13 · `test_kuota_latency` 15/15 ·
`test_hardening` 134 PASS / 0 FAIL · `sha256sum -c SHA256SUMS` bersih.

---

### v4.1.42 (2026-11-19)

**Satu perintah pasang, tanpa domain di command.** Domain (dan token bot) ditanya di tengah
proses, jadi tidak ada lagi dua "cara" yang harus dipilih pembaca.

- `install.sh` kini menyerahkan terminal ke `setup.sh` — `exec bash "$TMP" "$@" </dev/tty` — bila
  stdin bukan TTY. Efeknya `curl -4 -fsSL <url install.sh> | bash` juga jalan, bukan cuma
  `bash <(curl ...)`. Penyerahan sengaja dilakukan di baris **terakhir** (`exec`): pada mode pipa
  bash membaca sisa skrip dari fd 0, jadi `exec </dev/tty` di tengah skrip akan membuat bash membaca
  perintah dari terminal.
- Penjaga dini dipersempit: hanya menyala bila **benar-benar** tidak ada terminal **dan** tidak ada
  domain (cron/CI). Pesannya sekarang menyebut dua bentuk perintah yang sah.
- Regresi v4.1.41 diperbaiki: penjaga itu tidak lagi memblokir `WIBU_BOOTSTRAP_ONLY=1` lewat pipa,
  sehingga mode "cetak tag + hash lalu keluar" tetap bisa dipakai sebagai gerbang rilis.
- `README.md`: satu blok perintah utama; varian otomasi tanpa TTY dan cek-hash dipindah ke
  `<details>` supaya tidak bersaing dengan perintah yang dipakai 99% orang.
- `tools/verify-release.sh`: mencetak perintah pasang single-link.
- `tests/test_hardening.sh`: 129 → 131 asersi (penyerahan `/dev/tty`, perintah single-link di README).
- **Uninstaller: tiga hal yang dulu menghapus milik orang lain.**
  (1) Akun SSH pelanggan kini **ikut dihapus** (`hapus_akun_panel`, daftar dari `/etc/xray/ssh_exp.conf`,
      dibatasi uid ≥ 1000 **dan** anggota grup `ssh_tunnel`). Sebelumnya akun tertinggal di `/etc/passwd`
      dengan shell `/bin/bash`, sementara sshd port 22 tidak disentuh — pelanggan yang belum kedaluwarsa
      masih bisa login ke VPS setelah panel dihapus.
  (2) `/swapfile` hanya dihapus bila **panel** yang membuatnya: `setup.sh` menulis penanda
      `/etc/wibutunnel/.swapfile_panel`, uninstaller membacanya **sebelum** `/etc/wibutunnel` dibuang.
      Sebelumnya swap milik VPS ikut terhapus tanpa syarat (dan barisnya di `/etc/fstab` juga).
  (3) Tidak ada lagi `iptables -t mangle -F`. Dulu seluruh tabel mangle di-flush sehingga aturan
      QoS/firewall/klasifikasi milik admin hilang — bukan cuma di uninstaller, tapi juga di
      `network-tune` yang dijalankan berkala. Sekarang yang dihapus hanya 4 aturan
      `CLASSIFY --set-class 1:1` milik panel (daftar sama di ketiga tempat), lalu dipasang ulang —
      jadi idempoten tanpa menyentuh aturan lain.
  Yang **belum** diubah dan perlu diketahui: `/etc/iptables/rules.v4` disimpan apa adanya dan
  `netfilter-persistent` tetap di-disable saat uninstall; `network-tune` juga masih melakukan
  `tc qdisc del ... root` di setiap interface.
- `tests/test_hardening.sh`: 131 → 134 asersi (tiga asersi penjaga untuk akun panel, penanda
  `/swapfile`, dan larangan flush mangle).
- `SHA256SUMS` dibuat ulang; `EXPECT` di `install.sh` + hash di README mengikuti `setup.sh` baru
  (`25ed1895…` → `b1c19fa7…`), hash `uninstall.sh` di README jadi `4805af47…`.

Terbukti di VPS baru (Ubuntu 24.04, `103.150.61.138`, domain `id.priasawit.web.id`, lisensi VPSTEST):
satu perintah → 8/8 pemeriksaan installer `[OK]` → 10 unit inti `active` **dan** `enabled` →
sertifikat Let's Encrypt valid untuk domain → login akun SSH uji di port 143 `OK` → handshake
WebSocket `HTTP/1.1 101` → `xray -test` OK → tahan reboot (semua unit kembali, `failed: 0`).

Verifikasi suite: `test_ip_cdn` 18/18 · `test_ip_live` 13/13 · `test_kuota_latency` 15/15 ·
`test_hardening` 131 PASS / 0 FAIL · `sha256sum -c SHA256SUMS` bersih.

---

### v4.1.41 (2026-11-19)

**Rilis dokumen & mutu uji.** Tidak ada perubahan pada penegakan (limit IP, kuota, sesi) maupun
konfigurasi Xray/HAProxy — yang diperbaiki adalah jalur pemasangan, teks keluaran, dan daya jaga tes.

- `install.sh` berhenti menyarankan `... | bash` **tanpa** argumen domain. Pada mode pipa `stdin`
  sudah habis dipakai membaca skrip dan proses `setup.sh` mewarisinya, sehingga pertanyaan domain
  dijawab `Input berakhir (EOF)`. Sekarang ada penjaga dini: stdin bukan terminal + domain kosong →
  berhenti dengan pesan jelas **sebelum** apt/konfigurasi disentuh (terbukti: `bash install.sh </dev/null` → exit 1).
- `tests/test_ip_cdn.sh`: fixture `access.log` memakai tanggal **relatif**. Dengan tanggal mati
  (`2026/11/18`) + `LIVE_IP_WINDOW=86400`, `awk` berhenti pada baris pertama yang kedaluwarsa — jadi
  2 asersi merah **sendiri** sehari setelah fixture ditulis, tanpa ada kode yang berubah. Terukur
  2026-11-19: 16/18 merah → 18/18 hijau setelah diperbaiki.
- `tests/test_hardening.sh`: +3 asersi (penjaga pipa `install.sh`, perintah pasang `verify-release`,
  fixture tanpa tanggal mati) dan sekarang **keluar ≠ 0** bila ada FAIL — sebelumnya selalu `exit 0`,
  sehingga hasil merahnya tidak bisa dipakai sebagai gerbang.
- `tools/verify-release.sh`: mencetak dua bentuk perintah pasang yang benar (interaktif + satu baris
  dengan domain sebagai argumen).
- `README.md`: bagian Instalasi memisahkan **Cara 1 (interaktif)** dan **Cara 2 (satu baris, domain
  wajib)** + sebab `| bash` polos gagal; tabel Enforcement mendapat baris `wibu-acct` (sampler byte SSH
  0,5 dtk & kuota SSH jalur cepat ≤5 dtk) yang sebelumnya tidak terdokumentasi.
- `sbin/wibu-kuota`: catatan refresh usang ("~1 menit") diperbaiki — SSH ~5 dtk via `wibu-acct`,
  xray ~1 menit via `algojo-kuota`.
- `SHA256SUMS`: dibuat ulang. Sekaligus memperbaiki entri `izin.txt` yang **basi** sejak commit
  `izin_add` (izin.txt tidak diverifikasi hash saat instalasi, jadi tidak menggigit — tetapi manifest
  yang tidak cocok tetap bahaya).

Verifikasi: `test_ip_cdn` 18/18 · `test_ip_live` 13/13 · `test_kuota_latency` 15/15 ·
`test_hardening` 127 PASS / 0 FAIL · `sha256sum -c SHA256SUMS` bersih.

---

### v4.1.40 (2026-11-18)

**Fail-safe jendela IP.** Kalau `WIBU_IP_TTL` / `LIVE_IP_WINDOW` diisi nilai yang tidak bisa
dibaca `date` (salah ketik, satuan keliru), `thresh` menjadi kosong dan **seluruh isi
`access.log` dianggap aktif** — persis kondisi yang memicu kunci "melebihi limit IP" palsu.
Sekarang nilai angka polos dipahami (`60` = 60 detik) dan nilai rusak jatuh ke jendela **0**
(tidak ada IP dihitung), bukan menghitung semuanya.

Ditemukan saat mencoba mengukur ulang efek jendela 600 dtk di VPS: `LIVE_IP_WINDOW=600`
(ditulis tanpa kata "seconds" oleh saya sendiri) gagal di-parse dan menghasilkan hitungan IP
yang salah. Nilai yang sakral tidak boleh punya jalur "gagal terbuka".

Tes `tests/test_ip_live.sh` 11 → **13 asersi**: angka polos dipahami, dan nilai rusak harus
menghasilkan **nol** IP.

---

### v4.1.39 (2026-11-18)

**Limit IP kini menghitung koneksi yang benar-benar hidup, bukan jejak log 10 menit.**

Dengan jendela 600 detik, pelanggan yang sudah berhenti konek masih dihitung memakai IP lama.
Akibat nyatanya: pindah jaringan (WiFi → data) dalam rentang 10 menit terhitung **2 IP**, lalu
akun kena kunci 15 menit padahal satu orang satu perangkat.

| jalur | cara lama | cara sekarang |
|---|---|---|
| XRAY | `access.log` dalam **600 dtk** | `access.log` dalam **60 dtk** (`WIBU_IP_TTL` / `LIVE_IP_WINDOW`) |
| SSH | sudah dari socket (tidak berubah) | tetap `ss -tnp state established`, port sesi saja (22/109/143/2222) |

Tambahan kecil: `ssh_ss_lines()` sekarang menerima berkas contoh (`SSH_SS_SRC`) untuk uji offline,
dan komentar menyesatkan di `algojo-wibu` ("liveness dari socket ESTABLISHED :443") dihapus — klaim
itu tidak pernah ada di kodenya.

**Tes baru `tests/test_ip_live.sh` (11 asersi, dibuktikan MERAH dulu):** entri 30 dtk & 59 dtk
dihitung; 61 dtk, 5 menit, dan 2 jam tidak; jendela bisa disetel; sesi SSH terdeteksi dari socket
ESTABLISHED; user yang hanya muncul di catatan log autentikasi **tidak** dihitung; socket non-sesi
(port 59000) diabaikan.

Efek samping yang ikut diperbaiki: `tests/test_udpgw.sh` TEST 4 dulu memaku perilaku lama ("IP 5
menit lalu harus terbaca") — sekarang memaku perilaku baru, dan tetap menguji bahwa
`WIBU_IP_TTL=600` mengembalikan perilaku lama.

Mutasi yang diuji: jendela dikembalikan 600 (tertangkap), hook `SSH_SS_SRC` dihapus (tertangkap),
filter port sesi dilepas (tertangkap).

---

### v4.1.38 (2026-11-18)

Tiga cacat pada `kuota_scan_ssh()` (jalur cepat v4.1.37), ditemukan lewat review mandiri +
mutasi, bukan lewat pemakaian.

1. **`flock` tetap dipegang notifikasi.** Subshell pengirim Telegram mewarisi fd 198, jadi lock
   kuota tetap terkunci selama `curl` berjalan (sampai 10 detik) dan pemindaian berikutnya
   **dilewati tanpa pesan error**. Sekarang subshell menutup fd itu lebih dulu (`exec 198>&-`).
   Dibuktikan eksperimen: tanpa penutupan, `flock -n` gagal 0,3 dtk setelah pemindaian selesai.
2. **Akun sistem bisa dikunci.** `lock_ssh_user()` menjalankan `pkill -u`; satu baris `root:1` di
   `limit_bw.db` akan mematikan seluruh panel. Sekarang akun dengan uid < 1000 dilewati.
3. **Baris ber-CRLF dilewati diam-diam.** DB yang pernah disunting di Windows membuat
   `limit_gb="1\r"` gagal regex → akun tak pernah ditegakkan. Sekarang CR dan spasi dibersihkan
   per baris **dan** per field.

**Tes** `tests/test_kuota_latency.sh` naik 12 → **15 asersi**: baris CRLF harus terkunci, akun
uid 0 tidak boleh terkunci, dan lock harus langsung bebas walau notifikasi masih berjalan.
Enam mutasi diuji, semuanya tertangkap: CR-cleaner dihapus, guard uid dihapus, `exec 198>&-`
dihapus, `>=` → `>`, guard `locked_users` dihapus, `flock` dilepas.

**Catatan kejujuran:** dua reviewer otomatis yang kudelegasikan **gagal total** (satu balas
`{"status":"corrected"}` karena skema output, satu balas `{"response":"Ready."}`), jadi temuan di
atas berasal dari review manual + mutasi, bukan dari reviewer. Jangan menganggap rilis ini
"sudah direview dua agen" — tidak.

---

### v4.1.37 (2026-11-18)

Dua perbaikan dari kejadian nyata di panel produksi.

**1. Akun terkunci "Melebihi Limit IP" padahal hanya satu orang.**
Domain dilayani lewat CDN (Cloudflare), jadi `access.log` mencatat IP *edge* CDN, bukan IP
pelanggan. Terukur di VPS: akun `admin` muncul sebagai **41 IP** (162.158.x, 172.64.x,
104.23.x — semuanya AS13335 Cloudflare) lalu kena limit 10. IP CDN bukan identitas, jadi:

- `ip_is_cdn()` baru: 14 CIDR IPv4 + 7 prefix IPv6 Cloudflare, dicocokkan numerik.
- `live_ip_pairs()` dan `ssh_active_ips()` membuang IP CDN sebelum dihitung.
- `WIBU_IP_IGNORE_CDN=0` mengembalikan perilaku lama.
- **Konsekuensi yang dicatat jujur:** koneksi yang seluruhnya lewat CDN tidak bisa ditegakkan
  limit IP-nya, karena IP asli memang tidak pernah sampai ke server.

**2. Penegakan kuota SSH baru berjalan tiap 60 detik.**
Pelanggan yang melewati limit masih bisa menarik data selama sisa siklus (terukur 11 MB/s →
±600 MB). Sekarang:

- `kuota_scan_ssh()` memeriksa **hanya** akun SSH (tanpa statsquery xray, tanpa tulis config),
  ber-`flock`, idempoten lewat `locked_users.db`.
- `wibu-acct` memanggilnya tiap `WIBU_QUOTA_EVERY` detik (default **5**), di samping sampling
  byte 0,5 detik. Jeda penguncian turun dari ~60 dtk → **≤5 dtk**.
- Pesan penguncian dibangun `kuota_ssh_lock_message()` supaya jalur cepat (wibu-acct) dan jalur
  lambat (algojo-kuota) tidak pernah berbeda kalimat.

**Tes baru** (keduanya dibuktikan MERAH sebelum patch):

- `tests/test_ip_cdn.sh` — 18 asersi, termasuk batas rentang: `172.63.255.255` dan
  `104.15.255.255` **tidak** boleh dianggap CDN.
- `tests/test_kuota_latency.sh` — 12 asersi: pemakaian **persis** di limit harus terkunci
  (menahan mutasi `>=` → `>`), 1 byte di bawah limit tidak terkunci, idempoten, dan **8
  pemindaian paralel harus menghasilkan tepat 2 penguncian** (menahan mutasi yang melepas flock).

Mutasi yang diuji dan berhasil ditangkap: `>=`→`>`, `1073741824`→`1073741823`, guard
`locked_users` dihapus, `flock` dilepas (8 proses paralel → 16 penguncian).

---

### v4.1.36 (2026-11-17)

- **Regresi v4.1.35 tertangkap uji live: pemakaian SSH tercatat 0 byte.** Penyebabnya, soket
  "sisi-klien" dikenali lewat baris `LISTEN` di keluaran `ss -tie -tnp` — padahal perintah itu
  **tidak** mencetak LISTEN tanpa `-l`. Daftar port jadi kosong, semua soket dibuang, akuntansi
  berhenti tanpa error. Port listen kini dibaca dari `ss -tlnp` (atau dari fixture saat diuji).
- **Biaya siklus diturunkan** supaya sampling makin rapat: port listen di-cache 60 detik, dan
  pemetaan pid→user di-cache 15 detik (`SSH_PID_CACHE_TTL`). Tanpa cache, setiap soket `ssh -N`
  memicu `journalctl` (~150 ms) sehingga satu siklus bisa >1 detik.
- **Interval sampler `wibu-acct` jadi 0,5 detik** (dulu 1 detik).
- **Hasil ukur di VPS (sesi nyata lewat dropbear):** unduh 50 MB dalam 4,0 detik → tercatat
  **49.673.576 byte (0,99x)**. Sesi sangat pendek 20 MB dalam 1,7 detik masih under-count
  (0,23x) — lihat "batas yang diketahui" di bawah.
- **Batas yang diketahui (jujur):** `ss` hanya bisa membaca counter soket yang masih hidup, jadi
  byte antara sampel terakhir dan socket close tidak pernah terbaca. Untuk sesi normal (detikan-
  menitan) galatnya <1%; untuk burst sangat pendek galatnya bisa besar. Usulan berikutnya:
  fallback ke counter `conntrack` untuk soket yang baru menutup.

---

### v4.1.35 (2026-11-17)

- **BUG: pemakaian SSH terhitung DUA KALI.** `ssh_sessions_bytes` menjumlahkan **semua** soket milik
  dropbear — termasuk soket **keluar** yang dibuat trafik pelanggan sendiri (`ssh -D`/`-L`). Satu
  unduhan menghasilkan dua angka: soket masuk (server→klien) dan soket keluar (server→internet).
  Terukur di VPS uji: satu sesi 48,5 MB tercatat **42,9 MB + 47,2 MB**.
- **Perbaikan**: hanya soket **sisi-klien** yang dihitung — port lokalnya port LISTEN dropbear
  (jalur langsung 143/109), atau peer-nya loopback (jalur SSH-over-WS lewat ws-stunnel) — dan hanya
  soket milik proses `dropbear`/`sshd`. Soket keluar ke internet diabaikan.
- **Regresi dijaga tes offline**: fixture `ss -tie` berisi LISTEN + sesi masuk + soket keluar;
  tes menuntut total sisi-klien utuh (48.537.096) dan **port keluar tidak muncul** di keluaran.
- Catatan diagnostik: keluhan "20 MB hanya tercatat 1,3 MB" berasal dari kombinasi dua hal —
  sebagian byte teratribusi ke soket keluar, dan sisa detik terakhir hilang karena sampler hanya
  melihat soket yang masih hidup (sekarang 1 detik, jadi kerugian maksimal ~1 detik trafik).

---

### v4.1.34 (2026-11-17)

- **Unit systemd tidak ikut Update Script, jadi fitur baru bisa terpasang sebagai biner yang tidak
  pernah berjalan.** Terbukti saat meng-OTA `wibu-acct` (v4.1.33) ke VPS: binernya terpasang dengan
  hash benar, tetapi `wibu-acct.service` tidak ada — akuntansi sesi pendek tetap tidak jalan, tanpa
  satu pun pesan error.
- **Skrip baru `sbin/wibu-ensure-units`**: menulis unit wajib yang belum ada (idempoten, **tidak
  menimpa** unit yang sudah dikustomisasi), lalu `daemon-reload` + `enable` + `start`. Dipanggil
  oleh `setup.sh` (akhir instalasi), jalur **Update Script** di `m-setting.sh`, dan **Auto-Repair**
  (`wibu-repair`).
- Cakupan saat ini: `wibu-acct.service`. Menambah unit baru = tambahkan satu blok `write_unit` di
  skrip itu, dan OTA berikutnya akan memasangnya sendiri.

---

### v4.1.33 (2026-11-17)

- **BUG: kuota SSH tidak menghitung sesi pendek sama sekali.** `ss -tie` hanya bisa membaca
  counter soket yang **masih hidup**, dan akuntansi SSH hanya berjalan di siklus penegakan 60 detik
  (`algojo-kuota`). Terukur di VPS uji: unduh **50 MB dalam 7 detik** lalu sesi ditutup →
  `user_usage.db` tetap **0 byte**; sesi yang sama bila ditahan 75 detik tercatat 31.963.212 byte.
  Artinya pelanggan bisa memakai bandwidth gratis dengan menjaga tiap koneksi di bawah satu menit.
- **Unit baru `wibu-acct`**: sampler akuntansi byte SSH tiap **1 detik** (`usage_apply_ssh`).
  Biaya: satu `ss -tie` per detik, `Nice=10`. Interval bisa diatur lewat `WIBU_ACCT_INTERVAL`.
- **Serialisasi akuntansi**: `usage_apply_ssh` kini dibungkus `flock` — dua pemanggil (algojo-kuota
  60 dtk + wibu-acct 1 dtk) bisa membaca `prev` yang sama dan menghitung delta yang sama dua kali
  tanpa lock. Kunci: `/etc/wibutunnel/tmp/ssh_acct.lock`.
- Unit ikut jalur pasang/hapus/update: `setup.sh` (unduh + pasang + enable), `m-setting.sh`
  (daftar `safe_update`, restart-all, jalur update), `uninstall.sh`, README, dan tes invarian.
- **Hasil uji live yang menyertai rilis ini** (VPS uji, akun `ujissh` & `ujivless`, limit 1 IP / 1 GB):
  - limit IP SSH: 2 IP berbeda → `locked_users: ...:SSH_IP_LIMIT`, login ditolak, auto-unlock
    setelah `LOCK_DURATION` (15 menit) — terbukti lewat cron `unlocker-wibu`.
  - limit IP Xray: 2 IP berbeda → user masuk `routing.rules` (blocked) + `locked_users: ...:IP_LIMIT`;
    trafik berikutnya **ditolak** (`http_code=000`, log `rejected`).
  - akuntansi Xray tepat: `user_usage.db` = 30.052.691 byte = uplink (1.591) + downlink (30.051.100).

---

### v4.1.32 (2026-11-17)

- **Perintah instalasi di README ternyata tidak bekerja pada VPS baru.** `curl …/install.sh | bash`
  berhenti dengan `[!] Input berakhir (EOF). Instalasi dihentikan.` karena pada mode pipa `stdin`
  dipakai skrip, sehingga pertanyaan domain tidak bisa dijawab. Terbukti di VPS uji (RC=1).
- README kini memuat **dua bentuk yang benar**: interaktif (`curl -o install.sh` lalu `bash install.sh`)
  dan satu baris tanpa TTY (`… | bash -s -- vpn.domain-anda.com`), plus penjelasan singkat kenapa
  bentuk lama gagal.
- Pesan EOF di `setup.sh` tidak lagi buntu: ia menampilkan dua perintah yang bisa langsung dipakai dan
  memberi tahu bahwa token bot bisa diisi menyusul lewat menu Setting → [6].

---

### v4.1.31 (2026-11-17)

- **Instalasi baru GAGAL total karena pin hash instaleler Xray sudah basi.** Ditemukan saat uji
  uninstall → install ulang di VPS bersih: `setup.sh` mengunduh `install-release.sh` resmi Xray,
  hash-nya tidak cocok dengan pin (`a562d1…` vs `91fd40…`), lalu **ABORT** — fail-closed bekerja
  seperti desainnya, tetapi artinya tidak ada VPS baru yang bisa dipasang sampai pin diperbarui.
  Upstream memang mengubah skripnya sejak rilis sebelumnya.
- **Pin diperbarui setelah inspeksi isi**, bukan asal ganti: skrip 34.831 byte, `#!/usr/bin/env bash`,
  176 rujukan `xray`, memasang ke `/usr/local/bin/xray` + unit systemd — bentuk yang sama dengan
  sebelumnya. Nilai baru dipakai di `setup.sh` **dan** `uninstall.sh` (keduanya memanggil skrip itu).
- Catatan: `uninstall.sh` juga menampilkan `[ABORT]` untuk instaleler Xray dan jatuh ke pembersihan
  manual — setelah pin ini sama, jalur resmi kembali dipakai.
- Pelajaran operasional: pin pihak ketiga adalah **tanggungan waktu**. Gejalanya bukan error di
  panel, melainkan instalasi baru yang berhenti di tengah; uji "VPS kosong" adalah satu-satunya cara
  menemukannya lebih awal.

---

### v4.1.30 (2026-11-17)

- **BUG: `uninstall.sh` meninggalkan dua skrip dan seluruh UDPGW.** Ditemukan saat siklus
  uninstall → install ulang di VPS uji. `wibu-kuota` dan `wibu-udpgw` dipasang oleh `setup.sh`
  tetapi tidak ada di daftar hapus, jadi tertinggal di `/usr/local/{bin,sbin}`. Lebih besar:
  **UDPGW** — unit templated `badvpn-udpgw@.service`, biner `/usr/sbin/badvpn-udpgw`, direktori
  build `/usr/local/src/badvpn-src`, dan **enam proses** yang tetap mendengarkan
  `127.0.0.1:7100-7600` setelah panel "dihapus". Kini dibersihkan semua (stop per-instance,
  disable, hapus unit + biner + build, `pkill` sisa proses).
- **Invarian baru di `test_hardening.sh`**: setiap berkas `sbin/*` dan `menu/*.sh` **wajib**
  disebut `uninstall.sh`. Tanpa ini "uninstall bersih" hanya berlaku untuk berkas yang kebetulan
  diingat — persis cara dua skrip tadi lolos.
- **Catatan risiko**: uninstaller resmi Xray yang dipanggil `uninstall.sh` sekarang **gagal
  verifikasi hash** (skrip upstream berubah). Jalur cadangan manual tetap berjalan dan terbukti
  membersihkan `/etc/xray`, `/usr/local/bin/xray`, unit xray — tetapi pesan `[ABORT]` muncul di
  log. Pin hash perlu diperbarui saat ada kesempatan.
- README bagian uninstall menyebut bahwa UDPGW ikut dibersihkan.

---

### v4.1.29 (2026-11-17)

- **BUG MAJOR: installer menulis `bot.conf` dalam format yang ditolak oleh pembacanya sendiri.**
  `setup.sh` menulis `BOT_TOKEN=<nilai>` **tanpa tanda kutip**, sementara semua predikat memakai pola
  `^BOT_TOKEN="…"`. Akibatnya instalasi baru yang mengisi token **saat instalasi** dinilai "belum
  diatur": unit di-`disable`, bot di-`stop`, layar mencetak "Bot Telegram belum diatur" padahal admin
  baru saja mengisinya. Kalau nanti dinyalakan lewat menu [2], `systemctl start` jalan tetapi guard
  menolak `enable` — bot hidup sampai reboot lalu mati lagi: gejala v4.1.24, dari arah lain.
- **Perbaikan ganda**: penulis di installer kini menulis ber-kutip (sama dengan menu), dan **predikat
  dibuat toleran** `^KEY="?[^"]+"?[[:space:]]*$` sehingga berkas lama tanpa kutip (warisan
  ≤ v4.1.28) tetap terbaca — upgrade tidak memutus VPS yang bot-nya sudah jalan.
- **Tes [9/9] baru: penulis vs pembaca.** Menjalankan baris `printf` milik installer, lalu menguji
  berkas hasilnya dengan `bot_conf_lengkap()`; ditambah kasus berkas lama tanpa kutip dan kontrol
  negatif berkas kosong. Mutasi "kembalikan keadaan v4.1.28" memerahkan **tiga** asersi sekaligus,
  termasuk kalimat "installer menulis format yang DITOLAK predikatnya sendiri".
- **Tes [5/9] tidak lagi mematok satu verdict**: yang diuji adalah **kesepakatan** menu dan repair
  atas berkas yang sama (format apa pun boleh, asal kedua pihak satu suara).
- **Tes [2/9] tidak lagi bergantung urutan nama service** (dulu grep string literal, pecah bila
  daftar diurutkan ulang tanpa perubahan perilaku).

---

### v4.1.28 (2026-11-17)

- **Harness tes tidak bisa lagi menyentuh layanan nyata.** Stub `systemctl` versi lama memakai
  `PATH`; di VPS panel, `bash -c` memuat lingkungan lain sehingga **stub itu tidak terpakai** dan
  potongan kode yang diuji memanggil `systemctl` sungguhan — terukur: bot benar-benar berhenti dan
  ter-`disable` saat tes dijalankan di VPS. Stub kini berupa **fungsi bash yang di-export**, ditambah
  **sentinel**: satu panggilan percobaan sebelum skenario; kalau sentinel tidak tercatat, seluruh
  skenario dibatalkan dan tes ditandai gagal (fail-closed), bukan diam-diam mengeksekusi perintah asli.
- **Diverifikasi di VPS panel**: keadaan bot `active/enabled` sebelum dan **sesudah** suite dijalankan
  tetap sama, dengan 15 PASS / 0 FAIL. Sebelum perbaikan ini, menjalankan suite di VPS bisa mematikan
  bot produksi.
- Catatan operasional: kegagalan stub PATH ini juga menjelaskan kenapa uji manual di VPS bisa
  "berhasil" padahal efek sampingnya nyata — angka PASS tidak membuktikan tidak ada efek samping.

---

### v4.1.27 (2026-11-17)

- **Installer tidak lagi membatalkan `Stop`.** `setup.sh` punya cabang sendiri yang langsung
  `enable` + `restart` begitu konfigurasi lengkap — jadi menjalankan ulang skrip instalasi
  menghidupkan kembali bot yang sengaja dimatikan admin. Sekarang cabang penanda `bot_off`
  diperiksa **lebih dulu**: unit di-stop + disable + `reset-failed`, dengan pesan bahwa cara
  menghidupkannya adalah Setting → [6] → [2].
- **Parser konfigurasi diseragamkan betulan.** `sbin/wibu-repair` masih `source bot.conf` lalu
  menguji `-n "$BOT_TOKEN"`, sedangkan menu/installer memakai `grep` pola `KEY="…"`. Berkas yang
  formatnya berbeda (mis. kutip tunggal, spasi di sekitar `=`) membuat **menu bilang "belum diatur"
  sementara repair menghidupkan bot** — persis kelas bug yang diklaim sudah dibereskan di v4.1.26,
  hanya pindah ke cara membaca berkas. Repair kini memakai `grep` yang sama; tidak ada lagi `source`.
- **Tes menambah dua penjaga**: kasus konfigurasi berkutip tunggal (menu dan repair harus sepakat
  menolak) dan pemeriksaan bahwa cabang penanda di installer berada **sebelum** baris `enable`.
  Keduanya dibuktikan MERAH lewat dua mutasi (hapus cabang penanda; kembalikan `source` di repair).

---

### v4.1.26 (2026-11-17)

- **`Stop` manual kini menggerbangi `start`/`restart`, bukan hanya `enable`.** Temuan reviewer atas
  v4.1.25: `bot_enable_guard` hanya mencegah `systemctl enable`, sementara baris berikutnya tetap
  `systemctl restart telegram-bot` — dan `restart` menyalakan unit yang sedang mati **walau** status
  enabled-nya `disabled`. Jadi bot hidup lagi sampai reboot, lalu mati lagi: gejala yang sama,
  arah berlawanan. Sekarang `telegram-bot` dikeluarkan dari daftar restart massal dan hanya
  dinyalakan lewat `bot_boleh_jalan && systemctl restart telegram-bot`.
- **`wibu-repair` cabang penanda**: `stop` + `disable` + `reset-failed` (dulu hanya `stop`, sehingga
  unit yang terlanjur enabled bangkit lagi saat boot dan status `failed` lama menempel).
- **Restore backup menulis penanda** `bot_off`: niat "matikan bot agar tidak bentrok 409 dengan VPS
  lama" sekarang bertahan, tidak dibatalkan Auto-Repair/Update berikutnya.
- **Predikat konfigurasi diseragamkan**: `bot_conf_lengkap()` (token **dan** chat id) dipakai guard,
  `wibu-repair`, dan installer. Sebelumnya menu menilai cukup token sementara repair menuntut token
  + chat id, sehingga bot hidup-mati setiap kali menu [1] Auto-Repair dijalankan (tidak ada timer
  yang memanggilnya — pemicunya hanya menu).
- **`setup.sh` tidak lagi menghapus `/etc/wibutunnel/bot_off`**: alasan lamanya (penanda terbawa
  backup) tidak terbukti — berkas backup tidak pernah memuat penanda itu — dan efek nyatanya adalah
  membatalkan `Stop` admin saat skrip dijalankan ulang.
- **Status menu menampilkan dua fakta**: penanda Stop **dan** `is-enabled` sebenarnya, supaya keadaan
  "unit enabled tapi bot dimatikan manual" tidak lagi tersembunyi.
- **Tes: 8 bagian, bukan 6.** Ditambah uji *produsen* penanda (Stop benar-benar menulis berkasnya),
  perilaku `wibu-repair` dengan `systemctl` di-stub (3 skenario), gerbang restart, dan pemeriksaan
  predikat installer. Ketiganya **dibuktikan MERAH lewat tiga mutasi** (hapus `touch`, repair
  menghidupkan bot, bot dimasukkan lagi ke restart massal) sebelum diterima.
- **Harness tes dibuat aman**: `mktemp -d` divalidasi; kegagalan `mktemp` tidak lagi bisa berubah
  menjadi tulisan ke `/etc` atau pemotongan `/bin/systemctl` (jalur `"$TMP/x"` menjadi `"/x"`).

---

### v4.1.25 (2026-11-17)

- **`Stop` manual dihormati.** Penanda `/etc/wibutunnel/bot_off` dipasang saat admin memilih
  menu [6] → [3] Matikan Bot. Selama penanda ada, `bot_enable_guard` **dan** `wibu-repair` tidak
  meng-enable unit — jadi restart-all / Auto-Repair / Update Script tidak lagi menghidupkan bot
  yang sengaja dimatikan. Penanda dihapus oleh opsi Start, simpan token, dan installer.
- **`wibu-repair` konsisten dengan `setup.sh`**: saat token tidak ada, unit sekarang `disable` +
  `reset-failed` (sebelumnya hanya "kalau token ada, enable" — tanpa cabang sebaliknya, sehingga
  unit bisa tertinggal enabled dan gagal start tiap boot).
- **Tes bot jadi behavior, bukan grep**: `tests/test_bot_enable.sh` kini menjalankan
  `bot_enable_guard` sungguhan dengan `systemctl` di-stub (token ada / penanda Stop / token kosong).
  Sudah dibuktikan MERAH terhadap guard versi lama sebelum patch ini diterima.
- **Koreksi narasi v4.1.24** (lihat entri di bawah): notifikasi limit/expired tidak pernah ikut mati
  bersama unit bot karena dikirim langsung oleh `sbin/*`.

---

### v4.1.24 (2026-11-17)

- **Bot Telegram tahan reboot.** Menu Setting → [6] dulu hanya `start`/`restart` unit, tidak pernah
  `enable`: bot hidup sampai reboot pertama lalu mati **diam-diam**. Yang ikut mati adalah **panel
  interaktif Telegram** (buat akun, lock/unlock, cek trafik, callback menu) — sedangkan notifikasi
  limit/expired tetap terkirim karena dikirim **langsung** ke API oleh `sbin/*`, bukan lewat unit.
  Sekarang `bot_enable_guard` dipanggil di semua jalur yang menyalakan bot (simpan token, opsi Start,
  restart-all, dan Update Script).
- **Status boot ditampilkan di menu bot**: `Aktif saat Boot : enabled / disabled (mati setelah reboot!)`
  supaya kondisi ini bisa diaudit tanpa `systemctl`.
- **Opsi [3] Stop ikut `disable`** — state jadi jujur: bot yang dimatikan manual tidak bangkit sendiri.
- **Guard token dipertahankan**: tanpa `BOT_TOKEN`, unit tetap tidak di-enable (tidak ada status
  `failed` di tiap boot). Dijaga `tests/test_bot_enable.sh` (baru, offline).
- **Default `WIBU_REF` usang dibetulkan**: blok pemasangan berkas masih menyimpan `v4.1.17`
  sebagai fallback — selaras dengan versi rilis sekarang.

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
