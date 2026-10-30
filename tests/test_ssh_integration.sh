#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

CONFIG_FILE="/usr/local/etc/xray/config.json"
TEST_USER="testsshuser$$"
TEST_PASS="testpass123"

echo "=== 1. Testing add_ssh_user & DB sync ==="
# Buat akun SSH
add_ssh_user "$TEST_USER" "$TEST_PASS" 30 2 10

# Pastikan user sistem linux tercipta
id "$TEST_USER" >/dev/null 2>&1 || { echo "ASSERT_FAILED: linux user not created"; exit 1; }

# Pastikan terdaftar di ssh_exp.conf
grep -q "^${TEST_USER}:" /etc/xray/ssh_exp.conf || { echo "ASSERT_FAILED: user not in ssh_exp.conf"; exit 1; }

# Pastikan password tersimpan di ssh_pass.db
pass_read=$(ssh_get_pass "$TEST_USER")
[[ "$pass_read" == "$TEST_PASS" ]] || { echo "ASSERT_FAILED: password mismatch"; exit 1; }

# Pastikan limit IP dan BW tersimpan
[[ "$(db_get "$TEST_USER" /etc/wibutunnel/limit_ip.db)" == "2" ]] || { echo "ASSERT_FAILED: limit ip mismatch"; exit 1; }
[[ "$(db_get "$TEST_USER" /etc/wibutunnel/limit_bw.db)" == "10" ]] || { echo "ASSERT_FAILED: limit bw mismatch"; exit 1; }
echo "add_ssh_user: PASS"

echo "=== 2. Testing bot-daemon SSH function integration ==="
eval "$(sed -n '/^lock_account() {/,/^}/p' /usr/local/bin/bot-daemon)"
eval "$(sed -n '/^unlock_account() {/,/^}/p' /usr/local/bin/bot-daemon)"
eval "$(sed -n '/^change_limit() {/,/^}/p' /usr/local/bin/bot-daemon)"
eval "$(sed -n '/^renew_account() {/,/^}/p' /usr/local/bin/bot-daemon)"
eval "$(sed -n '/^delete_account() {/,/^}/p' /usr/local/bin/bot-daemon)"

MOCK_MSG=""
send_msg() { MOCK_MSG="$1"; }

# Test Bot Lock
lock_account "$TEST_USER" "SSH"
grep -q "^${TEST_USER}:" /etc/wibutunnel/locked_users.db || { echo "ASSERT_FAILED: ssh user not locked in db"; exit 1; }
# User passwd harus locked ('!')
passwd -S "$TEST_USER" | awk '{print $2}' | grep -q "L" || { echo "ASSERT_FAILED: ssh user shadow not locked"; exit 1; }
echo "Bot Lock SSH: PASS"

# Test Bot Unlock
unlock_account "$TEST_USER" "SSH"
if grep -q "^${TEST_USER}:" /etc/wibutunnel/locked_users.db; then
    echo "ASSERT_FAILED: ssh user still locked in db"; exit 1;
fi
passwd -S "$TEST_USER" | awk '{print $2}' | grep -q "P" || { echo "ASSERT_FAILED: ssh user shadow not unlocked"; exit 1; }
echo "Bot Unlock SSH: PASS"

# Test Bot Change Limit
change_limit "$TEST_USER" 5 20 "SSH"
[[ "$(db_get "$TEST_USER" /etc/wibutunnel/limit_ip.db)" == "5" ]] || { echo "ASSERT_FAILED: changed limit ip mismatch"; exit 1; }
[[ "$(db_get "$TEST_USER" /etc/wibutunnel/limit_bw.db)" == "20" ]] || { echo "ASSERT_FAILED: changed limit bw mismatch"; exit 1; }
echo "Bot Change Limit SSH: PASS"

# Test Bot Renew
old_exp=$(db_get "$TEST_USER" /etc/xray/ssh_exp.conf)
renew_account "$TEST_USER" 10 "SSH"
new_exp=$(db_get "$TEST_USER" /etc/xray/ssh_exp.conf)
[[ "$new_exp" > "$old_exp" ]] || { echo "ASSERT_FAILED: expiry not renewed (old: $old_exp, new: $new_exp)"; exit 1; }
echo "Bot Renew SSH: PASS"

# Test Bot Delete
delete_account "$TEST_USER" "SSH"
if id "$TEST_USER" >/dev/null 2>&1; then
    echo "ASSERT_FAILED: user still exists after delete"; exit 1;
fi
if grep -q "^${TEST_USER}:" /etc/xray/ssh_exp.conf; then
    echo "ASSERT_FAILED: user still in ssh_exp.conf after delete"; exit 1;
fi
echo "Bot Delete SSH: PASS"

echo "=== 3. Testing Dropbear & WS-Stunnel Port Connectivity ==="
# Test Dropbear raw port 143
nc -z -w 2 127.0.0.1 143 || { echo "ASSERT_FAILED: Dropbear port 143 not listening"; exit 1; }
# Test Dropbear port 109
nc -z -w 2 127.0.0.1 109 || { echo "ASSERT_FAILED: Dropbear port 109 not listening"; exit 1; }
# Test WS-Stunnel port 10015
nc -z -w 2 127.0.0.1 10015 || { echo "ASSERT_FAILED: ws-stunnel port 10015 not listening"; exit 1; }
# Test HAProxy port 80 Direct SSH multiplexing
local_ssh_resp=$(echo "SSH-2.0-TestAssert" | nc -w 2 127.0.0.1 80 2>/dev/null | head -n 1)
[[ "$local_ssh_resp" == SSH-2.0* ]] || { echo "ASSERT_FAILED: Port 80 did not route direct SSH payload to Dropbear"; exit 1; }

# Test HAProxy port 80 Enhanced / WS Payload
enhanced_test=$(python3 -c '
import socket
payload = b"GET / HTTP/1.1\r\nHost: edu.ruangguru.com\r\n\r\nPATCH / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\n\r\n"
s = socket.create_connection(("127.0.0.1", 80))
s.sendall(payload)
resp = s.recv(1024)
s.close()
if b"101 Switching Protocols" in resp:
    print("OK")
else:
    print("FAIL")
')
[[ "$enhanced_test" == "OK" ]] || { echo "ASSERT_FAILED: Port 80 enhanced payload failed"; exit 1; }

echo "Network port listening, Direct SSH & Enhanced SSH on port 80: PASS"

echo "ALL_SSH_INTEGRATION_ASSERTS_PASSED"
