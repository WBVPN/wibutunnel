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
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { echo "  [OK]    $1"; }
bad() { echo "  [GAGAL] $1"; fail=1; }
# Hash WAJIB dihitung dari berkas: $(command substitution) membuang newline terakhir
# sehingga hash-nya beda dan memunculkan alarm palsu.
hashf() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
unduh() { # $1=url tujuan-berkas $2=url sumber [3=accept]
    local out="$1" url="$2" acc="${3:-}"
    if [[ -n "$acc" ]]; then "${CURL[@]}" -H "Accept: $acc" -o "$out" "$url"; else "${CURL[@]}" -o "$out" "$url"; fi
}

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

ins_ok=1
unduh "$TMP/install.sh" "$DL/install.sh" || ins_ok=0
ref="$(sed -n 's/^REF="${WIBU_REF:-\(v[0-9.]*\)}".*/\1/p' "$TMP/install.sh" | head -1)"
exp="$(sed -n 's/^EXPECT="\([0-9a-f]\{64\}\)".*/\1/p' "$TMP/install.sh" | head -1)"
[[ -n "$ref" ]] && ok "install.sh menunjuk tag: $ref" || bad "install.sh tidak memuat REF"
[[ "$ref" == "$tag" ]] && ok "REF == tag rilis terbaru" || bad "REF ($ref) != tag rilis ($tag)"
[[ -n "$exp" ]] && ok "install.sh memuat EXPECT: ${exp:0:16}..." || bad "install.sh tidak memuat EXPECT"

# 3. setup.sh pada tag itu harus ber-hash sama dengan EXPECT
unduh "$TMP/setup.sh" "$API/contents/setup.sh?ref=$tag" "application/vnd.github.raw" || unduh "$TMP/setup.sh" "$DL/setup.sh" || bad "gagal mengambil setup.sh pada tag $tag"
got="$(hashf "$TMP/setup.sh")"
[[ -n "$exp" && "$got" == "$exp" ]] && ok "hash setup.sh cocok dengan EXPECT" || bad "hash setup.sh ($got) != EXPECT ($exp)"

# 4. manifest & uninstall pada tag itu
unduh "$TMP/SHA256SUMS" "$API/contents/SHA256SUMS?ref=$tag" "application/vnd.github.raw" || unduh "$TMP/SHA256SUMS" "$DL/SHA256SUMS" || bad "gagal mengambil SHA256SUMS pada tag $tag"
n_man="$(grep -c . "$TMP/SHA256SUMS" 2>/dev/null || echo 0)"
[[ "$n_man" -gt 0 ]] && ok "manifest terbaca: $n_man entri" || bad "manifest kosong/tidak terbaca"
grep -qE "^$got  setup.sh$" "$TMP/SHA256SUMS" && ok "manifest memuat hash setup.sh yang benar" || bad "manifest tidak memuat hash setup.sh yang benar"
unduh "$TMP/uninstall.sh" "$API/contents/uninstall.sh?ref=$tag" "application/vnd.github.raw" || unduh "$TMP/uninstall.sh" "$DL/uninstall.sh" || bad "gagal mengambil uninstall.sh pada tag $tag"
hu="$(hashf "$TMP/uninstall.sh")"
grep -qE "^$hu  uninstall.sh$" "$TMP/SHA256SUMS" && ok "manifest memuat hash uninstall.sh yang benar" || bad "manifest tidak memuat hash uninstall.sh yang benar"

echo
if [[ $fail -eq 0 ]]; then
    echo "HASIL: rantai instalasi VALID untuk VPS baru (tag $tag)."
    echo "Perintah pasang (interaktif — domain & bot ditanyakan):"
    echo "    curl -4 -fsSL -o install.sh $DL/install.sh && bash install.sh"
    echo "Perintah pasang (satu baris tanpa TTY — domain WAJIB jadi argumen):"
    echo "    curl -4 -fsSL $DL/install.sh | bash -s -- vpn.domain-anda.com"
else
    echo "HASIL: ADA YANG GAGAL - jangan sebarkan link ini sampai diperbaiki."
fi
exit $fail
