# 🚀 PANDUAN DEPLOYMENT & INSTALASI (WIBU TUNNELING v4.0 KURUMI)

Dokumen ini berisi panduan teknis deployment otomatis untuk AI Coding Assistant dan instalasi manual untuk manusia.

---

## 🤖 A. PANDUAN DEPLOYMENT OTOMATIS (UNTUK AI / AGENT)

### 1. Prasyarat Sistem & Environment
- **Operating System**: Ubuntu 20.04/22.04 LTS atau Debian 10/11/12 (Fresh Rebuild)
- **User**: Wajib `root` (`EUID == 0`)
- **Port Terbuka**: Port 80 (HTTP), Port 443 (HTTPS), Port 22 (SSH)

### 2. Langkah Eksekusi AI (Step-by-Step)
```bash
# 1. Update paket sistem & install dependensi
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget jq uuid-runtime haproxy certbot cron net-tools zip unzip iptables iptables-persistent iproute2 bc logrotate dos2unix

# 2. Registrasi IP VPS ke izin.txt (atau pastikan IP sudah terdaftar di repository)
# Format izin.txt: ### <NAMA_CLIENT> <EXPIRED_DATE/lifetime> <IP_VPS>

# 3. Jalankan Master Installer
bash <(curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh)
```

### 3. Konfigurasi Service Systemd Utama
- **Xray VPN Core**: `/etc/systemd/system/xray.service` (Inbounds: Port 10085 - 10093)
- **HAProxy Frontend**: `/etc/haproxy/haproxy.cfg` (Listening port 80 & 443)
- **Wibu Daemon**: `/etc/systemd/system/wibu-daemon.service` (Algojo monitor 24/7)
- **Telegram Webhook**: `/etc/systemd/system/telegram-webhook.socket` (Listening 127.0.0.1:8443)

### 4. Health Check / Verifikasi Otomatis
```bash
systemctl is-active xray haproxy wibu-daemon cron telegram-webhook.socket
haproxy -c -f /etc/haproxy/haproxy.cfg
ss -tlnp | grep -E ":80|:443|:10085"
```

---

## 👤 B. PANDUAN INSTALASI MANUAL (UNTUK PENGGUNA)

### 1. Persiapan Domain
- Arahkan (*pointing*) A-Record domain Anda ke IP VPS.
- Matikan proxy Cloudflare (gunakan status **DNS Only / Abu-abu**) saat instalasi awal agar sertifikat SSL Let's Encrypt dapat diterbitkan.

### 2. Perintah Instalasi 1-Klik
Buka terminal SSH VPS Anda sebagai `root`, lalu jalankan perintah berikut:
```bash
apt update -y && apt install -y curl wget && bash <(curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh)
```

### 3. Masukkan Domain
- Saat script meminta input domain, ketik nama domain Anda (misal: `vpn.domainanda.com`).
- Tunggu proses instalasi otomatis selesai (sekitar 1-2 menit).
- VPS akan reboot otomatis setelah proses verifikasi selesai.

### 4. Akses Dashboard Menu
Setelah VPS menyala kembali, login ke SSH dan ketik:
```bash
menu
```

---

*Dikembangkan oleh Tim WIBU TUNNELING (v4.0 Kurumi Patched)*
