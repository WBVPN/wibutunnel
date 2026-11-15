# Push ke GitHub (saat nanti diberi akses)

Repo yang diklaim paket: `github.com/WBVPN/wibutunnel` (README:5, setup.sh:47).

## Sekali saja
```bash
cd /root/wibutunnel-fix
git remote add origin git@github.com:WBVPN/wibutunnel.git   # butuh SSH key/deploy key
# atau HTTPS + PAT: git remote add origin https://<user>:<PAT>@github.com/WBVPN/wibutunnel.git
git branch -M main
```

## Riwayat commit yang sudah disiapkan orchestrator
1. `baseline: wibutunnel v4.0.6 (rilis 2026-11-02)` — isi apa adanya, untuk diff bersih
2. `fix(sec): rantai pasok — pin + verifikasi hash installer Xray` (setup.sh, uninstall.sh)
3. `fix(sec): isolasi API Xray 10085 (iptables owner-match + unit persisten)`
4. `fix(sec): token Telegram keluar dari argv + safe_update verifikasi SHA256`
5. `fix(sec): enforcement — guard 10#, tulis DB ber-flock, izin exp.conf`
6. `fix(sec): hardening restore backup + backup acak (mktemp)`
7. `chore: penanda versi 4.0.6-fixed, manifest SHA256SUMS, harness non-destruktif`

## Perintah push
```bash
git push -u origin main          # atau buat branch: git push -u origin fix/security-4.0.6
```
**Penting setelah push:** berkas `SHA256SUMS` harus ikut ter-push di ref yang dipakai
`menu/m-setting.sh` (`WIBU_REF`, default `v4.0.6-fixed`) — kalau tidak, `safe_update` akan
menolak semua update (memang disengaja: fail-closed). Buat tag:
```bash
git tag -a v4.0.6-fixed -m "security fixes" && git push origin v4.0.6-fixed
```

## Setelah push: uji di VPS
Ikuti `docs/STAGING_TEST.md` pada VPS kosong dulu; baru setelah 32/32 PASS + verifikasi
langkah 4 semuanya hijau, pasang di VPS produksi (dengan snapshot dari langkah 0).
