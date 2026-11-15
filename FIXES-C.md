# FIXES-C.md — Patch keamanan wibutunnel (v4.0 KURUMI → v4.0.6-fixed)

Cakupan berkas: `setup.sh`, `uninstall.sh`, `config/logrotate-xray`, `config/config.json`,
`config/haproxy.cfg`, `menu/bot-webhook.sh`.
`config/config.json` dan `config/haproxy.cfg` TIDAK diubah (tidak dipakai installer — setup.sh
menulis config.json & haproxy.cfg inline; berkas di `config/` hanya referensi lama).

Nomor baris = sebelum → sesudah (berkas diubah in-place, jadi nomor setelah = hasil akhir).

---

## C1 (KRITIS) — Pin + verifikasi hash instaleler Xray

**setup.sh** `350 → 106-160 (konstanta+fungsi), 460 (call site)`
- Sebelum: `curl -sS -L .../install-release.sh | bash -s -- install`
- Sesudah: konstanta `XRAY_INSTALL_URL` + `XRAY_INSTALL_SHA256` (default
  `a562d1287cd7bf2871023d4c81bd9031c56fa132956067ba1de126957cc5fb1c`, diverifikasi 2026-11-15);
  fungsi `xray_verify_sha256()` + `xray_installer_run()`; call site → `xray_installer_run install`.
- Alur: `curl -fSL --retry 3 --max-time 60 -o "$XRAY_TMP"` → `sha256sum` → banding. Beda/kosong/curl
  gagal → `[FATAL] ... ABORT` + `exit 1`. Cocok baru `bash "$XRAY_TMP" -s -- install`.
- Bypass HANYA bila `WIBUTUNNEL_ALLOW_UNVERIFIED=1` (peringatan besar + tulis
  `/var/log/wibutunnel-installer.log` + `logger`).
- Cleanup `$XRAY_TMP` via `trap xray_tmp_cleanup EXIT`.
- Alasan: tanpa pin, eksekusi kode hulu = root RCE bila repo hulu diretas.

**uninstall.sh** `38 → 8-23 (konstanta+fungsi), 54-64 (call site)`
- Sesudah: verifikasi hash dulu; cocok → `bash "$XRAY_TMP" -s -- remove`. Gagal → `[ABORT]`
  uninstaller resmi dilewati, lanjut pembersihan manual (agar uninstall tetap jalan offline).

## C2 (KRITIS) — Blokir akses non-root ke API Xray 10085

**setup.sh** `289 → 338-398` (blok firewall sebelum `iptables-save`)
- Menulis `/usr/local/sbin/wibutunnel-firewall.sh` + menjalankannya; menulis unit
  `/etc/systemd/system/wibutunnel-firewall.service` (Type=oneshot, After=network.target,
  Before=xray.service) + `systemctl enable` (ditegakkan ulang saat boot).
- Aturan: `iptables -C OUTPUT ! -m owner --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT
  || iptables -I OUTPUT 1 ...` dengan `API_PORTS="10085"` (loop, siap ditambah port API lain).
- Alasan: API tanpa auth = non-root bisa `xray api`/`ssh -L` → hapus user & lewati expiry/kuota.
  Owner-match ikut memblokir koneksi tunnel `ssh -L` karena sshd sudah turun ke uid user.
- Idempoten: `-C` guard + `==` compare; `systemctl enable` re-run aman.
- **Mitigasi utama. Residual risk: pelanggan tetap punya shell** — tercatat di header setup.sh (baris 6-10).

**uninstall.sh** `47-51 → 68-83`
- Sebelum: `iptables -F` (flush SELURUH firewall). Sesudah: hapus HANYA aturan owner-match
  wibutunnel via loop `iptables -C ... || (iptables -D ...; break)`. `-t mangle -F/-X` dipertahankan
  (aturan QoS produk sendiri, bukan filter global). Plus stop/disable + hapus unit & skrip firewall
  (baris 32-33, 113-114).

## C3 (TINGGI) — Izin berkas bocor data pelanggan

**config/logrotate-xray** `3 → 3` : `create 0644 xray xray` → `create 0640 xray adm`; `su xray xray`
→ `su xray adm`.
**setup.sh** `840 (dalam heredoc logrotate) → 951-952` : baris identik di-ubah sama (setup.sh menulis
`/etc/logrotate.d/xray` sendiri, tidak memakai config/).
**setup.sh** `254 → 326` : `chmod 755 /var/log/xray` → `chown xray:adm … ; chmod 750 /var/log/xray`.
**setup.sh** `352-353 → 462-464` : `chown -R xray:xray` → `chown -R xray:adm`; tmpfiles
`d /var/log/xray 0755 xray xray` → `0750 xray adm`.
**setup.sh** `192 → 253-255` : tambah `chmod 750 /etc/xray` + `chmod 600 /etc/xray/*_exp.conf`.
**setup.sh** `387 → 499` : tambah `chmod 750 /etc/xray`.
- Alasan: `/var/log/xray/*.log` memuat email+IP semua klien; `/etc/xray/*_exp.conf` = daftar pelanggan.

## C4 (SEDANG) — limits.conf idempoten + backup

**setup.sh** `229-234 → 292-303`
- Sebelum: `cat <<EOF > /etc/security/limits.conf` (menimpa total).
- Sesudah: `cp -a … limits.conf.wibutunnel.bak` (bila belum ada) → hapus blok lama
  (`sed -i '/# >>> wibutunnel >>>/,/# <<< wibutunnel <<</d'`) → `>>` tambah blok berpenanda.
  Idempoten (re-run tidak menduplikasi).

## C5 (SEDANG, opt-in) — pelanggan SSH dapat /bin/bash

**setup.sh** `183 → 234-241`
- `WIBU_SSH_NOLOGIN=1` → tulis `/etc/wibutunnel/ssh_shell.conf` = `SSH_SHELL=/usr/sbin/nologin`
  (chmod 600) + peringatan. Default produk TIDAK diubah (`/bin/bash`).
- Komentar: tunneling `ssh -N -L` tetap jalan, shell interaktif mati.
- Catatan residual risk ditulis di header setup.sh.
- ⚠️ `common.sh:396` (`SSH_SHELL="${SSH_SHELL:-/bin/bash}"`) membaca dari **env**, belum meng-source
  `ssh_shell.conf`. Berkas common.sh BUKAN milik patch ini → lihat "Belum selesai" di bawah.

## C6 (RENDAH) — penanda versi & orphan

**setup.sh** `178 → 228` : `echo "4.0 Kurumi"` → `echo "4.0.6-fixed"`.
**menu/bot-webhook.sh** `2` : komentar header "TIDAK DIPAKAI (orphan) — tidak dipasang installer".
**uninstall.sh** `62 → 93` : hapus token `/usr/local/bin/bot-webhook` + `bot-webhook-handler`
  (tak pernah dipasang); `bot-daemon` dipertahankan (memang dipasang).

## C7 (RENDAH) — `sed -i` tanpa cadangan

- **setup.sh** `118 → 167-168` : `cp -a /etc/default/grub … .wibutunnel.bak` sebelum `sed -i`.
- **setup.sh** C4 `sed -i` limits.conf: backup di baris 293-294.
- **uninstall.sh** `88 → 121-122` : `cp -a /root/.profile` sebelum `sed -i`.
- **uninstall.sh** `91-93 → 125-128` : `cp -a /etc/fstab` sebelum 3× `sed -i`.
- (baris `sed -i` yang masih ter-comment di uninstall:135-139 tidak aktif → dilewati.)

---

## Verifikasi

- `bash -n setup.sh uninstall.sh menu/bot-webhook.sh` → OK (semua).
- Fungsi `xray_verify_sha256` diekstrak ke `/tmp` + diuji: hash benar diterima; hash salah,
  berkas hilang, berkas kosong → ditolak. (Lihat output di laporan.)
- Tidak menjalankan `setup.sh`/`uninstall.sh`/`tests/` (VPS produksi).

## Belum selesai / ragu

1. **C5 belum fungsional end-to-end**: `ssh_shell.conf` ditulis, tapi `common.sh` (bukan berkas
   patch ini) belum meng-source-nya. Agar aktif perlu 1 baris di common.sh:
   `[ -r /etc/wibutunnel/ssh_shell.conf ] && . /etc/wibutunnel/ssh_shell.conf` sebelum baris 396.
2. **Hash instaleler Xray** dipakai sesuai spesifikasi tugas; belum diverifikasi ulang terhadap
   upstream (butuh unduh dari repo hulu — tidak dilakukan).
3. **config/config.json & config/haproxy.cfg**: tidak diubah (tidak dipakai installer). Jika
   dimaksud sebagai source-of-truth, perlu refactor setup.sh — di luar scope.
4. Rule iptables memakai `--uid-owner` (tersedia di xt_owner standar Debian/Ubuntu; sudah ada
   paket `iptables` di daftar apt setup.sh).

## Koreksi (2026-11-15, setelah uji container)
- Aturan iptables versi awal `! -m owner --uid-owner 0` TIDAK valid di iptables-nft (Ubuntu 22.04):
  `unexpected ! flag before --match`. Diskorig menjadi `-m owner ! --uid-owner 0` (diuji: `iptables -C` -> exit 1
  = sintaks valid, aturan belum ada). Terima kasih uji end-to-end.
