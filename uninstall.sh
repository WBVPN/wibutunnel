#!/bin/bash
# ==========================================
# Script Uninstall WIBU TUNNELING (v4.0 KURUMI)
# [PATCH] Cleanup lengkap semua komponen
# ==========================================

echo -e "\e[33mMemulai proses uninstall WIBU TUNNELING...\e[0m"

# Hentikan semua layanan
systemctl stop xray haproxy wibu-daemon 2>/dev/null
systemctl disable xray haproxy wibu-daemon 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null

# Hapus file konfigurasi dan database
umount -f /var/log/xray 2>/dev/null
rm -rf /usr/local/etc/xray /etc/haproxy /etc/wibutunnel /etc/xray /var/log/xray

# Hapus file executable menu & daemon
rm -f /usr/local/sbin/algojo-wibu /usr/local/sbin/algojo-kuota /usr/local/sbin/unlocker-wibu
rm -f /usr/local/bin/menu /usr/local/bin/m-vless /usr/local/bin/m-vmess /usr/local/bin/m-trojan
rm -f /usr/local/bin/m-setting /usr/local/bin/m-backup /usr/local/bin/menu-lock /usr/local/bin/menu-unlock
rm -f /usr/local/bin/menu-recovery /usr/local/bin/cek-trafik /usr/local/bin/xp
rm -f /usr/local/bin/lock-user /usr/local/bin/unlock-user
rm -f /usr/local/bin/bot-daemon /usr/local/bin/bot-webhook
rm -f /usr/local/bin/wibu-daemon /usr/local/bin/watchdog.sh /usr/local/bin/renew-cert-wibu.sh
rm -f /usr/local/bin/common.sh

# Bersihkan Cron Jobs bawaan Wibu Tunneling
crontab -l 2>/dev/null | grep -v -E 'watchdog\.sh|/usr/local/bin/xp|unlocker-wibu|renew-cert-wibu|algojo|drop_caches.*swapon|/sbin/reboot' | crontab -

# Hapus service systemd
rm -f /etc/systemd/system/wibu-daemon.service
rm -f /etc/systemd/system/telegram-webhook.socket
rm -f /etc/systemd/system/telegram-webhook@.service
rm -rf /etc/systemd/system/haproxy.service.d
rm -rf /etc/systemd/system/xray.service.d
rm -f /etc/systemd/system/wibutunnel-bot.service /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
systemctl daemon-reload

# Hapus logrotate
rm -f /etc/logrotate.d/xray

# Bersihkan .profile
sed -i '/^clear$/d; /^menu$/d' /root/.profile 2>/dev/null
sed -i '/\/var\/log\/xray/d' /etc/fstab 2>/dev/null

# Uninstall paket bawaan (opsional)
apt-get remove --purge -y haproxy vnstat jq >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "\e[32mUninstalasi Selesai! VPS sudah bersih dari WIBU TUNNELING.\e[0m"
