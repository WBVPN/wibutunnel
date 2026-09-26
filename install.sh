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

# [SECURITY] Token lisensi wajib. Jika piped (curl|bash), env var IZIN_TOKEN
# tetap terbawa; jika dijalankan manual tanpa env, prompt input di sini.
if [[ -z "${IZIN_TOKEN:-}" ]]; then
    read -rp "Masukkan IZIN_TOKEN (dari admin): " IZIN_TOKEN
    if [[ -z "$IZIN_TOKEN" ]]; then
        echo "Error: IZIN_TOKEN kosong. Registrasi IP dulu, lalu ulangi."
        echo "  export IZIN_TOKEN='token_anda'  lalu jalankan installer"
        exit 1
    fi
fi
export IZIN_TOKEN

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
