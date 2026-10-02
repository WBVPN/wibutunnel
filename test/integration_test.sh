#!/bin/bash
# Wibutunnel Integration Test Suite
# Tests full installation flow, service validation, and clean uninstall

set -e

# Source centralized test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_config.sh"

# Configuration
TEST_DOMAIN="${WIBU_TEST_DOMAIN}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
LOG_FILE="${WIBU_LOG_FILE}"
INSTALL_TIMEOUT="${WIBU_INSTALL_TIMEOUT}"

# Colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

# Test prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Must be root
    if [ "$EUID" -ne 0 ]; then
        error "Must run as root"
        exit 1
    fi
    
    # Check OS compatibility
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log "OS: $ID $VERSION_ID"
        case "$ID" in
            ubuntu|debian)
                log "✓ OS supported"
                ;;
            *)
                error "Unsupported OS: $ID"
                exit 1
                ;;
        esac
    else
        error "Cannot detect OS"
        exit 1
    fi
    
    # Check network
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        error "No network connectivity to GitHub"
        exit 1
    fi
    
    log "✓ Prerequisites OK"
}

# Test installation
test_install() {
    log "━━━ PHASE 1: Installation Test ━━━"
    
    # Prepare domain
    mkdir -p /etc/xray
    echo "$TEST_DOMAIN" > /etc/xray/domain
    log "Domain set: $TEST_DOMAIN"
    
    # Clone repos (with license)
    log "Cloning repositories..."
    cd /root
    rm -rf wibutunnel wibutunnel-izin
    
    # Check if CI mode (use fixture instead of git clone)
    if [ "${CI:-false}" = "true" ] || [ -f "${SCRIPT_DIR}/../test/fixtures/mock_license.txt" ]; then
        log "CI mode detected - using license fixture"
        mkdir -p wibutunnel-izin
        
        # Use fixture if available, otherwise create minimal license
        if [ -f "${SCRIPT_DIR}/../test/fixtures/mock_license.txt" ]; then
            cp "${SCRIPT_DIR}/../test/fixtures/mock_license.txt" wibutunnel-izin/izin.txt
            log "✓ Using mock license fixture"
        else
            # Fallback: create minimal license
            TEST_IP=$(curl -s ifconfig.me || echo "127.0.0.1")
            echo "$TEST_IP | integration-test | LIFETIME" > wibutunnel-izin/izin.txt
            log "✓ Created minimal test license"
        fi
        
        # Clone main repo
        if [ -n "$GITHUB_TOKEN" ]; then
            git clone "https://${GITHUB_TOKEN}@github.com/WBVPN/wibutunnel.git" 2>&1 | tee -a "$LOG_FILE"
        else
            git clone "https://github.com/WBVPN/wibutunnel.git" 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        log "Standard mode - cloning license repo"
        if [ -n "$GITHUB_TOKEN" ]; then
            git clone "https://${GITHUB_TOKEN}@github.com/WBVPN/wibutunnel-izin.git" 2>&1 | tee -a "$LOG_FILE"
            git clone "https://${GITHUB_TOKEN}@github.com/WBVPN/wibutunnel.git" 2>&1 | tee -a "$LOG_FILE"
        else
            git clone "https://github.com/WBVPN/wibutunnel-izin.git" 2>&1 | tee -a "$LOG_FILE"
            git clone "https://github.com/WBVPN/wibutunnel.git" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        # Add test license
        cd wibutunnel-izin
        TEST_IP=$(curl -s ifconfig.me || echo "127.0.0.1")
        echo "$TEST_IP | integration-test | LIFETIME" >> izin.txt
        log "License added: $TEST_IP"
        cd /root
    fi
    
    # Run installation
    cd /root/wibutunnel
    log "Starting installation (timeout: ${INSTALL_TIMEOUT}s)..."
    
    export WIBU_NO_REBOOT=1
    if timeout "$INSTALL_TIMEOUT" bash setup.sh >> "$LOG_FILE" 2>&1; then
        log "✓ Installation completed"
    else
        error "Installation failed or timeout"
        tail -50 "$LOG_FILE"
        exit 1
    fi
}

# Test services
test_services() {
    log "━━━ PHASE 2: Service Validation ━━━"
    
    local failed=0
    declare -a SERVICE_PIDS
    declare -A SERVICE_RESULTS
    
    # Function to check a single service
    check_service() {
        local service="$1"
        local result_file="$2"
        
        if systemctl is-active --quiet "$service"; then
            echo "ACTIVE" > "$result_file"
        else
            echo "INACTIVE" > "$result_file"
        fi
        
        # Check if enabled (optional, don't fail on this)
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            echo "ENABLED" >> "$result_file"
        else
            echo "NOT_ENABLED" >> "$result_file"
        fi
    }
    
    # Launch parallel service checks
    log "Checking services in parallel..."
    for service in $WIBU_SERVICES; do
        RESULT_FILE="/tmp/service_check_${service}.txt"
        check_service "$service" "$RESULT_FILE" &
        SERVICE_PIDS+=($!)
        SERVICE_RESULTS["$service"]="$RESULT_FILE"
    done
    
    # Wait for all checks to complete
    for pid in "${SERVICE_PIDS[@]}"; do
        wait "$pid"
    done
    
    # Collect results
    for service in $WIBU_SERVICES; do
        RESULT_FILE="${SERVICE_RESULTS[$service]}"
        
        if [ -f "$RESULT_FILE" ]; then
            STATUS=$(head -1 "$RESULT_FILE")
            ENABLED=$(tail -1 "$RESULT_FILE")
            
            log "Checking $service..."
            
            if [ "$STATUS" = "ACTIVE" ]; then
                log "  ✓ $service is active"
            else
                error "  ✗ $service is NOT active"
                systemctl status "$service" --no-pager | tee -a "$LOG_FILE"
                failed=$((failed + 1))
            fi
            
            if [ "$ENABLED" = "ENABLED" ]; then
                log "  ✓ $service is enabled"
            else
                warn "  ⚠ $service is NOT enabled"
            fi
            
            rm -f "$RESULT_FILE"
        else
            error "  ✗ Failed to check $service"
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -gt 0 ]; then
        error "$failed service(s) failed validation"
        exit 1
    fi
    
    log "✓ All services validated"
}

# Test binaries
test_binaries() {
    log "━━━ PHASE 3: Binary Validation ━━━"
    
    local required_bins=(
        "/usr/local/bin/xray"
        "/usr/local/bin/menu"
        "/usr/local/bin/m-backup"
        "/usr/local/bin/m-restore"
    )
    
    local failed=0
    
    for bin in "${required_bins[@]}"; do
        if [ -x "$bin" ]; then
            log "  ✓ $bin exists and executable"
        else
            error "  ✗ $bin missing or not executable"
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -gt 0 ]; then
        error "$failed binary/binaries missing"
        exit 1
    fi
    
    # Test menu command
    if menu --version >/dev/null 2>&1; then
        log "  ✓ menu command works"
    else
        error "  ✗ menu command failed"
        exit 1
    fi
    
    log "✓ All binaries validated"
}

# Test configuration
test_configuration() {
    log "━━━ PHASE 4: Configuration Validation ━━━"
    
    local required_configs=(
        "/usr/local/etc/xray/config.json"
        "/etc/haproxy/haproxy.cfg"
        "/etc/wibutunnel/bot.conf"
    )
    
    local failed=0
    
    for config in "${required_configs[@]}"; do
        if [ -f "$config" ]; then
            log "  ✓ $config exists"
            
            # Validate JSON files
            if [[ "$config" == *.json ]]; then
                if jq empty "$config" 2>/dev/null; then
                    log "    ✓ Valid JSON"
                else
                    error "    ✗ Invalid JSON"
                    failed=$((failed + 1))
                fi
            fi
        else
            error "  ✗ $config missing"
            failed=$((failed + 1))
        fi
    done
    
    # Check domain file
    if [ -f /etc/xray/domain ]; then
        DOMAIN=$(cat /etc/xray/domain)
        log "  ✓ Domain configured: $DOMAIN"
    else
        error "  ✗ Domain file missing"
        failed=$((failed + 1))
    fi
    
    if [ $failed -gt 0 ]; then
        error "$failed configuration issue(s)"
        exit 1
    fi
    
    log "✓ All configurations validated"
}

# Test uninstallation
test_uninstall() {
    log "━━━ PHASE 5: Uninstallation Test ━━━"
    
    if [ ! -f /root/wibutunnel/uninstall.sh ]; then
        error "uninstall.sh not found"
        exit 1
    fi
    
    log "Running uninstaller..."
    cd /root/wibutunnel
    
    if bash uninstall.sh >> "$LOG_FILE" 2>&1; then
        log "✓ Uninstaller executed"
    else
        error "Uninstaller failed"
        exit 1
    fi
    
    # Verify services stopped
    local cleaned=0
    for service in $WIBU_SERVICES; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            warn "  ⚠ $service still active after uninstall"
        else
            cleaned=$((cleaned + 1))
        fi
    done
    
    log "  $cleaned/4 services cleaned"
    
    # Verify binaries removed
    if [ ! -f /usr/local/bin/xray ]; then
        log "  ✓ xray binary removed"
    else
        warn "  ⚠ xray binary still exists"
    fi
    
    log "✓ Uninstallation completed"
}

# Main test flow
main() {
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  Wibutunnel Integration Test Suite              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    
    true > "$LOG_FILE"  # Clear log
    
    check_prerequisites
    test_install
    test_services
    test_binaries
    test_configuration
    test_uninstall
    
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  ✅ ALL TESTS PASSED                            ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Full log: $LOG_FILE"
    
    exit 0
}

# Run with error handling
trap 'error "Test failed at line $LINENO"; exit 1' ERR

main "$@"
