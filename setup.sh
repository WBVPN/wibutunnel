#!/bin/bash
# ==========================================
# MASTER INSTALLER WIBU TUNNELING - v4.0 KURUMI
# Zero-Lag Queue Daemon + Security Patch + Recovery System
# ==========================================

# [FIX] Root check harus paling awal sebelum operasi apapun
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31mError: Harus dijalankan sebagai root!\e[0m"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo -e "\e[31m[GAGAL] Hanya mendukung Ubuntu/Debian!\e[0m"
    exit 1
fi

MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com)
clear
echo -e "\e[1;36m[+] Memeriksa Lisensi Script...\e[0m"

LINK_IZIN="https://raw.githubusercontent.com/WBVPN/wibutunnel/main/izin.txt"
GET_DATA=$(curl -sS --max-time 10 $LINK_IZIN | grep -w "$MYIP")

CLIENT_NAME=$(echo "$GET_DATA" | awk '{print $2}' | tr -d '\r' | tr -d ' ')
EXP_DATE=$(echo "$GET_DATA" | awk '{print $3}' | tr -d '\r' | tr -d ' ')
REGISTERED_IP=$(echo "$GET_DATA" | awk '{print $4}' | tr -d '\r' | tr -d ' ')

if [[ "$MYIP" == "$REGISTERED_IP" ]]; then
    if [[ "${EXP_DATE,,}" != "lifetime" ]]; then
        DATE_NOW=$(date +%s)
        DATE_EXP=$(date -d "$EXP_DATE" +%s 2>/dev/null)
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
    sleep 1
else
    clear
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;31m                 AKSES DITOLAK!                   \e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;33m IP VPS Anda  : $MYIP\e[0m"
    echo -e "\e[1;33m Status       : Ilegal / Tidak Terdaftar\e[0m"
    echo -e "\e[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    exit 1
fi

GITHUB_USER="WBVPN"
REPO_NAME="wibutunnel"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main"

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
        sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
        update-grub >/dev/null 2>&1
    fi
fi
echo -e "\e[1;32m[+] IPv6 berhasil dimatikan secara permanen!\e[0m"

# DOMAIN INPUT
while true; do
    read -p "Masukkan Domain Anda: " domain
    if [[ -z "$domain" ]]; then
        echo -e "\e[31m[!] Domain tidak boleh kosong!\e[0m"
        continue
    fi

    if ! command -v dig >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y dnsutils >/dev/null 2>&1
    fi

    IP_DOMAIN=$(dig +short "$domain" | head -n 1)

    if [[ -z "$IP_DOMAIN" ]]; then
        echo -e "\e[1;31m[!] Domain tidak valid!\e[0m"
        continue
    fi

    if [[ "$IP_DOMAIN" == "$MYIP" ]]; then
        echo -e "\e[1;32m[+] Pointing Sukses!\e[0m"
        break
    else
        echo -e "\e[1;33m[!] IP Domain berbeda dengan IP VPS.\e[0m"
        read -p "Lanjutkan dengan mode Cloudflare? (y/n): " lanjut
        [[ "$lanjut" == "y" || "$lanjut" == "Y" ]] && break || continue
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
systemctl enable --now ntp >/dev/null 2>&1

mkdir -p /etc/xray /usr/local/etc/xray /etc/haproxy/certs /etc/wibutunnel /etc/wibutunnel/tmp
chmod 700 /etc/wibutunnel /etc/wibutunnel/tmp
echo "$domain" > /etc/xray/domain
echo "$domain" > /root/domain

# [PATCH VERSION] Teks versi yang akan tampil di Dashboard
echo "4.0 Kurumi" > /etc/wibutunnel/version

# Dummy users
echo "dummy-tls:Lifetime" > /etc/xray/vless_exp.conf
echo "dummy-ntls:Lifetime" >> /etc/xray/vless_exp.conf
echo "dummy-grpc:Lifetime" >> /etc/xray/vless_exp.conf
echo "dummy-vmess-tls:Lifetime" > /etc/xray/vmess_exp.conf
echo "dummy-vmess-ntls:Lifetime" >> /etc/xray/vmess_exp.conf
echo "dummy-vmess-grpc:Lifetime" >> /etc/xray/vmess_exp.conf
echo "dummy-trojan-tls:Lifetime" > /etc/xray/trojan_exp.conf
echo "dummy-trojan-grpc:Lifetime" >> /etc/xray/trojan_exp.conf

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

cat <<EOF > /etc/security/limits.conf
root soft nofile 512000
root hard nofile 512000
* soft nofile 512000
* hard nofile 512000
EOF

# INSTALL PAKET (dibersihkan dari bloat nginx/python3/socat)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl jq uuid-runtime haproxy certbot cron net-tools zip unzip wget iptables iptables-persistent iproute2 bc logrotate dos2unix

# [FIX] Enable iptables-persistent agar rules survive reboot
systemctl enable netfilter-persistent >/dev/null 2>&1 || true

if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,nosuid,nodev,noexec,mode=1777,size=100M 0 0" >> /etc/fstab
    mount -o remount /tmp
fi

if ! grep -q "tmpfs /var/log/xray" /etc/fstab; then
    echo "tmpfs /var/log/xray tmpfs defaults,nosuid,nodev,noexec,mode=0755,uid=65534,gid=65534,size=100M 0 0" >> /etc/fstab
    mkdir -p /var/log/xray
    mount /var/log/xray 2>/dev/null || true
fi
chown -R nobody:nogroup /var/log/xray
chmod 755 /var/log/xray

# Anti-Torrent
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

iptables-save > /etc/iptables/rules.v4
# QoS
cat > /usr/local/sbin/network-tune.sh << 'EOF'
#!/bin/bash
iptables -t mangle -F && iptables -t mangle -X
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK ACK -j CLASSIFY --set-class 1:1
iptables -t mangle -A PREROUTING -p tcp -m length --length 0:128 -j CLASSIFY --set-class 1:1
iptables -t mangle -A PREROUTING -p udp -m length --length 0:128 -j CLASSIFY --set-class 1:1
iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1
for IFACE in $(ip -o -4 addr show | awk '{print $2}' | grep -v lo); do
    tc qdisc del dev $IFACE root 2>/dev/null
    tc qdisc add dev $IFACE root handle 1: htb default 10
    tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
    tc qdisc add dev $IFACE parent 1:1 fq_codel quantum 300 ecn
done
EOF
chmod +x /usr/local/sbin/network-tune.sh

cat > /etc/systemd/system/network-tune.service << EOF
[Unit]
Description=QoS Low Latency
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/network-tune.sh
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now network-tune.service >/dev/null 2>&1

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

# XRAY CORE
curl -sS -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh | bash -s -- install

# Backup config lama
[ -f /usr/local/etc/xray/config.json ] && cp /usr/local/etc/xray/config.json "/usr/local/etc/xray/config.json.bak.$(date +%F_%H%M%S)"

# XRAY CONFIG (dengan StatsService + HandlerService)
DUMMY_UUID=$(uuidgen)
cat <<'XEOF' > /usr/local/etc/xray/config.json
{
  "log": {"access": "/var/log/xray/access.log","error": "/var/log/xray/error.log","loglevel": "warning"},
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

# HAProxy Config
cat <<HFEOF > /etc/haproxy/haproxy.cfg
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

frontend ssl_sni
    bind *:443 ssl crt /etc/haproxy/certs/${domain}.pem alpn h2,http/1.1
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

frontend vless_ntls_front
    bind *:80
    mode http
    option forwardfor
    acl is_vless_ntls path_beg /vless-ntls
    acl is_vless_ntls path_beg %2Fvless-ntls
    acl is_vmess_ntls path_beg /vmess-ntls
    acl is_vmess_ntls path_beg %2Fvmess-ntls
    use_backend xray_vless_ntls if is_vless_ntls
    use_backend xray_vmess_ntls if is_vmess_ntls

backend xray_vless_ntls
    mode http
    server vless_ntls_server 127.0.0.1:10087 send-proxy-v2 check
backend xray_vmess_ntls
    mode http
    server vmess_ntls_server 127.0.0.1:10090 send-proxy-v2 check

backend webhook_server
    mode http
    server local_webhook 127.0.0.1:8443
HFEOF

# Bypass GitHub 429 Rate Limit menggunakan GHProxy
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main"

# [FIX] Download Menu - $RANDOM tanpa backslash agar benar-benar cache-bust
download_menu() {
    local url="${GITHUB_RAW}/$1?v=$RANDOM"
    local dest="/usr/local/bin/$2"
    curl -sS -L -o "/etc/wibutunnel/tmp/$2" "$url"
    
    # Validasi apakah file yang diunduh adalah bash script (bukan HTML 429 Error)
    if grep -q "429: Too Many Requests" "/etc/wibutunnel/tmp/$2"; then
        echo -e "\e[31m[!] Terkena Rate Limit GitHub saat mengunduh $2. Mencoba mirror lain...\e[0m"
        url="https://cdn.jsdelivr.net/gh/${GITHUB_USER}/${REPO_NAME}@main/$1"
        curl -sS -L -o "/etc/wibutunnel/tmp/$2" "$url"
    fi
    
    if [ -s "/etc/wibutunnel/tmp/$2" ]; then
        mv "/etc/wibutunnel/tmp/$2" "$dest"
        chmod +x "$dest"
    else
        echo -e "\e[31m[!] Gagal mengunduh $2\e[0m"
    fi
}

download_menu "menu/menu.sh" "menu"
download_menu "menu/m-vless.sh" "m-vless"
download_menu "menu/m-vmess.sh" "m-vmess"
download_menu "menu/m-trojan.sh" "m-trojan"
download_menu "menu/m-setting.sh" "m-setting"
download_menu "menu/xp.sh" "xp"
download_menu "menu/m-backup.sh" "m-backup"
download_menu "menu/menu-lock.sh" "menu-lock"
download_menu "menu/menu-unlock.sh" "menu-unlock"
download_menu "menu/menu-recovery.sh" "menu-recovery"
download_menu "menu/cek-trafik.sh" "cek-trafik"
download_menu "common.sh" "common.sh"
download_menu "menu/bot-daemon.sh" "bot-daemon"
download_menu "menu/bot-webhook.sh" "bot-webhook"


# =========================================================
# SISTEM RECOVERY CENTER & ALGOJO MONITOR (v4.0 PERFECT)
# =========================================================
touch /etc/wibutunnel/locked_users.db /etc/wibutunnel/limit_ip.db /etc/wibutunnel/limit_bw.db /etc/wibutunnel/user_usage.db
chmod 600 /etc/wibutunnel/*.db


# Scripts lock-user, unlock-user, algojo, unlocker diunduh dari repo (versi patched)
# Download sbin scripts (source of truth — patched versions)
download_menu "sbin/algojo-wibu" "algojo-wibu-dl"
download_menu "sbin/algojo-kuota" "algojo-kuota-dl"
download_menu "sbin/lock-user" "lock-user-dl"
download_menu "sbin/unlock-user" "unlock-user-dl"
download_menu "sbin/unlocker-wibu" "unlocker-wibu-dl"

# Install sbin scripts
for s in algojo-wibu algojo-kuota lock-user unlock-user unlocker-wibu; do
    if [ -f "/usr/local/bin/${s}-dl" ]; then
        mv "/usr/local/bin/${s}-dl" "/usr/local/sbin/${s}"
        chmod +x "/usr/local/sbin/${s}"
    fi
done
# lock-user and unlock-user go to /usr/local/bin/
for s in lock-user unlock-user; do
    if [ -f "/usr/local/sbin/${s}" ]; then
        mv "/usr/local/sbin/${s}" "/usr/local/bin/${s}"
        chmod +x "/usr/local/bin/${s}"
    fi
done


# WIBU DAEMON
cat << 'WDEOF' > /usr/local/bin/wibu-daemon
#!/bin/bash
while true; do
    /usr/local/sbin/algojo-wibu >/dev/null 2>&1
    /usr/local/sbin/algojo-kuota >/dev/null 2>&1
    sleep 10
done
WDEOF
chmod +x /usr/local/bin/wibu-daemon

cat << 'EOF' > /etc/systemd/system/wibu-daemon.service
[Unit]
Description=Wibu Tunneling Real-Time Algojo Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/wibu-daemon
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/telegram-webhook.socket
[Unit]
Description=Telegram Webhook Socket

[Socket]
ListenStream=127.0.0.1:8443
Accept=yes

[Install]
WantedBy=sockets.target
EOF

cat << 'EOF' > /etc/systemd/system/telegram-webhook@.service
[Unit]
Description=Telegram Webhook Service

[Service]
ExecStart=/usr/local/bin/bot-webhook
StandardInput=socket
StandardOutput=socket
User=root
EOF

chmod +x /usr/local/bin/wibu-daemon
chmod +x /usr/local/sbin/algojo-wibu 2>/dev/null || true
chmod +x /usr/local/sbin/algojo-kuota 2>/dev/null || true
chmod +x /usr/local/bin/bot-daemon
chmod +x /usr/local/bin/bot-webhook

systemctl daemon-reload
systemctl enable wibu-daemon >/dev/null 2>&1
systemctl restart wibu-daemon

systemctl enable --now telegram-webhook.socket >/dev/null 2>&1

# Logrotate & Cron
cat << 'LREOF' > /etc/logrotate.d/xray
/var/log/xray/*.log {
    su nobody nogroup
    create 0644 nobody nogroup
    daily
    rotate 3
    size 10M
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        systemctl restart xray > /dev/null 2>&1
    endscript
}
LREOF

cat <<EOF > /usr/local/bin/watchdog.sh
#!/bin/bash
systemctl is-active --quiet xray || systemctl restart xray
systemctl is-active --quiet haproxy || systemctl restart haproxy
EOF
chmod +x /usr/local/bin/watchdog.sh

systemctl enable cron >/dev/null 2>&1

crontab -l 2>/dev/null | grep -v -E "xp|reboot|watchdog|algojo|unlocker|drop_caches|renew-cert-wibu" | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/watchdog.sh") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/xp") | crontab -
(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * * sync; echo 3 > /proc/sys/vm/drop_caches && swapoff -a && swapon -a") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/sbin/unlocker-wibu") | crontab -

# SSL Auto Renewal
cat > /usr/local/bin/renew-cert-wibu.sh << 'RCEOF'
#!/bin/bash
domain=$(cat /etc/xray/domain 2>/dev/null)
[[ -z "$domain" ]] && exit 1
systemctl stop haproxy
certbot renew --quiet --no-self-upgrade --standalone
cat /etc/letsencrypt/live/$domain/fullchain.pem /etc/letsencrypt/live/$domain/privkey.pem > /etc/haproxy/certs/$domain.pem
systemctl start haproxy
RCEOF
chmod +x /usr/local/bin/renew-cert-wibu.sh
(crontab -l 2>/dev/null; echo "0 4 * * * /usr/local/bin/renew-cert-wibu.sh") | crontab -

# Service Override
mkdir -p /etc/systemd/system/haproxy.service.d /etc/systemd/system/xray.service.d
cat <<EOF > /etc/systemd/system/haproxy.service.d/override.conf
[Service]
Restart=on-failure
RestartSec=5s
EOF
cat <<EOF > /etc/systemd/system/xray.service.d/override.conf
[Service]
ExecStartPre=/bin/mkdir -p /var/log/xray
ExecStartPre=/bin/chown -R nobody:nogroup /var/log/xray
Restart=on-failure
RestartSec=5s
EOF

systemctl daemon-reload
systemctl enable xray haproxy cron
systemctl start cron
systemctl restart xray haproxy

# Set Webhook URL to Telegram
source /etc/wibutunnel/bot.conf 2>/dev/null
if [[ -n "$BOT_TOKEN" ]]; then
    # Generate webhook secret jika belum ada
    if [[ -z "$WEBHOOK_SECRET" ]]; then
        WEBHOOK_SECRET=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
        echo "WEBHOOK_SECRET='${WEBHOOK_SECRET}'" >> /etc/wibutunnel/bot.conf
    fi
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
        -F "url=https://${domain}/telehook" \
        -F "secret_token=${WEBHOOK_SECRET}" >/dev/null 2>&1
fi

dos2unix /usr/local/bin/* /usr/local/sbin/* >/dev/null 2>&1

if ! grep -q "menu" /root/.profile; then
    echo -e 'clear\nmenu' >> /root/.profile
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    INSTALASI SELESAI! REBOOT DALAM 8 DETIK...    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 8
reboot
