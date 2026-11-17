#!/bin/bash
# ==============================================================================
# TEST SUITE: test_bot_enable.sh
# Regresi: unit telegram-bot harus "enabled" setiap kali bot dinyalakan dari menu.
# Bug yang dijaga: menu Setting -> [6] Setup Bot Telegram hanya `start`/`restart`,
# tidak pernah `enable` -> bot hidup sampai reboot pertama, lalu mati diam-diam
# (panel tetap jalan, notifikasi limit/expired hilang).
# Sifat tes: statis + offline, tidak menyentuh systemd sungguhan.
# ==============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$REPO_DIR/menu/m-setting.sh"

FAILS=0
ok()  { echo "  PASS  $1"; }
bad() { echo "  FAIL  $1"; FAILS=$((FAILS+1)); }

[[ -f "$TARGET" ]] || { echo "FAIL: $TARGET tidak ada"; exit 1; }

echo "=== [1/4] Setiap start/restart telegram-bot disertai enable ==="
python3 - "$TARGET" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()

start_re   = re.compile(r'systemctl\s+(?:start|restart)\s+[^\n]*telegram-bot')
enable_re  = re.compile(r'(?:systemctl\s+enable\b[^\n]*telegram-bot|bot_enable_guard\b)')
stop_re    = re.compile(r'systemctl\s+stop\s+[^\n]*telegram-bot')
disable_re = re.compile(r'systemctl\s+disable\b[^\n]*telegram-bot')

WINDOW = 3
def guarded(idx, pat):
    lo, hi = max(0, idx - WINDOW), min(len(lines), idx + WINDOW + 1)
    return any(pat.search(lines[j]) for j in range(lo, hi))

problems = []
for i, ln in enumerate(lines):
    if start_re.search(ln) and not guarded(i, enable_re):
        problems.append(f"baris {i+1}: {ln.strip()}")
    if stop_re.search(ln) and not guarded(i, disable_re):
        problems.append(f"baris {i+1}: {ln.strip()}")

if problems:
    print("TANPA_ENABLE " + str(len(problems)))
    for p in problems:
        print("  " + p)
    sys.exit(1)

n_enable = sum(1 for ln in lines if enable_re.search(ln))
if n_enable < 2:
    print(f"ENABLE_KURANG hanya {n_enable} pemanggilan enable (harap >= 2)")
    sys.exit(1)
print(f"OK {n_enable} pemanggilan enable, semua start/restart terjaga")
PY
[[ $? -eq 0 ]] && ok "start/restart selalu diikuti enable (dan stop diikuti disable)" \
                || bad "ada start/restart telegram-bot tanpa enable pasangannya"

echo "=== [2/4] Status boot ditampilkan di menu (bisa diaudit user) ==="
if grep -q 'is-enabled telegram-bot' "$TARGET"; then
    ok "menu menampilkan status boot bot (is-enabled)"
else
    bad "menu tidak menampilkan status boot bot -> user tak tahu bot akan mati saat reboot"
fi

echo "=== [3/4] Pesan sukses menyebut ketahanan reboot ==="
if grep -qiE 'otomatis (hidup|aktif|jalan).{0,40}(reboot|boot)|enabled.{0,30}reboot|tahan reboot' "$TARGET"; then
    ok "konfirmasi ke user menyebut bot hidup lagi setelah reboot"
else
    bad "pesan sukses tidak memberi tahu bahwa bot otomatis aktif setelah reboot"
fi

echo "=== [4/4] setup.sh tetap tidak mengaktifkan unit tanpa token ==="
if grep -q "unit tidak diaktifkan" "$REPO_DIR/setup.sh" \
   && grep -q 'systemctl disable telegram-bot.service' "$REPO_DIR/setup.sh"; then
    ok "instalasi tanpa token tetap tidak meng-enable unit (tidak ada status failed)"
else
    bad "guard instalasi tanpa token hilang/berubah"
fi

echo
if [[ $FAILS -eq 0 ]]; then
    echo "=== ALL BOT-ENABLE TESTS PASSED ==="
    exit 0
else
    echo "=== $FAILS TES GAGAL ==="
    exit 1
fi
