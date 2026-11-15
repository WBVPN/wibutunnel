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

## 7. Sisa yang belum diuji

- **Siklus reboot nyata** setelah perbaikan dedupe firewall (bukti statis + uji jalankan-2× sudah ada).
- **Koneksi klien dari perangkat nyata** (VLESS/VMESS/Trojan/SSH) — pemilik VPS melaporkan akun sudah konek.
- **Layanan bot Telegram** hanya diuji dengan satu bot uji (`@bansoswibu_bot`).
