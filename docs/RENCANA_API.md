# Rencana API Wibutunnel (belum dikerjakan — disimpan untuk nanti)

Status: **rancangan**, disetujui untuk ditunda. Ditulis dari pembacaan kode v4.0.6-fixed yang
sudah teruji di VPS (lihat [`HASIL_UJI_VPS.md`](HASIL_UJI_VPS.md)).

## Kenapa perlu

Hari ini panel hanya bisa dikendalikan **manusia**: menu di VPS + bot Telegram. Tidak ada pintu masuk
program, sehingga web toko / payment gateway tidak bisa memicu pembuatan akun otomatis
(pelanggan bayar → akun harus dibuat manual).

## Yang sudah ada (jangan ditulis ulang)

Logika akun sudah berbentuk fungsi di setiap modul protokol (`menu/m-vless.sh`, `m-vmess.sh`,
`m-trojan.sh`, `m-ssh.sh`):

```
add_user()  trial_user()  delete_user()  cek_user()  renew_user()
change_ip_user()  change_bw_user()  lock_unlock_user()  recovery_vless()
```

Penopang di `common.sh`:

```
safe_jq_edit / safe_jq_edit_args   # edit config.json dengan flock (anti race)
xray_inbound_index / xray_primary_index / xray_sync_user
db_set db_get db_has db_delete     # flat-file DB
sanitize_user                      # validasi nama user
check_license / check_license_silent
ssh_valid_user / ssh_list_users    # modul SSH
```

Bot Telegram (`menu/bot-daemon.sh` → `create_account()`) **sudah** memanggil jalur yang sama.
Artinya: API cukup **membungkus** fungsi-fungsi itu, bukan mengimplementasi ulang.

Enforcement kuota & expiry tetap milik daemon yang sudah ada (`algojo-kuota`, `algojo-expired`,
`algojo-expired-daemon`, `algojo-ssh`, `wibu-daemon`) — API hanya mendaftarkan akun + tanggal/kebijakannya.

## Tingkat 1 — Agen API di VPS (wajib, dasar semuanya)

Daemon kecil, **hanya 127.0.0.1** (`/usr/local/bin/wibu-api`, systemd `wibu-api.service`).

- Auth: bearer token dari `/etc/wibutunnel/api.conf` (0600) + opsional allowlist IP.
  **Fail-closed**: token kosong/berkas tidak ada → tolak semua permintaan.
- Rate limit (mis. 30 req/menit) + audit log `/var/log/wibutunnel-api.log` (siapa, endpoint, order_id).
- Semua nama lewat `sanitize_user`/`ssh_valid_user`; semua tulis config lewat `safe_jq_edit` (flock).

### Endpoint

| Metode | Jalur | Isi | Keluaran |
|---|---|---|---|
| POST | `/v1/accounts` | `{proto, username, days, limit_ip, limit_gb, order_id}` | `{ok, username, exp, link, order_id}` |
| POST | `/v1/trial` | `{proto}` | idem (nama acak) |
| GET | `/v1/accounts/{proto}/{username}` | — | `{ok, exp, ip_aktif, kuota, terpakai, locked}` |
| POST | `/v1/accounts/{proto}/{username}/renew` | `{days, order_id}` | `{ok, exp}` |
| POST | `/v1/accounts/{proto}/{username}/lock` \| `/unlock` | — | `{ok, locked}` |
| DELETE | `/v1/accounts/{proto}/{username}` | — | `{ok}` |
| GET | `/v1/server` | — | `{ok, versi, terlisensi, jumlah_user, trafik, uptime}` |

`proto` = `vless` \| `vmess` \| `trojan` \| `ssh`. `link` = URI config siap kirim
(`vless://…`, `vmess://…`, `trojan://…`, atau baris SSH).

### Idempotensi (wajib untuk payment)

Simpan `order_id → (proto, username, exp)` di `/etc/wibutunnel/api_orders.db` (flock).
Permintaan dengan `order_id` yang sudah ada **mengembalikan akun yang sama**, tidak membuat akun baru —
webhook pembayaran yang dikirim dua kali tidak boleh menghasilkan dua akun.

### Penolakan yang harus ada

- Nama tidak valid / kosong / > 32 karakter / mengandung karakter aneh → 400.
- Nama sudah dipakai → 409 (kecuali renew).
- Lisensi exp / tidak terdaftar → 403 (panggil `check_license_silent`).
- `days` ≤ 0 atau > 3650, `limit_gb`/`limit_ip` di luar rentang → 400.
- Tanpa token yang benar → 401 (fail-closed).

## Tingkat 2 — Lapisan kontrol (Cloudflare, sudah tersedia di akun yang dipakai)

Worker + D1 sebagai otak bisnis (kamu sudah memakai pola ini untuk bot lain):

- Tabel `orders` (order_id, paket, jumlah, status bayar, vps, username, exp, link, channel pelanggan).
- Tabel `servers` (nama VPS, alamat agen, token, kuota, jumlah akun aktif).
- Tabel `packages` (proto, hari, limit_ip, limit_gb, harga).
- Endpoint publik tipis: `/order` (buat tagihan), `/status/{order_id}` (publik, tanpa data sensitif).
- Dashboard stok: berapa akun aktif per VPS, sisa kapasitas, yang akan expired.

**Jalur ke VPS tanpa membuka port: Cloudflare Tunnel** (`cloudflared`) → agen tetap 127.0.0.1,
tidak ada IP VPS yang terekspos, tidak ada port panel yang dibuka.

## Tingkat 3 — Payment gateway (auto-provision)

Alur: pelanggan bayar → gateway kirim webhook ke Worker → **verifikasi tanda tangan** → Worker panggil
agen API (`POST /v1/accounts`, pakai `order_id` dari gateway) → simpan hasil ke D1 → kirim config ke
pelanggan (bot Telegram kamu, WhatsApp, atau email) → catat untuk perpanjangan otomatis.

Wajib: verifikasi tanda tangan, idempotensi per `order_id`, retry dengan backoff bila agen mati,
dan status `menunggu_dibuat` supaya pembayaran yang sudah masuk tidak hilang saat VPS sedang down.

## Aturan keamanan (jangan dilanggar)

1. Agen **hanya** 127.0.0.1; jangan pernah buka ke publik, jangan pakai port yang sama dengan panel.
2. Port API Xray (`10085`) tetap **root-only** (sudah ditegakkan `wibutunnel-firewall.sh` + timer).
3. Token disimpan 0600, tidak pernah di `argv` (baca seperti bot: `curl -K -`), rotasi bila bocor.
4. Fail-closed: token hilang → tolak semua; manifest/verifikasi gagal → jangan dasar.
5. Gerbang lisensi tetap dicek di setiap aksi.
6. Audit log semua aksi tulis (create/renew/delete/lock).

## Rencana uji (di VPS uji, bukan produksi)

```
1. Token salah          -> 401, tidak ada perubahan di sistem
2. Buat akun vless 30h  -> akun tampil di menu, config link valid, Xray /users bertambah 1
3. order_id sama 2x     -> akun TIDAK bertambah (idempotensi)
4. Nama aneh (`../../`, `a b`, 40 karakter) -> 400
5. Akun kedaluwarsa     -> GET menandai exp; algojo-expired menindak sesuai kebijakan
6. Lock/unlock          -> passwd -S & login SSH mengikuti
7. Kuota dihabiskan     -> algojo-kuota menindak; status akun melaporkan pemakaian
8. Lisensi di-exp-kan  -> semua endpoint tulis menolak (403)
9. Rate limit           -> 429 setelah batas
10. Matikan daemon      -> tidak ada perubahan pada panel (API opsional, bukan syarat hidup)
```

## Perkiraan besar pekerjaan

| Bagian | Perkiraan |
|---|---|
| Agen API (bash/python stdlib) + systemd + token + audit | ~400-500 baris |
| Uji otomatis (10 kasus di atas) | ~150 baris |
| Worker + D1 (pesanan/stok/paket) | ~300-500 baris |
| Integrasi payment (per gateway) | ~150-250 baris |
| Dokumentasi + paket | ikut pola paket sebelumnya |

## Catatan implementasi

- Kalau memanggil fungsi dari `menu/m-*.sh`, jangan `source` berkas menu secara langsung (bagian
  bawahnya `read` + loop menu). Ambil fungsinya seperti pola yang sudah dipakai bot (`create_account()`),
  atau jalankan dengan jawaban pipa.
- Ikuti pola update yang sudah dikunci: berkas repo + `SHA256SUMS`, manifest **dari API GitHub** (raw CDN
  terbukti menyajikan manifest lama), dan sertakan berkas baru di daftar update menu [5].
- Tambahkan berkas baru ke `SHA256SUMS` + daftar `safe_update` + harness dalam commit yang sama.
