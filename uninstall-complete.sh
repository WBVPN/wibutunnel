#!/bin/bash
# ==========================================
# Complete Uninstall WIBU TUNNELING v4.0
# VPS akan kembali seperti fresh install
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  COMPLETE UNINSTALL - WIBU TUNNELING v4.0${NC}"
echo -e "${YELLOW}  VPS akan dikembalikan seperti kondisi awal${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo -e "${RED}WARNING: Ini akan menghapus:${NC}"
echo "  - Semua service (xray, haproxy, dropbear)"
echo "  - Semua config & database"
echo "  - Semua user accounts"
echo "  - SSL certificates"
echo "  - Cron jobs"
echo "  - Packages yang terinstall"
echo "  - Source files & backups"
echo ""
read -p "Lanjutkan? (ketik: YES untuk konfirmasi): " confirm
if [ "$confirm" != "YES" ]; then
    echo -e "${YELLOW}Dibatalkan.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}[1/10] Stopping all services...${NC}"
systemctl stop xray haproxy dropbear cron wibu-daemon 2>/dev/null
systemctl stop telegram-webhook.socket telegram-webhook@*.service 2>/dev/null
systemctl stop wibutunnel-bot 2>/dev/null
killall -9 xray haproxy dropbear bot-daemon 2>/dev/null
sleep 2

echo -e "${GREEN}[2/10] Disabling services...${NC}"
systemctl disable xray haproxy dropbear wibu-daemon 2>/dev/null
systemctl disable telegram-webhook.socket wibutunnel-bot 2>/dev/null

echo -e "${GREEN}[3/10] Removing systemd service files...${NC}"
rm -f /etc/systemd/system/wibu-daemon.service
rm -f /etc/systemd/system/telegram-webhook.socket
rm -f /etc/systemd/system/telegram-webhook@.service
rm -f /etc/systemd/system/wibutunnel-bot.service
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/xray@.service
rm -rf /etc/systemd/system/haproxy.service.d
rm -rf /etc/systemd/system/xray.service.d
rm -rf /etc/systemd/system/dropbear.service.d
systemctl daemon-reload

echo -e "${GREEN}[4/10] Removing configuration directories...${NC}"
umount -f /var/log/xray 2>/dev/null
rm -rf /usr/local/etc/xray
rm -rf /etc/haproxy
rm -rf /etc/wibutunnel
rm -rf /etc/xray
rm -rf /var/log/xray
rm -rf /var/log/haproxy
rm -rf /var/log/wibu-backup.log

echo -e "${GREEN}[5/10] Removing executables & scripts...${NC}"
# Sbin executables
rm -f /usr/local/sbin/algojo-wibu
rm -f /usr/local/sbin/algojo-kuota
rm -f /usr/local/sbin/unlocker-wibu
rm -f /usr/local/sbin/lock-user
rm -f /usr/local/sbin/unlock-user

# Bin executables
rm -f /usr/local/bin/xray
rm -f /usr/local/bin/menu
rm -f /usr/local/bin/m-vless
rm -f /usr/local/bin/m-vmess
rm -f /usr/local/bin/m-trojan
rm -f /usr/local/bin/m-setting
rm -f /usr/local/bin/m-backup
rm -f /usr/local/bin/menu-lock
rm -f /usr/local/bin/menu-unlock
rm -f /usr/local/bin/menu-recovery
rm -f /usr/local/bin/cek-trafik
rm -f /usr/local/bin/xp
rm -f /usr/local/bin/bot-daemon
rm -f /usr/local/bin/bot-telegram
rm -f /usr/local/bin/bot-webhook
rm -f /usr/local/bin/wibu-daemon
rm -f /usr/local/bin/watchdog.sh
rm -f /usr/local/bin/renew-cert-wibu.sh
rm -f /usr/local/bin/common.sh
rm -f /usr/local/bin/ganti-token
rm -f /usr/local/bin/bot-daemon
rm -f /usr/bin/speedtest

echo -e "${GREEN}[6/10] Cleaning ALL cron jobs...${NC}"
# Backup crontab dulu
crontab -l > /tmp/crontab_backup_$(date +%s).txt 2>/dev/null
# Hapus semua cron (reset to empty)
crontab -r 2>/dev/null
echo "Original crontab backed up to /tmp/crontab_backup_*.txt"

echo -e "${GREEN}[7/10] Removing SSL certificates...${NC}"
rm -rf /etc/letsencrypt
rm -rf /var/lib/letsencrypt
rm -rf /var/log/letsencrypt

echo -e "${GREEN}[8/10] Uninstalling packages...${NC}"
apt-get remove --purge -y xray haproxy dropbear certbot vnstat speedtest-cli >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1
apt-get clean

echo -e "${GREEN}[9/10] Removing source files & backups...${NC}"
rm -rf /root/wibutunnel*
rm -rf /root/script_backup_*
rm -rf /root/backup-test
rm -rf /etc/wibutunnel/tmp/*

echo -e "${GREEN}[10/10] Cleaning system configurations...${NC}"
# Remove auto-menu dari .bashrc
sed -i '/^exec menu$/d' /root/.bashrc 2>/dev/null
sed -i '/^menu$/d' /root/.bashrc 2>/dev/null
sed -i '/wibutunnel/d' /root/.bashrc 2>/dev/null

# Remove dari .profile
sed -i '/^clear$/d; /^menu$/d' /root/.profile 2>/dev/null
sed -i '/wibutunnel/d' /root/.profile 2>/dev/null

# Remove fstab entry
sed -i '/\/var\/log\/xray/d' /etc/fstab 2>/dev/null

# Remove logrotate
rm -f /etc/logrotate.d/xray

# Remove user accounts (jika ada)
userdel -r xray 2>/dev/null
userdel -r wibu 2>/dev/null

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  UNINSTALL COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "Cleaned:"
echo "  ✓ All services stopped & disabled"
echo "  ✓ All configuration files removed"
echo "  ✓ All executables & scripts removed"
echo "  ✓ All cron jobs cleared (backup: /tmp/crontab_backup_*.txt)"
echo "  ✓ SSL certificates removed"
echo "  ✓ Packages uninstalled (xray, haproxy, dropbear, certbot)"
echo "  ✓ Source files & backups removed"
echo "  ✓ System configs cleaned (.bashrc, .profile, fstab)"
echo ""
echo -e "${YELLOW}Reboot recommended:${NC} ${GREEN}reboot${NC}"
echo ""
echo -e "${RED}Note: SSH mungkin terputus jika dropbear port dipakai!${NC}"
echo -e "${RED}Pastikan OpenSSH (port 22) masih aktif sebelum reboot.${NC}"
