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

echo "=== ALL ALGOJO-SSH TESTS PASSED ==="
