#!/bin/bash
# WIBUTUNNEL TELEGRAM BOT DAEMON (BASH) - v4.0 Kurumi
# Seringan kapas, secepat kilat.

BOT_CONF="/etc/wibutunnel/bot.conf"
source /usr/local/bin/common.sh 2>/dev/null
OFFSET_FILE="/etc/wibutunnel/tmp/bot_offset"
CONFIG_FILE="/usr/local/etc/xray/config.json"

mkdir -p /etc/wibutunnel/tmp
touch $OFFSET_FILE

get_random_quote() {
    local quotes=(
        '"Tidak peduli seberapa tebal awan gelap, matahari akan selalu bersinar di baliknya." - Naruto'
        '"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya." - Haku'
        '"Mimpi tidak akan pernah menjadi kenyataan jika kau hanya diam." - Doraemon'
        '"Kegagalan bukanlah akhir, melainkan awal dari pelajaran baru." - Saitama'
        '"Jika kau tidak menyukai takdirmu, jangan terima. Ubah takdirmu!" - Naruto'
        '"Keberhasilan tidak akan datang kepada mereka yang hanya menunggu." - Eren Yeager'
        '"Lebih baik mati dalam perjuangan daripada hidup tanpa tujuan." - Roronoa Zoro'
        '"Kekuatan sejati bukanlah tentang memenangkan pertarungan, tapi melindungi apa yang penting." - Kirito'
        '"Satu-satunya cara agar tidak kalah adalah dengan terus belajar." - Sora'
        '"Dunia ini tidak sempurna, itulah sebabnya dunia ini indah." - Roy Mustang'
        '"Terkadang, hal terberat yang harus dilakukan adalah yang paling benar." - Edward Elric'
        '"Menjadi lemah tidak memalukan, memalukan itu jika kita diam saja." - Fuegoleon Vermillion'
        '"Jangan biarkan masa lalumu menentukan masa depanmu." - Kenshin Himura'
    )
    local rand=$((RANDOM % ${#quotes[@]}))
    echo "${quotes[$rand]}"
}

# Utility function to send message
send_msg() {
    local text=$(echo -e "$1")
    local keyboard="$2"
    local target_id="${3:-${SENDER_ID:-$CHAT_ID}}"
    if [[ -n "$keyboard" ]]; then
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "disable_web_page_preview=true" \
            --data-urlencode "parse_mode=html" \
            --data-urlencode "text=${text}" \
            --data-urlencode "reply_markup=${keyboard}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    else
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "disable_web_page_preview=true" \
            --data-urlencode "parse_mode=html" \
            --data-urlencode "text=${text}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    fi
}

edit_msg() {
    local target_id="$1"
    local msg_id="$2"
    local text=$(echo -e "$3")
    local keyboard="$4"
    
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=${target_id}" \
        --data-urlencode "message_id=${msg_id}" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "parse_mode=html" \
        --data-urlencode "text=${text}" \
        --data-urlencode "reply_markup=${keyboard}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
}

format_online_users() {
    local raw_data="$1"
    local target_proto="$2"
    local MSG="<b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n"
    local count_users=0
    
    while IFS="|" read -r usr count iplist; do
        local proto=""
        if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto="VLESS"
        elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto="VMESS"
        elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto="TROJAN"
        else continue; fi
        
        if [[ -n "$target_proto" && "$target_proto" != "ALL" && "$proto" != "$target_proto" ]]; then
            continue
        fi
        
        IFS=',' read -ra ip_arr <<< "$iplist"
        local ip_limit=3
        local formatted_ips=""
        for ((i=0; i<${#ip_arr[@]} && i<ip_limit; i++)); do
            local clean_ip=$(echo "${ip_arr[$i]}" | tr -d ' ')
            formatted_ips+="    • <code>${clean_ip}</code>\n"
        done
        if [[ ${#ip_arr[@]} -gt $ip_limit ]]; then
            local sisa=$((${#ip_arr[@]} - ip_limit))
            formatted_ips+="    <i>... (+ ${sisa} IP lainnya)</i>\n"
        fi
        
        MSG+="<b>${usr}</b> [<code>${proto}</code>]\n ├ <b>Status:</b> ${count} Login Aktif\n └ <b>IP Address:</b>\n${formatted_ips}"
        ((count_users++))
    done <<< "$raw_data"
    
    if [[ "$count_users" -eq 0 ]]; then
        if [[ "$target_proto" == "ALL" ]]; then
            MSG+="<i>Saat ini tidak ada user yang aktif.</i>\n"
        else
            MSG+="<i>Tidak ada user ${target_proto} yang aktif.</i>\n"
        fi
    fi
    MSG+="━━━━━━━━━━━━━━━━━━━━"
    echo -e "$MSG"
}

create_account() {
    local proto=$1
    local user=$2
    local hari=$3
    local limit_ip=${4:-0}
    local limit_bw=${5:-0}
    
    # Validation
    if [[ ! "$limit_ip" =~ ^[0-9]+$ ]]; then limit_ip=0; fi
    if [[ ! "$limit_bw" =~ ^[0-9]+$ ]]; then limit_bw=0; fi
    
    if [[ -n "${user//[a-zA-Z0-9_-]/}" ]]; then
        send_msg "❌ <b>Nama User Salah!</b>\nHanya boleh huruf, angka, dan strip (-)."
        return
    fi
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>User '${user}' Sudah Ada!</b>"
        return
    fi

    local uuid=$(uuidgen)
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    
    local exp_date=""
    local tampil_exp=""
    
    local clean_hari="${hari%[hmd]}"
    if [[ -z "${clean_hari//[0-9]/}" && -n "$clean_hari" ]]; then
        if [[ "$hari" == *m ]]; then
            exp_date=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
        elif [[ "$hari" == *h ]]; then
            exp_date=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
        else
            exp_date=$(date -d "+${clean_hari} days" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} days" +"%Y-%m-%d")
        fi
    else
        send_msg "❌ <b>Format Waktu Salah!</b>\nGunakan angka untuk hari, atau akhiran 'h' untuk jam, 'm' untuk menit (contoh: 30, 1h, 60m)."
        return
    fi
    local link1=""
    local link2=""
    local link3=""
    
    if [[ "$proto" == "VLESS" ]]; then
        safe_jq_edit_args --arg uuid "$uuid" --arg user "$user" '
            .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}] |
            .inbounds[2].settings.clients += [{"id": $uuid, "email": $user}] |
            .inbounds[3].settings.clients += [{"id": $uuid, "email": $user}]
        '
        echo "${user}:${exp_date}" >> /etc/xray/vless_exp.conf
        link1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
        link3="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"
    elif [[ "$proto" == "VMESS" ]]; then
        safe_jq_edit_args --arg uuid "$uuid" --arg user "$user" '
            .inbounds[4].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}] |
            .inbounds[5].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}] |
            .inbounds[6].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}]
        '
        echo "${user}:${exp_date}" >> /etc/xray/vmess_exp.conf
        link1="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
        link2="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ntls\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"\",\"sni\":\"\"}" | base64 -w 0)"
        link3="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
    elif [[ "$proto" == "TROJAN" ]]; then
        safe_jq_edit_args --arg uuid "$uuid" --arg user "$user" '
            .inbounds[7].settings.clients += [{"password": $uuid, "email": $user}] |
            .inbounds[8].settings.clients += [{"password": $uuid, "email": $user}]
        '
        echo "${user}:${exp_date}" >> /etc/xray/trojan_exp.conf
        link1="trojan://${uuid}@${domain}:443?path=/trojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan&sni=${domain}#${user}"
    fi

    echo "${user}:${limit_ip}" >> /etc/wibutunnel/limit_ip.db
    echo "${user}:${limit_bw}" >> /etc/wibutunnel/limit_bw.db
    systemctl restart xray >/dev/null 2>&1

    [[ "$limit_ip" -eq 0 ]] && limit_ip="Bebas" || limit_ip="${limit_ip} IP"
    [[ "$limit_bw" -eq 0 ]] && limit_bw="Unlimited" || limit_bw="${limit_bw} GB"

    local CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null)
    local ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"
    local THICKLINE="━━━━━━━━━━━━━━━━━━━━"
    local pesan="<b>VPN ACCOUNT - ${proto}</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>Remarks    :</b> <code>${user}</code>\n"
    pesan+="<b>Domain     :</b> <code>${domain}</code>\n"
    pesan+="<b>ISP        :</b> <code>${ISP}</code>\n"
    pesan+="<b>City       :</b> <code>${CITY}</code>\n"
    pesan+="<b>Expired On :</b> <code>${exp_date}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>CONFIG DETAILS</b>\n"
    pesan+="<b>Port TLS   :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port NTLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>AlterId    :</b> <code>0</code>\n"
        pesan+="<b>Security   :</b> <code>auto</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vmess</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption :</b> <code>none</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vless</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password   :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/trojan</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>trojan</code>\n"
    fi

    pesan+="${THICKLINE}\n"
    pesan+="<b>LINK ${proto} WS TLS</b>\n<code>${link1}</code>\n\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>LINK ${proto} WS NO TLS</b>\n<code>${link2}</code>\n\n"
        pesan+="<b>LINK ${proto} GRPC</b>\n<code>${link3}</code>\n"
    else
        pesan+="<b>LINK ${proto} GRPC</b>\n<code>${link2}</code>\n"
    fi
    pesan+="${THICKLINE}"
    
    pesan+="\n\n<i>$(get_random_quote)</i>"
    send_msg "$pesan" ""
}

delete_account() {
    local user=$1
    local proto=$2
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then return; fi
    
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) == null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan di database."
        return
    fi
    
    safe_jq_edit_args --arg u "$user" '
        .inbounds[1].settings.clients |= map(select(.email != $u)) |
        .inbounds[2].settings.clients |= map(select(.email != $u)) |
        .inbounds[3].settings.clients |= map(select(.email != $u)) |
        .inbounds[4].settings.clients |= map(select(.email != $u)) |
        .inbounds[5].settings.clients |= map(select(.email != $u)) |
        .inbounds[6].settings.clients |= map(select(.email != $u)) |
        .inbounds[7].settings.clients |= map(select(.email != $u)) |
        .inbounds[8].settings.clients |= map(select(.email != $u)) |
        (.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))
    '

    safe_sed_delete "$user" /etc/xray/vless_exp.conf
    safe_sed_delete "$user" /etc/xray/vmess_exp.conf
    safe_sed_delete "$user" /etc/xray/trojan_exp.conf
    safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db
    safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db
    safe_sed_delete "$user" /etc/wibutunnel/locked_users.db
    safe_sed_delete "$user" /etc/wibutunnel/user_usage.db

    systemctl restart xray >/dev/null 2>&1
    
    local kb=""
    [[ -n "$proto" ]] && kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
    send_msg "<b>Berhasil!</b>\nAkun <code>${user}</code> telah dimusnahkan secara permanen." "$kb"
}

is_admin() {
    local id=$1
    if [[ "$id" == "$CHAT_ID" ]]; then
        return 0
    fi
    if [[ -f /etc/wibutunnel/bot_admins.db ]]; then
        if grep -q "^${id}$" /etc/wibutunnel/bot_admins.db; then
            return 0
        fi
    fi
    return 1
}

renew_account() {
    local user=$1
    local hari=$2
    local proto=$3
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then return; fi
    if [[ ! "$hari" =~ ^[0-9]+$ || "$hari" -le 0 ]]; then
        send_msg "❌ <b>Format Hari Salah!</b>\nGunakan angka."
        return
    fi
    
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) == null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan."
        return
    fi

    local exp_file=""
    if grep -q "^${user}:" /etc/xray/vless_exp.conf; then
        exp_file="/etc/xray/vless_exp.conf"
    elif grep -q "^${user}:" /etc/xray/vmess_exp.conf; then
        exp_file="/etc/xray/vmess_exp.conf"
    elif grep -q "^${user}:" /etc/xray/trojan_exp.conf; then
        exp_file="/etc/xray/trojan_exp.conf"
    fi

    if [[ -z "$exp_file" ]]; then
        send_msg "❌ <b>Gagal!</b>\nData masa aktif user <code>${user}</code> tidak ditemukan."
        return
    fi

    local exp_date=""
    local tampil_exp=""
    
    local clean_hari="${hari%[hmd]}"
    if [[ -z "${clean_hari//[0-9]/}" && -n "$clean_hari" ]]; then
        if [[ "$hari" == *m ]]; then
            exp_date=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
        elif [[ "$hari" == *h ]]; then
            exp_date=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
        else
            exp_date=$(date -d "+${clean_hari} days" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} days" +"%Y-%m-%d")
        fi
    else
        send_msg "❌ <b>Format Waktu Salah!</b>\nGunakan angka untuk hari, atau akhiran 'h' untuk jam, 'm' untuk menit (contoh: 30, 1h, 60m)."
        return
    fi
    
    safe_sed_delete "$user" "$exp_file"
    echo "${user}:${exp_date}" >> "$exp_file"
    
    local kb=""
    [[ -n "$proto" ]] && kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
    send_msg "<b>Berhasil Perpanjang Akun!</b>\n\n<b>User :</b> <code>${user}</code>\n<b>Ditambah :</b> ${hari}\n<b>Expired Baru :</b> <code>${tampil_exp}</code>" "$kb"
}

change_limit() {
    local user=$1
    local limit_ip=$2
    local limit_bw=$3
    local proto=$4
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then return; fi
    
    if [[ ! "$limit_ip" =~ ^[0-9]+$ || ! "$limit_bw" =~ ^[0-9]+$ ]]; then
        send_msg "❌ <b>Format Limit Salah!</b>\nIP dan GB harus berupa angka."
        return
    fi
    
    if ! jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan."
        return
    fi
    
    # Update IP
    safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db
    echo "${user}:${limit_ip}" >> /etc/wibutunnel/limit_ip.db
    
    # Update BW
    safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db
    echo "${user}:${limit_bw}" >> /etc/wibutunnel/limit_bw.db
    
    local ip_str="Bebas"; [[ "$limit_ip" -ne 0 ]] && ip_str="${limit_ip} IP"
    local bw_str="Unlimited"; [[ "$limit_bw" -ne 0 ]] && bw_str="${limit_bw} GB"
    
    local kb=""
    [[ -n "$proto" ]] && kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
    send_msg "<b>Limit Berhasil Diubah!</b>\n\n<b>User :</b> <code>${user}</code>\n<b>Limit IP :</b> ${ip_str}\n<b>Limit Kuota :</b> ${bw_str}" "$kb"
}

list_account() {
    local target_proto="$1"
    local msg="━━━━━━━━━━━━━━━━━━━━\n <b>LIST AKUN ${target_proto}</b>\n━━━━━━━━━━━━━━━━━━━━\n"
    
    get_limits() {
        local u=$1
        local ip=$(grep "^${u}:" /etc/wibutunnel/limit_ip.db 2>/dev/null | cut -d: -f2)
        local bw=$(grep "^${u}:" /etc/wibutunnel/limit_bw.db 2>/dev/null | cut -d: -f2)
        [[ -z "$ip" || "$ip" == "0" ]] && ip="Bebas" || ip="${ip} IP"
        [[ -z "$bw" || "$bw" == "0" ]] && bw="Unl" || bw="${bw} GB"
        echo "IP: ${ip} | BW: ${bw}"
    }

    if [[ "$target_proto" == "VLESS" ]]; then
        local c=0
        while IFS=":" read -r usr exp; do
            [[ -z "$usr" || "$usr" == dummy* ]] && continue
            local lmt=$(get_limits "$usr")
            msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
            ((c++))
        done < /etc/xray/vless_exp.conf
        [[ "$c" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    elif [[ "$target_proto" == "VMESS" ]]; then
        local c=0
        while IFS=":" read -r usr exp; do
            [[ -z "$usr" || "$usr" == dummy* ]] && continue
            local lmt=$(get_limits "$usr")
            msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
            ((c++))
        done < /etc/xray/vmess_exp.conf
        [[ "$c" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    elif [[ "$target_proto" == "TROJAN" ]]; then
        local c=0
        while IFS=":" read -r usr exp; do
            [[ -z "$usr" || "$usr" == dummy* ]] && continue
            local lmt=$(get_limits "$usr")
            msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
            ((c++))
        done < /etc/xray/trojan_exp.conf
        [[ "$c" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    fi
    
    msg+="\n━━━━━━━━━━━━━━━━━━━━"
    local kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${target_proto}"' Menu","callback_data":"menu_'"${target_proto,,}"'"}]]}'
    send_msg "$msg" "$kb"
}

backup_vps() {
    local target_id="${SENDER_ID:-$CHAT_ID}"
    
    local load_resp=$(curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -F "chat_id=${target_id}" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F "text=⏳ <b>Sedang merakit file backup...</b>")
    local load_msg_id=$(echo "$load_resp" | jq -r '.result.message_id // empty')
    
    local domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    local ip_vps=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null || echo "Unknown")
    local backup_file="/tmp/${domain}-${ip_vps}.zip"
    rm -f "$backup_file"
    
    cd /
    zip -q -P "$CHAT_ID" -r "$backup_file" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/xray/domain 2>/dev/null
    
    if [[ -f "$backup_file" ]]; then
        local tgl=$(date "+%Y-%m-%d %H:%M:%S")
        local caption=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${tgl}</code>\n\n<i>Mengunggah dan membuat File ID...</i>")
        local response=$(curl -s --max-time 60 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
            -F "chat_id=${target_id}" \
            -F "document=@${backup_file}" \
            -F "caption=${caption}" \
            -F "parse_mode=html")
            
        local file_id=$(echo "$response" | jq -r '.result.document.file_id // empty')
        local msg_id=$(echo "$response" | jq -r '.result.message_id // empty')
        
        if [[ -n "$file_id" && -n "$msg_id" && "$msg_id" != "null" ]]; then
            local new_caption=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${tgl}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${file_id}</code>\n\n🔐 <b>Password:</b> CHAT ID Anda")
            curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
                -F "chat_id=${target_id}" \
                -F "message_id=${msg_id}" \
                -F "parse_mode=html" \
                -F "caption=${new_caption}" >/dev/null 2>&1
        fi
        
        rm -f "$backup_file"
        
        if [[ -n "$load_msg_id" && "$load_msg_id" != "null" ]]; then
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
                -F "chat_id=${target_id}" \
                -F "message_id=${load_msg_id}" >/dev/null 2>&1
        fi
    else
        send_msg "❌ <b>Gagal membuat backup!</b>"
        if [[ -n "$load_msg_id" && "$load_msg_id" != "null" ]]; then
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
                -F "chat_id=${target_id}" \
                -F "message_id=${load_msg_id}" >/dev/null 2>&1
        fi
    fi
}

detail_account() {
    local user=$1
    local target_proto=$2
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then return; fi
    
    local proto=""
    local uuid=""
    local exp_date=""
    
    if grep -q "^${user}:" /etc/xray/vless_exp.conf; then
        proto="VLESS"
        uuid=$(jq -r --arg u "$user" '.inbounds[1].settings.clients[] | select(.email == $u) | .id' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/vless_exp.conf | cut -d: -f2- | awk '{print $1}')
    elif grep -q "^${user}:" /etc/xray/vmess_exp.conf; then
        proto="VMESS"
        uuid=$(jq -r --arg u "$user" '.inbounds[4].settings.clients[] | select(.email == $u) | .id' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/vmess_exp.conf | cut -d: -f2- | awk '{print $1}')
    elif grep -q "^${user}:" /etc/xray/trojan_exp.conf; then
        proto="TROJAN"
        uuid=$(jq -r --arg u "$user" '.inbounds[7].settings.clients[] | select(.email == $u) | .password' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/trojan_exp.conf | cut -d: -f2- | awk '{print $1}')
    fi

    if [[ -z "$proto" || -z "$uuid" ]]; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan."
        return
    fi

    local domain=$(cat /etc/xray/domain 2>/dev/null)
    local limit_ip=$(grep "^${user}:" /etc/wibutunnel/limit_ip.db 2>/dev/null | cut -d: -f2)
    local limit_bw=$(grep "^${user}:" /etc/wibutunnel/limit_bw.db 2>/dev/null | cut -d: -f2)
    
    [[ -z "$limit_ip" || "$limit_ip" -eq 0 ]] && limit_ip="Bebas" || limit_ip="${limit_ip} IP"
    [[ -z "$limit_bw" || "$limit_bw" -eq 0 ]] && limit_bw="Unlimited" || limit_bw="${limit_bw} GB"

    local link1=""
    local link2=""
    local link3=""

    if [[ "$proto" == "VLESS" ]]; then
        link1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
        link3="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"
    elif [[ "$proto" == "VMESS" ]]; then
        link1="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
        link2="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ntls\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"\",\"sni\":\"\"}" | base64 -w 0)"
        link3="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
    elif [[ "$proto" == "TROJAN" ]]; then
        link1="trojan://${uuid}@${domain}:443?path=/trojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan&sni=${domain}#${user}"
    fi

    local CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null)
    local ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"

    local THICKLINE="━━━━━━━━━━━━━━━━━━━━"
    local pesan="<b>VPN ACCOUNT - ${proto}</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>Remarks    :</b> <code>${user}</code>\n"
    pesan+="<b>Domain     :</b> <code>${domain}</code>\n"
    pesan+="<b>ISP        :</b> <code>${ISP}</code>\n"
    pesan+="<b>City       :</b> <code>${CITY}</code>\n"
    pesan+="<b>Expired On :</b> <code>${exp_date}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>CONFIG DETAILS</b>\n"
    pesan+="<b>Port TLS   :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port NTLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>AlterId    :</b> <code>0</code>\n"
        pesan+="<b>Security   :</b> <code>auto</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vmess</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption :</b> <code>none</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vless</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password   :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/trojan</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>trojan</code>\n"
    fi

    pesan+="${THICKLINE}\n"
    pesan+="<b>LINK ${proto} WS TLS</b>\n<code>${link1}</code>\n\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>LINK ${proto} WS NO TLS</b>\n<code>${link2}</code>\n\n"
        pesan+="<b>LINK ${proto} GRPC</b>\n<code>${link3}</code>\n"
    else
        pesan+="<b>LINK ${proto} GRPC</b>\n<code>${link2}</code>\n"
    fi
    pesan+="${THICKLINE}"
    
    pesan+="\n\n<i>$(get_random_quote)</i>"
    send_msg "$pesan" ""
}

check_login() {
    local target_proto="$1"
    LOG_FILE="/var/log/xray/access.log"
    if [[ ! -s "$LOG_FILE" ]]; then
        send_msg "❌ <b>Belum ada data log aktif (kosong).</b>"
        return
    fi
    
    THRESH=$(date -d '3 minutes ago' +'%Y/%m/%d %H:%M:%S')
    LOGIN_DATA=$(awk -v thresh="$THRESH" '{ if($1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1" "$2 < thresh) exit; if(/accepted/){ for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]", " : "") ip; counts[email]++ } } } } END { for (e in ips) print e "|" counts[e] "|" ips[e] }' <(tac "$LOG_FILE" 2>/dev/null) 2>/dev/null)

    if [[ -z "$LOGIN_DATA" ]]; then
        local msg="<b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n<i>Saat ini tidak ada user yang aktif.</i>\n━━━━━━━━━━━━━━━━━━━━"
        local kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${target_proto}"' Menu","callback_data":"menu_'"${target_proto,,}"'"}]]}'
        send_msg "$msg" "$kb"
    else
        LOG_MSG=$(format_online_users "$LOGIN_DATA" "$target_proto")
        local kb='{"inline_keyboard":[[{"text":"🔙 Back to '"${target_proto}"' Menu","callback_data":"menu_'"${target_proto,,}"'"}]]}'
        send_msg "$LOG_MSG" "$kb"
    fi
}

show_main_menu() {
    local target="$1"
    local msg_id="$2"
    local text="━━━━━━━━━━━━━━━━━━━━\n 🤖 <b>WIBUTUNNEL PANEL BOT</b>\n━━━━━━━━━━━━━━━━━━━━\n\nSelamat datang di Panel Kendali VPS. Silakan pilih menu di bawah ini:"
    
    local kb='{"inline_keyboard":['
    kb+='[{"text":"🔹 VLESS","callback_data":"menu_vless"},{"text":"🔸 VMESS","callback_data":"menu_vmess"}],'
    kb+='[{"text":"♦️ TROJAN","callback_data":"menu_trojan"},{"text":"⚙️ SYSTEM","callback_data":"menu_system"}]'
    kb+=']}'
    
    if [[ -n "$msg_id" ]]; then
        edit_msg "$target" "$msg_id" "$text" "$kb"
    else
        send_msg "$text" "$kb" "$target"
    fi
}

show_proto_menu() {
    local target="$1"
    local msg_id="$2"
    local proto="$3"
    
    if [[ "$proto" == "SYSTEM" ]]; then
        local text="⚙️ <b>MENU SYSTEM</b>\nSilakan pilih opsi:"
        local kb='{"inline_keyboard":['
        kb+='[{"text":"📊 Cek Trafik Global","callback_data":"act_trafik_ALL"}],'
        kb+='[{"text":"🟢 Cek Login Global","callback_data":"act_login_ALL"}],'
        kb+='[{"text":"💻 Info VPS","callback_data":"act_info_ALL"}],'
        kb+='[{"text":"📦 Backup VPS","callback_data":"act_backup_ALL"}],'
        kb+='[{"text":"🔙 Back","callback_data":"main_menu"}]'
        kb+=']}'
        edit_msg "$target" "$msg_id" "$text" "$kb"
        return
    fi
    
    local text="🛡 <b>MENU ${proto}</b>\nSilakan pilih opsi manajemen akun:"
    local kb='{"inline_keyboard":['
    kb+='[{"text":"➕ Create","callback_data":"act_create_'"$proto"'"},{"text":"⏱ Trial","callback_data":"act_trial_'"$proto"'"}],'
    kb+='[{"text":"♻️ Renew","callback_data":"act_renew_'"$proto"'"},{"text":"🗑 Delete","callback_data":"act_del_'"$proto"'"}],'
    kb+='[{"text":"🟢 Cek Login","callback_data":"act_login_'"$proto"'"},{"text":"📋 List Akun","callback_data":"act_list_'"$proto"'"}],'
    kb+='[{"text":"🎛 Limit & BW","callback_data":"act_limit_'"$proto"'"},{"text":"🔎 Detail Link","callback_data":"act_detail_'"$proto"'"}],'
    kb+='[{"text":"🔙 Back","callback_data":"main_menu"}]'
    kb+=']}'
    
    edit_msg "$target" "$msg_id" "$text" "$kb"
}

ask_input() {
    local target="$1"
    local action="$2"
    local proto="$3"
    local text=""
    
    case "$action" in
        create) text="✨ <b>CREATE ${proto}</b>\n\nKirim data dengan format:\n<code>[username] [hari] [limit_ip] [limit_gb]</code>\n\nContoh: <code>budi 30 2 10</code>\n<i>(Kirim 0 untuk IP/GB unlimited)</i>" ;;
        trial) text="⏱ <b>TRIAL ${proto}</b>\n\nBerapa jam atau berapa menit?\n\nKirim angka dengan akhiran <b>h</b> (jam) atau <b>m</b> (menit).\nContoh: <code>1h</code> atau <code>30m</code>\n\n<i>*Quota otomatis 1 GB & IP Unlimited.</i>" ;;
        del) text="🗑 <b>DELETE ${proto}</b>\n\nKirim <b>Username</b> yang ingin dihapus:\nContoh: <code>budi</code>" ;;
        renew) text="♻️ <b>RENEW ${proto}</b>\n\nKirim data dengan format:\n<code>[username] [tambahan_hari]</code>\n\nContoh: <code>budi 30</code>" ;;
        limit) text="🎛 <b>UBAH LIMIT ${proto}</b>\n\nKirim data dengan format:\n<code>[username] [limit_ip_baru] [limit_gb_baru]</code>\n\nContoh: <code>budi 2 5</code>\n<i>(Kirim 0 untuk unlimited)</i>" ;;
        detail) text="🔎 <b>DETAIL AKUN ${proto}</b>\n\nKirim <b>Username</b>:\nContoh: <code>budi</code>" ;;
    esac
    
    local kb='{"inline_keyboard":[[{"text":"❌ Batal","callback_data":"menu_'"${proto,,}"'"}]]}'
    send_msg "$text" "$kb" "$target"
}


# === WEBHOOK ENTRY POINT ===
if [[ ! -f "$BOT_CONF" ]]; then exit 1; fi
source "$BOT_CONF"
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then exit 1; fi

PAYLOAD=$1
[[ -z "$PAYLOAD" ]] && exit 0

CB_ID=$(echo "$PAYLOAD" | jq -r ".callback_query.id // empty")
if [[ -n "$CB_ID" ]]; then
    SENDER_ID=$(echo "$PAYLOAD" | jq -r ".callback_query.message.chat.id")
    MSG_ID=$(echo "$PAYLOAD" | jq -r ".callback_query.message.message_id")
    DATA=$(echo "$PAYLOAD" | jq -r ".callback_query.data // empty")
    
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery?callback_query_id=${CB_ID}" >/dev/null &
    
    if is_admin "$SENDER_ID"; then
        if [[ "$DATA" == "main_menu" ]]; then
            show_main_menu "$SENDER_ID" "$MSG_ID"
        elif [[ "$DATA" == menu_* ]]; then
            proto=${DATA#menu_}
            show_proto_menu "$SENDER_ID" "$MSG_ID" "${proto^^}"
        elif [[ "$DATA" == act_* ]]; then
            action=$(echo "$DATA" | cut -d'_' -f2)
            proto=$(echo "$DATA" | cut -d'_' -f3)
            
            rm -f "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}"
            
            case "$action" in
                trial)
                    create_account "$proto" "trial-$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)" "1h" "0" "1"
                    ;;
                list) list_account "$proto" ;;
                login) check_login "$proto" ;;
                trafik) 
                    if [[ -s "/etc/wibutunnel/user_usage.db" ]]; then
                        TRF_MSG="📊 <b>TOP 10 PEMAKAIAN QUOTA</b>\n━━━━━━━━━━━━━━━━━━━━\n"
                        idx=1
                        while IFS=":" read -r bytes usr; do
                            if [[ "$bytes" -ge 1073741824 ]]; then gb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1073741824 }'); vol="${gb} GB"
                            elif [[ "$bytes" -ge 1048576 ]]; then mb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1048576 }'); vol="${mb} MB"
                            elif [[ "$bytes" -ge 1024 ]]; then kb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1024 }'); vol="${kb} KB"
                            else vol="${bytes} Bytes"; fi
                            if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto_r="VLESS"; elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto_r="VMESS"; elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto_r="TROJAN"; else continue; fi
                            TRF_MSG+="<b>${idx}.</b> <code>${usr}</code> [${proto_r}] : ${vol}\n"
                            ((idx++))
                            [[ $idx -gt 10 ]] && break
                        done < <(awk -F':' '{ if ($1 ~ /^(vless|vmess|trojan)-(ws|grpc)-(tls|ntls)$/ || $1 ~ /^(vless|vmess|trojan)-grpc$/ || $1 == "api" || $1 == "direct" || $1 == "blocked") next; down=($2=="null"||$2=="")?0:$2; up=($3=="null"||$3=="")?0:$3; print (down+up)":"$1 }' /etc/wibutunnel/user_usage.db 2>/dev/null | sort -t: -k1 -nr)
                        TRF_MSG+="━━━━━━━━━━━━━━━━━━━━"
                        local kb='{"inline_keyboard":[[{"text":"🔙 Back to SYSTEM Menu","callback_data":"menu_system"}]]}'
                        send_msg "$TRF_MSG" "$kb"
                    else
                        send_msg "📊 <b>Belum ada data trafik pemakaian.</b>" '{"inline_keyboard":[[{"text":"🔙 Back to SYSTEM Menu","callback_data":"menu_system"}]]}'
                    fi
                    ;;
                info)
                    IP=$(curl -sS --max-time 3 ipv4.icanhazip.com 2>/dev/null)
                    UPTIME=$(uptime -p | cut -d' ' -f2-)
                    RAM=$(free -m | awk '/Mem:/ {print $3" MB / "$2" MB"}')
                    CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
                    DISK=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')
                    OS=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
                    INFO_MSG="💻 <b>INFORMASI VPS SERVER</b>\n━━━━━━━━━━━━━━━━━━━━\n<b>🖥 OS     :</b> <code>${OS}</code>\n<b>🌐 IP     :</b> <code>${IP}</code>\n<b>⏱ Uptime :</b> <code>${UPTIME}</code>\n<b>🧠 RAM    :</b> <code>${RAM}</code>\n<b>⚡️ CPU    :</b> <code>${CPU}%</code>\n<b>💾 Disk   :</b> <code>${DISK}</code>\n━━━━━━━━━━━━━━━━━━━━"
                    local kb='{"inline_keyboard":[[{"text":"🔙 Back to SYSTEM Menu","callback_data":"menu_system"}]]}'
                    send_msg "$INFO_MSG" "$kb"
                    ;;
                backup)
                    backup_vps
                    ;;
                *)
                    echo "$action $proto" > "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}"
                    ask_input "$SENDER_ID" "$action" "$proto"
                    ;;
            esac
        fi
    fi
else
    # Check for Text Message
    SENDER_ID=$(echo "$PAYLOAD" | jq -r ".message.chat.id // empty")
    if [[ -n "$SENDER_ID" ]]; then
        TEXT=$(echo "$PAYLOAD" | jq -r ".message.text // empty")
        TEXT="${TEXT//$'\r'/}"
        
        if is_admin "$SENDER_ID"; then
            if [[ -f "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}" && ! "$TEXT" =~ ^/ ]]; then
                read -r action proto < "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}"
                rm -f "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}"
                
                case "$action" in
                    create)
                        read -r user hari ip gb <<< "$TEXT"
                        if [[ -z "$gb" ]]; then
                            send_msg "❌ Format salah! Harap masukkan:\n<code>nama hari limit_ip limit_gb</code>" '{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
                        else
                            create_account "$proto" "$user" "$hari" "$ip" "$gb"
                        fi
                        ;;
                    trial)
                        waktu="$TEXT"
                        create_account "$proto" "trial-$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)" "$waktu" "0" "1"
                        ;;
                    del)
                        delete_account "$TEXT" "$proto"
                        ;;
                    renew)
                        read -r user hari <<< "$TEXT"
                        if [[ -z "$hari" ]]; then
                            send_msg "❌ Format salah! Harap masukkan:\n<code>nama hari</code>" '{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
                        else
                            renew_account "$user" "$hari" "$proto"
                        fi
                        ;;
                    limit)
                        read -r user ip gb <<< "$TEXT"
                        if [[ -z "$gb" ]]; then
                            send_msg "❌ Format salah! Harap masukkan:\n<code>nama limit_ip limit_gb</code>" '{"inline_keyboard":[[{"text":"🔙 Back to '"${proto}"' Menu","callback_data":"menu_'"${proto,,}"'"}]]}'
                        else
                            change_limit "$user" "$ip" "$gb" "$proto"
                        fi
                        ;;
                    detail)
                        detail_account "$TEXT" "$proto"
                        ;;
                esac
            else
                rm -f "/etc/wibutunnel/tmp/bot_state_${SENDER_ID}"
                case "$TEXT" in
                    /start|/menu)
                        show_main_menu "$SENDER_ID" ""
                        ;;
                esac
            fi
        fi
    fi
fi
