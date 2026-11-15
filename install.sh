#!/bin/bash
# ==========================================================================
#  Bootstrap instalasi Wibutunnel
#  Unduh setup.sh dari TAG RILIS -> verifikasi sha256 -> baru jalankan.
#  Aman untuk satu baris:   curl -4 -fsSL https://wibu.loli.web.id/i | bash
#  Verifikasi saja (tidak memasang apa pun):
#      curl -4 -fsSL https://wibu.loli.web.id/i | WIBU_BOOTSTRAP_ONLY=1 bash
# ==========================================================================
set -eu

REF="${WIBU_REF:-v4.1.16}"
EXPECT="ff51b9de2452bfedb4cd17f40a602407ce7e68713b03b87e1481f38b184e2af5"
PRIMARY="https://raw.githubusercontent.com/WBVPN/wibutunnel/$REF/setup.sh"
MIRROR="https://cdn.jsdelivr.net/gh/WBVPN/wibutunnel@$REF/setup.sh"

echo "== Bootstrap Wibutunnel =="
echo "   tag rilis : $REF"
echo "   harap     : ${EXPECT:0:16}…"

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
unduh() {
    curl -4 -fsSL --retry 3 --connect-timeout 10 --max-time 90 -o "$TMP" "$1"
}
if ! unduh "$PRIMARY" 2>/dev/null; then
    echo "   GitHub mentok, pakai mirror jsDelivr…"
    unduh "$MIRROR"
fi
[[ -s "$TMP" ]] || { echo "[!] gagal mengunduh setup.sh" >&2; exit 1; }

GOT="$(sha256sum "$TMP" | awk '{print $1}')"
if [[ "$GOT" != "$EXPECT" ]]; then
    echo "[!] HASH TIDAK COCOK — BERHENTI sebelum menjalankan apa pun." >&2
    echo "    harap : $EXPECT" >&2
    echo "    dapat : $GOT" >&2
    echo "    (tag lain? pakai cara manual: lihat README)" >&2
    exit 1
fi
echo "   hash      : OK (${GOT:0:16}…)"
[[ "${WIBU_BOOTSTRAP_ONLY:-0}" == "1" ]] && { echo "   [i] WIBU_BOOTSTRAP_ONLY=1 — instalasi tidak dijalankan."; exit 0; }

echo "   menjalankan instalasi…"
echo "----------------------------------------------------------------------"
exec bash "$TMP" "$@"
