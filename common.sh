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

export MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com)
if [[ -z "$MYIP" ]]; then
    echo -e "${RED}[FATAL] Gagal mendapatkan IP publik. Periksa koneksi internet.${NC}" >&2
    exit 1
fi

# safe_jq_edit: edit xray config.json dengan flock agar tidak race condition
# Usage: safe_jq_edit 'jq_filter_string'
# Atau untuk jq dengan --arg: safe_jq_edit_args --arg u "$user" 'filter'
safe_jq_edit() {
    local filter="$1"
    local src="${XRAY_CONFIG}"
    local tmp
    tmp=$(mktemp /etc/wibutunnel/tmp/xray_edit.XXXXXX.json)
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; rm -f "$tmp"; return 1; }
        if jq "$filter" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$src"
            chmod 644 "$src"
        else
            echo "[ERROR] jq edit gagal, config tidak diubah" >&2
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$XRAY_LOCK"
}

safe_jq_edit_args() {
    local src="$XRAY_CONFIG"
    local tmp
    tmp=$(mktemp /etc/wibutunnel/tmp/xray_edit.XXXXXX.json)
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; rm -f "$tmp"; return 1; }
        if jq "$@" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$src"
            chmod 644 "$src"
        else
            echo "[ERROR] jq edit gagal, config tidak diubah" >&2
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$XRAY_LOCK"
}

# safe_sed_delete: hapus baris user dari flat-file DB pakai grep -F (fixed string)
safe_sed_delete() {
    local user="$1"
    local file="$2"
    [[ -f "$file" ]] || return 0
    grep -v "^${user}:" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

check_license() {
    local CACHE_FILE="/etc/wibutunnel/tmp/wibu_license.cache"
    local CACHE_TTL=3600
    local CURRENT_TIME=$(date +%s)

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
