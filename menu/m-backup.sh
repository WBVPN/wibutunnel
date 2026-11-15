#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-backup.sh (v4.0 KURUMI)
# Fixed: license check tidak membunuh cron job, logging, PATH
# ==========================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi

source /etc/wibutunnel/bot.conf 2>/dev/null

IP_VPS="${MYIP:-$(curl -4 -sS --max-time 5 ipv4.icanhazip.com)}"
[[ -z "$IP_VPS" ]] && IP_VPS="Unknown"

VPS_NAME="PROJECT-WIBU"
BACKUP_DIR="/etc/wibutunnel/tmp"
mkdir -p "$BACKUP_DIR"
LOG_FILE="/var/log/wibu-backup.log"
DOMAIN_VPS=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")

# B7: password zip backup — acak bila admin tidak menyetel (JANGAN pakai CHAT_ID)
BACKUP_PASS="${WIBU_BACKUP_PASS:-}"
gen_backup_pass() {
    [[ -n "$BACKUP_PASS" ]] && return 0
    if command -v openssl >/dev/null 2>&1; then
        BACKUP_PASS=$(openssl rand -hex 16)
    else
        BACKUP_PASS=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
}

# ===== AUTO BACKUP (via Cron) =====
# DIJALANKAN PERTAMA: mencegah check_license_silent membunuh cron job
if [[ "$1" == "auto" ]]; then
    # License check dalam subshell — exit 1 tidak akan membunuh script utama
    (check_license >/dev/null 2>&1) || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] LICENSE CHECK FAILED — backup aborted" >> "$LOG_FILE"
        exit 0
    }

    [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]] && {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BOT NOT CONFIGURED — backup aborted" >> "$LOG_FILE"
        exit 0
    }

    DATE=$(date +"%Y-%m-%d_%H-%M")
    BACKUP_FILE="${BACKUP_DIR}/${DOMAIN_VPS}-${IP_VPS}.zip"
    gen_backup_pass

    cd /
    zip -q -P "$BACKUP_PASS" -r "$BACKUP_FILE" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/xray/ssh_exp.conf \
        etc/wibutunnel/ssh_pass.db \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/wibutunnel/recovery \
        etc/wibutunnel/bot.conf \
        etc/xray/domain 2>/dev/null

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ZIP CREATION FAILED — source files missing?" >> "$LOG_FILE"
        exit 0
    fi

    TGL=$(date "+%Y-%m-%d %H:%M:%S")
    CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔐 <b>Password:</b> <code>${BACKUP_PASS}</code>")

    RESPONSE=$(curl -4 -s --max-time 30 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${BACKUP_FILE}" \
        -F "caption=${CAPTION}" \
        -F "parse_mode=html")

    FILE_ID=$(echo "$RESPONSE" | jq -r '.result.document.file_id // empty')
    MSG_ID=$(echo "$RESPONSE" | jq -r '.result.message_id // empty')
    
    if [[ -n "$FILE_ID" && -n "$MSG_ID" ]]; then
        NEW_CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${FILE_ID}</code>\n\n🔐 <b>Password:</b> <code>${BACKUP_PASS}</code>")
        curl -4 -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
            -F "chat_id=${CHAT_ID}" \
            -F "message_id=${MSG_ID}" \
            -F "caption=${NEW_CAPTION}" \
            -F "parse_mode=html" >/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto backup SUCCESS — File ID: ${FILE_ID}" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto backup PARTIAL — ZIP sent but no File ID in response" >> "$LOG_FILE"
    fi
    rm -f "$BACKUP_FILE"
    exit 0
fi

# ===== INTERACTIVE MODE (dari menu) — baru jalankan license check =====
check_license_silent

# ===== MANUAL BACKUP =====
do_backup() {
    clear
    echo -e "${LINE}"
    echo -e "             ${WHITE}BACKUP MANUAL DATA VPS${NC}"
    echo -e "${LINE}"

    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        echo -e "${RED}ERROR: Bot Telegram belum di-setting!${NC}"
        echo -e "${YELLOW}Gunakan menu Setting untuk setup Bot.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${CYAN}[+] Mempersiapkan backup...${NC}"

    DATE=$(date +"%Y-%m-%d_%H-%M")
    BACKUP_FILE="${BACKUP_DIR}/${DOMAIN_VPS}-${IP_VPS}.zip"
    gen_backup_pass

    cd /
    zip -q -P "$BACKUP_PASS" -r "$BACKUP_FILE" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/xray/ssh_exp.conf \
        etc/wibutunnel/ssh_pass.db \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/wibutunnel/recovery \
        etc/wibutunnel/bot.conf \
        etc/xray/domain 2>/dev/null

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo -e "${RED}[!] Gagal membuat file backup. Periksa apakah file sumber ada.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${YELLOW}[+] Mengirim ke Telegram...${NC}"

    TGL=$(date "+%Y-%m-%d %H:%M:%S")
    CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔐 <b>Password:</b> <code>${BACKUP_PASS}</code>")

    RESPONSE=$(curl -4 -s --max-time 30 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${BACKUP_FILE}" \
        -F "caption=${CAPTION}" \
        -F "parse_mode=html")

    if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
        echo -e "${GREEN}[+] Backup berhasil dikirim ke Telegram!${NC}"
        FILE_ID=$(echo "$RESPONSE" | jq -r '.result.document.file_id // empty')
        MSG_ID=$(echo "$RESPONSE" | jq -r '.result.message_id // empty')
        
        if [[ -n "$FILE_ID" && -n "$MSG_ID" ]]; then
            NEW_CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${FILE_ID}</code>\n\n🔐 <b>Password:</b> <code>${BACKUP_PASS}</code>")
            curl -4 -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
                -F "chat_id=${CHAT_ID}" \
                -F "message_id=${MSG_ID}" \
                -F "caption=${NEW_CAPTION}" \
                -F "parse_mode=html" >/dev/null
        fi
    else
        echo -e "${RED}[!] Gagal mengirim ke Telegram. Cek koneksi atau konfigurasi Bot.${NC}"
    fi
    rm -f "$BACKUP_FILE"
    echo ""; read -p "Tekan Enter..." dummy
}

# ===== RESTORE =====
do_restore() {
    clear
    echo -e "${LINE}"
    echo -e "             ${WHITE}SMART RESTORE DATA VPS${NC}"
    echo -e "${LINE}"
    echo -e "${YELLOW}Masukkan: Link URL / File Path / File ID Telegram${NC}"
    echo -e "${LINE}"
    echo -ne "${WHITE}Masukkan Data Restore : ${NC}"
    read -r link_backup

    [[ -z "$link_backup" ]] && { echo -e "${RED}Batal.${NC}"; sleep 1; return; }

    # B6/B7: direktori kerja acak (mode 700) + bersihkan lewat trap
    local work_dir
    work_dir=$(mktemp -d "/etc/wibutunnel/tmp/restore.XXXXXX") || {
        echo -e "${RED}[!] Gagal membuat direktori kerja.${NC}"; read -p "Tekan Enter..." dummy; return; }
    chmod 700 "$work_dir"
    trap 'rm -rf "$work_dir"' RETURN EXIT INT TERM
    local restore_zip="${work_dir}/restore.zip"

    # B6(a): hanya https
    if [[ "$link_backup" =~ ^http:// ]]; then
        echo -e "${RED}[!] Hanya URL https yang diizinkan.${NC}"; read -p "Tekan Enter..." dummy; return
    elif [[ "$link_backup" =~ ^https:// ]]; then
        echo -e "${CYAN}[+] Mendeteksi Link URL...${NC}"
        wget -4 -q --timeout=20 --tries=2 -O "$restore_zip" "$link_backup" 2>/dev/null
    elif [[ "$link_backup" =~ ^documents/ ]] || [[ "$link_backup" =~ \.zip$ ]]; then
        echo -e "${CYAN}[+] Mendeteksi File Path Telegram...${NC}"
        [[ -z "$BOT_TOKEN" ]] && { echo -e "${RED}Bot Token belum diatur!${NC}"; read -p "Enter..."; return; }
        wget -4 -q --timeout=20 --tries=2 -O "$restore_zip" "https://api.telegram.org/file/bot${BOT_TOKEN}/${link_backup}" 2>/dev/null
    else
        echo -e "${CYAN}[+] Mendeteksi File ID Telegram...${NC}"
        [[ -z "$BOT_TOKEN" ]] && { echo -e "${RED}Bot Token belum diatur!${NC}"; read -p "Enter..."; return; }
        FILE_PATH=$(curl -4 -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${link_backup}" | jq -r '.result.file_path // empty')
        if [[ -n "$FILE_PATH" ]]; then
            wget -4 -q --timeout=20 --tries=2 -O "$restore_zip" "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}" 2>/dev/null
        else
            echo -e "${RED}[!] File ID tidak valid.${NC}"
        fi
    fi

    if [[ ! -s "$restore_zip" ]]; then
        echo -e "${RED}[!] Gagal restore. File kosong atau link bermasalah.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${GREEN}[+] File diterima. Verifikasi dan ekstrak...${NC}"

    command -v unzip >/dev/null 2>&1 || apt-get install -y unzip >/dev/null 2>&1

    # B6(b): password WAJIB (tidak ada fallback tanpa password)
    local restore_pass=""
    while [[ -z "$restore_pass" ]]; do
        read -r -p " ${WHITE}Password backup (wajib): ${NC}" restore_pass
    done

    # B6(c): validasi daftar entri SEBELUM ekstrak (anti path-traversal)
    local bad_entry="" entry
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        case "$entry" in
            /*|*..*) bad_entry="$entry"; break ;;
        esac
        case "$entry" in
            etc/wibutunnel/*|etc/xray/*|usr/local/etc/xray/config.json) ;;
            *) bad_entry="$entry"; break ;;
        esac
    done < <(unzip -Z1 "$restore_zip" 2>/dev/null)
    if [[ -n "$bad_entry" ]]; then
        echo -e "${RED}[!] Entri backup tidak valid / di luar cakupan: ${bad_entry}${NC}"
        echo -e "${RED}    Data lama AMAN. Restore dibatalkan.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    # B6(d): ekstrak ke direktori kerja acak
    local xdir="${work_dir}/x"
    mkdir -p "$xdir"
    if ! unzip -P "$restore_pass" -o "$restore_zip" -d "$xdir" >/dev/null 2>&1; then
        echo -e "${RED}[!] Ekstrak gagal (password salah / arsip korup). Data lama AMAN.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    # Verifikasi hasil ekstrak
    if [[ ! -f "${xdir}/usr/local/etc/xray/config.json" ]]; then
        echo -e "${RED}[!] File backup tidak valid atau password salah. Data lama AMAN.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    # Validasi config hasil ekstrak SEBELUM menyentuh data lama
    if ! xray -test -config "${xdir}/usr/local/etc/xray/config.json" >/dev/null 2>&1; then
        echo -e "${RED}[!] config.json di dalam backup tidak valid. Data lama AMAN.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${GREEN}[+] Backup valid. Mengembalikan data...${NC}"
    cp -a "${xdir}/usr/local/etc/xray/config.json" /usr/local/etc/xray/ 2>/dev/null
    cp -a "${xdir}/etc/xray/"*.conf /etc/xray/ 2>/dev/null
    cp -a "${xdir}/etc/wibutunnel/"*.db /etc/wibutunnel/ 2>/dev/null
    [[ -d "${xdir}/etc/wibutunnel/recovery" ]] && cp -a "${xdir}/etc/wibutunnel/recovery" /etc/wibutunnel/ 2>/dev/null
    cp -a "${xdir}/etc/xray/domain" /etc/xray/ 2>/dev/null
    cp -a "${xdir}/etc/wibutunnel/bot.conf" /etc/wibutunnel/ 2>/dev/null
    chmod 600 /etc/wibutunnel/*.db /etc/wibutunnel/bot.conf 2>/dev/null
    # [FIX] Zip tidak menyimpan pemilik grup: after `cp -a` config.json jadi root:root 640
    # sedangkan Xray jalan sebagai user `xray` -> "permission denied" dan xray.service GAGAL
    # (terbukti di VPS: restore sukses tapi Xray failed). Betulkan pemilik + izin di sini.
    chown root:xray /usr/local/etc/xray/config.json 2>/dev/null || true
    chmod 640 /usr/local/etc/xray/config.json 2>/dev/null || true
    chown -R xray:xray /var/log/xray 2>/dev/null || true
    chmod 600 /etc/xray/*_exp.conf 2>/dev/null || true

    # Pulihkan akun SSH ke sistem Linux jika ada data ssh_pass.db
    if [[ -f /etc/wibutunnel/ssh_pass.db ]]; then
        groupadd -f ssh_tunnel 2>/dev/null || true
        while IFS=: read -r s_u s_p; do
            [[ -z "$s_u" || -z "$s_p" ]] && continue
            if ! id "$s_u" >/dev/null 2>&1; then
                useradd -m -s /bin/bash -G ssh_tunnel "$s_u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$s_u" >/dev/null 2>&1
                printf '%s:%s\n' "$s_u" "$s_p" | chpasswd 2>/dev/null || true
            fi
        done < /etc/wibutunnel/ssh_pass.db
    fi

    rm -rf "$work_dir"   # dibersihkan juga otomatis oleh trap RETURN/EXIT

    systemctl restart xray haproxy dropbear ws-stunnel cron >/dev/null 2>&1

    # [FIX] bot.conf ikut dipulihkan -> bila VPS lama masih hidup dengan token yang sama,
    # dua poller akan bertabrakan (409) dan bot balas tidak konsisten. Matikan dulu;
    # admin mengaktifkan lagi setelah memastikan hanya satu VPS memakai token itu.
    if [[ -s /etc/wibutunnel/bot.conf ]]; then
        echo -e "${YELLOW}[!] bot.conf ikut dipulihkan: layanan bot DIMATIKAN lebih dulu supaya tidak"
        echo -e "    bertabrakan (409) dengan VPS lama yang memakai token sama.${NC}"
        echo -e "${YELLOW}    Aktifkan lagi setelah yakin: Setting -> [6] Setup Bot Telegram,"
        echo -e "    atau: systemctl enable --now telegram-bot${NC}"
        systemctl stop telegram-bot 2>/dev/null || true
        systemctl disable telegram-bot 2>/dev/null || true
    fi

    echo -e "${GREEN}[+] RESTORE BERHASIL! Semua data berhasil dikembalikan.${NC}"
    read -p "Tekan Enter..." dummy
}

# ===== AUTO BACKUP SCHEDULE =====
do_autobackup() {
    clear
    echo -e "${LINE}"
    echo -e "          ${WHITE}SETTING AUTO BACKUP BERJADWAL${NC}"
    echo -e "${LINE}"
    echo -e "${CYAN}Format 24 jam (contoh: ketik 3 untuk jam 03:00 WIB)${NC}"
    echo -ne " ${WHITE}Masukkan Jam (0-23) : ${NC}"
    read -r input_jam || return 0

    if [[ ! "$input_jam" =~ ^[0-9]+$ ]] || [ "$input_jam" -gt 23 ]; then
        echo -e "${RED}[!] Input harus angka 0-23.${NC}"
        sleep 2
        return
    fi

    crontab -l 2>/dev/null | grep -v "/usr/local/bin/m-backup auto" | crontab -
    (crontab -l 2>/dev/null; echo "0 $input_jam * * * /usr/local/bin/m-backup auto >> /var/log/wibu-backup.log 2>&1") | crontab -
    systemctl restart cron

    printf -v tampil_jam "%02d" "$input_jam"
    echo -e "${GREEN}[+] Auto Backup aktif setiap jam ${tampil_jam}:00 WIB.${NC}"
    echo ""
    read -p "Tekan Enter..." dummy
}

# ===== MAIN MENU =====
clear
echo -e "${LINE}"
echo -e "          ${WHITE}MENU BACKUP & RESTORE${NC}"
echo -e "${LINE}"
echo -e " ${GREEN}[1] Backup Manual ke Telegram${NC}"
echo -e " ${CYAN}[2] Restore Data (URL / File Path / File ID)${NC}"
echo -e " ${YELLOW}[3] Setup Auto Backup Berjadwal${NC}"
echo -e " ${RED}[0] Kembali ke Menu Utama${NC}"
echo -e "${LINE}"
echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_br || exit 0

case $sub_br in
    1) do_backup ; exec m-backup ;;
    2) do_restore ; exec m-backup ;;
    3) do_autobackup ; exec m-backup ;;
    0) exec menu ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec m-backup ;;
esac
