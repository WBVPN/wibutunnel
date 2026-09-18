#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-ssh.sh (v4.0 KURUMI + SSH Tunnel)
# Menu manajemen akun SSH Tunnel (Dropbear 2019 + SNI + Websocket + UDP gw)
# ==========================================

source /usr/local/bin/common.sh
check_license

source /etc/wibutunnel/bot.conf 2>/dev/null
DOMAIN_FILE="/etc/xray/domain"
SSH_EXP_FILE="/etc/xray/ssh_exp.conf"
DB_IP="/etc/wibutunnel/limit_ip.db"
DB_BW="/etc/wibutunnel/limit_bw.db"
DB_LOCK="/etc/wibutunnel/locked_users.db"

THICKLINE="----------------------------------------"

mkdir -p /etc/xray
touch "$SSH_EXP_FILE"

ssh_ready() {
    [[ -x /usr/sbin/dropbear ]]
}

select_ssh_user() {
    local ACTION_TITLE=$1
    local DISPLAY_TYPE=$2
    mapfile -t user_array < <(ssh_list_users | grep -v "dummy")

    TOTAL_USERS=${#user_array[@]}
    if [ "$TOTAL_USERS" -eq 0 ]; then
        echo -e "${YELLOW}Belum ada akun SSH Tunnel.${NC}"
        read -p "Tekan Enter..." dummy
        SELECTED_USER=""
        return
    fi

    clear; echo -e "${LINE}"; echo -e "             ${WHITE}${ACTION_TITLE}${NC}"; echo -e "${LINE}"
    for i in "${!user_array[@]}"; do
        u="${user_array[$i]}"
        if [[ "$DISPLAY_TYPE" == "IP" ]]; then
            val=$(db_lookup "$u" "$DB_IP" | cut -d: -f2)
            [[ -z "$val" || "$val" == "0" ]] && val="Bebas" || val="${val} IP"
            color="${CYAN}"
        elif [[ "$DISPLAY_TYPE" == "BW" ]]; then
            val=$(db_lookup "$u" "$DB_BW" | cut -d: -f2)
            [[ -z "$val" || "$val" == "0" ]] && val="Unlimited" || val="${val} GB"
            color="${CYAN}"
        else
            val=$(db_lookup "$u" "$SSH_EXP_FILE" | cut -d: -f2- | tail -n 1)
            is_locked=$(db_has "$u" "$DB_LOCK" && echo " ${RED}LOCKED${NC}" || echo "")
            [[ -z "$val" ]] && val="Lifetime"
            color="${YELLOW}Exp: "
        fi
        online=$(ssh_session_count "$u")
        [[ "$online" -gt 0 ]] && online="${GREEN} ($online online)${NC}" || online=""
        printf " ${GREEN}%2d.${NC} %-15s ${color}%s${NC}%b%b\n" "$((i+1))" "$u" "$val" "$is_locked" "$online"
    done
    echo -e "${LINE}\n ${CYAN}Total: ${TOTAL_USERS} users${NC}\n${LINE}"
    read -p " Pilih [Nomor/Nama] / [0] Batal: " sel

    if [[ -z "$sel" ]] || [[ "$sel" == "0" ]]; then SELECTED_USER=""; return
    elif [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -le "$TOTAL_USERS" ] && [ "$sel" -ge 1 ]; then SELECTED_USER="${user_array[$((sel-1))]}"; return
    elif ssh_user_exists "$sel" && [[ "$sel" != *"dummy"* ]]; then
        sanitize_user "$sel" || { echo -e "\n ${RED}Pilihan tidak valid!${NC}"; sleep 1; SELECTED_USER=""; return; }
        SELECTED_USER="$sel"; return
    else echo -e "\n ${RED}Pilihan tidak valid!${NC}"; sleep 1; SELECTED_USER=""; fi
}

ssh_config_message() {
    local user="$1" pass="$2" exp="$3" lip="$4" lbw="$5"
    local domain; domain=$(cat "$DOMAIN_FILE" 2>/dev/null)
    [[ -z "$domain" ]] && domain="${MYIP:-$(curl -sS --max-time 3 ipv4.icanhazip.com 2>/dev/null)}"

    [[ "$lip" == "0" || -z "$lip" ]] && lip="Bebas" || lip="${lip} IP"
    [[ "$lbw" == "0" || -z "$lbw" ]] && lbw="Unlimited" || lbw="${lbw} GB"

    echo -e "${THICKLINE}"
    echo -e "         ${GREEN}ACCOUNT CREATED SUCCESSFULLY${NC}"
    echo -e "${THICKLINE}"
    echo -e " Host            : ${GREEN}${domain}${NC}"
    echo -e " Username        : ${GREEN}${user}${NC}"
    echo -e " Password        : ${GREEN}${pass}${NC}"
    echo -e "${THICKLINE}"
    echo -e " Expired         : ${YELLOW}${exp}${NC}"
    echo -e "${THICKLINE}"
    echo -e " TLS             : ${GREEN}443${NC}"
    echo -e " None TLS        : ${GREEN}80${NC}"
    echo -e " OpenSSH         : ${GREEN}22${NC}"
    echo -e " Dropbear        : ${GREEN}109,143${NC}"
    echo -e " WebSocket       : ${GREEN}80,443${NC}"
    echo -e " SNI / Bug Host  : ${GREEN}443${NC}"
    echo -e " UDPGW           : ${GREEN}7100-7600${NC}"
    echo -e "${THICKLINE}"
}

add_ssh_menu() {
    clear; echo -e "${LINE}"; echo -e "               ${WHITE}BUAT AKUN SSH${NC}"; echo -e "${LINE}"
    if ! ssh_ready; then echo -e "${RED}ERROR: Dropbear belum terinstal! Pilih [99] Install dulu.${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Masukkan Nama User : " user
    [[ -z "$user" ]] && return
    ssh_valid_user "$user" || { echo -e "${RED}Error: Username tidak valid! 3-32 char (a-z 0-9 _ -)${NC}"; read -p "Enter..." dummy; return; }
    if ssh_user_exists "$user"; then echo -e "${RED}Error: User sudah ada!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Masa Aktif (Hari)  : " masaaktif
    if [[ "$masaaktif" =~ ^[0-9]+$ ]] && [ "$masaaktif" -gt 0 ]; then
        exp_date=$(date -d "+${masaaktif} days" +"%Y-%m-%d %H:%M:%S")
    else echo -e "${RED}Error: Angka tidak valid!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Password (min 6)   : " pass
    [[ -n "$pass" && ${#pass} -ge 6 ]] || { echo -e "${RED}Error: Password minimal 6 karakter!${NC}"; read -p "Enter..." dummy; return; }

    read -p "Limit IP (0 = Bebas): " limit_ip
    read -p "Limit Kuota GB (0 = Unli): " limit_kuota
    [[ -z "$limit_ip" ]] && limit_ip=0
    [[ -z "$limit_kuota" ]] && limit_kuota=0

    if out=$(add_ssh_user "$user" "$pass" "$masaaktif" "$limit_ip" "$limit_kuota"); then
        echo -e "${GREEN}Berhasil! Akun SSH dibuat.${NC}"
    else
        echo -e "${RED}Gagal: ${out}${NC}"; read -p "Enter..." dummy; return
    fi

    ssh_config_message "$user" "$pass" "$exp_date" "$limit_ip" "$limit_kuota"

    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        (
        PESAN="<b>SSH ACCOUNT CREATED</b>\n━━━━━━━━━━━━━━━━━━━━\n<b>User</b> : <code>${user}</code>\n<b>Pass</b> : <code>${pass}</code>\n<b>Exp</b> : <code>${exp_date}</code>\n<b>Limit IP</b> : <code>${limit_ip}</code>\n<b>Kuota</b> : <code>${limit_kuota} GB</code>"
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -F "chat_id=${CHAT_ID}" -F "parse_mode=html" -F "text=${PESAN}" >/dev/null 2>&1
        ) &
    fi

    echo ""; read -p "Tekan Enter..." dummy
}

trial_ssh_menu() {
    clear; echo -e "${LINE}"; echo -e "            ${WHITE}BUAT AKUN SSH TRIAL${NC}"; echo -e "${LINE}"
    if ! ssh_ready; then echo -e "${RED}ERROR: Dropbear belum terinstal!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Masukkan Waktu (Contoh: 20m, 1h, 1d) : " waktu
    if [[ "$waktu" =~ ^([0-9]+)([mhd])$ ]]; then
        val="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
        case "$unit" in
            m) exp_date=$(date -d "+${val} minutes" +"%Y-%m-%d %H:%M:%S") ;;
            h) exp_date=$(date -d "+${val} hours" +"%Y-%m-%d %H:%M:%S") ;;
            d) exp_date=$(date -d "+${val} days" +"%Y-%m-%d %H:%M:%S") ;;
        esac
    else echo -e "${RED}Error: Format salah!${NC}"; read -p "Enter..." dummy; return; fi

    local trial_user="trial-$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
    local trial_pass="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)"

    local hari=1
    [[ "$unit" == "d" ]] && hari="$val"
    if out=$(add_ssh_user "$trial_user" "$trial_pass" "$hari" 0 1); then
        local exp_sec; exp_sec=$(date -d "$exp_date" +%s)
        chage -E "$(date -d "@$exp_sec" +%Y-%m-%d)" -M $(( (exp_sec - $(date +%s)) / 86400 + 1 )) -I 0 "$trial_user" >/dev/null 2>&1
        safe_sed_delete "$trial_user" "$SSH_EXP_FILE"; echo "${trial_user}:${exp_date}" >> "$SSH_EXP_FILE"
        echo -e "${GREEN}Berhasil! Akun trial dibuat.${NC}"
    else
        echo -e "${RED}Gagal: ${out}${NC}"; read -p "Enter..." dummy; return
    fi

    ssh_config_message "$trial_user" "$trial_pass" "$exp_date" 0 1
    echo ""; read -p "Tekan Enter..." dummy
}

delete_ssh_menu() {
    select_ssh_user "HAPUS AKUN SSH" ""
    [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }

    echo -e "\n ${RED}Yakin hapus ${SELECTED_USER}? [y/n]${NC}"
    read -r konfirmasi
    if [[ "$konfirmasi" =~ ^[yY]$ ]]; then
        if del_ssh_user "$SELECTED_USER"; then
            echo -e "\n ${GREEN}BERHASIL! Akun ${SELECTED_USER} dihapus permanen.${NC}"
        else
            echo -e "\n ${RED}Gagal menghapus akun.${NC}"
        fi
    fi
    read -p "Tekan Enter..." dummy
}

cek_ssh_menu() {
    clear; echo -e "${LINE}"; echo -e "             ${WHITE}LIST AKUN SSH${NC}"; echo -e "${LINE}"
    mapfile -t user_array < <(ssh_list_users | grep -v "dummy")

    if [ "${#user_array[@]}" -eq 0 ]; then
        echo -e " ${YELLOW}Belum ada akun SSH.${NC}\n${LINE}"
        read -p "Tekan Enter..." dummy; exec m-ssh
    fi

    printf " ${WHITE}%-15s %-20s %-8s %-6s %-8s %s${NC}\n" USER EXPIRED IP KUOTA STATUS LOGIN
    for u in "${user_array[@]}"; do
        exp=$(db_lookup "$u" "$SSH_EXP_FILE" | cut -d: -f2- | awk '{print $1}')
        [[ -z "$exp" ]] && exp="Lifetime"
        lip=$(db_lookup "$u" "$DB_IP" | cut -d: -f2); [[ -z "$lip" || "$lip" == "0" ]] && lip="Bebas"
        lbw=$(db_lookup "$u" "$DB_BW" | cut -d: -f2); [[ -z "$lbw" || "$lbw" == "0" ]] && lbw="Unli" || lbw="${lbw}G"
        if db_has "$u" "$DB_LOCK"; then status="${RED}LOCK${NC}"
        elif [[ "$exp" != "Lifetime" && "$exp" < "$(date +%F)" ]]; then status="${YELLOW}EXPD${NC}"
        else status="${GREEN}AKTIF${NC}"; fi
        login=$(ssh_session_count "$u")
        printf " %-15s %-20s %-8s %-6s %-8b %s\n" "$u" "$exp" "$lip" "$lbw" "$status" "$login"
    done
    echo -e "${LINE}"
    read -p "Tekan Enter..." dummy
}

renew_ssh_menu() {
    select_ssh_user "PERPANJANG AKUN SSH" ""
    [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }
    local user="$SELECTED_USER"
    clear; echo -e "${LINE}"; echo -e "             ${WHITE}PERPANJANG AKUN SSH${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Jumlah Hari Tambahan : " tambahan
    if [[ ! "$tambahan" =~ ^[0-9]+$ ]] || [ "$tambahan" -le 0 ]; then echo -e "${RED}Error: Angka tidak valid!${NC}"; read -p "Enter..." dummy; return; fi

    if new_exp=$(renew_ssh_user "$user" "$tambahan"); then
        echo -e "\n ${GREEN}BERHASIL!${NC}"
        echo -e " User : ${CYAN}${user}${NC}"
        echo -e " Expired Baru : ${YELLOW}${new_exp}${NC}"
    else
        echo -e "\n ${RED}Gagal memperpanjang.${NC}"
    fi
    read -p "Tekan Enter..." dummy
}

detail_ssh_menu() {
    select_ssh_user "DETAIL AKUN SSH" ""
    [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }
    local user="$SELECTED_USER"
    local pass; pass=$(ssh_get_pass "$user")
    [[ -z "$pass" ]] && pass="<tidak tersedia>"
    local exp; exp=$(db_lookup "$user" "$SSH_EXP_FILE" | cut -d: -f2-)
    [[ -z "$exp" ]] && exp="Lifetime"
    local lip; lip=$(db_lookup "$user" "$DB_IP" | cut -d: -f2)
    local lbw; lbw=$(db_lookup "$user" "$DB_BW" | cut -d: -f2)
    ssh_config_message "$user" "$pass" "$exp" "$lip" "$lbw"
    read -p "Tekan Enter..." dummy
}

change_ip_ssh_menu() {
    select_ssh_user "GANTI LIMIT IP SSH" "IP"
    [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }
    local user="$SELECTED_USER"
    clear; echo -e "${LINE}"; echo -e "             ${WHITE}GANTI LIMIT IP SSH${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Masukkan Limit IP Baru (0 = Bebas): " new_limit
    [[ "$new_limit" =~ ^[0-9]+$ ]] || new_limit=0
    safe_sed_delete "$user" "$DB_IP"; echo "${user}:${new_limit}" >> "$DB_IP"
    echo -e "\n ${GREEN}Limit IP ${user} => ${new_limit}${NC}"
    read -p "Tekan Enter..." dummy
}

change_bw_ssh_menu() {
    select_ssh_user "GANTI LIMIT KUOTA SSH" "BW"
    [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }
    local user="$SELECTED_USER"
    clear; echo -e "${LINE}"; echo -e "            ${WHITE}GANTI LIMIT KUOTA SSH${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Masukkan Limit Kuota Baru GB (0 = Unli): " new_limit
    [[ "$new_limit" =~ ^[0-9]+$ ]] || new_limit=0
    safe_sed_delete "$user" "$DB_BW"; echo "${user}:${new_limit}" >> "$DB_BW"

    # [FIX] kuota dinaikkan (bukan 0) -> buka kunci QUOTA permanen bila ada
    if [[ "$new_limit" != "0" ]]; then
        lock_entry=$(db_lookup "$user" "$DB_LOCK")
        if [[ -n "$lock_entry" && "$(echo "$lock_entry" | cut -d: -f4)" == "QUOTA" ]]; then
            unlock_ssh_user "$user" >/dev/null 2>&1
        fi
    fi
    echo -e "\n ${GREEN}Limit Kuota ${user} => ${new_limit} GB${NC}"
    read -p "Tekan Enter..." dummy
}

lock_unlock_ssh_menu() {
    clear; echo -e "${LINE}"; echo -e "          ${WHITE}LOCK / UNLOCK AKUN SSH${NC}"; echo -e "${LINE}"
    echo -e " ${GREEN}[1]${NC} Lock Akun"
    echo -e " ${RED}[2]${NC} Unlock Akun"
    echo -e " ${WHITE}[0]${NC} Kembali"
    read -p " Pilih: " sub
    case "$sub" in
        1)
            select_ssh_user "LOCK AKUN SSH" ""
            [[ -z "$SELECTED_USER" ]] && { exec m-ssh; }
            lock_ssh_user "$SELECTED_USER" "LOCK" && echo -e "\n ${GREEN}${SELECTED_USER} terkunci.${NC}"
            ;;
        2)
            mapfile -t locked_users < <(awk -F: '{print $1}' "$DB_LOCK" 2>/dev/null | sort -u)
            if [ "${#locked_users[@]}" -eq 0 ] || [[ -z "${locked_users[0]}" ]]; then
                echo -e "\n ${YELLOW}Tidak ada akun terkunci.${NC}"
            else
                echo -e "\n ${CYAN}Akun terkunci:${NC}"
                for i in "${!locked_users[@]}"; do
                    printf " ${GREEN}%2d.${NC} %s\n" "$((i+1))" "${locked_users[$i]}"
                done
                read -p " Pilih [nomor/nama] / [0] batal: " sel
                local target=""
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#locked_users[@]}" ]; then
                    target="${locked_users[$((sel-1))]}"
                elif [[ -n "$sel" && "$sel" != "0" ]]; then
                    target="$sel"
                fi
                if [[ -n "$target" ]] && unlock_ssh_user "$target"; then
                    echo -e "\n ${GREEN}${target} di-unlock.${NC}"
                fi
            fi
            ;;
        *) exec m-ssh ;;
    esac
    read -p "Tekan Enter..." dummy
}

install_ssh_menu() {
    clear; echo -e "${LINE}"; echo -e "          ${WHITE}INSTALL SSH STACK${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}Memasang: dropbear 2019.78 + ws-stunnel + badvpn-udpgw${NC}"
    echo -e " ${CYAN}Mode: SNI 443 (HAProxy) + websocket 80 + UDP gateway${NC}\n"
    if [[ -x /usr/local/bin/ssh-tunnel-install ]]; then
        /usr/local/bin/ssh-tunnel-install
    else
        echo -e "${RED}Installer ssh-tunnel-install tidak ditemukan.${NC}"
        echo -e "${YELLOW}Jalankan ulang setup.sh atau download dari repo.${NC}"
    fi
    read -p "Tekan Enter..." dummy
}

# ==========================================
# MENU UTAMA
# ==========================================
clear
echo -e "${LINE}"
echo -e "              ${WHITE}MENU KELOLA SSH${NC}"
echo -e "${LINE}"
echo -e " ${GREEN}[1]  Create Akun${NC}"
echo -e " ${CYAN}[2]  Create Trial${NC}"
echo -e " ${RED}[3]  Delete Akun${NC}"
echo -e " ${YELLOW}[4]  List Akun / Cek Akun${NC}"
echo -e " ${BLUE}[5]  Renew Akun (Masa Aktif)${NC}"
echo -e " ${CYAN}[6]  Detail & Config Akun${NC}"
echo -e " ${YELLOW}[7]  Ganti Limit IP User${NC}"
echo -e " ${CYAN}[8]  Ganti Limit Kuota GB${NC}"
echo -e " ${GREEN}[9]  Cek Login Online${NC}"
echo -e "${LINE}"
echo -e " ${RED}[10] Lock / Unlock Akun${NC}"
echo -e " ${CYAN}[99] Install / Repair SSH Stack${NC}"
echo -e " ${WHITE}[0]  Back to Menu Dashboard${NC}"
echo -e "${LINE}"
echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_menu

case $sub_menu in
    99) install_ssh_menu; exec m-ssh ;;
    1) add_ssh_menu; exec m-ssh ;;
    2) trial_ssh_menu; exec m-ssh ;;
    3) delete_ssh_menu; exec m-ssh ;;
    4) cek_ssh_menu; exec m-ssh ;;
    5) renew_ssh_menu; exec m-ssh ;;
    6) detail_ssh_menu; exec m-ssh ;;
    7) change_ip_ssh_menu; exec m-ssh ;;
    8) change_bw_ssh_menu; exec m-ssh ;;
    9) /usr/local/bin/cek-trafik SSH ;;
    10) lock_unlock_ssh_menu; exec m-ssh ;;
    0) exec menu ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec m-ssh ;;
esac
