# Changelog

## v4.0.6-fixed — 2026-11-15 (patch keamanan)
Perbaikan dari audit independen. Rincian + cara verifikasi: `docs/SECURITY_FIXES.md`.
Harness: `bash tests/test_hardening.sh` → 32 PASS / 0 FAIL.

**KRITIS**
- Pin + verifikasi SHA256 instaleler Xray; hapus semua `curl | bash` (`setup.sh`, `uninstall.sh`).
- Update menu (`safe_update`) fail-closed: `curl -f` + manifest `SHA256SUMS` + cadangan rollback.
- API Xray `127.0.0.1:10085` diblokir untuk non-root (iptables owner-match + `wibutunnel-firewall.service`, persisten setelah reboot); `uninstall.sh` tidak lagi `iptables -F` global.

**TINGGI**
- Token bot keluar dari `argv` (11 titik → `curl -K -`).
- Restore backup: wajib password + validasi entri + `mktemp -d` + trap.
- Hitungan trafik global diperbaiki (kolom 2 saja).
- Durasi lock: guard `10#` + normalisasi + batas 1440 menit.

**SEDANG/RENDAH**
- Izin: `*_exp.conf` 600, `/etc/xray` 750, log xray 0640 di direktori 750.
- Tulis DB ber-`flock`; guard protokol tak dikenal; validasi numerik sebelum banding.
- Resolver indeks inbound berbasis tag (bukan hardcode 1..8).
- Backup pakai `mktemp` + password acak; `limits.conf` idempoten + cadangan; `sed -i` diberi cadangan.
- `common.sh` tidak lagi memanggil jaringan saat source-time; `read -r`.
- Penanda versi `4.0.6-fixed`; `menu/bot-webhook.sh` ditandai orphan.

**Alat baru**
- `tests/test_hardening.sh` (32 cek, non-destruktif) + `SHA256SUMS` (44 berkas) + `docs/STAGING_TEST.md`, `docs/PUSH_GITHUB.md`.
