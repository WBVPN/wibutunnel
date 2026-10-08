#!/bin/bash
# ==========================================
# WIBU TUNNELING - menu-lock.sh (v4.0 KURUMI)
# Support: menu-lock VLESS|VMESS|TROJAN (per-protocol mode)
#          menu-lock (global mode, auto-detect)
# ==========================================

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi
check_license

source /etc/wibutunnel/bot.conf 2>/dev/null
CONFIG_FILE="/usr/local/etc/xray/config.json"
DB_IP="/etc/wibutunnel/limit_ip.db"
DB_LOCK="/etc/wibutunnel/locked_users.db"

# Detect protocol mode
if [[ -n "$1" ]] && [[ "$1" =~ ^(VLESS|VMESS|TROJAN)$ ]]; then
    FILTER_PROTO="$1"
    proto_lower="${FILTER_PROTO,,}"
    proto_color="${GREEN}"
    [[ "$FILTER_PROTO" == "VMESS" ]] && proto_color="${CYAN}"
    [[ "$FILTER_PROTO" == "TROJAN" ]] && proto_color="${YELLOW}"
else
    FILTER_PROTO=""
fi

user_json_exists() {
    jq -e --arg u "$1" '[.inbounds[].settings.clients[]?.email] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1
}

get_user_proto() {
    local u=$1
    if grep -q "^${u}:" /etc/xray/vless_exp.conf 2>/dev/null; then echo "VLESS"
    elif grep -q "^${u}:" /etc/xray/vmess_exp.conf 2>/dev/null; then echo "VMESS"
    elif grep -q "^${u}:" /etc/xray/trojan_exp.conf 2>/dev/null; then echo "TROJAN"
    else echo "UNKNOWN"; fi
}

clear
if [[ -n "$FILTER_PROTO" ]]; then
    echo -e "${LINE}"
    echo -e "       ${proto_color}MANUAL LOCK USER ${FILTER_PROTO}${NC}"
else
    echo -e "${LINE}"
    echo -e "            ${RED}MANUAL LOCK USER AKUN${NC}"
fi
echo -e "${LINE}"
echo -e " ${CYAN}Lock manual akan memindahkan user ke Recovery.${NC}"
echo -e " ${YELLOW}User tidak akan bisa login sampai di-reactivate.${NC}"
echo -e "${LINE}"

if [[ -n "$2" ]]; then
    user="$2"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
else
    read -p " Masukkan Nama User yang akan di-lock : " user
    [[ -z "$user" ]] && { echo -e "${RED}Batal.${NC}"; sleep 1; [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu; }
fi

if [[ "$user" == *"trial"* ]]; then
    if [[ -z "$2" ]]; then
        echo -e "\n ${YELLOW}User trial akan dihapus permanen, bukan di-lock.${NC}"
        read -p " Lanjutkan? (y/n): " lanjut
        if [[ "$lanjut" != "y" && "$lanjut" != "Y" ]]; then
            [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
        fi
    fi
fi

# Per-protocol validation
if [[ -n "$FILTER_PROTO" ]]; then
    if ! grep -q "^${user}:" "/etc/xray/${proto_lower}_exp.conf" 2>/dev/null; then
        echo -e "\n ${RED}User '$user' tidak ditemukan di protokol ${FILTER_PROTO}!${NC}"
        read -p " Tekan Enter..."
        exec "m-${proto_lower}"
    fi
else
    if ! user_json_exists "$user"; then
        echo -e "\n ${RED}User '$user' tidak ditemukan di system!${NC}"
        read -p " Tekan Enter..."
        exec menu-lock
    fi
fi

if grep -q "^${user}:" "$DB_LOCK" 2>/dev/null; then
    echo -e "\n ${YELLOW}User '$user' sudah dalam status TERKUNCI!${NC}"
    echo -e " ${CYAN}Gunakan menu Recovery untuk mengaktifkan kembali.${NC}"
    read -p " Tekan Enter..."
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

if [[ -n "$FILTER_PROTO" ]]; then
    proto="$FILTER_PROTO"
else
    proto=$(get_user_proto "$user")
fi

limit_ip=$(grep "^${user}:" "$DB_IP" 2>/dev/null | cut -d: -f2)
[[ -z "$limit_ip" || "$limit_ip" == "0" ]] && limit_str="Bebas" || limit_str="${limit_ip} IP"

/usr/local/bin/lock-user "$user" "0" "MANUAL" "$proto" "$limit_str" "Manual Lock"

echo -e "\n ${GREEN}User '$user' (${proto}) berhasil dikunci!${NC}"
echo -e " ${CYAN}Status: Dipindahkan ke Recovery Center${NC}"
read -p " Tekan Enter untuk kembali..."

if [[ -n "$FILTER_PROTO" ]]; then
    exec "m-${proto_lower}"
else
    exec menu
fi
