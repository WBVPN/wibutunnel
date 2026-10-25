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

# safe_sed_delete: hapus baris user dari flat-file DB (fixed-string prefix match)
# FIX: grep -v exit 1 saat file jadi kosong -> mv tidak jalan -> baris basi tertinggal.
# FIX: awk index() = fixed string, aman untuk username berisi '.' dsb.
safe_sed_delete() {
    local user="$1"
    local file="$2"
    [[ -f "$file" ]] || return 0
    local tmp="${file}.tmp.$$"
    if awk -v u="$user" 'index($0, u ":") != 1' "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
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
    awk -v thresh="$thresh" '{ if($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1" "$2 < thresh) exit; if(/accepted/){ for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]" " : "") ip; } } } } END { for (e in ips) print e, ips[e] }' <(tac "$log" 2>/dev/null) 2>/dev/null
}
