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

# live_ip_pairs: cetak "<user> <ip> <ip> ..." dari access.log dalam jendela LIVE_IP_WINDOW.
# Asosiasi user<->IP murni dari log (xray melihat IP asli karena rantai haproxy
# mengirim PROXY protocol v2: ssl_sni -> hub(accept-proxy) -> xray(acceptProxyProtocol)).
# ponytail: perangkat yang idle lebih lama dari jendela ini lepas dari hitungan walau
#           socket-nya masih terbuka. `ss`/conntrack TIDAK dipakai: pada box ini peer
#           :443 berisi IP haproxy/Cloudflare, bukan IP client.
#           Upgrade path: ekspos jumlah koneksi aktif per-user dari xray (butuh plugin).
# ==========================================
# CDN / CLOUDFLARE IP (v4.1.38)
#
# Kalau domain dilayani lewat CDN, access.log mencatat IP edge CDN, bukan IP
# pelanggan. Satu orang bisa muncul sebagai 40+ "IP" (terukur di VPS: akun
# 'admin' kena limit 10 padahal cuma satu perangkat, karena 162.158.x,
# 172.64.x, 104.23.x semuanya milik Cloudflare AS13335).
#
# IP CDN BUKAN identitas -> tidak boleh dihitung sebagai "IP login".
# Daftar: https://www.cloudflare.com/ips/  (IPv4 + IPv6)
# Matikan dengan WIBU_IP_IGNORE_CDN=0 bila ingin perilaku lama.
# ==========================================
_IP_CDN4="173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18
108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17
162.158.0.0/15 104.16.0.0/13 172.64.0.0/13 131.0.72.0/22"

ip_is_cdn() { # $1=ip -> 0 bila termasuk rentang CDN (Cloudflare)
    local ip="${1%%[[:space:]]*}" cidr net bits n mask
    local a b c d v4
    [[ -n "$ip" ]] || return 1

    if [[ "$ip" == *:* ]]; then
        case "${ip,,}" in
            2400:cb00:*|2606:4700:*|2803:f800:*|2405:b500:*|2405:8100:*|2a06:98c0:*|2c0f:f248:*) return 0 ;;
        esac
        return 1
    fi

    IFS=. read -r a b c d <<< "$ip"
    [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ && "$c" =~ ^[0-9]+$ && "$d" =~ ^[0-9]+$ ]] || return 1
    (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )) || return 1
    v4=$(( (a << 24) + (b << 16) + (c << 8) + d ))

    for cidr in $_IP_CDN4; do
        net="${cidr%/*}"; bits="${cidr#*/}"
        IFS=. read -r a b c d <<< "$net"
        n=$(( (a << 24) + (b << 16) + (c << 8) + d ))
        mask=$(( (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
        (( (v4 & mask) == (n & mask) )) && return 0
    done
    return 1
}

live_ip_pairs() {
    local log="${XRAY_ACCESS_LOG:-/var/log/xray/access.log}"
    local thresh
    [[ ! -s "$log" ]] && return 0
    # WIBU_IP_TTL / LIVE_IP_WINDOW: jendela "masih terhubung" untuk jalur XRAY.
    # [v4.1.39] Diturunkan 600 -> 60 detik. Alasannya di lapangan: dengan 600 detik,
    # pelanggan yang sudah berhenti konek masih dihitung memakai IP lama, sehingga
    # pindah jaringan (WiFi -> data) dalam 10 menit terhitung 2 IP dan kena kunci
    # padahal satu orang satu perangkat. 60 detik = "ada trafik dalam satu menit
    # terakhir", jadi hitungannya mendekati koneksi yang benar-benar hidup.
    # Jalur SSH tidak memakai jendela waktu sama sekali: dihitung dari socket
    # ESTABLISHED (lihat ssh_ss_lines).
    # Nilai bisa ditulis sebagai angka polos ("60" = 60 detik) atau dengan satuan
    # ("120 seconds"). Kalau nilainya rusak, JANGAN menghitung seluruh isi log —
    # dulu thresh menjadi kosong dan semua baris dianggap "aktif" (kunci palsu).
    local _win="${LIVE_IP_WINDOW:-${WIBU_IP_TTL:-60}}"
    [[ "$_win" =~ ^[0-9]+$ ]] && _win="$_win seconds"
    thresh=$(date -d "$_win ago" +'%Y/%m/%d %H:%M:%S' 2>/dev/null)
    [[ -n "$thresh" ]] || thresh=$(date +'%Y/%m/%d %H:%M:%S')
    awk -v thresh="$thresh" '
        { if ($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1 " " $2 < thresh) exit }
        /accepted/ && /email: / {
            em = ""; ip = ""
            for (i = 1; i <= NF; i++) {
                if ($i == "accepted") {
                    ip = $(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); gsub(/[\[\]]/, "", ip)
                } else if ($i == "email:") {
                    em = $(i+1)
                }
            }
            # nama user xray boleh mengandung titik/@ (a-zA-Z0-9._@-) -> jangan dibuang
            gsub(/[^a-zA-Z0-9._@-]/, "", em)
            if (em != "" && em != "dummy" && em != "api" && ip != "" && ip != "127.0.0.1" && ip != "::1") {
                if (!seen[em, ip]++) ips[em] = (ips[em] ? ips[em] " " : "") ip
            }
        }
        END { for (e in ips) print e, ips[e] }
    ' <(tail -n 5000 "$log" 2>/dev/null | tac) 2>/dev/null | while read -r _u _ips; do
        local keep="" _ip
        for _ip in $_ips; do
            if [[ "${WIBU_IP_IGNORE_CDN:-1}" == "1" ]] && ip_is_cdn "$_ip"; then continue; fi
            keep="$keep $_ip"
        done
        [[ -n "${keep// /}" ]] && printf '%s %s\n' "$_u" "${keep# }"
    done
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

# --- Deteksi sesi SSH -------------------------------------------------------
# Fakta lapangan (dibuktikan di VPS uji 24.04): proses PEMILIK socket sesi adalah
# dropbear yang masih jalan sebagai ROOT; shell user (`bash`) adalah ANAK dari
# proses itu. Jadi `ps -o user= -p <pid-socket>` selalu "root" -> seluruh
# penilaian per-user (jumlah sesi, limit IP, "user aktif") gagal dan limit tak
# pernah terpicu. Pemetaannya harus menelusuri KETURUNAN sampai ketemu non-root.

# Pisah satu baris `ss -tnp` -> "<port>\t<pid>\t<peer-ip>"
ssh_parse_line() { # $1=baris ss
    local l="$1" lp pid ip
    lp=$(printf '%s\n' "$l" | awk '{print $3}'); lp=${lp##*:}
    pid=$(printf '%s\n' "$l" | awk '{print $5}' | grep -oP 'pid=\K[0-9]+' | tail -1)
    ip=$(printf '%s\n' "$l" | awk '{print $4}'); ip=${ip%:*}; ip=${ip#[}; ip=${ip%]}
    printf '%s\t%s\t%s\n' "$lp" "$pid" "$ip"
}

# Baris `ss` yang benar-benar sesi SSH (22=sshd, 109/143=dropbear langsung, 2222=dropbear loopback/WS)
SSH_SESSION_PORTS='^(22|109|143|2222)$'
ssh_ss_lines() {
    local l lp
    while IFS= read -r l; do
        [[ -n "$l" ]] || continue
        # Sumber hidup: `ss -tnp state established` (hanya socket yang benar-benar
        # tersambung). SSH_SS_SRC dipakai uji offline, dan karena itu berkas contoh
        # tidak difilter nama program.
        if [[ -z "${SSH_SS_SRC:-}" ]]; then
            printf '%s\n' "$l" | grep -Eq 'dropbear|sshd' || continue
        fi
        lp=$(ssh_parse_line "$l" | cut -f1)
        [[ "$lp" =~ $SSH_SESSION_PORTS ]] && printf '%s\n' "$l"
    done < <( [[ -n "${SSH_SS_SRC:-}" ]] && cat "$SSH_SS_SRC" || ss -tnp state established 2>/dev/null )
}

# Peta pid->user dari log autentikasi dropbear. Dropbear dijalankan dengan -E
# (log ke stderr -> journald), jadi auth.log TIDAK berisi jejak login. Peta ini
# wajib untuk sesi TANPA shell (`ssh -N -D` / `-L`): uid pelanggan tidak muncul
# di keturunan proses sama sekali, satu-satunya jejak identitas ada di log ini.
ssh_auth_parse() { # stdin: baris log dropbear -> "pid user"
    sed -nE "s/.*dropbear\[([0-9]+)\].*auth succeeded for '([^']+)'.*/\1 \2/p" \
    | awk '{a[$1] = $2} END { for (p in a) print p, a[p] }'
}

ssh_auth_map_refresh() { # SSH_AUTH_LOG_SRC = berkas contoh (untuk uji offline)
    local out
    if [[ -n "${SSH_AUTH_LOG_SRC:-}" ]]; then
        out=$(ssh_auth_parse < "$SSH_AUTH_LOG_SRC")
    else
        out=$({ journalctl -u dropbear --since "-6 hours" --no-pager 2>/dev/null
                grep -h "auth succeeded" /var/log/auth.log /var/log/auth.log.1 2>/dev/null
              } | ssh_auth_parse)
    fi
    SSH_AUTH_MAP="$out"
}

ssh_auth_user_of_pid() { # $1=pid -> cetak user (return 1 bila tak ada di log)
    [[ -n "${SSH_AUTH_MAP:-}" ]] || ssh_auth_map_refresh
    local p="$1" u
    u=$(awk -v p="$p" '$1 == p { print $2 }' <<<"$SSH_AUTH_MAP" 2>/dev/null)
    [[ -n "$u" ]] && { printf '%s' "$u"; return 0; }
    return 1
}

# User sesi dari pid pemilik socket: turun ke keturunan pertama yang merupakan
# AKUN NYATA (uid >= 1000). Wajib begitu karena sshd 24.04 punya user sistem
# `sshd` (uid 105) untuk privsep -> koneksi brute-force port 22 akan terbaca
# seolah sesi milik user "sshd". Pelanggan panel selalu uid >= 1000 (useradd).
# [v4.1.36] Cache pid->user. Tanpa ini setiap soket `ssh -N` memicu `journalctl`
# (~150 ms) dan satu siklus sampler bisa melewati 1 detik -> byte di ujung sesi hilang.
declare -gA SSH_PID_USER_CACHE=() 2>/dev/null || true
_SSH_PID_CACHE_TS=0
SSH_PID_CACHE_TTL="${SSH_PID_CACHE_TTL:-15}"

ssh_pid_session_user() { # $1=pid -> cetak user (return 1 bila tak ada)
    local _now=${EPOCHSECONDS:-$(date +%s)}
    if (( _now - _SSH_PID_CACHE_TS > SSH_PID_CACHE_TTL )); then
        SSH_PID_USER_CACHE=(); _SSH_PID_CACHE_TS=$_now
    fi
    if [[ -n "${SSH_PID_USER_CACHE[$1]:-}" ]]; then
        printf '%s' "${SSH_PID_USER_CACHE[$1]}"; return 0
    fi
    local _u
    if _u=$(_ssh_pid_session_user_uncached "$1"); then
        SSH_PID_USER_CACHE[$1]="$_u"
        printf '%s' "$_u"; return 0
    fi
    return 1
}

_ssh_pid_session_user_uncached() {
    local pid="$1" u uid p i=0
    while [[ -n "$pid" && $i -lt 4 ]]; do
        u=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' \n')
        uid=$(id -u "$u" 2>/dev/null)
        if [[ -n "$u" && "$uid" =~ ^[0-9]+$ && "$uid" -ge 1000 ]]; then
            printf '%s' "$u"; return 0
        fi
        p=$(pgrep -P "$pid" 2>/dev/null | head -1)
        [[ -z "$p" ]] && break
        pid="$p"; i=$((i+1))
    done
    # Sesi tanpa shell (ssh -N -D / -L): identitas hanya ada di log dropbear.
    ssh_auth_user_of_pid "$1"
}

# Snapshot sesi: satu baris per sesi -> "<user>\t<ip-klien|via-WS>"
# Sesi lewat WS (443) tiba di dropbear dari 127.0.0.1; IP klien aslinya dicatat
# ws-stunnel di ws_client_ip.log, dipetakan lewat PORT LOKAL soket yang dipakai
# ws-stunnel menghubungi dropbear (port itulah yang tampak sebagai peer port).
WS_IP_LOG="${WS_IP_LOG:-/etc/wibutunnel/tmp/ws_client_ip.log}"
WS_IP_TTL="${WS_IP_TTL:-3600}"   # catatan lebih tua dari ini diabaikan (nomor port bisa dipakai ulang)
ws_client_ip_of_port() { # $1=port -> cetak IP (return 1 bila tak ada catatan segar)
    [[ -f "$WS_IP_LOG" ]] || return 1
    local ip now
    now=$(date +%s)
    ip=$(awk -v p="$1" -v now="$now" -v ttl="$WS_IP_TTL" \
        '$1==p && (now - $3) <= ttl {last=$2} END {if (last!="") print last}' "$WS_IP_LOG" 2>/dev/null)
    [[ -n "$ip" ]] && { printf '%s' "$ip"; return 0; }
    return 1
}

ssh_sessions_snapshot() {
    local l pid u ip f port
    ssh_ss_lines | while IFS= read -r l; do
        f=$(ssh_parse_line "$l"); pid=$(printf '%s' "$f" | cut -f2); ip=$(printf '%s' "$f" | cut -f3)
        [[ -n "$pid" ]] || continue
        u=$(ssh_pid_session_user "$pid") || continue
        # peer loopback = jalur WS: coba petakan ke IP asli dari catatan ws-stunnel
        if [[ "$ip" == 127.* || "$ip" == "::1" ]]; then
            port=$(printf '%s\n' "$l" | awk '{print $4}'); port=${port##*:}
            ip=$(ws_client_ip_of_port "$port") || ip="via-WS"
        fi
        printf '%s\t%s\n' "$u" "$ip"
    done
}

ssh_session_count() { # $1=user -> jumlah sesi aktif
    ssh_sessions_snapshot | awk -F'\t' -v u="$1" '$1==u {n++} END {print n+0}'
}

ssh_active_ips() { # $1=user -> IP unik jalur langsung (WS tak terlihat di ss)
    local _ip
    ssh_sessions_snapshot | awk -F'\t' -v u="$1" '$1==u && $2!="via-WS" {print $2}' | sort -u | while read -r _ip; do
        [[ -z "$_ip" ]] && continue
        if [[ "${WIBU_IP_IGNORE_CDN:-1}" == "1" ]] && ip_is_cdn "$_ip"; then continue; fi
        printf '%s ' "$_ip"
    done
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
    # Renew = periode baru: pemakaian kuota dimulai dari nol (kalau tidak, akun yang
    # sudah menyentuh limit akan langsung terkunci lagi sesaat setelah diperpanjang).
    usage_reset "$user"
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


# ==========================================
# AKUNTANSI PEMAKAIAN SSH (byte per sesi, dari kernel)
# ==========================================
# Kenapa BUKAN iptables per-uid: trafik pelanggan SSH tidak dimiliki proses
# miliknya (shell-nya ringan), tapi diproksikan proses dropbear milik root.
# Aturan `-m owner --uid-owner <user>` karenanya mencatat ~0 byte, dan di
# hook INPUT ditolak sama sekali oleh backend nft. Jadi angka diambil dari
# counter KERNEL PER-SOKET (tcp_info via `ss -tie`): byte_sent + byte_received
# pada soket sesi. Semua forward SSH (SHELL/SOCKS/-L/-R) lewat soket itu juga,
# jadi totalnya = trafik pelanggan pada sesi tersebut.
ACCT_DB="${ACCT_DB:-/etc/wibutunnel/user_acct.db}"
USAGE_DB="${USAGE_DB:-/etc/wibutunnel/user_usage.db}"

acct_init() {
    touch "$ACCT_DB" "$USAGE_DB" 2>/dev/null
    chmod 600 "$ACCT_DB" "$USAGE_DB" 2>/dev/null
    return 0
}

# ssh_sessions_bytes [berkas] — kosong = baca langsung dari kernel.
# Cetak: "<port_lokal> <pid> <total_byte>"
ssh_sessions_bytes() {
    local src="${1:-}" listen_ports=""
    # [v4.1.35] Hanya soket SISI-KLIEN (pelanggan) yang dihitung.
    #
    # Dua bug sebelumnya:
    #  1) semua soket milik dropbear dijumlahkan, termasuk soket KELUAR yang dibuat
    #     trafik pelanggan sendiri (ssh -D/-L) -> satu unduhan terhitung dua kali;
    #  2) soket dikenali "sisi-klien" lewat baris LISTEN, padahal `ss -tie -tnp`
    #     tidak mencetak LISTEN tanpa `-l` -> daftar port kosong -> SEMUA soket
    #     dibuang dan pemakaian tercatat 0.
    # Port listen kini dibaca dari `ss -tlnp` (atau dari berkas fixture bila diuji),
    # dan soket dianggap sisi-klien bila port lokalnya port listen dropbear/sshd
    # (jalur langsung) atau peer-nya loopback (jalur SSH-over-WS lewat ws-stunnel).
    local prog='
        function flush_prev() {
            if (cur_port != "") {
                n++
                lp[n] = cur_port; pa[n] = cur_peer
                bs[n] = (sent == "" ? 0 : sent); br[n] = (recv == "" ? 0 : recv)
                pd[n] = pid; li[n] = is_listen; ssh[n] = is_ssh
            }
            cur_port = ""; cur_peer = ""; pid = ""; sent = ""; recv = ""; is_listen = 0; is_ssh = 0
        }
        /^[^ \t]/ {
            flush_prev()
            split($4, a, ":")
            cur_port = a[length(a)]
            cur_peer = $5; sub(/:[^:]*$/, "", cur_peer); gsub(/[\[\]]/, "", cur_peer)
            if (index($0, "pid=") > 0) { t = $0; sub(/.*pid=/, "", t); sub(/[^0-9].*/, "", t); pid = t }
            if ($0 ~ /users:\(\("dropbear"|users:\(\("sshd"/) is_ssh = 1
            if (index($0, "LISTEN") > 0) is_listen = 1
            next
        }
        {
            if (index($0, "bytes_sent:") > 0) { t = $0; sub(/.*bytes_sent:/, "", t); sub(/[^0-9].*/, "", t); sent = t }
            if (index($0, "bytes_received:") > 0) { t = $0; sub(/.*bytes_received:/, "", t); sub(/[^0-9].*/, "", t); recv = t }
        }
        END {
            flush_prev()
            for (i = 1; i <= n; i++) {
                if (li[i] == 1 || pd[i] == "" || ssh[i] != 1) continue
                sisi_klien = (("," LP ",") ~ ("," lp[i] ",")) || (pa[i] ~ /^(127\.|::1$)/)
                if (!sisi_klien) continue
                total = bs[i] + br[i]
                if (total > 0) print lp[i], pd[i], total
            }
        }'

    if [[ -n "$src" ]]; then
        listen_ports=$(awk '/LISTEN/ && /users:\(\("(dropbear|sshd)"/ { n = split($4, a, ":"); print a[n] }' "$src" 2>/dev/null | sort -u | paste -sd, -)
        awk -v LP="$listen_ports" "$prog" < "$src"
    else
        # port listen jarang berubah -> cache 60 detik (ss -tlnp ~29 ms tiap siklus itu mahal)
        local now=${EPOCHSECONDS:-$(date +%s)}
        if [[ -z "${_SSH_LISTEN_CACHE:-}" ]] || (( now - ${_SSH_LISTEN_TS:-0} > 60 )); then
            _SSH_LISTEN_CACHE=$(ss -tlnp 2>/dev/null | awk '/users:\(\("(dropbear|sshd)"/ { n = split($4, a, ":"); print a[n] }' | sort -u | paste -sd, -)
            _SSH_LISTEN_TS=$now
        fi
        listen_ports="$_SSH_LISTEN_CACHE"
        ss -tie -tnp 2>/dev/null | awk -v LP="$listen_ports" "$prog"
    fi
}

# acct_apply_one <key> <user> <total_byte>: tambahkan DELTA ke USAGE_DB.
# key = identitas soket (pid.port) supaya pembacaan berulang tidak dobel hitung;
# total turun (soket/PID baru) diperlakukan sebagai mulai dari nol, bukan negatif.
acct_apply_one() {
    local key="$1" u="$2" total="$3" prev delta
    [[ -z "$key" || -z "$u" || ! "$total" =~ ^[0-9]+$ ]] && return 0
    prev=$(db_get "$key" "$ACCT_DB" | cut -d: -f1)
    [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
    if (( total >= prev )); then delta=$(( total - prev )); else delta=$total; fi
    db_set "$ACCT_DB" "$key" "$total"
    (( delta > 0 )) && usage_add "$u" "$delta"
    return 0
}

usage_apply_ssh() { # [berkas-keluaran-ss] — pemetaan sesi->user + akumulasi
    # [v4.1.33] Dua pemanggil bisa jalan bersamaan (algojo-kuota 60 dtk + wibu-acct 1 dtk).
    # acct_apply_one adalah baca-ubah-tulis atas ACCT_DB dan USAGE_DB; tanpa lock keduanya
    # bisa membaca `prev` yang sama lalu menghitung delta yang sama dua kali.
    local _lock="${ACCT_LOCK:-/etc/wibutunnel/tmp/ssh_acct.lock}"
    mkdir -p "$(dirname "$_lock")" 2>/dev/null || true
    ( flock -w 15 199 || exit 0
      _usage_apply_ssh_body "$@"
    ) 199>"$_lock"
}

_usage_apply_ssh_body() { # [berkas-keluaran-ss]
    local port pid total key u counters
    local -A seen=()
    acct_init
    counters=$(ssh_sessions_bytes "${1:-}")
    [[ -z "$counters" ]] && return 0
    while read -r port pid total; do
        [[ -z "$port" || -z "$pid" || -z "$total" ]] && continue
        u=$(ssh_pid_session_user "$pid") || continue
        key="${pid}.${port}"
        seen["$key"]=1
        acct_apply_one "$key" "$u" "$total"
    done <<<"$counters"
    # bersihkan ledger soket yang sudah tutup (total tetap tersimpan di USAGE_DB)
    local k
    while IFS=: read -r k _; do
        [[ -n "$k" ]] || continue
        [[ -n "${seen[$k]:-}" ]] && continue
        db_delete "$k" "$ACCT_DB"
    done < "$ACCT_DB"
    return 0
}

usage_add() { # $1=user $2=byte -> tambah ke total (format user:total:last)
    local u="$1" add="$2" cur total last
    cur=$(db_get "$u" "$USAGE_DB")
    total="${cur%%:*}"; last="${cur##*:}"
    [[ "$total" =~ ^[0-9]+$ ]] || total=0
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    db_set "$USAGE_DB" "$u" "$(( total + add )):$last"
}

xray_quota_awk() { # input: "<nama_stat> <nilai>" per baris -> "user <total byte>"
    awk '{
        split($1, p, ">>>")
        if (p[1] != "user") next
        if (p[2] == "") next
        if (p[4] != "uplink" && p[4] != "downlink") next
        sum[p[2]] += ($NF + 0)
      }
      END { for (u in sum) print u, sum[u] }'
}

xray_quota_parse() { # stdin: JSON `xray api statsquery` -> "user <total byte>"
    jq -r '.stat[]? | select(.name | startswith("user>>>")) | "\(.name) \(.value // 0)"' 2>/dev/null \
    | xray_quota_awk
}

usage_of() { # $1=user -> total byte
    local v; v=$(db_get "$1" "$USAGE_DB"); v="${v%%:*}"
    [[ "$v" =~ ^[0-9]+$ ]] || v=0
    printf '%s' "$v"
}

usage_reset() { # $1=user -> pemakaian mulai dari nol (renew / restore)
    db_delete "$1" "$USAGE_DB"
    return 0
}

usage_gb_label() { awk -v b="${1:-0}" 'BEGIN{printf "%.2f GB", b/1073741824}'; }

# ==========================================
# PENEGAKAN KUOTA SSH JALUR CEPAT (v4.1.37)
#
# algojo-kuota berjalan tiap 60 detik. Pelanggan yang melewati limit masih bisa
# menarik data selama sisa siklus itu (terukur 11 MB/s -> +-600 MB). Fungsi di
# bawah ini memeriksa HANYA akun SSH (tanpa statsquery xray, tanpa tulis config)
# sehingga cukup murah untuk dipanggil tiap beberapa detik dari wibu-acct.
#
# Semua jalur penguncian tetap lewat lock_ssh_user() di atas, dan teks pesan
# dibangun kuota_ssh_lock_message() supaya jalur cepat & jalur lambat tidak
# pernah berbeda kalimat.
# ==========================================
kuota_ssh_lock_message() { # $1=user $2=limit_gb -> pesan HTML
    local user="$1" limit_gb="$2" domain waktu terpakai
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    waktu=$(date '+%d %b %Y %H:%M WIB')
    terpakai=$(usage_gb_label "$(usage_of "$user")")
    printf "🔒 <b>AKUN SSH DI-LOCK (KUOTA HABIS)</b>\n\n<b>User     :</b> <code>%s</code>\n<b>Limit    :</b> %s GB\n<b>Terpakai :</b> %s\n<b>Waktu    :</b> %s\n<b>Domain   :</b> <code>%s</code>" \
        "$user" "$limit_gb" "$terpakai" "$waktu" "$domain"
}

kuota_send_message() { # $1=pesan ; kirim ke Telegram bila token & chat tersedia
    local pesan="$1" token chat
    token="${BOT_TOKEN:-}"; chat="${CHAT_ID:-}"
    if [[ -z "$token" || -z "$chat" ]] && [[ -f /etc/wibutunnel/bot.conf ]]; then
        token=$(sed -n 's/^BOT_TOKEN="\?\([^"]*\)"\?.*/\1/p' /etc/wibutunnel/bot.conf 2>/dev/null | head -1)
        chat=$(sed -n 's/^CHAT_ID="\?\([^"]*\)"\?.*/\1/p' /etc/wibutunnel/bot.conf 2>/dev/null | head -1)
    fi
    [[ -z "$token" || -z "$chat" ]] && return 1
    curl -4 -s --max-time 10 -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -F "chat_id=${chat}" -F "disable_web_page_preview=true" -F "parse_mode=html" \
        -F "text=${pesan}" >/dev/null 2>&1
}

kuota_scan_ssh() {
    local db_bw="${KUOTA_DB_BW:-/etc/wibutunnel/limit_bw.db}"
    local db_usage="${KUOTA_DB_USAGE:-${USAGE_DB:-/etc/wibutunnel/user_usage.db}}"
    local db_lock="${KUOTA_DB_LOCK:-/etc/wibutunnel/locked_users.db}"
    local lock="${KUOTA_LOCK:-/etc/wibutunnel/tmp/kuota_scan.lock}"

    [[ -f "$db_bw" ]] || return 0
    mkdir -p "$(dirname "$lock")" 2>/dev/null || true

    ( flock -n 198 || exit 0
      local line user limit_gb total
      local -A locked=()
      if [[ -f "$db_lock" ]]; then
          while IFS=: read -r user _; do
              [[ -n "$user" ]] && locked["$user"]=1
          done < "$db_lock"
      fi
      while IFS= read -r line; do
          [[ -n "$line" ]] || continue
          # DB bisa datang dari sistem lain (CRLF) atau disunting tangan (spasi)
          line="${line//$'\r'/}"; line="${line%"${line##*[![:space:]]}"}"
          user="${line%%:*}"; user="${user//[[:space:]]/}"
          limit_gb="${line#*:}"; limit_gb="${limit_gb%%:*}"; limit_gb="${limit_gb//[[:space:]]/}"
          [[ -n "$user" ]] || continue
          [[ "$limit_gb" =~ ^[0-9]+$ ]] || continue
          (( 10#$limit_gb > 0 )) || continue
          [[ -n "${locked[$user]:-}" ]] && continue
          ssh_user_exists "$user" || continue
          # Akun sistem (uid < 1000) TIDAK boleh dikunci: lock_ssh_user menjalankan
          # `pkill -u`, dan satu baris `root:1` di DB akan mematikan seluruh panel.
          local _uid
          _uid=$(id -u "$user" 2>/dev/null)
          [[ "$_uid" =~ ^[0-9]+$ ]] || continue
          (( _uid >= 1000 )) || continue
          total=$(usage_of "$user")
          [[ "$total" =~ ^[0-9]+$ ]] || total=0
          if (( 10#$total >= 10#$limit_gb * 1073741824 )); then
              lock_ssh_user "$user" "QUOTA_EXCEEDED"
              locked["$user"]=1
              # fd 198 (flock) DITUTUP di subshell: kalau tidak, lock tetap dipegang
              # selama curl (sampai 10 detik) dan pemindaian berikutnya dilewati.
              ( exec 198>&-; kuota_send_message "$(kuota_ssh_lock_message "$user" "$limit_gb")" ) &
          fi
      done < "$db_bw"
    ) 198>"$lock"
}

# Port badvpn-udpgw yang sedang aktif (dipakai menu/pesan akun).
udpgw_active_ports() {
    local p out=""
    for p in ${UDPGW_PORTS:-7100 7200 7300 7400 7500 7600}; do
        if systemctl is-active --quiet "badvpn-udpgw@${p}.service" 2>/dev/null; then out="$out $p"; fi
    done
    [[ -n "$out" ]] && printf '%s' "${out# }"
    return 0
}

