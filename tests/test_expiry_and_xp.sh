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

# Run algojo-expired one-shot
bash /usr/local/sbin/algojo-expired >/dev/null 2>&1

# Verify trial was purged completely
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
echo "Trial auto-expiry purge: PASS"

echo "ALL_EXPIRY_AND_XP_ASSERTS_PASSED"
