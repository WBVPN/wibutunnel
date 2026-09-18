#!/bin/bash
# ==========================================
# WIBU TUNNELING - menu.sh (v4.0 KURUMI)
# ==========================================

source /usr/local/bin/common.sh
check_license_silent

IP_SERVER="${MYIP:-$(curl -sS ipv4.icanhazip.com)}"
OS_SYSTEM=$(grep PRETTY_NAME /etc/os-release | awk -F '"' '{print $2}')

# Pindah ke tmp terisolasi
curl -sS --max-time 10 "http://ip-api.com/line/?fields=city,isp" > /etc/wibutunnel/tmp/ipapi.txt
CITY=$(sed -n '1p' /etc/wibutunnel/tmp/ipapi.txt)
ISP=$(sed -n '2p' /etc/wibutunnel/tmp/ipapi.txt)
[[ -z "$CITY" ]] && CITY="Unknown"
[[ -z "$ISP" ]] && ISP="Unknown"

if [ -f /etc/wibutunnel/version ]; then
    SCRIPT_VER=$(cat /etc/wibutunnel/version)
else
    SCRIPT_VER="4.0 Kurumi"
fi

UPTIME=$(uptime -p | sed 's/up //')
RAM_USED=$(free -m | awk '/Mem:/ { print $3 }')
RAM_TOTAL=$(free -m | awk '/Mem:/ { print $2 }')

# [FIX MUTLAK CPU] - Memaksa sistem membaca satu baris utama saja!
CPU_USAGE=$(grep -i '^cpu ' /proc/stat | awk '{print int(($2+$4)*100/($2+$4+$5))}')
[[ -z "$CPU_USAGE" ]] && CPU_USAGE=0

# Hitung jumlah service yang mati untuk status global server
SVC_OFF=0
for _u in haproxy xray dropbear ws-stunnel; do
    systemctl is-active --quiet "$_u" 2>/dev/null || SVC_OFF=$((SVC_OFF + 1))
done
case "$SVC_OFF" in
    0) SERVER_ST="${GREEN}online${NC}" ;;
    1) SERVER_ST="${YELLOW}bad${NC}" ;;
    *) SERVER_ST="${RED}failure${NC}" ;;
esac

# Render status service dengan warna (hijau=ON, merah=OFF) - format ringkas 1 baris
svc_status() {
    local nm="$1" unit="$2" st
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        st="${GREEN}ON${NC}"
    else
        st="${RED}OFF${NC}"
    fi
    printf "%s [%s]" "$nm" "$st"
}

clear
echo -e "${LINE}"
echo -e "               ${WHITE}WIBU TUNNELING${NC}"
echo -e "${LINE}"
echo -e " ${CYAN}ISP        :${NC} ${WHITE}${ISP}${NC}"
echo -e " ${CYAN}City       :${NC} ${WHITE}${CITY}${NC}"
echo -e " ${CYAN}IP Server  :${NC} ${WHITE}${IP_SERVER}${NC}"
echo -e " ${CYAN}Domain     :${NC} ${WHITE}$(cat /etc/xray/domain 2>/dev/null)${NC}"
echo -e " ${CYAN}OS System  :${NC} ${WHITE}${OS_SYSTEM}${NC}"
echo -e " ${CYAN}Uptime     :${NC} ${WHITE}${UPTIME}${NC}"
echo -e " ${CYAN}RAM Use    :${NC} ${WHITE}${RAM_USED} MB / ${RAM_TOTAL} MB${NC}"
echo -e " ${CYAN}CPU Use    :${NC} ${WHITE}${CPU_USAGE}%${NC}"
echo -e " ${CYAN}Service    :${NC} [ ${SERVER_ST} ]"
echo -e " $(svc_status HAProxy haproxy) ${WHITE}•${NC} $(svc_status Xray xray) ${WHITE}•${NC} $(svc_status Dropbear dropbear) ${WHITE}•${NC} $(svc_status WS ws-stunnel)"
echo -e "${LINE}"
echo -e " ${BLUE}[1] Menu SSH${NC}"
echo -e " ${GREEN}[2] Menu VLESS${NC}"
echo -e " ${CYAN}[3] Menu VMESS${NC}"
echo -e " ${YELLOW}[4] Menu TROJAN${NC}"
echo -e "${LINE}"
echo -e " ${BLUE}[5] Setting Server${NC}"
echo -e " ${CYAN}[6] Backup & Restore${NC}"
echo -e " ${RED}[0] Keluar / Exit Terminal${NC}"
echo -e "${LINE}"
echo -e " ${CYAN}Client Name : ${GREEN}${CLIENT_NAME:-Unknown}${NC}"
echo -e " ${CYAN}Version     : ${WHITE}${SCRIPT_VER}${NC}"
echo -e " ${CYAN}Expired On  : ${GREEN}${EXP_DATE}${NC}"
echo -e "${LINE}"

while true; do
    echo -ne "${WHITE}Pilih menu: ${NC}"
    read -r sub_menu
    case $sub_menu in
        1) exec m-ssh ;;
        2) exec m-vless ;;
        3) exec m-vmess ;;
        4) exec m-trojan ;;
        5) exec m-setting ;;
        6) exec m-backup ;;
        0) clear; exit ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec menu ;;
    esac
done
