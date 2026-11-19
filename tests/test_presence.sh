#!/bin/bash
# ==========================================
# Uji status online (xray_presence) TANPA panel terpasang.
#
# Pelajaran dari review v4.1.45 yang dikunci di sini:
#  - format `ss` NYATA = 4 kolom (kolom State hilang karena sudah difilter) -> peer = $NF
#  - hanya socket yang melayani :80/:443 dihitung sebagai bukti hidup
#  - umur memakai aktivitas TERBARU, bukan yang tertua
#  - log TIDAK monoton tidak boleh memotong daftar user
#  - edge Cloudflare bukan identitas pelanggan (kolom IP dikosongkan)
# ==========================================
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
t() { local n="$1"; shift; if eval "$@"; then PASS=$((PASS+1)); echo "  PASS  $n"; else FAIL=$((FAIL+1)); echo "  FAIL  $n"; fi; }

TMP=$(mktemp -d /tmp/presence.XXXXXX)
LOG="$TMP/access.log"; SS="$TMP/ss.txt"
ts() { date -d "$1" '+%Y/%m/%d %H:%M:%S'; }
mklog() { # $1=user $2=ip $3=detik-lalu [berkas]
    printf '%s.000000 from %s:1234 accepted tcp:example.com:443 [vless-ws-ntls >> direct] email: %s\n' \
        "$(ts "-$3 seconds")" "$2" "$1" >> "${4:-$LOG}"
}
# Format `ss` asli: 4 kolom, peer = kolom terakhir, alamat lokal = kedua terakhir.
sock4() { printf '0      0      %s      %s\n' "$1" "$2" >> "$SS"; }

# --- fixture utama (kronologis) ---
mklog basi         203.0.113.40  7200    # lewat TTL 1800 -> tidak ditampilkan
mklog lama         203.0.113.20  1200    # offline, masih di dalam TTL
mklog socket       203.0.113.30  1200    # offline menurut umur, TAPI socket :443 terbuka
mklog sshonly      203.0.113.60  1200    # socket hanya di :22 -> BUKAN bukti xray online
mklog dua_ip       203.0.113.91  600     # IP lama 10 menit
mklog dua_ip       203.0.113.92  5       # IP baru 5 detik -> umur user harus 5
mklog menengah     203.0.113.50  120     # 2 menit: offline di window 60, online di 180
mklog cdn_menengah 162.158.218.88 120    # CDN, 2 menit
mklog cdn_lama     162.158.218.77 30     # CDN, 30 detik -> online
mklog campur       203.0.113.80  40      # IP asli 40 detik
mklog campur       162.158.218.99 10     # + edge CF: harus dibuang dari laporan
mklog baru         203.0.113.10  5       # online

sock4 10.0.0.1:443 203.0.113.30:55000    # socket :443 -> user "socket" online
sock4 10.0.0.1:22  203.0.113.60:55002    # socket :22  -> harus DIABAIKAN
sock4 10.0.0.1:443 162.158.218.10:55003  # edge CF   -> harus DIABAIKAN

OUT=$(cd "$REPO" && XRAY_ACCESS_LOG="$LOG" XRAY_SS_SRC="$SS" bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
echo "--- keluaran ---"; printf '%s\n' "$OUT" | sed 's/^/  /'; echo "----------------"
row() { printf '%s\n' "$OUT" | awk -F'|' -v u="$1" '$1==u'; }

t "aktivitas 5 detik lalu -> online"                  'row baru | grep -q "|online|"'
t "idle 20 menit tanpa socket -> offline"             'row lama | grep -q "|offline|"'
t "idle 20 menit TAPI socket :443 terbuka -> online"  'row socket | grep -q "|online|"'
t "socket hanya di :22 tidak dihitung (filter port)"  'row sshonly | grep -q "|offline|"'
t "user lewat PRESENCE_TTL tidak ditampilkan"         '! row basi | grep -q .'
t "umur diambil dari aktivitas TERBARU (bukan tertua)" 'row dua_ip | awk -F"|" "{exit !(\$3<60)}"'
t "user dua IP tetap online"                          'row dua_ip | grep -q "|online|"'
t "IP yang dilaporkan hanya IP asli"                  'row baru | grep -q "203.0.113.10"'
t "IP edge CDN historis dibuang bila ada IP asli"     'row campur | grep -q "203.0.113.80" && ! row campur | grep -q "162.158"'
t "user CDN-only online tapi kolom IP kosong"         'row cdn_lama | grep -qE "\|online\|[0-9]+\|$"'
t "edge CF di ss tidak dijadikan bukti"               '! printf "%s\n" "$OUT" | grep -q "162.158.218.10"'
t "window 60: user 120 dtk -> offline"                'row menengah | grep -q "|offline|"'

OUT2=$(cd "$REPO" && XRAY_ACCESS_LOG="$LOG" XRAY_SS_SRC="$SS" ONLINE_WINDOW=180 bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
t "ONLINE_WINDOW=180: user 120 dtk -> online"         'printf "%s\n" "$OUT2" | awk -F"|" "\$1==\"menengah\"{exit !(\$2==\"online\")}"'
t "ONLINE_WINDOW=180: user CDN 120 dtk -> online"     'printf "%s\n" "$OUT2" | awk -F"|" "\$1==\"cdn_menengah\"{exit !(\$2==\"online\")}"'

# --- log tidak monoton: baris tua di akhir tidak boleh menghapus user lain ---
LOG2="$TMP/nonmono.log"
mklog A 203.0.113.101 5    "$LOG2"
mklog B 203.0.113.102 4000 "$LOG2"
mklog C 203.0.113.103 10   "$LOG2"
OUT3=$(cd "$REPO" && XRAY_ACCESS_LOG="$LOG2" XRAY_SS_SRC="$SS" bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
t "log tidak monoton: user terbaru (A) tetap muncul"      'printf "%s\n" "$OUT3" | grep -q "^A|online|"'
t "log tidak monoton: user C tetap muncul"                'printf "%s\n" "$OUT3" | grep -q "^C|online|"'
t "log tidak monoton: user di luar TTL (B) tidak muncul"  '! printf "%s\n" "$OUT3" | grep -q "^B|"'

# --- log dengan zona waktu berbeda (xray menulis UTC, panel lokal) tetap benar ---
LOG3="$TMP/tz.log"
printf '%s.000000 from 203.0.113.202:1234 accepted tcp:x:443 [vless-ws-ntls >> direct] email: tzuser\n' \
    "$(ts '-5 seconds +8 hours')" >> "$LOG3"
OUT4=$(cd "$REPO" && XRAY_ACCESS_LOG="$LOG3" XRAY_SS_SRC="$SS" bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
t "log bergeser 8 jam (TZ beda) tetap dinilai online" 'printf "%s\n" "$OUT4" | grep -qE "^tzuser\\|online\\|[0-9]+\\|"'

# --- format ss 5 kolom (dengan kolom State) harus tetap terbaca ---
SS5="$TMP/ss5.txt"
printf 'ESTAB 0      0      10.0.0.1:443     203.0.113.30:55000\n' > "$SS5"
OUT5=$(cd "$REPO" && XRAY_ACCESS_LOG="$LOG" XRAY_SS_SRC="$SS5" bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
t "format ss 5 kolom juga dikenali" 'printf "%s\n" "$OUT5" | awk -F"|" "\$1==\"socket\"{exit !(\$2==\"online\")}"'

# --- log tidak ada ---
OUT6=$(cd "$REPO" && XRAY_ACCESS_LOG="$TMP/tidak-ada.log" XRAY_SS_SRC="$SS" bash -c 'source ./common.sh; xray_presence' 2>/dev/null)
t "log tidak ada -> keluaran kosong, rc=0" '[[ -z "$OUT6" ]]'

rm -rf "$TMP"
echo
echo "=========== HASIL: $PASS PASS / $FAIL FAIL ==========="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1