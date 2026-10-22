#!/bin/bash
# [PATCH] Tambah validasi X-Telegram-Bot-Api-Secret-Token
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

source /etc/wibutunnel/bot.conf 2>/dev/null
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"

shopt -s nocasematch
SECRET_HEADER=""
while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && break
    if [[ "$line" =~ ^content-length:\ *([0-9]+) ]]; then
        CONTENT_LENGTH="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ^x-telegram-bot-api-secret-token:\ *(.+) ]]; then
        SECRET_HEADER="${BASH_REMATCH[1]}"
    fi
done
shopt -u nocasematch

# Constant-time comparison to prevent timing attacks
compare_constant_time() {
    local a="$1" b="$2"
    [[ ${#a} -ne ${#b} ]] && return 1
    local result=0
    for ((i=0; i<${#a}; i++)); do
        [[ "${a:i:1}" != "${b:i:1}" ]] && result=1
    done
    return $result
}

# Validasi secret token jika dikonfigurasi
if [[ -n "$WEBHOOK_SECRET" ]] && ! compare_constant_time "$SECRET_HEADER" "$WEBHOOK_SECRET"; then
    echo -en "HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{\"error\":\"unauthorized\"}"
    exit 0
fi

payload=""
if [[ -n "$CONTENT_LENGTH" ]] && [[ "$CONTENT_LENGTH" =~ ^[0-9]+$ ]] && [[ "$CONTENT_LENGTH" -le 10485760 ]]; then
    payload=$(head -c "$CONTENT_LENGTH")
fi

echo -en "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{}"

if [[ -n "$payload" ]]; then
    /usr/local/bin/bot-daemon "$payload" >/tmp/bot_daemon_error.log 2>&1
fi
