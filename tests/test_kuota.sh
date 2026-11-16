#!/bin/bash
# ==========================================
# Tes akurasi AKUNTANSI KUOTA (SSH byte kernel + xray stats)
# ==========================================
# Semua tes di sini offline: tidak butuh iptables/xray, karena bagian yang diuji
# adalah PARSING + ARITMETIKA DELTA (yang paling mudah salah dan paling mahal
# kalau salah: kuota pelanggan).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

export ACCT_DB="$TMPD/user_acct.db"
export USAGE_DB="$TMPD/user_usage.db"
: > "$ACCT_DB"; : > "$USAGE_DB"
source "$REPO_DIR/common.sh"
acct_init

echo "=== TEST 1: byte per sesi dari kernel (ss -tie) ==="
cat > "$TMPD/ss.txt" <<'SS'
ESTAB      0      0            127.0.0.1:109       127.0.0.1:50506 users:(("dropbear",pid=282081,fd=0))
	 skmem:(r0,rb3145728,t0,tb3145728,f2680,w0,o0,bl0,d0)
	 ts sack cubic wscale:7,7 rto:204 mss:32768 cwnd:10 bytes_sent:1234 bytes_acked:1235 bytes_received:4321 segs_out:12 segs_in:11 data_segs_out:3
ESTAB      0      0            43.156.147.95:22      222.210.35.197:48282 users:(("sshd",pid=284251,fd=3))
	 ts sack cubic bytes_sent:99 bytes_received:100
ESTAB      0      0            127.0.0.1:10015     127.0.0.1:20384 users:(("python3",pid=999,fd=5))
	 ts sack bytes_sent:7 bytes_received:7
SS
OUT=$(ssh_sessions_bytes "$TMPD/ss.txt")
grep -q "^109 282081 5555$" <<< "$OUT" || { echo "FAIL: sesi dropbear -> '$OUT'"; exit 1; }
echo "PASS: sesi dropbear: 1234+4321 = 5555 byte (dua arah dijumlah)"
grep -q "^22 284251 199$" <<< "$OUT" || { echo "FAIL: sesi sshd -> '$OUT'"; exit 1; }
echo "PASS: sesi sshd (port 22) ikut terbaca"
grep -q "^10015 999 " <<< "$OUT" && { echo "FAIL: proses non-SSH ikut terhitung"; exit 1; }
echo "PASS: soket non-SSH (python3/ws-stunnel) tidak dihitung (bukan sesi pelanggan)"

echo "=== TEST 2: akumulasi delta (berulang + soket baru) ==="
acct_apply_one "282081.109" andi 5555
[[ "$(usage_of andi)" == "5555" ]] || { echo "FAIL: awal -> $(usage_of andi)"; exit 1; }
echo "PASS: pembacaan pertama masuk seluruhnya"
acct_apply_one "282081.109" andi 5555
[[ "$(usage_of andi)" == "5555" ]] || { echo "FAIL: pembacaan ulang harus idempoten"; exit 1; }
echo "PASS: pembacaan ulang tanpa trafik baru tidak menambah (idempoten)"
acct_apply_one "282081.109" andi 9000
[[ "$(usage_of andi)" == "9000" ]] || { echo "FAIL: delta -> $(usage_of andi)"; exit 1; }
echo "PASS: hanya delta yang ditambahkan (3445)"
acct_apply_one "282081.109" andi 100
[[ "$(usage_of andi)" == "9100" ]] || { echo "FAIL: reset soket -> $(usage_of andi)"; exit 1; }
echo "PASS: counter yang turun (soket/PID baru) dihitung dari nol, bukan negatif"

echo "=== TEST 3: parsing statistik xray (hanya per-user, unggah+unduh) ==="
# Aritmetika diuji tanpa jq (xray_quota_awk); parsing JSON penuh hanya bila jq ada.
OUT=$(printf '%s\n' 'user>>>roodyz.prem>>>traffic>>>uplink 100' 'user>>>roodyz.prem>>>traffic>>>downlink 250' 'inbound>>>vless-ws-tls>>>traffic>>>downlink 999999' 'user>>>budi>>>traffic>>>uplink 7' | xray_quota_awk)
grep -q "^roodyz.prem 350$" <<< "$OUT" || { echo "FAIL: jumlah unggah+unduh -> '$OUT'"; exit 1; }
grep -q "^vless-ws-tls" <<< "$OUT" && { echo "FAIL: statistik inbound ikut terbaca"; exit 1; }
grep -q "^budi 7$" <<< "$OUT" || { echo "FAIL: baris user tanpa downlink -> '$OUT'"; exit 1; }
echo "PASS: unggah+unduh dijumlah, statistik inbound diabaikan, stat tanpa nilai = 0"

if command -v jq >/dev/null 2>&1; then
cat > "$TMPD/stats.json" <<'JSON'
{ "stat": [
  { "name": "inbound>>>vless-ws-tls>>>traffic>>>downlink", "value": 999999 },
  { "name": "user>>>roodyz.prem>>>traffic>>>uplink", "value": 100 },
  { "name": "user>>>roodyz.prem>>>traffic>>>downlink", "value": 250 },
  { "name": "user>>>budi>>>traffic>>>uplink", "value": 7 },
  { "name": "user>>>budi>>>traffic>>>downlink" }
] }
JSON
OUT=$(xray_quota_parse < "$TMPD/stats.json")
grep -q "^roodyz.prem 350$" <<< "$OUT" || { echo "FAIL: xray parse -> '$OUT'"; exit 1; }
echo "PASS: user ber-titik, unggah+unduh dijumlah (100+250=350)"
grep -q "^vless-ws-tls" <<< "$OUT" && { echo "FAIL: statistik inbound ikut terbaca"; exit 1; }
echo "PASS: statistik per-inbound tidak ikut (bukan pelanggan)"
grep -q "^budi 7$" <<< "$OUT" || { echo "FAIL: stat tanpa nilai -> '$OUT'"; exit 1; }
echo "PASS: stat tanpa nilai dianggap 0 (budi = 7 dari uplink)"

else
    echo "SKIP: pengujian JSON penuh (jq tidak terpasang di mesin ini)"
fi

echo "=== TEST 4: reset pemakaian (renew / restore) ==="
db_set "$USAGE_DB" andi "9100:0"
db_set "$ACCT_DB" "282081.109" "100"
usage_reset andi
[[ "$(usage_of andi)" == "0" ]] || { echo "FAIL: usage_reset tidak mengosongkan"; exit 1; }
[[ "$(db_get '282081.109' "$ACCT_DB")" == "100" ]] || { echo "FAIL: ledger soket harus DIPERTAHANKAN saat renew"; exit 1; }
echo "PASS: total dipakai dikosongkan, ledger soket dipertahankan (soket hidup tidak dihitung ulang)"

echo "=== TEST 5: penjaga regresi (rantai wajib ada) ==="
grep -q 'usage_reset "$user"' "$REPO_DIR/common.sh" || { echo "FAIL: renew_ssh_user tidak mereset kuota"; exit 1; }
echo "PASS: renew_ssh_user memanggil usage_reset (akun diperpanjang tidak langsung terkunci)"
grep -q 'usage_apply_ssh' "$REPO_DIR/sbin/algojo-kuota" || { echo "FAIL: algojo-kuota tidak memakai akuntansi SSH"; exit 1; }
echo "PASS: algojo-kuota memakai akuntansi byte kernel untuk SSH"
grep -q 'lock_ssh_user "\(.*\)QUOTA_EXCEEDED' "$REPO_DIR/sbin/algojo-kuota" || { echo "FAIL: kuota SSH tidak bisa mengunci akun"; exit 1; }
echo "PASS: kuota habis pada akun SSH benar-benar mengunci (passwd -l)"

echo "=== ALL KUOTA TESTS PASSED ==="
