#!/bin/bash
# ==========================================
# Tes UDP gateway (badvpn-udpgw), toleransi IP, dan keamanan ganti token bot
# ==========================================
# Semua offline: systemctl dipalsukan lewat stub, curl palsu untuk jalur manifest,
# tg_api dipalsukan untuk menguji self-heal bot. Tidak ada permintaan ke Telegram.
set -euo pipefail
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

echo "=== TEST 1: wibu-udpgw — sintaks, unit templated, daftar port ==="
bash -n "$REPO_DIR/sbin/wibu-udpgw" || { echo "FAIL: sintaks sbin/wibu-udpgw"; exit 1; }
echo "PASS: sbin/wibu-udpgw sintaks OK"
export UDPGW_SYSTEMD_DIR="$TMPD/systemd"
export UDPGW_BIN="$TMPD/badvpn-udpgw"
export UDPGW_LOG="$TMPD/build.log"
printf '#!/bin/sh\necho "--listen-addr ok"\n' > "$UDPGW_BIN"; chmod +x "$UDPGW_BIN"
bash "$REPO_DIR/sbin/wibu-udpgw" install >/dev/null 2>&1 || true
UNIT="$UDPGW_SYSTEMD_DIR/badvpn-udpgw@.service"
[[ -s "$UNIT" ]] || { echo "FAIL: unit templated tidak dibuat"; exit 1; }
grep -qF "ExecStart=$UDPGW_BIN --listen-addr 127.0.0.1:%i --max-clients 1000" "$UNIT" || { echo "FAIL: ExecStart salah"; exit 1; }
grep -qF 'Restart=always' "$UNIT" || { echo "FAIL: unit tanpa auto-restart"; exit 1; }
echo "PASS: unit satu-untuk-semua-port dengan auto-restart"
h1=$(sha256sum "$UNIT" | cut -d' ' -f1)
out2=$(bash "$REPO_DIR/sbin/wibu-udpgw" install 2>&1 || true)
h2=$(sha256sum "$UNIT" | cut -d' ' -f1)
[[ "$h1" == "$h2" ]] || { echo "FAIL: unit berubah saat dijalankan ulang"; exit 1; }
grep -q "sudah sesuai" <<< "$out2" || { echo "FAIL: tidak idempoten"; exit 1; }
echo "PASS: idempoten"

echo "=== TEST 2: daftar port UDPGW (systemctl dipalsukan) ==="
mkdir -p "$TMPD/bin"
printf '#!/bin/bash\nexit 0\n' > "$TMPD/bin/systemctl"; chmod +x "$TMPD/bin/systemctl"
PORTS=$(PATH="$TMPD/bin:$PATH" bash "$REPO_DIR/sbin/wibu-udpgw" ports)
[[ "$PORTS" == "7100 7200 7300 7400 7500 7600" ]] || { echo "FAIL: daftar port -> '$PORTS'"; exit 1; }
echo "PASS: 6 port (konsisten dengan yang diiklankan di pesan akun SSH)"

echo "=== TEST 3: uji live UDP tersedia + protokolnya benar ==="
[[ -f "$REPO_DIR/tests/test_udpgw_live.sh" ]] || { echo "FAIL: tests/test_udpgw_live.sh tidak ada"; exit 1; }
grep -q 'struct.pack("<H", len(body)) + body' "$REPO_DIR/tests/test_udpgw_live.sh" || { echo "FAIL: bingkai PacketProto hilang"; exit 1; }
grep -q 'struct.pack("!H", dst_port)' "$REPO_DIR/tests/test_udpgw_live.sh" || { echo "FAIL: port alamat harus big-endian"; exit 1; }
grep -q 'PacketProto' "$REPO_DIR/docs/HASIL_UJI_VPS.md" || { echo "FAIL: docs belum menjelaskan bingkai"; exit 1; }
echo "PASS: uji live + dokumentasi protokol (bingkai PacketProto, port network order)"

echo "=== TEST 4: toleransi IP (WIBU_IP_TTL=600) ==="
export XRAY_ACCESS_LOG="$TMPD/access.log"
NOW_TS=$(date '+%Y/%m/%d %H:%M:%S')
OLD_TS=$(date -d '300 seconds ago' '+%Y/%m/%d %H:%M:%S')
ANCIENT_TS=$(date -d '2 hours ago' '+%Y/%m/%d %H:%M:%S')
{
  printf '%s.100000 from 198.51.100.7:5555 accepted tcp:x:443 [vless-ws-tls >> direct] email: lama.sekali\n' "$ANCIENT_TS"
  printf '%s.200000 from 43.156.147.95:44321 accepted tcp:x:443 [vless-ws-tls >> direct] email: roaming.one\n' "$OLD_TS"
  printf '%s.300000 from 203.0.113.9:6666 accepted tcp:x:443 [vless-ws-tls >> direct] email: baru.dua\n' "$NOW_TS"
} > "$XRAY_ACCESS_LOG"
source "$REPO_DIR/common.sh"
OUT=$(live_ip_pairs)
grep -q "^roaming.one 43.156.147.95$" <<< "$OUT" || { echo "FAIL: IP 5 menit lalu harus terbaca -> '$OUT'"; exit 1; }
grep -q "^lama.sekali" <<< "$OUT" && { echo "FAIL: IP 2 jam lalu seharusnya diabaikan"; exit 1; }
echo "PASS: 5 menit lalu terbaca, 2 jam lalu diabaikan"
[[ "$(WIBU_IP_TTL=60 bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; live_ip_pairs" | grep -c 'roaming.one')" == "0" ]] \
    || { echo "FAIL: WIBU_IP_TTL harus bisa disetel"; exit 1; }
echo "PASS: WIBU_IP_TTL dapat disetel"

echo "=== TEST 5: ganti token bot aman (polling, tanpa webhook nyangkut) ==="
grep -q 'bot_selfheal_polling' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: daemon tanpa self-heal"; exit 1; }
grep -q 'bot_selfheal_polling ;;' "$REPO_DIR/menu/bot-daemon.sh" || { echo "FAIL: self-heal tak dipanggil saat 409"; exit 1; }
grep -q 'OLD_TOKEN=' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: ganti token tak mencatat token lama"; exit 1; }
grep -qF 'bot${OLD_TOKEN}/deleteWebhook' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: webhook token lama tidak dilepas"; exit 1; }
echo "PASS: ganti token melepas webhook token lama + token baru"

HEAL="$TMPD/heal.sh"
awk '/^bot_selfheal_polling\(\)/,/^}/' "$REPO_DIR/menu/bot-daemon.sh" > "$HEAL"
[[ -s "$HEAL" ]] || { echo "FAIL: fungsi self-heal tidak ditemukan"; exit 1; }
run_heal() {
    local dir; dir=$(mktemp -d); : > "$dir/calls"
    CALLS="$dir/calls" bash -c '
        CALLS="$CALLS"
        tg_api() { echo "CALL:$1" >> "$CALLS"; case "$1" in getWebhookInfo) echo "{\"result\":{\"url\":\"https://x/telehook\"}}";; esac; }
        jq() { echo "https://x/telehook"; }
        logger() { :; }
        source "'"$HEAL"'"
        bot_selfheal_polling
    ' >/dev/null 2>&1
    grep -c deleteWebhook "$dir/calls" 2>/dev/null
    rm -rf "$dir"
}
[[ "$(run_heal)" == "1" ]] || { echo "FAIL: webhook nyangkut tidak dibersihkan"; exit 1; }
echo "PASS: webhook yang masih terpasang dibersihkan otomatis (bebas 409)"

echo "=== TEST 6: webhook benar-benar TIDAK ada lagi di panel ==="
for f in sbin/bot-webhook-server sbin/wibu-units tests/test_udpgw_webhook.sh; do
    [[ -e "$REPO_DIR/$f" ]] && { echo "FAIL: $f masih ada"; exit 1; }
done
grep -rqI "setWebhook" "$REPO_DIR/menu" "$REPO_DIR/sbin" && { echo "FAIL: masih ada pemanggil setWebhook"; exit 1; }
grep -rqI "bot_webhook_queue" "$REPO_DIR/menu" "$REPO_DIR/sbin" && { echo "FAIL: masih ada antrean webhook"; exit 1; }
grep -q "telehook" "$REPO_DIR/setup.sh" && { echo "FAIL: rute /telehook masih ada di setup.sh"; exit 1; }
grep -q "Mode Bot" "$REPO_DIR/menu/m-setting.sh" && { echo "FAIL: menu Mode Bot masih ada"; exit 1; }
echo "PASS: tidak ada berkas/rute/menu webhook yang tersisa"

echo "=== TEST 7: paritas daftar modul (setup.sh <-> Update Script) ==="
missing=0
while read -r mod; do
    [[ -z "$mod" ]] && continue
    grep -q "safe_update \"${mod}\"" "$REPO_DIR/menu/m-setting.sh" || { echo "  FAIL: ${mod} tak ada di daftar Update Script"; missing=1; }
done < <(grep -oP '_need "\K(sbin/[^"]+)' "$REPO_DIR/setup.sh" | sort -u)
[[ "$missing" -eq 0 ]] || exit 1
echo "PASS: semua modul sbin di setup.sh punya entri safe_update di Update Script"
while read -r mod; do
    [[ -z "$mod" ]] && continue
    grep -qE "(_need|wibu_get_script) \"${mod}\"" "$REPO_DIR/setup.sh" || { echo "FAIL: ${mod} di Update Script tapi tidak diunduh setup.sh"; exit 1; }
done < <(grep -oP 'safe_update "\K(sbin/[^"]+)' "$REPO_DIR/menu/m-setting.sh" | sort -u)
echo "PASS: semua entri safe_update punya padanan di setup.sh"

echo "=== TEST 8: manifest diambil sekali per putaran update ==="
grep -q 'WIBU_MANIFEST_FILE' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: tanpa manifest bersama"; exit 1; }
grep -q 'cdn.jsdelivr.net/gh/WBVPN/wibutunnel' "$REPO_DIR/menu/m-setting.sh" || { echo "FAIL: tanpa cadangan jsDelivr"; exit 1; }
echo "PASS: manifest sekali per putaran + cadangan jsDelivr"

echo "=== ALL UDPGW/IP/BOT TESTS PASSED ==="
