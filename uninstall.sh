#!/bin/bash
# ==========================================
# Script Uninstall WIBU TUNNELING (v4.0 KURUMI)
# [PATCH] Cleanup lengkap semua komponen
# ==========================================

# [C1] Pin + verifikasi instaleler Xray (sama seperti setup.sh). Hash 2026-11-15.
XRAY_INSTALL_URL="${XRAY_INSTALL_URL:-https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh}"
XRAY_INSTALL_SHA256="${XRAY_INSTALL_SHA256:-a562d1287cd7bf2871023d4c81bd9031c56fa132956067ba1de126957cc5fb1c}"
XRAY_TMP=""
xray_tmp_cleanup() { [ -n "$XRAY_TMP" ] && rm -f "$XRAY_TMP"; return 0; }
trap xray_tmp_cleanup EXIT

xray_verify_sha256() {
    local file="$1" want="$2" got
    [ -s "$file" ] || { echo "instaleler kosong/tidak ada: $file" >&2; return 1; }
    got="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
    [ -n "$got" ] || { echo "sha256sum gagal" >&2; return 1; }
    [ "$got" = "$want" ] || { echo "HASH TIDAK COCOK (dapat=$got harap=$want)" >&2; return 1; }
    return 0
}

echo -e "\e[33mMemulai proses uninstall WIBU TUNNELING...\e[0m"

# Hentikan semua layanan
systemctl stop xray haproxy wibu-daemon network-tune ws-stunnel dropbear 2>/dev/null
systemctl disable xray haproxy wibu-daemon network-tune ws-stunnel dropbear 2>/dev/null
systemctl stop telegram-bot.service algojo-expired.service 2>/dev/null
systemctl disable telegram-bot.service algojo-expired.service 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null
systemctl stop wibutunnel-firewall.service wibutunnel-firewall.timer 2>/dev/null
systemctl disable wibutunnel-firewall.service wibutunnel-firewall.timer 2>/dev/null

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
    # [C1] Uninstaller resmi HANYA dijalankan setelah hash cocok (tanpa verifikasi = risiko RCE).
    XRAY_TMP="$(mktemp /tmp/xray-uninstall.XXXXXX.sh)" || XRAY_TMP=""
    if [ -n "$XRAY_TMP" ] && curl -4 -fSL --retry 3 --connect-timeout 10 --max-time 90 -o "$XRAY_TMP" "$XRAY_INSTALL_URL" \
        && xray_verify_sha256 "$XRAY_TMP" "$XRAY_INSTALL_SHA256"; then
        bash "$XRAY_TMP" remove >/dev/null 2>&1   # [FIX] bentuk berkas, bukan "-s --"
    else
        echo -e "\e[33m[ABORT] Unduh/verifikasi instaleler Xray gagal - uninstaller resmi DILEWATI, lanjut pembersihan manual.\e[0m"
    fi
fi
rm -rf /usr/local/share/xray /usr/local/bin/xray /etc/tmpfiles.d/xray.conf
rm -f /usr/lib/systemd/system/xray.service /usr/lib/systemd/system/xray@.service
id -u xray >/dev/null 2>&1 && userdel xray >/dev/null 2>&1
id -g xray >/dev/null 2>&1 && groupdel xray >/dev/null 2>&1

# Kembalikan iptables ke kondisi bersih
if command -v iptables >/dev/null 2>&1; then
    # [C2] Hapus HANYA aturan owner-match milik wibutunnel (cocokkan pola),
    # jangan flush seluruh firewall.
    for p in 10085; do
        while iptables -C OUTPUT -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT 2>/dev/null; do
            iptables -D OUTPUT -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT 2>/dev/null || break
        done
    done
    iptables -t mangle -F 2>/dev/null
    iptables -t mangle -X 2>/dev/null
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
fi
systemctl disable netfilter-persistent >/dev/null 2>&1

# Hapus file executable menu & daemon
# [FIX] Daftar hapus lengkap: sebelumnya algojo-ssh, lock-user, unlock-user, ws-stunnel & wibu-daemon
# tertinggal di /usr/local/sbin|bin setelah uninstall.
# [FIX v4.1.30] wibu-kuota & wibu-udpgw ikut dipasang setup.sh tetapi dulu tidak ada di daftar ini:
# keduanya tertinggal di /usr/local/{bin,sbin} setelah uninstall (terukur di VPS uji).
for _f in algojo-wibu algojo-kuota algojo-ssh algojo-expired algojo-expired-daemon lock-user unlock-user \
          unlocker-wibu ws-stunnel wibu-daemon wibu-repair wibu-audit-akun wibu-ssl-ulang wibu-isp wibutunnel-firewall \
          wibutunnel-firewall.sh network-tune network-tune.sh wibu-kuota wibu-udpgw; do
    rm -f "/usr/local/sbin/$_f" "/usr/local/bin/$_f" 2>/dev/null
done
rm -f /usr/local/bin/algojo-expired-daemon
rm -f /usr/local/sbin/network-tune /usr/local/sbin/network-tune.sh /usr/local/bin/network-tune /usr/local/bin/network-tune.sh /usr/local/sbin/wibu-repair /usr/local/sbin/wibu-audit-akun /usr/local/bin/wibu-audit-akun
systemctl disable --now wibutunnel-ssl-ulang.timer >/dev/null 2>&1
rm -f /etc/systemd/system/wibutunnel-ssl-ulang.service /etc/systemd/system/wibutunnel-ssl-ulang.timer
rm -f /usr/local/bin/menu /usr/local/bin/m-vless /usr/local/bin/m-vmess /usr/local/bin/m-trojan /usr/local/bin/m-ssh
rm -f /usr/local/bin/m-setting /usr/local/bin/m-backup /usr/local/bin/menu-lock /usr/local/bin/menu-unlock
rm -f /usr/local/bin/menu-recovery /usr/local/bin/cek-trafik /usr/local/bin/xp
rm -f /usr/local/bin/lock-user /usr/local/bin/unlock-user
rm -f /usr/local/bin/bot-daemon
rm -f /usr/local/bin/wibu-daemon /usr/local/bin/watchdog.sh /usr/local/bin/renew-cert-wibu.sh
rm -f /usr/local/bin/ws-stunnel /usr/local/sbin/ws-stunnel
rm -f /usr/local/bin/common.sh /usr/local/bin/common.sh.bak* /usr/local/bin/common.sh.before-lib-split

# Bersihkan Cron Jobs bawaan Wibu Tunneling
crontab -l 2>/dev/null | grep -v -E 'watchdog\.sh|/usr/local/bin/xp|unlocker-wibu|renew-cert-wibu|algojo|m-backup|drop_caches.*swapon|/sbin/reboot' | crontab -

# Hapus service systemd
rm -f /etc/systemd/system/wibu-daemon.service
rm -f /etc/systemd/system/telegram-bot.service
rm -f /etc/wibutunnel/bot_off
rm -f /etc/systemd/system/algojo-expired.service
rm -f /etc/systemd/system/network-tune.service
rm -f /etc/systemd/system/ws-stunnel.service
rm -f /etc/systemd/system/dropbear.service
rm -f /etc/systemd/system/telegram-webhook.socket
rm -f /etc/systemd/system/telegram-webhook@.service
rm -rf /etc/systemd/system/haproxy.service.d
rm -rf /etc/systemd/system/xray.service.d
rm -f /etc/systemd/system/wibutunnel-bot.service /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
rm -f /etc/systemd/system/wibutunnel-firewall.service /etc/systemd/system/wibutunnel-firewall.timer
rm -f /usr/local/sbin/wibutunnel-firewall /usr/local/sbin/wibutunnel-firewall.sh /usr/local/bin/wibutunnel-firewall /usr/local/bin/wibutunnel-firewall.sh

# [FIX v4.1.30] UDPGW: unit templated badvpn-udpgw@ + biner hasil build + proses yang masih hidup.
# Tanpa blok ini uninstall meninggalkan 6 proses yang tetap mendengarkan 127.0.0.1:7100-7600.
for _u in $(systemctl list-units --all --no-legend 'badvpn-udpgw@*' 2>/dev/null | awk '{print $1}'); do
    systemctl stop "$_u" >/dev/null 2>&1 || true
done
systemctl disable badvpn-udpgw@.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/badvpn-udpgw@.service
pkill -f 'badvpn-udpgw' >/dev/null 2>&1 || true
rm -f /usr/sbin/badvpn-udpgw /usr/local/sbin/badvpn-udpgw /usr/local/bin/badvpn-udpgw
rm -rf /usr/local/src/badvpn-src
systemctl daemon-reload

# Hapus logrotate
rm -f /etc/logrotate.d/xray

# Bersihkan .profile
[ -f /root/.profile ] && [ ! -f /root/.profile.wibutunnel.bak ] && cp -a /root/.profile /root/.profile.wibutunnel.bak
sed -i '/Auto-start menu/d; /^clear$/d; /^menu$/d' /root/.profile 2>/dev/null

# Bersihkan fstab entries
[ -f /etc/fstab ] && [ ! -f /etc/fstab.wibutunnel.bak ] && cp -a /etc/fstab /etc/fstab.wibutunnel.bak
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

# [FIX] Bersihkan rujukan banner wibutunnel di konfigurasi dropbear SEBELUM purge.
# Tanpa ini instalasi ULANG gagal: dpkg --configure dropbear mencari banner yang sudah dihapus
# (/etc/wibutunnel/ssh-banner) -> apt-get install mengembalikan error -> instalasi berhenti.
if [[ -f /etc/default/dropbear ]] && grep -q 'wibutunnel' /etc/default/dropbear 2>/dev/null; then
    sed -i '/^DROPBEAR_BANNER=.*wibutunnel/d' /etc/default/dropbear
    echo -e "\e[33m[i] rujukan banner wibutunnel dihapus dari /etc/default/dropbear\e[0m"
fi

# Uninstall paket bawaan (opsional)
apt-get remove --purge -y haproxy vnstat dropbear >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "\e[32mUninstalasi Selesai! VPS sudah bersih dari WIBU TUNNELING.\e[0m"
