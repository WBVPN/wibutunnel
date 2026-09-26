#!/bin/bash
# Wibutunnel Quick Installer
# Usage:
#   export IZIN_TOKEN='token_dari_admin'
#   curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash
#
# Token lisensi WAJIB. Dapatkan dari admin (registrasi IP via Telegram).
# Jangan pernah commit token ke repo manapun.

echo "============================================"
echo "   Wibutunnel VPN Management System"
echo "   Quick Installer v4.0.2 Kurumi"
echo "============================================"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "Error: Script harus dijalankan sebagai root"
   echo "Gunakan: sudo bash install.sh"
   exit 1
fi

# [SECURITY] Token lisensi wajib. Cara dapat token:
#   1. Dari admin (registrasi IP via Telegram), atau
#   2. Positional arg (RECOMMENDED untuk curl|bash):
#        curl -sL .../install.sh | sudo bash -s -- 'TOKEN_ANDA'
#   3. Env var (HANYA jika TANPA sudo, sudo strip env var):
#        sudo IZIN_TOKEN='TOKEN' bash install.sh
IZIN_TOKEN="${1:-${IZIN_TOKEN:-}}"
if [[ -z "$IZIN_TOKEN" ]]; then
    echo "Error: IZIN_TOKEN kosong."
    echo ""
    echo "Cara pakai yang benar:"
    echo "  curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | sudo bash -s -- 'TOKEN_ANDA'"
    echo ""
    echo "Atau download dulu:"
    echo "  curl -sL -o install.sh https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh"
    echo "  sudo bash install.sh 'TOKEN_ANDA'"
    exit 1
fi

# Check OS (konsisten dengan setup.sh: Ubuntu atau Debian)
source /etc/os-release 2>/dev/null || true
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
    echo "Error: Hanya mendukung Ubuntu / Debian (terdeteksi: ${ID:-unknown})"
    exit 1
fi

# Clone / update repo
INSTALL_DIR="/root/wibutunnel"
echo "[1/2] ${INSTALL_DIR} bersedia, dapatkan source terbaru..."
cd /root || exit 1
if [[ -d "wibutunnel/.git" ]]; then
    cd wibutunnel && git pull --ff-only
else
    rm -rf wibutunnel
    git clone https://github.com/WBVPN/wibutunnel.git
    cd wibutunnel || exit 1
fi

# Run installer utama (IZIN_TOKEN sudah di-export, setup.sh terima)
echo "[2/2] Menjalankan installer utama..."
echo ""
chmod +x setup.sh
./setup.sh
