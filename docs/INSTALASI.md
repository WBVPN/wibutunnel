# Panduan Instalasi WIBUTUNNEL

Panduan langkah-demi-langkah untuk reseller non-teknis. Ikuti berurutan; total waktu
kira-kira 5–10 menit di VPS yang memenuhi syarat.

---

## 1. Prasyarat

| Syarat | Nilai |
|---|---|
| OS | Ubuntu 20.04 / 22.04 / 24.04 · Debian 11 / 12 (systemd) |
| CPU | 1 vCPU — x86_64 / aarch64 / arm64 |
| RAM | minimal 512 MB · disarankan 1 GB |
| Disk bebas `/` | minimal 2 GB · disarankan 5 GB |
| Virtualisasi | KVM / VMware · **bukan** OpenVZ / LXC / container |
| Port | 80 · 443 · 143 · 109 bebas (panel lama boleh; nginx/apache2 dihentikan otomatis) |
| Domain | A record → IP VPS, tanpa AAAA |
| Akses | root |
| Lisensi | IP VPS terdaftar di `izin.txt` ([@wibuvpn](https://t.me/wibuvpn)) |

### Cek cepat sebelum mulai

Jalankan di VPS (lewat SSH sebagai root):

```bash
nproc                       # jumlah CPU — minimal 1
free -m                     # kolom total — minimal 512, disarankan 1024
df -h /                     # kolom Avail — minimal 2G, disarankan 5G
systemd-detect-virt         # didukung: kvm / vmware / microsoft / xen / qemu / bochs /
                            # parallels / oracle / none (nilai lain -> WARN, tidak fatal)
                            # container (openvz/lxc/docker) ditolak — paksa: WIBU_ALLOW_CONTAINER=1
ss -ltnp | grep -E ':(80|443|143|109)\b'   # kosong = aman
```

Kalau `ss` menampilkan proses selain `haproxy`, `xray`, `dropbear`, `stunnel`,
`ws-stunnel`, `badvpn-udpgw`, atau `systemd`, hentikan dulu proses itu
(`systemctl stop <nama>`) atau pilih port/VPS lain.

---

## 2. Langkah 1 — Daftarkan IP VPS

Kirim **IP publik VPS** ke [@wibuvpn](https://t.me/wibuvpn). Contoh pesan:

> Halo, saya mau pasang WIBUTUNNEL.
> IP VPS: 103.150.xx.xx
> Domain: vpn.domain-anda.com

Pendaftaran berlaku langsung, tanpa perlu rilis baru. Tanpa langkah ini installer akan
berhenti di **gerbang lisensi** dan menampilkan IP VPS — itu bukan error jaringan.

Cek IP publik VPS bila belum tahu:

```bash
curl -4 -fsSL https://api.ipify.org; echo
```

---

## 3. Langkah 2 — Arahkan domain ke VPS

Di pengelola DNS domain (Cloudflare, Registrar, dll.) buat:

| Tipe | Nama | Nilai | TTL |
|---|---|---|---|
| A | `vpn` (atau `@`) | IP VPS | Auto / 300 |

**Jangan** membuat record **AAAA** (IPv6) untuk nama yang sama — installer memakai
`curl -4`, dan AAAA yang salah adalah penyebab umum "domain tidak mengarah ke VPS".
Bila memakai Cloudflare, awali sebagai **DNS only** (awan abu-abu) sampai sertifikat
selesai dipasang.

Cek propagasi dari komputer Anda:

```bash
dig +short A vpn.domain-anda.com
```

Harus keluar IP VPS. Propagasi bisa 1–10 menit (maksimal 24 jam).

---

## 4. Langkah 3 — Pasang panel

Satu perintah di VPS (sebagai root):

```bash
bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
```

Perintah ini mengunduh `install.sh` dari **Release GitHub**, lalu bootstrap mengunduh
`setup.sh` dari **tag rilis tetap** dan memverifikasi sha256 sebelum menjalankan apa pun.
Hash tidak cocok → berhenti tanpa menyentuh sistem.

Untuk server tanpa terminal interaktif (cron/CI), lihat bentuk otomasi di bagian akhir
langkah ini — domain wajib diberikan sebagai argumen.

---

## 5. Langkah 4 — Jawab pertanyaan installer

Installer akan bertanya di terminal:

1. **Domain** — masukkan domain dari Langkah 2, mis. `vpn.domain-anda.com`.
2. **Token bot Telegram (opsional)** — boleh dikosongkan; bisa diatur nanti lewat
   `menu` → Setting → [6] Setup Bot Telegram.

Setelah itu installer berjalan otomatis: memasang paket, menyiapkan Xray/HAProxy/
Dropbear, meminta sertifikat SSL, dan menyalakan service. Jangan tutup terminal.

Untuk otomasi tanpa terminal (cron/CI), domain wajib jadi argumen:

```bash
curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash -s -- vpn.domain-anda.com
```

---

## 6. Langkah 5 — Verifikasi

Setelah muncul **INSTALASI SELESAI**, cek:

```bash
menu                              # dashboard panel
systemctl status xray haproxy    # keduanya harus active (running)
```

WIBUTUNNEL **tidak punya panel web**. Semua pengelolaan lewat `menu` (TUI di terminal).
Alamat `https://vpn.domain-anda.com` dipakai HAProxy sebagai pintu masuk koneksi tunnel;
membukanya di browser bisa menampilkan 503 — itu normal, bukan tanda instalasi gagal.
Untuk memastikan TLS aktif dan sertifikat terpasang:

```bash
openssl s_client -connect vpn.domain-anda.com:443 -servername vpn.domain-anda.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -dates
```

Buat satu akun percobaan lewat `menu`, lalu sambungkan dari aplikasi klien untuk memastikan
tunnel bekerja.

Bila ada yang tidak sesuai, lihat log di `/root/wibutunnel-install.log` (bagian 9).

---

## 7. Langkah 6 — Reboot (disarankan)

Di akhir installer akan ditanya:

```
Apakah Anda ingin reboot VPS sekarang? [y/N]:
```

Jawab `y` bila tidak ada pekerjaan lain di VPS. Reboot memastikan seluruh unit dan aturan
firewall dimuat ulang dari kondisi bersih. Setelah VPS hidup, jalankan `menu` sekali untuk
memastikan panel kembali normal.

---

## 8. Verifikasi hash tanpa memasang

Untuk memastikan rantai unduhan benar tanpa mengubah sistem:

```bash
WIBU_BOOTSTRAP_ONLY=1 bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
```

Keluaran yang diharapkan: `tag rilis : v4.1.50` → `hash      : OK` →
`[i] WIBU_BOOTSTRAP_ONLY=1 — instalasi tidak dijalankan.`

Cara manual (unduh → verifikasi → pasang) juga tersedia di README; `SHA256SUMS` dan
`setup.sh` harus berasal dari rilis yang sama.

---

## 9. Log instalasi

Keluaran installer sejak gerbang lisensi **dan** preflight lolos disalin ke:

```
/root/wibutunnel-install.log
```

Berkas ini dibuat dengan permission `600` (hanya root). Bila instalasi gagal atau perilakunya
aneh, kirim berkas ini ke [@wibuvpn](https://t.me/wibuvpn) agar bisa dibantu:

```bash
ls -l /root/wibutunnel-install.log
```

Jangan mengirim isi `bot.conf`, `izin.txt`, atau berkas kredensial lain.

---

## 10. FAQ

### DNS belum propagasi — domain tidak mengarah ke VPS

- **Gejala:** installer/SSL gagal, `dig +short A domain` kosong atau IP lama.
- **Penyebab:** record A belum tersebar, masih ada AAAA, atau salah nama.
- **Solusi:** tunggu 1–10 menit, hapus AAAA, cek ulang dengan `dig +short A domain`.
  Coba juga `dig @1.1.1.1 +short A domain` untuk memastikan sisi resolver.

### Port dipakai proses lain

- **Gejala:** preflight menampilkan `Port 80 dipakai proses lain: <nama>` (atau 443/143/109).
- **Penyebab:** ada proses asing (bukan panel) yang memegang port tersebut.
- **Solusi:** hentikan dulu prosesnya: `systemctl stop <nama>`, lalu jalankan ulang installer.
- Catatan: `nginx`/`apache2` **tidak** menggagalkan preflight — installer sendiri yang
  menghentikannya (muncul `[WARN] ... akan dihentikan otomatis`). Proses milik panel lama
  (`haproxy`, `xray`, `dropbear`, dll.) juga tidak perlu dihentikan — reinstall diizinkan.
  Bila `ss` tidak ada (jarang di Debian/Ubuntu), preflight memberi **WARN** dan melewati cek
  port — pasang `iproute2` lalu jalankan ulang bila ingin pemeriksaan penuh. Bila `ss` ada
  tetapi gagal membaca pemilik socket, preflight bersikap ketat (gagal) agar proses yang
  tidak dikenal tidak tertimpa.

### IP belum terdaftar

- **Gejala:** berhenti di gerbang lisensi, layar menampilkan IP VPS dan kontak admin.
- **Penyebab:** IP belum ada di `izin.txt`.
- **Solusi:** kirim IP ke [@wibuvpn](https://t.me/wibuvpn), tunggu konfirmasi, jalankan
  ulang perintah installer. Tidak perlu memformat ulang VPS.

### 429 Let's Encrypt (rate limit)

- **Gejala:** permintaan sertifikat gagal dengan kode 429 / "too many certificates".
- **Penyebab:** terlalu banyak permintaan sertifikat untuk domain yang sama dalam periode
  singkat (batas ACME).
- **Solusi:** tunggu sesuai pesan (biasanya 1 jam–1 minggu), atau pakai subdomain lain,
  lalu ulangi `m-setting` → [1] Auto-Repair / `wibu-ssl-ulang`. Jangan menghapus dan
  memasang berulang kali — itu menambah hitungan limit.

### Bot 409 — webhook/polling bentrok

- **Gejala:** bot tidak menjawab; `journalctl -u telegram-bot` menampilkan 409.
- **Penyebab:** token yang sama dipakai bot lain / VPS lain, atau webhook lama masih aktif.
- **Solusi:** hentikan bot di VPS lain, atau ganti token lewat `menu` → Setting → [1]
  (token lama dan baru dilepas otomatis). Cek `/etc/wibutunnel/tmp/bot_error.log`.

### OpenVZ / LXC

- **Gejala:** preflight menolak dengan `Virtualisasi 'openvz' tidak didukung`.
- **Penyebab:** kernel container tidak mendukung TUN/TProxy yang dibutuhkan panel.
- **Solusi:** pindah ke VPS KVM/VMware. Opsi paksa `WIBU_ALLOW_CONTAINER=1` hanya untuk
  uji dan tidak disarankan untuk produksi.

---

## 11. Hapus panel

```bash
curl -4 -fsSL -o uninstall.sh https://github.com/WBVPN/wibutunnel/releases/latest/download/uninstall.sh
bash uninstall.sh
```

Uninstall menghapus seluruh bagian panel (termasuk UDPGW), tetapi **tidak** menyentuh akses
SSH port 22. Cadangan otomatis dibuat di `/root/wibutunnel-backup-*/` sebelum penghapusan —
simpan direktori itu bila suatu saat ingin memulihkan.

---

## 12. Pin versi

Bootstrap bisa dipin ke tag tertentu:

```bash
WIBU_REF=v4.1.50 bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
```

`EXPECT` di `install.sh` harus menunjuk hash `setup.sh` pada tag yang sama. Artinya pin hanya
valid untuk tag yang `setup.sh`-nya cocok dengan `EXPECT` pada `install.sh` yang dipakai — saat
ini `v4.1.50`. Untuk tag lain, bootstrap akan berhenti dengan "HASH TIDAK COCOK" sampai rilis
tersebut membawa `EXPECT` yang sesuai. Untuk penggunaan normal, biarkan default
(`releases/latest`) agar selalu mendapat perbaikan terbaru.
