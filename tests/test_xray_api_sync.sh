#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

PID_START=$(systemctl show --property MainPID --value xray 2>/dev/null || echo 0)
TEST_USER="assert-test-user-$$"
TEST_UUID="12345678-aaaa-bbbb-cccc-1234567890ab"

# 1. Add VLESS
xray_sync_user add VLESS "$TEST_USER" "$TEST_UUID"
grep -q "$TEST_USER" <(xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TEST_USER") || { echo "ASSERT_FAILED: add"; exit 1; }

# 2. Verify PID did not change
if [[ "$PID_START" != "0" ]]; then
    PID_NOW=$(systemctl show --property MainPID --value xray)
    [[ "$PID_START" == "$PID_NOW" ]] || { echo "ASSERT_FAILED: PID changed on add"; exit 1; }
fi

# 3. Del VLESS
xray_sync_user del VLESS "$TEST_USER"
! grep -q "$TEST_USER" <(xray api inbounduser --server=127.0.0.1:10085 --tag="vless-ws-tls" --email="$TEST_USER" 2>&1) || { echo "ASSERT_FAILED: del"; exit 1; }

# 4. Verify PID still did not change
if [[ "$PID_START" != "0" ]]; then
    PID_FINAL=$(systemctl show --property MainPID --value xray)
    [[ "$PID_START" == "$PID_FINAL" ]] || { echo "ASSERT_FAILED: PID changed on del"; exit 1; }
fi

echo "ALL_ASSERTS_PASSED: PID=$PID_FINAL"
