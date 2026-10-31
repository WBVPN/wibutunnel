#!/bin/bash
set -e

echo "=== Testing License Enforcement System ==="
REPO_DIR="/root/wibutunnel-repo"
source "${REPO_DIR}/common.sh"

TEST_TMP="/tmp/test_lic_$$"
mkdir -p "$TEST_TMP"
FAKE_IZIN="${TEST_TMP}/izin.txt"
FAKE_CACHE="${TEST_TMP}/license.cache"

cleanup() {
    rm -rf "$TEST_TMP"
}
trap cleanup EXIT

# 1. Test Unregistered IP
echo "1. Testing unregistered IP rejection..."
cat << 'EOF' > "$FAKE_IZIN"
### USERNAME EXPIRY_DATE IP_ADDRESS
### USER1 2099-12-31 1.2.3.4
EOF

out=$(
    export MYIP="192.168.1.100"
    export LINK_IZIN="file://${FAKE_IZIN}"
    # override check_license to read FAKE_IZIN
    CACHE_FILE="$FAKE_CACHE"
    if (
        GET_DATA=$(grep -w "$MYIP" "$FAKE_IZIN" 2>/dev/null || true)
        if [[ -z "$GET_DATA" ]]; then
            show_license_denied "$MYIP"
            exit 1
        fi
    ); then
        echo "SHOULD_FAIL"
    else
        echo "DENIED_OK"
    fi
)
[[ "$out" == *"DENIED_OK"* ]] || { echo "ASSERT_FAILED: unregistered IP was not denied"; exit 1; }
[[ "$out" == *"AKSES DITOLAK"* ]] || { echo "ASSERT_FAILED: denied banner missing"; exit 1; }
echo "Unregistered IP check: PASS"

# 2. Test Expired IP
echo "2. Testing expired IP rejection..."
cat << 'EOF' > "$FAKE_IZIN"
### USERNAME EXPIRY_DATE IP_ADDRESS
### EXPIRED_USER 2020-01-01 192.168.1.100
EOF

out_exp=$(
    export MYIP="192.168.1.100"
    CURRENT_TIME=$(date -u +%s)
    if (
        GET_DATA=$(grep -w "$MYIP" "$FAKE_IZIN" 2>/dev/null || true)
        c_name=$(echo "$GET_DATA" | awk '{print $2}')
        c_exp=$(echo "$GET_DATA" | awk '{print $3}')
        exp_parse="$c_exp"
        [[ "$exp_parse" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && exp_parse="${exp_parse} 23:59:59"
        exp_sec=$(date -u -d "$exp_parse" +%s 2>/dev/null)
        if [[ -z "$exp_sec" || $CURRENT_TIME -gt $exp_sec ]]; then
            show_license_expired "$c_name" "$c_exp"
            exit 1
        fi
    ); then
        echo "SHOULD_FAIL"
    else
        echo "EXPIRED_OK"
    fi
)
[[ "$out_exp" == *"EXPIRED_OK"* ]] || { echo "ASSERT_FAILED: expired IP was not rejected"; exit 1; }
[[ "$out_exp" == *"LISENSI KEDALUWARSA"* ]] || { echo "ASSERT_FAILED: expired banner missing"; exit 1; }
echo "Expired IP check: PASS"

# 3. Test Active Future Date IP
echo "3. Testing active future date IP..."
cat << 'EOF' > "$FAKE_IZIN"
### USERNAME EXPIRY_DATE IP_ADDRESS
### ACTIVE_USER 2099-12-31 192.168.1.100
EOF

out_active=$(
    export MYIP="192.168.1.100"
    CURRENT_TIME=$(date -u +%s)
    if (
        GET_DATA=$(grep -w "$MYIP" "$FAKE_IZIN" 2>/dev/null || true)
        c_name=$(echo "$GET_DATA" | awk '{print $2}')
        c_exp=$(echo "$GET_DATA" | awk '{print $3}')
        if [[ "${c_exp,,}" != "lifetime" ]]; then
            exp_parse="$c_exp"
            [[ "$exp_parse" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && exp_parse="${exp_parse} 23:59:59"
            exp_sec=$(date -u -d "$exp_parse" +%s 2>/dev/null)
            if [[ -z "$exp_sec" || $CURRENT_TIME -gt $exp_sec ]]; then
                show_license_expired "$c_name" "$c_exp"
                exit 1
            fi
        fi
        echo "ACTIVE_OK"
        exit 0
    ); then
        echo "PASS"
    else
        echo "FAIL"
    fi
)
[[ "$out_active" == *"ACTIVE_OK"* ]] || { echo "ASSERT_FAILED: active IP rejected"; exit 1; }
echo "Active future date check: PASS"

# 4. Test Lifetime IP
echo "4. Testing lifetime IP..."
cat << 'EOF' > "$FAKE_IZIN"
### USERNAME EXPIRY_DATE IP_ADDRESS
### LIFETIME_USER lifetime 192.168.1.100
EOF

out_life=$(
    export MYIP="192.168.1.100"
    if (
        GET_DATA=$(grep -w "$MYIP" "$FAKE_IZIN" 2>/dev/null || true)
        c_name=$(echo "$GET_DATA" | awk '{print $2}')
        c_exp=$(echo "$GET_DATA" | awk '{print $3}')
        if [[ "${c_exp,,}" == "lifetime" ]]; then
            echo "LIFETIME_OK"
            exit 0
        fi
        exit 1
    ); then
        echo "PASS"
    else
        echo "FAIL"
    fi
)
[[ "$out_life" == *"LIFETIME_OK"* ]] || { echo "ASSERT_FAILED: lifetime IP rejected"; exit 1; }
echo "Lifetime IP check: PASS"

# 5. Test Live check_license() with actual registered IP
echo "5. Testing check_license() on current VPS IP..."
if check_license_silent; then
    echo "Current VPS IP check_license_silent: PASS (Registered and Valid)"
else
    echo "ASSERT_FAILED: current VPS IP failed license check"
    exit 1
fi

echo "ALL_LICENSE_ENFORCEMENT_ASSERTS_PASSED"
