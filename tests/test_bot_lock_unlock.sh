#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

CONFIG_FILE="/usr/local/etc/xray/config.json"
CONFIG="/usr/local/etc/xray/config.json"
TEST_USER="testbotlock-$$"
TEST_UUID="11223344-5566-7788-99aa-bbccddeeff00"

echo "=== 1. Preparing test user in Xray & DB ==="
safe_jq_edit_args --arg uuid "$TEST_UUID" --arg user "$TEST_USER" '
    .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}]
'
db_set /etc/xray/vless_exp.conf "$TEST_USER" "2026-12-31 00:00:00"
db_set /etc/wibutunnel/limit_ip.db "$TEST_USER" "2"
xray_sync_user add VLESS "$TEST_USER" "$TEST_UUID"

# Verify active in memory
xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TEST_USER" 2>&1 | grep -q "$TEST_USER" || {
    echo "ASSERT_FAILED: test user not in memory"; exit 1;
}

echo "=== 2. Testing lock_account function ==="
# Source functions from bot-daemon
eval "$(sed -n '/^lock_account() {/,/^}/p' /usr/local/bin/bot-daemon)"
eval "$(sed -n '/^unlock_account() {/,/^}/p' /usr/local/bin/bot-daemon)"

# Mock send_msg to avoid real telegram spam during unit test
MOCK_MSG=""
send_msg() { MOCK_MSG="$1"; }

lock_account "$TEST_USER" "VLESS"

# Verify locked in db
grep -q "^${TEST_USER}:" /etc/wibutunnel/locked_users.db || {
    echo "ASSERT_FAILED: user not in locked_users.db"; exit 1;
}

# Verify blocked in routing
jq -e --arg u "$TEST_USER" '
    (.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) | index($u) != null
' "$CONFIG" >/dev/null 2>&1 || {
    echo "ASSERT_FAILED: user not in blocked routing"; exit 1;
}

# Verify removed from in-memory via xray API
if xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TEST_USER" 2>&1 | grep -q "$TEST_USER"; then
    echo "ASSERT_FAILED: locked user still in inbound memory"; exit 1;
fi
echo "Lock execution: PASS"

echo "=== 3. Testing unlock_account function ==="
unlock_account "$TEST_USER" "VLESS"

# Verify removed from locked_users.db
if grep -q "^${TEST_USER}:" /etc/wibutunnel/locked_users.db; then
    echo "ASSERT_FAILED: user still in locked_users.db"; exit 1;
fi

# Verify removed from blocked routing
jq -e --arg u "$TEST_USER" '
    (.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) | index($u) == null
' "$CONFIG" >/dev/null 2>&1 || {
    echo "ASSERT_FAILED: user still in blocked routing"; exit 1;
}

# Verify restored in memory via xray API
xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TEST_USER" 2>&1 | grep -q "$TEST_USER" || {
    echo "ASSERT_FAILED: unlocked user not restored in inbound memory"; exit 1;
}
echo "Unlock execution: PASS"

echo "=== 4. Cleanup ==="
safe_jq_edit_args --arg u "$TEST_USER" '
    .inbounds[1].settings.clients |= map(select(.email != $u))
'
safe_sed_delete "$TEST_USER" /etc/xray/vless_exp.conf
safe_sed_delete "$TEST_USER" /etc/wibutunnel/limit_ip.db
xray_sync_user del VLESS "$TEST_USER"

echo "ALL_BOT_LOCK_UNLOCK_ASSERTS_PASSED"
