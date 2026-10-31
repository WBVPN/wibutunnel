#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

echo "1. Checking Crontab Schedule..."
if crontab -l 2>/dev/null | grep -q '^\* \* \* \* \* .*/usr/local/bin/xp'; then
    echo "ASSERT_FAILED: xp is still running every minute in crontab"
    exit 1
fi
echo "Crontab check: PASS (xp is not running every minute)"

echo "2. Testing xp.sh execution and log/temp cleanup..."
# Create a dummy stale temp file
mkdir -p /etc/wibutunnel/tmp
touch -d "2 hours ago" /etc/wibutunnel/tmp/test_stale.tmp.$$
touch /etc/wibutunnel/tmp/test_fresh.tmp.$$

# Run xp
bash /usr/local/bin/xp

# Verify stale was cleaned, fresh remains
if [[ -f /etc/wibutunnel/tmp/test_stale.tmp.$$ ]]; then
    echo "ASSERT_FAILED: stale temp file was not deleted"
    rm -f /etc/wibutunnel/tmp/test_stale.tmp.$$ /etc/wibutunnel/tmp/test_fresh.tmp.$$
    exit 1
fi
rm -f /etc/wibutunnel/tmp/test_fresh.tmp.$$
echo "Temporary file cleanup: PASS"

echo "3. Testing expiry dedup in xp.sh..."
TEST_EXP="/etc/xray/vless_exp.conf"
# Append duplicate lines
echo "dedup_test_user:Lifetime" >> "$TEST_EXP"
echo "dedup_test_user:Lifetime" >> "$TEST_EXP"
bash /usr/local/bin/xp
DUP_COUNT=$(grep -c "^dedup_test_user:Lifetime" "$TEST_EXP" || true)
safe_sed_delete "dedup_test_user" "$TEST_EXP"
if [[ "$DUP_COUNT" -ne 1 ]]; then
    echo "ASSERT_FAILED: deduplication failed, count: $DUP_COUNT"
    exit 1
fi
echo "Expiry file deduplication: PASS"

echo "4. Testing trial expiry purging via algojo..."
TRIAL_USER="trial-exp-test-$$"
TRIAL_UUID="77777777-8888-9999-aaaa-bbbbbbbbbbbb"
EXP_PAST="2020-01-01 00:00:00"

# Register in config & DB
safe_jq_edit_args --arg uuid "$TRIAL_UUID" --arg user "$TRIAL_USER" '
    .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}]
'
db_set /etc/xray/vless_exp.conf "$TRIAL_USER" "$EXP_PAST"
db_set /etc/wibutunnel/limit_ip.db "$TRIAL_USER" "1"
xray_sync_user add VLESS "$TRIAL_USER" "$TRIAL_UUID"

# Register SSH trial past expiry
SSH_TRIAL="trial-ssh-exp-$$"
add_ssh_user "$SSH_TRIAL" "testpass123" 1 1 1
db_set /etc/xray/ssh_exp.conf "$SSH_TRIAL" "$EXP_PAST"

# Run algojo-expired one-shot
bash /usr/local/sbin/algojo-expired >/dev/null 2>&1

# Verify VLESS trial was purged completely
if grep -q "$TRIAL_USER" /etc/xray/vless_exp.conf; then
    echo "ASSERT_FAILED: trial user still in exp.conf"
    exit 1
fi
if grep -q "$TRIAL_USER" /etc/wibutunnel/limit_ip.db; then
    echo "ASSERT_FAILED: trial user still in limit_ip.db"
    exit 1
fi
if xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TRIAL_USER" 2>&1 | grep -q email; then
    echo "ASSERT_FAILED: trial user still active in Xray RAM"
    exit 1
fi

# Verify SSH trial was purged completely
if id "$SSH_TRIAL" >/dev/null 2>&1; then
    echo "ASSERT_FAILED: SSH trial user still in Linux system"
    exit 1
fi
if grep -q "$SSH_TRIAL" /etc/xray/ssh_exp.conf; then
    echo "ASSERT_FAILED: SSH trial user still in ssh_exp.conf"
    exit 1
fi
echo "Trial auto-expiry purge (VLESS & SSH): PASS"

echo "5. Testing regular account expired moves to recovery (not deleted)..."
REG_USER="reg-exp-test-$$"
REG_UUID="11112222-3333-4444-5555-666677778888"
EXP_PAST="2020-01-01 00:00:00"

# Register in config & DB
safe_jq_edit_args --arg uuid "$REG_UUID" --arg user "$REG_USER" '
    .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}]
'
db_set /etc/xray/vless_exp.conf "$REG_USER" "$EXP_PAST"
db_set /etc/wibutunnel/limit_ip.db "$REG_USER" "2"
xray_sync_user add VLESS "$REG_USER" "$REG_UUID"

# Run algojo-expired one-shot
bash /usr/local/sbin/algojo-expired >/dev/null 2>&1

# Verify sidecar exists
if [[ ! -s "/etc/wibutunnel/recovery/${REG_USER}.json" ]]; then
    echo "ASSERT_FAILED: recovery sidecar not created for regular user"
    exit 1
fi

# Verify user removed from config.json and marked EXPIRED in DB
if jq -e --arg u "$REG_USER" '.inbounds[1].settings.clients[]? | select(.email == $u)' /usr/local/etc/xray/config.json >/dev/null 2>&1; then
    echo "ASSERT_FAILED: regular user still in config.json"
    exit 1
fi
if ! grep -q "$REG_USER" /etc/wibutunnel/locked_users.db; then
    echo "ASSERT_FAILED: regular user not in locked_users.db"
    exit 1
fi

# Test unlock-user restores user from recovery sidecar!
bash /usr/local/sbin/unlock-user "$REG_USER" "TEST" >/dev/null 2>&1

if ! jq -e --arg u "$REG_USER" '.inbounds[1].settings.clients[]? | select(.email == $u)' /usr/local/etc/xray/config.json >/dev/null 2>&1; then
    echo "ASSERT_FAILED: unlock-user failed to restore regular user from recovery to config.json"
    exit 1
fi
if [[ -f "/etc/wibutunnel/recovery/${REG_USER}.json" ]]; then
    echo "ASSERT_FAILED: recovery sidecar was not cleaned up after unlock-user"
    exit 1
fi

# Cleanup test user
safe_jq_edit_args --arg u "$REG_USER" '
    .inbounds[1].settings.clients |= map(select(.email != $u))
'
safe_sed_delete "$REG_USER" /etc/xray/vless_exp.conf
safe_sed_delete "$REG_USER" /etc/wibutunnel/limit_ip.db
safe_sed_delete "$REG_USER" /etc/wibutunnel/locked_users.db
xray_sync_user del VLESS "$REG_USER" >/dev/null 2>&1 || true
echo "Regular expiry recovery & unlock-user restore: PASS"

echo "ALL_EXPIRY_AND_XP_ASSERTS_PASSED"
