#!/bin/bash
# ==========================================================================
# Perbarui PIN SHA256 installer Xray di setup.sh.
# Alasan: installer Xray di-pin (anti root-RCE bila hulu XTLS diretas). Kalau
# XTLS merilis ulang skripnya, pin lama membuat instalasi DITOLAK (fail-closed).
# Jalankan skrip ini, tinjau perubahannya, lalu commit (SHA256SUMS wajib dibuat
# ulang bersama setup.sh).
# Pakai: bash tools/update-xray-pin.sh [URL]
# ==========================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
URL="${1:-https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "[+] Mengunduh: $URL"
curl -4 -fsSL --max-time 60 --connect-timeout 10 -o "$TMP/install-release.sh" "$URL"
NEW=$(sha256sum "$TMP/install-release.sh" | cut -d' ' -f1)
OLD=$(grep -oE 'XRAY_INSTALL_SHA256="\$\{XRAY_INSTALL_SHA256:-[0-9a-f]{64}' "$REPO/setup.sh" | grep -oE '[0-9a-f]{64}$' || true)
echo "[i] Pin lama : ${OLD:-<tidak ada>}"
echo "[i] Pin baru : $NEW"
if [[ "$OLD" == "$NEW" ]]; then echo "[✓] Pin sudah terbaru, tidak ada perubahan."; exit 0; fi
sed -i "s|$OLD|$NEW|" "$REPO/setup.sh"
if ! grep -q "$NEW" "$REPO/setup.sh"; then echo "[✗] Gagal menulis pin baru."; exit 1; fi
echo "[✓] Pin diperbarui di setup.sh:"
grep -n 'XRAY_INSTALL_SHA256' "$REPO/setup.sh" | head -3
echo "[!] Langkah lanjut: jalankan (a) bash tests/test_hardening.sh,"
echo "    (b) bash tests/test_license_enforcement.sh, (c) buat ulang SHA256SUMS,"
echo "       (d) commit + pindahkan tag v4.0.6-fixed."
