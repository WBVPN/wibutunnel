#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

LOG_FILE="/etc/wibutunnel/tmp/bot_error.log"
mkdir -p /etc/wibutunnel/tmp

echo "1. Testing log truncation on oversize (>1MB)..."
# Fill with 1.2MB dummy text
head -c 1200000 /dev/zero | tr '\0' 'a' > "$LOG_FILE"
echo "Initial oversize size: $(stat -c%s "$LOG_FILE") bytes"

# Source log_bot_error function from bot-daemon
eval "$(sed -n '/^log_bot_error() {/,/^}/p' /usr/local/bin/bot-daemon)"

log_bot_error "Test error message"
NEW_SIZE=$(stat -c%s "$LOG_FILE")
echo "After log_bot_error call, size: $NEW_SIZE bytes"

[[ "$NEW_SIZE" -lt 1048576 ]] || { echo "ASSERT_FAILED: Log file was not capped below 1MB"; exit 1; }
grep -q "Test error message" "$LOG_FILE" || { echo "ASSERT_FAILED: Log message not found"; exit 1; }
echo "Oversize log capping: PASS"

echo "2. Testing xp.sh cleanup of bot_error.log..."
# Fill with 3MB dummy text (> 2MB threshold)
head -c 3000000 /dev/zero | tr '\0' 'b' > "$LOG_FILE"
echo "Oversize size before xp: $(stat -c%s "$LOG_FILE") bytes"
bash /usr/local/bin/xp
XP_SIZE=$(stat -c%s "$LOG_FILE")
echo "Size after xp.sh: $XP_SIZE bytes"
[[ "$XP_SIZE" -eq 0 ]] || { echo "ASSERT_FAILED: xp.sh did not truncate bot_error.log"; exit 1; }
echo "xp.sh bot log truncation: PASS"

echo "ALL_BOT_LOG_ASSERTS_PASSED"
