#!/bin/bash
# ==========================================
# TEST AUTO-REPAIR SYSTEM
# ==========================================
set -e

echo "=== 1. Testing wibu-repair syntax and executable ==="
bash -n /root/wibutunnel-repo/sbin/wibu-repair
[[ -x /usr/local/sbin/wibu-repair ]] || { echo "ASSERT_FAILED: /usr/local/sbin/wibu-repair not executable"; exit 1; }
[[ -x /usr/local/bin/wibu-repair ]] || { echo "ASSERT_FAILED: /usr/local/bin/wibu-repair not executable"; exit 1; }

echo "=== 2. Testing Dropbear hostkey auto-recovery ==="
# Backup key, delete, run repair, verify recreation
KEY_BAK="/etc/dropbear/dropbear_ed25519_host_key.testbak"
if [[ -f /etc/dropbear/dropbear_ed25519_host_key ]]; then
    mv /etc/dropbear/dropbear_ed25519_host_key "$KEY_BAK"
fi

/usr/local/sbin/wibu-repair >/dev/null 2>&1

[[ -s /etc/dropbear/dropbear_ed25519_host_key ]] || { echo "ASSERT_FAILED: Dropbear hostkey was not recreated"; exit 1; }
rm -f "$KEY_BAK"
echo "Dropbear hostkey auto-recovery: PASS"

echo "=== 3. Testing WS-Response auto-recovery ==="
RESP_BAK="/etc/wibutunnel/ws-response.testbak"
if [[ -f /etc/wibutunnel/ws-response ]]; then
    mv /etc/wibutunnel/ws-response "$RESP_BAK"
fi

/usr/local/sbin/wibu-repair >/dev/null 2>&1

[[ -s /etc/wibutunnel/ws-response ]] || { echo "ASSERT_FAILED: ws-response was not recreated"; exit 1; }
grep -qi "websocket" /etc/wibutunnel/ws-response || { echo "ASSERT_FAILED: invalid ws-response content"; exit 1; }
rm -f "$RESP_BAK"
echo "WS-Response auto-recovery: PASS"

echo "=== 4. Testing Xray config corruption recovery ==="
# Backup valid config, corrupt it, test recovery
cp -f /etc/xray/config.json /etc/xray/config.json.testbak
cp -f /etc/xray/config.json /etc/xray/config.json.bak
echo "CORRUPTED_JSON_NOT_VALID" > /etc/xray/config.json

/usr/local/sbin/wibu-repair >/dev/null 2>&1

jq . /etc/xray/config.json >/dev/null 2>&1 || { echo "ASSERT_FAILED: Corrupted Xray config was not restored"; exit 1; }
rm -f /etc/xray/config.json.testbak
echo "Xray config corruption recovery: PASS"

echo "=== 5. Testing Live Service Status after Repair ==="
for svc in xray haproxy dropbear ws-stunnel algojo-expired wibu-daemon cron; do
    systemctl is-active --quiet "$svc" || { echo "ASSERT_FAILED: Service $svc is not active"; exit 1; }
done
echo "Core services active check: PASS"

echo "=== 6. Testing Port Listening after Repair ==="
for port in 80 443 109 143 10015 10085; do
    ss -tlnp | grep -q -E ":${port}\b" || { echo "ASSERT_FAILED: Port $port is not listening"; exit 1; }
done
echo "Stack ports listening check: PASS"

echo "ALL_AUTO_REPAIR_ASSERTS_PASSED"
