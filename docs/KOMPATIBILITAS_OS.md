# Kompatibilitas OS

Status per 2026-11-15. **Didukung** = paket & dependensinya ada di repo resmi OS tersebut dan
konfigurasi kita kompatibel dengan versi paketnya (diverifikasi lewat indeks paket resmi).
**Teruji** = sudah dipasang & diverifikasi di VPS nyata dari aset Release (instalasi + reboot + klien connect).
Ubuntu 22.04: HAProxy 2.4.30, certbot 1.21.0, dropbear 2020.81, python 3.10.12 - lulus 2026-11-15.
Ubuntu 24.04: /tmp = tmpfs noexec -> installer resmi Xray gagal; installer mengarahkan TMPDIR + punya jalur cadangan Xray tanpa API.
HAProxy 2.8.30, certbot 2.9.0, dropbear 2022.83, openssl 3.0.13, python 3.12.3, awk = gawk 5.2.1 - lulus 2026-11-15.
Debian 11: HARUS memakai arsip (bullseye EOL) - installer mengalihkan otomatis ke archive.debian.org.
HAProxy 2.2.9, certbot 1.12.0, dropbear 2020.81, python 3.9.2, awk = mawk 1.3.4 (tanpa interval regex) - lulus 2026-11-15.

| OS | Status | HAProxy | certbot | dropbear | python3 | iptables-persistent | Catatan |
|---|---|---|---|---|---|---|---|
| Ubuntu 20.04 (focal) | ✅ **teruji** | 2.0.33 | 0.40.0 | 2019.78 | 3.8.2 | 1.0.14 | baseline uji utama |
| **Debian 12 (bookworm)** | ✅ **teruji** | 2.6.12 | 2.1.0 | 2022.83 | 3.11.2 | 1.0.20 | `rsyslog` tidak default (ditambahkan), `ntp` tidak ada (pakai timesyncd) |
| Debian 11 (bullseye) | ✅ **teruji** | 2.2.9 | 1.12.0 | 2020.81 | 3.9.2 | 1.0.15 | iptables legacy; LTS berakhir 2026 |
| Ubuntu 22.04 (jammy) | ✅ **teruji** | 2.4.30 | 1.21.0 | 2020.81 | 3.10.6 | 1.0.16 | paling banyak dipakai pelanggan |
| Ubuntu 24.04 (noble) | ✅ **teruji** | 2.8.30 | 2.9.0 | 2022.83 | 3.12.3 | 1.0.20 | perlu cek AppArmor profil haproxy |

**Sudah ditangani agar kelima OS ini jalan** (dari uji Debian 12):
`rsyslog` ikut dipasang (instalasi minimal Debian/Ubuntu sering tanpa syslog sehingga log HAProxy hilang),
NTP memakai `systemd-timesyncd` lebih dulu, serta `systemctl reset-failed` supaya status layanan tidak menyesatkan.

**Belum diuji di seluruh OS:** beban banyak klien paralel (load test).

## Cara menyatakan satu OS "teruji"

1. Rebuild VPS ke OS tersebut (1 vCPU / 1 GB cukup), A record domain mengarah ke IP-nya (tanpa AAAA).
2. Pasang dari aset Release: `curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash`
   (jawab domain saat diminta).
3. Verifikasi minimal: `haproxy -c -f /etc/haproxy/haproxy.cfg`, `systemctl is-active` 8 layanan,
   `ss -tln` (80/443/143/109), `xray -test`, izin `640 root:xray` + `:10085` root-only, lisensi LOLOS,
   buat 1 akun uji lalu **connect dari perangkat**.
4. `reboot` lalu ulangi poin 3 - kalau lolos, OS itu masuk daftar **teruji**.
