#!/bin/bash
# WIBUTUNNEL TELEGRAM BOT - POLLING MODE v4.1
# Migrated from webhook to polling for better reliability

BOT_CONF="/etc/wibutunnel/bot.conf"
OFFSET_FILE="/etc/wibutunnel/tmp/bot_offset"

# Load config
[[ ! -f "$BOT_CONF" ]] && { echo "Bot config not found"; exit 1; }
source "$BOT_CONF"
[[ -z "$BOT_TOKEN" ]] && { echo "BOT_TOKEN not set"; exit 1; }

mkdir -p /etc/wibutunnel/tmp
OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")

echo "[$(date)] Bot polling started, offset: $OFFSET"

# Polling loop
while true; do
    RESPONSE=$(curl -s --max-time 35 "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")
    
    # Check response valid
    if ! echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
        sleep 5
        continue
    fi
    
    # Process each update
    echo "$RESPONSE" | jq -c '.result[]?' 2>/dev/null | while read -r update; do
        [[ -z "$update" ]] && continue
        
        # Update offset
        UPDATE_ID=$(echo "$update" | jq -r '.update_id')
        if [[ -n "$UPDATE_ID" && "$UPDATE_ID" != "null" ]]; then
            echo "$((UPDATE_ID + 1))" > "$OFFSET_FILE"
        fi
        
        # Process update via bot-daemon in background
        /usr/local/bin/bot-daemon "$update" &
    done
    
    # Re-read offset
    OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "$OFFSET")
    sleep 0.1
done
