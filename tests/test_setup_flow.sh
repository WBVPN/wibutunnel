#!/bin/bash
set -e

SETUP_FILE="/root/wibutunnel-repo/setup.sh"
SETTING_FILE="/root/wibutunnel-repo/menu/m-setting.sh"

echo "1. Checking setup.sh for apt-get upgrade..."
if grep -q 'apt-get upgrade' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: apt-get upgrade found in setup.sh"
    exit 1
fi
echo "apt-get upgrade check: PASS (cleanly removed)"

echo "2. Checking setup.sh crontab for hardcoded reboot..."
if grep -E 'crontab.*\/sbin\/reboot' "$SETUP_FILE" | grep -v 'grep -v'; then
    echo "ASSERT_FAILED: hardcoded /sbin/reboot crontab found in setup.sh"
    exit 1
fi
echo "Hardcoded reboot crontab check: PASS (not hardcoded)"

echo "3. Checking setup.sh for interactive reboot prompt..."
if ! grep -q 'ans_reboot' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: ans_reboot interactive prompt missing in setup.sh"
    exit 1
fi
echo "Interactive reboot prompt check: PASS"

echo "4. Checking m-setting.sh for auto reboot off support..."
if ! grep -q 'Auto Reboot telah dinonaktifkan' "$SETTING_FILE"; then
    echo "ASSERT_FAILED: off support missing in m-setting.sh"
    exit 1
fi
echo "m-setting auto reboot 'off' check: PASS"

echo "ALL_SETUP_FLOW_ASSERTS_PASSED"
