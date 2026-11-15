# FIXES-A — patch keamanan inti enforcement wibutunnel v4.0.6

Berkas milikku: `common.sh`, `sbin/algojo-ssh`, `sbin/algojo-wibu`, `sbin/algojo-kuota`,
`sbin/algojo-expired`, `sbin/unlock-user`. Tidak menyentuh berkas lain. Tidak menjalankan
`setup.sh` / `uninstall.sh` / `tests/`.

> Catatan: helper baru `xray_proto_tags` + `xray_del_filter` + `xray_add_filter` +
> `xray_primary_index` ditambahkan di `common.sh` untuk A6 (dipakai 3 berkas).

---

## A1 (KRITIS) — tulis DB wajib lewat helper ber-flock

- `common.sh:128` `db_append()` → ditambah cabang 3-arg: `db_append <user> <value> <file>`
  yang delegasi ke `db_set` (flock fd 200 + dedupe `awk index()` + `mv` atomik + `chmod 600`).
  Bentuk 2-arg lama `<file> <line>` (dipakai `menu/m-*.sh`) tetap utuh.
  Alasan: `db_append` bentuk `"$user" "value" "$file"` tidak ada sebelumnya → ditambahkan.
- `sbin/algojo-wibu:54` `echo "${email}:${now}:${unlock_time}:IP_LIMIT" >> "$DB_LOCK"`
  → `db_append "$email" "${now}:${unlock_time}:IP_LIMIT" "$DB_LOCK"`.
- `sbin/algojo-ssh:96` `echo "${user}:${now}:${unlock_time}:SSH_IP_LIMIT" >> "$DB_LOCK"`
  → `db_append "$user" "${now}:${unlock_time}:SSH_IP_LIMIT" "$DB_LOCK"`.
  Alasan: tulis non-atomik (bisa korup/duplikat saat concurrency). Format baris akhir IDENTIK:
  `user:kolom2:kolom3:kolom4`.

## A2 (TINGGI) — guard oktal `10#` + fallback

- `sbin/algojo-wibu:52` `$((now + (LOCK_DURATION * 60)))`
  → `$((now + (10#${LOCK_DURATION} * 60)))`; guard di `:48` → bila `LOCK_DURATION` bukan `^[0-9]+$`,
  set `LOCK_DURATION=15` + log stderr.
- `sbin/algojo-ssh:87` `unlock_time=$((now + (LOCK_DURATION * 60)))`
  → `$((now + (10#${LOCK_DURATION} * 60)))`; guard di `:83`.
  Alasan: `LOCK_DURATION=08` → `08: value too great for base` → `unlock_time` kosong → akun terkunci permanen.
  `10#` menafsirkan `08` sebagai desimal 8; non-numerik → fallback 15 menit.

## A3 (TINGGI) — izin bocor exp.conf 644 → 600

- `common.sh:90` `safe_sed_delete`: `chmod 644 "$file"` → `chmod 600 "$file"`.
- `common.sh:118` `db_set`: `chmod 644 "$file"` → `chmod 600 "$file"`.
  Alasan: `/etc/xray/*_exp.conf` (daftar pelanggan + masa aktif) di dir 755 dapat dibaca semua user
  lokal. Dua-duanya diubah karena `db_set` adalah penulis utama baris exp
  (`add_ssh_user`, `algojo-kuota`, `algojo-expired`). Berkas `/etc/wibutunnel/*.db` tidak diubah.

## A4 (SEDANG) — validasi numerik sebelum banding

- `sbin/algojo-wibu:30-33` sebelum `[[ $ip_count -gt $max_ip ]]` → tambah guard: nilai `limit_ip.db`
  non-`^[0-9]+$` dianggap 0 + log; banding di `:38` jadi `(( ip_count > 10#$max_ip ))`.
- `sbin/algojo-ssh:70-71` guard sama untuk `max_sess`; banding `:79` tetap `10#` (sudah ada).
  Alasan: bash menganggap non-numerik = 0 → `limit_ip` korup memicu lock user sah (kolom `-gt`).

## A5 (SEDANG) — `proto=UNKNOWN` jangan tulis berkas palsu

- `sbin/algojo-kuota:70-76` setelah deteksi protokol: bila `proto` bukan VLESS/VMESS/TROJAN →
  log stderr + notif Telegram (bila `BOT_TOKEN`/`CHAT_ID`) + `continue` (tidak menulis
  `/etc/xray/unknown_exp.conf` di `db_set ":142"`).
  Alasan: protokol tak dikenal sebelumnya menulis `unknown_exp.conf` sampah + flag lock palsu.

## A6 (SEDANG) — jangan bergantung indeks inbound 1..8

- `common.sh:186` `xray_inbound_index <tag>`: baca `$XRAY_CONFIG` via `jq`
  (`.inbounds | to_entries[] | select(.value.tag == $t) | .key`); non-nol + tanpa output bila
  tag tak ada ATAU `jq` gagal (jangan menebak).
- `common.sh:197` `xray_proto_tags <PROTO>` (`VLESS/VMESS/TROJAN/ALL`), `:208` `xray_primary_index`,
  `:216` `xray_del_filter`, `:228` `xray_add_filter`.
- Dipakai: `algojo-kuota:81,111-113,127`; `algojo-expired:60,87-89,115`; `unlock-user:38,65-67`.
  Indeks `1..8` hardcoded diganti resolusi via tag; gagal resolve → `echo "[ERROR] ..."` + tidak
  menulis konfigurasi.
  Alasan: layout inbound bisa berubah; indeks hardcoded menulis ke inbound yang salah.

## A7 (RENDAH) — curl saat source-time → lazy

- `common.sh:24` blok `export MYIP=$(curl ...)` saat source-time → `MYIP="${MYIP:-}"` + fungsi
  `detect_myip()` (`:25`); pemanggil jaringan lama di `check_license` → `detect_myip >/dev/null` (`:353`).
  Alasan: sourcing `common.sh` tidak boleh menunggu / bergantung jaringan.

## A8 (RENDAH) — `read -r`

- `sbin/algojo-expired:39` `while read stat_name` → `while read -r stat_name`.
  Alasan: cegah backslash-eating pada nama stat.

---

## Verifikasi

- `bash -n` LULUS untuk 6 berkas (lihat laporan).
- Unit test `/tmp/wibutest/test.sh`: **27/27 PASS** (A2 oktal/fallback, A4 numerik, A6 indeks/filter).
  jq absen di sandbox ini → dipakai shim `/tmp/wibutest/jq` (perilaku identik untuk lookup tag);
  config uji = `config/config.json` (indeks 1..8 cocok dgn `setup.sh`).
- A1 diuji dgn `flock`: 3-arg dedupe (user1 tetap 1 baris), format `user:col:col:col`, perm `600`.

Bukti bug lama (dicetak test):
- A2: `LOCK_DURATION=08` → `08: value too great for base (error token is "08")`.
- A4: `[[ 1 -gt $max_ip(abc) ]]` → TRUE (limit korup dianggap 0).

## Sisa / ragu

- A5: instruksi "Telegram (kalau ada helper)" — tidak ada helper notif generik, jadi notif
  Telegram dilakukan inline (guard `BOT_TOKEN`/`CHAT_ID`) + log stderr; tidak menambah dependensi.
- A6: `xray_inbound_index` bergantung `jq` (sudah dipakai di seluruh paket). Bila `jq` absen saat
  runtime, helper mengembalikan non-nol → script mencatat error & tidak menulis konfigurasi
  (tidak menebak). jq tidak ada di sandbox ini, jadi A6 diuji via shim (bukan jq asli).
