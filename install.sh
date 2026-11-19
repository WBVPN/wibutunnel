#!/bin/bash
# ==========================================================================
#  Bootstrap instalasi Wibutunnel
#  Unduh setup.sh dari TAG RILIS -> verifikasi sha256 -> baru jalankan.
#
#  Interaktif (domain & bot ditanyakan) — unduh berkasnya dulu:
#      curl -4 -fsSL -o install.sh https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh
#      bash install.sh
#
#  Satu baris tanpa TTY — domain WAJIB jadi argumen:
#      curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh | bash -s -- vpn.domain-anda.com
#
#  Verifikasi saja (tidak memasang apa pun):
#      curl -4 -fsSL <url install.sh> | WIBU_BOOTSTRAP_ONLY=1 bash
#
#  KENAPA domain wajib di mode pipa: `... | bash` membuat stdin berisi skrip ini,
#  dan proses setup.sh yang di-`exec` MEWARISINYA (sudah EOF) -> pertanyaan domain
#  tidak bisa dijawab ("Input berakhir (EOF)"). Penjaga dini di bawah menghentikan
#  mode itu dengan pesan jelas, sebelum menyentuh apt/konfigurasi.
# ==========================================================================
set -eu

# Mode pipa tanpa domain = pasti gagal di tengah jalan (stdin EOF). Berhenti di sini.
if [[ $# -eq 0 && -z "${DOMAIN:-}" && ! -t 0 ]]; then
    echo "[!] stdin bukan terminal dan domain belum diberikan." >&2
    echo "    Ini yang dimaksud 'mode pipa': stdin habis dipakai membaca skrip ini," >&2
    echo "    jadi pertanyaan domain tidak bisa dijawab." >&2
    echo "    Pakai salah satu:" >&2
    echo "      curl -4 -fsSL <url install.sh> | bash -s -- vpn.domain-anda.com" >&2
    echo "      curl -4 -fsSL -o install.sh <url install.sh> && bash install.sh" >&2
    exit 1
fi

REF="${WIBU_REF:-v4.1.41}"
EXPECT="030f0fd214caf4e32b46ff9e7118f5200e4aeae2e93f57699cecc8a85b1e837c"
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
