#!/bin/bash
# ==========================================
# WIBU TUNNELING - menu.sh (v4.0 KURUMI)
# ==========================================

source /usr/local/bin/common.sh
check_license_silent

IP_SERVER="${MYIP:-$(curl -sS ipv4.icanhazip.com)}"
OS_SYSTEM=$(grep PRETTY_NAME /etc/os-release | awk -F '"' '{print $2}')

# Pindah ke tmp terisolasi
curl -s "http://ip-api.com/line/?fields=city,isp" > /etc/wibutunnel/tmp/ipapi.txt
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

st_hap=$(systemctl is-active --quiet haproxy && echo "ON" || echo "OFF")
st_xry=$(systemctl is-active --quiet xray && echo "ON" || echo "OFF")

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
echo -e " ${CYAN}Services   :${NC} HAProxy [${st_hap}] ${WHITE}•${NC} Xray [${st_xry}]"
echo -e "${LINE}"
echo -e " ${GREEN}[1] Menu VLESS${NC}"
echo -e " ${CYAN}[2] Menu VMESS${NC}"
echo -e " ${YELLOW}[3] Menu TROJAN${NC}"
echo -e "${LINE}"
echo -e " ${BLUE}[4] Setting Server${NC}"
echo -e " ${CYAN}[5] Backup & Restore${NC}"
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
        1) exec m-vless ;;
        2) exec m-vmess ;;
        3) exec m-trojan ;;
        4) exec m-setting ;;
        5) exec m-backup ;;
        0) clear; exit ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec menu ;;
    esac
done
