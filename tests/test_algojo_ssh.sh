#!/bin/bash
# ==========================================
# Test Suite: algojo-ssh Unit & Integration Tests
# ==========================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/common.sh" 2>/dev/null || source /usr/local/bin/common.sh

echo "=== TEST 1: Unit parse ss line logic ==="
parse_test() {
    local line="$1"
    [[ "$line" =~ ^State|^Recv-Q ]] && return 1
    local_addr=$(echo "$line" | awk '{print $3}')
    local_port=${local_addr##*:}
    [[ ! "$local_port" =~ ^(22|109|143|2222)$ ]] && return 1
    process=$(echo "$line" | awk '{print $5}')
    pid=$(echo "$process" | grep -oP 'pid=\K[0-9]+' | tail -1)
    [[ -z "$pid" ]] && return 1
    printf '%s' "$pid"
}

# Line 1: dropbear relay
p1=$(parse_test '0 0 127.0.0.1:109 127.0.0.1:40001 users:(("dropbear",pid=1234,fd=4))')
[[ "$p1" == "1234" ]] || { echo "FAIL: dropbear 109 relay PID mismatch (got: '$p1')"; exit 1; }

# Line 2: dropbear 143 direct
p2=$(parse_test '0 0 103.10.1.50:143 45.22.33.44:52340 users:(("dropbear",pid=5678,fd=3))')
[[ "$p2" == "5678" ]] || { echo "FAIL: dropbear 143 direct PID mismatch"; exit 1; }

# Line 3: sshd 22 direct
p3=$(parse_test '0 0 103.10.1.50:22 45.22.33.44:52340 users:(("sshd",pid=9012,fd=3))')
[[ "$p3" == "9012" ]] || { echo "FAIL: sshd 22 direct PID mismatch"; exit 1; }

# Line 4: Non-ssh port (e.g. 443) -> must be rejected
p4=$(parse_test '0 0 103.10.1.50:443 45.22.33.45:52341 users:(("xray",pid=9999,fd=5))' || true)
[[ -z "$p4" ]] || { echo "FAIL: non-ssh port was not rejected"; exit 1; }

echo "PASS: Unit ss parsing"

echo "=== TEST 2: Integration lock and timed format test ==="
TMP_DIR=$(mktemp -d /tmp/test-algojo-ssh-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_EXP="$TMP_DIR/ssh_exp.conf"
TEST_LIMIT="$TMP_DIR/limit_ip.db"
TEST_LOCK="$TMP_DIR/locked_users.db"

cat <<EOF > "$TEST_EXP"
user1:2026-12-31 23:59:59
user2:2026-12-31 23:59:59
EOF

cat <<EOF > "$TEST_LIMIT"
user1:02
user2:08
EOF

touch "$TEST_LOCK"

# Run a simulated evaluation loop matching algojo-ssh
test_lock_runner() {
    declare -A sessions
    sessions["user1"]=3  # 3 > 02 (tests octal 02)
    sessions["user2"]=9  # 9 > 08 (tests octal 08)

    local LOCK_DURATION=15
    for user in "${!sessions[@]}"; do
        max_sess=$(grep "^${user}:" "$TEST_LIMIT" | cut -d: -f2)
        sess_count=${sessions[$user]}

        if (( 10#$sess_count > 10#$max_sess )); then
            now=$(date -u +%s)
            unlock_time=$((now + (LOCK_DURATION * 60)))
            echo "${user}:${now}:${unlock_time}:SSH_IP_LIMIT" >> "$TEST_LOCK"
        fi
    done
}

test_lock_runner

# Verify user1 locked
grep -q "^user1:" "$TEST_LOCK" || { echo "FAIL: user1 not locked"; exit 1; }
u1_unlock=$(grep "^user1:" "$TEST_LOCK" | cut -d: -f3)
now_ts=$(date -u +%s)
[[ "$u1_unlock" -gt "$now_ts" ]] || { echo "FAIL: user1 unlock time is not timed in the future (got: $u1_unlock)"; exit 1; }

# Verify user2 locked (10# octal guard)
grep -q "^user2:" "$TEST_LOCK" || { echo "FAIL: user2 not locked (octal bug)"; exit 1; }
u2_unlock=$(grep "^user2:" "$TEST_LOCK" | cut -d: -f3)
[[ "$u2_unlock" -gt "$now_ts" ]] || { echo "FAIL: user2 unlock time is not timed in the future"; exit 1; }

echo "PASS: Integration lock and timed auto-unlock format"

echo "=== TEST 3: Cek Login m-ssh menu session count ==="
# Test ssh_session_count returns integer >= 0
cnt=$(ssh_session_count "root")
[[ "$cnt" =~ ^[0-9]+$ ]] || { echo "FAIL: ssh_session_count not integer (got: $cnt)"; exit 1; }
echo "PASS: ssh_session_count valid output"

echo "=== TEST 4: parsing baris ss + atribusi user sesi (bug pemilik-socket) ==="
L1='0      0      103.150.60.84:109     43.156.147.95:57024 users:(("dropbear",pid=243623,fd=0))'
P=$(ssh_parse_line "$L1" | cut -f1); D=$(ssh_parse_line "$L1" | cut -f2); I=$(ssh_parse_line "$L1" | cut -f3)
[[ "$P" == "109" && "$D" == "243623" && "$I" == "43.156.147.95" ]] || { echo "FAIL: ssh_parse_line (port=$P pid=$D ip=$I)"; exit 1; }
echo "PASS: ssh_parse_line port/pid/ip"

L2='0 0 127.0.0.1:2222 127.0.0.1:1234 users:(("dropbear",pid=111,fd=6),("dropbear",pid=222,fd=7))'
[[ "$(ssh_parse_line "$L2" | cut -f2)" == "222" ]] || { echo "FAIL: pid terakhir (sesi klien) tak diambil"; exit 1; }
echo "PASS: pid terakhir (sesi klien) diambil"

for ok in 22 109 143 2222; do
    [[ "$ok" =~ $SSH_SESSION_PORTS ]] || { echo "FAIL: port $ok tak dianggap sesi SSH"; exit 1; }
done
for no in 443 8080 38497; do
    [[ ! "$no" =~ $SSH_SESSION_PORTS ]] || { echo "FAIL: port $no dianggap sesi SSH"; exit 1; }
done
echo "PASS: filter port sesi SSH (22/109/143/2222)"

# Penjaga regresi: user sesi dicari lewat KETURUNAN proses, bukan pemilik socket
grep -q "ssh_pid_session_user" "$REPO_DIR/common.sh" || { echo "FAIL: helper keturunan hilang dari common.sh"; exit 1; }
grep -q "ssh_sessions_snapshot" "$REPO_DIR/sbin/algojo-ssh" || { echo "FAIL: algojo-ssh tak memakai snapshot"; exit 1; }
grep -q 'ps -o user= -p "\$pid"' "$REPO_DIR/sbin/algojo-ssh" && { echo "FAIL: algojo-ssh kembali ke atribusi pemilik socket"; exit 1; }
echo "PASS: atribusi sesi lewat keturunan (bug pemilik-socket tidak kembali)"

echo "=== TEST 5: pemetaan IP klien jalur WS (443) ==="
LOGF=$(mktemp)
NOW=$(date +%s)
# catatan harus SEGAR (ada TTL): port -> IP -> epoch
printf '%s 203.0.113.9 %s\n%s 198.51.100.7 %s\n' 40412 "$NOW" 40413 "$NOW" > "$LOGF"
IP=$(WS_IP_LOG="$LOGF" bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; ws_client_ip_of_port 40412" || true)
[[ "$IP" == "203.0.113.9" ]] || { echo "FAIL: ws_client_ip_of_port (dapat '$IP')"; exit 1; }
echo "PASS: ws_client_ip_of_port membaca catatan IP ws-stunnel"

# catatan BASI (lebih tua dari TTL) harus diabaikan -> port bisa dipakai ulang
printf '%s 203.0.113.9 %s\n' 40414 "$((NOW - 7200))" > "$LOGF"
if WS_IP_LOG="$LOGF" bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; ws_client_ip_of_port 40414"; then
    echo "FAIL: catatan basi (lewat TTL) seharusnya diabaikan"; exit 1
fi
echo "PASS: catatan basi diabaikan (port dipakai ulang tak salah IP)"

printf '%s 203.0.113.9 %s\n' 40415 "$NOW" > "$LOGF"
if WS_IP_LOG="$LOGF" bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; ws_client_ip_of_port 99999"; then
    echo "FAIL: port tanpa catatan seharusnya gagal (fallback via-WS)"; exit 1
fi
echo "PASS: port tanpa catatan -> gagal (jujur 'via-WS', bukan IP karangan)"
rm -f "$LOGF"

python3 - "$REPO_DIR" <<'PY' || exit 1
import importlib.util, importlib.machinery, sys
sys.dont_write_bytecode = True          # jangan tinggalkan sbin/__pycache__
repo = sys.argv[1]
loader = importlib.machinery.SourceFileLoader('ws', f'{repo}/sbin/ws-stunnel')
spec = importlib.util.spec_from_loader('ws', loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)
ok = m.client_ip_from(b'GET / HTTP/1.1\r\nCF-Connecting-IP: 203.0.113.9\r\n\r\n', '10.0.0.1') == '203.0.113.9'
ok = ok and m.client_ip_from(b'GET / HTTP/1.1\r\nX-Forwarded-For: 198.51.100.7, 10.1.1.1\r\n\r\n', '10.0.0.1') == '198.51.100.7'
ok = ok and m.client_ip_from(b'GET / HTTP/1.1\r\nHost: x\r\n\r\n', '10.0.0.1') == '10.0.0.1'
print("PASS: ws-stunnel memilih IP klien dari header (CF-Connecting-IP > XFF > peer)" if ok else "FAIL: parser header ws-stunnel")
sys.exit(0 if ok else 1)
PY

echo "=== TEST 6: deteksi user xray (live_ip_pairs) ==="
XLOG=$(mktemp)
NOWTS=$(date +'%Y/%m/%d %H:%M:%S')
{
    printf '%s.100000 from 43.156.147.95:44321 accepted tcp:api.ipify.org:443 [vless-ws-tls >> direct] email: roodyz.prem\n' "$NOWTS"
    printf '%s.200000 from 43.156.147.95:44322 accepted tcp:www.google.com:443 [vless-ws-tls >> direct] email: roodyz.prem\n' "$NOWTS"
    printf '%s.300000 from 127.0.0.1:44323 accepted tcp:x:443 [vless-ws-tls >> direct] email: dia\n' "$NOWTS"
    printf '%s.400000 from 198.51.100.7:5555 accepted tcp:x:443 [vless-ws-ntls >> direct] email: api\n' "$NOWTS"
} > "$XLOG"
OUT=$(XRAY_ACCESS_LOG="$XLOG" bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; live_ip_pairs" || true)
grep -q "^roodyz.prem 43.156.147.95$" <<< "$OUT" || { echo "FAIL: user ber-titik/IP asli tak terbaca -> '$OUT'"; exit 1; }
echo "PASS: user ber-titik (.prem) + IP asli terbaca, duplikat IP disatukan"
grep -q "^dia " <<< "$OUT" && { echo "FAIL: baris 127.0.0.1 seharusnya dibuang"; exit 1; }
echo "PASS: 127.0.0.1 dibuang (bukan IP pelanggan, jangan dikira online)"
grep -q "^api " <<< "$OUT" && { echo "FAIL: email 'api' seharusnya dibuang"; exit 1; }
echo "PASS: email sistem (api/dummy) dibuang"

OLDTS=$(date -d '30 minutes ago' +'%Y/%m/%d %H:%M:%S')
printf '%s.100000 from 203.0.113.9:1 accepted tcp:x:443 [vless-ws-tls >> direct] email: lama.sekali\n' "$OLDTS" > "$XLOG"
OUT=$(XRAY_ACCESS_LOG="$XLOG" bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; live_ip_pairs" || true)
[[ -z "$OUT" ]] || { echo "FAIL: baris di luar jendela waktu harus diabaikan -> '$OUT'"; exit 1; }
echo "PASS: baris di luar jendela waktu diabaikan (user lama tak dikira online)"
rm -f "$XLOG"

python3 - "$REPO_DIR" <<'PY' || exit 1
import importlib.util, importlib.machinery, sys
sys.dont_write_bytecode = True
repo = sys.argv[1]
loader = importlib.machinery.SourceFileLoader('ws', f'{repo}/sbin/ws-stunnel')
spec = importlib.util.spec_from_loader('ws', loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)
# header PROXY protocol v2 (TCP/IPv4): sig + ver/cmd + fam + len + src(4+2) + dst(4+2)
hdr = m.PROXY_V2_SIG + b'\x21\x11' + (12).to_bytes(2, 'big') + bytes([203, 0, 113, 9, 0, 0]) + bytes([10, 0, 0, 1, 0, 0])
ok = m.proxy_v2_addr(hdr) == '203.0.113.9'
ok = ok and m.proxy_v2_addr(b'GET / HTTP/1.1\r\n\r\n') is None
# header HTTP (CF-Connecting-IP) harus tetap menang atas alamat PROXY
ok = ok and m.client_ip_from(b'GET / HTTP/1.1\r\nCF-Connecting-IP: 198.51.100.7\r\n\r\n', '203.0.113.9') == '198.51.100.7'
print("PASS: ws-stunnel membaca PROXY protocol v2 (IP asli tak lagi 127.0.0.1)" if ok else "FAIL: parsing PROXY v2 ws-stunnel")
sys.exit(0 if ok else 1)
PY

echo "=== ALL ALGOJO-SSH TESTS PASSED ==="
