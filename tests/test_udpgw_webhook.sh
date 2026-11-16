#!/bin/bash
# ==========================================
# Tes UDPGW (badvpn-udpgw) + mode WEBHOOK bot + toleransi IP (TTL 600)
# ==========================================
# Semua offline: systemctl dipalsukan lewat stub, server webhook dijalankan di
# port lokal sementara, dan tidak ada permintaan ke Telegram.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPD=$(mktemp -d)
SRV_PID=""
cleanup() { [[ -n "$SRV_PID" ]] && kill "$SRV_PID" 2>/dev/null || true; rm -rf "$TMPD"; }
export WIBU_UNITS_DRY_RUN=0
trap cleanup EXIT

echo "=== TEST 1: wibu-udpgw — sintaks, unit, daftar port ==="
bash -n "$REPO_DIR/sbin/wibu-udpgw" || { echo "FAIL: sintaks sbin/wibu-udpgw"; exit 1; }
echo "PASS: sbin/wibu-udpgw sintaks OK"

# unit ditulis ke direktori temporer (jangan sentuh /etc)
export UDPGW_SYSTEMD_DIR="$TMPD/systemd"
export UDPGW_BIN="$TMPD/badvpn-udpgw"
export UDPGW_LOG="$TMPD/build.log"
printf '#!/bin/sh\necho "--listen-addr ok"\n' > "$UDPGW_BIN"; chmod +x "$UDPGW_BIN"
out=$(bash "$REPO_DIR/sbin/wibu-udpgw" install 2>&1 || true)
UNIT="$UDPGW_SYSTEMD_DIR/badvpn-udpgw@.service"
[[ -f "$UNIT" ]] || { echo "FAIL: unit tidak dibuat di $UDPGW_SYSTEMD_DIR"; exit 1; }
echo "PASS: unit templated dibuat"
grep -qF 'ExecStart='"$UDPGW_BIN"' --listen-addr 127.0.0.1:%i --max-clients 1000' "$UNIT" \
    || { echo "FAIL: ExecStart tidak sesuai"; grep ExecStart "$UNIT"; exit 1; }
echo "PASS: ExecStart memakai --listen-addr 127.0.0.1:%i (satu unit untuk semua port)"
grep -qF 'Restart=always' "$UNIT" || { echo "FAIL: unit tidak auto-restart"; exit 1; }
echo "PASS: unit auto-restart"

# idempotensi: jalankan kedua kali, isi unit tidak berubah
h1=$(sha256sum "$UNIT" | cut -d' ' -f1)
out2=$(bash "$REPO_DIR/sbin/wibu-udpgw" install 2>&1 || true)
h2=$(sha256sum "$UNIT" | cut -d' ' -f1)
[[ "$h1" == "$h2" ]] || { echo "FAIL: unit berubah saat dijalankan ulang"; exit 1; }
grep -q "sudah sesuai (tidak diubah)" <<< "$out2" || { echo "FAIL: tidak idempoten -> $out2"; exit 1; }
echo "PASS: idempoten (unit tidak ditulis ulang tanpa perubahan)"

echo "=== TEST 2: wibu-udpgw ports — baca status unit (systemctl dipalsukan) ==="
mkdir -p "$TMPD/bin"
cat > "$TMPD/bin/systemctl" <<'STUB'
#!/bin/bash
case "$1" in
    is-active) exit 0 ;;                  # anggap semua unit aktif
    *) exit 0 ;;
esac
STUB
chmod +x "$TMPD/bin/systemctl"
PORTS=$(PATH="$TMPD/bin:$PATH" bash "$REPO_DIR/sbin/wibu-udpgw" ports)
[[ "$PORTS" == "7100 7200 7300 7400 7500 7600" ]] || { echo "FAIL: daftar port -> '$PORTS'"; exit 1; }
echo "PASS: ports melaporkan 6 port UDPGW (7100-7600)"
grep -qE '^UDPGW_PORTS="\$\{UDPGW_PORTS:-7100 7200 7300 7400 7500 7600\}"' "$REPO_DIR/sbin/wibu-udpgw" \
    || { echo "FAIL: daftar port default tidak seperti yang didokumentasikan"; exit 1; }
echo "PASS: port default konsisten dengan yang diiklankan ke klien (UDPGW 7100-7600)"

echo "=== TEST 3: bot-webhook-server — sintaks + perilaku HTTP ==="
python3 -c "import py_compile, tempfile, os; py_compile.compile('$REPO_DIR/sbin/bot-webhook-server', cfile=os.path.join(tempfile.mkdtemp(), 'c.pyc'), doraise=True)" \
    || { echo "FAIL: sintaks bot-webhook-server"; exit 1; }
echo "PASS: bot-webhook-server sintaks OK"

PORT=$(( 20000 + RANDOM % 20000 ))
CONF="$TMPD/bot.conf"; QUEUE="$TMPD/queue.jsonl"
printf 'BOT_TOKEN="x"\nCHAT_ID="1"\n' > "$CONF"      # tanpa WEBHOOK_SECRET -> fail-closed
WIBU_WEBHOOK_PORT="$PORT" WIBU_BOT_CONF="$CONF" WIBU_WEBHOOK_QUEUE="$QUEUE" \
    python3 "$REPO_DIR/sbin/bot-webhook-server" > "$TMPD/srv1.log" 2>&1 &
SRV_PID=$!
for _ in $(seq 1 20); do curl -4 -s -o /dev/null "http://127.0.0.1:$PORT/health" 2>/dev/null && break; sleep 0.3; done
code=$(curl -4 -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
        -H 'X-Telegram-Bot-Api-Secret-Token: salah' -d '{"update_id":1}' "http://127.0.0.1:$PORT/telehook")
[[ "$code" == "503" ]] || { echo "FAIL: tanpa secret harus 503, dapat $code"; exit 1; }
echo "PASS: secret belum diatur -> 503 (fail-closed, tidak ada mode terbuka)"
kill "$SRV_PID" 2>/dev/null; SRV_PID=""

printf 'BOT_TOKEN="x"\nWEBHOOK_SECRET="rahasia-uji"\n' > "$CONF"
WIBU_WEBHOOK_PORT="$PORT" WIBU_BOT_CONF="$CONF" WIBU_WEBHOOK_QUEUE="$QUEUE" \
    python3 "$REPO_DIR/sbin/bot-webhook-server" >> "$TMPD/srv2.log" 2>&1 &
SRV_PID=$!
for _ in $(seq 1 20); do curl -4 -s -o /dev/null "http://127.0.0.1:$PORT/health" 2>/dev/null && break; sleep 0.3; done
code=$(curl -4 -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Telegram-Bot-Api-Secret-Token: salah' \
        -d '{"update_id":1}' "http://127.0.0.1:$PORT/telehook")
[[ "$code" == "403" ]] || { echo "FAIL: secret salah harus 403, dapat $code"; exit 1; }
echo "PASS: secret salah -> 403 (request ditolak)"
code=$(curl -4 -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Telegram-Bot-Api-Secret-Token: rahasia-uji' \
        -d 'bukan-json' "http://127.0.0.1:$PORT/telehook")
[[ "$code" == "400" ]] || { echo "FAIL: body bukan JSON harus 400, dapat $code"; exit 1; }
echo "PASS: body bukan JSON -> 400 (tidak masuk antrean)"
code=$(curl -4 -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Telegram-Bot-Api-Secret-Token: rahasia-uji' \
        -d '{"update_id":99,"message":{"text":"/start"}}' "http://127.0.0.1:$PORT/telehook")
[[ "$code" == "200" ]] || { echo "FAIL: update sah harus 200, dapat $code"; exit 1; }
grep -q '"update_id":99' "$QUEUE" || { echo "FAIL: update tidak masuk antrean"; exit 1; }
echo "PASS: update sah -> 200 dan masuk antrean"
kill "$SRV_PID" 2>/dev/null; SRV_PID=""

echo "=== TEST 4: bot-daemon mengubah antrean jadi bentuk getUpdates ==="
if command -v jq >/dev/null 2>&1; then
    RESP=$(jq -c -s '{ok:true, result:.}' "$QUEUE")
    [[ "$(echo "$RESP" | jq -r '.ok')" == "true" ]] || { echo "FAIL: bentuk resp ok"; exit 1; }
    [[ "$(echo "$RESP" | jq -r '.result | length')" == "1" ]] || { echo "FAIL: jumlah update tidak 1"; exit 1; }
    [[ "$(echo "$RESP" | jq -r '.result[0].update_id')" == "99" ]] || { echo "FAIL: update_id hilang"; exit 1; }
    echo "PASS: antrean -> {\"ok\":true,\"result\":[...]} (pemrosesan update tak perlu diubah)"
else
    echo "SKIP: konversi antrean (jq tidak terpasang di mesin ini; ada di VPS panel)"
fi
grep -q 'WEBHOOK_QUEUE' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: bot-daemon tidak membaca antrean"; exit 1; }
grep -q "jq -c -s '{ok:true, result:.}'" "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: konversi antrean hilang"; exit 1; }
grep -q 'BOT_MODE_FILE' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: bot-daemon tidak tahu mode webhook"; exit 1; }
echo "PASS: mode webhook pada bot-daemon tidak memanggil getUpdates (tidak bentrok 409)"

echo "=== TEST 5: toleransi IP (WIBU_IP_TTL=600) ==="
export XRAY_ACCESS_LOG="$TMPD/access.log"
NOW_TS=$(date '+%Y/%m/%d %H:%M:%S')
OLD_TS=$(date -d '300 seconds ago' '+%Y/%m/%d %H:%M:%S')      # 5 menit: harus MASIH terbaca
ANCIENT_TS=$(date -d '2 hours ago' '+%Y/%m/%d %H:%M:%S')      # 2 jam: harus diabaikan
# urutan KRONOLOGIS seperti access.log nyata (dibaca terbalik oleh live_ip_pairs)
{
  printf '%s.100000 from 198.51.100.7:5555 accepted tcp:x:443 [vless-ws-tls >> direct] email: lama.sekali\n' "$ANCIENT_TS"
  printf '%s.200000 from 43.156.147.95:44321 accepted tcp:x:443 [vless-ws-tls >> direct] email: roaming.one\n' "$OLD_TS"
  printf '%s.300000 from 203.0.113.9:6666 accepted tcp:x:443 [vless-ws-tls >> direct] email: baru.dua\n' "$NOW_TS"
} > "$XRAY_ACCESS_LOG"
source "$REPO_DIR/common.sh"
OUT=$(live_ip_pairs)
grep -q "^roaming.one 43.156.147.95$" <<< "$OUT" || { echo "FAIL: IP 5 menit lalu harus masih dihitung -> '$OUT'"; exit 1; }
echo "PASS: IP 5 menit lalu masih dianggap terhubung (toleransi roaming 600s)"
grep -q "^lama.sekali" <<< "$OUT" && { echo "FAIL: IP 2 jam lalu seharusnya diabaikan"; exit 1; }
echo "PASS: IP 2 jam lalu diabaikan"
[[ "$(WIBU_IP_TTL=60 bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; live_ip_pairs" | grep -c 'roaming.one')" == "0" ]] \
    || { echo "FAIL: WIBU_IP_TTL harus bisa diubah"; exit 1; }
echo "PASS: WIBU_IP_TTL dapat disetel (60s -> IP 5 menit lalu keluar)"

echo "=== TEST 6: penjaga regresi pemasangan ==="
grep -q '_need "sbin/wibu-udpgw"' "$REPO_DIR/setup.sh" || { echo "FAIL: setup.sh tidak mengunduh wibu-udpgw"; exit 1; }
grep -q 'wibu-udpgw install' "$REPO_DIR/setup.sh" || { echo "FAIL: setup.sh tidak menjalankan pemasang udpgw"; exit 1; }
grep -q 'wibu-units' "$REPO_DIR/setup.sh" || { echo "FAIL: setup.sh tidak memakai wibu-units untuk unit baru"; exit 1; }
grep -q 'safe_update "sbin/wibu-udpgw"' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: m-setting tidak memperbarui wibu-udpgw"; exit 1; }
grep -q '\[14\] Pasang / Perbaiki UDP Gateway' "$REPO_DIR/menu/m-ssh.sh" || { echo "FAIL: menu SSH belum punya entri UDPGW"; exit 1; }
grep -q 'Mode Bot (Polling / Webhook)' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: menu mode bot hilang"; exit 1; }
echo "PASS: semua rantai pemasangan/menu terdaftar"

echo "=== TEST 7: wibu-units — unit baru bisa dikirim lewat Update Script ==="
export WIBU_SYSTEMD_DIR="$TMPD/systemd2"
UD="$TMPD/bin-units"; mkdir -p "$UD"
cat > "$UD/systemctl" <<'STUB'
#!/bin/bash
echo "$*" >> "${STUB_LOG:-/dev/null}"
case "$1" in
    is-enabled) echo "enabled"; exit 0 ;;
    *) exit 0 ;;
esac
STUB
chmod +x "$UD/systemctl"
export STUB_LOG="$TMPD/systemctl.log"; : > "$STUB_LOG"

PATH="$UD:$PATH" bash "$REPO_DIR/sbin/wibu-units" sync > "$TMPD/units1.log" 2>&1
U="$WIBU_SYSTEMD_DIR/bot-webhook.service"
[[ -s "$U" ]] || { echo "FAIL: unit bot-webhook tidak ditulis/kosong"; exit 1; }
grep -qF 'ExecStart=/usr/bin/python3 /usr/local/bin/bot-webhook-server' "$U" || { echo "FAIL: ExecStart salah"; exit 1; }
grep -qF 'Restart=always' "$U" || { echo "FAIL: unit harus auto-restart"; exit 1; }
echo "PASS: unit bot-webhook ditulis lengkap (tidak kosong -> tidak lagi 'masked')"
h1=$(sha256sum "$U" | cut -d' ' -f1)
PATH="$UD:$PATH" bash "$REPO_DIR/sbin/wibu-units" sync > "$TMPD/units2.log" 2>&1
h2=$(sha256sum "$U" | cut -d' ' -f1)
[[ "$h1" == "$h2" ]] || { echo "FAIL: unit berubah saat sync diulang"; exit 1; }
grep -q "sudah sesuai" "$TMPD/units2.log" || { echo "FAIL: sync tidak idempoten"; exit 1; }
echo "PASS: sync idempoten"
grep -q "daemon-reload" "$STUB_LOG" || { echo "FAIL: sync tidak memanggil daemon-reload"; exit 1; }
echo "PASS: sync memanggil systemctl daemon-reload"
: > "$U"     # regresi: unit 0 byte (kejadian nyata -> systemd menganggap masked)
PATH="$UD:$PATH" bash "$REPO_DIR/sbin/wibu-units" status 2>&1 | grep -q "KOSONG" \
    || { echo "FAIL: unit kosong tidak terdeteksi"; exit 1; }
echo "PASS: unit 0 byte terdeteksi sebagai masalah (bukan dianggap sehat)"

echo "=== TEST 8: penjaga rantai unit + pass kedua Update Script ==="
grep -q '_need "sbin/wibu-units"' "$REPO_DIR/setup.sh" || { echo "FAIL: setup.sh tidak mengunduh wibu-units"; exit 1; }
grep -q '/usr/local/sbin/wibu-units sync' "$REPO_DIR/setup.sh" || { echo "FAIL: setup.sh tidak menyelaraskan unit"; exit 1; }
grep -q 'bot-webhook.service' "$REPO_DIR/setup.sh" && { echo "FAIL: unit inline masih ada (harus lewat wibu-units)"; exit 1; }
echo "PASS: setup.sh memakai wibu-units (tanpa unit inline)"
grep -q 'wibu-units sync' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: Update Script tidak menyelaraskan unit"; exit 1; }
grep -q '_FILES2' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: Update Script tidak punya pass kedua untuk berkas baru"; exit 1; }
echo "PASS: Update Script menyelaraskan unit + pass kedua berkas baru"

echo "=== TEST 9: paritas daftar modul (anti modul yang tak bisa lewat OTA) ==="
missing=0
while read -r mod; do
    [[ -z "$mod" ]] && continue
    if ! grep -q "safe_update \"${mod}\"" "$REPO_DIR/menu/m-setting.sh"; then
        echo "  FAIL: ${mod} ada di setup.sh tapi TIDAK ada di daftar Update Script"; missing=1
    fi
done < <(grep -oP '_need "\K(sbin/[^"]+)' "$REPO_DIR/setup.sh" | sort -u)
[[ "$missing" -eq 0 ]] || { echo "FAIL: ada modul yang tak akan pernah terpasang lewat OTA"; exit 1; }
echo "PASS: semua modul sbin di setup.sh punya entri safe_update di Update Script"
while read -r mod; do
    [[ -z "$mod" ]] && continue
    # modul boleh diunduh lewat _need ATAU wibu_get_script (dua jalur yang ada di setup.sh)
    if ! grep -qE "(_need|wibu_get_script) \"${mod}\"" "$REPO_DIR/setup.sh"; then
        echo "FAIL: ${mod} ada di Update Script tapi tidak diunduh setup.sh"; exit 1
    fi
done < <(grep -oP 'safe_update "\K(sbin/[^"]+)' "$REPO_DIR/menu/m-setting.sh" | sort -u)
echo "PASS: semua entri safe_update sbin ada padanannya di setup.sh"

echo "=== TEST 10: manifest diambil sekali per putaran update (hemat kuota API) ==="
grep -q 'WIBU_MANIFEST_FILE' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: m-setting tidak memakai manifest bersama"; exit 1; }
grep -q 'cdn.jsdelivr.net/gh/WBVPN/wibutunnel' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: jsDelivr tidak dipakai sebagai cadangan manifest"; exit 1; }
grep -q 'cdn.jsdelivr.net/gh/WBVPN/wibutunnel@${WIBU_REF}/${repo_path}' "$REPO_DIR/menu/m-setting.sh" \
    || { echo "FAIL: jsDelivr tidak dipakai saat hash berkas tidak cocok"; exit 1; }
echo "PASS: jsDelivr dipakai sebagai penyelamat berkas (API kena kuota / CDN raw basi)"
grep -q 'if \[\[ -n "${WIBU_MANIFEST_FILE:-}" && -s "${WIBU_MANIFEST_FILE:-}" \]\]' "$REPO_DIR/menu/m-setting.sh" \
    || { echo "FAIL: safe_update tidak memakai manifest bersama"; exit 1; }
echo "PASS: safe_update memakai manifest bersama + cadangan jsDelivr"

# jalankan potongan pengambilan manifest dengan curl palsu: hitung berapa kali dipanggil
CD="$TMPD/bin-curl"; mkdir -p "$CD"
cat > "$CD/curl" <<'STUB'
#!/bin/bash
COUNT_FILE="${CURL_COUNT:-/dev/null}"
echo x >> "$COUNT_FILE"
MANIFEST_OUT=""
prev=""
for a in "$@"; do
    [[ "$prev" == "-o" ]] && MANIFEST_OUT="$a"
    prev="$a"
done
if [[ -n "$MANIFEST_OUT" ]]; then
    : > "$MANIFEST_OUT"
    i=0
    while [[ $i -lt 12 ]]; do
        printf '%064d  berkas-%02d\n' "$i" "$i" >> "$MANIFEST_OUT"
        i=$((i+1))
    done
fi
exit 0
STUB
chmod +x "$CD/curl"
export CURL_COUNT="$TMPD/curl.count"; : > "$CURL_COUNT"
SNIP="$TMPD/manifest.snip"
python3 - "$REPO_DIR/menu/m-setting.sh" "$SNIP" <<'PY'
import pathlib, sys, re
src = pathlib.Path(sys.argv[1]).read_text()
i = src.index('        # Manifest sekali untuk seluruh putaran')
j = src.index('        safe_update "menu/menu.sh"', i)
snippet = src[i:j]
snippet = snippet.replace('WIBU_MANIFEST_FILE="/etc/wibutunnel/tmp/SHA256SUMS.run.$$"',
                          'WIBU_MANIFEST_FILE="%s/SUMS.run"' % pathlib.Path(sys.argv[2]).parent)
pathlib.Path(sys.argv[2]).write_text('#!/bin/bash\nWIBU_REF=main\n' + snippet + '\necho "MANIFEST=$WIBU_MANIFEST_FILE"\n')
PY
chmod +x "$SNIP"
out=$(PATH="$CD:$PATH" bash "$SNIP" 2>&1 || true)
MF=$(sed -n 's/^MANIFEST=//p' <<< "$out")
[[ -s "$MF" ]] || { echo "FAIL: manifest tidak terbentuk -> $out"; exit 1; }
MF_CNT=$(grep -cE '^[0-9a-f]{64}  ' "$MF" || true)
[[ "$MF_CNT" -ge 10 ]] || { echo "FAIL: isi manifest kurang ($MF_CNT entri)"; exit 1; }
echo "PASS: manifest terkumpul sekali ke berkas bersama ($MF_CNT entri)"
n=$(wc -l < "$CURL_COUNT")
[[ "$n" -le 2 ]] || { echo "FAIL: curl dipanggil $n kali (harus berhenti di sumber pertama yang berhasil)"; exit 1; }
echo "PASS: berhenti di sumber pertama yang berhasil (curl dipanggil $n kali, bukan per berkas)"

echo "=== TEST 11: pass kedua hanya membaca entri asli (bukan teks grep di dalam dirinya) ==="
grep -qF "grep -oP '^\\s*safe_update \"\\K[^\"]+'" "$REPO_DIR/menu/m-setting.sh" \
    || { echo "FAIL: pola pass kedua tidak di-anchor"; exit 1; }
echo "PASS: pola pass kedua di-anchor (^\\s*safe_update)"
FAKE="$TMPD/m-setting.fake"
cat > "$FAKE" <<'MS'
        safe_update "menu/menu.sh"
        safe_update "sbin/wibu-units"
        mapfile -t _FILES2 < <(grep -oP 'safe_update "\K[^"]+' /usr/local/bin/m-setting | sed '/^$/d')
        for _f in "${_FILES2[@]:-}"; do safe_update "$_f" >/dev/null 2>&1 || true; done
MS
parsed=$(grep -oP '^\s*safe_update "\K[^"]+' "$FAKE" | sed '/^$/d' | tr '\n' ' ')
[[ "$parsed" == "menu/menu.sh sbin/wibu-units " ]] || { echo "FAIL: hasil parse -> '$parsed'"; exit 1; }
echo "PASS: hanya entri asli yang terbaca (tanpa nama palsu seperti \K[^\n)"

echo "=== TEST 12: uji live dikirim + protokolnya benar (bingkai + port network order) ==="
[[ -f "$REPO_DIR/tests/test_udpgw_live.sh" ]] || { echo "FAIL: tests/test_udpgw_live.sh tidak ada"; exit 1; }
grep -q 'struct.pack("<H", len(body)) + body' "$REPO_DIR/tests/test_udpgw_live.sh" \
    || { echo "FAIL: bingkai PacketProto hilang dari uji live"; exit 1; }
grep -q 'struct.pack("!H", dst_port)' "$REPO_DIR/tests/test_udpgw_live.sh" \
    || { echo "FAIL: port alamat harus big-endian (network order)"; exit 1; }
grep -q 'PacketProto' "$REPO_DIR/docs/HASIL_UJI_VPS.md" || { echo "FAIL: docs belum menjelaskan bingkai PacketProto"; exit 1; }
echo "PASS: uji live tersedia + dua detail protokol terdokumentasi"
bash "$REPO_DIR/tests/test_udpgw_live.sh" 2>&1 | tail -2 | sed 's/^/  /'

echo "=== TEST 13: penyaring entri ber-variabel pada pass kedua ==="
n_ok=$(grep "_FILES2 < <" "$REPO_DIR/menu/m-setting.sh" | grep -c "grep -v")
n_all=$(grep -c "_FILES2 < <" "$REPO_DIR/menu/m-setting.sh")
[[ "$n_all" -ge 1 && "$n_ok" -eq "$n_all" ]] || { echo "FAIL: baris _FILES2 tanpa penyaring variabel ($n_ok/$n_all)"; exit 1; }
echo "PASS: setiap baris _FILES2 menyaring entri ber-variabel"
grep "_FILES2 < <" "$REPO_DIR/menu/m-setting.sh" | grep -q '\^' || { echo "FAIL: pola tidak di-anchor"; exit 1; }
echo "PASS: pola pass kedua di-anchor (^\\s*safe_update)"

echo "=== TEST 14: ganti token & mode bot aman (kasus webhook lama) ==="
grep -q 'bot_selfheal_polling' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: daemon tanpa self-heal mode"; exit 1; }
grep -q 'bot_selfheal_polling ;;' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: self-heal tidak dipanggil pada 409"; exit 1; }
grep -q 'OLD_TOKEN=' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: ganti token tidak mencatat token lama"; exit 1; }
grep -qF 'bot${OLD_TOKEN}/deleteWebhook' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: webhook token lama tidak dilepas"; exit 1; }
grep -q 'MODE_SEKARANG' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: ganti token tidak menyesuaikan mode"; exit 1; }
echo "PASS: ganti token melepas webhook token lama + menyesuaikan mode (polling/webhook)"

# perilaku: self-heal harus memanggil deleteWebhook HANYA saat mode polling & webhook terpasang
HEAL="$TMPD/heal.sh"
awk '/^bot_selfheal_polling\(\)/,/^}/' "$REPO_DIR/menu/bot-daemon.sh" > "$HEAL"
[[ -s "$HEAL" ]] || { echo "FAIL: fungsi self-heal tidak ditemukan"; exit 1; }
run_heal() {   # $1 = isi berkas mode
    local dir; dir=$(mktemp -d)
    printf '%s' "$1" > "$dir/mode"; : > "$dir/calls"
    BOT_MODE_FILE="$dir/mode" CALLS="$dir/calls" bash -c '
        BOT_MODE_FILE="$BOT_MODE_FILE"
        tg_api() { echo "CALL:$1" >> "$CALLS"; case "$1" in getWebhookInfo) echo "{\"result\":{\"url\":\"https://x/telehook\"}}";; esac; }
        jq() { echo "https://x/telehook"; }
        logger() { :; }
        source "'"$HEAL"'"
        bot_selfheal_polling
    ' >/dev/null 2>&1
    grep -c deleteWebhook "$dir/calls" 2>/dev/null
    rm -rf "$dir"
}
n_polling=$(run_heal polling)
[[ "$n_polling" == "1" ]] || { echo "FAIL: mode polling + webhook terpasang -> harus deleteWebhook (dapat $n_polling)"; exit 1; }
echo "PASS: mode polling + webhook masih terpasang -> deleteWebhook otomatis (bebas 409)"
n_webhook=$(run_heal webhook)
[[ "$n_webhook" == "0" ]] || { echo "FAIL: mode webhook tidak boleh deleteWebhook (dapat $n_webhook)"; exit 1; }
echo "PASS: mode webhook tidak menyentuh webhook sendiri"

echo "=== ALL UDPGW/WEBHOOK TESTS PASSED ==="
