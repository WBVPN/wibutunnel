#!/bin/bash
# ==========================================================================
# TEST AUTO-REPAIR SYSTEM
# Perbaikan penting vs versi lama:
#  - Semua berkas yang "dirusak" untuk pengujian dipulihkan lewat trap, jadi
#    kegagalan di tengah TIDAK meninggalkan VPS tanpa host key / config rusak.
#  - Uji host key tidak lagi khusus ed25519: dropbear Ubuntu 20.04 (2020.81)
#    TIDAK mendukung `-t ed25519`, sehingga uji lama selalu gagal & meninggalkan
#    berkas .testbak (host key hilang). Sekarang: minimal satu host key pulih.
#  - Path config Xray diambil dari common.sh (bukan /etc/xray/ yang bisa kosong).
# ==========================================================================
set -e
REPO="${REPO:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
[[ -d "$REPO/sbin" ]] || REPO="/root/wibutunnel-repo"

XRAY_CFG="/usr/local/etc/xray/config.json"
[[ -f "$XRAY_CFG" ]] || XRAY_CFG="/etc/xray/config.json"

KEYS=(/etc/dropbear/dropbear_ed25519_host_key /etc/dropbear/dropbear_ecdsa_host_key /etc/dropbear/dropbear_rsa_host_key)
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

restore_all() {
    for k in "${KEYS[@]}"; do
        [[ -f "$k.testbak" && ! -s "$k" ]] && mv "$k.testbak" "$k"
        rm -f "$k.testbak" 2>/dev/null || true
    done
    [[ -f /etc/wibutunnel/ws-response.testbak && ! -s /etc/wibutunnel/ws-response ]] && mv /etc/wibutunnel/ws-response.testbak /etc/wibutunnel/ws-response
    [[ -f "$XRAY_CFG.testbak" ]] && { mv "$XRAY_CFG.testbak" "$XRAY_CFG"; rm -f "$XRAY_CFG.bak"; }
    [[ -f "$HAPROXY_CFG.testbak" ]] && { mv "$HAPROXY_CFG.testbak" "$HAPROXY_CFG"; }
    rm -rf /tmp/wibu_test_hide_bak
}
trap restore_all EXIT

echo "=== 1. Testing wibu-repair syntax and executable ==="
bash -n "$REPO/sbin/wibu-repair"
[[ -x /usr/local/sbin/wibu-repair ]] || { echo "ASSERT_FAILED: /usr/local/sbin/wibu-repair not executable"; exit 1; }
[[ -x /usr/local/bin/wibu-repair ]] || { echo "ASSERT_FAILED: /usr/local/bin/wibu-repair not executable"; exit 1; }

echo "=== 2. Testing Dropbear host key auto-recovery ==="
for k in "${KEYS[@]}"; do [[ -f "$k" ]] && mv "$k" "$k.testbak"; rm -f "$k"; done
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
ADA=0
for k in "${KEYS[@]}"; do [[ -s "$k" ]] && ADA=$((ADA+1)); done
if [[ $ADA -lt 1 ]]; then echo "ASSERT_FAILED: tidak ada host key dropbear yang dipulihkan"; exit 1; fi
echo "Dropbear host key auto-recovery: PASS ($ADA tipe pulih)"

echo "=== 3. Testing WS-Response auto-recovery ==="
if [[ -f /etc/wibutunnel/ws-response ]]; then mv /etc/wibutunnel/ws-response /etc/wibutunnel/ws-response.testbak; fi
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
[[ -s /etc/wibutunnel/ws-response ]] || { echo "ASSERT_FAILED: ws-response was not recreated"; exit 1; }
grep -qi "websocket" /etc/wibutunnel/ws-response || { echo "ASSERT_FAILED: invalid ws-response content"; exit 1; }
echo "WS-Response auto-recovery: PASS"

echo "=== 4. Testing Xray config corruption recovery ($XRAY_CFG) ==="
cp -f "$XRAY_CFG" "$XRAY_CFG.testbak"
cp -f "$XRAY_CFG" "$XRAY_CFG.bak"
echo "CORRUPTED_JSON_NOT_VALID" > "$XRAY_CFG"
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
jq . "$XRAY_CFG" >/dev/null 2>&1 || { echo "ASSERT_FAILED: Corrupted Xray config was not restored"; exit 1; }
echo "Xray config corruption recovery: PASS"

echo "=== 5. Testing Xray blank-template protection when no .bak exists ==="
mkdir -p /tmp/wibu_test_hide_bak
mv "$XRAY_CFG".bak* /tmp/wibu_test_hide_bak/ 2>/dev/null || true
echo "CORRUPTED_WITHOUT_BAK" > "$XRAY_CFG"
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
if [[ -f "$REPO/config/config.json" ]] && cmp -s "$XRAY_CFG" "$REPO/config/config.json"; then
    echo "ASSERT_FAILED: Empty repo template was restored, risking silent user wipe"
    exit 1
fi
mv /tmp/wibu_test_hide_bak/* "$XRAY_CFG".bak 2>/dev/null || true
rm -rf /tmp/wibu_test_hide_bak
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
echo "Xray blank-template protection: PASS"

echo "=== 6. Testing HAProxy config corruption and domain placeholder recovery ==="
cp -f "$HAPROXY_CFG" "$HAPROXY_CFG.testbak"
echo "CORRUPTED_HAPROXY_CONFIG" > "$HAPROXY_CFG"
/usr/local/sbin/wibu-repair >/dev/null 2>&1 || true
haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1 || { echo "ASSERT_FAILED: HAProxy config repair failed syntax check"; exit 1; }
if grep -q '\${__DOMAIN__}' "$HAPROXY_CFG"; then
    echo "ASSERT_FAILED: HAProxy config contains unreplaced \${__DOMAIN__} placeholder"; exit 1
fi
cur_domain=$(cat /etc/xray/domain 2>/dev/null || true)
if [[ -n "$cur_domain" ]] && ! grep -q "$cur_domain" "$HAPROXY_CFG"; then
    echo "ASSERT_FAILED: HAProxy config missing current domain: $cur_domain"; exit 1
fi
echo "HAProxy config corruption and domain placeholder recovery: PASS"

echo "=== 7. Testing Live Service Status after Repair ==="
for svc in xray haproxy dropbear ws-stunnel algojo-expired wibu-daemon cron; do
    systemctl is-active --quiet "$svc" || { echo "ASSERT_FAILED: Service $svc is not active"; exit 1; }
done
echo "Core services active check: PASS"

echo "=== 8. Testing Port Listening after Repair ==="
for port in 80 443 109 143 10015 10085; do
    ss -tlnp | grep -q -E ":${port}\b" || { echo "ASSERT_FAILED: Port $port is not listening"; exit 1; }
done
echo "Stack ports listening check: PASS"

echo "ALL_AUTO_REPAIR_ASSERTS_PASSED"
