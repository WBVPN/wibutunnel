#!/bin/bash
# ==========================================
# WIBU TUNNELING - xp.sh (v4.0 KURUMI)
# Daily Maintenance: Log truncation, tmp cleanup, exp dedup, safety-net sweep
# ==========================================

source /usr/local/bin/common.sh 2>/dev/null || exit 1
check_license_silent

mkdir -p /etc/wibutunnel/tmp 2>/dev/null
exec 200>/etc/wibutunnel/tmp/xp.lock
flock -n 200 || exit 0

# 1. Truncate Xray & Bot logs if size exceeded to prevent disk full
for log_file in /var/log/xray/access.log /var/log/xray/error.log; do
    if [[ -f "$log_file" ]] && [[ $(stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 52428800 ]]; then
        > "$log_file"
    fi
done
if [[ -f /etc/wibutunnel/tmp/bot_error.log ]] && [[ $(stat -c%s /etc/wibutunnel/tmp/bot_error.log 2>/dev/null || echo 0) -gt 2097152 ]]; then
    > /etc/wibutunnel/tmp/bot_error.log
fi

# 2. Clean temporary files older than 1 hour in /etc/wibutunnel/tmp
find /etc/wibutunnel/tmp -type f \( -name "*.tmp.*" -o -name "xray_adu.*" \) -mmin +60 -delete 2>/dev/null || true

# 3. Deduplicate entries in expiry files
for exp_file in /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf /etc/xray/ssh_exp.conf; do
    [[ -f "$exp_file" ]] || continue
    tmp_clean="${exp_file}.dedup.$$"
    if awk '!seen[$0]++' "$exp_file" > "$tmp_clean"; then
        mv "$tmp_clean" "$exp_file"
    else
        rm -f "$tmp_clean"
    fi
done

# 4. Safety net sweep for expired accounts
# ponytail: algojo-expired-daemon handles real-time expiry (5s). xp.sh runs once daily at 00:00 as safety net.
if [[ -x /usr/local/sbin/algojo-expired ]]; then
    /usr/local/sbin/algojo-expired >/dev/null 2>&1
fi
