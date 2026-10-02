#!/bin/bash
# =====================================================
# Wibutunnel VPN Auto Installer with GitHub Token
# Orchestrator-based automation untuk install VPS
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required:
  --vps IP            VPS IP address
  --user USER         VPS SSH username (default: root)
  --pass PASS         VPS SSH password
  --domain DOMAIN     Domain untuk SSL certificate
  --github-token TOKEN GitHub fine-grained token untuk wibutunnel-izin repo

Optional:
  --port PORT         SSH port (default: 22)
  --timeout SEC       Installation timeout (default: 1800)
  --skip-prereq       Skip prerequisite check

Example:
  $0 --vps 110.232.90.195 --user root --pass 'Giftia#123' \\
     --domain aku.priasawit.web.id --github-token ghp_xxxxx

EOF
    exit 1
}

# Parse arguments
VPS_IP=""
VPS_USER="root"
VPS_PASS=""
DOMAIN=""
GITHUB_TOKEN=""
SSH_PORT=22
TIMEOUT=1800
SKIP_PREREQ=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --vps) VPS_IP="$2"; shift 2 ;;
        --user) VPS_USER="$2"; shift 2 ;;
        --pass) VPS_PASS="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --port) SSH_PORT="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --skip-prereq) SKIP_PREREQ=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Validate required args
if [[ -z "$VPS_IP" || -z "$VPS_PASS" || -z "$DOMAIN" || -z "$GITHUB_TOKEN" ]]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    usage
fi

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"
}

log_err() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] !${NC} $1"
}

# =====================================================
# STEP 1: Prerequisites Check
# =====================================================
check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ $SKIP_PREREQ -eq 1 ]]; then
        log_warn "Skipping prerequisite check"
        return 0
    fi
    
    # Check sshpass
    if ! command -v sshpass &>/dev/null; then
        log "Installing sshpass..."
        apt-get update -qq && apt-get install -y sshpass
    fi
    log_ok "sshpass available"
    
    # Test SSH connectivity
    log "Testing SSH connection to $VPS_IP:$SSH_PORT..."
    if ! timeout 10 sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -p "$SSH_PORT" "${VPS_USER}@${VPS_IP}" "echo OK" &>/dev/null; then
        log_err "Cannot connect to VPS. Check IP/credentials/firewall."
        exit 1
    fi
    log_ok "SSH connection OK"
}

# =====================================================
# STEP 2: Install Dependencies on VPS
# =====================================================
install_vps_dependencies() {
    log "Installing VPS dependencies (git, curl, wget)..."
    
    sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" \
        "${VPS_USER}@${VPS_IP}" << 'EOFSSH'
set -e

# Check if git exists
if command -v git &>/dev/null; then
    echo "git already installed"
    exit 0
fi

# Try normal install
apt-get update -qq
if apt-get install -y git curl wget 2>/dev/null; then
    echo "Dependencies installed successfully"
    exit 0
fi

# Handle Debian repo issues (perl version conflict)
echo "Detected package conflict. Attempting fix..."
apt-get install -y --allow-downgrades perl-base=5.32.1-4+deb11u3 2>/dev/null || true
apt-get install -y git curl wget

if ! command -v git &>/dev/null; then
    echo "ERROR: Failed to install git"
    exit 1
fi

echo "Dependencies installed (with conflict resolution)"
EOFSSH
    
    if [[ $? -eq 0 ]]; then
        log_ok "VPS dependencies installed"
    else
        log_err "Failed to install dependencies"
        exit 1
    fi
}

# =====================================================
# STEP 3: Setup License File
# =====================================================
setup_license() {
    log "Setting up license validation..."
    
    sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" \
        "${VPS_USER}@${VPS_IP}" bash -s "$VPS_IP" "$GITHUB_TOKEN" << 'EOFSSH'
set -e

VPS_IP_PARAM="$1"
TOKEN="$2"

# Get actual VPS IP
ACTUAL_IP=$(curl -s --max-time 10 ifconfig.me || curl -s --max-time 10 api.ipify.org)
echo "VPS Public IP: $ACTUAL_IP"

# Clone license repo with token
mkdir -p /root
cd /root
rm -rf wibutunnel-izin

echo "Cloning license repo..."
if git clone https://oauth2:${TOKEN}@github.com/WBVPN/wibutunnel-izin.git 2>&1; then
    echo "License repo cloned successfully"
else
    echo "ERROR: Failed to clone license repo. Check token permissions."
    exit 1
fi

# Verify IP in whitelist
if ! grep -q "$ACTUAL_IP" /root/wibutunnel-izin/izin.txt; then
    echo "ERROR: IP $ACTUAL_IP not found in whitelist"
    echo "Whitelist content:"
    cat /root/wibutunnel-izin/izin.txt
    exit 1
fi

echo "IP verified in whitelist:"
grep "$ACTUAL_IP" /root/wibutunnel-izin/izin.txt
EOFSSH
    
    if [[ $? -eq 0 ]]; then
        log_ok "License validated"
    else
        log_err "License validation failed"
        exit 1
    fi
}

# =====================================================
# STEP 4: Run Installer
# =====================================================
run_installer() {
    log "Running wibutunnel installer with domain: $DOMAIN"
    log "This will take 5-10 minutes..."
    
    sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" \
        "${VPS_USER}@${VPS_IP}" bash -s "$DOMAIN" << 'EOFSSH'
set -e

DOMAIN_PARAM="$1"

cd /root

# Clone main repo
if [[ -d "wibutunnel/.git" ]]; then
    cd wibutunnel && git pull --ff-only
else
    rm -rf wibutunnel
    git clone https://github.com/WBVPN/wibutunnel.git
    cd wibutunnel
fi

# Run installer
chmod +x setup.sh
echo "$DOMAIN_PARAM" | bash setup.sh 2>&1 | tee /tmp/wibu_install.log

echo ""
echo "Installer finished. VPS will reboot..."
EOFSSH
    
    local exit_code=$?
    
    # SSH disconnect (exit 255) expected karena reboot
    if [[ $exit_code -eq 255 || $exit_code -eq 0 ]]; then
        log_ok "Installer completed. VPS rebooting..."
        return 0
    else
        log_err "Installer failed with exit code $exit_code"
        return 1
    fi
}

# =====================================================
# STEP 5: Wait for Reboot
# =====================================================
wait_for_reboot() {
    log "Waiting for VPS reboot (max 120 seconds)..."
    
    sleep 20  # Initial wait
    
    for i in {1..20}; do
        if timeout 5 sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
            -p "$SSH_PORT" "${VPS_USER}@${VPS_IP}" "echo OK" &>/dev/null; then
            log_ok "VPS back online after $((20 + i*5)) seconds"
            sleep 5  # Extra wait untuk services startup
            return 0
        fi
        sleep 5
    done
    
    log_err "VPS did not respond after reboot timeout"
    return 1
}

# =====================================================
# STEP 6: Validate Installation
# =====================================================
validate_installation() {
    log "Running post-install validation..."
    
    local validation_output
    validation_output=$(sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" \
        "${VPS_USER}@${VPS_IP}" << 'EOFSSH'
echo "=== VALIDATION REPORT ==="
echo ""

# Services
echo "[1] Services Status:"
for svc in xray haproxy dropbear ws-stunnel wibu-daemon; do
    status=$(systemctl is-active $svc 2>&1)
    if [[ "$status" == "active" ]]; then
        echo "  ✓ $svc: active"
    else
        echo "  ✗ $svc: $status"
    fi
done
echo ""

# Ports
echo "[2] Critical Ports:"
for port in 80 443 143 109; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ✓ Port $port: listening"
    else
        echo "  ✗ Port $port: not listening"
    fi
done
echo ""

# SSL
echo "[3] SSL Certificate:"
if [[ -f /etc/letsencrypt/live/*/fullchain.pem ]]; then
    expiry=$(openssl x509 -in /etc/letsencrypt/live/*/fullchain.pem -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "  ✓ Valid until: $expiry"
else
    echo "  ✗ Certificate not found"
fi
echo ""

# Domain
echo "[4] Domain:"
if [[ -f /etc/xray/domain ]]; then
    domain=$(cat /etc/xray/domain)
    resolved_ip=$(dig +short "$domain" A 2>/dev/null | head -1)
    actual_ip=$(curl -s ifconfig.me)
    echo "  Domain: $domain"
    echo "  Resolves to: $resolved_ip"
    echo "  VPS IP: $actual_ip"
    if [[ "$resolved_ip" == "$actual_ip" ]]; then
        echo "  ✓ DNS matches VPS IP"
    else
        echo "  ! DNS mismatch (might need propagation)"
    fi
else
    echo "  ✗ Domain file not found"
fi
echo ""

# Menu
echo "[5] Menu Command:"
if command -v menu &>/dev/null; then
    echo "  ✓ menu command available"
    echo "  Location: $(which menu)"
else
    echo "  ✗ menu command not found"
fi

echo ""
echo "=== END VALIDATION ==="
EOFSSH
)
    
    echo "$validation_output"
    
    # Check if critical services are running
    if echo "$validation_output" | grep -q "✗.*xray\|✗.*haproxy"; then
        log_err "Critical services not running"
        return 1
    fi
    
    log_ok "Installation validated successfully"
    return 0
}

# =====================================================
# MAIN EXECUTION
# =====================================================
main() {
    echo ""
    echo "========================================="
    echo "  Wibutunnel VPN Auto Installer"
    echo "========================================="
    echo "VPS: ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
    echo "Domain: $DOMAIN"
    echo "========================================="
    echo ""
    
    START_TIME=$(date +%s)
    
    # Run steps
    check_prerequisites
    install_vps_dependencies
    setup_license
    
    if ! run_installer; then
        log_err "Installation failed"
        exit 1
    fi
    
    if ! wait_for_reboot; then
        log_warn "Could not verify reboot, but continuing validation..."
    fi
    
    if ! validate_installation; then
        log_err "Validation failed"
        exit 1
    fi
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo "========================================="
    log_ok "Installation complete in ${DURATION}s"
    echo "========================================="
    echo ""
    echo "Access your VPS:"
    echo "  ssh ${VPS_USER}@${VPS_IP}"
    echo "  menu"
    echo ""
    echo "Available protocols:"
    echo "  - VLESS (WS/gRPC)"
    echo "  - VMESS (WS/gRPC)"
    echo "  - Trojan (WS/gRPC)"
    echo "  - SSH Tunneling"
    echo ""
}

main
