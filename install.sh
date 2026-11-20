#!/bin/bash
# ==========================================================================
#  Bootstrap instalasi Wibutunnel — SATU perintah, domain ditanya saat proses.
#  Unduh setup.sh dari TAG RILIS -> verifikasi sha256 -> baru jalankan.
#
#  PASANG (interaktif; domain & bot ditanyakan di tengah proses):
#      bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)
#
#  Bentuk lain yang juga jalan:
#      curl -4 -fsSL <url install.sh> | bash            # terminal disambungkan otomatis
#      curl -4 -fsSL -o install.sh <url> && bash install.sh
#
#  Verifikasi saja (tidak memasang apa pun) — cetak tag + hash lalu keluar:
#      WIBU_BOOTSTRAP_ONLY=1 bash <(curl -4 -fsSL <url install.sh>)
#
#  Otomasi TANPA terminal (cron/CI): domain WAJIB jadi argumen, karena tidak ada
#  yang bisa menjawab pertanyaan domain:
#      curl -4 -fsSL <url install.sh> | bash -s -- vpn.domain-anda.com
#
#  CATATAN stdin (penting, jangan diubah tanpa membaca ini):
#  `... | bash` membuat fd 0 = pipa yang sudah habis, dan proses setup.sh yang
#  di-`exec` MEWARISINYA -> pertanyaan domain dijawab EOF. Karena itu terminal
#  diserahkan eksplisit ke proses anak (`exec ... </dev/tty`), BUKAN dengan
#  mengganti fd 0 di tengah skrip: pada mode pipa bash membaca sisa skrip dari
#  fd 0, jadi `exec </dev/tty` di sini akan membuat bash membaca perintah dari
#  terminal, bukan dari skrip.
# ==========================================================================
set -eu

have_tty() { { : </dev/tty; } 2>/dev/null; }

# Tidak ada terminal DAN tidak ada domain -> pertanyaan domain mustahil dijawab.
# Berhenti di sini, sebelum apt/konfigurasi disentuh, dengan pesan yang bisa ditindaklanjuti.
if [[ $# -eq 0 && -z "${DOMAIN:-}" && ! -t 0 ]] && ! have_tty && [[ "${WIBU_BOOTSTRAP_ONLY:-0}" != "1" ]]; then
    echo "[!] Tidak ada terminal dan domain belum diberikan." >&2
    echo "    Pertanyaan domain tidak bisa dijawab, jadi instalasi dihentikan di sini." >&2
    echo "    Di VPS dengan terminal (domain ditanya otomatis):" >&2
    echo "      bash <(curl -4 -fsSL <url install.sh>)" >&2
    echo "    Otomasi tanpa TTY (domain sebagai argumen):" >&2
    echo "      curl -4 -fsSL <url install.sh> | bash -s -- vpn.domain-anda.com" >&2
    exit 1
fi

REF="${WIBU_REF:-v4.1.46}"
EXPECT="3e7e14247320b90e05a1ca627171128610bdcd1d73dfb41f0acf7fb53a37e403"
PRIMARY="https://raw.githubusercontent.com/WBVPN/wibutunnel/$REF/setup.sh"
MIRROR="https://cdn.jsdelivr.net/gh/WBVPN/wibutunnel@$REF/setup.sh"

echo "== Bootstrap Wibutunnel =="
echo "   tag rilis : $REF"
echo "   harap     : ${EXPECT:0:16}..."

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
unduh() {
    curl -4 -fsSL --retry 3 --connect-timeout 10 --max-time 90 -o "$TMP" "$1"
}
if ! unduh "$PRIMARY" 2>/dev/null; then
    echo "   GitHub mentok, pakai mirror jsDelivr..."
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
echo "   hash      : OK (${GOT:0:16}...)"
[[ "${WIBU_BOOTSTRAP_ONLY:-0}" == "1" ]] && { echo "   [i] WIBU_BOOTSTRAP_ONLY=1 — instalasi tidak dijalankan."; exit 0; }

echo "   menjalankan instalasi..."
echo "----------------------------------------------------------------------"
# Serahkan terminal ke setup.sh bila stdin bukan TTY (mode pipa): pertanyaan domain
# dibaca dari /dev/tty, bukan dari fd 0 yang sudah EOF. Ini baris terakhir skrip,
# jadi fd 0 milik bash sendiri tidak dipakai lagi setelah titik ini.
if [[ ! -t 0 ]] && have_tty; then
    exec bash "$TMP" "$@" </dev/tty
fi
exec bash "$TMP" "$@"