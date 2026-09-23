# WIBUTUNNEL PERFORMANCE AUDIT

## A. HOT PATHS (FREQUENT OPERATIONS)

### 1. **bin/xp - Expiry Check (CRITICAL - runs every 1 min)**
**BOTTLENECK:** O(n) loop with repeated string pattern matching per user
- **CURRENT:** Loops through exp files (n users), checks `[[ " $ACTIVE_USERS " == *" $user "* ]]` per user
- **IMPACT:** 100 users = 100 pattern matches per cycle × 1440 cycles/day = 144k ops/day
- **OPTIMIZATION:** Build associative array once: `declare -A active; for u in $ACTIVE_VLESS; do active[$u]=1; done` → lookup in O(1)
- **EXPECTED GAIN:** 40-60% faster with 100+ users (pattern match slow in bash)

**BOTTLENECK:** Telegram curl spawned per expired user (network I/O)
- **CURRENT:** 10 expired users = 10 background curl processes per cycle
- **IMPACT:** Process spawn overhead + Telegram API rate limits
- **OPTIMIZATION:** Batch notifications: collect all expired users, send single message with list
- **EXPECTED GAIN:** 90% fewer API calls, faster execution, less rate limit risk

**BOTTLENECK:** SSH expiry loop reads /etc/xray/ssh_exp.conf, calls `ssh_user_exists` (spawns `id`) per user
- **CURRENT:** 50 SSH users = 50 `id` command spawns per cycle
- **IMPACT:** 50 × 1440 = 72k process spawns/day
- **OPTIMIZATION:** Pre-load all system users once: `getent passwd | awk -F: '{print $1}' > /tmp/users.cache`, check in-memory
- **EXPECTED GAIN:** 80% faster (avoid repeated process spawns)

---

### 2. **bin/algojo-kuota - Quota Check (CRITICAL - runs every 1 min)**
**BOTTLENECK:** O(n×m) protocol detection loop
- **CURRENT:** For each user with quota limit, calls `db_has` 4 times (vless/vmess/trojan) + `is_xray_user` check
- **IMPACT:** 100 users = 400 awk spawns per cycle × 1440 = 576k spawns/day
- **OPTIMIZATION:** Build protocol map once at start:
  ```bash
  declare -A proto_map
  while IFS=: read -r u _; do proto_map[$u]="VLESS"; done < /etc/xray/vless_exp.conf
  # repeat for vmess/trojan
  # lookup: ${proto_map[$user]}
  ```
- **EXPECTED GAIN:** 95% reduction in file I/O (4 scans → 1 lookup)

**BOTTLENECK:** SSH accounting with iptables per user
- **CURRENT:** Loops through quota DB, runs `iptables -t mangle -C` + `-L -n -v -x` per SSH user
- **IMPACT:** 20 SSH users = 40 iptables calls per cycle
- **OPTIMIZATION:** Get all counters once: `iptables -t mangle -L OUTPUT -n -v -x | awk ...` → parse all at once
- **EXPECTED GAIN:** 50% faster (1 iptables call vs n)

---

### 3. **bin/bot-daemon - format_online_users (MEDIUM - on-demand)**
**BOTTLENECK:** Protocol detection per online user
- **CURRENT:** For each online user, calls `db_has` 4 times + `ssh_user_exists`
- **IMPACT:** 50 online users = 250 file scans per bot command
- **OPTIMIZATION:** Reuse protocol map from algojo-kuota (shared via /tmp or common.sh function)
- **EXPECTED GAIN:** 90% faster response (instant lookup vs file scans)

**BOTTLENECK:** External API calls (ip-api.com)
- **CURRENT:** `get_isp`/`get_city` cached 10min TTL, still hits API 144 times/day minimum
- **IMPACT:** Account creation waits 4 seconds if cache cold (every 10 min)
- **OPTIMIZATION:** Increase cache TTL to 1 hour (IP/ISP rarely changes)
- **EXPECTED GAIN:** 6× fewer API calls, faster account creation

---

## B. RESOURCE LEAKS

### 1. **Background curl processes**
**CURRENT:** Telegram notifications spawn `curl ... &` without wait/cleanup
- **LEAK RISK:** If Telegram API slow/down, processes accumulate
- **FIX:** Add timeout (`--max-time 10` already present) + periodic cleanup: `pkill -f "curl.*telegram" -TERM` if >50 processes
- **EXPECTED GAIN:** Prevent OOM on slow network

### 2. **Temp files accumulation**
**CURRENT:** `/etc/wibutunnel/tmp/` has exp_clean, xray_edit.*.json, bot_offset, etc.
- **IMPACT:** Low (files small) but can accumulate if cleanup skipped
- **FIX:** Add daily cron: `find /etc/wibutunnel/tmp -name "*.tmp" -mtime +1 -delete`
- **EXPECTED GAIN:** Prevent inode exhaustion on long-running systems

### 3. **Zombie processes (NONE FOUND)**
**STATUS:** Scripts use `&` for background jobs but no orphan risk (short-lived curl)

---

## C. SCALABILITY LIMITS

### 1. **Config file bloat (CRITICAL at >500 users)**
**CURRENT:** All users in single `/usr/local/etc/xray/config.json`, jq parses entire file on every edit
- **IMPACT:** 1000 users ≈ 2-5MB config.json, jq takes 2-5 seconds to parse/edit
- **LIMIT:** xp + algojo-kuota both edit config every minute → flock contention
- **OPTIMIZATION:** 
  - Split config: inbounds in separate files, use `#include` (if xray supports) OR
  - Use xray API to add/remove users dynamically (no config edit) OR
  - Batch edits: collect all changes in 1-minute window, single jq pass
- **EXPECTED GAIN:** 10× faster at 1000 users (batch vs per-user edit)

### 2. **Linear scan databases**
**CURRENT:** All .db files flat text, awk scans O(n) per lookup
- **IMPACT:** 1000 users = 1000 lines scanned per `db_has` call
- **OPTIMIZATION:** Use associative arrays (load once at script start) OR sqlite with index
- **EXPECTED GAIN:** O(1) lookup vs O(n), 100× faster with 1000 users

### 3. **Cron job overlap**
**CURRENT:** xp has flock (good), but with 500+ users could run >60 seconds
- **IMPACT:** Next xp cycle skipped (flock fails), delayed expiry enforcement
- **FIX:** Increase flock timeout or split work (process 100 users per cycle, rotate)
- **EXPECTED GAIN:** Prevent skip cycles at high load

---

## D. INSTALLATION PERFORMANCE

### 1. **Multiple apt-get updates (LOW PRIORITY)**
**CURRENT:** 9 `apt-get update` calls in setup.sh (some in functions)
- **IMPACT:** 30-60 seconds wasted fetching same package lists
- **OPTIMIZATION:** Single `apt-get update` at start, remove others
- **EXPECTED GAIN:** 30-45 seconds faster install

### 2. **Sequential package installs**
**CURRENT:** `apt-get install -y pkg1 pkg2 pkg3 ...` (already batched, good)
- **STATUS:** Already optimized (single install line)

### 3. **Large downloads without resume**
**CURRENT:** Xray binary, geoip files downloaded via curl without `-C`
- **IMPACT:** Failed download = restart from 0%
- **OPTIMIZATION:** Add `-C -` to curl commands
- **EXPECTED GAIN:** Faster retry on network interruption

---

## E. SYSTEM RESOURCE USAGE

### 1. **CPU spikes**
**CURRENT:** xray restart after user batch operations
- **IMPACT:** 1-2 second service interruption per restart
- **OPTIMIZATION:** Use xray API to reload config without full restart (if supported)
- **EXPECTED GAIN:** Zero downtime, 5× faster config apply

**CURRENT:** jq parsing large config.json repeatedly
- **IMPACT:** 100% CPU for 1-2 seconds per jq call at 1000 users
- **OPTIMIZATION:** See "Config file bloat" above (batch or split)

### 2. **Memory footprint**
**CURRENT:** bash space-delimited strings (ACTIVE_VLESS, ACTIVE_VMESS) hold all usernames
- **IMPACT:** 1000 users × 20 chars = 20KB per string (acceptable)
- **STATUS:** Not a bottleneck (bash handles this efficiently)

### 3. **Disk I/O**
**CURRENT:** Frequent small writes to .db files (limit_ip.db, user_usage.db, etc.)
- **IMPACT:** 10-20 writes/minute across all scripts
- **OPTIMIZATION:** Batch updates (write once per cycle, not per user)
- **EXPECTED GAIN:** 50% less I/O, longer SSD life

### 4. **Network bandwidth**
**CURRENT:** Telegram API polling + notifications, ip-api.com
- **IMPACT:** ~100KB/day baseline (low)
- **STATUS:** Acceptable (Telegram is primary interface)

---

## PRIORITY MATRIX

| Priority | Bottleneck | Current Perf | Optimized Perf | Gain | Effort |
|----------|-----------|--------------|----------------|------|--------|
| **P0** | Protocol detection O(n×m) | 400 file scans/min | 100 lookups/min | 75% | 1h |
| **P0** | xp pattern matching | 144k ops/day | O(1) assoc array | 60% | 30m |
| **P1** | Batch Telegram notifs | 10 curls/expired batch | 1 curl/batch | 90% | 1h |
| **P1** | Config file bloat >500 users | 5s jq parse | 0.5s batched | 90% | 4h |
| **P2** | ip-api cache TTL | 144 calls/day | 24 calls/day | 83% | 5m |
| **P2** | SSH user exists check | 72k spawns/day | 1.4k (cached) | 98% | 30m |
| **P3** | iptables per-user | 40 calls/min | 1 call/min | 95% | 1h |
| **P3** | apt-get update spam | 9× in setup | 1× | 45s saved | 10m |

---

## RECOMMENDED QUICK WINS (2 hours work, 70% speedup)

1. **Protocol map cache (1h):** Create `/etc/wibutunnel/tmp/proto_map.cache` updated by xp, read by algojo/bot
2. **Associative arrays in xp (30m):** Replace pattern match with `declare -A active`
3. **Batch Telegram (1h):** Collect expired users, send single message
4. **ip-api TTL increase (5m):** Change `WIBU_IP_TTL=3600` in common.sh

**TOTAL EXPECTED GAIN:** 60-75% reduction in CPU/I/O for 100+ users
