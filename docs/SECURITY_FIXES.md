# SECURITY FIXES — wibutunnel v4.0.6-fixed (2026-11-15)

Hasil audit independen (3 reviewer) + patch. Setiap butir: temuan → perbaikan → cara verifikasi → sisa risiko.
Harness verifikasi: `bash tests/test_hardening.sh` → **32 PASS / 0 FAIL**.

## KRITIS
### K1 — Rantai pasok: `curl | bash` & update tanpa verifikasi
- **Sebelum:** `setup.sh:350`, `uninstall.sh:38` → `curl -sS -L …/install-release.sh | bash`. Semua `menu/*`,`sbin/*` diunduh dari `main` dan hanya divalidasi `bash -n` (terbukti: `printf '404: Not Found' | bash -n` LULUS) lalu dijalankan sebagai root.
- **Sesudah:** unduh ke berkas (`curl -fSL --retry 3`) → `sha256sum` → bandingkan dengan pin (`XRAY_INSTALL_SHA256` di setup/uninstall) → **ABORT** bila beda/kosong/gagal. `safe_update` mengambil `SHA256SUMS` dari ref terpin (`WIBU_REF`, default `v4.0.6-fixed`) dan menolak bila hash tidak cocok/berkas tidak ada di manifest; cadangan lama disimpan ke `/usr/local/share/wibutunnel/backup/` sebelum menimpa. Bypass hanya `WIBUTUNNEL_ALLOW_UNVERIFIED=1` (peringatan besar + `logger`).
- **Verifikasi:** `test_hardening.sh` bagian C; uji negatif `WIBU_REF=…` dengan manifest dirusak → update ditolak.
- **Sisa:** pin hash adalah TOFU — bila hulu merilis versi baru, perbarui `XRAY_INSTALL_SHA256` secara sadar.

### K2 — API Xray tanpa auth + akun tunnel ber-shell
- **Sebelum:** API `StatsService`+`HandlerService` di `127.0.0.1:10085` tanpa auth; akun pelanggan dibuat `-s /bin/bash` → pelanggan bisa `xray api` / `ssh -L 10085` → hapus user lain, lewati expiry & kuota.
- **Sesudah:** aturan iptables owner-match (hanya uid 0 boleh menuju `127.0.0.1:10085`) + unit `wibutunnel-firewall.service` yang menegakkan ulang setelah boot; `uninstall.sh` menghapus **hanya** aturan itu (bukan `iptables -F` global). Opsi `WIBU_SSH_NOLOGIN=1` (opt-in) menulis `/etc/wibutunnel/ssh_shell.conf` yang **dibaca `common.sh`** untuk memakai nologin (port-forwarding tetap jalan).
- **Verifikasi:** `iptables -S OUTPUT | grep 10085`; dari user non-root: `xray api statsquery --server=127.0.0.1:10085` harus gagal; `ps aux | grep -c 'api.telegram.org/bot'` = 0.
- **Sisa:** default produk tetap shell biasa (tidak diubah tanpa keputusan pemilik); mitigasi utama = aturan firewall.

## TINGGI
### T1 — Token bot di `argv`
- **Sebelum:** 11× `curl … "https://api.telegram.org/bot${BOT_TOKEN}/…"` → token terlihat di `ps` oleh setiap user lokal.
- **Sesudah:** helper `tg_api()` mengirim URL via `curl -K -` (STDIN). `grep -c 'api.telegram.org/bot${BOT_TOKEN}'` = **0**.
- **Verifikasi:** jalankan bot, lalu `ps aux | grep api.telegram.org` → kosong.

### T2 — `safe_update` tanpa cek status HTTP → menjadi K1 (bagian update).

### T3 — Restore backup dari URL/zip arbitrer
- **Sebelum:** unduh zip dari URL mana pun, `unzip` fallback **tanpa password**, `cp` ke `/etc` + `useradd`/`chpasswd` sebagai root.
- **Sesudah:** hanya `https`; **password wajib** (`unzip -P`); validasi daftar entri (tolak absolut/`..`/di luar `etc/wibutunnel`+`etc/xray`); ekstrak ke `mktemp -d` + `trap` pembersih.
- **Verifikasi:** uji entri `..`, `/etc/passwd`, `usr/bin/evil` → ditolak.

### T4 — Hitungan trafik global salah
- **Sebelum:** `bot-daemon.sh` menjumlahkan kolom 2+3 padahal DB 3 kolom `user:total:lastraw` (penulis `sbin/algojo-kuota`) → laporan dobel (pembaca acuan `menu/cek-trafik.sh` pakai kolom 2).
- **Sesudah:** hanya kolom 2.

### T5 — User terkunci permanen karena oktal
- **Sebelum:** `LOCK_DURATION=08` (lolos validasi) → `$((LOCK_DURATION * 60))` error “value too great for base” → `unlock_time` kosong.
- **Sesudah:** `10#` + fallback 15 menit + log; input dinormalisasi & dibatasi ≤1440 di menu.

## SEDANG / RENDAH
- `chmod 644` pada `*_exp.conf` (daftar pelanggan di `/etc/xray`) → **600**; `/etc/xray` 750.
- `create 0644` logrotate `/var/log/xray/*.log` (email+IP klien) → **0640 xray:adm**, direktori 750.
- Tulis DB tanpa `flock` (4 tempat) → lewat `db_set`/`db_append` (flock fd200, `mv` atomik) atau truncate ber-flock.
- `proto=UNKNOWN` menulis `unknown_exp.conf` → sekarang di-`continue` + log.
- Perbandingan `-gt` pada nilai non-numerik (dianggap 0 → salah kunci) → validasi `^[0-9]+$`.
- Indeks inbound hardcoded `1..8` → resolver berbasis tag (`xray_inbound_index`), gagal → tidak menulis konfigurasi.
- Unggah/backup ke `/tmp` nama tetap + password `CHAT_ID` → `mktemp -d` 700 + password acak (`openssl rand`), password ditampilkan ke admin.
- `/etc/security/limits.conf` ditimpa → dicadangkan + blok berpenanda idempoten.
- `uninstall.sh` `iptables -F` global → penghapusan terarah; `sed -i` diberi cadangan `.wibutunnel.bak`.
- `common.sh` memanggil jaringan saat *source-time* → lazy (`detect_myip`).
- Penanda versi `"4.0 Kurumi"` → `"4.0.6-fixed"`; `menu/bot-webhook.sh` ditandai orphan (tidak dipasang).

## Tidak diubah (sengaja)
- Model produk: akun SSH tetap ber-shell kecuali admin memilih `WIBU_SSH_NOLOGIN=1`.
- `config/haproxy.cfg` dipakai `wibu-repair` sebagai template rebuild; `config/config.json` dipakai suite uji `test_auto_repair.sh`. `setup.sh` sendiri menulis konfigurasi secara inline.
- Lisensi vendor (GitHub + override lokal) belum diperketat: butuh keputusan pemilik soal alur distribusinya.
