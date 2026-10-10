# Bot Migration: Webhook → Polling Mode

**Status:** ✅ Complete | **Date:** 2026-10-10

## Why Migrate?

**Polling advantages over webhook:**
- No port exposure (more secure)
- Works behind firewall/NAT  
- No SSL cert needed for bot
- More reliable for small VPS

## Files Changed

- `bot-telegram-polling.sh` - Long polling script (30s timeout)
- `systemd/telegram-bot-polling.service` - Auto-restart service
- Webhook removed: bot-webhook script, HAProxy /telehook route

## Installation

```bash
cp bot-telegram-polling.sh /usr/local/bin/bot-telegram-polling
chmod +x /usr/local/bin/bot-telegram-polling
cp systemd/telegram-bot-polling.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now telegram-bot-polling
```

## Verification

```bash
systemctl status telegram-bot-polling
tail -f /var/log/telegram-bot.log
# Send /start to bot
```

Performance: ~3MB RAM, <1% CPU, 1-3s latency
