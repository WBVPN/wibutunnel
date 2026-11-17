#!/bin/bash
# ==========================================
# UJI: penegakan kuota SSH jalur cepat (v4.1.37)
#
# Masalah yang diuji: penegakan kuota hanya berjalan di siklus algojo-kuota
# (60 detik). Pelanggan yang melewati limit masih bisa menarik data sampai
# ~60 detik sebelum terkunci (terukur: 11 MB/s -> +-600 MB).
#
# Yang diuji di sini TANPA menyentuh sistem nyata:
#   1. kuota_scan_ssh() mengunci user yang sudah melewati limit  (1 panggilan)
#   2. user di bawah limit TIDAK dikunci
#   3. idempoten: panggilan kedua tidak mengunci/notif ulang
#   4. lock bersih: berkas lock tidak ditinggalkan dalam keadaan terkunci
#   5. limit 0 (=tanpa limit) dilewati, bukan dikunci
#   6. baris rusak di DB tidak membuat skrip berhenti
#
# semua efek samping (passwd -l, pkill, curl) diganti stub -> nol sentuhan sistem.
# ==========================================
set -u
export PYTHONDONTWRITEBYTECODE=1

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/uji-latensi.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

echo "=== UJI LATENSI PENEGAKAN KUOTA SSH ==="
echo

# --- 1. fungsi harus ADA (ini yang bikin uji MERAH sebelum patch) ---
source "$REPO/common.sh" >/dev/null 2>&1 || { bad "common.sh gagal di-source"; echo "RINGKAS: $PASS hijau / $FAIL merah"; exit 1; }

if declare -F kuota_scan_ssh >/dev/null 2>&1; then
    ok "kuota_scan_ssh() tersedia di common.sh"
else
    bad "kuota_scan_ssh() TIDAK ADA di common.sh — jalur cepat belum diimplementasikan"
    echo
    echo "RINGKAS: $PASS hijau / $FAIL merah"
    exit 1
fi

# --- panggung uji ---
DB_BW="$TMP/limit_bw.db"; DB_USAGE="$TMP/user_usage.db"; DB_LOCK="$TMP/locked_users.db"
: > "$DB_LOCK"
cat > "$DB_BW" <<'EOF'
over:1
under:1
nolimit:0
rusak:
tepat:1
kurang:1
EOF
# CR sungguhan (bukan teks "\r"): DB yang pernah disunting di Windows
printf 'crlf:1\r\n' >> "$DB_BW"
printf 'root:1\n' >> "$DB_BW"
# 'tepat' = persis 1 GiB (harus terkunci), 'kurang' = 1 GiB - 1 byte (tidak boleh).
# Dua baris ini yang menahan mutasi >= menjadi > dan salah ketik konstanta 1 GiB.
cat > "$DB_USAGE" <<'EOF'
over:2147483648:2147483648
under:107374182:107374182
nolimit:2147483648:2147483648
tepat:1073741824:1073741824
kurang:1073741823:1073741823
EOF
printf 'crlf:2147483648:2147483648\r\n' >> "$DB_USAGE"
printf 'root:2147483648:2147483648\n' >> "$DB_USAGE"

# stub: tidak menyentuh user nyata, hanya mencatat panggilan
STUB="$TMP/stub.log"; : > "$STUB"
ssh_user_exists() { case "$1" in over|under|nolimit|tepat|kurang|crlf|root|lambat) return 0;; *) return 1;; esac; }
id() { case "$2" in root) echo 0;; crlf) echo 1001;; *) echo 1002;; esac; }
lock_ssh_user() {
    echo "lock:$1:$2" >> "$STUB"
    printf '%s:1:0:%s\n' "$1" "${2:-MANUAL}" >> "${KUOTA_DB_LOCK:-/etc/wibutunnel/locked_users.db}"
    return 0
}
kuota_send_message() { echo "notif" >> "$STUB"; sleep "${STUB_NOTIF_SLEEP:-0}"; return 0; }

export KUOTA_DB_BW="$DB_BW" KUOTA_DB_USAGE="$DB_USAGE" KUOTA_DB_LOCK="$DB_LOCK" KUOTA_LOCK="$TMP/scan.lock"
USAGE_DB="$DB_USAGE"

# --- 2. satu panggilan harus mengunci 'over' saja ---
echo
echo "--- uji 1: satu panggilan ---"
( kuota_scan_ssh ) 2>/dev/null
if grep -q "^lock:over:QUOTA_EXCEEDED$" "$STUB"; then ok "user melewati limit dikunci pada panggilan pertama"; else bad "user melewati limit TIDAK dikunci"; fi
if grep -q "^lock:under" "$STUB"; then bad "user di bawah limit ikut dikunci"; else ok "user di bawah limit tidak dikunci"; fi
if grep -q "^lock:nolimit" "$STUB"; then bad "limit 0 (tanpa limit) ikut dikunci"; else ok "limit 0 dilewati"; fi
if grep -q "^lock:tepat:QUOTA_EXCEEDED$" "$STUB"; then ok "pemakaian PERSIS di limit (1 GiB) dikunci"; else bad "pemakaian persis di limit TIDAK dikunci (batas >= salah)"; fi
if grep -q "^lock:kurang" "$STUB"; then bad "1 byte di bawah limit ikut dikunci (off-by-one)"; else ok "1 byte di bawah limit tidak dikunci"; fi
if grep -qx "lock:crlf:QUOTA_EXCEEDED" "$STUB"; then ok "baris ber-CRLF tetap terbaca & dikunci"; else bad "baris ber-CRLF dilewati (DB Windows ikut tak tertegakkan)"; fi
if grep -qx "lock:root:QUOTA_EXCEEDED" "$STUB"; then bad "akun SISTEM (uid 0) dikunci -> bisa mematikan panel"; else ok "akun sistem (uid<1000) tidak dikunci"; fi
# notifikasi dikirim di subshell background (tidak memblokir pemindaian) -> tunggu singkat
for _ in $(seq 1 20); do grep -q '^notif$' "$STUB" && break; sleep 0.1; done
if [[ "$(grep -c '^notif$' "$STUB")" -ge 1 ]]; then ok "notifikasi terkirim untuk penguncian"; else bad "notifikasi tidak terkirim"; fi

# --- 3. idempoten: panggilan kedua tidak mengunci ulang ---
echo
echo "--- uji 2: idempoten (panggilan kedua) ---"
BEFORE=$(grep -c '^lock:' "$STUB")
NOTIF_BEFORE=$(grep -c '^notif$' "$STUB")
( kuota_scan_ssh ) 2>/dev/null
( kuota_scan_ssh ) 2>/dev/null
AFTER=$(grep -c '^lock:' "$STUB")
if [[ "$BEFORE" -eq "$AFTER" ]]; then ok "panggilan berikutnya tidak mengunci ulang ($BEFORE panggilan lock)"; else bad "kunci ganda: $BEFORE -> $AFTER"; fi
NOTIF=$(grep -c '^notif$' "$STUB")
if [[ "$NOTIF" -eq "$NOTIF_BEFORE" ]]; then ok "notifikasi tidak terkirim berulang (tetap $NOTIF, satu per user terkunci)"; else bad "notifikasi berulang: $NOTIF_BEFORE -> $NOTIF"; fi

# --- 4. berkas lock tidak ditinggalkan terkunci ---
echo
echo "--- uji 3: kebersihan lock ---"
if ( flock -n "$KUOTA_LOCK" true ) 2>/dev/null; then ok "berkas lock bebas setelah pemindaian"; else bad "berkas lock masih dipegang (deadlock berikutnya)"; fi

# --- 5. DB rusak / tidak ada tidak membuat exit non-nol ---
echo
echo "--- uji 4: ketahanan masukan rusak ---"
export KUOTA_DB_BW="$TMP/tidak-ada.db"
( kuota_scan_ssh ) 2>/dev/null; RC=$?
if [[ "$RC" -eq 0 ]]; then ok "DB limit tidak ada -> keluar 0 (tidak error)"; else bad "DB limit tidak ada -> rc=$RC"; fi


# --- 5. konkurensi: 8 pemindaian paralel tidak boleh mengunci ganda ---
echo
echo "--- uji 5: konkurensi (8 paralel) ---"
: > "$STUB"
: > "$DB_LOCK"
export KUOTA_DB_BW="$DB_BW" KUOTA_DB_USAGE="$DB_USAGE" KUOTA_DB_LOCK="$DB_LOCK" KUOTA_LOCK="$TMP/scan2.lock"
# beri jeda di dalam penguncian supaya jendela balapan benar-benar terbuka
lock_ssh_user() {
    echo "lock:$1:$2" >> "$STUB"
    sleep 0.3
    printf '%s:1:0:%s\n' "$1" "${2:-MANUAL}" >> "${KUOTA_DB_LOCK:-/etc/wibutunnel/locked_users.db}"
    return 0
}
for _i in $(seq 1 8); do ( kuota_scan_ssh ) 2>/dev/null & done
wait
for _ in $(seq 1 20); do [[ "$(grep -c '^lock:' "$STUB")" -ge 1 ]] && break; sleep 0.1; done
sleep 0.5
NKUNCI=$(grep -c '^lock:' "$STUB")
# fixture saat ini punya 3 akun yang memang melewati limit: over, tepat, crlf
# (root dikecualikan karena akun sistem)
if [[ "$NKUNCI" -eq 3 ]]; then
    ok "8 pemindaian paralel -> tepat 3 penguncian, tanpa ganda"
else
    bad "8 pemindaian paralel -> $NKUNCI penguncian (harus 3; flock/guard tidak bekerja)"
fi


# --- 6. flock tidak boleh dipegang oleh notifikasi background ---
echo
echo "--- uji 6: lock dilepas walau notifikasi masih jalan ---"
: > "$STUB"; : > "$DB_LOCK"
cat > "$DB_BW" <<'EOF2'
lambat:1
EOF2
cat > "$DB_USAGE" <<'EOF2'
lambat:2147483648:2147483648
EOF2
export STUB_NOTIF_SLEEP=3
( kuota_scan_ssh ) 2>/dev/null
if ( flock -n "$KUOTA_LOCK" true ) 2>/dev/null; then
    ok "lock langsung bebas walau notifikasi (3 dtk) masih berjalan"
else
    bad "lock masih dipegang notifikasi background -> pemindaian berikutnya dilewati"
fi
unset STUB_NOTIF_SLEEP

echo
echo "RINGKAS: $PASS hijau / $FAIL merah"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
