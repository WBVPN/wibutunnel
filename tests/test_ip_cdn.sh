#!/bin/bash
# ==========================================
# UJI: pengabaian IP CDN pada penghitungan limit IP (v4.1.38)
#
# Kasus nyata di VPS: akun 'admin' terkunci "Melebihi Limit IP" padahal cuma
# satu orang. Sebabnya domain dilayani lewat CDN (Cloudflare), jadi yang
# tercatat di access.log adalah IP edge Cloudflare (162.158.x, 172.64.x,
# 104.23.x, ...), bukan IP pelanggan. one user -> 41 "IP" -> limit 10 jebol.
#
# Yang diuji, tanpa menyentuh log sistem:
#   1. ip_is_cdn() mengenali rentang Cloudflare (IPv4 + IPv6)
#   2. IP di luar rentang TIDAK dianggap CDN (batas rentang diuji)
#   3. live_ip_pairs() membuang IP CDN, menyisakan IP asli
#   4. user yang hanya lewat CDN -> tidak menghasilkan IP (tidak bisa dilimit)
# ==========================================
set -u
export PYTHONDONTWRITEBYTECODE=1

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/uji-cdn.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

echo "=== UJI PENGABAIAN IP CDN ==="
echo
source "$REPO/common.sh" >/dev/null 2>&1 || { bad "common.sh gagal di-source"; exit 1; }

echo "--- 1: ip_is_cdn() tersedia ---"
if declare -F ip_is_cdn >/dev/null 2>&1; then
    ok "ip_is_cdn() ada"
else
    bad "ip_is_cdn() TIDAK ADA — pengabaian CDN belum diimplementasikan"
    echo
    echo "RINGKAS: $PASS hijau / $FAIL merah"
    exit 1
fi

echo
echo "--- 2: rentang Cloudflare dikenali ---"
for ip in 162.158.218.19 172.64.178.201 104.23.232.30 173.245.48.7 198.41.200.1 2606:4700:3033::1 2a06:98c0::5; do
    if ip_is_cdn "$ip"; then ok "$ip -> CDN"; else bad "$ip seharusnya CDN"; fi
done

echo
echo "--- 3: IP non-CDN tidak ikut dibuang (batas rentang) ---"
for ip in 43.156.147.95 8.8.8.8 172.63.255.255 104.15.255.255 162.157.255.255 131.0.71.255 2001:db8::1; do
    if ip_is_cdn "$ip"; then bad "$ip salah dianggap CDN"; else ok "$ip -> bukan CDN"; fi
done

echo
echo "--- 4: live_ip_pairs() membuang IP CDN ---"
LOG="$TMP/access.log"
# Fixture WAJIB bertanggal RELATIF. live_ip_pairs() membuang baris yang lebih tua
# dari jendelanya, dan `awk` di dalamnya `exit` pada baris pertama yang kedaluwarsa.
# Tanggal mati membuat tes ini MERAH SENDIRI satu hari setelah ditulis — bukan kode
# yang rusak (terbukti 2026-11-19: fixture 2026/11/18 + LIVE_IP_WINDOW=86400 -> nol
# baris terbaca, 2 asersi gagal tanpa ada perubahan kode).
ts_ago() { date -d "-$1 seconds" '+%Y/%m/%d %H:%M:%S.%6N'; }
{
    printf '%s from 162.158.218.19:13621 accepted tcp:l.apiok.net:443 [vless-ws-ntls >> direct] email: admin\n'        "$(ts_ago 36)"
    printf '%s from 172.64.178.251:10076 accepted tcp:gateway.facebook.com:443 [vless-ws-ntls >> direct] email: admin\n' "$(ts_ago 35)"
    printf '%s from 104.23.232.30:12993 accepted tcp:z-m.example.com:443 [vless-ws-ntls >> direct] email: admin\n'      "$(ts_ago 34)"
    printf '%s from 43.156.147.95:5555 accepted tcp:example.com:443 [vless-ws-ntls >> direct] email: admin\n'           "$(ts_ago 33)"
    printf '%s from 2606:4700:3033::1:8080 accepted tcp:example.com:443 [vless-ws-ntls >> direct] email: cdonly\n'      "$(ts_ago 32)"
    printf '%s from 8.8.8.8:53 accepted tcp:example.com:443 [vless-ws-ntls >> direct] email: biasa\n'                  "$(ts_ago 31)"
} > "$LOG"
OUT=$(XRAY_ACCESS_LOG="$LOG" LIVE_IP_WINDOW=86400 live_ip_pairs 2>/dev/null)
ADMIN_IPS=$(echo "$OUT" | awk '$1=="admin"{ $1=""; print }' | xargs 2>/dev/null)
if [[ "$ADMIN_IPS" == "43.156.147.95" ]]; then
    ok "admin -> hanya IP asli (43.156.147.95), 3 IP CDN dibuang"
else
    bad "admin -> '$ADMIN_IPS' (harusnya hanya 43.156.147.95)"
fi
if echo "$OUT" | awk '$1=="cdonly"' | grep -q .; then
    bad "user yang hanya lewat CDN masih menghasilkan IP"
else
    ok "user CDN-only -> tanpa IP (tidak bisa salah kunci)"
fi
if [[ "$(echo "$OUT" | awk '$1=="biasa"{ $1=""; print }' | xargs 2>/dev/null)" == "8.8.8.8" ]]; then
    ok "user non-CDN tidak terpengaruh"
else
    bad "user non-CDN ikut terpengaruh"
fi

echo
echo "RINGKAS: $PASS hijau / $FAIL merah"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
