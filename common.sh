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

# [FIX] MYIP di-cache (TTL 10 menit) supaya icanhazip tidak dibebani:
#       wibu-daemon memanggil algojo tiap 10 detik -> tanpa cache = ~17.000 req/hari.
#       Saat gagal, jatuh ke cache lama (bukan exit) agar daemon & menu tetap jalan.
WIBU_IP_CACHE="/etc/wibutunnel/tmp/wibu_ip.cache"
WIBU_IP_TTL=600

get_myip() {
    local now=$(date +%s) mtime cached fresh
    if [[ -f "$WIBU_IP_CACHE" ]]; then
        mtime=$(stat -c %Y "$WIBU_IP_CACHE" 2>/dev/null || echo 0)
        cached=$(cat "$WIBU_IP_CACHE" 2>/dev/null)
        if [[ -n "$cached" && $((now - mtime)) -le $WIBU_IP_TTL ]]; then
            printf '%s' "$cached"; return 0
        fi
    fi
    fresh=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null)
    if [[ -n "$fresh" ]]; then
        printf '%s' "$fresh" > "$WIBU_IP_CACHE" 2>/dev/null
        printf '%s' "$fresh"; return 0
    fi
    # Fallback: pakai cache lama meskipun kadaluarsa (lebih baik daripada kosong)
    if [[ -f "$WIBU_IP_CACHE" ]]; then
        cached=$(cat "$WIBU_IP_CACHE" 2>/dev/null)
        if [[ -n "$cached" ]]; then printf '%s' "$cached"; return 0; fi
    fi
    return 1
}

export MYIP=$(get_myip 2>/dev/null)
if [[ -z "$MYIP" ]]; then
    echo -e "${RED}[WARNING] Gagal mendapatkan IP publik. Periksa koneksi internet.${NC}" >&2
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

# safe_sed_delete: hapus baris user dari flat-file DB dengan pencocokan EXAKT
# (field pertama harus sama persis; aman untuk username yang mengandung "." atau "@")
safe_sed_delete() {
    local user="$1"
    local file="$2"
    [[ -f "$file" ]] || return 0
    [[ -z "$user" ]] && return 0
    awk -F':' -v u="$user" '$1!=u' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# db_lookup <user> <file>: cetak baris yang field pertamanya EXAKT sama dengan user
#   (pengganti `grep "^${user}:"` yang tidak aman untuk username mengandung ".")
db_lookup() {
    local user="$1" file="$2"
    [[ -f "$file" ]] || return 1
    awk -F':' -v u="$user" '$1==u' "$file"
}

# db_has <user> <file>: sukses (0) kalau user ada di file
# (harus cek output — exit status awk selalu 0 meski tidak ada baris yang cocok)
db_has() { [[ -n "$(db_lookup "$1" "$2")" ]]; }

# license_expired: cek apakah tanggal kadaluarsa lisensi sudah lewat.
#   - "lifetime" / kosong / format tak dikenal -> TIDAK expired (fail-safe)
#   - tanggal YYYY-MM-DD -> expired jika < hari ini
# Mengembalikan 0 = expired, 1 = masih aktif.
license_expired() {
    local exp="$1"
    [[ -z "$exp" || "$exp" == "lifetime" ]] && return 1
    # hanya format YYYY-MM-DD yang divalidasi
    [[ "$exp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    local today exp_epoch
    today=$(date +%Y-%m-%d)
    exp_epoch=$(date -d "$exp" +%s 2>/dev/null) || return 1
    # expired kalau tanggal expiry < tanggal hari ini
    [[ "$exp" < "$today" ]]
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
                # [SECURITY] Tolak lisensi yang sudah kadaluarsa meski cache-nya
                # masih "VALID". Tanpa ini, customer masa habis tetap bisa pakai
                # script selamanya selama cache belum TTL 1 jam.
                if license_expired "$c_exp"; then
                    rm -f "$CACHE_FILE"
                    clear
                    echo -e "${LINE}\n                 ${RED}LISENSI KADALUARSA!${NC}\n${LINE}"
                    echo -e " ${CYAN}Client     : ${WHITE}${c_name}${NC}"
                    echo -e " ${CYAN}Berlaku s/d: ${RED}${c_exp}${NC}\n${LINE}"
                    echo -e " ${YELLOW}Perpanjang lisensi Anda untuk lanjut menggunakan script.${NC}\n${LINE}"
                    exit 1
                fi
                export CLIENT_NAME="$c_name"
                export EXP_DATE="$c_exp"
                return 0
            fi
        fi
    fi

    # [SECURITY] MYIP wajib ada; kalau kosong, grep -F -w "" akan mencocokkan
    # semua baris izin.txt dan license bisa lolos untuk IP yang tidak terdaftar.
    if [[ -z "$MYIP" ]]; then
        clear
        echo -e "${LINE}\n                 ${RED}AKSES DITOLAK!${NC}\n${LINE}"
        echo -e " ${RED}Gagal memverifikasi IP publik (kosong). Periksa koneksi internet.${NC}\n${LINE}"
        exit 1
    fi

    # Jika cache tidak ada/expired, tarik dari GitHub
    local LINK_IZIN="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
    local GET_DATA=$(curl -sS --max-time 10 "$LINK_IZIN" | grep -F -w "$MYIP")

    if [[ -z "$GET_DATA" ]]; then
        clear
        echo -e "${LINE}\n                 ${RED}AKSES DITOLAK!${NC}\n${LINE}"
        echo -e " IP VPS Anda  : ${WHITE}$MYIP${NC}"
        echo -e " Status       : ${RED}Ilegal / Tidak Terdaftar${NC}\n${LINE}"
        exit 1
    fi

    export CLIENT_NAME=$(echo "$GET_DATA" | awk '{print $2}')
    export EXP_DATE=$(echo "$GET_DATA" | awk '{print $3}')

    # [SECURITY] Cek kadaluarsa: "lifetime" & format tak dikenal dianggap aktif.
    if license_expired "$EXP_DATE"; then
        rm -f "$CACHE_FILE"
        clear
        echo -e "${LINE}\n                 ${RED}LISENSI KADALUARSA!${NC}\n${LINE}"
        echo -e " ${CYAN}Client     : ${WHITE}${CLIENT_NAME}${NC}"
        echo -e " ${CYAN}Berlaku s/d: ${RED}${EXP_DATE}${NC}\n${LINE}"
        echo -e " ${YELLOW}Perpanjang lisensi Anda untuk lanjut menggunakan script.${NC}\n${LINE}"
        exit 1
    fi

    # Simpan ke Cache dengan Format Baru
    echo "VALID|${CLIENT_NAME}|${EXP_DATE}" > "$CACHE_FILE"
    return 0
}

check_license_silent() {
    check_license >/dev/null 2>&1
}

# ==========================================
# SSH TUNNEL (Dropbear 2019) — backend account
# ==========================================
# Akun SSH adalah user sistem (chage expiry) pada group tunnel, jauh berbeda
# dari klien xray (config.json). Fungsi-fungsi ini menyediakan API yang setara
# dengan manajemen akun xray agar bisa dipakai menu, bot, xp.sh & algojo.

SSH_GROUP="${SSH_GROUP:-ssh_tunnel}"
SSH_SHELL="${SSH_SHELL:-/bin/bash}"
SSH_EXP_FILE="${SSH_EXP_FILE:-/etc/xray/ssh_exp.conf}"
SSH_DB_PASS="${SSH_DB_PASS:-/etc/wibutunnel/ssh_pass.db}"   # user:password (600)

# pastikan group & file DB ada (dipanggil aman berulang)
ssh_init() {
    getent group "$SSH_GROUP" >/dev/null 2>&1 || groupadd --system "$SSH_GROUP" >/dev/null 2>&1
    mkdir -p /etc/xray /etc/wibutunnel/tmp
    touch "$SSH_EXP_FILE" "$SSH_DB_PASS" /etc/wibutunnel/limit_ip.db /etc/wibutunnel/limit_bw.db /etc/wibutunnel/locked_users.db
    chmod 600 "$SSH_DB_PASS" /etc/wibutunnel/*.db 2>/dev/null
}

# validasi username sistem (lebih ketat dari sanitize_user: huruf kecil + _ - angka)
ssh_valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{2,31}$ ]]; }

ssh_user_exists() { id "$1" >/dev/null 2>&1; }


# daftar akun ssh (dari group tunnel), excludes dummy/system
ssh_list_users() {
    ssh_init
    getent group "$SSH_GROUP" 2>/dev/null | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sort
}

# ambil password plaintext (diperlukan untuk config HTTP Custom). Fallback:
# generate ulang tidak mungkin - jika tidak ada, kembalikan placeholder.
ssh_get_pass() {
    [[ -f "$SSH_DB_PASS" ]] || return 1
    db_lookup "$1" "$SSH_DB_PASS" | cut -d: -f2
}

# hitung sesi dropbear aktif per user (pgrep lebih akurat daripada utmp)
ssh_session_count() {
    local c
    c=$(pgrep -fcu "$1" 2>/dev/null)
    [[ "$c" =~ ^[0-9]+$ ]] || c=0
    printf '%s' "$c"
}

# daftar IP sumber dari koneksi dropbear milik user (via ss + mapping pid)
ssh_active_ips() {
    local user="$1" pids out=""
    pids=$(pgrep -u "$user" 2>/dev/null | paste -sd'|')
    [[ -z "$pids" ]] && return 0
    while read -r line; do
        out+="${line} "
    done < <(ss -tnp state established 2>/dev/null | grep -E "pid=($pids)" | awk '{print $4}' | sed 's/:[0-9]*$//' | grep -v '^127.0.0.1$' | sort -u)
    printf '%s' "$out"
}

# buat akun ssh: user pass hari limit_ip limit_bw
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

    safe_sed_delete "$user" "$SSH_EXP_FILE"; echo "${user}:${exp}" >> "$SSH_EXP_FILE"
    safe_sed_delete "$user" "$SSH_DB_PASS";   echo "${user}:${pass}" >> "$SSH_DB_PASS"
    safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db; echo "${user}:${lip}" >> /etc/wibutunnel/limit_ip.db
    safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db; echo "${user}:${lbw}" >> /etc/wibutunnel/limit_bw.db
    chmod 600 "$SSH_DB_PASS" /etc/wibutunnel/*.db
    return 0
}

del_ssh_user() {
    local user="$1"
    ssh_valid_user "$user" || { echo "username tidak valid"; return 1; }
    ssh_user_exists "$user" || { echo "user $user tidak ada"; return 1; }
    pkill -u "$user" 2>/dev/null; sleep 1
    userdel -r "$user" >/dev/null 2>&1 || userdel "$user" >/dev/null 2>&1
    safe_sed_delete "$user" "$SSH_EXP_FILE"
    safe_sed_delete "$user" "$SSH_DB_PASS"
    safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db
    safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db
    safe_sed_delete "$user" /etc/wibutunnel/locked_users.db
    safe_sed_delete "$user" /etc/wibutunnel/user_usage.db
    return 0
}

# perpanjang: tambah durasi dari expiry saat ini.
#   durasi: angka = hari; "30m" = menit, "1h" = jam, "2d" = hari
renew_ssh_user() {
    local user="$1" hari="$2" base new exp add_sec=0
    ssh_valid_user "$user" || { echo "username tidak valid"; return 1; }
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }

    # parsing durasi (menit/jam/hari)
    local val="${hari%[mhd]}"
    case "$hari" in
        *[mM]) add_sec=$(( val * 60 )) ;;
        *[hH]) add_sec=$(( val * 3600 )) ;;
        *[dD]|*[0-9]) add_sec=$(( val * 86400 )) ;;
        *) echo "durasi tidak valid"; return 1 ;;
    esac
    [[ "$add_sec" -le 0 ]] && { echo "durasi tidak valid"; return 1; }

    base=$(db_lookup "$user" "$SSH_EXP_FILE" | cut -d: -f2-)
    if [[ -z "$base" ]]; then
        base=$(chage -l "$user" 2>/dev/null | awk -F': ' '/Account expires/{print $2}')
        [[ -z "$base" || "$base" == "never" ]] && base=$(date +"%Y-%m-%d %H:%M:%S")
    fi
    # [FIX] jangan pakai "date -d "$base + N days"" — '+' disalahbaca sebagai
    # zona waktu (mis. "+ 7" => UTC+7). Gunakan aritmetika epoch.
    local base_sec; base_sec=$(date -d "$base" +%s 2>/dev/null)
    [[ -z "$base_sec" ]] && base_sec=$(date +%s)
    local new_sec=$(( base_sec + add_sec ))
    new=$(date -d "@$new_sec" +"%Y-%m-%d %H:%M:%S")
    chage -E "$(date -d "$new" +%Y-%m-%d)" -M $(( ( $(date -d "$new" +%s) - $(date +%s) ) / 86400 + 1 )) -I 0 "$user" >/dev/null 2>&1
    passwd -u "$user" >/dev/null 2>&1
    safe_sed_delete "$user" "$SSH_EXP_FILE"; echo "${user}:${new}" >> "$SSH_EXP_FILE"
    safe_sed_delete "$user" /etc/wibutunnel/locked_users.db
    printf '%s' "$new"
    return 0
}

lock_ssh_user() {
    local user="$1" reason="${2:-LOCK}" now unlock
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }
    passwd -l "$user" >/dev/null 2>&1
    pkill -u "$user" 2>/dev/null
    now=$(date +%s); unlock=0
    safe_sed_delete "$user" /etc/wibutunnel/locked_users.db
    echo "${user}:${now}:${unlock}:${reason}" >> /etc/wibutunnel/locked_users.db
    return 0
}

unlock_ssh_user() {
    local user="$1"
    ssh_user_exists "$user" || { echo "user tidak ada"; return 1; }
    passwd -u "$user" >/dev/null 2>&1
    safe_sed_delete "$user" /etc/wibutunnel/locked_users.db
    return 0
}

# Sanitasi user input — reject karakter berbahaya
sanitize_user() {
    local u="$1"
    [[ -z "$u" ]] && return 1
    [[ ${#u} -gt 64 ]] && return 1
    [[ "$u" =~ [^a-zA-Z0-9._@-] ]] && return 1
    return 0
}

# ==========================================
# PER-USER STATS TRACKING (xray)
# ==========================================
# Xray hanya mencatat trafik per-user jika email user masuk ke rule routing
# dengan outboundTag="user-stats" (freedom). Tanpa ini, limit kuota per-user
# VLESS/VMESS/TROJAN tidak bisa dihitung (stat hanya per-inbound).
STATS_RULE_OUTBOUND="user-stats"

stats_rule_add() {
    # tambah email user ke routing rule user-stats (idempoten)
    local u="$1"
    [[ -z "$u" || "$u" == "dummy" || "$u" == "api" ]] && return 0
    safe_jq_edit_args --arg u "$u" '
        .routing.rules |= map(
            if .outboundTag == "user-stats" then
                .user = ((.user // []) + [$u] | unique)
            else . end
        )
    ' 2>/dev/null
}

stats_rule_del() {
    # hapus email user dari routing rule user-stats
    local u="$1"
    [[ -z "$u" ]] && return 0
    safe_jq_edit_args --arg u "$u" '
        .routing.rules |= map(
            if .outboundTag == "user-stats" then
                .user = ((.user // []) | map(select(. != $u)))
            else . end
        )
    ' 2>/dev/null
}

# ==========================================
# DETEKSI SESSION LIVE (via ss) + GRACE PERIOD IP HANDOVER
# ==========================================
# Xray official hanya melog "accepted" (tidak ada "closed"), jadi deteksi
# IP-sharing tidak bisa andalkan log saja. Kita baca koneksi ESTABLISHED
# langsung dari socket table (ss) untuk dapat IP client yang BENAR-BENAR
# online saat ini, lalu filter berdasarkan user pemilik koneksi.
#
# GRACE PERIOD: saat client pindah WiFi/handover, IP lama & IP baru bisa
# overlap sebentar. Kita kasih waktu 120 detik sebelum anggap sharing,
# supaya user jujur tidak kena lock palsu.

WIBU_GRACE_PERIOD=120

# xray_live_user_ips: cetak daftar "user ip" untuk koneksi xray yang masih
# ESTABLISHED saat ini. Cara: ambil koneksi ESTABLISHED milik proses xray
# (sport = port inbound xray 10086-10093), dapat peer IP-nya, lalu cocokkan
# IP tsb dengan user yang pernah tercatat di access.log.
xray_live_user_ips() {
    command -v ss >/dev/null 2>&1 || return 0
    # Ambil peer IP dari koneksi established ke port inbound xray.
    # Karena xray listen di 127.0.0.1, peer-nya adalah IP HAProxy (loopback)
    # untuk ws/grpc — TAPI untuk koneksi langsung (trojan tcp biasa), peer
    # adalah IP client asli. Kita ambil semua, nanti difilter di bawah.
    ss -tnH state established 2>/dev/null \
        | awk '$4 ~ /:(10086|10087|10088|10089|10090|10091|10092|10093)$/ {
            split($4, a, ":"); ip=a[1]; split($3, b, ":");
            # simpan: ip client (peer) -> port lokal xray
            print ip, b[2]
        }' | sort -u
}

# xray_log_user_ips: cetak "user ip" dari access.log 3 menit terakhir
# (fallback bila ss tidak tersedia / tidak ada koneksi terdeteksi).
xray_log_user_ips() {
    local THRESH=$(date -d '3 minutes ago' +'%Y/%m/%d %H:%M:%S')
    awk -v thresh="$THRESH" '{
        if($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1" "$2 < thresh) exit
        if(/accepted/){
            for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }
            email=$NF; gsub(/[ \t\r\n]+$/, "", email)
            if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") {
                print email, ip
            }
        }
    }' <(tac /var/log/xray/access.log 2>/dev/null) 2>/dev/null | sort -u
}
