#!/bin/bash
# ==========================================
# WIBU TUNNELING - cek-trafik.sh (v1.1 Kurumi)
# Spesifik per Protokol & Fast Query
# ==========================================

source /usr/local/bin/common.sh
check_license

RED='\e[1;31m'
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
WHITE='\e[1;37m'
BLUE='\e[34m'
NC='\e[0m'
LINE="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DB_IP="/etc/wibutunnel/limit_ip.db"
DB_BW="/etc/wibutunnel/limit_bw.db"
DB_LOCK="/etc/wibutunnel/locked_users.db"
DB_USAGE="/etc/wibutunnel/user_usage.db"

# Mata Elang: Menangkap jenis protokol yang dilempar dari menu
PROTOCOL_FILTER=${1^^}

age_human() { # $1=detik
    local a="${1:-0}"
    if   (( a < 90 ));   then printf '%d detik' "$a"
    elif (( a < 5400 )); then printf '%d menit' $(( a / 60 ))
    else printf '%d jam' $(( a / 3600 )); fi
}

function convert_size() {
    local -i bytes=$1
    if [[ -z "$bytes" || "$bytes" == "0" ]]; then echo "0 B"; return; fi
    if [[ $bytes -lt 1024 ]]; then echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then echo "$(( (bytes + 1023) / 1024 )) KB"
    elif [[ $bytes -lt 1073741824 ]]; then echo "$(( (bytes + 1048575) / 1048576 )) MB"
    else echo "$(( (bytes + 1073741823) / 1073741824 )) GB"
    fi
}

clear
echo -e "${LINE}"
if [[ -n "$PROTOCOL_FILTER" ]]; then
    echo -e "       ${WHITE}📊 TRAFFIC & IP MONITOR (${PROTOCOL_FILTER}) 📊${NC}"
else
    echo -e "       ${WHITE}📊 REAL-TIME TRAFFIC & IP MONITOR 📊${NC}"
fi
echo -e "${LINE}"

/usr/local/sbin/algojo-kuota >/dev/null 2>&1

declare -A USER_PROTOS
for conf in /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf; do
    [[ ! -f "$conf" ]] && continue
    if [[ "$conf" == *"vless"* ]]; then proto="VLESS"
    elif [[ "$conf" == *"vmess"* ]]; then proto="VMESS"
    elif [[ "$conf" == *"trojan"* ]]; then proto="TROJAN"
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        u="${line%%:*}"
        [[ -n "$u" && "$u" != *"dummy"* ]] && USER_PROTOS["$u"]="$proto"
    done < "$conf"
done

# [MATA ELANG v4] Sumber tunggal: xray_presence() dari common.sh.
# Status online = ada SOCKET terbuka ke :80/:443 dari IP user itu, ATAU ada
# trafik nyata dalam ONLINE_WINDOW detik. Pengguna yang sudah disconnect tetap
# terlihat sebentar sebagai "terakhir terlihat N lalu" (PRESENCE_TTL), bukan
# hilang mendadak -- supaya beda antara "mati" dan "tidak ada data" jelas.
declare -A USER_IPS USER_STATE USER_AGE USER_CDN
while IFS='|' read -r _u _st _age _ips; do
    [[ -n "${_u:-}" ]] || continue
    USER_STATE["$_u"]="$_st"
    USER_AGE["$_u"]="${_age:-0}"
    _ips="${_ips//,/ }"
    USER_IPS["$_u"]="$_ips"
    _all_cdn=1
    for _ip in $_ips; do
        ip_is_cdn "$_ip" || { _all_cdn=0; break; }
    done
    [[ "$_all_cdn" == "1" ]] && USER_CDN["$_u"]=1
done < <(xray_presence 2>/dev/null)

declare -A ALL_USERS
while read -r line; do
    u=$(echo "$line" | cut -d: -f1)
    [[ -n "$u" ]] && ALL_USERS["$u"]=1
done < "$DB_BW"

for u in "${!USER_IPS[@]}"; do ALL_USERS["$u"]=1; done
for u in "${!USER_CDN[@]}"; do ALL_USERS["$u"]=1; done

online_count=0

if [ ${#ALL_USERS[@]} -eq 0 ]; then
    echo -e " ${YELLOW}Belum ada aktivitas pemakaian tercatat.${NC}"
    echo -e "${LINE}"
else
    mapfile -t sorted_users < <(printf "%s\n" "${!ALL_USERS[@]}" | sort)
    
    for user in "${sorted_users[@]}"; do
        proto_user=${USER_PROTOS[$user]}
        
        # [MATA ELANG] Lewati jika protokol tidak sesuai dengan filter menu
        if [[ -n "$PROTOCOL_FILTER" && "$proto_user" != "$PROTOCOL_FILTER" ]]; then
            continue
        fi

        [[ -z "$proto_user" ]] && proto_user="${YELLOW}UNKNOWN${NC}"
        
        limit_ip=$(grep "^${user}:" "$DB_IP" 2>/dev/null | cut -d: -f2)
        limit_bw=$(grep "^${user}:" "$DB_BW" 2>/dev/null | cut -d: -f2)
        [[ -z "$limit_ip" || "$limit_ip" == "0" ]] && str_limit_ip="Bebas" || str_limit_ip="${limit_ip} IP"
        [[ -z "$limit_bw" || "$limit_bw" == "0" ]] && str_limit_bw="Unli" || str_limit_bw="${limit_bw} GB"
        
        ip_list=${USER_IPS[$user]}
        # Hanya IP milik user yang sedang ONLINE yang dihitung. User offline tetap
        # ditampilkan (dengan "terakhir terlihat") tapi IP-nya tidak dihitung, supaya
        # tidak muncul "MELANGGAR LIMIT IP" untuk koneksi yang sudah lama tertutup.
        [[ "${USER_STATE[$user]:-offline}" == "online" ]] || ip_list=""
        active_ip_count=$(echo "$ip_list" | wc -w)
        [[ -z "$ip_list" ]] && active_ip_count=0
        
        is_locked=$(grep "^${user}:" "$DB_LOCK" 2>/dev/null)
        
        if [[ -n "$is_locked" ]]; then
            status="${RED}TERKUNCI / LOCKED ⛔${NC}"
        elif [[ "$limit_ip" != "0" && -n "$limit_ip" && $active_ip_count -gt $limit_ip ]]; then
            status="${RED}MELANGGAR LIMIT IP ⚠️${NC}"
        elif [[ "${USER_STATE[$user]:-offline}" == "online" && -z "${USER_IPS[$user]:-}" ]]; then
            status="${YELLOW}Online via CDN (IP asli tak terlihat) 🌐${NC}"
        elif [[ "${USER_STATE[$user]:-offline}" == "online" ]]; then
            status="${GREEN}Aktif / Online ✅${NC}"
        elif [[ $active_ip_count -gt 0 || "${USER_STATE[$user]:-offline}" == "offline" ]]; then
            status="${YELLOW}Terakhir terlihat $(age_human "${USER_AGE[$user]:-0}") lalu ⏱${NC}"
        else
            continue
        fi

        ((online_count++))

        raw_bytes=$(grep "^${user}:" "$DB_USAGE" | cut -d: -f2)
        [[ -z "$raw_bytes" ]] && raw_bytes=0
        usage_quota=$(convert_size "$raw_bytes")

        echo -e " ${WHITE}User        :${NC} ${GREEN}${user}${NC}"
        echo -e " ${WHITE}Protokol    :${NC} ${CYAN}${proto_user}${NC}"
        echo -e " ${WHITE}Status      :${NC} ${status}"
        echo -e " ${WHITE}Pemakaian   :${NC} ${YELLOW}${usage_quota}${NC} (Limit: ${str_limit_bw})"
        echo -e " ${WHITE}IP Aktif    :${NC} ${active_ip_count} IP (Limit: ${str_limit_ip})"
        
        if [[ "$active_ip_count" -gt 0 ]]; then
            echo -e " ${WHITE}Alamat IP   :${NC}"
            for ip in $ip_list; do echo -e "   ${CYAN}• $ip${NC}"; done
        elif [[ "${USER_STATE[$user]:-offline}" == "online" ]]; then
            echo -e " ${WHITE}Alamat IP   :${NC} ${YELLOW}(tidak terlihat - trafik lewat Cloudflare, headernya tidak terbaca)${NC}"
        fi
        if [[ "${USER_STATE[$user]:-offline}" == "offline" && $active_ip_count -gt 0 ]]; then
            echo -e " ${WHITE}Terakhir    :${NC} $(age_human "${USER_AGE[$user]:-0}") lalu (socket sudah tertutup)"
        fi
        echo -e "${LINE}"
    done

    if [ "$online_count" -eq 0 ]; then
        if [[ -n "$PROTOCOL_FILTER" ]]; then
            echo -e " ${YELLOW}Saat ini tidak ada user ${PROTOCOL_FILTER} yang sedang online. 💤${NC}"
        else
            echo -e " ${YELLOW}Saat ini tidak ada user yang sedang online. Server sepi! 💤${NC}"
        fi
        echo -e "${LINE}"
    fi
fi

rm -f /etc/wibutunnel/tmp/recent_log.txt
echo -e " ${WHITE}Tekan Enter untuk kembali...${NC}"
read -r

# Kembali ke asal menu dipanggil
if [[ "$PROTOCOL_FILTER" == "VLESS" ]]; then exec m-vless
elif [[ "$PROTOCOL_FILTER" == "VMESS" ]]; then exec m-vmess
elif [[ "$PROTOCOL_FILTER" == "TROJAN" ]]; then exec m-trojan
else exec menu
fi
