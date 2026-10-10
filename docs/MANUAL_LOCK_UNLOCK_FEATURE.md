# Manual Lock/Unlock Feature

## Overview
Fitur manual lock/unlock per protocol (VLESS, VMESS, TROJAN) untuk mengontrol akses user via bot Telegram.

## Features

### 1. Username Uniqueness Enforcement
- Prevents duplicate usernames across protocols
- Validation: `check_username_exists()` checks vless_exp.conf, vmess_exp.conf, trojan_exp.conf
- Error message: "Username sudah digunakan di protocol lain"

### 2. Manual Lock
- Function: `lock_user_manual(proto, username)`
- Lock type: MANUAL_LOCK (permanent, unlock_timestamp=0)
- Actions: Add to locked_users.db, block in xray routing, restart xray
- Bandwidth tracking continues during lock
- Telegram notification sent

### 3. Manual Unlock
- Function: `unlock_user_manual(proto, username)`  
- Actions: Remove from locked_users.db, remove from xray routing, restart xray
- Bandwidth history PRESERVED (not reset)
- Telegram notification sent

### 4. Auto-Unlock Prevention
- unlocker-wibu skips MANUAL_LOCK entries (unlock_timestamp=0)
- Only IP_LIMIT (temporary) locks auto-unlock

## Bot Menu
Each protocol menu (VLESS/VMESS/TROJAN) now includes:
- 🔒 Lock User (new)
- 🔓 Unlock User (new)

## Usage
1. Select protocol menu
2. Click Lock/Unlock button
3. Enter username
4. Confirmation message displayed

## Technical Details
- Database format: `username:timestamp:unlock_timestamp:LOCK_TYPE`
- MANUAL_LOCK example: `budi:1791634065:0:MANUAL_LOCK`
- Files modified: /usr/local/bin/bot-daemon

## Testing
All tests passed (6/6):
- Username uniqueness ✓
- Lock function ✓  
- Unlock function ✓
- Auto-unlock prevention ✓
- All protocols (VLESS/VMESS/TROJAN) ✓
- Bandwidth tracking ✓

Test date: 2026-10-10
