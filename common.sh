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
            chown root:xray "$src" 2>/dev/null || true
            chmod 640 "$src"
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
            chown root:xray "$src" 2>/dev/null || true
            chmod 640 "$src"
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

# db_get <file> <user> atau db_get <user> <file>: ambil value terakhir, fixed-string prefix match
db_get() {
    local file user
    if [[ -f "$1" ]]; then
        file="$1"; user="$2"
    elif [[ -f "$2" ]]; then
        file="$2"; user="$1"
    else
        file="$1"; user="$2"
    fi
    awk -v u="$user" 'index($0, u ":") == 1 { sub(/^[^:]*:/, ""); v=$0 } END { if (v != "") print v }' "$file" 2>/dev/null
}

# db_has <file> <user> atau db_has <user> <file>: true jika entry ada
db_has() {
    local file user
    if [[ -f "$1" ]]; then
        file="$1"; user="$2"
    elif [[ -f "$2" ]]; then
        file="$2"; user="$1"
    else
        file="$1"; user="$2"
    fi
    awk -v u="$user" 'index($0, u ":") == 1 {f=1} END {exit !f}' "$file" 2>/dev/null
}

# db_delete alias untuk safe_sed_delete (support arg urut <file> <user> maupun <user> <file>)
db_delete() {
    if [[ -f "$1" ]]; then
        safe_sed_delete "$2" "$1"
    else
        safe_sed_delete "$1" "$2"
    fi
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

show_license_expired() {
    local name="$1" exp="$2"
    clear 2>/dev/null || true
    echo -e "${LINE}"
    echo -e "               ${RED}LISENSI KEDALUWARSA!${NC}"
    echo -e "${LINE}"
    echo -e " Klien       : ${YELLOW}${name}${NC}"
    echo -e " IP VPS      : ${WHITE}${MYIP}${NC}"
    echo -e " Expired On  : ${RED}${exp}${NC}"
    echo -e "${LINE}"
    echo -e " Silakan hubungi Admin untuk perpanjangan lisensi."
    echo -e " WhatsApp : ${GREEN}087757315408${NC}"
    echo -e " Telegram : ${CYAN}t.me/wibuvpn${NC}"
    echo -e "${LINE}"
}

show_license_denied() {
    local ip="$1"
    clear 2>/dev/null || true
    echo -e "${LINE}"
    echo -e "                 ${RED}AKSES DITOLAK!${NC}"
    echo -e "${LINE}"
    echo -e " IP VPS Anda  : ${WHITE}${ip}${NC}"
    echo -e " Status       : ${RED}Ilegal / Tidak Terdaftar${NC}"
    echo -e "${LINE}"
    echo -e " Silakan hubungi Admin untuk registrasi IP."
    echo -e " WhatsApp : ${GREEN}087757315408${NC}"
    echo -e " Telegram : ${CYAN}t.me/wibuvpn${NC}"
    echo -e "${LINE}"
}

check_license() {
    local CACHE_FILE="/etc/wibutunnel/tmp/wibu_license.cache"
    local CACHE_TTL=3600
    local CURRENT_TIME=$(date -u +%s)

    [[ -z "$MYIP" ]] && MYIP=$(curl -sS --max-time 3 ipv4.icanhazip.com 2>/dev/null || curl -sS --max-time 3 ifconfig.me 2>/dev/null)

    # Cek Cache & Ekstrak Data (Format: STATUS|NAMA|EXPIRED)
    if [[ -f "$CACHE_FILE" ]]; then
        local FILE_MOD_TIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        local TIME_DIFF=$((CURRENT_TIME - FILE_MOD_TIME))
        if [[ $TIME_DIFF -le $CACHE_TTL ]]; then
            IFS='|' read -r c_status c_name c_exp < "$CACHE_FILE"
            if [[ "$c_status" == "VALID" && -n "$c_name" && -n "$c_exp" ]]; then
                if [[ "${c_exp,,}" != "lifetime" ]]; then
                    local exp_parse="$c_exp"
                    [[ "$exp_parse" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && exp_parse="${exp_parse} 23:59:59"
                    local exp_sec; exp_sec=$(date -u -d "$exp_parse" +%s 2>/dev/null)
                    if [[ -z "$exp_sec" || $CURRENT_TIME -gt $exp_sec ]]; then
                        rm -f "$CACHE_FILE"
                        show_license_expired "$c_name" "$c_exp"
                        exit 1
                    fi
                fi
                export CLIENT_NAME="$c_name"
                export EXP_DATE="$c_exp"
                return 0
            fi
        fi
    fi

    # Tarik dari GitHub (atau fallback local izin.txt)
    local LINK_IZIN="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
    local GET_DATA=""
    if [[ -f "/etc/wibutunnel/izin.txt" ]] && grep -qw "$MYIP" "/etc/wibutunnel/izin.txt" 2>/dev/null; then
        GET_DATA=$(grep -w "$MYIP" "/etc/wibutunnel/izin.txt")
    elif [[ -f "./izin.txt" ]] && grep -qw "$MYIP" "./izin.txt" 2>/dev/null; then
        GET_DATA=$(grep -w "$MYIP" "./izin.txt")
    else
        GET_DATA=$(curl -sS --max-time 7 "$LINK_IZIN" 2>/dev/null | grep -w "$MYIP")
    fi

    if [[ -z "$GET_DATA" ]]; then
        rm -f "$CACHE_FILE"
        show_license_denied "$MYIP"
        exit 1
    fi

    local c_name c_exp reg_ip
    c_name=$(echo "$GET_DATA" | awk '{print $2}' | tr -d '\r' | tr -d ' ')
    c_exp=$(echo "$GET_DATA" | awk '{print $3}' | tr -d '\r' | tr -d ' ')
    reg_ip=$(echo "$GET_DATA" | awk '{print $4}' | tr -d '\r' | tr -d ' ')

    if [[ -n "$reg_ip" && "$reg_ip" != "$MYIP" ]]; then
        rm -f "$CACHE_FILE"
        show_license_denied "$MYIP"
        exit 1
    fi

    if [[ "${c_exp,,}" != "lifetime" ]]; then
        local exp_parse="$c_exp"
        [[ "$exp_parse" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && exp_parse="${exp_parse} 23:59:59"
        local exp_sec; exp_sec=$(date -u -d "$exp_parse" +%s 2>/dev/null)
        if [[ -z "$exp_sec" || $CURRENT_TIME -gt $exp_sec ]]; then
            rm -f "$CACHE_FILE"
            show_license_expired "$c_name" "$c_exp"
            exit 1
        fi
    fi

    export CLIENT_NAME="$c_name"
    export EXP_DATE="$c_exp"

    # Simpan ke Cache
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "VALID|${CLIENT_NAME}|${EXP_DATE}" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
    return 0
}

check_license_silent() {
    ( check_license >/dev/null 2>&1 )
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

# ==========================================
# SSH TUNNEL (Dropbear) — backend account
# ==========================================
SSH_GROUP="${SSH_GROUP:-ssh_tunnel}"
SSH_SHELL="${SSH_SHELL:-/bin/bash}"
SSH_EXP_FILE="${SSH_EXP_FILE:-/etc/xray/ssh_exp.conf}"
SSH_DB_PASS="${SSH_DB_PASS:-/etc/wibutunnel/ssh_pass.db}"

ssh_init() {
    getent group "$SSH_GROUP" >/dev/null 2>&1 || groupadd --system "$SSH_GROUP" >/dev/null 2>&1
    mkdir -p /etc/xray /etc/wibutunnel/tmp
    touch "$SSH_EXP_FILE" "$SSH_DB_PASS" /etc/wibutunnel/limit_ip.db /etc/wibutunnel/limit_bw.db /etc/wibutunnel/locked_users.db
    chmod 600 "$SSH_DB_PASS" /etc/wibutunnel/*.db 2>/dev/null
}

ssh_valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{2,31}$ ]]; }
ssh_user_exists() { id "$1" >/dev/null 2>&1; }

ssh_list_users() {
    ssh_init
    getent group "$SSH_GROUP" 2>/dev/null | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sort
}

ssh_get_pass() {
    [[ -f "$SSH_DB_PASS" ]] || return 1
    db_get "$1" "$SSH_DB_PASS"
}

ssh_session_count() {
    local user="$1" count=0
    count=$(ps -u "$user" -o comm= 2>/dev/null | grep -cE '^(dropbear|sshd|sh|bash)$' || true)
    printf '%s' "$count"
}

ssh_active_ips() {
    local user="$1" out=""
    local pids
    pids=$(pgrep -u "$user" 2>/dev/null || true)
    [[ -z "$pids" ]] && return 0
    while read -r line; do
        out+="${line} "
    done < <(ss -tnp 2>/dev/null | grep "haproxy" | grep ":443" | grep ESTAB | awk '{print $5}' | sed 's/:[0-9]*$//' | grep -vE '^(127\.0\.0\.1|::1)$' | sort -u)
    printf '%s' "$out"
}

add_ssh_user() {
    ssh_init
    local user="$1" pass="$2" hari="$3" lip="${4:-0}" lbw="${5:-0}"
    ssh_valid_user "$user" || { echo "username tidak valid (3-32 char: a-z 0-9 _ -)"; return 1; }
    [[ -n "$pass" && ${#pass} -ge 6 ]] || { echo "password minimal 6 karakter"; return 1; }
    [[ "$hari" =~ ^[0-9]+$ && "$hari" -ge 1 ]] || { echo "durasi hari tidak valid"; return 1; }
    ssh_user_exists "$user" && { echo "user $user sudah ada"; return 1; }

    useradd -m -s "$SSH_SHELL" -G "$SSH_GROUP" "$user" >/dev/null 2>&1 || { echo "gagal useradd"; return 1; }
    if ! printf '%s:%s\n' "$user" "$pass" | chpasswd 2>/dev/null; then
        userdel "$user" >/dev/null 2>&1; echo "gagal set password"; return 1
    fi
    local exp; exp=$(date -d "+${hari} days" +"%Y-%m-%d %H:%M:%S")
    chage -E "$(date -d "+${hari} days" +%Y-%m-%d)" -M "$hari" -I 0 "$user" >/dev/null 2>&1

    db_set "$SSH_EXP_FILE" "$user" "$exp"
    db_set "$SSH_DB_PASS" "$user" "$pass"
    db_set /etc/wibutunnel/limit_ip.db "$user" "$lip"
    db_set /etc/wibutunnel/limit_bw.db "$user" "$lbw"
    chmod 600 "$SSH_DB_PASS" /etc/wibutunnel/*.db 2>/dev/null
    chown root:root "$SSH_DB_PASS" /etc/wibutunnel/*.db 2>/dev/null
    return 0
}

del_ssh_user() {
    local user="$1"
    ssh_valid_user "$user" || { echo "username tidak valid"; return 1; }
    ssh_user_exists "$user" || { echo "user $user tidak ada"; return 1; }
    
    local uid; uid=$(id -u "$user" 2>/dev/null)
    pkill -u "$user" 2>/dev/null || true; sleep 0.5
    userdel -r "$user" >/dev/null 2>&1 || userdel "$user" >/dev/null 2>&1
    
    if [[ -n "$uid" ]]; then
        iptables -t mangle -D OUTPUT -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null || true
        iptables -t mangle -D INPUT -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null || true
    fi
    
    db_delete "$user" "$SSH_EXP_FILE"
    db_delete "$user" "$SSH_DB_PASS"
    db_delete "$user" /etc/wibutunnel/limit_ip.db
    db_delete "$user" /etc/wibutunnel/limit_bw.db
    db_delete "$user" /etc/wibutunnel/locked_users.db
    db_delete "$user" /etc/wibutunnel/user_usage.db
    return 0
}

renew_ssh_user() {
    local user="$1" hari="$2" base new exp add_sec=0
    ssh_valid_user "$user" || { echo "username tidak valid"; return 1; }
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }

    local val="${hari%[mhd]}"
    [[ "$val" =~ ^[0-9]+$ ]] || { echo "durasi tidak valid"; return 1; }
    [[ ${#val} -le 7 ]] || { echo "durasi di luar batas (maks 1 tahun)"; return 1; }
    (( val > 0 && val <= 525600 )) || { echo "durasi di luar batas (maks 1 tahun)"; return 1; }
    case "$hari" in
        *[mM]) add_sec=$(( val * 60 )) ;;
        *[hH]) add_sec=$(( val * 3600 )) ;;
        *[dD]|*[0-9]) add_sec=$(( val * 86400 )) ;;
        *) echo "durasi tidak valid"; return 1 ;;
    esac
    [[ "$add_sec" -le 0 ]] && { echo "durasi tidak valid"; return 1; }

    base=$(db_get "$user" "$SSH_EXP_FILE")
    if [[ -z "$base" ]]; then
        base=$(chage -l "$user" 2>/dev/null | awk -F': ' '/Account expires/{print $2}')
        [[ -z "$base" || "$base" == "never" ]] && base=$(date +"%Y-%m-%d %H:%M:%S")
    fi
    local base_sec; base_sec=$(date -d "$base" +%s 2>/dev/null)
    [[ -z "$base_sec" ]] && base_sec=$(date +%s)
    local new_sec=$(( base_sec + add_sec ))
    new=$(date -d "@$new_sec" +"%Y-%m-%d %H:%M:%S")
    [[ -z "$new" ]] && return 1

    chage -E "$(date -d "$new" +%Y-%m-%d)" -M $(( ( $(date -d "$new" +%s) - $(date +%s) ) / 86400 + 1 )) -I 0 "$user" >/dev/null 2>&1
    passwd -u "$user" >/dev/null 2>&1
    mkdir -p "$(dirname "$SSH_EXP_FILE")" 2>/dev/null
    db_set "$SSH_EXP_FILE" "$user" "$new"
    db_delete "$user" /etc/wibutunnel/locked_users.db
    printf '%s' "$new"
    return 0
}

lock_ssh_user() {
    local user="$1" reason="${2:-MANUAL}" now unlock
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }
    passwd -l "$user" >/dev/null 2>&1
    pkill -u "$user" 2>/dev/null || true
    now=$(date +%s); unlock=0
    db_set /etc/wibutunnel/locked_users.db "$user" "${now}:${unlock}:${reason}"
    return 0
}

unlock_ssh_user() {
    local user="$1"
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }
    passwd -u "$user" >/dev/null 2>&1
    db_delete "$user" /etc/wibutunnel/locked_users.db
    return 0
}
