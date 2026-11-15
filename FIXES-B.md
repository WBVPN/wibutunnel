# FIXES-B.md — Patch Keamanan Bagian Bot & Menu (wibutunnel v4.0.6-fixed)

Koder B. Berkas yang diubah: `menu/bot-daemon.sh`, `menu/m-setting.sh`, `menu/m-backup.sh`,
`menu/menu-recovery.sh`, `menu/m-ssh.sh`. Semua `bash -n` LULUS. Tak menyentuh berkas lain.

---

## B1 (TINGGI, keamanan) — token bot keluar dari argv
**Berkas:** `menu/bot-daemon.sh`

- **Helper baru** di dekat `log_bot_error` → `tg_api` (sekarang baris **47-51**):
  ```bash
  # B1: Token TIDAK boleh muncul di argv. curl membaca URL dari STDIN (-K -).
  tg_api() {  # $1=method (mis. sendMessage), sisanya diteruskan ke curl
    local m="$1"; shift
    printf 'url = "https://api.telegram.org/bot%s/%s"\n' "$BOT_TOKEN" "$m" | curl -s -K - "$@"
  }
  ```
  Alasan: URL (memuat token) tak lagi jadi argumen → tidak terlihat di `ps aux`.

- **11 titik panggil** `curl … api.telegram.org/bot${BOT_TOKEN}/…` diganti `tg_api <method> …`
  (argumen `-X POST`/`-F`/`--data-urlencode`/`--max-time`/`&` tetap):
  | sebelum | sesudah |
  |---|---|
  | 53 (sendMessage+kb) | **59** |
  | 60 (sendMessage) | **66** |
  | 78 (editMessageText) | **84** |
  | 671 (sendMessage -F) | **676** |
  | 701 (sendDocument) | **706** |
  | 712 (editMessageCaption) | **717** |
  | 722 (deleteMessage) | **727** |
  | 729 (deleteMessage) | **734** |
  | 983 (deleteWebhook) | **988** |
  | 994 (getUpdates?query) | **999** → `tg_api getUpdates -S --max-time 35 -G --data-urlencode "offset=${OFFSET}" --data-urlencode "timeout=30" 2>&1` |
  | 1017 (answerCallbackQuery?query) | **1022** → `tg_api answerCallbackQuery -G --data-urlencode "callback_query_id=${CB_ID}" >/dev/null &` |

  Alasan query dipindah: `getUpdates`/`answerCallbackQuery` ber-query → pakai `-G --data-urlencode`
  agar URL dibangun curl dari stdin (bukan disisipkan ke argv).

- **Bukti:** `grep -c 'api.telegram.org/bot${BOT_TOKEN}' menu/bot-daemon.sh` → **0**.
  Uji mekanik `-K -` + `-G` terhadap listener lokal → path benar
  (`/bot<token>/getUpdates?offset=5&timeout=30`, dst).

## B4 (SEDANG) — hitungan trafik bot dobel
**Berkas:** `menu/bot-daemon.sh`
- **Baris 1066 → 1071** pada `awk` "Cek Trafik Global":
  - sebelum: `down=($2=="null"||$2=="")?0:$2; up=($3=="null"||$3=="")?0:$3; print (down+up)":"$1`
  - sesudah: `tot=($2=="null"||$2=="")?0:$2; print tot":"$1`
  - Alasan: `user_usage.db` = 3 kolom `user:total:lastraw`; kolom 3 bukan byte pemakaian
    (acuan `menu/cek-trafik.sh:120` pakai kolom 2 saja). Sebelumnya `$2+$3` = total+lastraw (dobel).

## B5 (SEDANG) — tulis DB tanpa flock
- **`menu/bot-daemon.sh` baris 494-495 → 500:** `safe_sed_delete …` + `echo … >> "$exp_file"`
  diganti `db_set "$exp_file" "$user" "$exp_date"` (helper flock dari `common.sh`).
- **`menu/menu-recovery.sh` baris 105 → 107-108:** truncate telanjang
  `> /etc/wibutunnel/locked_users.db` diganti
  ```bash
  ( flock -w 10 200 || echo "[ERROR] flock timeout locked_users.db" >&2
    : > /etc/wibutunnel/locked_users.db ) 200>/etc/wibutunnel/tmp/locked_users.db.lock
  ```
  Alasan: cegah race dengan penulis lain (mis. `lock-user`). (`db_truncate` tak ada di `common.sh`;
  `common.sh` bukan milik koder ini → implementasi lokal ber-flock.)

## B2 (TINGGI) — `safe_update` verifikasi unduhan (fail-closed)
**Berkas:** `menu/m-setting.sh` (fungsi `safe_update`, kini baris **36-126**)
- **Ref dipin** (baris **14-15**): `WIBU_REF="${WIBU_REF:-v4.0.6-fixed}"`.
- **Unduh** (47-52): `wget` → `curl -fSL --retry 3 --max-time 60 -o "$tmp_file" "$raw_url"`;
  cek exit code + non-kosong → gagal = `return 1` (tak menimpa apa pun).
- **Verifikasi SHA256** (54-79): ambil `${raw_base}/SHA256SUMS` (ref sama), bandingkan
  `sha256sum` dengan baris manifest `$2 == <repo_path>`; manifest tak ada / tak memuat / hash beda
  → **TOLAK** (`return 1`). Bypass hanya bila `WIBUTUNNEL_ALLOW_UNVERIFIED=1` (ditampilkan besar +
  dicatat ke `bot_error.log`).
  - Sebelum: `if [[ -s "$tmp_file" ]]` + `bash -n` saja (404 bisa lolos).
- **Cadangan rollback** (106-116): sebelum menimpa, `cp -a` berkas lama →
  `/usr/local/share/wibutunnel/backup/<nama>.<timestamp>`.
- **Bukti unit test** (fungsi asli, path dipindah ke `/tmp`): hash cocok→diterima; hash beda→DITOLAK;
  manifest kosong→DITOLAK; manifest 404→DITOLAK; unduh 404→DITOLAK; bypass env→diterima.

## B3 (SEDANG) — durasi lock: normalisasi + guard
**Berkas:** `menu/m-setting.sh` (menu 9, baris **470-479**)
- Sebelum: `^[0-9]+$` + `-lt 1` saja (→ `08`/`09` lolos, `$((LOCK_DURATION*60))` error oktal).
- Sesudah: normalisasi `new_duration=$((10#$new_duration))` + tolak `<1` atau `>1440`.
  - Bukti: `08→8`, `09→9`, `1440` diterima, `1441`/`0`/`abc` ditolak.

## B6 (TINGGI, keamanan) — restore backup dari URL/zip arbitrer
**Berkas:** `menu/m-backup.sh` (`do_restore`, baris **175-300**)
- **(a) hanya https** (196-197): `^http://` ditolak; path Telegram/File ID tetap dibangun via https.
- **(b) password wajib** (225-228): prompt password non-kosong; `unzip -P "$restore_pass"`.
  Fallback **tanpa password dihapus** (dulu ada `unzip -o … || unzip -o …`).
- **(c) validasi entri sebelum ekstrak** (232-243): tolak entri berawalan `/`, mengandung `..`, atau di
  luar `etc/wibutunnel/*`, `etc/xray/*` (plus berkas eksplisit `usr/local/etc/xray/config.json`).
- **(d) ekstrak ke `mktemp -d`** (189, 253-259), bukan `/tmp` nama tetap.
- **(e) bersihkan via trap** (192): `trap 'rm -rf "$work_dir"' RETURN EXIT INT TERM` (+ `rm -rf` akhir).
- **Bukti unit test** (blok verifikasi asli): entri sah→lolos; `..`→DITOLAK; `/etc/passwd`→DITOLAK;
  `usr/bin/evil`→DITOLAK.

## B7 (RENDAH, keamanan) — backup ke /tmp nama tetap + password default = CHAT_ID
**Berkas:** `menu/m-backup.sh`
- **Password acak** (24-32): `BACKUP_PASS` default `openssl rand -hex 16` (fallback `/dev/urandom`);
  `zip -P "$BACKUP_PASS"` (baris **53**, **123**) menggantikan `-P "$CHAT_ID"`.
- Password ditampilkan ke admin di caption (baris **73**, **84**, **146**, **158**): `CHAT ID Anda`
  → `<code>${BACKUP_PASS}</code>`.
- **Berkas kerja di `mktemp -d`** mode 700 + trap (lihat B6).

## B8 (RENDAH) — unlock daftar semua user
**Berkas:** `menu/m-ssh.sh` (baris **305-313**)
- Sebelum: `mapfile … awk -F: '{print $1}' "$DB_LOCK" | sort -u` (semua protokol).
- Sesudah: disaring `id "$u"` (hanya user SSH ber-akun sistem); teks menu
  `Akun terkunci:` → `Akun SSH terkunci:` dan `Tidak ada akun terkunci.` → `Tidak ada akun SSH terkunci.`.

## B9 (RENDAH) — restart-all
**Berkas:** `menu/m-setting.sh` (baris **163**)
- `systemctl restart … wibu-daemon cron …` → `… wibu-daemon telegram-bot network-tune cron 2>/dev/null || true`.
  Alasan: unit bot & network-tune ikut di-restart; `|| true` agar unit yang tak ada tak menggagalkan.

---

## Verifikasi
- `bash -n`: LULUS untuk kelima berkas.
- `grep -c 'api.telegram.org/bot${BOT_TOKEN}' menu/bot-daemon.sh` → **0**.
- Unit test `/tmp/wibu_tests.sh` → **16 PASS / 0 FAIL** (B2/B3/B6).
- Uji `tg_api` vs listener lokal → URL & query benar; uji trap → work_dir terhapus.

## Sisa / ragu (jujur)
- `menu/bot-daemon.sh` `backup_vps` (baris ~676-733) masih membuat zip dengan `-P "$CHAT_ID"` dan
  menulis `/tmp/${domain}-${ip}.zip` (nama tetap). Di luar lingkup B7 (khusus `m-backup.sh`) dan tak
  mengubah UX bot → **tidak diubah**. Hardening serupa disarankan bila diinginkan.
- Restore kini WAJIB password; backup lama yang ber-password CHAT_ID tetap bisa di-restore dengan
  mengetik CHAT ID saat prompt (perilaku lama = password default, bukan bypass).
- Manifest `SHA256SUMS` harus ada di root repo pada `$WIBU_REF`; belum diverifikasi keberadaannya di
  repo (di luar kendali koder ini) — sesuai desain fail-closed, update ditolak sampai manifest dibuat.
