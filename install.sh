#!/bin/bash
# Wibutunnel Quick Installer
# Usage: curl -sL https://raw.githubusercontent.com/WBVPN/wibutunnel/main/install.sh | bash

set -e

echo "============================================"
echo "   Wibutunnel VPN Management System"
echo "   Quick Installer v4.0.1"
echo "============================================"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "Error: Script harus dijalankan sebagai root"
   echo "Gunakan: sudo bash install.sh"
   exit 1
fi

# Check OS
if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
    echo "Warning: Script dioptimalkan untuk Ubuntu 22.04"
    read -p "Lanjutkan? (y/n): " confirm
    [[ "$confirm" != "y" ]] && exit 1
fi

# Clone repo
echo "[1/3] Clone repository..."
cd /root
if [[ -d "wibutunnel" ]]; then
    echo "Directory wibutunnel sudah ada, update..."
    cd wibutunnel && git pull
else
    git clone https://github.com/WBVPN/wibutunnel.git
    cd wibutunnel
fi

# Make executable
echo "[2/3] Setup permissions..."
chmod +x setup.sh

# Run installer
echo "[3/3] Menjalankan installer utama..."
echo ""
./setup.sh

