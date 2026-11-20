#!/bin/bash
# ==========================================
# Script Uninstall WIBU TUNNELING (v4.0 KURUMI)
# [PATCH] Cleanup lengkap semua komponen
# ==========================================

# [C1] Pin + verifikasi instaleler Xray (sama seperti setup.sh). Hash 2026-11-15.
XRAY_INSTALL_URL="${XRAY_INSTALL_URL:-https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh}"
XRAY_INSTALL_SHA256="${XRAY_INSTALL_SHA256:-91fd40e9b6f222b5819f3ba91f0bfb4bb8c4d425a7c0ffe9d8b155d25ed79609}"
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

# ---------------------------------------------------------------- tampilan
C_INFO=$'\e[1;36m'; C_OK=$'\e[1;32m'; C_WARN=$'\e[1;33m'; C_ERR=$'\e[1;31m'
C_DIM=$'\e[2m'; C_OFF=$'\e[0m'
LINE="──────────────────────────────────────────────────────"
step() { printf '\n %s[%s]%s %s\n' "$C_INFO" "$1" "$C_OFF" "$2"; }
ok()   { printf '        %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
info() { printf '        %s·%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
warn() { printf '        %s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
fail() { printf '        %s✗%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }

PANEL_DOMAIN="$(cat /etc/xray/domain 2>/dev/null || echo '-')"
PANEL_VER="$(cat /etc/wibutunnel/version 2>/dev/null || echo '-')"
AKUN_DIHAPUS=0
SWAP_HASIL="tidak ada /swapfile"

printf '\n%s\n' "$LINE"
printf ' %s🧹 UNINSTALL WIBUTUNNEL%s\n' "$C_INFO" "$C_OFF"
printf ' %sdomain%s : %s\n' "$C_DIM" "$C_OFF" "$PANEL_DOMAIN"
printf ' %sversi %s : %s\n' "$C_DIM" "$C_OFF" "$PANEL_VER"
printf '%s\n' "$LINE"

step "1/7" "Menghentikan layanan panel"

# [FIX] Akun SSH panel adalah user sistem sungguhan (`add_ssh_user`: useradd -m -s /bin/bash -G
# ssh_tunnel). Sebelumnya uninstall TIDAK menghapusnya, sementara sshd port 22 tidak disentuh ->
# pelanggan yang belum kedaluwarsa tetap bisa login lewat port 22 setelah panel dihapus.
# Daftar akun ada di /etc/xray/ssh_exp.conf (baris "user:exp"). Penjaga: hanya user yang anggota
# grup ssh_tunnel DAN uid >= 1000, supaya user sistem milik VPS tidak ikut terhapus.
hapus_akun_panel() {
    local exp_file="${1:-/etc/xray/ssh_exp.conf}" grup="${2:-ssh_tunnel}" u uid
    [ -r "$exp_file" ] || return 0
    while IFS=: read -r u _rest; do
        [ -n "$u" ] || continue
        uid="$(id -u "$u" 2>/dev/null)" || continue
        [ -n "$uid" ] && [ "$uid" -ge 1000 ] 2>/dev/null || continue
        if id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx "$grup"; then
            pkill -KILL -u "$u" >/dev/null 2>&1 || true
            userdel -r "$u" >/dev/null 2>&1 || userdel "$u" >/dev/null 2>&1 || true
            if id -u "$u" >/dev/null 2>&1; then
                warn "gagal hapus akun: $u (manual: userdel -r $u)"
            else
                ok "dihapus: $u"; AKUN_DIHAPUS=$((AKUN_DIHAPUS+1))
            fi
        else
            info "dilewati: $u (bukan anggota grup $grup)"
        fi
    done < "$exp_file"
}

# Hentikan semua layanan
systemctl stop xray haproxy wibu-daemon network-tune ws-stunnel dropbear 2>/dev/null
systemctl disable xray haproxy wibu-daemon network-tune ws-stunnel dropbear 2>/dev/null
systemctl stop telegram-bot.service algojo-expired.service 2>/dev/null
systemctl disable telegram-bot.service algojo-expired.service 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null
systemctl stop wibutunnel-firewall.service wibutunnel-firewall.timer 2>/dev/null
systemctl disable wibutunnel-firewall.service wibutunnel-firewall.timer 2>/dev/null
systemctl stop wibu-acct.service 2>/dev/null
systemctl disable wibu-acct.service 2>/dev/null

# Proses panel yang lolos dari `systemctl stop`.
#
# Jebakan yang terbukti di VPS uji (v4.1.46): `systemctl stop` TIDAK mematikan unit berstatus
# "not-found" (file unitnya sudah hilang tapi prosesnya masih jalan). `wibu-acct` yang terus hidup
# membuat /etc/wibutunnel/user_acct.db & user_usage.db muncul lagi tiap beberapa menit SETELAH
# uninstall selesai — jadi VPS yang sudah "dibersihkan" jadi kotor lagi. `pgrep` juga tidak
# menemukannya kalau polanya cuma `wibu-daemon`. Karena itu: matikan prosesnya secara eksplisit,
# tunggu, lalu naikkan ke SIGKILL kalau masih hidup.
kill_proses_panel() {
    local pola=( '/usr/local/bin/wibu-acct' 'wibu-acct' 'wibu-audit-akun' 'algojo-wibu'
                 'algojo-kuota' 'algojo-ssh' 'wibu-daemon' 'ws-stunnel' 'wibu-kuota'
                 'wibu-udpgw' 'wibutunnel-firewall' 'network-tune' )
    local p sisa
    for p in "${pola[@]}"; do pkill -f "$p" >/dev/null 2>&1 || true; done
    for _w in 1 2 3 4 5; do
        sisa=0
        for p in "${pola[@]}"; do pgrep -f "$p" >/dev/null 2>&1 && sisa=$((sisa + 1)); done
        [ "$sisa" -eq 0 ] && break
        sleep 1
    done
    if [ "$sisa" -ne 0 ]; then
        for p in "${pola[@]}"; do pkill -9 -f "$p" >/dev/null 2>&1 || true; done
        sleep 1
        sisa=0
        for p in "${pola[@]}"; do pgrep -f "$p" >/dev/null 2>&1 && sisa=$((sisa + 1)); done
    fi
    SISA_PROSES="$sisa"
}
kill_proses_panel
if [ "${SISA_PROSES:-0}" -eq 0 ]; then
    ok "xray, haproxy, dropbear, ws-stunnel, wibu-daemon, wibu-acct, bot, firewall"
else
    warn "masih ada proses panel hidup ($SISA_PROSES pola) — cek: ps -eo args | grep -E 'wibu|algojo'"
fi

step "2/7" "Backup data panel"
SAVED="/root/wibutunnel-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SAVED" || { fail "gagal buat $SAVED — uninstall dibatalkan"; exit 1; }
BACKUP_PATHS=()
for p in /etc/xray /etc/wibutunnel /usr/local/etc/xray /etc/haproxy /etc/iptables; do
    [ -e "$p" ] && BACKUP_PATHS+=("$p")
done
if [ ${#BACKUP_PATHS[@]} -gt 0 ]; then
    tar -czf "$SAVED/data.tar.gz" "${BACKUP_PATHS[@]}" 2>/dev/null || {
        fail "backup gagal — uninstall dibatalkan (cek disk/permission)"; exit 1; }
    BACKUP_FILE="$SAVED/data.tar.gz"
    ok "tersimpan: $SAVED/data.tar.gz"
else
    BACKUP_FILE=""
    warn "tidak ada data yang perlu dibackup"
fi

# Penanda /swapfile dibuat panel (dibaca SEBELUM /etc/wibutunnel dihapus).
SWAP_PANEL=0; [ -f /etc/wibutunnel/.swapfile_panel ] && SWAP_PANEL=1

# [FIX] Hapus akun SSH pelanggan sebelum data konfigurasinya dibuang.
step "3/7" "Akun SSH pelanggan"
hapus_akun_panel /etc/xray/ssh_exp.conf "${SSH_GROUP:-ssh_tunnel}"
[ "$AKUN_DIHAPUS" -eq 0 ] && info "tidak ada akun pelanggan yang tersisa"

step "4/7" "Konfigurasi & core Xray"

# Hapus file konfigurasi dan database
umount -f /var/log/xray 2>/dev/null
rm -rf /usr/local/etc/xray /etc/haproxy /etc/wibutunnel /etc/xray /var/log/xray

# Uninstall Xray core (dipasang setup.sh via install-release.sh)
if command -v xray >/dev/null 2>&1; then
    # [C1] Uninstaller resmi HANYA dijalankan setelah hash cocok (tanpa verifikasi = risiko RCE).
    XRAY_TMP="$(mktemp /tmp/xray-uninstall.XXXXXX.sh)" || XRAY_TMP=""
    if [ -n "$XRAY_TMP" ] && curl -4 -sS -fL --retry 3 --connect-timeout 10 --max-time 90 -o "$XRAY_TMP" "$XRAY_INSTALL_URL" \
        && xray_verify_sha256 "$XRAY_TMP" "$XRAY_INSTALL_SHA256"; then
        info "uninstaller resmi Xray diunduh & sha256 cocok"
        bash "$XRAY_TMP" remove >/dev/null 2>&1   # [FIX] bentuk berkas, bukan "-s --"
    else
        warn "unduh/verifikasi uninstaller Xray gagal — dilewati, lanjut pembersihan manual"
    fi
fi
rm -rf /usr/local/share/xray /usr/local/bin/xray /etc/tmpfiles.d/xray.conf
rm -f /usr/lib/systemd/system/xray.service /usr/lib/systemd/system/xray@.service
id -u xray >/dev/null 2>&1 && userdel xray >/dev/null 2>&1
id -g xray >/dev/null 2>&1 && groupdel xray >/dev/null 2>&1
ok "/config, /etc/xray, /etc/haproxy, core Xray, user xray"

step "5/7" "Firewall & QoS"
# Kembalikan iptables ke kondisi bersih
if command -v iptables >/dev/null 2>&1; then
    # [C2] Hapus HANYA aturan owner-match milik wibutunnel (cocokkan pola),
    # jangan flush seluruh firewall.
    for p in 10085; do
        while iptables -C OUTPUT -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT 2>/dev/null; do
            iptables -D OUTPUT -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT 2>/dev/null || break
        done
    done
    # [FIX] Jangan `iptables -t mangle -F`: itu membuang SEMUA aturan mangle milik VPS (QoS lain,
    # fail2ban, klasifikasi buatan admin), bukan hanya punya panel. Yang dihapus hanya 4 aturan
    # CLASSIFY milik panel -- daftar yang sama dengan sbin/network-tune.sh.
    for _spec in "-p icmp -j CLASSIFY --set-class 1:1" \
                 "-p tcp --tcp-flags ACK ACK -j CLASSIFY --set-class 1:1" \
                 "-p tcp -m length --length 0:128 -j CLASSIFY --set-class 1:1" \
                 "-p udp -m length --length 0:128 -j CLASSIFY --set-class 1:1"; do
        while iptables -t mangle -C PREROUTING $_spec 2>/dev/null; do
            iptables -t mangle -D PREROUTING $_spec 2>/dev/null || break
        done
    done
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
fi
systemctl disable netfilter-persistent >/dev/null 2>&1
ok "aturan panel dihapus · aturan mangle lain dibiarkan"

step "6/7" "Biner, unit systemd & UDPGW"
# Hapus file executable menu & daemon
# [FIX] Daftar hapus lengkap: sebelumnya algojo-ssh, lock-user, unlock-user, ws-stunnel & wibu-daemon
# tertinggal di /usr/local/sbin|bin setelah uninstall.
# [FIX v4.1.30] wibu-kuota & wibu-udpgw ikut dipasang setup.sh tetapi dulu tidak ada di daftar ini:
# keduanya tertinggal di /usr/local/{bin,sbin} setelah uninstall (terukur di VPS uji).
for _f in algojo-wibu algojo-kuota algojo-ssh algojo-expired algojo-expired-daemon lock-user unlock-user \
          unlocker-wibu ws-stunnel wibu-daemon wibu-repair wibu-audit-akun wibu-ssl-ulang wibu-isp wibutunnel-firewall \
          wibutunnel-firewall.sh network-tune network-tune.sh wibu-kuota wibu-udpgw wibu-acct wibu-ensure-units; do
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
rm -f /etc/systemd/system/wibu-acct.service
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
# Unit templated badvpn-udpgw@ yang file-nya sudah dihapus tetap tersimpan systemd sebagai
# unit "not-found failed" dan ikut dihitung di `systemctl --failed`. Tanpa reset-failed,
# VPS terlihat masih punya 6 unit gagal milik panel.
systemctl reset-failed $(systemctl list-units --all --no-legend 'badvpn-udpgw@*' 2>/dev/null | awk '{print $1}') >/dev/null 2>&1 || true
if pgrep -f badvpn-udpgw >/dev/null 2>&1; then
    warn "proses badvpn-udpgw masih hidup (port 7100-7600)"
else
    ok "menu, daemon, unit systemd, badvpn-udpgw"
fi

step "7/7" "Sisa sistem: profil, fstab, swap, paket"
# Hapus logrotate
rm -f /etc/logrotate.d/xray

# Bersihkan .profile
[ -f /root/.profile ] && [ ! -f /root/.profile.wibutunnel.bak ] && cp -a /root/.profile /root/.profile.wibutunnel.bak
sed -i '/Auto-start menu/d; /^clear$/d; /^menu$/d' /root/.profile 2>/dev/null

# Bersihkan fstab entries
[ -f /etc/fstab ] && [ ! -f /etc/fstab.wibutunnel.bak ] && cp -a /etc/fstab /etc/fstab.wibutunnel.bak
sed -i '/\/var\/log\/xray/d' /etc/fstab 2>/dev/null
# Baris swap hanya dibuang kalau /swapfile memang buatan panel (lihat SWAP_PANEL di atas).
[ "$SWAP_PANEL" = 1 ] && sed -i '/\/swapfile none swap sw 0 0/d' /etc/fstab 2>/dev/null
sed -i '/tmpfs \/tmp tmpfs/d' /etc/fstab 2>/dev/null

# Hapus swapfile — HANYA kalau panel yang membuatnya. VPS bisa sudah punya swap sendiri di
# /swapfile sebelum panel dipasang; dulu file itu ikut dihapus tanpa syarat (swap VPS hilang).
if [ "$SWAP_PANEL" = 1 ] && [ -e /swapfile ]; then
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile
    SWAP_HASIL="dihapus (dibuat panel)"
    info "$SWAP_HASIL"
elif [ -e /swapfile ]; then
    SWAP_HASIL="dipertahankan (bukan buatan panel)"
    info "$SWAP_HASIL"
else
    SWAP_HASIL="tidak ada /swapfile"
    info "$SWAP_HASIL"
fi

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
    info "rujukan banner wibutunnel dibuang dari /etc/default/dropbear"
fi

# Uninstall paket bawaan (opsional)
#
# Jebakan yang terbukti di VPS uji (v4.1.45): selama proses rilis, `unattended-upgrades`
# memegang /var/lib/dpkg/lock-frontend. `apt-get remove --purge` gagal seketika, keluarannya
# dibuang ke /dev/null, dan uninstaller tetap mencetak ✓ — padahal haproxy dan dropbear masih
# terpasang. Sekarang: tunggu kunci, purge per paket, lalu VERIFIKASI dengan `dpkg -s`.
for _i in $(seq 1 150); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    sleep 2
done
PAKET_SISA=""
for _p in haproxy vnstat dropbear; do
    dpkg -s "$_p" >/dev/null 2>&1 || continue
    apt-get remove --purge -y "$_p" >/dev/null 2>&1 || true
    dpkg -s "$_p" >/dev/null 2>&1 && PAKET_SISA="$PAKET_SISA $_p"
done
# Sekali coba lagi: unattended-upgrades kadang baru melepas kunci setelah beberapa menit.
if [ -n "$PAKET_SISA" ]; then
    info "purge belum berhasil ($PAKET_SISA) — tunggu 60 dtk lalu coba sekali lagi"
    sleep 60
    for _p in $PAKET_SISA; do
        apt-get remove --purge -y "$_p" >/dev/null 2>&1 || true
    done
    PAKET_SISA=""
    for _p in haproxy vnstat dropbear; do
        dpkg -s "$_p" >/dev/null 2>&1 && PAKET_SISA="$PAKET_SISA $_p"
    done
fi
apt-get autoremove -y >/dev/null 2>&1 || true
if [ -z "$PAKET_SISA" ]; then
    ok "haproxy, vnstat, dropbear di-purge (dicek ulang dengan dpkg -s)"
else
    warn "masih terpasang:$PAKET_SISA — jalankan: apt-get remove --purge -y$PAKET_SISA"
fi

# Sapu bersih sisa panel. /etc/wibutunnel bisa HIDUP LAGI setelah step 4 kalau cron/proses panel
# sempat menulis DB-nya; grup ssh_tunnel dan sisa unit juga tidak dibersihkan versi sebelumnya.
rm -rf /etc/wibutunnel /etc/xray /etc/haproxy /usr/local/etc/xray /var/log/xray /config
rm -f /etc/systemd/system/dropbear.service /etc/systemd/system/haproxy.service
rm -rf /etc/systemd/system/haproxy.service.d /etc/systemd/system/dropbear.service.d
# Unit panel yang masih termuat systemd walau berkasnya sudah dihapus ("not-found") tidak bisa
# dihentikan lewat `systemctl stop <unit>` biasa, dan state "active (exited)" milik oneshot seperti
# wibutunnel-firewall tetap tersangkut. Hentikan per nama, lalu bersihkan state-nya.
for _u in wibutunnel-firewall.service wibutunnel-firewall.timer wibu-acct.service xray.service \
          haproxy.service dropbear.service ws-stunnel.service wibu-daemon.service network-tune.service \
          telegram-bot.service telegram-webhook.socket algojo-expired.service; do
    systemctl stop "$_u" >/dev/null 2>&1 || true
    systemctl reset-failed "$_u" >/dev/null 2>&1 || true
done
systemctl stop system-badvpn-udpgw.slice >/dev/null 2>&1 || true
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed >/dev/null 2>&1 || true
if getent group ssh_tunnel >/dev/null 2>&1; then
    groupdel ssh_tunnel 2>/dev/null && info "grup ssh_tunnel dihapus" || warn "grup ssh_tunnel tidak bisa dihapus (masih dipakai akun lain)"
fi

# Unit oneshot dengan RemainAfterExit (mis. wibutunnel-firewall) tetap berstatus "active (exited)"
# walau file unitnya sudah dihapus, dan itu ikut terhitung sebagai sisa. `systemctl stop` masih
# sanggup membersihkannya selama unit masih dimuat systemd — jadi coba sekali lagi di akhir.
for _u in wibutunnel-firewall.service wibutunnel-firewall.timer wibu-acct.service wibu-daemon.service \
          ws-stunnel.service network-tune.service telegram-bot.service telegram-webhook.socket \
          algojo-expired.service wibu-acct.service; do
    systemctl stop "$_u" >/dev/null 2>&1 || true
done
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed >/dev/null 2>&1 || true

# Unit oneshot dengan RemainAfterExit (mis. wibutunnel-firewall) tetap berstatus "active (exited)"
# walau file unitnya sudah dihapus; `systemctl stop` masih sanggup membersihkannya selama unit
# masih dimuat systemd, jadi coba sekali lagi di akhir sebelum menghitung sisa.
for _u in wibutunnel-firewall.service wibutunnel-firewall.timer wibu-acct.service wibu-daemon.service \
          ws-stunnel.service network-tune.service telegram-bot.service telegram-webhook.socket \
          algojo-expired.service; do
    systemctl stop "$_u" >/dev/null 2>&1 || true
done
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed >/dev/null 2>&1 || true

SISA_DIR=0
for _d in /etc/wibutunnel /etc/xray /etc/haproxy /usr/local/etc/xray /var/log/xray; do
    [ -e "$_d" ] && SISA_DIR=$((SISA_DIR + 1))
done
SISA_UNIT=$(systemctl list-unit-files --no-legend --plain 2>/dev/null | grep -cE '^(wibu|xray|haproxy|dropbear|ws-stunnel|algojo|badvpn)')
SISA_FAIL=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
# Unit "not-found" tetap terdaftar di systemd walau file unitnya sudah dihapus; kalau masih aktif
# berarti ada proses panel yang belum mati (lihat kill_proses_panel di step 1).
# Perhatikan: jangan pakai /active/ saja — string "inactive" juga cocok dan membuat unit mati
# dihitung sebagai sisa. Kolom 4 adalah state aktif (active|inactive|failed), kolom 3 load state.
# Unit oneshot yang sudah kelar tetap terlihat "active (exited)"; itu bukan proses yang hidup.
# Yang benar-benar mengkhawatirkan cuma state "running" (dulu: wibu-acct hidup terus dan menulis
# ulang /etc/wibutunnel/*.db). Lihat kolom 5 = sub-state.
SISA_NF=$(systemctl list-units --all --no-legend 2>/dev/null | awk '$3=="not-found" && $4=="active" && $5=="running" {print $2}' | grep -cE 'wibu|xray|haproxy|dropbear|ws-stunnel|algojo|badvpn|telegram')
SISA_PROC=$(ps -eo args 2>/dev/null | grep -cE '[w]ibu-acct|[w]ibu-daemon|[a]lgojo|[w]s-stunnel|[b]advpn-udpgw|[w]ibutunnel-firewall')
if [ "$SISA_DIR" -eq 0 ] && [ "$SISA_UNIT" -eq 0 ] && [ "$SISA_FAIL" -eq 0 ] && [ "$SISA_NF" -eq 0 ] && [ "$SISA_PROC" -eq 0 ]; then
    ok "tidak ada sisa panel: direktori, unit, proses, dan status systemd bersih"
else
    warn "sisa panel: $SISA_DIR direktori · $SISA_UNIT unit · $SISA_FAIL unit gagal · $SISA_NF unit not-found aktif · $SISA_PROC proses"
fi
# /etc/wibutunnel bisa dibuat ulang oleh proses/profil yang masih hidup; jangan tinggalkan jejaknya.
if [ -e /etc/wibutunnel ]; then
    rm -rf /etc/wibutunnel
    [ -e /etc/wibutunnel ] && warn "/etc/wibutunnel muncul kembali setelah sapu bersih" || info "/etc/wibutunnel dihapus ulang setelah pemeriksaan sisa"
fi

printf '\n%s\n' "$LINE"
printf ' %s✓ UNINSTALL SELESAI%s\n' "$C_OK" "$C_OFF"
printf '%s\n' "$LINE"
[ -n "${BACKUP_FILE:-}" ] && printf ' %sbackup%s : %s\n' "$C_DIM" "$C_OFF" "$BACKUP_FILE"
printf ' %sakun  %s : %s dihapus\n' "$C_DIM" "$C_OFF" "$AKUN_DIHAPUS"
printf ' %sswap  %s : %s\n' "$C_DIM" "$C_OFF" "$SWAP_HASIL"
printf ' %ssshd  %s : port 22 tidak disentuh\n' "$C_DIM" "$C_OFF"
printf '%s\n' "$LINE"
printf ' %sPasang ulang kapan saja%s\n' "$C_DIM" "$C_OFF"
printf '   bash <(curl -4 -fsSL https://github.com/WBVPN/wibutunnel/releases/latest/download/install.sh)\n\n'
