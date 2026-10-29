#!/bin/bash
# ==========================================
# WIBU TUNNELING - common.sh (v4.0 KURUMI)
# [PATCH] flock xray config, MYIP guard, escape fix, safe helpers
# ==========================================

RED='\e[1;31m'
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
WHITE='\e[1;37m'
BLUE='\e[34m'
NC='\e[0m'
LINE="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mkdir -p /etc/wibutunnel/tmp
chmod 700 /etc/wibutunnel/tmp

XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_LOCK="/etc/wibutunnel/tmp/xray_config.lock"

# Deteksi IP publik (optional, caller harus validasi jika required)
export MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null)
if [[ -z "$MYIP" ]]; then
    MYIP=$(curl -sS --max-time 5 ifconfig.me 2>/dev/null)
fi

# safe_jq_edit: edit xray config.json dengan flock agar tidak race condition
# Usage: safe_jq_edit 'jq_filter_string'
# Atau untuk jq dengan --arg: safe_jq_edit_args --arg u "$user" 'filter'
safe_jq_edit() {
    local filter="$1"
    local src="${XRAY_CONFIG}"
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; return 1; }
        local tmp
        tmp=$(mktemp /etc/wibutunnel/tmp/xray_edit.XXXXXX.json) || return 1
        if jq "$filter" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$src"
            chmod 644 "$src"
            rm -f "$tmp"
        else
            echo "[ERROR] jq edit gagal, config tidak diubah" >&2
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$XRAY_LOCK"
}

safe_jq_edit_args() {
    local src="$XRAY_CONFIG"
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; return 1; }
        local tmp
        tmp=$(mktemp /etc/wibutunnel/tmp/xray_edit.XXXXXX.json) || return 1
        if jq "$@" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$src"
            chmod 644 "$src"
            rm -f "$tmp"
        else
            echo "[ERROR] jq edit gagal, config tidak diubah" >&2
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$XRAY_LOCK"
}

# safe_sed_delete: hapus baris user dari flat-file DB dengan flock agar aman concurrency
# FIX: grep -v exit 1 saat file jadi kosong -> mv tidak jalan -> baris basi tertinggal.
# FIX: awk index() = fixed string, aman untuk username berisi '.' dsb.
# ponytail: flat-file DB locked with flock. Upgrade to SQLite if > 10,000 concurrent users.
safe_sed_delete() {
    local user="$1"
    local file="$2"
    [[ -f "$file" ]] || return 0
    mkdir -p /etc/wibutunnel/tmp 2>/dev/null
    local lockfile="/etc/wibutunnel/tmp/$(basename "$file").lock"
    (
        flock -w 10 200 || { echo "[ERROR] flock timeout on $file" >&2; return 1; }
        local tmp="${file}.tmp.$$"
        if awk -v u="$user" 'index($0, u ":") != 1' "$file" > "$tmp"; then
            mv "$tmp" "$file"
            chmod 644 "$file" 2>/dev/null || true
        else
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$lockfile"
}

# db_set <file> <user> <value>: update line user atau append jika belum ada (atomic + flock)
db_set() {
    local file="$1"
    local user="$2"
    local val="$3"
    [[ -n "$file" && -n "$user" ]] || return 1
    mkdir -p "$(dirname "$file")" /etc/wibutunnel/tmp 2>/dev/null
    touch "$file"
    local lockfile="/etc/wibutunnel/tmp/$(basename "$file").lock"
    (
        flock -w 10 200 || { echo "[ERROR] flock timeout on $file" >&2; return 1; }
        local tmp="${file}.tmp.$$"
        local target="${user}:${val}"
        if awk -v u="$user" -v v="$target" '
            BEGIN { found = 0 }
            index($0, u ":") == 1 { print v; found = 1; next }
            { print }
            END { if (!found) print v }
        ' "$file" > "$tmp"; then
            mv "$tmp" "$file"
            chmod 644 "$file" 2>/dev/null || true
        else
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$lockfile"
}

# db_append <file> <line>: append line ke file dengan perlindungan flock
db_append() {
    local file="$1"
    local line="$2"
    [[ -n "$file" && -n "$line" ]] || return 1
    mkdir -p "$(dirname "$file")" /etc/wibutunnel/tmp 2>/dev/null
    touch "$file"
    local lockfile="/etc/wibutunnel/tmp/$(basename "$file").lock"
    (
        flock -w 10 200 || { echo "[ERROR] flock timeout on $file" >&2; return 1; }
        echo "$line" >> "$file"
    ) 200>"$lockfile"
}

# db_get <file> <user>: ambil value terakhir, fixed-string prefix match
db_get() {
    awk -v u="$2" 'index($0, u ":") == 1 { sub(/^[^:]*:/, ""); v=$0 } END { if (v != "") print v }' "$1" 2>/dev/null
}

# db_has <file> <user>: true jika entry ada
db_has() {
    awk -v u="$2" 'index($0, u ":") == 1 {f=1} END {exit !f}' "$1" 2>/dev/null
}

# xray_sync_user: sinkronisasi penambahan/penghapusan user via Xray API (port 10085)
# Tanpa restart service -> koneksi user lain tidak terputus.
# Fallback ke systemctl restart xray jika API offline/gagal.
# ponytail: sync inbounds via gRPC API port 10085. Dynamic routing rules require RoutingService API if needed later.
# Usage:
#   xray_sync_user add <VLESS|VMESS|TROJAN> <user> <uuid_or_pw>
#   xray_sync_user del <VLESS|VMESS|TROJAN|ALL> <user>
xray_sync_user() {
    local action="$1"
    local proto="${2^^}"
    local user="$3"
    local cred="$4"
    local api_server="127.0.0.1:10085"

    # Jika port API tidak hidup, fallback restart service
    if ! ss -tln 2>/dev/null | grep -q ":10085 "; then
        systemctl restart xray >/dev/null 2>&1
        return
    fi

    if [[ "$action" == "add" ]]; then
        local tmp
        tmp=$(mktemp /etc/wibutunnel/tmp/xray_adu.XXXXXX.json 2>/dev/null) || tmp="/tmp/xray_adu_$$.json"
        case "$proto" in
            VLESS)
                cat <<EOF > "$tmp"
{"inbounds":[
  {"tag":"vless-ws-tls","port":10086,"protocol":"vless","settings":{"decryption":"none","clients":[{"id":"$cred","email":"$user"}]}},
  {"tag":"vless-ws-ntls","port":10087,"protocol":"vless","settings":{"decryption":"none","clients":[{"id":"$cred","email":"$user"}]}},
  {"tag":"vless-grpc","port":10088,"protocol":"vless","settings":{"decryption":"none","clients":[{"id":"$cred","email":"$user"}]}}
]}
EOF
                ;;
            VMESS)
                cat <<EOF > "$tmp"
{"inbounds":[
  {"tag":"vmess-ws-tls","port":10089,"protocol":"vmess","settings":{"clients":[{"id":"$cred","alterId":0,"email":"$user"}]}},
  {"tag":"vmess-ws-ntls","port":10090,"protocol":"vmess","settings":{"clients":[{"id":"$cred","alterId":0,"email":"$user"}]}},
  {"tag":"vmess-grpc","port":10091,"protocol":"vmess","settings":{"clients":[{"id":"$cred","alterId":0,"email":"$user"}]}}
]}
EOF
                ;;
            TROJAN)
                cat <<EOF > "$tmp"
{"inbounds":[
  {"tag":"trojan-ws-tls","port":10092,"protocol":"trojan","settings":{"clients":[{"password":"$cred","email":"$user"}]}},
  {"tag":"trojan-grpc","port":10093,"protocol":"trojan","settings":{"clients":[{"password":"$cred","email":"$user"}]}}
]}
EOF
                ;;
            *)
                rm -f "$tmp"
                systemctl restart xray >/dev/null 2>&1
                return
                ;;
        esac

        if ! xray api adu --server="$api_server" "$tmp" >/dev/null 2>&1; then
            systemctl restart xray >/dev/null 2>&1
        fi
        rm -f "$tmp"

    elif [[ "$action" == "del" ]]; then
        local tags=()
        case "$proto" in
            VLESS) tags=("vless-ws-tls" "vless-ws-ntls" "vless-grpc") ;;
            VMESS) tags=("vmess-ws-tls" "vmess-ws-ntls" "vmess-grpc") ;;
            TROJAN) tags=("trojan-ws-tls" "trojan-grpc") ;;
            ALL) tags=("vless-ws-tls" "vless-ws-ntls" "vless-grpc" "vmess-ws-tls" "vmess-ws-ntls" "vmess-grpc" "trojan-ws-tls" "trojan-grpc") ;;
            *) tags=() ;;
        esac

        for tag in "${tags[@]}"; do
            xray api rmu --server="$api_server" -tag="$tag" "$user" >/dev/null 2>&1
        done
    fi
}

check_license() {
    local CACHE_FILE="/etc/wibutunnel/tmp/wibu_license.cache"
    local CACHE_TTL=3600
    local CURRENT_TIME=$(date -u +%s)

    # Cek Cache & Ekstrak Data (Format: STATUS|NAMA|EXPIRED)
    if [[ -f "$CACHE_FILE" ]]; then
        local FILE_MOD_TIME=$(stat -c %Y "$CACHE_FILE")
        local TIME_DIFF=$((CURRENT_TIME - FILE_MOD_TIME))
        if [[ $TIME_DIFF -le $CACHE_TTL ]]; then
            IFS='|' read -r c_status c_name c_exp < "$CACHE_FILE"
            if [[ "$c_status" == "VALID" && -n "$c_name" ]]; then
                export CLIENT_NAME="$c_name"
                export EXP_DATE="$c_exp"
                return 0
            fi
        fi
    fi

    # Jika cache tidak ada/expired, tarik dari GitHub
    local LINK_IZIN="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
    local GET_DATA=$(curl -sS --max-time 10 "$LINK_IZIN" | grep -w "$MYIP")
    
    if [[ -z "$GET_DATA" ]]; then
        clear
        echo -e "${LINE}\n                 ${RED}AKSES DITOLAK!${NC}\n${LINE}"
        echo -e " IP VPS Anda  : ${WHITE}$MYIP${NC}"
        echo -e " Status       : ${RED}Ilegal / Tidak Terdaftar${NC}\n${LINE}"
        exit 1
    fi

    export CLIENT_NAME=$(echo "$GET_DATA" | awk '{print $2}')
    export EXP_DATE=$(echo "$GET_DATA" | awk '{print $3}')
    
    # Simpan ke Cache dengan Format Baru
    echo "VALID|${CLIENT_NAME}|${EXP_DATE}" > "$CACHE_FILE"
    return 0
}

check_license_silent() {
    check_license >/dev/null 2>&1
}

# Sanitasi user input — reject karakter berbahaya
sanitize_user() {
    local u="$1"
    [[ -z "$u" ]] && return 1
    [[ ${#u} -gt 64 ]] && return 1
    [[ "$u" =~ [^a-zA-Z0-9._@-] ]] && return 1
    return 0
}
escape_sed() { printf '%s' "$1" | sed 's/[].\/[\\*^$()+?{|]/\\&/g'; }
escape_grep() { printf '%s' "$1" | sed 's/[].\/[\\*^$()+?{|]/\\&/g'; }

# live_ip_pairs: cetak "user ip ip ..." hanya untuk koneksi yang socket TCP-nya masih hidup.
# Asosiasi user<->IP diambil dari access.log 10 menit terakhir, liveness dari socket ESTABLISHED :443.
# ponytail: kalau client lewat CDN/reverse-proxy, IP di ss != IP di log -> user tidak terhitung.
#           Ganti ke conntrack per-UUID kalau topologi CDN dipakai.
live_ip_pairs() {
    # IP diambil dari access.log (xray melihat IP asli via PROXY protocol).
    # ponytail: liveness murni dari log, jadi device yang idle lebih lama dari jendela ini
    #           akan lepas dari hitungan walau socket-nya masih terbuka. Alternatif `ss`/conntrack
    #           TIDAK dipakai: pada box ini peer :80/:443 berisi IP Cloudflare, bukan IP client,
    #           sehingga filter socket membuang semua user nyata. Upgrade path: ekspos jumlah
    #           koneksi aktif per-user dari xray (butuh fork/plugin), bukan dari ss.
    local log="/var/log/xray/access.log"
    local thresh
    [[ ! -s "$log" ]] && return 0
    thresh=$(date -d "${LIVE_IP_WINDOW:-120 seconds} ago" +'%Y/%m/%d %H:%M:%S')
    awk -v thresh="$thresh" '{ if($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1" "$2 < thresh) exit; if(/accepted/ && /email: /){ for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]" " : "") ip; } } } } END { for (e in ips) print e, ips[e] }' <(tac "$log" 2>/dev/null) 2>/dev/null
}
