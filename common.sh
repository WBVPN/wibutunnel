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

# Deteksi IP publik — LAZY: jangan panggil jaringan saat source-time.
# Sourcing common.sh tidak boleh menunggu / bergantung jaringan.
MYIP="${MYIP:-}"
detect_myip() {
    [[ -n "$MYIP" ]] && { printf '%s' "$MYIP"; return 0; }
    MYIP=$(curl -4 -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null)
    [[ -z "$MYIP" ]] && MYIP=$(curl -4 -sS --max-time 5 ifconfig.me 2>/dev/null)
    export MYIP
    printf '%s' "$MYIP"
}

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
            chmod 600 "$file" 2>/dev/null || true
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
            chmod 600 "$file" 2>/dev/null || true
        else
            rm -f "$tmp"
            return 1
        fi
    ) 200>"$lockfile"
}

# db_append <file> <line>            -> append baris (flock)
# db_append <user> <value> <file>    -> tulis "user:value" unik+atomik (gaya db_set: flock + dedupe + chmod 600)
db_append() {
    if [[ $# -ge 3 ]]; then
        # bentuk 3-arg A1: db_append <user> <value> <file>
        db_set "$3" "$1" "$2"
        return
    fi
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

# ==========================================
# XRAY INBOUND RESOLUTION (resolve via tag, JANGAN hardcode indeks 1..8)
# ==========================================
# xray_inbound_index <tag>: cetak indeks array inbound dengan tag tsb.
# Non-nol + TANPA output bila tag tidak ditemukan (jangan menebak).
xray_inbound_index() {
    local tag="$1" out="" rc=0
    [[ -n "$tag" && -f "$XRAY_CONFIG" ]] || return 1
    out=$(jq -r --arg t "$tag" '.inbounds | to_entries[] | select(.value.tag == $t) | .key' "$XRAY_CONFIG" 2>/dev/null) || rc=$?
    [[ $rc -ne 0 ]] && return 1
    out="${out%%$'\n'*}"
    [[ -n "$out" ]] || return 1
    printf '%s' "$out"
}

# xray_proto_tags <PROTO>: cetak tag inbound protokol (satu per baris).
xray_proto_tags() {
    case "${1^^}" in
        VLESS)  printf '%s\n' vless-ws-tls vless-ws-ntls vless-grpc ;;
        VMESS)  printf '%s\n' vmess-ws-tls vmess-ws-ntls vmess-grpc ;;
        TROJAN) printf '%s\n' trojan-ws-tls trojan-grpc ;;
        ALL)    printf '%s\n' vless-ws-tls vless-ws-ntls vless-grpc vmess-ws-tls vmess-ws-ntls vmess-grpc trojan-ws-tls trojan-grpc ;;
        *)      return 1 ;;
    esac
}

# xray_primary_index <PROTO>: indeks inbound utama (tag pertama) protokol.
xray_primary_index() {
    local tags
    tags=$(xray_proto_tags "$1") || return 1
    xray_inbound_index "${tags%%$'\n'*}"
}

# xray_del_filter <PROTO>: cetak jq filter hapus client $u (email) dari semua
# inbound protokol + routing block. Non-nol bila ada tag tak ketemu.
xray_del_filter() {
    local proto="$1" t i f="" tags
    tags=$(xray_proto_tags "$proto") || return 1
    for t in $tags; do
        i=$(xray_inbound_index "$t") || return 1
        f+=".inbounds[$i].settings.clients |= map(select(.email != \$u)) | "
    done
    f+='(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))'
    printf '%s' "$f"
}

# xray_add_filter <PROTO>: cetak jq filter tambah client $c ke semua inbound protokol.
xray_add_filter() {
    local proto="$1" t i f="" sep="" tags
    tags=$(xray_proto_tags "$proto") || return 1
    for t in $tags; do
        i=$(xray_inbound_index "$t") || return 1
        f+="${sep}.inbounds[$i].settings.clients += [\$c]"
        sep=" | "
    done
    printf '%s' "$f"
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
    echo -e " Expired On  : ${RED}$(license_expiry_label "$exp")${NC}"
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

# ---------------------------------------------------------------------------
# LISENSI — sumber daftar (dapat dioverride untuk pengujian/pemulihan)
LICENSE_URL="${LICENSE_URL:-https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt}"
LICENSE_URL_DEFAULT="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
LICENSE_MIRROR="${LICENSE_MIRROR:-https://cdn.jsdelivr.net/gh/WBVPN/wibutunnel@main/izin.txt}"
# API GitHub = sumber OTORITATIF: raw.githubusercontent & jsDelivr bisa menyajikan
# izin.txt VERSI LAMA sampai cache-nya kedaluwarsa (terbukti: setelah entri lisensi
# baru di-push, raw masih mengembalikan daftar lama berjam-jam, cache-buster tak
# menolong) -> IP yang sah tertolak. Urutan: API dulu, raw & jsDelivr cadangan.
# API dipakai HANYA bila LICENSE_URL masih bawaan; uji/pemulihan yang meng-override
# LICENSE_URL (mis. file:// fixture) tetap memakai sumbernya sendiri.
LICENSE_API="${LICENSE_API:-https://api.github.com/repos/WBVPN/wibutunnel/contents/izin.txt?ref=main}"
LICENSE_CACHE="${LICENSE_CACHE:-/etc/wibutunnel/tmp/wibu_license.cache}"
# Tanpa jaringan: pakai salinan lokal/cache, tapi maksimal 7 hari (setelah itu tolak).
LICENSE_OFFLINE_GRACE="${LICENSE_OFFLINE_GRACE:-604800}"

# Daftar dianggap SAH hanya bila memuat minimal satu entri utuh
# `### NAMA EXP IP`. Tanpa ini, balasan terpotong/halaman galat
# (yang isinya bukan daftar) diperlakukan sebagai daftar lisensi
# dan membuat IP sah tertolak.
license_valid_list() {
    local l="$1"
    [[ -n "$l" ]] || return 1
    printf '%s\n' "$l" | grep -qE '^### +[^ ]+ +(lifetime|[0-9]{4}-[0-9]{2}-[0-9]{2}) +[0-9]{1,3}(\.[0-9]{1,3}){3}'
}

# Ambil daftar lisensi (API dulu, lalu raw, lalu mirror). Gagal -> return 1.
license_fetch() {
    local out=""
    if [[ -n "${LICENSE_API:-}" && "$LICENSE_URL" == "$LICENSE_URL_DEFAULT" ]]; then
        out=$(curl -4 -sS --max-time 8 --connect-timeout 5 \
                   -H 'Accept: application/vnd.github.raw' \
                   ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
                   "$LICENSE_API" 2>/dev/null) || out=""
        if license_valid_list "$out"; then printf '%s' "$out"; return 0; fi
        [[ -n "$out" ]] && echo -e "${YELLOW}[!] Daftar lisensi dari API tidak utuh, mencoba sumber cadangan…${NC}" >&2
    fi

    out=$(curl -4 -sS --max-time 8 --connect-timeout 5 "$LICENSE_URL" 2>/dev/null) || out=""
    if license_valid_list "$out"; then printf '%s' "$out"; return 0; fi

    if [[ -n "$LICENSE_MIRROR" ]]; then
        out=$(curl -4 -sS --max-time 8 --connect-timeout 5 "$LICENSE_MIRROR" 2>/dev/null) || out=""
        if license_valid_list "$out"; then printf '%s' "$out"; return 0; fi
    fi
    return 1
}

# Cari entri untuk IP tertentu. Pencocokan HARUS persis pada kolom IP
# (sebelumnya `grep -w` bisa cocok kabur karena titik = karakter apa pun).
license_lookup() { # $1=daftar  $2=ip  -> cetak baris entri
    printf '%s\n' "$1" | awk -v ip="$2" '{ for (i = 1; i <= NF; i++) if ($i == ip) { print; exit } }'
}

# Validasi satu entri -> set LICENSE_NAME/LICENSE_EXP, kembalikan 1 bila exp.
license_entry() { # $1=baris entri  -> 0 valid, 1 kedaluwarsa, 2 rusak
    LICENSE_NAME=$(printf '%s' "$1" | awk '{print $2}' | tr -d '\r')
    LICENSE_EXP=$(printf '%s' "$1" | awk '{print $3}' | tr -d '\r')
    [[ -n "$LICENSE_NAME" && -n "$LICENSE_EXP" ]] || return 2
    [[ "${LICENSE_EXP,,}" == "lifetime" ]] && return 0
    local e="$LICENSE_EXP"
    [[ "$e" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && e="$e 23:59:59"
    local s; s=$(date -u -d "$e" +%s 2>/dev/null) || return 2
    [[ -z "$s" ]] && return 2
    [[ $(date -u +%s) -gt $s ]] && return 1
    return 0
}

# Sisa hari menuju EXP (UTC). `lifetime` tidak punya hitungan -> return 1.
# Pembulatan ke BAWAH (permintaan pemilik): lisensi 30 hari tampil "30 Hari".
# Konsekuensi yang disadari: pada hari terakhir masa aktif tampil "0 Hari"
# walaupun lisensi masih berlaku sampai 23:59:59 UTC hari itu.
license_days_left() { # $1=EXP -> cetak angka hari (minimal 0)
    local e="$1" s n
    [[ -z "$e" || "${e,,}" == "lifetime" ]] && return 1
    [[ "$e" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && e="$e 23:59:59"
    s=$(date -u -d "$e" +%s 2>/dev/null) || return 1
    [[ -z "$s" ]] && return 1
    n=$(( (s - $(date -u +%s)) / 86400 ))
    [[ $n -lt 0 ]] && n=0
    printf '%s' "$n"
}

# Label siap tampil. Aturan (diminta pemilik): `lifetime` DICETAK APA ADANYA
# tanpa tambahan; entri bertanggal ditampilkan sebagai "N Hari" saja — tanpa
# tanda kurung (tanggalnya tetap sumber kebenaran di izin.txt & cache, cuma
# tidak dipajang).
license_expiry_label() { # $1=EXP -> "lifetime" | "N Hari"
    local d
    [[ "${1,,}" == "lifetime" ]] && { printf 'lifetime'; return 0; }
    if d=$(license_days_left "$1"); then printf '%s Hari' "$d"; else printf '? Hari'; fi
}

check_license() {
    local CURRENT_TIME; CURRENT_TIME=$(date -u +%s)
    local CACHE_IP="" CACHE_EXP="" CACHE_NAME=""

    detect_myip >/dev/null 2>&1
    if [[ -z "${MYIP:-}" ]]; then
        show_license_denied "tidak terdeteksi (jaringan bermasalah)"
        exit 1
    fi

    # --- 1) Cache lokal: hanya berlaku bila IP-nya SAMA dengan VPS ini
    if [[ -f "$LICENSE_CACHE" ]]; then
        local mtime; mtime=$(stat -c %Y "$LICENSE_CACHE" 2>/dev/null || echo 0)
        IFS='|' read -r _st CACHE_NAME CACHE_EXP CACHE_IP < "$LICENSE_CACHE" 2>/dev/null || true
        if [[ "$CACHE_IP" == "$MYIP" && -n "$CACHE_EXP" ]]; then
            if [[ "${CACHE_EXP,,}" != "lifetime" ]]; then
                local e="$CACHE_EXP"
                [[ "$e" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && e="$e 23:59:59"
                local s; s=$(date -u -d "$e" +%s 2>/dev/null)
                if [[ -z "$s" || $CURRENT_TIME -gt $s ]]; then
                    rm -f "$LICENSE_CACHE"
                    show_license_expired "$CACHE_NAME" "$CACHE_EXP"
                    exit 1
                fi
            fi
            # masih segar -> langsung dipakai (hemat jaringan)
            if [[ $((CURRENT_TIME - mtime)) -le 3600 ]]; then
                export CLIENT_NAME="$CACHE_NAME" EXP_DATE="$CACHE_EXP"
                return 0
            fi
        else
            rm -f "$LICENSE_CACHE"   # cache milik IP lain: jangan dipercaya
        fi
    fi

    # --- 2) Daftar resmi (selalu dari jaringan bila bisa)
    local LIST="" GET_DATA=""
    if LIST=$(license_fetch); then
        GET_DATA=$(license_lookup "$LIST" "$MYIP")
        if [[ -z "$GET_DATA" ]]; then
            rm -f "$LICENSE_CACHE"
            show_license_denied "$MYIP"
            exit 1
        fi
        license_entry "$GET_DATA"; local rc=$?
        if [[ $rc -eq 1 ]]; then
            rm -f "$LICENSE_CACHE"
            show_license_expired "$LICENSE_NAME" "$LICENSE_EXP"
            exit 1
        elif [[ $rc -ne 0 ]]; then
            rm -f "$LICENSE_CACHE"
            show_license_denied "$MYIP (entri rusak, hubungi admin)"
            exit 1
        fi
        export CLIENT_NAME="$LICENSE_NAME" EXP_DATE="$LICENSE_EXP"
        mkdir -p "$(dirname "$LICENSE_CACHE")"
        printf 'VALID|%s|%s|%s\n' "$CLIENT_NAME" "$EXP_DATE" "$MYIP" > "$LICENSE_CACHE"
        chmod 600 "$LICENSE_CACHE"
        return 0
    fi

    # --- 3) Jaringan gagal: salinan lokal / cache lama, maksimal 7 hari
    local FALLBACK_LIST=""
    [[ -f /etc/wibutunnel/izin.txt ]] && FALLBACK_LIST=$(cat /etc/wibutunnel/izin.txt 2>/dev/null)
    if [[ -n "$FALLBACK_LIST" ]]; then
        GET_DATA=$(license_lookup "$FALLBACK_LIST" "$MYIP")
        if [[ -n "$GET_DATA" ]]; then
            license_entry "$GET_DATA"; local rc2=$?
            if [[ $rc2 -eq 0 ]]; then
                echo -e "${YELLOW}[!] Daftar lisensi tidak bisa diambil (jaringan). Memakai salinan lokal.${NC}" >&2
                export CLIENT_NAME="$LICENSE_NAME" EXP_DATE="$LICENSE_EXP"
                return 0
            elif [[ $rc2 -eq 1 ]]; then
                show_license_expired "$LICENSE_NAME" "$LICENSE_EXP"
                exit 1
            fi
        fi
    fi

    if [[ -n "$CACHE_IP" && "$CACHE_IP" == "$MYIP" && -n "$CACHE_EXP" ]]; then
        local mtime2; mtime2=$(stat -c %Y "$LICENSE_CACHE" 2>/dev/null || echo 0)
        if [[ $((CURRENT_TIME - mtime2)) -le $LICENSE_OFFLINE_GRACE ]]; then
            echo -e "${YELLOW}[!] Offline: memakai lisensi tersimpan (maks 7 hari).${NC}" >&2
            export CLIENT_NAME="$CACHE_NAME" EXP_DATE="$CACHE_EXP"
            return 0
        fi
    fi

    rm -f "$LICENSE_CACHE"
    show_license_denied "$MYIP"
    exit 1
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
    awk -v thresh="$thresh" '{ if($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1" "$2 < thresh) exit; if(/accepted/ && /email: /){ for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]" " : "") ip; } } } } END { for (e in ips) print e, ips[e] }' <(tail -n 5000 "$log" 2>/dev/null | tac) 2>/dev/null
}

# ==========================================
# SSH TUNNEL (Dropbear) — backend account
# ==========================================
SSH_GROUP="${SSH_GROUP:-ssh_tunnel}"
# C5: opsi nologin dipilih admin saat install (ditulis setup.sh dengan WIBU_SSH_NOLOGIN=1).
# Tanpa berkas ini, perilaku lama (/bin/bash) TIDAK berubah.
[[ -f /etc/wibutunnel/ssh_shell.conf && -z "${SSH_SHELL:-}" ]] && . /etc/wibutunnel/ssh_shell.conf
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

# ==========================================
# SSH LOGIN CHECK
# ==========================================
ssh_check_login() {
    local user="$1"
    [[ -z "$user" ]] && return 1
    
    # Get active SSH connections for this user
    local count=0
    local ips=""
    
    # Parse ss output for established SSH connections
    while read -r line; do
        [[ -z "$line" ]] && continue
        
        local_port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
        [[ ! "$local_port" =~ ^(22|109|143|2222)$ ]] && continue
        
        remote_full=$(echo "$line" | awk '{print $5}')
        remote_ip=$(echo "$remote_full" | cut -d: -f1)
        
        uid=$(echo "$line" | awk '{print $6}' | grep -oP 'uid:\K\d+')
        [[ -z "$uid" ]] && continue
        
        username=$(id -nu "$uid" 2>/dev/null)
        [[ "$username" != "$user" ]] && continue
        
        ((count++))
        if [[ -n "$ips" ]]; then
            ips="$ips $remote_ip"
        else
            ips="$remote_ip"
        fi
    done < <(ss -tnp state established 2>/dev/null | grep -E 'users:\(\("sshd"')
    
    echo "$count"
    echo "$ips"
    return 0
}
