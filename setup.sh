#!/bin/bash
# ==========================================
# MASTER INSTALLER WIBU TUNNELING - v4.1.5
# Zero-Lag Queue Daemon + Security Patch + Recovery System
# ==========================================
# RESIDUAL RISK (v4.1.5):
#  * Pelanggan SSH masih mendapat shell /bin/bash. Mitigasi utama: port API Xray
#    127.0.0.1:10085 dibatasi uid 0 via iptables owner-match + unit systemd
#    wibutunnel-firewall.service (ditegakkan saat boot). Opt-in WIBU_SSH_NOLOGIN=1
#    mematikan shell interaktif pelanggan (tunnel ssh -N -L tetap jalan).
#  * Instaleler Xray dipin hash (XRAY_INSTALL_SHA256). Bypass HANYA via env
#    WIBUTUNNEL_ALLOW_UNVERIFIED=1 (dicatat ke log + peringatan besar).

# [FIX] Root check harus paling awal sebelum operasi apapun
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31mError: Harus dijalankan sebagai root!\e[0m"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo -e "\e[31m[GAGAL] Hanya untuk Ubuntu/Debian. Didukung: Ubuntu 20.04/22.04/24.04, Debian 11/12.\e[0m"
    echo -e "\e[33m        Sudah diuji di VPS nyata: Ubuntu 20.04 dan Debian 12.\e[0m"
    echo -e "\e[33m        Terdeteksi: ${PRETTY_NAME:-$ID} - hubungi @wibuvpn untuk OS lain.\e[0m"
    exit 1
fi
echo -e "\e[1;32m[+] OS terdeteksi: ${PRETTY_NAME:-$ID} ($VERSION_ID)\e[0m"

# Pre-flight tool check
command -v curl >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1 && apt-get install -y curl wget >/dev/null 2>&1; }

# [FIX Bug #1] Deteksi IP publik dengan validasi dan retry
echo -e "\e[1;36m[+] Mendeteksi IP publik...\e[0m"
MYIP=$(curl -4 -sS --max-time 8 ipv4.icanhazip.com)
if [[ -z "$MYIP" ]]; then
    echo -e "\e[1;33m[WARN] Mencoba service alternatif...\e[0m"
    MYIP=$(curl -4 -sS --max-time 8 ifconfig.me)
fi
if [[ -z "$MYIP" ]]; then
    echo -e "\e[1;33m[WARN] Mencoba service alternatif kedua...\e[0m"
    MYIP=$(curl -4 -sS --max-time 8 api.ipify.org)
fi
if [[ -z "$MYIP" ]]; then
    clear
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;31m            GAGAL MENDETEKSI IP PUBLIK!            \e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;37m Tidak dapat mendeteksi IP publik VPS Anda.\e[0m"
    echo -e "\e[1;37m Silakan periksa koneksi internet dan coba lagi.\e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    exit 1
fi
echo -e "\e[1;32m[✓] IP terdeteksi: $MYIP\e[0m"
clear
echo -e "\e[1;36m[+] Memeriksa Lisensi Script...\e[0m"

LINK_IZIN="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
LINK_IZIN_MIRROR="https://cdn.jsdelivr.net/gh/WBVPN/wibutunnel@main/izin.txt"
# [FIX] Daftar lisensi HANYA dari sumber resmi. Sebelumnya berkas ./izin.txt di
# direktori kerja ikut dipercaya -> cukup `printf 'x lifetime <IP>' > izin.txt`
# untuk melewati gerbang. Kini berkas lokal DIABAIKAN saat instalasi.
IZIN_LIST=""
for _coba in 1 2 3; do
    IZIN_LIST=$(curl -4 -sS --max-time 15 --connect-timeout 8 "$LINK_IZIN" 2>/dev/null) || IZIN_LIST=""
    [[ -n "$IZIN_LIST" ]] && break
    IZIN_LIST=$(curl -4 -sS --max-time 15 --connect-timeout 8 "$LINK_IZIN_MIRROR" 2>/dev/null) || IZIN_LIST=""
    [[ -n "$IZIN_LIST" ]] && break
    sleep 2
done
if [[ -z "$IZIN_LIST" ]]; then
    clear
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;31m        GAGAL MEMVERIFIKASI LISENSI (JARINGAN)     \e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;33m IP VPS Anda  : $MYIP\e[0m"
    echo -e "\e[1;37m Daftar lisensi tidak bisa diambil. Periksa koneksi\e[0m"
    echo -e "\e[1;37m lalu jalankan ulang instalasi.\e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    exit 1
fi

# Cocokkan PERSIS pada kolom IP (bukan grep kabur: titik di IP = karakter apa pun)
GET_DATA=$(printf '%s\n' "$IZIN_LIST" | awk -v ip="$MYIP" '{ for (i = 1; i <= NF; i++) if ($i == ip) { print; exit } }')

CLIENT_NAME=$(echo "$GET_DATA" | awk '{print $2}' | tr -d '\r' | tr -d ' ')
EXP_DATE=$(echo "$GET_DATA" | awk '{print $3}' | tr -d '\r' | tr -d ' ')
REGISTERED_IP=$(echo "$GET_DATA" | awk '{print $4}' | tr -d '\r' | tr -d ' ')

if [[ -n "$GET_DATA" ]]; then
    if [[ -z "$CLIENT_NAME" || -z "$EXP_DATE" ]]; then
        clear
        echo -e "\e[1;31m                 AKSES DITOLAK!                   \e[0m"
        echo -e "\e[1;33m IP VPS Anda  : $MYIP\e[0m"
        echo -e "\e[1;33m Status       : Entri lisensi rusak, hubungi Admin.\e[0m"
        exit 1
    fi
    if [[ "${EXP_DATE,,}" != "lifetime" ]]; then
        DATE_NOW=$(date -u +%s)
        exp_parse="$EXP_DATE"
        [[ "$exp_parse" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && exp_parse="${exp_parse} 23:59:59"
        DATE_EXP=$(date -u -d "$exp_parse" +%s 2>/dev/null)
        if [[ -z "$DATE_EXP" ]] || [[ $DATE_NOW -gt $DATE_EXP ]]; then
            clear
            echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
            echo -e "\e[1;31m               LISENSI KEDALUWARSA!               \e[0m"
            echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
            echo -e "\e[1;33m Klien       : $CLIENT_NAME\e[0m"
            echo -e "\e[1;33m IP VPS      : $MYIP\e[0m"
            echo -e "\e[1;33m Expired On  : $EXP_DATE\e[0m"
            echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
            echo -e "\e[1;37m Silakan hubungi Admin untuk perpanjangan.\e[0m"
            echo -e "\e[1;32m WhatsApp : 087757315408\e[0m"
            echo -e "\e[1;36m Telegram : t.me/wibuvpn\e[0m"
            echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
            exit 1
        fi
    fi
    echo -e "\e[1;32m[+] Lisensi Valid! Selamat Datang, $CLIENT_NAME.\e[0m"
    # Simpan salinan resmi -> dipakai sebagai cadangan saat VPS offline
    mkdir -p /etc/wibutunnel && printf '%s\n' "$IZIN_LIST" > /etc/wibutunnel/izin.txt && chmod 600 /etc/wibutunnel/izin.txt
    sleep 1
else
    clear
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;31m                 AKSES DITOLAK!                   \e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;33m IP VPS Anda  : $MYIP\e[0m"
    echo -e "\e[1;33m Status       : Ilegal / Tidak Terdaftar\e[0m"
    echo -e "\e[1;36m Telegram     : t.me/wibuvpn\e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    exit 1
fi

GITHUB_USER="WBVPN"
REPO_NAME="wibutunnel"
# [FIX-K1] Kode diambil dari REF TERPIN + diverifikasi (lihat wibu_verify_file di bawah).
WIBU_REF="${WIBU_REF:-v4.1.5}"   # tag rilis TETAP (immutable)
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${WIBU_REF}"

# [C1] Pin + verifikasi instaleler Xray. Tanpa pin, menjalankan skrip hulu
# langsung = root RCE bila hulu diretas. Hash diverifikasi 2026-11-15.
XRAY_INSTALL_URL="${XRAY_INSTALL_URL:-https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh}"
XRAY_INSTALL_SHA256="${XRAY_INSTALL_SHA256:-a562d1287cd7bf2871023d4c81bd9031c56fa132956067ba1de126957cc5fb1c}"
XRAY_TMP=""
xray_tmp_cleanup() { [ -n "$XRAY_TMP" ] && rm -f "$XRAY_TMP"; return 0; }
trap xray_tmp_cleanup EXIT

xray_verify_sha256() {
    # $1=berkas $2=hash harap. Cetak alasan ke stderr bila gagal, return 1.
    local file="$1" want="$2" got
    [ -s "$file" ] || { echo "instaleler kosong/tidak ada: $file" >&2; return 1; }
    got="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
    [ -n "$got" ] || { echo "sha256sum gagal" >&2; return 1; }
    [ "$got" = "$want" ] || { echo "HASH TIDAK COCOK (dapat=$got harap=$want)" >&2; return 1; }
    return 0
}

xray_installer_run() {
    # $1=aksi (install|remove). ABORT bila unduh/verifikasi gagal, kecuali bypass.
    local action="${1:-install}"
    mkdir -p /etc/wibutunnel/tmp
    XRAY_TMP="$(mktemp /etc/wibutunnel/tmp/xray-install.XXXXXX.sh)" || {
        echo -e "\e[1;31m[FATAL] gagal membuat berkas temporer.\e[0m"; exit 1; }
    if ! curl -4 -fSL --retry 3 --connect-timeout 10 --max-time 90 -o "$XRAY_TMP" "$XRAY_INSTALL_URL"; then
        echo -e "\e[1;31m[FATAL] unduh instaleler Xray gagal: $XRAY_INSTALL_URL\e[0m"
        [ "${WIBUTUNNEL_ALLOW_UNVERIFIED:-0}" = "1" ] || exit 1
    fi
    if ! xray_verify_sha256 "$XRAY_TMP" "$XRAY_INSTALL_SHA256"; then
        if [ "${WIBUTUNNEL_ALLOW_UNVERIFIED:-0}" = "1" ]; then
            echo -e "\e[1;31m[PERINGATAN BESAR] Instaleler Xray TIDAK TERVERIFIKASI - melanjutkan karena WIBUTUNNEL_ALLOW_UNVERIFIED=1\e[0m"
            echo "$(date -Is) bypass WIBUTUNNEL_ALLOW_UNVERIFIED: $XRAY_INSTALL_URL" >> /var/log/wibutunnel-installer.log 2>/dev/null
            logger -t wibutunnel "Xray installer UNVERIFIED bypass (hash mismatch)" 2>/dev/null
        else
            echo -e "\e[1;31m[FATAL] Hash instaleler Xray tidak cocok/kosong. ABORT (installer tidak dijalankan).\e[0m"
            echo -e "\e[1;33m         Override sadar (tidak disarankan): WIBUTUNNEL_ALLOW_UNVERIFIED=1\e[0m"
            exit 1
        fi
    fi
    bash "$XRAY_TMP" "$action"   # [FIX] bentuk berkas: aksi jadi $1 (bukan "-s --" yang untuk pipa)
}

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "     STARTING INSTALL WIBU TUNNELING (FINAL)      "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# [NEW] DISABLE IPV6 SECARA PERMANEN (CEGAH APT/XRAY ERROR)
echo -e "\e[1;36m[+] Menonaktifkan IPv6 untuk mencegah masalah routing...\e[0m"
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
    cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
fi
sysctl -p >/dev/null 2>&1

if command -v update-grub >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
    if ! grep -q "ipv6.disable=1" /etc/default/grub; then
        [ -f /etc/default/grub ] && [ ! -f /etc/default/grub.wibutunnel.bak ] && cp -a /etc/default/grub /etc/default/grub.wibutunnel.bak
        sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
        update-grub >/dev/null 2>&1
    fi
fi
echo -e "\e[1;32m[+] IPv6 berhasil dimatikan secara permanen!\e[0m"

# DOMAIN INPUT
domain="${1:-${DOMAIN}}"
_domain_try=0
while true; do
    if [[ -z "$domain" ]]; then
        # [FIX] tanpa penjaga ini, input habis (EOF) = loop tanpa henti (1,4 juta baris log / 2 menit)
        if ! read -r -p "Masukkan Domain Anda: " domain; then
            echo -e "\e[31m[!] Input berakhir (EOF). Instalasi dihentikan.\e[0m"
            exit 1
        fi
        [[ -z "$domain" ]] && { echo -e "\e[31m[!] Domain tidak boleh kosong!\e[0m"
                                _domain_try=$((_domain_try+1))
                                [[ $_domain_try -ge 5 ]] && { echo -e "\e[31m[!] 5 kali gagal. Keluar.\e[0m"; exit 1; }
                                continue; }
    fi

    if ! command -v dig >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y dnsutils >/dev/null 2>&1
    fi

    IP_DOMAIN=$(dig +short "$domain" | head -n 1)

    if [[ -z "$IP_DOMAIN" ]]; then
        echo -e "\e[1;31m[!] Domain tidak valid!\e[0m"
        domain=""
        continue
    fi

    if [[ "$IP_DOMAIN" == "$MYIP" ]]; then
        echo -e "\e[1;32m[+] Pointing Sukses!\e[0m"
        break
    else
        echo -e "\e[1;33m[!] IP Domain berbeda dengan IP VPS.\e[0m"
        read -r -p "Lanjutkan dengan mode Cloudflare? (y/n): " lanjut || { echo -e "\e[31m[!] Input berakhir (EOF). Keluar.\e[0m"; exit 1; }
        if [[ "$lanjut" == "y" || "$lanjut" == "Y" ]]; then
            break
        fi
        _domain_try=$((_domain_try+1))
        [[ $_domain_try -ge 5 ]] && { echo -e "\e[31m[!] 5 kali gagal. Keluar.\e[0m"; exit 1; }
        domain=""
        continue
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         MEMULAI PROSES INSTALASI OTOMATIS        "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 1

# Timezone
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
timedatectl set-timezone Asia/Jakarta
apt-get update -y >/dev/null 2>&1
apt-get install -y ntp dnsutils >/dev/null 2>&1
# [FIX Debian 12] paket `ntp` tidak ada di instalasi minimal bookworm -> pakai systemd-timesyncd
systemctl enable --now systemd-timesyncd >/dev/null 2>&1 || systemctl enable --now ntp >/dev/null 2>&1 || systemctl enable --now chrony >/dev/null 2>&1 || true

mkdir -p /etc/xray /usr/local/etc/xray /etc/haproxy/certs /etc/wibutunnel /etc/wibutunnel/tmp
chmod 700 /etc/wibutunnel /etc/wibutunnel/tmp
echo "$domain" > /etc/xray/domain
echo "$domain" > /root/domain

# [PATCH VERSION] Teks versi yang akan tampil di Dashboard
echo "4.1.5" > /etc/wibutunnel/version

# Lock duration config (dipakai algojo-wibu & m-setting)
[[ -f /etc/wibutunnel/lock.conf ]] || printf 'LOCK_DURATION=15\n' > /etc/wibutunnel/lock.conf
chmod 600 /etc/wibutunnel/lock.conf

# [C5 opt-in] Pelanggan SSH default dapat shell /bin/bash (common.sh:396).
# WIBU_SSH_NOLOGIN=1 mematikan shell interaktif pelanggan: tunneling (ssh -N -L)
# tetap jalan, tapi shell mati. Disimpan di ssh_shell.conf.
if [[ "${WIBU_SSH_NOLOGIN:-0}" == "1" ]]; then
    printf 'SSH_SHELL=/usr/sbin/nologin\n' > /etc/wibutunnel/ssh_shell.conf
    chmod 600 /etc/wibutunnel/ssh_shell.conf
    echo -e "\e[1;33m[!] WIBU_SSH_NOLOGIN=1: shell pelanggan SSH = /usr/sbin/nologin (tunneling tetap jalan).\e[0m"
fi

# Dummy users
echo "dummy-tls:Lifetime" > /etc/xray/vless_exp.conf
echo "dummy-ntls:Lifetime" >> /etc/xray/vless_exp.conf
echo "dummy-grpc:Lifetime" >> /etc/xray/vless_exp.conf
echo "dummy-vmess-tls:Lifetime" > /etc/xray/vmess_exp.conf
echo "dummy-vmess-ntls:Lifetime" >> /etc/xray/vmess_exp.conf
echo "dummy-vmess-grpc:Lifetime" >> /etc/xray/vmess_exp.conf
echo "dummy-trojan-tls:Lifetime" > /etc/xray/trojan_exp.conf
echo "dummy-trojan-grpc:Lifetime" >> /etc/xray/trojan_exp.conf

# [C3] /etc/xray memuat *_exp.conf (daftar pelanggan) -> batasi akses.
chmod 750 /etc/xray
chmod 600 /etc/xray/*_exp.conf 2>/dev/null || true

# AUTO-SWAP CERDAS
total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$total_ram" -le 1024 ]; then swap_mb=4096
elif [ "$total_ram" -le 4096 ]; then swap_mb=2048
else swap_mb=1024; fi

if ! swapon --show | grep -q "/swapfile"; then
    fallocate -l ${swap_mb}M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=$swap_mb status=progress
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile >/dev/null 2>&1
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

# KERNEL TUNING
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
EOF
sysctl -p >/dev/null 2>&1
fi

# [C4] Jangan timpa /etc/security/limits.conf: backup sekali + blok berpenanda (idempoten).
[ -f /etc/security/limits.conf ] && [ ! -f /etc/security/limits.conf.wibutunnel.bak ] && \
    cp -a /etc/security/limits.conf /etc/security/limits.conf.wibutunnel.bak
if grep -q '# >>> wibutunnel >>>' /etc/security/limits.conf 2>/dev/null; then
    sed -i '/# >>> wibutunnel >>>/,/# <<< wibutunnel <<</d' /etc/security/limits.conf
fi
cat <<'EOF' >> /etc/security/limits.conf
# >>> wibutunnel >>>
root soft nofile 512000
root hard nofile 512000
* soft nofile 512000
* hard nofile 512000
# <<< wibutunnel <<<
EOF

# INSTALL PAKET (dibersihkan dari bloat nginx/python3/socat)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# [FIX-KRITIS] '-4' pernah nyasar masuk daftar paket di sini (akibat penyisiran curl -4),
# membuat SELURUH apt-get gagal -> haproxy tidak terpasang -> "Failed to enable services".
# apt gagal sekarang DIANGGAP FATAL: lanjut tanpa paket = instalasi setengah jalan.
# [FIX-KRITIS] dropbear dari instalasi lama bisa masih menunjuk banner yang sudah dihapus
# (/etc/wibutunnel/ssh-banner). dpkg --configure dropbear lalu GAGAL -> seluruh apt-get gagal.
# Siapkan direktori+banner kosong lebih dulu, dan buat banner yang hilang jadi ada.
mkdir -p /etc/wibutunnel 2>/dev/null || true
[[ -f /etc/wibutunnel/ssh-banner ]] || : > /etc/wibutunnel/ssh-banner
# [PORTABILITAS] Paket dropbear bawaan Debian/Ubuntu mendengarkan di port 22 dan postinst-nya
# menjalankannya SEGERA saat apt memasang. Kalau dia menang balapan dengan sshd, admin bisa
# kehilangan akses SSH. Tulis NO_START=1 lebih dulu supaya postinst tidak menyalakannya;
# konfigurasi sebenarnya (143/109/2222) ditulis setelah semua paket terpasang.
if [[ ! -f /etc/default/dropbear ]] || ! grep -q '^# WIBUTUNNEL' /etc/default/dropbear 2>/dev/null; then
    printf '# WIBUTUNNEL: jangan start otomatis sebelum konfigurasi siap\nNO_START=1\nDROPBEAR_PORT=143\n' > /etc/default/dropbear
fi
if [[ -f /etc/default/dropbear ]]; then
    _bn=$(sed -n 's/^DROPBEAR_BANNER="\?\(.*\)"\?$/\1/p' /etc/default/dropbear | head -1)
    [[ -n "$_bn" && ! -f "$_bn" ]] && { mkdir -p "$(dirname "$_bn")" 2>/dev/null; : > "$_bn"; }
fi
# DEBIAN_FRONTEND=noninteractive: hindari prompt debconf (iptables-persistent) saat instalasi tanpa TTY.
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y curl jq uuid-runtime haproxy certbot cron net-tools zip unzip wget iptables iptables-persistent iproute2 bc logrotate dos2unix dropbear python3 rsyslog; then
    echo -e "\e[1;31m[!] Gagal memasang paket dasar. Instalasi DIHENTIKAN supaya tidak setengah jalan.\e[0m"
    echo -e "\e[1;33m    Cek koneksi repo: apt-get update && apt-get install -y curl\e[0m"
    exit 1
fi

# [PORTABILITAS] Catat versi paket kunci: memudahkan tahu kombinasi apa yang dipakai saat ada keluhan.
echo -e "\e[1;36m[+] Versi: haproxy $(haproxy -v 2>/dev/null | head -1 | awk '{print $3}') | certbot $(certbot --version 2>&1 | awk '{print $2}') | dropbear $(dpkg -l dropbear 2>/dev/null | awk '/^ii/{print $3}') | python $(python3 -V 2>&1 | awk '{print $2}') | openssl $(openssl version 2>/dev/null | awk '{print $2}')\e[0m"
[[ -e /dev/log ]] || echo -e "\e[1;33m[!] /dev/log tidak ada -> log HAProxy tidak tersimpan (pasang rsyslog).\e[0m"

# [FIX] Enable iptables-persistent agar rules survive reboot
systemctl enable netfilter-persistent >/dev/null 2>&1 || true

if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,nosuid,nodev,noexec,mode=1777,size=100M 0 0" >> /etc/fstab
    mount -o remount /tmp
fi

if ! grep -q "tmpfs /var/log/xray" /etc/fstab; then
    echo "tmpfs /var/log/xray tmpfs defaults,nosuid,nodev,noexec,mode=0755,size=100M 0 0" >> /etc/fstab
    mkdir -p /var/log/xray
    mount /var/log/xray 2>/dev/null || true
fi
chown xray:adm /var/log/xray 2>/dev/null || true
chmod 750 /var/log/xray

# Anti-Torrent
# Guard idempoten: 25 rule di bawah di-append tanpa flush, jadi re-run setup.sh
# akan menduplikasi semuanya. Rule pertama dipakai sebagai sentinel.
if ! iptables -C FORWARD -m string --string "get_peers" --algo bm -j DROP 2>/dev/null; then
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP

# Anti-DDoS & Syn-Flood Protection (Ultra Lightweight)
echo -e "\e[1;36m[+] Memasang Anti-DDoS & SSH Brute-Force Protection...\e[0m"
# 1. Drop paket cacat / malformed packets
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
# 2. Limit Ping (Cegah Ping of Death)
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 1 -j ACCEPT
iptables -A INPUT -p icmp -j DROP
# 3. Cegah SSH Brute-Force (Port 22) - Banned jika >10 percobaan dalam 60 detik
iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j DROP
# 4. Batasi Max Koneksi per IP (Cegah Layer 4/7 Flood ke Port Proxy)
iptables -I INPUT -p tcp --dport 443 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset
iptables -I INPUT -p tcp --dport 80 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset

fi   # end iptables idempotency guard

# [FIX] Ambil skrip dari ref terpin supaya berkas ini juga ikut ter-update lewat menu [5]
# (sebelumnya hanya ada sebagai heredoc di sini, jadi perbaikannya tak bisa dikirim ke VPS
# pelanggan lewat jalur update). Gagal unduh/verifikasi -> pakai heredoc di bawahnya.
wibu_get_script() { # $1=jalur repo  $2=tujuan
    local tmp="/etc/wibutunnel/tmp/wg.$$" code exp act
    code=$(curl -4 -sS -L --connect-timeout 10 --max-time 60 -w '%{http_code}' -o "$tmp" "${GITHUB_RAW}/$1" 2>/dev/null)
    if [[ "$code" != "200" ]]; then
        code=$(curl -4 -sS -L --connect-timeout 10 --max-time 60 -w '%{http_code}' -o "$tmp" "https://cdn.jsdelivr.net/gh/${GITHUB_USER}/${REPO_NAME}@${WIBU_REF}/$1" 2>/dev/null)
    fi
    [[ "$code" == "200" && -s "$tmp" ]] || { rm -f "$tmp"; return 1; }
    local cb="cb=$(date +%s)$$"
    exp=$(curl -4 -sS --max-time 40 "${GITHUB_RAW}/SHA256SUMS?${cb}" 2>/dev/null | awk -v f="$1" '$2==f{print $1}' | head -1)
    [[ -z "$exp" ]] && exp=$(curl -4 -sS --max-time 40 -H 'Accept: application/vnd.github.raw' -H 'User-Agent: wibutunnel-installer' \
        "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/SHA256SUMS?ref=${WIBU_REF}" 2>/dev/null | awk -v f="$1" '$2==f{print $1}' | head -1)
    act=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
    if [[ -n "$exp" && "$act" == "$exp" ]]; then install -m755 "$tmp" "$2"; rm -f "$tmp"; return 0; fi
    # [FIX] Berkas lewat CDN raw pun bisa basi -> coba sekali lagi lewat API (otoritatif).
    curl -4 -fsSL --retry 2 --connect-timeout 10 --max-time 60 -H 'Accept: application/vnd.github.raw' \
        -H 'User-Agent: wibutunnel-installer' -o "$tmp" \
        "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/$1?ref=${WIBU_REF}" 2>/dev/null
    act=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
    if [[ -n "$exp" && "$act" == "$exp" ]]; then install -m755 "$tmp" "$2"; rm -f "$tmp"; return 0; fi
    rm -f "$tmp"
    return 1
}

# [C2] MITIGASI UTAMA: API Xray 127.0.0.1:10085 tanpa auth hanya boleh diakses uid 0.
# Akun pelanggan SSH dapat shell, jadi tanpa ini mereka bisa `xray api ...` atau
# `ssh -L 10085:127.0.0.1:10085` untuk hapus user & lewati expiry/kuota.
# Owner-match memblokir non-root, termasuk koneksi tunnel ssh -L (proses sshd
# sudah turun ke uid user). Residual risk: pelanggan tetap punya shell.
if wibu_get_script "sbin/wibutunnel-firewall.sh" /usr/local/sbin/wibutunnel-firewall; then
    echo -e "\e[1;32m[+] Skrip firewall dari ref terpin & terverifikasi\e[0m"
else
cat > /usr/local/sbin/wibutunnel-firewall << 'FWEOF'
#!/bin/bash
# Wibu Tunneling - paksa akses root-only ke port API Xray (mitigasi utama).
# Tambahkan port API baru ke API_PORTS bila skema berubah.
API_PORTS="10085"
rc=0
for p in $API_PORTS; do
    # [FIX] Buang SEMUA salinan lama dulu. `iptables -C` tidak mengenali aturan hasil
    # restore /etc/iptables/rules.v4 (spesifikasi target REJECT dinormalisasi berbeda),
    # sehingga tiap boot menambah satu salinan lagi. Dedupe lewat spesifikasi persis
    # dari `iptables -S` -> pasti terhapus, lalu pasang tepat satu aturan.
    while :; do
        spec=$(iptables -S OUTPUT 2>/dev/null | awk -v p="$p" 'index($0,"-j REJECT") && index($0,"--dport "p){sub(/^-A OUTPUT /,"");print;exit}')
        [ -z "$spec" ] && break
        # shellcheck disable=SC2086
        iptables -D OUTPUT $spec 2>/dev/null || break
    done
    iptables -I OUTPUT 1 -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT || rc=1
done
# [FIX] Simpan keadaan yang sudah rapi ke rules.v4 supaya berkas == aturan nyata.
# (Restore saat boot berjalan setelah unit ini dan menambah salinan -> berkas yang
#  sudah berisi tepat satu aturan membuat siklus boot berikutnya stabil.)
command -v iptables-save >/dev/null 2>&1 && iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
exit $rc
FWEOF
    chmod +x /usr/local/sbin/wibutunnel-firewall
fi
# symlink nama lama supaya unit yang sudah terpasang tetap bekerja
ln -sf /usr/local/sbin/wibutunnel-firewall /usr/local/sbin/wibutunnel-firewall.sh 2>/dev/null || true
/usr/local/sbin/wibutunnel-firewall || true

cat > /etc/systemd/system/wibutunnel-firewall.service << 'SVCEOF'
[Unit]
Description=Wibu Tunneling - Re-enforce root-only Xray API firewall
After=network.target netfilter-persistent.service
Before=xray.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/wibutunnel-firewall

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable wibutunnel-firewall.service >/dev/null 2>&1 || true

# [FIX] Timer idempoten: unit oneshot bisa kalah urutan dengan restore iptables saat boot
# (terbukti: aturan jadi 2 setelah reboot). Timer menjalankan ulang skrip (yang mendedupe)
# 2 menit setelah boot lalu tiap 5 menit -> aturan kembali tepat 1 dan tetap ditegakkan.
cat > /etc/systemd/system/wibutunnel-firewall.timer << 'TMREOF'
[Unit]
Description=Wibu Tunneling - re-enforce root-only Xray API firewall (periodik)

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=false

[Install]
WantedBy=timers.target
TMREOF
systemctl daemon-reload
systemctl enable --now wibutunnel-firewall.timer >/dev/null 2>&1 || true

iptables-save > /etc/iptables/rules.v4
# QoS
if wibu_get_script "sbin/network-tune.sh" /usr/local/sbin/network-tune; then
    echo -e "\e[1;32m[+] Skrip network-tune dari ref terpin & terverifikasi\e[0m"
else
cat > /usr/local/sbin/network-tune << 'EOF'
#!/bin/bash
# [FIX] Probe dukungan target CLASSIFY: sebagian kernel VPS tanpa modul ini, dan sebelumnya
# 4 aturan gagal setiap menit (journal spam + QoS tidak jalan diam-diam).
iptables -t mangle -F 2>/dev/null && iptables -t mangle -X 2>/dev/null
if iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1 2>/dev/null; then
    iptables -t mangle -D PREROUTING -p icmp -j CLASSIFY --set-class 1:1 2>/dev/null
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK ACK -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p tcp -m length --length 0:128 -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p udp -m length --length 0:128 -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1
else
    echo "[network-tune] Target CLASSIFY tidak didukung kernel ini - aturan QoS dilewati (bukan error)."
fi
for IFACE in $(ip -o -4 addr show | awk '{print $2}' | grep -v lo); do
    tc qdisc del dev $IFACE root 2>/dev/null
    tc qdisc add dev $IFACE root handle 1: htb default 10 2>/dev/null || { echo "[network-tune] $IFACE: HTB tidak didukung, QoS dilewati"; continue; }
    tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
    tc qdisc add dev $IFACE parent 1:1 fq_codel quantum 300 ecn
done
EOF
    chmod +x /usr/local/sbin/network-tune
fi
ln -sf /usr/local/sbin/network-tune /usr/local/sbin/network-tune.sh 2>/dev/null || true

cat > /etc/systemd/system/network-tune.service << EOF
[Unit]
Description=QoS Low Latency
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/network-tune
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now network-tune.service >/dev/null 2>&1

# Stop conflicting web servers
echo -e "\e[1;36m[+] Menghentikan web server yang konflik dengan HAProxy...\e[0m"
for svc in nginx apache2; do
    if systemctl is-active --quiet $svc; then
        echo -e "\e[1;33m[!] Menghentikan $svc...\e[0m"
        systemctl stop $svc && systemctl disable $svc
    fi
done

# SSL
systemctl stop haproxy 2>/dev/null

# [FIX] Deteksi versi certbot untuk kompatibilitas flag
if certbot --version 2>/dev/null | grep -qE "certbot 2\."; then
    # Certbot 2.x+ tidak support --register-unsafely-without-email
    certbot certonly --standalone --non-interactive --agree-tos -m "admin@${domain}" -d "$domain"
else
    certbot certonly --standalone --register-unsafely-without-email --no-eff-email --agree-tos -d "$domain"
fi

if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
    echo -e "${RED}SSL GAGAL! Pastikan domain $domain mengarah ke IP ini.${NC}"
    exit 1
fi
cat /etc/letsencrypt/live/"$domain"/fullchain.pem /etc/letsencrypt/live/"$domain"/privkey.pem > /etc/haproxy/certs/"$domain".pem
chmod 700 /etc/haproxy/certs
chmod 600 /etc/haproxy/certs/*.pem

# XRAY CORE
xray_installer_run install
# [FIX] gagal dini dengan pesan jelas bila Xray tidak terpasang
if ! command -v xray >/dev/null 2>&1 || ! id xray >/dev/null 2>&1; then
    echo -e "\\e[1;31m[FATAL] Xray gagal terpasang (binary/user 'xray' tidak ada).\\e[0m"
    echo -e "\\e[33m        Cek koneksi ke github.com/XTLS atau jalankan ulang; instalasi DIHENTIKAN sebelum merusak konfigurasi.\\e[0m"
    exit 1
fi
# user xray baru ada setelah install-release.sh di atas
chown -R xray:adm /var/log/xray
chmod 750 /var/log/xray
echo 'd /var/log/xray 0750 xray adm -' > /etc/tmpfiles.d/xray.conf

# Backup config lama
[ -f /usr/local/etc/xray/config.json ] && cp /usr/local/etc/xray/config.json "/usr/local/etc/xray/config.json.bak.$(date +%F_%H%M%S)"

# XRAY CONFIG (dengan StatsService + HandlerService)
DUMMY_UUID=$(uuidgen)
cat <<'XEOF' > /usr/local/etc/xray/config.json
{
  "log": {"access": "/var/log/xray/access.log","error": "/var/log/xray/error.log","loglevel": "info"},
  "api": {"tag": "api","services": ["StatsService", "HandlerService"]},
  "stats": {},
  "policy": {
    "levels": {"0": {"statsUserUplink": true,"statsUserDownlink": true}},
    "system": {"statsInboundUplink": true,"statsInboundDownlink": true}
  },
  "inbounds": [
    {"tag": "api","listen": "127.0.0.1","port": 10085,"protocol": "dokodemo-door","settings": {"address": "127.0.0.1"}},
    {"tag": "vless-ws-tls","port": 10086,"listen": "127.0.0.1","protocol": "vless","settings": {"clients": [], "decryption": "none"},"streamSettings": {"network": "ws","sockopt": {"acceptProxyProtocol": true},"wsSettings": {"path": "/vless"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "vless-ws-ntls","port": 10087,"listen": "127.0.0.1","protocol": "vless","settings": {"clients": [], "decryption": "none"},"streamSettings": {"network": "ws","sockopt": {"acceptProxyProtocol": true},"wsSettings": {"path": "/vless-ntls"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "vless-grpc","port": 10088,"listen": "127.0.0.1","protocol": "vless","settings": {"clients": [], "decryption": "none"},"streamSettings": {"network": "grpc","sockopt": {"acceptProxyProtocol": true},"grpcSettings": {"serviceName": "vless"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "vmess-ws-tls","port": 10089,"listen": "127.0.0.1","protocol": "vmess","settings": {"clients": []},"streamSettings": {"network": "ws","sockopt": {"acceptProxyProtocol": true},"wsSettings": {"path": "/vmess"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "vmess-ws-ntls","port": 10090,"listen": "127.0.0.1","protocol": "vmess","settings": {"clients": []},"streamSettings": {"network": "ws","sockopt": {"acceptProxyProtocol": true},"wsSettings": {"path": "/vmess-ntls"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "vmess-grpc","port": 10091,"listen": "127.0.0.1","protocol": "vmess","settings": {"clients": []},"streamSettings": {"network": "grpc","sockopt": {"acceptProxyProtocol": true},"grpcSettings": {"serviceName": "vmess"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "trojan-ws-tls","port": 10092,"listen": "127.0.0.1","protocol": "trojan","settings": {"clients": []},"streamSettings": {"network": "ws","sockopt": {"acceptProxyProtocol": true},"wsSettings": {"path": "/trojan"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}},
    {"tag": "trojan-grpc","port": 10093,"listen": "127.0.0.1","protocol": "trojan","settings": {"clients": []},"streamSettings": {"network": "grpc","sockopt": {"acceptProxyProtocol": true},"grpcSettings": {"serviceName": "trojan"}},"sniffing": {"enabled": true,"destOverride": ["http", "tls"]}}
  ],
  "outbounds": [{"protocol": "freedom","settings": {},"tag": "direct"},{"protocol": "blackhole","settings": {},"tag": "blocked"}],
  "routing": {"domainStrategy": "AsIs","rules": [{"type": "field","inboundTag": ["api"],"outboundTag": "api"},{"type": "field","outboundTag": "blocked","user": ["DUMMY-LOCK"]},{"type": "field","ip": ["geoip:private"],"outboundTag": "blocked"},{"type": "field","protocol": ["bittorrent"],"outboundTag": "blocked"}]}
}
XEOF
chown -R root:xray /usr/local/etc/xray
chmod 640 /usr/local/etc/xray/config.json
ln -sf /usr/local/etc/xray/config.json /etc/xray/config.json
chown -R root:xray /etc/xray 2>/dev/null || true
chmod 750 /etc/xray 2>/dev/null || true

# HAProxy Config
cat <<HFEOF > /etc/haproxy/haproxy.cfg

# [PORTABILITAS] Rentang versi HAProxy yang didukung cukup lebar (2.0 Ubuntu 20.04 .. 2.8 Ubuntu 24.04).
# Validasi konfigurasi lalu turunkan versi minimal kalau ada direktif yang tidak dikenal versi itu,
# supaya instalasi tidak berhenti hanya karena satu baris direktif.
if ! haproxy -c -f /etc/haproxy/haproxy.cfg >/tmp/hpcheck.log 2>&1; then
    echo -e "\e[1;33m[!] haproxy -c menolak konfigurasi -> mencoba versi minimal (tanpa direktif khusus 2.2+)\e[0m"
    grep -vE '^[[:space:]]*ssl-default-bind-ciphersuites' /etc/haproxy/haproxy.cfg > /tmp/hp.min.cfg
    if ! haproxy -c -f /tmp/hp.min.cfg >/tmp/hpcheck2.log 2>&1; then
        grep -vE '^[[:space:]]*(ssl-default-bind-ciphersuites|ssl-default-bind-options|ssl-default-bind-ciphers)' /etc/haproxy/haproxy.cfg > /tmp/hp.min.cfg
    fi
    if haproxy -c -f /tmp/hp.min.cfg >/dev/null 2>&1; then
        install -m 644 /tmp/hp.min.cfg /etc/haproxy/haproxy.cfg
        echo -e "\e[1;32m[+] Konfigurasi minimal diterima versi HAProxy ini ($(haproxy -v 2>/dev/null | head -1 | awk '{print $3}')).\e[0m"
    else
        echo -e "\e[1;31m[!] haproxy -c tetap gagal. Keluaran: $(tail -1 /tmp/hpcheck.log)\e[0m"
    fi
    rm -f /tmp/hp.min.cfg
fi
rm -f /tmp/hpcheck.log /tmp/hpcheck2.log
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon
    maxconn 100000
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client  30m
    timeout server  30m
    timeout tunnel  1h
    timeout client-fin 20s
    timeout server-fin 20s

# ===================== TAHAP 1 =====================
frontend ssl_sni
    bind 0.0.0.0:443 ssl crt /etc/haproxy/certs/${domain}.pem alpn h2,http/1.1
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.payload(0,4) -m str SSH- }
    tcp-request content accept if HTTP

    acl is_raw_ssh req.payload(0,4) -m str SSH-
    acl is_h2 ssl_fc_alpn -i h2
    acl is_xray path_beg /vless /vmess /trojan
    acl is_xray path_beg %2Fvless %2Fvmess %2Ftrojan
    acl is_telehook path_beg /telehook

    use_backend dropbear_raw if is_raw_ssh
    use_backend bk_hub443 if is_h2
    use_backend bk_hub443 if is_xray
    use_backend bk_hub443 if is_telehook
    default_backend ws_tunnel

frontend port_80_front
    bind 0.0.0.0:80
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.payload(0,4) -m str SSH- }
    tcp-request content accept if HTTP

    acl is_raw_ssh req.payload(0,4) -m str SSH-
    acl is_xray_vless path_beg /vless-ntls
    acl is_xray_vless path_beg %2Fvless-ntls
    acl is_xray_vmess path_beg /vmess-ntls
    acl is_xray_vmess path_beg %2Fvmess-ntls

    use_backend dropbear_raw if is_raw_ssh
    use_backend bk_hub80 if is_xray_vless || is_xray_vmess
    default_backend ws_tunnel

backend dropbear_raw
    mode tcp
    server local_dropbear 127.0.0.1:143 check

backend ws_tunnel
    mode tcp
    server local_ws_stunnel 127.0.0.1:10015 check

backend bk_hub443
    mode tcp
    server hub443 127.0.0.1:8444

backend bk_hub80
    mode tcp
    server hub80 127.0.0.1:8445

# ===================== TAHAP 2 =====================
listen http_hub443
    bind 127.0.0.1:8444
    mode http
    option forwardfor
    acl is_vless_grpc path_beg /vless/
    acl is_vless_grpc path_beg %2Fvless%2F
    acl is_vmess_grpc path_beg /vmess/
    acl is_vmess_grpc path_beg %2Fvmess%2F
    acl is_trojan_grpc path_beg /trojan/
    acl is_trojan_grpc path_beg %2Ftrojan%2F
    acl is_vless_ws path_beg /vless
    acl is_vless_ws path_beg %2Fvless
    acl is_vmess_ws path_beg /vmess
    acl is_vmess_ws path_beg %2Fvmess
    acl is_trojan_ws path_beg /trojan
    acl is_trojan_ws path_beg %2Ftrojan
    acl is_telehook path_beg /telehook
    acl is_telehook path_beg %2Ftelehook
    use_backend webhook_server if is_telehook
    use_backend xray_vless_grpc if is_vless_grpc
    use_backend xray_vmess_grpc if is_vmess_grpc
    use_backend xray_trojan_grpc if is_trojan_grpc
    use_backend xray_vless if is_vless_ws
    use_backend xray_vmess if is_vmess_ws
    use_backend xray_trojan if is_trojan_ws

listen http_hub80
    bind 127.0.0.1:8445
    mode http
    option forwardfor
    acl is_vless_ntls path_beg /vless-ntls
    acl is_vless_ntls path_beg %2Fvless-ntls
    acl is_vmess_ntls path_beg /vmess-ntls
    acl is_vmess_ntls path_beg %2Fvmess-ntls
    use_backend xray_vless_ntls if is_vless_ntls
    use_backend xray_vmess_ntls if is_vmess_ntls

backend xray_vless
    mode http
    server local_vless_ws 127.0.0.1:10086 send-proxy-v2 check

backend xray_vless_grpc
    mode http
    server local_vless_grpc 127.0.0.1:10088 send-proxy-v2 proto h2 check

backend xray_vmess
    mode http
    server local_vmess_ws 127.0.0.1:10089 send-proxy-v2 check

backend xray_vmess_grpc
    mode http
    server local_vmess_grpc 127.0.0.1:10091 send-proxy-v2 proto h2 check

backend xray_trojan
    mode http
    server local_trojan_ws 127.0.0.1:10092 send-proxy-v2 check

backend xray_trojan_grpc
    mode http
    server local_trojan_grpc 127.0.0.1:10093 send-proxy-v2 proto h2 check

backend xray_vless_ntls
    mode http
    server vless_ntls_server 127.0.0.1:10087 send-proxy-v2 check

backend xray_vmess_ntls
    mode http
    server vmess_ntls_server 127.0.0.1:10090 send-proxy-v2 check

backend ssh_ws_backend
    mode http
    server local_ws_stunnel 127.0.0.1:10015 check

backend webhook_server
    mode http
    server local_webhook 127.0.0.1:8443
HFEOF

# Simpan template haproxy ber-placeholder agar wibu-repair bisa rebuild tanpa
# bergantung pada folder repo (yang tidak ada di VPS hasil install).
mkdir -p /etc/wibutunnel/templates
sed "s|/etc/haproxy/certs/${domain}\.pem|/etc/haproxy/certs/\${__DOMAIN__}.pem|" \
    /etc/haproxy/haproxy.cfg > /etc/wibutunnel/templates/haproxy.cfg
chmod 644 /etc/wibutunnel/templates/haproxy.cfg

# [FIX-K1] Rantai pasang: kode diambil dari REF TERPIN (bukan main) dan setiap berkas
# diverifikasi terhadap SHA256SUMS milik ref yang sama. Fail-closed; bypass hanya via
# WIBUTUNNEL_ALLOW_UNVERIFIED=1 (peringatan besar + dicatat). Untuk upgrade, naikkan tag.
WIBU_REF="${WIBU_REF:-v4.1.5}"   # tag rilis TETAP (immutable)
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${WIBU_REF}"
WIBU_MANIFEST_CACHE="/etc/wibutunnel/tmp/wibu-manifest"
wibu_manifest_fetch() {
    [[ -s "$WIBU_MANIFEST_CACHE" ]] && return 0
    mkdir -p /etc/wibutunnel/tmp
    local cb="cb=$(date +%s)$$"
    # [FIX] API GitHub = sumber OTORITATIF (isi per ref, tak lewat CDN raw). Diuji: setelah tag
    # dipindah, raw menyajikan MANIFEST LAMA (55 entri vs 57 di API) dan cache-buster `?cb=`
    # TIDAK menolong -> verifikasi fail-closed menolak berkas yang sudah ada.
    curl -4 -fsSL --retry 2 --connect-timeout 10 --max-time 40 \
        -H 'Accept: application/vnd.github.raw' -H 'User-Agent: wibutunnel-installer' \
        -o "$WIBU_MANIFEST_CACHE" "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/SHA256SUMS?ref=${WIBU_REF}" 2>/dev/null
    [[ -s "$WIBU_MANIFEST_CACHE" ]] || curl -4 -fsSL --retry 3 --connect-timeout 10 --max-time 40 -o "$WIBU_MANIFEST_CACHE" "${GITHUB_RAW}/SHA256SUMS?${cb}" 2>/dev/null
    [[ -s "$WIBU_MANIFEST_CACHE" ]] || curl -4 -fsSL --retry 2 --connect-timeout 10 --max-time 40 -o "$WIBU_MANIFEST_CACHE" \
        "https://cdn.jsdelivr.net/gh/${GITHUB_USER}/${REPO_NAME}@${WIBU_REF}/SHA256SUMS" 2>/dev/null
    [[ -s "$WIBU_MANIFEST_CACHE" ]]
}
wibu_verify_file() {   # $1=berkas lokal  $2=nama di manifest (jalur repo)
    local f="$1" name="$2" want got
    wibu_manifest_fetch || { echo -e "\e[31m[!] Manifest SHA256SUMS (ref ${WIBU_REF}) tidak dapat diambil.\e[0m"; return 1; }
    want="$(awk -v n="$name" '$2 == n {print $1; exit}' "$WIBU_MANIFEST_CACHE")"
    [[ -n "$want" ]] || { echo -e "\e[31m[!] $name tidak terdaftar di SHA256SUMS.\e[0m"; return 1; }
    got="$(sha256sum "$f" 2>/dev/null | awk '{print $1}')"
    [[ "$got" == "$want" ]] || { echo -e "\e[31m[!] HASH TIDAK COCOK: $name\e[0m"
                                 echo -e "\e[31m    harap=$want\n    dapat=$got\e[0m"; return 1; }
    return 0
}

# [FIX] Download Menu - $RANDOM tanpa backslash agar benar-benar cache-bust
download_menu() {
    local url="${GITHUB_RAW}/$1?v=$RANDOM"
    local dest="/usr/local/bin/$2"
    local tmp_file="/etc/wibutunnel/tmp/$2"
    local http_code
    
    # Download with HTTP status code
    # [FIX-IPv6] paksa IPv4 + timeout: di VPS dengan IPv6 blackhole, tanpa -4 setiap unduhan
    # menunggu ~24 dtk lalu gagal (wget malah menggantung). Mirror dicoba untuk SEMUA kegagalan.
    http_code=$(curl -4 -sS -L --connect-timeout 10 --max-time 60 -w '%{http_code}' -o "$tmp_file" "$url" 2>/dev/null)

    if [[ "$http_code" != "200" ]]; then
        echo -e "\e[33m[!] Unduhan $2 gagal (HTTP ${http_code:-timeout}). Mencoba mirror jsdelivr...\e[0m"
        url="https://cdn.jsdelivr.net/gh/${GITHUB_USER}/${REPO_NAME}@${WIBU_REF}/$1"
        http_code=$(curl -4 -sS -L --connect-timeout 10 --max-time 60 -w '%{http_code}' -o "$tmp_file" "$url" 2>/dev/null)
    fi
    
    # Validate HTTP status
    if [[ "$http_code" != "200" ]]; then
        echo -e "\e[31m[!] Gagal mengunduh $2 (HTTP $http_code)\e[0m"
        rm -f "$tmp_file"
        return 1
    fi
    
    # Validate file exists and has reasonable size (not empty, not > 10MB)
    if [[ ! -s "$tmp_file" ]]; then
        echo -e "\e[31m[!] File $2 kosong\e[0m"
        rm -f "$tmp_file"
        return 1
    fi
    
    local file_size=$(stat -c%s "$tmp_file" 2>/dev/null || echo 0)
    if [[ $file_size -gt 10485760 ]]; then
        echo -e "\e[31m[!] File $2 terlalu besar ($(($file_size/1024))KB)\e[0m"
        rm -f "$tmp_file"
        return 1
    fi
    
    # [FIX-K1] Verifikasi hash terhadap SHA256SUMS ref terpin (fail-closed)
    if ! wibu_verify_file "$tmp_file" "$1"; then
        if [[ "${WIBUTUNNEL_ALLOW_UNVERIFIED:-0}" == "1" ]]; then
            echo -e "\e[1;31m[PERINGATAN BESAR] $2 TIDAK TERVERIFIKASI — lanjut karena WIBUTUNNEL_ALLOW_UNVERIFIED=1\e[0m"
            echo "$(date -Is) bypass unverified: $1" >> /var/log/wibutunnel-installer.log 2>/dev/null
        else
            echo -e "\e[31m[!] $2 DITOLAK: hash tidak cocok/berkas tak terdaftar. Instalasi dihentikan.\e[0m"
            echo -e "\e[33m    Ref: ${WIBU_REF}. Override sadar (tidak disarankan): WIBU_REF=main WIBUTUNNEL_ALLOW_UNVERIFIED=1\e[0m"
            rm -f "$tmp_file"
            return 1
        fi
    fi

    # Validate shebang and syntax
    local shebang=$(head -n 1 "$tmp_file")
    if [[ "$shebang" =~ ^#!.*(bash|sh) ]]; then
        if ! bash -n "$tmp_file" 2>/dev/null; then
            echo -e "\e[31m[!] File $2 gagal syntax check (bash -n)\e[0m"
            rm -f "$tmp_file"
            return 1
        fi
    elif [[ "$shebang" =~ ^#!.*python ]]; then
        if ! python3 -m py_compile "$tmp_file" 2>/dev/null; then
            echo -e "\e[31m[!] File $2 gagal syntax check (python3 -m py_compile)\e[0m"
            rm -f "$tmp_file"
            return 1
        fi
        rm -rf /etc/wibutunnel/tmp/__pycache__
    else
        echo -e "\e[31m[!] File $2 bukan script bash/python valid\e[0m"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$dest"
    chmod +x "$dest"
    return 0
}

# download_menu mengembalikan 1 bila gagal; tanpa cek, instalasi lanjut dengan file hilang.
_dl_fail=0
_need() { download_menu "$1" "$2" || { echo -e "\e[31m[!] Gagal install $2\e[0m"; _dl_fail=1; }; }

_need "menu/menu.sh" "menu"
_need "menu/m-vless.sh" "m-vless"
_need "menu/m-vmess.sh" "m-vmess"
_need "menu/m-trojan.sh" "m-trojan"
_need "menu/m-setting.sh" "m-setting"
_need "menu/xp.sh" "xp"
_need "menu/m-backup.sh" "m-backup"
_need "menu/menu-lock.sh" "menu-lock"
_need "menu/menu-unlock.sh" "menu-unlock"
_need "menu/menu-recovery.sh" "menu-recovery"
_need "menu/cek-trafik.sh" "cek-trafik"
_need "menu/m-ssh.sh" "m-ssh"
_need "common.sh" "common.sh"
_need "menu/bot-daemon.sh" "bot-daemon"


# =========================================================
# SISTEM RECOVERY CENTER & ALGOJO MONITOR (v4.0 PERFECT)
# =========================================================
touch /etc/wibutunnel/locked_users.db /etc/wibutunnel/limit_ip.db /etc/wibutunnel/limit_bw.db /etc/wibutunnel/user_usage.db /etc/wibutunnel/ssh_pass.db
chmod 600 /etc/wibutunnel/*.db


# Scripts lock-user, unlock-user, algojo, unlocker diunduh dari repo (versi patched)
# Download sbin scripts (source of truth — patched versions)
_need "sbin/algojo-wibu" "algojo-wibu-dl"
_need "sbin/algojo-kuota" "algojo-kuota-dl"
_need "sbin/algojo-ssh" "algojo-ssh-dl"
_need "sbin/lock-user" "lock-user-dl"
_need "sbin/unlock-user" "unlock-user-dl"
_need "sbin/unlocker-wibu" "unlocker-wibu-dl"
_need "sbin/algojo-expired" "algojo-expired-dl"
_need "sbin/algojo-expired-daemon" "algojo-expired-daemon"
_need "sbin/ws-stunnel" "ws-stunnel"
_need "sbin/wibu-repair" "wibu-repair-dl"
_need "sbin/wibu-audit-akun" "wibu-audit-akun-dl"
_need "sbin/wibu-daemon" "wibu-daemon-dl"

# Install sbin scripts
for s in algojo-wibu algojo-kuota algojo-ssh lock-user unlock-user unlocker-wibu algojo-expired algojo-expired-daemon ws-stunnel wibu-repair wibu-daemon wibu-audit-akun; do
    if [ -f "/usr/local/bin/${s}-dl" ]; then
        mv "/usr/local/bin/${s}-dl" "/usr/local/sbin/${s}"
    fi
    if [ -f "/usr/local/sbin/${s}" ]; then
        cp -f "/usr/local/sbin/${s}" "/usr/local/bin/${s}" 2>/dev/null || ln -sf "/usr/local/sbin/${s}" "/usr/local/bin/${s}"
        chmod +x "/usr/local/bin/${s}" "/usr/local/sbin/${s}" 2>/dev/null || true
    elif [ -f "/usr/local/bin/${s}" ]; then
        cp -f "/usr/local/bin/${s}" "/usr/local/sbin/${s}" 2>/dev/null || ln -sf "/usr/local/bin/${s}" "/usr/local/sbin/${s}"
        chmod +x "/usr/local/bin/${s}" "/usr/local/sbin/${s}" 2>/dev/null || true
    fi
done


# BOT TELEGRAM CONFIG
# setup.sh sebelumnya tidak pernah menulis bot.conf, jadi telegram-bot start tanpa token
# dan getUpdates gagal sampai admin menjalankan m-setting [6] secara manual.
if [[ ! -s /etc/wibutunnel/bot.conf ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  KONFIGURASI BOT TELEGRAM (opsional, Enter untuk lewati)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -r -p "Bot Token (dari @BotFather): " _bt
    read -r -p "Chat ID admin (dari @userinfobot): " _bc
    if [[ -n "$_bt" && -n "$_bc" ]]; then
        printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "$_bt" "$_bc" > /etc/wibutunnel/bot.conf
        chmod 600 /etc/wibutunnel/bot.conf
        echo -e "\e[1;32m[+] bot.conf tersimpan\e[0m"
    else
        echo -e "\e[1;33m[!] Dilewati. Aktifkan nanti: menu -> Settings -> Setup Bot Telegram\e[0m"
    fi
fi

# WIBU DAEMON SERVICE
cat << 'EOF' > /etc/systemd/system/wibu-daemon.service
[Unit]
Description=Wibu Tunneling Real-Time Algojo Daemon
After=network.target xray.service
Wants=xray.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
ExecStart=/usr/local/bin/wibu-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/algojo-expired.service
[Unit]
Description=Real-time VPN Account Expiry Enforcement
After=xray.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/local/bin/algojo-expired-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/telegram-bot.service
[Unit]
Description=Telegram Bot Polling Daemon
After=network.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/local/bin/bot-daemon
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/dropbear.service
[Unit]
Description=Dropbear Enhanced (SSH Tunneling)
After=network.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
EnvironmentFile=-/etc/default/dropbear
ExecStart=/usr/sbin/dropbear -F -E -p ${DROPBEAR_PORT} $DROPBEAR_EXTRA_ARGS
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/ws-stunnel.service
[Unit]
Description=SSH WebSocket Python Tunnel (ws-stunnel)
After=network.target dropbear.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-stunnel
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/dropbear /etc/wibutunnel
echo "NO_START=0" > /etc/default/dropbear
echo "DROPBEAR_PORT=143" >> /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-b /etc/wibutunnel/ssh-banner -W 32768 -w -g -K 60 -I 300 -p 109 -p 127.0.0.1:2222"' >> /etc/default/dropbear
echo 'DROPBEAR_BANNER="/etc/wibutunnel/ssh-banner"' >> /etc/default/dropbear
echo "DROPBEAR_RECEIVE_WINDOW=65536" >> /etc/default/dropbear
cat << 'BEOF' > /etc/wibutunnel/ssh-banner
<p style="text-align:center; line-height:0.9; margin:0; padding:0;">
<font color='#00ff36'><b>WIBU VPN STORE</b></font><br>
<font color='#5539fb'>===============================</font><br>
<font color='#aa1df8'>GUNAKAN DENGAN BIJAK</font><br>
<font color='#5539fb'>===============================</font><br>
<font color='#0056ff'>NO DDOS</font><br>
<font color='#0080bf'>NO HACKING</font><br>
<font color='#00ab80'>NO TORRENT</font><br>
<font color='#00d540'>NO PORN</font><br>
<font color='#ff0000'>MELANGGAR = BANNED PERMANENT</font><br>
<font color='#55aa75'>===============================</font><br>
<font color='#aa55b5'>Telegram : <a href="https://t.me/wibuvpnstore" target="_blank" style="color:#00ffff;">@wibuvpnstore</a></font><br>
<font color='#aa55b5'>WhatsApp : <a href="https://wa.me/6287757315408" target="_blank" style="color:#00ffff;">62877-5731-5408</a></font><br>
<font color='#aa55b5'>Grup WA : <a href="https://chat.whatsapp.com/La5nXNSOYQj8cZ5Ugyk3l8" target="_blank" style="color:#00ffff;">FREE CONFIG By WIBUVPN</a></font><br>
<font color='#00ff36'><b>VPN PREMIUM 7K / 30 HARI</b></font><br>
<font color='#aa55b5'>THANK YOU FOR USING OUR SERVICE</font><br>
<font color='#0000ff'>===============================</font>
</p>
BEOF
cat << 'REOF' > /etc/wibutunnel/ws-response
HTTP/1.1 101 <b><font color=blue>WIBUVPNSTORE</font></b>
Upgrade: websocket
Connection: Upgrade
REOF
groupadd -f ssh_tunnel

dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key 2>/dev/null || true
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key 2>/dev/null || true
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key 2>/dev/null || true

chmod +x /usr/local/bin/bot-daemon

systemctl daemon-reload
systemctl enable wibu-daemon || { echo "Failed to enable wibu-daemon"; exit 1; }
systemctl restart wibu-daemon || { echo "Failed to start wibu-daemon"; exit 1; }
sleep 2
systemctl is-active --quiet wibu-daemon || { echo "wibu-daemon failed to start"; systemctl status wibu-daemon; exit 1; }

systemctl daemon-reload
# [FIX] Unit bot hanya diaktifkan kalau tokennya ada. Sebelumnya selalu di-enable sehingga
# `systemctl status telegram-bot` menampilkan "failed" pada instalasi yang belum diisi token.
if [[ -s /etc/wibutunnel/bot.conf ]] && grep -qE '^BOT_TOKEN="[^"]+' /etc/wibutunnel/bot.conf 2>/dev/null; then
    systemctl enable telegram-bot.service >/dev/null 2>&1 || true
    systemctl restart telegram-bot.service >/dev/null 2>&1 || true
else
    systemctl disable telegram-bot.service >/dev/null 2>&1 || true
    systemctl stop telegram-bot.service >/dev/null 2>&1 || true
    # Hapus status "failed" sisa percobaan sebelumnya supaya `systemctl status` bersih.
    systemctl reset-failed telegram-bot.service >/dev/null 2>&1 || true
    echo -e "\e[1;33m[i] Bot Telegram belum diatur -> unit tidak diaktifkan (Setting -> [6] Setup Bot Telegram).\e[0m"
fi
systemctl enable dropbear.service ws-stunnel.service >/dev/null 2>&1
# [FIX] Bersihkan status 'failed' sisa percobaan sebelum konfigurasi ditulis (di Debian 12
# dropbear/haproxy sempat gagal start dengan config bawaan paket -> `systemctl status` menampilkan
# 'failed' walau layanannya sudah berjalan normal setelah installer menulis konfigurnya).
systemctl reset-failed dropbear.service haproxy.service ws-stunnel.service >/dev/null 2>&1 || true
systemctl restart dropbear.service ws-stunnel.service >/dev/null 2>&1
systemctl enable algojo-expired.service >/dev/null 2>&1
systemctl restart algojo-expired.service >/dev/null 2>&1

# Logrotate & Cron
cat << 'LREOF' > /etc/logrotate.d/xray
/var/log/xray/*.log {
    su xray adm
    create 0640 xray adm
    daily
    rotate 3
    size 10M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
LREOF

cat <<EOF > /usr/local/bin/watchdog.sh
#!/bin/bash
systemctl is-active --quiet xray || systemctl restart xray
systemctl is-active --quiet haproxy || systemctl restart haproxy
# [PORTABILITAS] Ubuntu membawa profil AppArmor untuk haproxy; profil itu bisa memblokir
# sertifikat/chroot sehingga haproxy gagal start walau `haproxy -c` lolos. Kalau terdeteksi
# penolakan AppArmor, ubah profil ke mode complain lalu coba lagi.
if ! systemctl is-active --quiet haproxy; then
    if command -v aa-status >/dev/null 2>&1 && aa-status 2>/dev/null | grep -q haproxy \
       && journalctl -k --no-pager -n 200 2>/dev/null | grep -qi 'apparmor.*haproxy'; then
        echo -e "\e[1;33m[!] AppArmor memblokir haproxy -> profil diubah ke complain mode\e[0m"
        aa-complain /etc/apparmor.d/usr.sbin.haproxy >/dev/null 2>&1 || true
        systemctl restart haproxy >/dev/null 2>&1 || true
    fi
    systemctl is-active --quiet haproxy || echo -e "\e[1;31m[!] haproxy belum aktif. Periksa: journalctl -u haproxy -n 40\e[0m"
fi
EOF
chmod +x /usr/local/bin/watchdog.sh

systemctl enable cron >/dev/null 2>&1

crontab -l 2>/dev/null | grep -v -E "xp|reboot|watchdog|algojo|unlocker|drop_caches|renew-cert-wibu" | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/watchdog.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/xp") | crontab -
# DIHAPUS: drop_caches + swapoff/on tiap 00:00 menyebabkan OOM-kill xray
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/sbin/unlocker-wibu") | crontab -

# SSL Auto Renewal
cat > /usr/local/bin/renew-cert-wibu.sh << 'RCEOF'
#!/bin/bash
domain=$(cat /etc/xray/domain 2>/dev/null)
[[ -z "$domain" ]] && exit 1
systemctl stop haproxy
certbot renew --quiet --no-self-upgrade --standalone
cat /etc/letsencrypt/live/$domain/fullchain.pem /etc/letsencrypt/live/$domain/privkey.pem > /etc/haproxy/certs/$domain.pem
chmod 700 /etc/haproxy/certs
chmod 600 /etc/haproxy/certs/*.pem
systemctl start haproxy || { echo "Failed to start haproxy"; exit 1; }
sleep 2
systemctl is-active --quiet haproxy || { echo "haproxy failed to start"; systemctl status haproxy; exit 1; }
RCEOF
chmod +x /usr/local/bin/renew-cert-wibu.sh
(crontab -l 2>/dev/null; echo "0 4 * * * /usr/local/bin/renew-cert-wibu.sh") | crontab -

# Service Override
mkdir -p /etc/systemd/system/haproxy.service.d /etc/systemd/system/xray.service.d
cat <<EOF > /etc/systemd/system/haproxy.service.d/override.conf
[Unit]
After=xray.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Restart=on-failure
RestartSec=5s
EOF
cat <<EOF > /etc/systemd/system/xray.service.d/override.conf
[Unit]
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Restart=on-failure
RestartSec=5s
EOF

# Flush all pending writes to disk
sync
sleep 1

systemctl daemon-reload
systemctl enable xray haproxy cron || { echo "Failed to enable services"; exit 1; }
systemctl start cron
systemctl restart xray haproxy || { echo "Failed to restart services"; exit 1; }
sleep 2
systemctl is-active --quiet xray || { echo "xray failed to start"; systemctl status xray; exit 1; }
systemctl is-active --quiet haproxy || { echo "haproxy failed to start"; systemctl status haproxy; exit 1; }

# Pastikan tidak ada webhook aktif: webhook + getUpdates saling bertabrakan (Telegram error 409)
source /etc/wibutunnel/bot.conf 2>/dev/null
if [[ -n "$BOT_TOKEN" ]]; then
    curl -4 -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook" >/dev/null 2>&1
fi

dos2unix /usr/local/bin/* /usr/local/sbin/* >/dev/null 2>&1

# Auto-start menu setelah login. Cek baris perintah persis, bukan kata "menu":
# komentar "# Auto-start menu" membuat grep -q "menu" selalu cocok dan blok ini
# tidak pernah jalan (bug lama).
if ! grep -qx 'menu' /root/.profile 2>/dev/null; then
    echo 'clear' >> /root/.profile
    echo 'menu' >> /root/.profile
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "\e[1;36m[+] Verifikasi Akhir Instalasi...\e[0m"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl is-active --quiet xray && echo -e "Xray Service        : \e[32m[OK]\e[0m" || echo -e "Xray Service        : \e[31m[FAIL]\e[0m"
systemctl is-active --quiet haproxy && echo -e "HAProxy Service     : \e[32m[OK]\e[0m" || echo -e "HAProxy Service     : \e[31m[FAIL]\e[0m"
ss -tlnp | grep -q ":443" && echo -e "Port 443            : \e[32m[OK]\e[0m" || echo -e "Port 443            : \e[31m[FAIL]\e[0m"
ss -tlnp | grep -q ":80" && echo -e "Port 80             : \e[32m[OK]\e[0m" || echo -e "Port 80             : \e[31m[FAIL]\e[0m"
haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 && echo -e "HAProxy Config      : \e[32m[OK]\e[0m" || echo -e "HAProxy Config      : \e[31m[FAIL]\e[0m"
[ -f /etc/haproxy/certs/$domain.pem ] && echo -e "SSL Certificate     : \e[32m[OK]\e[0m" || echo -e "SSL Certificate     : \e[31m[FAIL]\e[0m"
ss -tlnp | grep -q ":10085" && echo -e "Xray API (10085)    : \e[32m[OK]\e[0m" || echo -e "Xray API (10085)    : \e[33m[WARNING]\e[0m"
systemctl is-active --quiet wibu-daemon && echo -e "Algojo Daemon       : \e[32m[OK]\e[0m" || echo -e "Algojo Daemon       : \e[31m[FAIL]\e[0m"

if [[ "${_dl_fail:-0}" == "1" ]]; then
    echo -e "\e[1;31m[!] Ada file yang gagal diunduh. Instalasi TIDAK lengkap.\e[0m"
    echo -e "\e[1;33m    Perbaiki koneksi lalu jalankan ulang setup.sh, atau pakai m-setting [5].\e[0m"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# [FIX] Tulis ULANG penanda versi di akhir: data lama yang dipulihkan dari backup bisa
# mengembalikan /etc/wibutunnel/version ke versi lama sehingga dashboard menampilkan versi salah.
echo "4.1.5" > /etc/wibutunnel/version

echo -e "         \e[1;32mINSTALASI SELESAI DENGAN SUKSES!\e[0m         "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " Ketik \e[1;36mmenu\e[0m untuk membuka panel admin."
echo ""
read -r -p " Apakah Anda ingin reboot VPS sekarang? [y/N]: " ans_reboot
if [[ "$ans_reboot" =~ ^[Yy]$ ]]; then
    echo -e "\e[1;33m[!] Rebooting VPS...\e[0m"
    reboot
else
    echo -e "\e[1;32m[✓] Membuka menu WIBUTUNNEL...\e[0m"
    sleep 1
    exec menu
fi
