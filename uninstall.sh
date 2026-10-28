#!/bin/bash
# ==========================================
# Script Uninstall WIBU TUNNELING (v4.0 KURUMI)
# [PATCH] Cleanup lengkap semua komponen
# ==========================================

echo -e "\e[33mMemulai proses uninstall WIBU TUNNELING...\e[0m"

# Hentikan semua layanan
systemctl stop xray haproxy wibu-daemon network-tune 2>/dev/null
systemctl disable xray haproxy wibu-daemon network-tune 2>/dev/null
systemctl stop telegram-bot.service algojo-expired.service 2>/dev/null
systemctl disable telegram-bot.service algojo-expired.service 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null

# Backup SEMUA data user sebelum dihapus. Gagal backup = batalkan uninstall.
SAVED="/root/wibutunnel-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SAVED" || { echo -e "\e[31m[!] Gagal buat $SAVED, uninstall dibatalkan.\e[0m"; exit 1; }
BACKUP_PATHS=()
for p in /etc/xray /etc/wibutunnel /usr/local/etc/xray /etc/haproxy /etc/iptables; do
    [ -e "$p" ] && BACKUP_PATHS+=("$p")
done
if [ ${#BACKUP_PATHS[@]} -gt 0 ]; then
    tar -czf "$SAVED/data.tar.gz" "${BACKUP_PATHS[@]}" 2>/dev/null || {
        echo -e "\e[31m[!] Backup gagal, uninstall dibatalkan. Cek disk/permission.\e[0m"; exit 1; }
    echo -e "\e[33m[!] Backup data disimpan di $SAVED/data.tar.gz\e[0m"
else
    echo -e "\e[33m[!] Tidak ada data untuk dibackup.\e[0m"
fi

# Hapus file konfigurasi dan database
umount -f /var/log/xray 2>/dev/null
rm -rf /usr/local/etc/xray /etc/haproxy /etc/wibutunnel /etc/xray /var/log/xray

# Uninstall Xray core (dipasang setup.sh via install-release.sh)
if command -v xray >/dev/null 2>&1; then
    curl -sS -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh | bash -s -- remove >/dev/null 2>&1
fi
rm -rf /usr/local/share/xray /usr/local/bin/xray /etc/tmpfiles.d/xray.conf
rm -f /usr/lib/systemd/system/xray.service /usr/lib/systemd/system/xray@.service
id -u xray >/dev/null 2>&1 && userdel xray >/dev/null 2>&1
id -g xray >/dev/null 2>&1 && groupdel xray >/dev/null 2>&1

# Kembalikan iptables ke kondisi bersih
if command -v iptables >/dev/null 2>&1; then
    iptables -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -t mangle -X 2>/dev/null
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
fi
systemctl disable netfilter-persistent >/dev/null 2>&1

# Hapus file executable menu & daemon
rm -f /usr/local/sbin/algojo-wibu /usr/local/sbin/algojo-kuota /usr/local/sbin/unlocker-wibu /usr/local/sbin/algojo-expired
rm -f /usr/local/bin/algojo-expired-daemon
rm -f /usr/local/sbin/network-tune.sh
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
rm -f /etc/systemd/system/telegram-bot.service
rm -f /etc/systemd/system/algojo-expired.service
rm -f /etc/systemd/system/network-tune.service
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

# Bersihkan fstab entries
sed -i '/\/var\/log\/xray/d' /etc/fstab 2>/dev/null
sed -i '/\/swapfile none swap sw 0 0/d' /etc/fstab 2>/dev/null
sed -i '/tmpfs \/tmp tmpfs/d' /etc/fstab 2>/dev/null

# Hapus swapfile
swapoff /swapfile 2>/dev/null
rm -f /swapfile

# Revert sysctl modifications (commented out by default - uncomment to revert network optimizations)
# sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
# sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
# sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
# sed -i '/net.ipv4.tcp_/d' /etc/sysctl.conf
# sed -i '/net.core./d' /etc/sysctl.conf
# sysctl -p 2>/dev/null

# Note: iptables rules persist in /etc/iptables/rules.v4
# Run 'iptables -F && netfilter-persistent save' to reset if needed

# Uninstall paket bawaan (opsional)
apt-get remove --purge -y haproxy vnstat >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "\e[32mUninstalasi Selesai! VPS sudah bersih dari WIBU TUNNELING.\e[0m"
