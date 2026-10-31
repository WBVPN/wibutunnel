#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-setting.sh (v4.0 KURUMI)
# Security Patch: Anti-Symlink Update + Fix Format Waktu + Speedtest Repo
# ==========================================

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi
check_license

source /etc/wibutunnel/bot.conf 2>/dev/null
source /etc/wibutunnel/lock.conf 2>/dev/null || LOCK_DURATION=15

if [[ -z "$BOT_TOKEN" ]]; then
    STATUS_TOKEN="${RED}Belum disetting${NC}"
else
    TAMPIL_TOKEN="${BOT_TOKEN:0:4}..."
    STATUS_TOKEN="${GREEN}Aktif (${TAMPIL_TOKEN})${NC}"
fi

if [[ -z "$CHAT_ID" ]]; then
    STATUS_CHATID="${RED}Belum disetting${NC}"
else
    STATUS_CHATID="${GREEN}${CHAT_ID}${NC}"
fi

CEK_REBOOT=$(crontab -l 2>/dev/null | awk '!/^#/ && /\/sbin\/reboot/ {printf "%02d:%02d", $2, $1; exit}')
STATUS_REBOOT=$([[ -z "$CEK_REBOOT" ]] && echo "${RED}Belum disetting${NC}" || echo "${GREEN}Tersetting pada ${CEK_REBOOT} WIB${NC}")

CEK_BACKUP=$(crontab -l 2>/dev/null | awk '!/^#/ && /m-backup auto/ {printf "%02d:%02d", $2, $1; exit}')
STATUS_BACKUP=$([[ -z "$CEK_BACKUP" ]] && echo "${RED}Belum disetting${NC}" || echo "${GREEN}Tersetting pada ${CEK_BACKUP} WIB${NC}")

safe_update() {
    local repo_path="$1"
    local base_name=$(basename "$repo_path")
    local target_name="${base_name%.sh}"
    if [[ "$base_name" == "common.sh" ]]; then target_name="common.sh"; fi
    
    local raw_url="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/${repo_path}?$(date +%s)"
    local tmp_file="/etc/wibutunnel/tmp/${base_name}"
    
    wget -q -O "$tmp_file" "$raw_url" 2>/dev/null
    if [[ -s "$tmp_file" ]]; then
        local shebang=$(head -n 1 "$tmp_file")
        if [[ "$shebang" =~ ^#!.*(bash|sh) ]]; then
            if ! bash -n "$tmp_file" 2>/dev/null; then
                echo -e "${RED}× Gagal syntax check bash -n: ${base_name}${NC}"
                rm -f "$tmp_file"
                return 1
            fi
        elif [[ "$shebang" =~ ^#!.*python ]]; then
            if ! python3 -m py_compile "$tmp_file" 2>/dev/null; then
                echo -e "${RED}× Gagal syntax check python: ${base_name}${NC}"
                rm -f "$tmp_file"
                return 1
            fi
            rm -rf /etc/wibutunnel/tmp/__pycache__
        else
            if ! bash -n "$tmp_file" 2>/dev/null; then
                echo -e "${RED}× Gagal validasi script: ${base_name}${NC}"
                rm -f "$tmp_file"
                return 1
            fi
        fi

        if [[ "$repo_path" =~ ^sbin/ ]]; then
            cp -f "$tmp_file" "/usr/local/sbin/${target_name}"
            chmod +x "/usr/local/sbin/${target_name}"
            cp -f "$tmp_file" "/usr/local/bin/${target_name}"
            chmod +x "/usr/local/bin/${target_name}"
            rm -f "$tmp_file"
        else
            mv "$tmp_file" "/usr/local/bin/${target_name}"
            chmod +x "/usr/local/bin/${target_name}"
        fi
        echo -e "${GREEN}√ Berhasil memperbarui ${target_name}${NC}"
    else
        echo -e "${RED}× Gagal mengunduh ${base_name} (Sistem dilindungi dari file kosong)${NC}"
    fi
}

clear
echo -e "$LINE"
echo -e "            ${WHITE}MENU SETTING & MONITOR${NC}"
echo -e "$LINE"
echo -e "  ${CYAN}Bot Telegram : ${NC}${STATUS_TOKEN}"
echo -e "  ${CYAN}ID Telegram  : ${NC}${STATUS_CHATID}"
echo -e "  ${CYAN}Auto Reboot  : ${NC}${STATUS_REBOOT}"
echo -e "  ${CYAN}Auto Backup  : ${NC}${STATUS_BACKUP}"
echo -e "  ${CYAN}Lock Duration: ${NC}${GREEN}${LOCK_DURATION} menit${NC}"
echo -e "$LINE"
echo -e " ${RED}[1] Restart Semua Service${NC}"
echo -e " ${GREEN}[2] Bersihkan Cache & RAM${NC}"
echo -e " ${CYAN}[3] Speedtest VPS${NC}"
echo -e " ${YELLOW}[4] Cek Bandwidth VPS (vnStat)${NC}"
echo -e " ${BLUE}[5] Update Script (Safe Mode)${NC}"
echo -e " ${WHITE}[6] Setup Bot Telegram${NC}"
echo -e " ${CYAN}[7] Setup Auto Reboot VPS${NC}"
echo -e " ${YELLOW}[8] Ganti Domain & Renew SSL${NC}"
echo -e " ${GREEN}[9] Atur Durasi Lock Otomatis${NC}"
echo -e " ${WHITE}[10] Edit Banner SSH${NC}"
echo -e " ${RED}[0] Kembali ke Dashboard Utama${NC}"
echo -e "$LINE"

echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_setting

case $sub_setting in
    1)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}MERESTART SERVICES...${NC}"; echo -e "$LINE"
        systemctl restart xray haproxy cron
        echo -e "${GREEN}Semua service berhasil direstart!${NC}"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    2)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}MEMBERSIHKAN CACHE & RAM...${NC}"; echo -e "$LINE"
        sync; echo 1 > /proc/sys/vm/drop_caches
        sync; echo 2 > /proc/sys/vm/drop_caches
        sync; echo 3 > /proc/sys/vm/drop_caches
        > /etc/wibutunnel/tmp/bot_error.log 2>/dev/null || true
        echo -e "${GREEN}RAM & Log Bot berhasil dibersihkan!${NC}"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    3)
        clear; echo -e "$LINE"; echo -e "            ${WHITE}SPEEDTEST VPS${NC}"; echo -e "$LINE"
        # Ookla CLI diblokir (config.speedtest.net 403), tapi server Ookla tetap
        # terbuka. Ukur langsung pakai protokol server Ookla, multi-koneksi
        # paralel seperti CLI resmi (single stream under-report di link cepat).
        # ponytail: 6 stream tetap. Naikkan kalau link > 5 Gbps.
        STREAMS=6
        SRV_JSON=$(curl -fsSL --max-time 20 'https://www.speedtest.net/api/js/servers?engine=js&limit=10' 2>/dev/null)
        if [ -z "$SRV_JSON" ]; then
            echo -e "${RED}Gagal ambil daftar server Ookla (speedtest.net tidak terjangkau).${NC}"
            read -n 1 -s -r -p "Tekan tombol apa saja..."; exec m-setting
        fi

        # Pilih server dengan latency terendah, bukan asal server pertama.
        echo -e "${CYAN}[*] Cari server terdekat...${NC}"
        BASE=""; S_NAME=""; S_ID=""; S_MS=999999
        for _i in 0 1 2 3 4 5 6 7 8 9; do
            _h=$(echo "$SRV_JSON" | jq -r ".[$_i].host // empty" 2>/dev/null)
            [ -z "$_h" ] && continue
            _hn=${_h%%:*}; _pn=${_h##*:}
            _hs=$(echo "$SRV_JSON" | jq -r ".[$_i].https_functional // 0" 2>/dev/null)
            _sch=http; [ "$_hs" = "1" ] && _sch=https
            _t=$(curl -fsS -o /dev/null -w '%{time_total}' --max-time 6 "$_sch://$_hn:$_pn/speedtest/latency.txt" 2>/dev/null) || continue
            _ms=$(awk -v t="$_t" 'BEGIN{printf "%d", t*1000}')
            if [ "$_ms" -lt "$S_MS" ]; then
                S_MS=$_ms; BASE="$_sch://$_hn:$_pn/speedtest"
                S_NAME=$(echo "$SRV_JSON" | jq -r ".[$_i].sponsor // \"?\"" 2>/dev/null)
                S_ID=$(echo "$SRV_JSON" | jq -r ".[$_i].id // \"?\"" 2>/dev/null)
            fi
        done

        if [ -z "$BASE" ]; then
            echo -e "${RED}Tidak ada server Ookla yang bisa dihubungi dari VPS ini.${NC}"
            read -n 1 -s -r -p "Tekan tombol apa saja..."; exec m-setting
        fi

        echo -e "${CYAN}[*] Server : ${S_NAME} (Ookla id ${S_ID}) - ${S_MS} ms${NC}"
        curl -fsS -o /dev/null --max-time 10 "$BASE/random1000x1000.jpg" 2>/dev/null  # warmup

        echo -e "${CYAN}[*] Ping...${NC}"
        PING_MS=$(for _n in 1 2 3 4 5; do
            curl -fsS -o /dev/null -w '%{time_total}\n' --max-time 10 "$BASE/latency.txt" 2>/dev/null
        done | sort -n | head -1 | awk '{printf "%.0f", $1*1000}')

        echo -e "${CYAN}[*] Download (${STREAMS} koneksi)...${NC}"
        DL_BPS=$({ for _n in $(seq 1 $STREAMS); do
            curl -fsS -o /dev/null -w '%{speed_download}\n' --max-time 10 "$BASE/random3500x3500.jpg" 2>/dev/null &
        done; wait; } | awk '{s+=$1} END{printf "%.0f", s}')
        DL_MBPS=$(awk -v b="${DL_BPS:-0}" 'BEGIN{printf "%.2f", (b*8)/1000000}')

        echo -e "${CYAN}[*] Upload (${STREAMS} koneksi)...${NC}"
        UL_BPS=$({ for _n in $(seq 1 $STREAMS); do
            head -c 30000000 /dev/zero | curl -fsS -o /dev/null -w '%{speed_upload}\n' --max-time 10 -X POST --data-binary @- "$BASE/upload.php" 2>/dev/null &
        done; wait; } | awk '{s+=$1} END{printf "%.0f", s}')
        UL_MBPS=$(awk -v b="${UL_BPS:-0}" 'BEGIN{printf "%.2f", (b*8)/1000000}')

        echo -e "$LINE"
        echo -e " ${GREEN}Server   :${NC} ${S_NAME} (Ookla id ${S_ID})"
        echo -e " ${GREEN}PING     :${NC} ${PING_MS:-n/a} ms"
        echo -e " ${GREEN}DOWNLOAD :${NC} ${DL_MBPS} Mbps"
        echo -e " ${GREEN}UPLOAD   :${NC} ${UL_MBPS} Mbps"
        echo -e " ${YELLOW}Catatan  :${NC} ukur ke server Ookla (${STREAMS} koneksi paralel)"
        echo -e "$LINE"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    4)
        clear; echo -e "$LINE"; echo -e "          ${WHITE}MONITOR BANDWIDTH VPS${NC}"; echo -e "$LINE"
        if ! command -v vnstat &> /dev/null; then
            apt-get install -y vnstat >/dev/null 2>&1
            systemctl enable --now vnstat >/dev/null 2>&1
        fi
        MAIN_IFACE=$(ip -4 route show default | awk '{print $5}' | head -n1)
        
        # Raw Data (Realtime from kernel)
        RX_B=$(cat /sys/class/net/$MAIN_IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
        TX_B=$(cat /sys/class/net/$MAIN_IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
        
        # Format to human readable
        rx_mb=$(awk -v b="$RX_B" 'BEGIN { printf "%.2f MB", b / 1048576 }')
        rx_gb=$(awk -v b="$RX_B" 'BEGIN { printf "%.2f GB", b / 1073741824 }')
        tx_mb=$(awk -v b="$TX_B" 'BEGIN { printf "%.2f MB", b / 1048576 }')
        tx_gb=$(awk -v b="$TX_B" 'BEGIN { printf "%.2f GB", b / 1073741824 }')
        
        if (( RX_B > 1073741824 )); then rx_print=$rx_gb; else rx_print=$rx_mb; fi
        if (( TX_B > 1073741824 )); then tx_print=$tx_gb; else tx_print=$tx_mb; fi
        
        echo -e " ${GREEN}REALTIME BANDWIDTH (Sejak VPS ON)${NC}"
        echo -e "  - Download (RX) : ${WHITE}$rx_print${NC}"
        echo -e "  - Upload (TX)   : ${WHITE}$tx_print${NC}"
        echo -e "$LINE"
        
        # Vnstat output
        VNSTAT_OUT=$(vnstat -d -i "$MAIN_IFACE" 2>&1)
        if echo "$VNSTAT_OUT" | grep -q "Not enough data"; then
            echo -e " ${YELLOW}Catatan:${NC} Vnstat sedang merekam data."
            echo -e " Tunggu 5-10 menit untuk melihat log harian/bulanan."
        else
            echo -e " ${CYAN}DATA HARIAN (DAILY)${NC}"
            vnstat -d -i "$MAIN_IFACE" | grep -v "$MAIN_IFACE" | grep -v "^$" | head -n 8
            echo -e ""
            echo -e " ${CYAN}DATA BULANAN (MONTHLY)${NC}"
            vnstat -m -i "$MAIN_IFACE" | grep -v "$MAIN_IFACE" | grep -v "^$" | head -n 8
        fi
        echo -e "$LINE"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    5)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}UPDATE SCRIPT (SAFE MODE)${NC}"; echo -e "$LINE"
        echo -e "${YELLOW}Mengecek dan mengunduh pembaruan...${NC}"
        
        safe_update "menu/menu.sh"
        safe_update "menu/m-vless.sh"
        safe_update "menu/m-vmess.sh"
        safe_update "menu/m-trojan.sh"
        safe_update "menu/m-ssh.sh"
        safe_update "menu/m-setting.sh"
        safe_update "menu/xp.sh"
        safe_update "menu/m-backup.sh"
        safe_update "menu/menu-lock.sh"
        safe_update "menu/menu-unlock.sh"
        safe_update "menu/menu-recovery.sh"
        safe_update "menu/cek-trafik.sh"
        safe_update "menu/bot-daemon.sh"

        safe_update "sbin/algojo-kuota"
        safe_update "sbin/algojo-wibu"
        safe_update "sbin/algojo-expired"
        safe_update "sbin/algojo-expired-daemon"
        safe_update "sbin/lock-user"
        safe_update "sbin/unlock-user"
        safe_update "sbin/unlocker-wibu"
        safe_update "sbin/ws-stunnel"
        
        safe_update "common.sh"
        
        dos2unix /usr/local/bin/* /usr/local/sbin/* >/dev/null 2>&1
        systemctl restart telegram-bot algojo-expired wibu-daemon ws-stunnel >/dev/null 2>&1 || true
        echo -e "\n${GREEN}Update Selesai! Semua menu sudah versi terbaru.${NC}"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    6)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}SETUP BOT TELEGRAM${NC}"; echo -e "$LINE"
        source /etc/wibutunnel/bot.conf 2>/dev/null
        bot_status=$(systemctl is-active telegram-bot 2>/dev/null)
        if [[ "$bot_status" == "active" ]]; then
            text_sts="${GREEN}Aktif & Berjalan${NC}"
        else
            text_sts="${RED}Mati (Stopped)${NC}"
        fi
        echo -e " Status Daemon Bot : $text_sts\n"
        echo -e " [1] Ganti BOT TOKEN & CHAT ID"
        echo -e " [2] Hidupkan (Start) Bot"
        echo -e " [3] Matikan (Stop) Bot"
        echo -e " [4] Bersihkan Log Bot"
        echo -e " [0] Kembali"
        echo -e "$LINE"
        read -p " Pilih opsi [0-4]: " sub_bot
        case $sub_bot in
            1)
                read -p "Masukkan BOT TOKEN : " input_token
                read -p "Masukkan CHAT ID   : " input_chatid
                if [[ -n "$input_token" && -n "$input_chatid" ]]; then
                    cat <<EOFBOT > /etc/wibutunnel/bot.conf
BOT_TOKEN="${input_token}"
CHAT_ID="${input_chatid}"
EOFBOT
                    chmod 600 /etc/wibutunnel/bot.conf
                    curl -s -X POST "https://api.telegram.org/bot${input_token}/deleteWebhook" >/dev/null 2>&1
                    systemctl restart telegram-bot >/dev/null 2>&1
                    curl -s -X POST "https://api.telegram.org/bot${input_token}/sendMessage" \
                        -d "chat_id=${input_chatid}" \
                        -d "text=🤖 Bot Wibu Tunneling Berhasil Terhubung!" >/dev/null 2>&1
                    echo -e "${GREEN}Bot berhasil disimpan dan diaktifkan!${NC}"
                fi
                ;;
            2)
                source /etc/wibutunnel/bot.conf 2>/dev/null
                if [[ -z "$BOT_TOKEN" ]]; then
                    echo -e "${RED}[!] BOT TOKEN belum dikonfigurasi. Pilih opsi [1] dahulu.${NC}"
                else
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook" >/dev/null 2>&1
                    systemctl start telegram-bot >/dev/null 2>&1
                    echo -e "${GREEN}Bot Telegram berhasil dihidupkan!${NC}"
                fi
                ;;
            3)
                systemctl stop telegram-bot >/dev/null 2>&1
                echo -e "${YELLOW}Bot Telegram telah dimatikan!${NC}"
                ;;
            4)
                > /etc/wibutunnel/tmp/bot_error.log
                echo -e "${GREEN}Log Bot Telegram (/etc/wibutunnel/tmp/bot_error.log) berhasil dibersihkan!${NC}"
                ;;
            0) exec m-setting ;;
            *) echo -e "${RED}Pilihan salah!${NC}" ;;
        esac
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    7)
        clear; echo -e "$LINE"; echo -e "            ${WHITE}SETUP AUTO REBOOT${NC}"; echo -e "$LINE"
        echo -e " ${YELLOW}Ketik jam (0-23) untuk aktifkan, atau ketik 'off' untuk matikan.${NC}"
        read -p " Masukkan Pilihan: " input_jam
        if [[ "$input_jam" =~ ^[0-9]+$ ]] && [ "$input_jam" -le 23 ]; then
            crontab -l 2>/dev/null | grep -v "/sbin/reboot" | crontab -
            (crontab -l 2>/dev/null; echo "0 $input_jam * * * /sbin/reboot") | crontab -
            systemctl restart cron
            echo -e "\n ${GREEN}Auto Reboot disetel jam $(printf "%02d:00" "$input_jam") WIB${NC}"
        elif [[ "${input_jam,,}" == "off" || "${input_jam,,}" == "disable" ]]; then
            crontab -l 2>/dev/null | grep -v "/sbin/reboot" | crontab -
            systemctl restart cron
            echo -e "\n ${YELLOW}Auto Reboot telah dinonaktifkan (dihapus dari crontab).${NC}"
        else
            echo -e "\n ${RED}Input tidak valid! Harus angka 0-23 atau 'off'.${NC}"
        fi
        read -p " Tekan Enter..." dummy
        exec m-setting
        ;;
    8)
        clear; echo -e "$LINE"; echo -e "       ${WHITE}GANTI DOMAIN & RENEW SSL${NC}"; echo -e "$LINE"
        read -p "Masukkan Domain Baru: " new_domain
        if [[ ! "$new_domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
            echo -e "${RED}[!] Domain tidak valid!${NC}"
            read -p "Tekan Enter..." dummy
            exec m-setting
        fi
        if [[ -n "$new_domain" ]]; then
            systemctl stop haproxy xray
            _restore_svc() { systemctl start haproxy xray >/dev/null 2>&1; }
            trap _restore_svc EXIT
            # Deteksi versi certbot
            if certbot --version 2>/dev/null | grep -qE "certbot 2\."; then
                certbot certonly --standalone --non-interactive --agree-tos -m "admin@${new_domain}" -d "$new_domain" --force-renewal 2>/dev/null
            else
                certbot certonly --standalone --register-unsafely-without-email --no-eff-email --agree-tos -d "$new_domain" --force-renewal 2>/dev/null
            fi
            if [[ -f "/etc/letsencrypt/live/${new_domain}/fullchain.pem" ]]; then
                cat "/etc/letsencrypt/live/${new_domain}/fullchain.pem" "/etc/letsencrypt/live/${new_domain}/privkey.pem" > "/etc/haproxy/certs/${new_domain}.pem"
                echo "$new_domain" > /etc/xray/domain
                sed -i "s|bind \*:443 ssl crt .*\.pem|bind *:443 ssl crt /etc/haproxy/certs/${new_domain}.pem|g" /etc/haproxy/haproxy.cfg
                systemctl start haproxy xray
                trap - EXIT
                echo -e "${GREEN}Domain berhasil diganti!${NC}"
            else
                echo -e "${RED}SSL gagal untuk $new_domain!${NC}"
            fi
        fi
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    9)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}ATUR DURASI LOCK OTOMATIS${NC}"; echo -e "$LINE"
        echo -e "${CYAN}Saat ini durasi lock otomatis: ${GREEN}${LOCK_DURATION} menit${NC}\n"
        read -p "Durasi Lock (menit): " new_duration
        if [[ ! "$new_duration" =~ ^[0-9]+$ ]] || [ "$new_duration" -lt 1 ]; then
            echo -e "${RED}Durasi minimal 1!${NC}"
            sleep 2
            exec m-setting
        fi
        echo "LOCK_DURATION=$new_duration" > /etc/wibutunnel/lock.conf
        echo -e "${GREEN}Berhasil! Durasi lock diubah menjadi ${new_duration} menit.${NC}"
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    10)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}EDIT BANNER SSH${NC}"; echo -e "$LINE"
        BANNER_FILE="/etc/wibutunnel/ssh-banner"
        if [[ ! -f "$BANNER_FILE" ]]; then
            mkdir -p /etc/wibutunnel
            cat << 'BEOF' > "$BANNER_FILE"
<p style="text-align:center; line-height:0.9; margin:0; padding:0;">
<font color='#00ff36'><b>WIBU VPN STORE</b></font><br>
<font color='#5539fb'>===============================</font><br>
<font color='#aa1df8'>GUNAKAN DENGAN BIJAK</font><br>
<font color='#5539fb'>===============================</font><br>
<font color='#0056ff'>NO DDOS</font><br>
<font color='#0080bf'>NO HACKING</font><br>
<font color='#00ab80'>NO TORRENT</font><br>
<font color='#00d540'>NO PORN</font><br>
<font color='#ff0000'>MELANGGAR = BANNED PERMANENT</font><br>
<font color='#55aa75'>===============================</font><br>
<font color='#aa55b5'>Telegram : <a href="https://t.me/wibuvpnstore" target="_blank" style="color:#00ffff;">@wibuvpnstore</a></font><br>
<font color='#aa55b5'>WhatsApp : <a href="https://wa.me/6287757315408" target="_blank" style="color:#00ffff;">62877-5731-5408</a></font><br>
<font color='#aa55b5'>Grup WA : <a href="https://chat.whatsapp.com/La5nXNSOYQj8cZ5Ugyk3l8" target="_blank" style="color:#00ffff;">FREE CONFIG By WIBUVPN</a></font><br>
<font color='#00ff36'><b>VPN PREMIUM 7K / 30 HARI</b></font><br>
<font color='#aa55b5'>THANK YOU FOR USING OUR SERVICE</font><br>
<font color='#0000ff'>===============================</font>
</p>
BEOF
        fi
        echo -e "${CYAN}Banner saat ini:${NC}"
        echo -e "$LINE"
        cat "$BANNER_FILE"
        echo -e "\n$LINE"
        echo -e "${YELLOW}Buka editor nano untuk mengubah banner.${NC}"
        echo -e "${YELLOW}Simpan: CTRL+O lalu Enter. Keluar: CTRL+X.${NC}"
        read -p "Tekan Enter untuk membuka editor..." dummy
        ${EDITOR:-nano} "$BANNER_FILE"
        systemctl restart dropbear
        echo -e "\n${GREEN}Banner SSH berhasil diperbarui & Dropbear direstart!${NC}"
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    0)
        exec menu
        ;;
    *)
        echo -e "${RED}Pilihan tidak valid!${NC}"
        sleep 1
        exec m-setting
        ;;
esac
