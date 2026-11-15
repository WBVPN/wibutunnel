#!/bin/bash
# ==========================================================================
#  tools/verify-release.sh - verifikasi rantai instalasi rilis terbaru
#
#  Memeriksa bahwa link yang dipakai VPS BARU benar-benar valid:
#    github.com/WBVPN/wibutunnel/releases/latest/download/install.sh
#
#  Pakai : bash tools/verify-release.sh
#  Sifat : hanya membaca (tidak mengubah apa pun di VPS/repo). Butuh internet.
#  Keluar dengan kode != 0 kalau ada satu pemeriksaan yang gagal.
# ==========================================================================
set -uo pipefail

REPO="WBVPN/wibutunnel"
API="https://api.github.com/repos/$REPO"
DL="https://github.com/$REPO/releases/latest/download"
CURL=(curl -4 -fsSL --max-time 60 -H "User-Agent: wibutunnel-verify")
fail=0
ok()  { echo "  [OK]   $1"; }
bad() { echo "  [GAGAL] $1"; fail=1; }

echo "== Verifikasi rilis $REPO =="

# 1. rilis terbaru + asetnya
rel="$("${CURL[@]}" "$API/releases/latest" || true)"
tag="$(printf '%s' "$rel" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
[[ -n "$tag" ]] && ok "rilis terbaru: $tag" || bad "tidak bisa membaca rilis terbaru"
for a in install.sh setup.sh uninstall.sh SHA256SUMS; do
    if printf '%s' "$rel" | grep -q "\"name\": *\"$a\""; then ok "aset ada: $a"; else bad "aset HILANG: $a"; fi
done

# 2. link publik yang dipakai VPS baru (ikuti redirect GitHub)
code="$(curl -4 -s -o /dev/null -w '%{http_code}' -L --max-time 60 "$DL/install.sh" || echo 000)"
[[ "$code" == "200" ]] && ok "link publik install.sh menjawab 200" || bad "link publik install.sh menjawab $code"

ins="$("${CURL[@]}" "$DL/install.sh" || true)"
ref="$(printf '%s' "$ins" | sed -n 's/^REF="${WIBU_REF:-\(v[0-9.]*\)}".*/\1/p' | head -1)"
exp="$(printf '%s' "$ins" | sed -n 's/^EXPECT="\([0-9a-f]\{64\}\)".*/\1/p' | head -1)"
[[ -n "$ref" ]] && ok "install.sh menunjuk tag: $ref" || bad "install.sh tidak memuat REF"
[[ "$ref" == "$tag" ]] && ok "REF == tag rilis terbaru" || bad "REF ($ref) != tag rilis ($tag)"
[[ -n "$exp" ]] && ok "install.sh memuat EXPECT: ${exp:0:16}..." || bad "install.sh tidak memuat EXPECT"

# 3. setup.sh pada tag itu harus ber-hash sama dengan EXPECT
setup="$("${CURL[@]}" -H "Accept: application/vnd.github.raw" "$API/contents/setup.sh?ref=$tag" || true)"
[[ -z "$setup" ]] && setup="$("${CURL[@]}" "$DL/setup.sh" || true)"
got="$(printf '%s' "$setup" | sha256sum | cut -d' ' -f1)"
[[ -n "$exp" && "$got" == "$exp" ]] && ok "hash setup.sh cocok dengan EXPECT" || bad "hash setup.sh ($got) != EXPECT ($exp)"

# 4. manifest & uninstall pada tag itu
man="$("${CURL[@]}" -H "Accept: application/vnd.github.raw" "$API/contents/SHA256SUMS?ref=$tag" || true)"
[[ -n "$man" ]] && ok "manifest terbaca: $(printf '%s\n' "$man" | grep -c .) entri" || bad "manifest tidak terbaca"
printf '%s\n' "$man" | grep -qE "^$got  setup.sh$"  && ok "manifest memuat hash setup.sh yang benar" || bad "manifest tidak memuat hash setup.sh yang benar"
unin="$("${CURL[@]}" -H "Accept: application/vnd.github.raw" "$API/contents/uninstall.sh?ref=$tag" || true)"
hu="$(printf '%s' "$unin" | sha256sum | cut -d' ' -f1)"
printf '%s\n' "$man" | grep -qE "^$hu  uninstall.sh$" && ok "manifest memuat hash uninstall.sh yang benar" || bad "manifest tidak memuat hash uninstall.sh yang benar"

echo
if [[ $fail -eq 0 ]]; then
    echo "HASIL: rantai instalasi VALID untuk VPS baru (tag $tag)."
    echo "Perintah pasang:  curl -4 -fsSL $DL/install.sh | bash"
else
    echo "HASIL: ADA YANG GAGAL - jangan sebarkan link ini sampai diperbaiki."
fi
exit $fail
