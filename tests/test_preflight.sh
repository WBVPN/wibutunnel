#!/bin/bash
# tests/test_preflight.sh — uji unit wibu_preflight() dari setup.sh
# Non-destruktif: fungsi diekstrak ke shell tes, semua perintah eksternal di-shim via PATH.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP_FILE="$REPO_DIR/setup.sh"
BASH_BIN="$(command -v bash)"

PASS=0
FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

eval "$(awk '/^wibu_preflight\(\)/{flag=1} flag{print} flag && /^}/{exit}' "$SETUP_FILE")"
if ! declare -f wibu_preflight >/dev/null 2>&1; then
    echo "  FAIL  fungsi wibu_preflight() tidak ditemukan di setup.sh"
    echo "PREFLIGHT: 0 PASS / 1 FAIL"
    exit 1
fi
export -f wibu_preflight

TMP_DIR=$(mktemp -d /tmp/wibu_preflight.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/noss"

cat > "$TMP_DIR/bin/uname" <<'EOF'
#!/bin/bash
echo "${WIBU_TEST_ARCH:-x86_64}"
EOF

cat > "$TMP_DIR/bin/systemd-detect-virt" <<'EOF'
#!/bin/bash
echo "${WIBU_TEST_VIRT:-kvm}"
EOF

cat > "$TMP_DIR/bin/ss" <<'EOF'
#!/bin/bash
[[ -n "${WIBU_TEST_SS_RC:-}" ]] && exit "$WIBU_TEST_SS_RC"
[[ "${WIBU_TEST_SS_NOISE:-0}" == "1" ]] && echo "Warning: socket info tidak lengkap"
echo "State Recv-Q Send-Q Local Address:Port Peer Address:Port Process"
port="${!#}"
port="${port##*:}"
var="WIBU_TEST_SS_$port"
line="${!var:-}"
[[ -n "$line" ]] && printf '%s\n' "$line"
exit 0
EOF

chmod +x "$TMP_DIR/bin/uname" "$TMP_DIR/bin/systemd-detect-virt" "$TMP_DIR/bin/ss"

# PATH minimal tanpa ss: hanya alat yang benar-benar dipakai fungsi.
for _c in awk sed head df curl wget; do
    ln -s "$(command -v "$_c")" "$TMP_DIR/noss/$_c"
done
cp "$TMP_DIR/bin/uname" "$TMP_DIR/bin/systemd-detect-virt" "$TMP_DIR/noss/"
chmod +x "$TMP_DIR/noss/uname" "$TMP_DIR/noss/systemd-detect-virt"

FULL_PATH="$TMP_DIR/bin:$PATH"
NO_SS_PATH="$TMP_DIR/noss"
# Tanpa wget (curl ada) dan tanpa curl sama sekali.
mkdir -p "$TMP_DIR/nowget" "$TMP_DIR/nocurl"
for _c in awk sed head df curl; do ln -s "$(command -v "$_c")" "$TMP_DIR/nowget/$_c"; done
for _c in awk sed head df wget; do ln -s "$(command -v "$_c")" "$TMP_DIR/nocurl/$_c"; done
cp "$TMP_DIR/bin/uname" "$TMP_DIR/bin/systemd-detect-virt" "$TMP_DIR/bin/ss" "$TMP_DIR/nowget/"
cp "$TMP_DIR/bin/uname" "$TMP_DIR/bin/systemd-detect-virt" "$TMP_DIR/bin/ss" "$TMP_DIR/nocurl/"
chmod +x "$TMP_DIR/nowget"/* "$TMP_DIR/nocurl"/*
NOWGET_PATH="$TMP_DIR/nowget:$TMP_DIR/bin"
NOCURL_PATH="$TMP_DIR/nocurl:$TMP_DIR/bin"

run_case() {
    local name="$1" want_rc="$2" want_msg="$3" path="$4"
    local virt="$5" ram="$6" disk="$7" ss80="$8" ss443="$9" allow="${10}" ss_rc="${11:-}"
    local ss143="${12:-}" ss109="${13:-}" noise="${14:-0}" sysdir="${15:-/run/systemd/system}" tun="${16:-/dev/net/tun}"
    local out rc

    out=$(PATH="$path" \
        WIBU_PREFLIGHT_RAM_MB="$ram" \
        WIBU_PREFLIGHT_DISK_MB="$disk" \
        WIBU_TEST_ARCH="${WIBU_TEST_ARCH_OVERRIDE:-x86_64}" \
        WIBU_TEST_VIRT="$virt" \
        WIBU_ALLOW_CONTAINER="$allow" \
        WIBU_TEST_SS_RC="$ss_rc" \
        WIBU_TEST_SS_NOISE="$noise" \
        WIBU_TEST_SS_80="$ss80" \
        WIBU_TEST_SS_443="$ss443" \
        WIBU_TEST_SS_143="$ss143" \
        WIBU_TEST_SS_109="$ss109" \
        WIBU_PREFLIGHT_SYSTEMD_DIR="$sysdir" \
        WIBU_PREFLIGHT_TUN="$tun" \
        "$BASH_BIN" -c 'wibu_preflight' 2>&1)
    rc=$?

    if [[ "$rc" -eq "$want_rc" ]] && { [[ -z "$want_msg" ]] || grep -qF "$want_msg" <<<"$out"; }; then
        ok "$name"
    else
        bad "$name (rc=$rc, harap rc=$want_rc${want_msg:+, pesan '$want_msg'})"
        printf '%s\n' "$out" | sed 's/^/        /'
    fi
}

SS_NGINX='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=101,fd=6))'
SS_HAPROXY='LISTEN 0 4096 0.0.0.0:443 0.0.0.0:* users:(("haproxy",pid=202,fd=7))'
SS_MULTI_NGINX='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:* users:(("systemd",pid=1,fd=1),("nginx",pid=101,fd=6))'
SS_MULTI_BAD='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:* users:(("systemd",pid=1,fd=1),("python3",pid=303,fd=4))'
SS_DROPBEAR143='LISTEN 0 128 0.0.0.0:143 0.0.0.0:* users:(("dropbear",pid=404,fd=3))'
SS_STUNNEL143='LISTEN 0 128 0.0.0.0:143 0.0.0.0:* users:(("stunnel",pid=505,fd=3))'

echo "== wibu_preflight =="
run_case "sistem bersih KVM, port bebas -> rc 0"            0 ""                  "$FULL_PATH"  kvm     2048 10240 ""      ""          0
run_case "port 80 nginx -> rc 0 (dihentikan otomatis)"      0 "akan dihentikan otomatis" "$FULL_PATH" kvm 2048 10240 "$SS_NGINX" "" 0
run_case "port 443 dipakai haproxy -> rc 0 (reinstall)"     0 "reinstall"         "$FULL_PATH"  kvm     2048 10240 ""      "$SS_HAPROXY" 0
run_case "multi-owner systemd+nginx -> rc 0 (warn)"         0 "akan dihentikan otomatis" "$FULL_PATH" kvm 2048 10240 "$SS_MULTI_NGINX" "" 0
run_case "multi-owner systemd+python3 -> rc 1"              1 "python3"           "$FULL_PATH"  kvm     2048 10240 "$SS_MULTI_BAD" "" 0
run_case "ss gagal (rc 2) -> rc 1 fail-closed"              1 "ss gagal diperiksa" "$FULL_PATH" kvm     2048 10240 ""      ""          0 2
run_case "openvz -> rc 1"                                   1 "openvz"            "$FULL_PATH"  openvz  2048 10240 ""      ""          0
run_case "openvz + WIBU_ALLOW_CONTAINER=1 -> rc 0"          0 ""                  "$FULL_PATH"  openvz  2048 10240 ""      ""          1
run_case "RAM 256 MB -> rc 1"                               1 "RAM 256 MB"        "$FULL_PATH"  kvm      256 10240 ""      ""          0
run_case "disk 1024 MB -> rc 1"                             1 "Disk bebas 1024"   "$FULL_PATH"  kvm     2048  1024 ""      ""          0
run_case "ss tidak ada -> rc 0 (warn)"                      0 "ss tidak tersedia" "$NO_SS_PATH" kvm     2048 10240 ""      ""          0
run_case "warning line ss + port bebas -> rc 0"             0 "Port 443 bebas"     "$FULL_PATH"  kvm     2048 10240 ""      ""          0 ""      ""      ""      1
run_case "dropbear di 143 -> rc 0 (reinstall)"              0 "reinstall"          "$FULL_PATH"  kvm     2048 10240 ""      ""          0 ""      "$SS_DROPBEAR143"
run_case "stunnel di 143 (proses asing) -> rc 1"            1 "stunnel"            "$FULL_PATH"  kvm     2048 10240 ""      ""          0 ""      "$SS_STUNNEL143"
run_case "systemd tidak ada -> rc 1"                        1 "systemd tidak terdeteksi" "$FULL_PATH" kvm 2048 10240 "" ""     0 ""      ""      ""      0 "/tmp/wibu_no_systemd_$$"
run_case "TUN tidak ada -> rc 0 (warn)"                     0 "/dev/net/tun tidak ada" "$FULL_PATH" kvm 2048 10240 "" ""      0 ""      ""      ""      0 "/run/systemd/system" "/tmp/wibu_no_tun_$$"
run_case "wget absen -> rc 0 (warn, dipasang nanti)"        0 "wget belum ada"     "$NOWGET_PATH" kvm    2048 10240 ""     ""          0
run_case "curl absen -> rc 1"                               1 "curl tidak tersedia" "$NOCURL_PATH" kvm   2048 10240 ""     ""          0
WIBU_TEST_ARCH_OVERRIDE=riscv64 run_case "arsitektur asing -> rc 1" 1 "tidak didukung" "$FULL_PATH" kvm 2048 10240 "" ""       0

# [m-01] Cabang WARN dan klasifikasi port yang tersisa.
SS_NOOWNER='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:*'
SS_SYSTEMD_ONLY='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:* users:(("systemd",pid=1,fd=1))'
SS_HAPROXY143='LISTEN 0 4096 0.0.0.0:143 0.0.0.0:* users:(("haproxy",pid=202,fd=7))'
SS_DROPBEAR80='LISTEN 0 4096 0.0.0.0:80 0.0.0.0:* users:(("dropbear",pid=404,fd=3))'
run_case "RAM 768 -> rc 0 (warn di bawah 1 GB)"             0 "di bawah 1 GB"       "$FULL_PATH"  kvm     768  10240 ""      ""          0
run_case "disk 4096 -> rc 0 (warn di bawah 5 GB)"           0 "di bawah 5 GB"       "$FULL_PATH"  kvm     2048 4096  ""      ""          0
run_case "owner socket tak terbaca -> rc 1 (fail-closed)"   1 "pemilik"            "$FULL_PATH"  kvm     2048 10240 "$SS_NOOWNER" ""      0
run_case "socket hanya systemd -> rc 0"                     0 "Prasyarat sistem terpenuhi" "$FULL_PATH" kvm 2048 10240 "$SS_SYSTEMD_ONLY" "" 0
run_case "haproxy di 143 -> rc 1"                           1 "haproxy"            "$FULL_PATH"  kvm     2048 10240 ""      ""          0 ""      "$SS_HAPROXY143"
run_case "dropbear di 80 -> rc 1"                           1 "dropbear"           "$FULL_PATH"  kvm     2048 10240 "$SS_DROPBEAR80" "" 0

echo "PREFLIGHT: $PASS PASS / $FAIL FAIL"
[[ "$FAIL" -eq 0 ]]
