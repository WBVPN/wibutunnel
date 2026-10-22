#!/bin/bash
# WIBUTUNNEL TELEGRAM BOT DAEMON (POLLING) - v4.0 Kurumi
# Long-polling implementation, zero webhook dependency

BOT_CONF="/etc/wibutunnel/bot.conf"
source /usr/local/bin/common.sh 2>/dev/null
OFFSET_FILE="/etc/wibutunnel/bot_offset"
CONFIG_FILE="/usr/local/etc/xray/config.json"

# Load bot configuration
if [[ ! -f "$BOT_CONF" ]]; then
    echo "[ERROR] Bot configuration not found: $BOT_CONF"
    exit 1
fi

source "$BOT_CONF"

if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
    echo "[ERROR] BOT_TOKEN or CHAT_ID not configured"
    exit 1
fi

# Initialize offset
[[ -f "$OFFSET_FILE" ]] && OFFSET=$(cat "$OFFSET_FILE") || OFFSET=0

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
    local target_id="${3:-$CHAT_ID}"
    if [[ -n "$keyboard" ]]; then
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=HTML" \
            --data-urlencode "reply_markup=${keyboard}" >/dev/null 2>&1
    else
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=HTML" >/dev/null 2>&1
    fi
}

# Process a single update
process_update() {
    local update="$1"
    
    # Extract message data
    local message=$(echo "$update" | jq -r '.message // .callback_query.message // empty')
    local callback_query=$(echo "$update" | jq -r '.callback_query // empty')
    
    if [[ -n "$callback_query" && "$callback_query" != "null" ]]; then
        # Handle callback query
        local callback_id=$(echo "$callback_query" | jq -r '.id')
        local callback_data=$(echo "$callback_query" | jq -r '.data')
        SENDER_ID=$(echo "$callback_query" | jq -r '.from.id')
        
        # Answer callback to remove loading state
        curl -s --max-time 5 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
            --data-urlencode "callback_query_id=${callback_id}" >/dev/null 2>&1
        
        # Process callback data
        case "$callback_data" in
            "info")
                local info_text=$(get_system_info)
                send_msg "$info_text" ""
                ;;
            "users")
                local users_text=$(list_users)
                send_msg "$users_text" ""
                ;;
            "adduser")
                send_msg "🔹 Untuk menambah user, gunakan:\n<code>/adduser username durasi_hari</code>\n\nContoh: <code>/adduser joko 30</code>" ""
                ;;
            "deluser")
                send_msg "🔹 Untuk menghapus user, gunakan:\n<code>/deluser username</code>\n\nContoh: <code>/deluser joko</code>" ""
                ;;
            "renew")
                send_msg "🔹 Untuk perpanjang user, gunakan:\n<code>/renew username durasi_hari</code>\n\nContoh: <code>/renew joko 30</code>" ""
                ;;
            "backup")
                perform_backup
                ;;
            *)
                send_msg "⚠️ Command tidak dikenal: $callback_data" ""
                ;;
        esac
        return
    fi
    
    if [[ -z "$message" || "$message" == "null" ]]; then
        return
    fi
    
    local text=$(echo "$message" | jq -r '.text // empty')
    SENDER_ID=$(echo "$message" | jq -r '.from.id')
    
    # Only process if from authorized chat
    if [[ "$SENDER_ID" != "$CHAT_ID" ]]; then
        send_msg "⛔ Anda tidak memiliki akses ke bot ini." "" "$SENDER_ID"
        return
    fi
    
    # Command routing
    case "$text" in
        /start|/menu)
            local quote=$(get_random_quote)
            local kb='{"inline_keyboard":[[{"text":"📊 Info Server","callback_data":"info"},{"text":"👥 List Users","callback_data":"users"}],[{"text":"➕ Add User","callback_data":"adduser"},{"text":"➖ Del User","callback_data":"deluser"}],[{"text":"🔄 Renew User","callback_data":"renew"},{"text":"💾 Backup","callback_data":"backup"}]]}'
            send_msg "🌸 <b>WIBUTUNNEL BOT v4.0</b> 🌸\n\n${quote}\n\nSilakan pilih menu:" "$kb"
            ;;
        /adduser*)
            handle_adduser "$text"
            ;;
        /deluser*)
            handle_deluser "$text"
            ;;
        /renew*)
            handle_renew "$text"
            ;;
        /backup)
            perform_backup
            ;;
        /info)
            local info_text=$(get_system_info)
            send_msg "$info_text" ""
            ;;
        /users)
            local users_text=$(list_users)
            send_msg "$users_text" ""
            ;;
        *)
            send_msg "❓ Command tidak dikenal. Ketik /menu untuk melihat pilihan." ""
            ;;
    esac
}

get_system_info() {
    local uptime_text=$(uptime -p | sed 's/up //;s/ days/d/;s/ day/d/;s/ hours/h/;s/ hour/h/;s/ minutes/m/;s/ minute/m/')
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    local disk_usage=$(df -h / | awk 'NR==2{print $5}')
    local xray_status=$(systemctl is-active xray 2>/dev/null || echo "inactive")
    
    echo "📊 <b>INFORMASI SERVER</b>

🖥 Uptime: ${uptime_text}
🔥 CPU: ${cpu_usage}%
🧠 RAM: ${mem_usage}%
💾 Disk: ${disk_usage}
⚡ Xray: ${xray_status}

$(date '+%d-%m-%Y %H:%M:%S')"
}

list_users() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "⚠️ File konfigurasi tidak ditemukan"
        return
    fi
    
    local users=$(jq -r '.inbounds[].settings.clients[]?.email // empty' "$CONFIG_FILE" 2>/dev/null | sort -u)
    
    if [[ -z "$users" ]]; then
        echo "📋 <b>DAFTAR USER</b>\n\n⚠️ Belum ada user terdaftar"
        return
    fi
    
    local result="📋 <b>DAFTAR USER</b>\n\n"
    local count=0
    
    while IFS= read -r username; do
        [[ -z "$username" ]] && continue
        count=$((count + 1))
        
        local exp_file="/etc/wibutunnel/users/${username}.exp"
        if [[ -f "$exp_file" ]]; then
            local exp_date=$(cat "$exp_file")
            local exp_epoch=$(date -d "$exp_date" +%s 2>/dev/null || echo 0)
            local now_epoch=$(date +%s)
            local days_left=$(( (exp_epoch - now_epoch) / 86400 ))
            
            if [[ $days_left -lt 0 ]]; then
                result+="${count}. ${username} ❌ (Expired)\n"
            elif [[ $days_left -le 3 ]]; then
                result+="${count}. ${username} ⚠️ (${days_left} hari lagi)\n"
            else
                result+="${count}. ${username} ✅ (${days_left} hari lagi)\n"
            fi
        else
            result+="${count}. ${username} ℹ️ (Lifetime)\n"
        fi
    done <<< "$users"
    
    echo -e "$result"
}

handle_adduser() {
    local cmd="$1"
    local username=$(echo "$cmd" | awk '{print $2}')
    local days=$(echo "$cmd" | awk '{print $3}')
    
    if [[ -z "$username" ]] || [[ -z "$days" ]]; then
        send_msg "⚠️ Format salah!\n\nGunakan: <code>/adduser username durasi_hari</code>\nContoh: <code>/adduser joko 30</code>" ""
        return
    fi
    
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        send_msg "⚠️ Durasi harus berupa angka!" ""
        return
    fi
    
    # Check if user exists
    if jq -e ".inbounds[].settings.clients[]? | select(.email==\"$username\")" "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "⚠️ User <code>$username</code> sudah ada!" ""
        return
    fi
    
    # Add user via common.sh function or direct implementation
    if command -v add_xray_user >/dev/null 2>&1; then
        add_xray_user "$username" "$days"
    else
        send_msg "⚠️ Fungsi add_xray_user tidak tersedia" ""
        return
    fi
    
    local exp_date=$(date -d "+${days} days" '+%Y-%m-%d')
    mkdir -p /etc/wibutunnel/users
    echo "$exp_date" > "/etc/wibutunnel/users/${username}.exp"
    
    systemctl reload xray 2>/dev/null
    
    send_msg "✅ User berhasil ditambahkan!\n\n👤 Username: <code>$username</code>\n📅 Expire: $exp_date ($days hari)" ""
}

handle_deluser() {
    local cmd="$1"
    local username=$(echo "$cmd" | awk '{print $2}')
    
    if [[ -z "$username" ]]; then
        send_msg "⚠️ Format salah!\n\nGunakan: <code>/deluser username</code>\nContoh: <code>/deluser joko</code>" ""
        return
    fi
    
    # Check if user exists
    if ! jq -e ".inbounds[].settings.clients[]? | select(.email==\"$username\")" "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "⚠️ User <code>$username</code> tidak ditemukan!" ""
        return
    fi
    
    # Delete user via common.sh function or direct implementation
    if command -v del_xray_user >/dev/null 2>&1; then
        del_xray_user "$username"
    else
        send_msg "⚠️ Fungsi del_xray_user tidak tersedia" ""
        return
    fi
    
    rm -f "/etc/wibutunnel/users/${username}.exp"
    
    systemctl reload xray 2>/dev/null
    
    send_msg "✅ User <code>$username</code> berhasil dihapus!" ""
}

handle_renew() {
    local cmd="$1"
    local username=$(echo "$cmd" | awk '{print $2}')
    local days=$(echo "$cmd" | awk '{print $3}')
    
    if [[ -z "$username" ]] || [[ -z "$days" ]]; then
        send_msg "⚠️ Format salah!\n\nGunakan: <code>/renew username durasi_hari</code>\nContoh: <code>/renew joko 30</code>" ""
        return
    fi
    
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        send_msg "⚠️ Durasi harus berupa angka!" ""
        return
    fi
    
    # Check if user exists
    if ! jq -e ".inbounds[].settings.clients[]? | select(.email==\"$username\")" "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "⚠️ User <code>$username</code> tidak ditemukan!" ""
        return
    fi
    
    local exp_file="/etc/wibutunnel/users/${username}.exp"
    local new_exp_date
    
    if [[ -f "$exp_file" ]]; then
        local old_exp=$(cat "$exp_file")
        local old_epoch=$(date -d "$old_exp" +%s 2>/dev/null || date +%s)
        local now_epoch=$(date +%s)
        
        # If already expired, extend from now; otherwise extend from old expiry
        if [[ $old_epoch -lt $now_epoch ]]; then
            new_exp_date=$(date -d "+${days} days" '+%Y-%m-%d')
        else
            new_exp_date=$(date -d "$old_exp +${days} days" '+%Y-%m-%d')
        fi
    else
        new_exp_date=$(date -d "+${days} days" '+%Y-%m-%d')
    fi
    
    mkdir -p /etc/wibutunnel/users
    echo "$new_exp_date" > "$exp_file"
    
    send_msg "✅ User berhasil diperpanjang!\n\n👤 Username: <code>$username</code>\n📅 Expire baru: $new_exp_date" ""
}

perform_backup() {
    send_msg "💾 Memulai backup..." ""
    
    local backup_dir="/root/backup"
    local backup_file="backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    mkdir -p "$backup_dir"
    
    tar -czf "${backup_dir}/${backup_file}" \
        /etc/wibutunnel \
        /usr/local/etc/xray/config.json \
        2>/dev/null
    
    if [[ -f "${backup_dir}/${backup_file}" ]]; then
        local size=$(du -h "${backup_dir}/${backup_file}" | awk '{print $1}')
        send_msg "✅ Backup berhasil!\n\n📦 File: <code>$backup_file</code>\n📊 Size: $size\n📂 Lokasi: <code>$backup_dir</code>" ""
    else
        send_msg "❌ Backup gagal!" ""
    fi
}

# Main polling loop
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bot daemon started (polling mode)"

while true; do
    # Get updates with long polling (30 second timeout)
    updates=$(curl -sS --max-time 35 "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30" 2>/dev/null)
    
    if [[ -z "$updates" ]]; then
        sleep 1
        continue
    fi
    
    # Check if response is valid JSON
    if ! echo "$updates" | jq empty 2>/dev/null; then
        sleep 1
        continue
    fi
    
    # Check if ok field is true
    local ok=$(echo "$updates" | jq -r '.ok // false')
    if [[ "$ok" != "true" ]]; then
        sleep 1
        continue
    fi
    
    # Get result array
    local result=$(echo "$updates" | jq -r '.result // []')
    local count=$(echo "$result" | jq 'length')
    
    if [[ "$count" -eq 0 ]]; then
        continue
    fi
    
    # Process each update
    for ((i=0; i<count; i++)); do
        local update=$(echo "$result" | jq ".[$i]")
        local update_id=$(echo "$update" | jq -r '.update_id')
        
        # Process the update
        process_update "$update"
        
        # Update offset to next update_id
        OFFSET=$((update_id + 1))
        echo "$OFFSET" > "$OFFSET_FILE"
    done
done
