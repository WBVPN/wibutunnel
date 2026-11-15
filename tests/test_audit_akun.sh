#!/bin/bash
# ==========================================================================
# Uji wibu-audit-akun di VPS (bukan mock).
# Skenario yang diuji: klien ditambahkan langsung ke config Xray TANPA catatan
# exp (= tidak akan pernah kedaluwarsa). Audit harus menemukannya, --fix harus
# menulis catatan exp, dan algojo-expired harus mengarantinanya lewat recovery.
# Bersih-bersih lewat trap supaya kegagalan tidak meninggalkan data uji.
# ==========================================================================
set -u
AUDIT=/usr/local/sbin/wibu-audit-akun
[[ -x "$AUDIT" ]] || { echo "SKIP: wibu-audit-akun belum terpasang"; exit 0; }
source /usr/local/bin/common.sh 2>/dev/null || true

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS  $1"; PASS=$((PASS+1)); else echo "  FAIL  $1 (dapat '$2', harap '$3')"; FAIL=$((FAIL+1)); fi; }

U="uji-audit-$$"
EXP=/etc/xray/vless_exp.conf
BAK="$(mktemp)"
cp -a "$EXP" "$BAK" 2>/dev/null || : > "$BAK"

cleanup() {
    cp -a "$BAK" "$EXP" 2>/dev/null || true
    rm -f "$BAK"
    safe_jq_edit_args --arg u "$U" '.inbounds[] | if .settings.clients then .settings.clients |= map(select(.email != $u)) else . end' >/dev/null 2>&1 || true
    rm -f "/etc/wibutunnel/recovery/${U}.json"
}
trap cleanup EXIT

# 1. Klien di config TANPA catatan exp
i=$(xray_primary_index VLESS 2>/dev/null); jid=$(cat /proc/sys/kernel/random/uuid)
safe_jq_edit_args --arg u "$U" --arg id "$jid" --argjson i "$i" \
    '.inbounds[$i].settings.clients += [{"id":$id,"email":$u,"level":0,"flow":""}]' >/dev/null 2>&1

out=$("$AUDIT" 2>&1); rc=$?
ck "1. akun tanpa exp dilaporkan" "$(printf '%s' "$out" | grep -c "$U")" "1"
ck "2. keluar != 0 saat ada temuan" "$([[ $rc -ne 0 ]] && echo ya || echo tidak)" "ya"

# 2. --fix menulis catatan exp
"$AUDIT" --fix >/dev/null 2>&1
ck "3. --fix menulis catatan exp" "$(grep -c "^${U}:" "$EXP" 2>/dev/null)" "1"

# 3. algojo-expired mengarantina lewat recovery (jalur yang sudah ada)
timeout 120 /usr/local/sbin/algojo-expired >/dev/null 2>&1
ck "4. klien dicabut dari config" "$(jq -r --arg u "$U" '[.inbounds[].settings.clients[]? | select(.email==$u)] | length' /usr/local/etc/xray/config.json 2>/dev/null)" "0"
ck "5. sidecar recovery dibuat" "$([[ -s "/etc/wibutunnel/recovery/${U}.json" ]] && echo ada || echo tidak)" "ada"
ck "6. xray tetap valid" "$(xray -test -config /usr/local/etc/xray/config.json 2>&1 | grep -c 'Configuration OK')" "1"
ck "7. audit bersih setelah perbaikan" "$([[ $("$AUDIT" 2>/dev/null | grep -c "$U") -eq 0 ]] && echo bersih || echo masih)" "bersih"

echo "=========== AUDIT AKUN: $PASS PASS / $FAIL FAIL ==========="
[[ $FAIL -eq 0 ]]
