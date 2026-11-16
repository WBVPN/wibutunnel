#!/bin/bash
# ==========================================================================
# Uji NYATA gerbang lisensi. Versi sebelumnya hanya MENGULANG logikanya
# sendiri lalu menguji ulang salinannya (tautologi) + `REPO_DIR` dikunci ke
# "/root/wibutunnel-repo", jadi tidak membuktikan apa pun soal kode asli.
# Sekarang: panggil fungsi ASLI `check_license` dari common.sh.
# Jalankan: bash tests/test_license_enforcement.sh
# ==========================================================================
set -u
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ck() { # $1=nama $2=dapat $3=harap
    if [[ "$2" == "$3" ]]; then echo "  PASS  $1"; PASS=$((PASS+1));
    else echo "  FAIL  $1 (dapat '$2', harap '$3')"; FAIL=$((FAIL+1)); fi
}

LIST="$TMP/izin.txt"; CACHE="$TMP/license.cache"; DEAD="file://$TMP/tidak-ada.txt"

# $1=nama $2=ip $3=isi-daftar $4=cache $5=url $6=harap (ALLOW|DENY|EXPIRED)
case_run() {
    local name="$1" ip="$2" list="$3" cache="$4" url="$5" harap="$6"
    printf '%s\n' "$list" > "$LIST"
    rm -f "$CACHE"; [[ -n "$cache" ]] && printf '%s\n' "$cache" > "$CACHE"
    local out rc got
    out=$(MYIP="$ip" LICENSE_URL="$url" LICENSE_MIRROR="" LICENSE_CACHE="$CACHE" LICENSE_OFFLINE_GRACE=604800 \
        bash -c "source '$REPO_DIR/common.sh' >/dev/null 2>&1; check_license; echo \"ALLOW|CLIENT=\$CLIENT_NAME|EXP=\$EXP_DATE\"" 2>&1)
    rc=$?
    got="RC=$rc"
    [[ "$out" == *"ALLOW|"* ]] && got="ALLOW"
    [[ "$out" == *"KEDALUWARSA"* ]] && got="EXPIRED"
    [[ "$got" == "RC=1" ]] && got="DENY"
    ck "$name" "$got" "$harap"
}

U="file://$LIST"
case_run "1. IP tidak terdaftar -> ditolak" "192.168.1.100" \
"### USER EXP IP
### USER1 2099-12-31 10.0.0.1" "" "$U" "DENY"

case_run "2. Lisensi kedaluwarsa -> ditolak" "192.168.1.100" \
"### USER EXP IP
### EXPIRED_USER 2020-01-01 192.168.1.100" "" "$U" "EXPIRED"

case_run "3. Lisensi aktif -> lolos" "192.168.1.100" \
"### USER EXP IP
### USER1 2099-12-31 192.168.1.100" "" "$U" "ALLOW"

case_run "4. lifetime -> lolos" "192.168.1.100" \
"### USER EXP IP
### USER1 lifetime 192.168.1.100" "" "$U" "ALLOW"

case_run "5. IP mirip tidak boleh cocok (.85 vs .84)" "103.150.60.85" \
"### USER EXP IP
### USER1 2099-12-31 103.150.60.84" "" "$U" "DENY"

case_run "6. Entri rusak (tanpa tanggal) -> ditolak" "192.168.1.100" \
"### USER EXP IP
### USER1 192.168.1.100" "" "$U" "DENY"

case_run "7. Cache milik IP LAIN tidak dipercaya" "192.168.1.100" \
"### USER EXP IP
### USER1 2099-12-31 10.0.0.1" "VALID|USER1|2099-12-31|9.9.9.9" "$U" "DENY"

case_run "8. Offline + cache segar (IP sama) -> lolos" "192.168.1.100" \
"### USER EXP IP" "VALID|USER1|2099-12-31|192.168.1.100" "$DEAD" "ALLOW"

case_run "9. Cache kedaluwarsa -> ditolak walau offline" "192.168.1.100" \
"### USER EXP IP" "VALID|USER1|2020-01-01|192.168.1.100" "$DEAD" "EXPIRED"

# 10. Sumber bawaan = daftar resmi (bukan berkas lokal)
D=$(grep -m1 '^LICENSE_URL=' "$REPO_DIR/common.sh" | grep -c 'raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt')
ck "10. sumber bawaan = daftar resmi GitHub" "$D" "1"

# 11. Gerbang instalasi tidak lagi memercayai ./izin.txt di direktori kerja
L=$(grep -c '"./izin.txt"' "$REPO_DIR/setup.sh" || true)
ck "11. setup.sh tidak memercayai ./izin.txt lokal" "$L" "0"

# 12. Cache menyimpan IP (syarat kasus 7 & 8 bisa bekerja)
C=$(grep -c 'VALID|%s|%s|%s' "$REPO_DIR/common.sh" || true)
ck "12. cache lisensi menyimpan IP" "$C" "1"

# 13-15. Label tampilan masa aktif (aturan pemilik): lifetime apa adanya,
#        entri bertanggal -> "( N Hari )" saja, tanggal lampau -> 0 hari.
LB=$(. "$REPO_DIR/common.sh" >/dev/null 2>&1; license_expiry_label lifetime)
ck "13. label lifetime apa adanya, tanpa tambahan" "$LB" "lifetime"

ok=0
D=$(. "$REPO_DIR/common.sh" >/dev/null 2>&1; license_days_left "$(date -u -d '+30 days' +%F)")
[[ "$D" =~ ^[0-9]+$ ]] && [[ $D -ge 29 && $D -le 31 ]] && ok=1
ck "14. sisa hari untuk +30 hari (~30)" "$ok" "1"

LBP=$(. "$REPO_DIR/common.sh" >/dev/null 2>&1; license_expiry_label "2020-01-01")
ck "15. tanggal lampau -> '0 Hari', bukan negatif" "$LBP" "0 Hari"

echo "=========== LISENSI: $PASS PASS / $FAIL FAIL ==========="
[[ $FAIL -eq 0 ]]
