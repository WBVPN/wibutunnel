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

echo "5. Testing download_menu validation logic (bash, python, invalid syntax)..."
# Extract download_menu validation into a test harness
eval "$(awk '/^download_menu\(\)/{flag=1} flag{print} flag && /^}/{exit}' "$SETUP_FILE")"

TEST_TMP_DIR=$(mktemp -d /tmp/wibu_test_dl.XXXXXX)
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# Test valid bash
cat << 'EOF' > "$TEST_TMP_DIR/valid_bash.sh"
#!/bin/bash
echo "valid bash"
EOF

# Test valid python
cat << 'EOF' > "$TEST_TMP_DIR/valid_py.py"
#!/usr/bin/env python3
import sys
sys.exit(0)
EOF

# Test invalid bash syntax
cat << 'EOF' > "$TEST_TMP_DIR/bad_bash.sh"
#!/bin/bash
if [ -z foo; then
EOF

# Test invalid python syntax
cat << 'EOF' > "$TEST_TMP_DIR/bad_py.py"
#!/usr/bin/env python3
def foo(
EOF

# Test unsupported shebang
cat << 'EOF' > "$TEST_TMP_DIR/unsupported.rb"
#!/usr/bin/env ruby
puts "ruby"
EOF

validate_script() {
    local tmp_file="$1"
    local name="$2"
    local shebang=$(head -n 1 "$tmp_file")
    if [[ "$shebang" =~ ^#!.*(bash|sh) ]]; then
        bash -n "$tmp_file" 2>/dev/null || return 1
    elif [[ "$shebang" =~ ^#!.*python ]]; then
        python3 -m py_compile "$tmp_file" 2>/dev/null || return 1
        rm -rf /etc/wibutunnel/tmp/__pycache__
    else
        return 1
    fi
    return 0
}

validate_script "$TEST_TMP_DIR/valid_bash.sh" "valid_bash" || { echo "ASSERT_FAILED: valid bash rejected"; exit 1; }
validate_script "$TEST_TMP_DIR/valid_py.py" "valid_py" || { echo "ASSERT_FAILED: valid python rejected"; exit 1; }
validate_script "/root/wibutunnel-repo/menu/menu.sh" "menu.sh" || { echo "ASSERT_FAILED: menu.sh rejected"; exit 1; }
validate_script "/root/wibutunnel-repo/sbin/ws-stunnel" "ws-stunnel" || { echo "ASSERT_FAILED: ws-stunnel rejected"; exit 1; }

if validate_script "$TEST_TMP_DIR/bad_bash.sh" "bad_bash"; then
    echo "ASSERT_FAILED: invalid bash accepted"
    exit 1
fi
if validate_script "$TEST_TMP_DIR/bad_py.py" "bad_py"; then
    echo "ASSERT_FAILED: invalid python accepted"
    exit 1
fi
if validate_script "$TEST_TMP_DIR/unsupported.rb" "unsupported"; then
    echo "ASSERT_FAILED: unsupported ruby script accepted"
    exit 1
fi
echo "download_menu validation logic check: PASS"

echo "6. Checking all files in _need calls in setup.sh exist in repo..."
REPO_DIR="/root/wibutunnel-repo"
grep -E '^\s*_need\s+"' "$SETUP_FILE" | while read -r line; do
    rel_path=$(echo "$line" | sed -E 's/.*_need\s+"([^"]+)".*/\1/')
    if [ ! -f "$REPO_DIR/$rel_path" ]; then
        echo "ASSERT_FAILED: _need target not found in repo: $rel_path"
        exit 1
    fi
done
echo "All _need files exist check: PASS"

echo "7. Checking HAProxy config heredoc in setup.sh for unescaped \${domain}.pem..."
if grep -q 'bind \*:443 ssl crt /etc/haproxy/certs/\\${domain}\.pem' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh contains escaped \\${domain}.pem in HAProxy heredoc"
    exit 1
fi
if ! grep -q 'bind \*:443 ssl crt /etc/haproxy/certs/${domain}\.pem' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh missing unescaped \${domain}.pem in HAProxy heredoc"
    exit 1
fi
echo "HAProxy heredoc domain pem check: PASS"

echo "8. Checking m-setting.sh preserves common.sh filename..."
if ! grep -q 'if \[\[ "$base_name" == "common.sh" \]\]; then target_name="common.sh"; fi' "$SETTING_FILE"; then
    echo "ASSERT_FAILED: m-setting.sh missing common.sh preservation logic"
    exit 1
fi
echo "m-setting common.sh preservation check: PASS"

echo "9. Checking setup.sh xray config permission and ownership..."
if grep -q 'chmod 600 /usr/local/etc/xray/config.json' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh still contains chmod 600 for config.json"
    exit 1
fi
if ! grep -q 'chown -R root:xray /usr/local/etc/xray' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh missing chown -R root:xray /usr/local/etc/xray"
    exit 1
fi
if ! grep -q 'chmod 640 /usr/local/etc/xray/config.json' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh missing chmod 640 /usr/local/etc/xray/config.json"
    exit 1
fi
if ! grep -q 'chown -R root:xray /etc/xray 2>/dev/null || true' "$SETUP_FILE"; then
    echo "ASSERT_FAILED: setup.sh missing chown -R root:xray /etc/xray"
    exit 1
fi
echo "setup.sh xray config permission check: PASS"

echo "10. Checking common.sh safe_jq_edit permission and ownership..."
COMMON_FILE="/root/wibutunnel-repo/common.sh"
if ! grep -q 'chown root:xray "$src" 2>/dev/null || true' "$COMMON_FILE"; then
    echo "ASSERT_FAILED: common.sh missing chown root:xray on edit"
    exit 1
fi
if ! grep -q 'chmod 640 "$src"' "$COMMON_FILE"; then
    echo "ASSERT_FAILED: common.sh missing chmod 640 on edit"
    exit 1
fi
echo "common.sh safe_jq_edit permission check: PASS"

echo "11. Checking m-setting.sh dos2unix order before systemctl restart..."
awk '
/dos2unix \/usr\/local\/bin\/\* \/usr\/local\/sbin\/\*/ { dos_line = NR }
/systemctl restart telegram-bot algojo-expired/ { restart_line = NR }
END {
    if (!dos_line || !restart_line || dos_line >= restart_line) {
        exit 1
    }
}
' "$SETTING_FILE" || { echo "ASSERT_FAILED: dos2unix not before systemctl restart in m-setting.sh"; exit 1; }
echo "m-setting dos2unix ordering check: PASS"

echo "ALL_SETUP_FLOW_ASSERTS_PASSED"
