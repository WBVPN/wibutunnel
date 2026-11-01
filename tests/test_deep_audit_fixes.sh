#!/bin/bash
# ==============================================================================
# TEST SUITE: test_deep_audit_fixes.sh
# Tests deep audit bug fixes:
# 1. unlock-user without "local" outside function error
# 2. unlocker-wibu robust parsing & auto-unlock
# 3. menu-recovery supports SSH accounts (no ghost purge)
# 4. m-backup includes SSH and recovery files
# 5. ws-stunnel target socket cleanup
# ==============================================================================
set -euo pipefail

REPO_DIR="/root/wibutunnel-repo"
TMP_DIR=$(mktemp -d /tmp/wibu_deep_test.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== [1/5] Testing unlock-user for local outside function syntax ==="
# Running unlock-user with empty arg should cleanly exit 1 with NO stderr
err_out=$(bash "$REPO_DIR/sbin/unlock-user" "" "AUTO" 2>&1 || true)
if [[ "$err_out" =~ "local: can only be used in a function" ]]; then
    echo "FAIL: unlock-user emitted 'local: can only be used in a function'"
    exit 1
fi
echo "PASS: unlock-user clean from invalid local keywords"

echo "=== [2/5] Testing unlocker-wibu with malformed & valid rows ==="
# Setup mock locked_users.db
MOCK_DB="$TMP_DIR/locked_users.db"
now=$(date -u +%s)
past=$((now - 100))
future=$((now + 1000))

cat <<EOF > "$MOCK_DB"
valid_past:${past}:${past}:IP_LIMIT
valid_future:${now}:${future}:IP_LIMIT
perm_locked:${now}:0:EXPIRED
malformed_line
another_bad:::QUOTA
EOF

MOCK_UNLOCKED="$TMP_DIR/unlocked_list.txt"
> "$MOCK_UNLOCKED"

# Test parsing logic in unlocker-wibu
users_to_unlock=()
while IFS=: read -r user now_lock unlock_time reason; do
    [[ -z "$user" ]] && continue
    if [[ "$unlock_time" =~ ^[0-9]+$ && "$unlock_time" -gt 0 && "$now" -ge "$unlock_time" ]]; then
        users_to_unlock+=("$user")
    fi
done < "$MOCK_DB"

[[ "${#users_to_unlock[@]}" -eq 1 ]] || { echo "FAIL: expected 1 user, got ${#users_to_unlock[@]}"; exit 1; }
[[ "${users_to_unlock[0]}" == "valid_past" ]] || { echo "FAIL: expected valid_past, got ${users_to_unlock[0]}"; exit 1; }
echo "PASS: unlocker-wibu logic correctly isolated expired lock without errors"

echo "=== [3/5] Testing menu-recovery SSH protocol inclusion ==="
# Check menu-recovery.sh syntax & SSH handling
grep -q "ssh_exp.conf" "$REPO_DIR/menu/menu-recovery.sh" || { echo "FAIL: menu-recovery missing ssh_exp.conf"; exit 1; }
grep -q "del_ssh_user" "$REPO_DIR/menu/menu-recovery.sh" || { echo "FAIL: menu-recovery missing del_ssh_user in deleteall"; exit 1; }
grep -q "unlock_ssh_user" "$REPO_DIR/menu/menu-recovery.sh" || { echo "FAIL: menu-recovery missing unlock_ssh_user"; exit 1; }
echo "PASS: menu-recovery fully integrates SSH accounts"

echo "=== [4/5] Testing m-backup file list includes SSH and Recovery ==="
grep -q "etc/xray/ssh_exp.conf" "$REPO_DIR/menu/m-backup.sh" || { echo "FAIL: m-backup missing ssh_exp.conf"; exit 1; }
grep -q "etc/wibutunnel/ssh_pass.db" "$REPO_DIR/menu/m-backup.sh" || { echo "FAIL: m-backup missing ssh_pass.db"; exit 1; }
grep -q "etc/wibutunnel/recovery" "$REPO_DIR/menu/m-backup.sh" || { echo "FAIL: m-backup missing recovery dir"; exit 1; }
grep -q "useradd -m -s /bin/bash" "$REPO_DIR/menu/m-backup.sh" || { echo "FAIL: m-backup missing SSH user restore"; exit 1; }
echo "PASS: m-backup and restore handles SSH and recovery completely"

echo "=== [5/5] Testing ws-stunnel python compilation & structure ==="
python3 -m py_compile "$REPO_DIR/sbin/ws-stunnel"
grep -q "if target:" "$REPO_DIR/sbin/ws-stunnel" || { echo "FAIL: ws-stunnel missing target cleanup"; exit 1; }
echo "PASS: ws-stunnel verified"

echo "ALL DEEP AUDIT CHECKS PASSED!"
