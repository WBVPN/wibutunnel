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

# Validasi secret token — FAIL CLOSED.
# Kalau secret belum dikonfigurasi, tolak SEMUA request (siapa pun tidak boleh
# mengendalikan bot tanpa otentikasi).
if [[ -z "$WEBHOOK_SECRET" ]]; then
    echo -e "[SECURITY] WEBHOOK_SECRET belum dikonfigurasi di /etc/wibutunnel/bot.conf — request ditolak" >&2
    echo -en "HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{\"error\":\"webhook secret not configured\"}"
    exit 0
fi
if [[ "$SECRET_HEADER" != "$WEBHOOK_SECRET" ]]; then
    echo -e "[SECURITY] Webhook secret token tidak valid — request ditolak" >&2
    echo -en "HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{\"error\":\"unauthorized\"}"
    exit 0
fi

payload=""
if [[ -n "$CONTENT_LENGTH" ]]; then
    payload=$(head -c "$CONTENT_LENGTH")
fi

echo -en "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{}"

if [[ -n "$payload" ]]; then
    /usr/local/bin/bot-daemon "$payload" >/tmp/bot_daemon_error.log 2>&1
fi
