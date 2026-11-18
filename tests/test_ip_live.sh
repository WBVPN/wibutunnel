#!/bin/bash
# ==========================================
# UJI: limit IP berdasarkan KONEKSI YANG BENAR-BENAR HIDUP (v4.1.39)
#
# Masalah: IP xray dihitung dari access.log dengan jendela 600 detik, jadi
# pelanggan yang sudah berhenti konek masih dihitung sebagai "aktif" sampai
# 10 menit. Konsekuensinya: pindah jaringan (WiFi -> data) dalam rentang itu
# terhitung 2 IP -> kena kunci padahal satu orang.
#
# Aturan baru yang diuji:
#   XRAY : IP dianggap aktif hanya bila ada trafik di log <= 60 detik terakhir.
#   SSH  : dihitung HANYA dari socket ESTABLISHED milik dropbear/sshd
#          (bukan dari catatan log lama).
#
# Semua bahan uji adalah berkas contoh -> nol sentuhan sistem.
# ==========================================
set -u
export PYTHONDONTWRITEBYTECODE=1

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/uji-iplive.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

echo "=== UJI LIMIT IP: HANYA KONEKSI HIDUP ==="
echo
source "$REPO/common.sh" >/dev/null 2>&1 || { bad "common.sh gagal di-source"; exit 1; }

# ---------- bagian 1: jendela XRAY 60 detik ----------
echo "--- 1: jendela aktivitas xray (<= 60 dtk) ---"
LOG="$TMP/access.log"
mkline() { # $1=detik-lalu $2=user  ; 2 ruas IP supaya tidak bisa lolos "kebetulan"
    local t ip
    t=$(date -d "$1 seconds ago" '+%Y/%m/%d %H:%M:%S.000000')
    printf '%s from 43.156.147.95:34738 accepted tcp:example.com:443 [vless-ws-ntls >> direct] email: %s\n' "$t" "$2" >> "$LOG"
}
# ditulis berurutan seperti log sungguhan (lama -> baru); fungsi pembaca
# berhenti saat menemui baris yang lebih tua dari jendela, jadi urutannya penting
mkline 601 user601
mkline 600 user600
mkline 61 user61
mkline 59 user59
mkline 30 user30

OUT=$(XRAY_ACCESS_LOG="$LOG" live_ip_pairs 2>/dev/null)

for u in user30 user59; do
    if echo "$OUT" | awk -v u="$u" '$1==u' | grep -q .; then ok "$u (<=60 dtk) dihitung aktif"; else bad "$u (<=60 dtk) TIDAK dihitung"; fi
done
for u in user61 user600 user601; do
    if echo "$OUT" | awk -v u="$u" '$1==u' | grep -q .; then bad "$u (>60 dtk) MASIH dihitung aktif"; else ok "$u (>60 dtk) tidak lagi dihitung"; fi
done

OUT120=$(XRAY_ACCESS_LOG="$LOG" LIVE_IP_WINDOW=120 live_ip_pairs 2>/dev/null)
if echo "$OUT120" | awk '$1=="user61"' | grep -q .; then ok "jendela bisa diubah (LIVE_IP_WINDOW=120 -> user61 masuk)"; else bad "LIVE_IP_WINDOW diabaikan"; fi

# ---------- bagian 2: SSH hanya socket ESTABLISHED ----------
echo
echo "--- 2: sesi SSH dari socket hidup (bukan catatan log) ---"
SS="$TMP/ss.txt"
cat > "$SS" <<'EOF'
0          0                  103.150.60.84:143      43.156.147.95:34738     users:(("dropbear",pid=111,fd=3))
0          0                  103.150.60.84:143      198.51.100.7:2201       users:(("dropbear",pid=222,fd=4))
0          0                  103.150.60.84:59000    203.0.113.9:51000       users:(("nginx",pid=333,fd=5))
EOF
ALOG="$TMP/dropbear.txt"
cat > "$ALOG" <<'EOF'
Nov 18 00:10:00 VPSTEST dropbear[111]: [111] Nov 18 00:10:00 Password auth succeeded for 'userA' from 43.156.147.95:34738
Nov 18 00:11:00 VPSTEST dropbear[222]: [222] Nov 18 00:11:00 Pubkey auth succeeded for 'userB' from 198.51.100.7:2201
Nov 17 23:00:00 VPSTEST dropbear[999]: [999] Nov 17 23:00:00 Password auth succeeded for 'userLAMA' from 203.0.113.9:51000
EOF

export SSH_SS_SRC="$SS" SSH_AUTH_LOG_SRC="$ALOG"
# pemetaan pid->user dibuat eksplisit supaya uji tidak bergantung proses nyata
ssh_pid_session_user() {
    case "$1" in
        111) printf 'userA' ;;
        222) printf 'userB' ;;
        333) printf 'sesiNginx' ;;   # socket non-sesi; harus disaring oleh daftar port
        *)   return 1 ;;
    esac
}
SNAP=$(ssh_sessions_snapshot 2>/dev/null)
if echo "$SNAP" | grep -q "^userA"; then ok "userA (socket ESTABLISHED) terdeteksi"; else bad "userA tidak terdeteksi"; fi
if echo "$SNAP" | grep -q "^userB"; then ok "userB (socket ESTABLISHED) terdeteksi"; else bad "userB tidak terdeteksi"; fi
if echo "$SNAP" | grep -q "^userLAMA"; then bad "userLAMA (hanya catatan log, tanpa socket) IKUT dihitung"; else ok "userLAMA (tanpa socket) tidak dihitung"; fi
if echo "$SNAP" | grep -q "^sesiNginx"; then bad "socket non-sesi (port 59000) ikut terhitung"; else ok "socket non-sesi (port 59000) diabaikan"; fi

IP_A=$(ssh_active_ips userA 2>/dev/null | xargs)
if [[ "$IP_A" == "43.156.147.95" ]]; then ok "ssh_active_ips userA -> 43.156.147.95"; else bad "ssh_active_ips userA -> '$IP_A'"; fi

echo
echo "RINGKAS: $PASS hijau / $FAIL merah"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
