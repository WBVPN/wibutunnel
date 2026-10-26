#!/bin/bash
# WIBU TUNNELING - recovery center (v4.0 KURUMI)
# Akses: menu-recovery [VLESS|VMESS|TROJAN]
source /usr/local/bin/common.sh
check_license

RED='\e[1;31m'; GREEN='\e[1;32m'; CYAN='\e[1;36m'; YELLOW='\e[1;33m'; WHITE='\e[1;37m'; BLUE='\e[34m'; NC='\e[0m'
LINE="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DB_LOCK="/etc/wibutunnel/locked_users.db"

if [[ -n "$1" ]] && [[ "$1" =~ ^(VLESS|VMESS|TROJAN)$ ]]; then
    FILTER_PROTO="$1"; proto_lower="${FILTER_PROTO,,}"
    proto_color="${GREEN}"; [[ "$FILTER_PROTO" == "VMESS" ]] && proto_color="${CYAN}"; [[ "$FILTER_PROTO" == "TROJAN" ]] && proto_color="${YELLOW}"
else FILTER_PROTO=""; fi

clear
[[ -n "$FILTER_PROTO" ]] && echo -e "${LINE}\n        ${proto_color}RECOVERY CENTER ${FILTER_PROTO}${NC}\n${LINE}" || echo -e "${LINE}\n              ${GREEN}RECOVERY CENTER USER${NC}\n${LINE}"

if [[ ! -s "$DB_LOCK" || -z $(cat "$DB_LOCK" 2>/dev/null) ]]; then
    echo -e " ${YELLOW}Tidak ada user di ruang Recovery.${NC}\n${LINE}\n"
    read -p " Tekan Enter..."; [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

declare -A USER_EXPS; declare -A USER_PROTOS

if [[ -n "$FILTER_PROTO" ]]; then
    proto_conf="/etc/xray/${proto_lower}_exp.conf"
    [[ -f "$proto_conf" ]] && while IFS= read -r line; do
        [[ -z "$line" ]] && continue; u="${line%%:*}"; e_full="${line#*:}"; e_clean="${e_full%% *}"
        [[ -n "$u" && "$u" != *"dummy"* ]] && { USER_EXPS["$u"]="$e_clean"; USER_PROTOS["$u"]="$FILTER_PROTO"; }
    done < "$proto_conf"
else
    for conf in /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf; do
        [[ ! -f "$conf" ]] && continue
        [[ "$conf" == *"vless"* ]] && proto="VLESS"; [[ "$conf" == *"vmess"* ]] && proto="VMESS"; [[ "$conf" == *"trojan"* ]] && proto="TROJAN"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue; u="${line%%:*}"; e_full="${line#*:}"; e_clean="${e_full%% *}"
            [[ -n "$u" && "$u" != *"dummy"* ]] && { USER_EXPS["$u"]="$e_clean"; USER_PROTOS["$u"]="$proto"; }
        done < "$conf"
    done
fi

echo -e " ${WHITE}NO  USERNAME       PROTO    REASON       STATUS${NC}\n${LINE}"

idx=1; declare -a USER_NAMES; GHOST_FOUND=false; mapfile -t locked_list < "$DB_LOCK"

for line in "${locked_list[@]}"; do
    u="${line%%:*}"; reason="${line##*:}"; [[ -z "$u" ]] && continue
    proto="${USER_PROTOS[$u]}"
    [[ -n "$FILTER_PROTO" && "$proto" != "$FILTER_PROTO" ]] && continue
    if [[ -z "$proto" ]]; then
        safe_sed_delete "$u" "$DB_LOCK"; safe_sed_delete "$u" /etc/wibutunnel/user_usage.db
        safe_jq_edit_args --arg user "$u" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $user))'
        GHOST_FOUND=true; continue
    fi
    USER_NAMES[$idx]=$u
    [[ "$reason" == "EXPIRED" ]]         && txt_rsn="${YELLOW}EXPIRED     ${NC}"
    [[ "$reason" == "QUOTA_EXCEEDED" ]] && txt_rsn="${RED}QUOTA       ${NC}"
    [[ "$reason" == "IP_LIMIT" ]]        && txt_rsn="${RED}IP LIMIT    ${NC}"
    [[ "$reason" == "MANUAL_DEL" ]] && txt_rsn="${CYAN}DELETED     ${NC}"
    [[ "$reason" == "LOCK" ]]       && txt_rsn="${RED}LOCKED      ${NC}"
    [[ -z "$txt_rsn" ]]            && txt_rsn="${RED}${reason}${NC}"
    printf " %-3s %-14s %-8s %b %b\n" "$idx)" "$u" "$proto" "$txt_rsn" "${RED}RECOVERY${NC}"; ((idx++))
done

[[ "$GHOST_FOUND" == true ]] && systemctl restart xray >/dev/null 2>&1

total=$((idx - 1))
if [ "$total" -eq 0 ]; then
    echo -e " ${GREEN}Tidak ada user di Recovery.${NC}\n${LINE}\n"; read -p " Tekan Enter..."
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

echo -e "${LINE}\n ${CYAN}Total: ${WHITE}$total user${NC}\n${LINE}"
echo -e " Input type : ${GREEN}deleteallusers${NC}\n              for Delete All Users RECOVERY\n${LINE}"
read -p " Pilih akun [1-$total] / [nama] / [0] Batal: " target

if [[ "$target" == "deleteallusers" ]]; then
    for user in "${USER_NAMES[@]}"; do
        [[ -z "$user" ]] && continue
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
    done
    > /etc/wibutunnel/locked_users.db
    systemctl restart xray >/dev/null 2>&1
    echo -e "\n ${GREEN}SEMUA AKUN RECOVERY TELAH DIMUSNAHKAN PERMANEN!${NC}"
    read -p " Tekan Enter..." dummy
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

[[ -z "$target" || "$target" == "0" ]] && { [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu; }
if [[ "$target" =~ ^[0-9]+$ ]] && [ "$target" -ge 1 ] && [ "$target" -le "$total" ]; then user="${USER_NAMES[$target]}"
else user="$target"; fi

[[ -z $(grep "^${user}:" "$DB_LOCK" 2>/dev/null) ]] && { echo -e "\n ${RED}User '$user' tidak di Recovery!${NC}"; sleep 2; exec menu-recovery; }

echo -e "\n ${WHITE}Reaktivasi: ${GREEN}$user${NC}\n${LINE}"
read -p " Masa Aktif Baru (Hari): " hari_baru
[[ ! "$hari_baru" =~ ^[0-9]+$ || "$hari_baru" -le 0 ]] && { echo -e " ${RED}Format salah!${NC}"; sleep 2; exec menu-recovery; }
read -p " Limit IP Baru (0=Bebas): " ip_baru; [[ ! "$ip_baru" =~ ^[0-9]+$ ]] && ip_baru=0
read -p " Limit Kuota GB (0=Unli): " bw_baru; [[ ! "$bw_baru" =~ ^[0-9]+$ ]] && bw_baru=0

new_exp=$(date -d "+${hari_baru} days" +"%Y-%m-%d %H:%M:%S"); proto="${USER_PROTOS[$user]}"

# Restore client dari sidecar (UUID/password asli)
if [[ -f "/etc/wibutunnel/recovery/${user}.json" ]]; then
    client_data=$(jq -r '.client' "/etc/wibutunnel/recovery/${user}.json" 2>/dev/null)
    if [[ -n "$client_data" && "$client_data" != "null" ]]; then
        if [[ "$proto" == "VLESS" ]]; then
            safe_jq_edit_args --argjson c "$client_data" '.inbounds[1].settings.clients += [$c] | .inbounds[2].settings.clients += [$c] | .inbounds[3].settings.clients += [$c]'
        elif [[ "$proto" == "VMESS" ]]; then
            safe_jq_edit_args --argjson c "$client_data" '.inbounds[4].settings.clients += [$c] | .inbounds[5].settings.clients += [$c] | .inbounds[6].settings.clients += [$c]'
        elif [[ "$proto" == "TROJAN" ]]; then
            safe_jq_edit_args --argjson c "$client_data" '.inbounds[7].settings.clients += [$c] | .inbounds[8].settings.clients += [$c]'
        fi
    fi
    rm -f "/etc/wibutunnel/recovery/${user}.json"
fi

[[ "$proto" == "VLESS" ]]  && { safe_sed_delete "$user" /etc/xray/vless_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/vless_exp.conf; }
[[ "$proto" == "VMESS" ]]  && { safe_sed_delete "$user" /etc/xray/vmess_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/vmess_exp.conf; }
[[ "$proto" == "TROJAN" ]] && { safe_sed_delete "$user" /etc/xray/trojan_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/trojan_exp.conf; }

safe_sed_delete "$user" /etc/wibutunnel/limit_ip.db; echo "${user}:${ip_baru}" >> /etc/wibutunnel/limit_ip.db
safe_sed_delete "$user" /etc/wibutunnel/limit_bw.db; echo "${user}:${bw_baru}" >> /etc/wibutunnel/limit_bw.db
safe_sed_delete "$user" /etc/wibutunnel/user_usage.db

safe_jq_edit_args --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))'
safe_jq_edit_args --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))'
safe_sed_delete "$user" /etc/wibutunnel/locked_users.db; systemctl restart xray >/dev/null 2>&1

# Send full account details to Telegram
source /etc/wibutunnel/bot.conf 2>/dev/null
if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null || echo "Unknown")
    ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null || echo "Unknown")
    
    if [[ "$proto" == "VLESS" ]]; then
        uuid=$(jq -r --arg u "$user" '.inbounds[1].settings.clients[]? | select(.email == $u) | .id' /etc/xray/config.json 2>/dev/null | head -n1)
        link_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
        link_ntls="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
        link_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"
        
        PESAN="<b>VPN ACCOUNT - VLESS</b>
━━━━━━━━━━━━━━━━━━━━
<b>Remarks    :</b> <code>${user}</code>
<b>Domain     :</b> <code>${domain}</code>
<b>ISP        :</b> <code>${ISP}</code>
<b>City       :</b> <code>${CITY}</code>
<b>Expired On :</b> <code>${new_exp}</code>
━━━━━━━━━━━━━━━━━━━━
<b>CONFIG DETAILS</b>
<b>Port TLS   :</b> <code>443</code>
<b>Port NTLS  :</b> <code>80</code>
<b>UUID       :</b> <code>${uuid}</code>
<b>Encryption :</b> <code>none</code>
<b>Network    :</b> <code>ws, grpc</code>
<b>Path WS    :</b> <code>/vless</code>
<b>Serv.Name  :</b> <code>vless</code>
━━━━━━━━━━━━━━━━━━━━
<b>LINK VLESS WS TLS</b>
<code>${link_tls}</code>

<b>LINK VLESS WS NO TLS</b>
<code>${link_ntls}</code>

<b>LINK VLESS GRPC</b>
<code>${link_grpc}</code>
━━━━━━━━━━━━━━━━━━━━

<i>\"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya.\" - Haku</i>"
        
    elif [[ "$proto" == "VMESS" ]]; then
        uuid=$(jq -r --arg u "$user" '.inbounds[4].settings.clients[]? | select(.email == $u) | .id' /etc/xray/config.json 2>/dev/null | head -n1)
        link_tls="vmess://$(echo -n '{"add":"'${domain}'","aid":"0","host":"'${domain}'","id":"'${uuid}'","net":"ws","path":"/vmess","port":"443","ps":"'${user}'","scy":"auto","sni":"'${domain}'","tls":"tls","type":"none","v":"2"}' | base64 -w0)"
        link_ntls="vmess://$(echo -n '{"add":"'${domain}'","aid":"0","host":"'${domain}'","id":"'${uuid}'","net":"ws","path":"/vmess-ntls","port":"80","ps":"'${user}'","scy":"auto","tls":"none","type":"none","v":"2"}' | base64 -w0)"
        link_grpc="vmess://$(echo -n '{"add":"'${domain}'","aid":"0","host":"'${domain}'","id":"'${uuid}'","net":"grpc","path":"vmess","port":"443","ps":"'${user}'","scy":"auto","sni":"'${domain}'","tls":"tls","type":"none","v":"2"}' | base64 -w0)"
        
        PESAN="<b>VPN ACCOUNT - VMESS</b>
━━━━━━━━━━━━━━━━━━━━
<b>Remarks    :</b> <code>${user}</code>
<b>Domain     :</b> <code>${domain}</code>
<b>ISP        :</b> <code>${ISP}</code>
<b>City       :</b> <code>${CITY}</code>
<b>Expired On :</b> <code>${new_exp}</code>
━━━━━━━━━━━━━━━━━━━━
<b>CONFIG DETAILS</b>
<b>Port TLS   :</b> <code>443</code>
<b>Port NTLS  :</b> <code>80</code>
<b>UUID       :</b> <code>${uuid}</code>
<b>AlterID    :</b> <code>0</code>
<b>Security   :</b> <code>auto</code>
<b>Network    :</b> <code>ws, grpc</code>
<b>Path WS    :</b> <code>/vmess</code>
<b>Serv.Name  :</b> <code>vmess</code>
━━━━━━━━━━━━━━━━━━━━
<b>LINK VMESS WS TLS</b>
<code>${link_tls}</code>

<b>LINK VMESS WS NO TLS</b>
<code>${link_ntls}</code>

<b>LINK VMESS GRPC</b>
<code>${link_grpc}</code>
━━━━━━━━━━━━━━━━━━━━

<i>\"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya.\" - Haku</i>"
        
    elif [[ "$proto" == "TROJAN" ]]; then
        password=$(jq -r --arg u "$user" '.inbounds[7].settings.clients[]? | select(.email == $u) | .password' /etc/xray/config.json 2>/dev/null | head -n1)
        link_tls="trojan://${password}@${domain}:443?path=/trojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
        link_grpc="trojan://${password}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan&sni=${domain}#${user}"
        
        PESAN="<b>VPN ACCOUNT - TROJAN</b>
━━━━━━━━━━━━━━━━━━━━
<b>Remarks    :</b> <code>${user}</code>
<b>Domain     :</b> <code>${domain}</code>
<b>ISP        :</b> <code>${ISP}</code>
<b>City       :</b> <code>${CITY}</code>
<b>Expired On :</b> <code>${new_exp}</code>
━━━━━━━━━━━━━━━━━━━━
<b>CONFIG DETAILS</b>
<b>Port       :</b> <code>443</code>
<b>Password   :</b> <code>${password}</code>
<b>Network    :</b> <code>ws, grpc</code>
<b>Path WS    :</b> <code>/trojan</code>
<b>Serv.Name  :</b> <code>trojan</code>
━━━━━━━━━━━━━━━━━━━━
<b>LINK TROJAN WS TLS</b>
<code>${link_tls}</code>

<b>LINK TROJAN GRPC</b>
<code>${link_grpc}</code>
━━━━━━━━━━━━━━━━━━━━

<i>\"Seseorang akan menjadi kuat jika melindungi seseorang yang dicintainya.\" - Haku</i>"
    fi
    
    curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${CHAT_ID}" \
        --data-urlencode "parse_mode=html" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${PESAN}" >/dev/null 2>&1 &
fi

echo -e "\n ${GREEN}BERHASIL! Akun ${user} telah aktif kembali.${NC}"
[[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]] && echo -e " ${CYAN}Detail akun telah dikirim ke Telegram.${NC}"
read -p " Tekan Enter..."; [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
