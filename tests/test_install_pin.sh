#!/usr/bin/env bash
# [F6] Penjaga sinkronisasi pin installer.
# install.sh mengunduh setup.sh dari tag $WIBU_REF lalu membandingkan sha256-nya
# dengan $EXPECT. Kalau setup.sh diedit setelah tag (atau EXPECT lupa di-bump),
# SEMUA user ditolak installer. Tes ini menangkap kondisi itu sebelum dirilis.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  PASS  $1"; }
no()  { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

echo "== install.sh pin =="

ref=$(sed -n 's/^REF="\${WIBU_REF:-\([^}]*\)}".*/\1/p' install.sh | head -1)
exp=$(sed -n 's/^EXPECT="\([^"]*\)".*/\1/p' install.sh | head -1)

[[ -n "$ref" ]] && ok "WIBU_REF terbaca: $ref" || no "WIBU_REF tidak ditemukan di install.sh"
[[ "$exp" =~ ^[0-9a-f]{64}$ ]] && ok "EXPECT berformat sha256" || no "EXPECT bukan sha256: '$exp'"

if [[ -n "$ref" && -n "$exp" ]]; then
    if git rev-parse -q --verify "refs/tags/$ref" >/dev/null 2>&1; then
        got=$(git show "$ref:setup.sh" | sha256sum | cut -d' ' -f1)
        if [[ "$got" == "$exp" ]]; then
            ok "EXPECT == sha256 setup.sh@$ref"
        else
            no "EXPECT ($exp) != sha256 setup.sh@$ref ($got)"
        fi
    else
        echo "  SKIP  tag $ref tidak ada di clone ini (jalankan di clone penuh)"
    fi
fi

# SHA256SUMS harus mencerminkan SELURUH isi working tree, bukan hanya setup.sh.
if [[ -f SHA256SUMS ]]; then
    if sha256sum -c SHA256SUMS >/tmp/install_pin_chk.$$ 2>&1; then
        ok "sha256sum -c SHA256SUMS bersih ($(wc -l < SHA256SUMS) entri)"
    else
        no "sha256sum -c SHA256SUMS gagal: $(grep -c FAILED /tmp/install_pin_chk.$$) entri"
        grep FAILED /tmp/install_pin_chk.$$ | sed 's/^/        /' | head -5
    fi
    rm -f /tmp/install_pin_chk.$$
    dup=$(awk '$2 == "setup.sh" {c++} END {print c+0}' SHA256SUMS)
    [[ "$dup" == "1" ]] && ok "entri setup.sh unik di SHA256SUMS" || no "entri setup.sh tidak unik ($dup)"
else
    no "SHA256SUMS tidak ada"
fi

echo "INSTALL_PIN: $PASS PASS / $FAIL FAIL"
[[ $FAIL -eq 0 ]]
