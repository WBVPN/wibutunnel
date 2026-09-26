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

# Check trial rate limit (max 3 per IP per day)
check_trial_limit() {
    local caller_ip="$1"
    local trial_db="/etc/wibutunnel/tmp/trial_limits.db"
    local max_trials=3
    local cutoff_time=$(($(date +%s) - 86400))  # 24 hours ago
    
    mkdir -p "$(dirname "$trial_db")"
    touch "$trial_db"
    
    # Clean old entries (>24h) atomically
    if [[ -f "$trial_db" ]]; then
        awk -F: -v cutoff="$cutoff_time" '$3 >= cutoff || $0 ~ /^#/' "$trial_db" > "${trial_db}.tmp" 2>/dev/null
        mv "${trial_db}.tmp" "$trial_db" 2>/dev/null || touch "$trial_db"
    fi
    
    # Count trials from this IP in last 24h
    # [FIX M-B6] grep prefix: IP "1.2.3.4" juga hitung entry "1.2.3.40" ->
    # # customer sah diblokir trial lebih awal. Exact field match via awk.
    trial_count=$(awk -F: -v ip="$caller_ip" '$1==ip' "$trial_db" 2>/dev/null | wc -l)
    
    if [[ "$trial_count" -ge "$max_trials" ]]; then
        echo -e "${RED}[!] Limit trial tercapai. Maksimal ${max_trials} trial per IP per 24 jam.${NC}"
        return 1
    fi
    
    return 0
}

# Record trial creation
record_trial() {
    local caller_ip="$1"
    local username="$2"
    local trial_db="/etc/wibutunnel/tmp/trial_limits.db"
    
    echo "${caller_ip}:${username}:$(date +%s)" >> "$trial_db"
}
if [[ -z "$MYIP" ]]; then
    echo -e "${RED}[WARNING] Gagal mendapatkan IP publik. Periksa koneksi internet.${NC}" >&2
fi

# safe_jq_edit: edit xray config.json dengan flock agar tidak race condition
# Usage: safe_jq_edit 'jq_filter_string'
# Atau untuk jq dengan --arg: safe_jq_edit_args --arg u "$user" 'filter'
# [HARDENING] validasi hasil edit sebelum di-commit. jq diam-diam melakukan
# null-padding pada index array di luar jangkauan (mis. .inbounds[999] pada array
# berisi 9 elemen -> array jadi 1000 elemen dengan 990 null). Config seperti itu
# DITOLAK xray ("Listen on AnyIP but no Port(s)") -> service mati total.
# Reject juga jika JSON tidak valid / bukan object.
_xray_validate() {
    local f="$1"
    # [FIX M-B5] Validasi semantik oleh xray sendiri, bukan cuma struktur JSON.
    # jq menerima config yang ditolak xray (semantic) -> restart xray gagal
    # -> SEMUA user VPN down. `xray test -config` mendeteksi yang jq tidak.
    if [[ -x /usr/local/bin/xray ]]; then
        /usr/local/bin/xray test -config "$f" >/dev/null 2>&1 || return 1
    fi
    jq -e '
        type == "object"
        and (.inbounds | type == "array")
        and ([.inbounds[]? | select(. == null)] | length == 0)
        and ([.outbounds[]? | select(. == null)] | length == 0)
        and (.routing.rules | type == "array")
    ' "$f" >/dev/null 2>&1
}

# [M4] Cek config xray bisa dibaca & valid JSON. jq -e exit 1 ambigu: bisa
# berarti "tidak ketak" atau "config rusak/sedang ditulis". Helper ini
# memisahkan: config tidak terbaca = false -> caller TOLAK operasi, bukan
# assume "user tidak ada" lalu lanjut (create/hapus palsu).
_xray_ok() {
    local f="$1"
    [[ -f "$f" ]] || return 1
    jq -e 'type == "object" and (.inbounds | type == "array")' "$f" >/dev/null 2>&1
}

safe_jq_edit() {
    local filter="$1"
    local src="${XRAY_CONFIG}"
    local tmp
    # [FIX M-B7] mktemp di direktori yang SAMA dengan target agar mv atomik
    # # (beda filesystem -> mv = copy non-atomic, jendela config setengah tertulis).
    tmp=$(mktemp "$(dirname "$src")/xray_edit.XXXXXX.json")
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; rm -f "$tmp"; return 1; }
        if jq "$filter" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            if _xray_validate "$tmp"; then
                mv "$tmp" "$src"
                chmod 600 "$src"
            else
                echo "[ERROR] hasil edit tidak valid (null padding/struktur rusak), config tidak diubah" >&2
                rm -f "$tmp"
                return 1
            fi
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
    tmp=$(mktemp "$(dirname "$src")/xray_edit.XXXXXX.json")
    (
        flock -w 30 200 || { echo "[ERROR] flock timeout on xray config" >&2; rm -f "$tmp"; return 1; }
        if jq "$@" "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            if _xray_validate "$tmp"; then
                mv "$tmp" "$src"
                chmod 600 "$src"
            else
                echo "[ERROR] hasil edit tidak valid (null padding/struktur rusak), config tidak diubah" >&2
                rm -f "$tmp"
                return 1
            fi
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
    local today=$(date +%Y-%m-%d)
    
    # Validate date format strictly (YYYY-MM-DD only)
    if [[ ! "$exp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo -e "${RED}[!] ERROR: Invalid license date format: $exp${NC}" >&2
        echo -e "${RED}[!] Expected format: YYYY-MM-DD${NC}" >&2
        return 1  # Treat invalid as expired (fail-safe)
    fi
    
    # String comparison works for ISO dates
    if [[ "$exp" < "$today" ]]; then
        return 0  # expired
    else
        return 1  # not expired
    fi
}

check_license() {
    # [SECURITY] Validate MYIP FIRST before any cache logic
    if [[ -z "$MYIP" ]]; then
        clear
        echo -e "${LINE}\n${RED}AKSES DITOLAK!${NC}\n${LINE}"
        echo -e "${RED}Gagal memverifikasi IP publik (kosong). Periksa koneksi internet.${NC}\n${LINE}"
        exit 1
    fi

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

    # [SECURITY] Daftar lisensi disimpan di repo PRIVATE (WBVPN/wibutunnel-izin).
    # Token diambil dari (berurutan):
    #   1. env var IZIN_TOKEN
    #   2. file lokal /etc/wibutunnel/izin_token  (dibuat saat install)
    # [PERINGATAN] setup.sh mengisi /etc/wibutunnel/izin_token dengan token
    # bawaan supaya fresh install bisa verifikasi. Karena setup.sh ada di repo
    # PUBLIK, token bawaan itu terbaca semua orang -> daftar pelanggan bisa
    # diambil siapa pun. Lihat AI_DEPLOYMENT_INSTRUCTIONS.md bagian kebocoran.
    # Solusi jangka panjang: endpoint allow/deny per-IP, bukan bagikan token.
    local IZIN_TOKEN="${IZIN_TOKEN:-}"
    [[ -z "$IZIN_TOKEN" && -f /etc/wibutunnel/izin_token ]] && IZIN_TOKEN=$(cat /etc/wibutunnel/izin_token 2>/dev/null)
    # [SECURITY] Token via Authorization header, bukan URL userinfo.
    # URL userinfo (https://WBVPN:TOKEN@...) bocor ke `ps`/cmdline curl.
    local IZIN_URL="https://raw.githubusercontent.com/WBVPN/wibutunnel-izin/main/izin.txt"
    local GET_DATA=$(curl -sS --max-time 10 -H "Authorization: token ${IZIN_TOKEN}" "$IZIN_URL" | grep -F -w "$MYIP")

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

# ==========================================
# [FIX ROBUSTNESS] Pembacaan bot.conf tahan banting
# ==========================================
# bot.conf di-`source` oleh 11 script berbeda. `source` mem-parsing SELURUH
# file sebagai kode bash: SATU baris cacat (mis. hasil edit manual seperti
# "CHAT ID=..." yang bukan assignment valid, baris kosong berisi spasi, atau
# CRLF dari editor Windows) membuat `source` berhenti di baris itu dan
# SEMUA baris setelahnya tidak pernah dibaca.
# Gejala nyata: "Bot Telegram: Aktif (8918...)" tapi "ID Telegram: Belum
# disetting" - BOT_TOKEN (di atas baris cacat) terbaca, CHAT_ID (di bawahnya)
# tidak. Lapor di VPS mynusa2.
#
# load_bot_conf() hanya mengambil baris assignment yang VALID, mengabaikan
# baris rusak, dan memakai whitelist key (anti injeksi script).
load_bot_conf() {
    local _f="/etc/wibutunnel/bot.conf"
    [[ -f "$_f" ]] || return 0
    local _line _key _val
    while IFS= read -r _line || [[ -n "$_line" ]]; do
        _line="${_line%$'\r'}"
        [[ "$_line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
        _key="${BASH_REMATCH[1]}"
        _val="${BASH_REMATCH[2]}"
        # singkirkan kutipan yang membingkai nilai. Pakai case+parameter
        # expansion, BUKAN [[ =~ ]]: dalam [[ =~ ]] bagian pattern yang
        # di-quote di-strip oleh bash sehingga matchernya jadi ^(.*), salah.
        case "$_val" in
            \'*\') _val="${_val:1:${#_val}-2}" ;;
            \"*\") _val="${_val:1:${#_val}-2}" ;;
        esac
        # [KEAMANAN] hanya key dikenal yang dieksekusi, bukan nama variabel bebas
        case "$_key" in
            BOT_TOKEN|CHAT_ID|WEBHOOK_SECRET) printf -v "$_key" '%s' "$_val" ;;
        esac
    done < "$_f"
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
    # WARNING: Plaintext storage required for HTTP Custom config generation
    # Ensure SSH_DB_PASS has mode 600 and owned by root only
    safe_sed_delete "$user" "$SSH_DB_PASS";   echo "${user}:${pass}" >> "$SSH_DB_PASS"
    safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db; echo "${user}:${lip}" >> /etc/wibutunnel/limit_ip.db
    safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db; echo "${user}:${lbw}" >> /etc/wibutunnel/limit_bw.db
    chmod 600 "$SSH_DB_PASS" /etc/wibutunnel/*.db
    chown root:root "$SSH_DB_PASS" /etc/wibutunnel/*.db 2>/dev/null
    return 0
}

del_ssh_user() {
    local user="$1"
    ssh_valid_user "$user" || { echo "username tidak valid"; return 1; }
    ssh_user_exists "$user" || { echo "user $user tidak ada"; return 1; }
    
    # Get UID before deletion for iptables cleanup
    local uid=$(id -u "$user" 2>/dev/null)
    
    pkill -u "$user" 2>/dev/null; sleep 1
    userdel -r "$user" >/dev/null 2>&1 || userdel "$user" >/dev/null 2>&1
    
    # Clean iptables rules if UID was found
    if [[ -n "$uid" ]]; then
        iptables -t mangle -D OUTPUT -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null
        iptables -t mangle -D INPUT -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null
    fi
    
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
    # [FIX B4] Cap input raksasa: (( base + val*86400 )) wrap 64-bit ->
    # date "out of range" -> new_exp KOSONG -> akun Lifetime (bypass komersial).
    [[ "$val" =~ ^[0-9]+$ ]] || { echo "durasi tidak valid"; return 1; }
    (( val > 0 && val <= 525600 )) || { echo "durasi di luar batas (maks 1 tahun)"; return 1; }
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
    # [FIX] echo >> gagal diam bila file/dir tidak ada (SSH_EXP_FILE belum
    # # dibuat) -> menu bilang BERHASIL tapi expiry tak tersimpan ke DB.
    mkdir -p "$(dirname "$SSH_EXP_FILE")" 2>/dev/null
    safe_sed_delete "$user" "$SSH_EXP_FILE"
    echo "${user}:${new}" >> "$SSH_EXP_FILE" || return 1
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
    # [FIX C4] Nama ini adalah satu-satunya isi rule "blocked" awal (setup.sh).
    # Membuat user bernama DUMMY-LOCK lalu menghapusnya akan mengosongkan array
    # user rule tsb -> xray menolak config -> service mati total.
    [[ "$u" == "DUMMY-LOCK" ]] && return 1
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
    # [FIX] kalau outbound/rule user-stats belum ada (config hasil installer
    # lama), rule ini no-op -> kuota user tidak pernah tercatat. Buat dulu.
    if ! jq -e 'any(.outbounds[]?; .tag == "user-stats")' "$XRAY_CONFIG" >/dev/null 2>&1; then
        safe_jq_edit_args --arg u "$u" '
            .outbounds += [{"protocol":"freedom","settings":{"accountStats":true},"tag":"user-stats"}]
            | .routing.rules += [{"type":"field","outboundTag":"user-stats","user":[$u]}]
        ' 2>/dev/null
        return $?
    fi
    safe_jq_edit_args --arg u "$u" '
        .routing.rules |= map(
            if .outboundTag == "user-stats" then
                .user = ((.user // []) + [$u] | unique)
            else . end
        )
        | if (.routing.rules | all(.outboundTag != "user-stats")) then
              .routing.rules += [{"type":"field","outboundTag":"user-stats","user":[$u]}]
          else . end
    ' 2>/dev/null
}

stats_rule_del() {
    # hapus email user dari routing rule user-stats
    local u="$1"
    [[ -z "$u" ]] && return 0
    # [FIX] rule dengan user:[] DITOLAK xray ("this rule has no effective
    # fields") -> service mati total. Hapus seluruh rule jika jadi kosong.
    safe_jq_edit_args --arg u "$u" '
        .routing.rules |= map(
            if .outboundTag == "user-stats" then
                .user = ((.user // []) | map(select(. != $u)))
            else . end
        )
        | .routing.rules |= map(
            if .outboundTag == "user-stats" and ((.user // []) | length) == 0 then empty
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

# ==========================================
# GEO-IP LOOKUP (CITY / ISP) — cached, anti-hang
# ==========================================
# ip-api.com sering dipanggil saat buat akun (banyak titik di menu). Tanpa
# cache & tanpa --max-time, tiap pembuatan akun menunggu ip-api yang lambat/
# down -> menu terasa hang. Solusi: cache 10 menit di file + timeout ketat
# 4 detik + fallback "Unknown" (tidak pernah memblokir pembuatan akun).
WIBU_GEO_CACHE="/etc/wibutunnel/tmp/geo.cache"
WIBU_GEO_TTL=600

# get_geo: cetak 2 baris (CITY\nISP). Fallback aman bila offline.
get_geo() {
    local now mtime cached_city cached_isp fresh
    now=$(date +%s)
    if [[ -f "$WIBU_GEO_CACHE" ]]; then
        mtime=$(stat -c %Y "$WIBU_GEO_CACHE" 2>/dev/null || echo 0)
        if [[ $((now - mtime)) -le $WIBU_GEO_TTL ]]; then
            { read -r cached_city; read -r cached_isp; } < "$WIBU_GEO_CACHE" 2>/dev/null
            if [[ -n "$cached_city" || -n "$cached_isp" ]]; then
                printf '%s\n%s\n' "${cached_city:-Unknown}" "${cached_isp:-Unknown}"
                return 0
            fi
        fi
    fi
    fresh=$(curl -sS --max-time 4 "http://ip-api.com/line/?fields=city,isp" 2>/dev/null)
    if [[ -n "$fresh" ]]; then
        printf '%s\n%s\n' "${fresh%%$'\n'*}" "${fresh##*$'\n'}" > "$WIBU_GEO_CACHE" 2>/dev/null
        printf '%s\n%s\n' "${fresh%%$'\n'*}" "${fresh##*$'\n'}"
        return 0
    fi
    # fallback: cache lama (boleh kadaluarsa) atau Unknown
    if [[ -f "$WIBU_GEO_CACHE" ]]; then
        cat "$WIBU_GEO_CACHE" 2>/dev/null
        return 0
    fi
    printf 'Unknown\nUnknown\n'
}

# get_city / get_isp: aksesoris untuk pemanggil yang cuma butuh satu field.
get_city() { get_geo | sed -n '1p'; }
get_isp()  { get_geo | sed -n '2p'; }

# Safe flat-file DB write with flock
# Usage: safe_db_write "user:value" "$DB_FILE"

# Safe flat-file DB delete with flock
# Usage: safe_db_delete "user" "$DB_FILE"

# [FIX H6] Helper Telegram: token TIDAK boleh muncul di argv proses curl
# (terlihat di /proc/*/cmdline untuk user lokal selama curl jalan -> takeover
# bot). curl -K - membaca config dari stdin; URL tidak terlihat di argv.
# Usage: tg_curl <method> [curl args...]   -> GET  api.telegram.org/bot<TOKEN>/<method>
#        tg_curl -X POST <method> ...      -> POST
tg_curl() {
    # [FIX B1] Format call site: "tg_curl sendMessage ..." atau
    # "tg_curl -X POST sendMessage ...". Sebelumnya "-X" dianggap method ->
    # request ke /bot<TOKEN>/-X -> 404, SEMUA notifikasi -X POST gagal diam-diam.
    local method="$1"; shift
    local xpost=()
    if [[ "$method" == "-X" ]]; then
        xpost=(-X "$1"); method="$2"; shift 2
    fi
    curl -s -K - "${xpost[@]}" "$@" <<TGCONF 2>/dev/null
url = "https://api.telegram.org/bot${BOT_TOKEN}/${method}"
TGCONF
}
