#!/bin/bash
# ==========================================
# Script Uninstall WIBU TUNNELING (v4.0 KURUMI)
# [PATCH] Cleanup lengkap: service, fstab, swap, limits, log, cron
# ==========================================

echo -e "\e[33mMemulai proses uninstall WIBU TUNNELING...\e[0m"

# Hentikan semua layanan
systemctl stop xray haproxy wibu-daemon network-tune 2>/dev/null
systemctl disable xray haproxy wibu-daemon network-tune 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null

# Lepaskan webhook Telegram (jika bot dikonfigurasi)
if [[ -f /etc/wibutunnel/bot.conf ]]; then
    BOT_TOKEN=$(grep -E "^[[:space:]]*BOT_TOKEN[[:space:]]*=" /etc/wibutunnel/bot.conf 2>/dev/null | head -1 | sed -E "s/^[^=]*=[[:space:]]*//; s/^'//; s/'$//; s/^\"//; s/\"$//")
    if [[ -n "$BOT_TOKEN" ]]; then
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook" >/dev/null 2>&1
    fi
fi

# Lepaskan tmpfs /var/log/xray sebelum menghapus
umount -f /var/log/xray 2>/dev/null

# Hapus file konfigurasi dan database
rm -rf /usr/local/etc/xray /etc/haproxy /etc/wibutunnel /etc/xray /var/log/xray \
       /usr/local/share/xray
# binary xray juga dihapus: installer XTLS mendeteksinya dan akan
# MELEWATI pembuatan service ('No new version') saat reinstall.
rm -f /usr/local/bin/xray

# [SSH TUNNEL] Hentikan & bersihkan stack SSH (dropbear 2019 + ws-stunnel + udpgw)
systemctl stop dropbear ws-stunnel 2>/dev/null
systemctl disable dropbear ws-stunnel 2>/dev/null
rm -f /etc/systemd/system/dropbear.service /etc/systemd/system/ws-stunnel.service
systemctl stop badvpn-udpgw@*.service 2>/dev/null
systemctl disable badvpn-udpgw@*.service 2>/dev/null
rm -f /etc/systemd/system/badvpn-udpgw@.service
# Lepaskan kembali port 80 ke nginx/apache bila sebelumnya dipakai
[[ -x /usr/sbin/nginx ]] && { systemctl enable nginx >/dev/null 2>&1; systemctl start nginx >/dev/null 2>&1; }
# Bersihkan rule akunting iptables milik wibu
if command -v iptables >/dev/null 2>&1; then
    iptables -t mangle -S 2>/dev/null | grep -o 'owner --uid-owner [0-9]*' | while read -r _ _ uid; do
        iptables -t mangle -D OUTPUT -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null
        iptables -t mangle -D INPUT  -m owner --uid-owner "$uid" -j ACCEPT 2>/dev/null
    done
fi
# Kembalikan binary dropbear paket bila ada cadangannya
if [[ -f /usr/sbin/dropbear.orig ]]; then
    mv -f /usr/sbin/dropbear.orig /usr/sbin/dropbear
fi
rm -f /usr/local/bin/ws-stunnel /usr/local/bin/ssh-tunnel-install
rm -f /etc/nginx/conf.d/ssh-ws.conf /etc/nginx/conf.d/map-upgrade.conf 2>/dev/null
systemctl daemon-reload

# Hapus file executable menu & daemon
rm -f /usr/local/sbin/algojo-wibu /usr/local/sbin/algojo-kuota /usr/local/sbin/unlocker-wibu
rm -f /usr/local/sbin/network-tune.sh
rm -f /etc/sysctl.d/99-wibutune.conf
rm -f /usr/local/bin/menu /usr/local/bin/m-vless /usr/local/bin/m-vmess /usr/local/bin/m-trojan
rm -f /usr/local/bin/m-setting /usr/local/bin/m-backup /usr/local/bin/menu-lock /usr/local/bin/menu-unlock
rm -f /usr/local/bin/menu-recovery /usr/local/bin/cek-trafik /usr/local/bin/xp
rm -f /usr/local/bin/lock-user /usr/local/bin/unlock-user
rm -f /usr/local/bin/bot-daemon /usr/local/bin/bot-webhook
rm -f /usr/local/bin/m-ssh /usr/local/bin/ws-stunnel /usr/local/bin/ssh-tunnel-install
rm -f /usr/local/bin/wibu-daemon /usr/local/bin/watchdog.sh /usr/local/bin/renew-cert-wibu.sh
rm -f /usr/local/bin/common.sh /usr/local/bin/common

# [PATCH] Matikan & hapus swapfile yang dibuat installer
if swapon --show 2>/dev/null | grep -q "/swapfile"; then
    swapoff /swapfile 2>/dev/null
fi
rm -f /swapfile

# [PATCH] Bersihkan entry fstab bawaan installer (tmpfs & swap)
if [ -f /etc/fstab ]; then
    cp /etc/fstab /etc/fstab.wibu.bak 2>/dev/null
    sed -i '/tmpfs \/tmp tmpfs/d; /tmpfs \/var\/log\/xray tmpfs/d; /^\/swapfile[[:space:]]/d' /etc/fstab
fi

# [PATCH] Restore /etc/security/limits.conf dari backup installer (jika ada)
if [ -f /etc/security/limits.conf.wibu.bak ]; then
    mv /etc/security/limits.conf.wibu.bak /etc/security/limits.conf
fi

# Bersihkan Cron Jobs bawaan Wibu Tunneling
crontab -l 2>/dev/null | grep -v -E 'watchdog\.sh|/usr/local/bin/xp|unlocker-wibu|renew-cert-wibu|algojo|drop_caches.*swapon|/sbin/reboot|m-backup' | crontab -

# Hapus service systemd
rm -f /etc/systemd/system/wibu-daemon.service
rm -f /etc/systemd/system/telegram-webhook.socket
rm -f /etc/systemd/system/telegram-webhook@.service
rm -f /etc/systemd/system/network-tune.service
rm -rf /etc/systemd/system/haproxy.service.d
rm -rf /etc/systemd/system/xray.service.d
rm -f /etc/systemd/system/wibutunnel-bot.service /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
systemctl daemon-reload

# Hapus logrotate
rm -f /etc/logrotate.d/xray

# [PATCH] Hapus binary hasil compile + source tree SSH stack (benar-bersih)
rm -f /usr/sbin/dropbear /usr/sbin/badvpn-udpgw
rm -rf /usr/local/src/dropbear-2019.78 /usr/local/src/dropbear-2019.78.tar.bz2 /usr/local/src/badvpn-src
rm -f /var/log/wibutunnel-udpgw-build.log /var/log/wibu-backup.log
# [PATCH] Reset state failed unit yang tersisa di systemd
systemctl reset-failed dropbear ws-stunnel 'badvpn-udpgw@*' 2>/dev/null
systemctl daemon-reload

# Bersihkan .profile & sisipan lain
sed -i '/^clear$/d; /^menu$/d' /root/.profile 2>/dev/null
rm -f /root/domain 2>/dev/null

# Uninstall paket bawaan (opsional)
apt-get remove --purge -y haproxy vnstat jq >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

# [PATCH] Hapus direktori config terakhir (tmp & sisa file)
rm -rf /etc/wibutunnel

echo -e "\e[32mUninstalasi Selesai! VPS sudah bersih dari WIBU TUNNELING.\e[0m"
echo -e "\e[33mCatatan: tuning kernel (BBR, buffer, nonaktifkan IPv6) dan\e[0m"
echo -e "\e[33m          parameter GRUB (ipv6.disable=1) sengaja tidak diubah karena\e[0m"
echo -e "\e[33m          bersifat tuning sistem dan tidak mengganggu operasional VPS.\e[0m"
