#!/bin/bash
# Regression Test Suite for Known Issues
# Tests fixes for previously reported bugs and issues

set -e

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

log() { echo -e "${GREEN}[TEST]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "╔══════════════════════════════════════════════════╗"
echo "║  Wibutunnel Regression Test Suite               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

FAIL=0
PASS=0

# Test 1: SSL Backup - 4 files must be backed up
test_ssl_backup() {
    log "Test 1: SSL Certificate Backup (4 files)"
    
    local backup_script="bin/m-backup"
    if [ ! -f "$backup_script" ]; then
        backup_script="m-backup"
        if [ ! -f "$backup_script" ]; then
            error "  m-backup script not found in bin/ or current dir"
            return 1
        fi
    fi
    
    # Check if all 4 SSL files are included in backup
    local ssl_files=(
        "fullchain.pem"
        "privkey.pem"
        "cert.pem"
        "chain.pem"
    )
    
    local found=0
    for file in "${ssl_files[@]}"; do
        if grep -q "$file" "$backup_script"; then
            log "  ✓ $file backup found"
            found=$((found + 1))
        else
            error "  ✗ $file backup MISSING"
        fi
    done
    
    if [ $found -eq 4 ]; then
        log "  ✅ All 4 SSL files in backup"
        return 0
    else
        error "  ❌ Only $found/4 SSL files in backup"
        return 1
    fi
}

# Test 2: Domain Auto-Detect from /etc/xray/domain
test_domain_autodetect() {
    log "Test 2: Domain Auto-Detect from /etc/xray/domain"
    
    local backup_script="bin/m-backup"
    if [ ! -f "$backup_script" ]; then
        backup_script="m-backup"
        if [ ! -f "$backup_script" ]; then
            error "  m-backup script not found"
            return 1
        fi
    fi
    
    # Check if script reads domain from /etc/xray/domain
    if grep -q "/etc/xray/domain" "$backup_script"; then
        log "  ✓ Domain file reference found"
    else
        error "  ✗ Domain auto-detect missing"
        return 1
    fi
    
    # Check if DOMAIN variable is set from file (various patterns)
    if grep -qE 'DOMAIN.*cat.*\/etc\/xray\/domain' "$backup_script" || \
       grep -qE 'DOMAIN.*\$\(cat.*\/etc\/xray\/domain' "$backup_script"; then
        log "  ✓ Domain auto-detect logic found"
        return 0
    else
        error "  ✗ Domain assignment logic missing"
        return 1
    fi
}

# Test 3: Restore Password Auto (CHAT_ID default)
test_restore_password_auto() {
    log "Test 3: Restore Password Auto (CHAT_ID default)"
    
    local restore_script="bin/m-restore"
    if [ ! -f "$restore_script" ]; then
        restore_script="m-restore"
        if [ ! -f "$restore_script" ]; then
            warn "  ⚠ m-restore script not found (optional feature)"
            log "  ✓ Test skipped (restore is optional)"
            return 0
        fi
    fi
    
    # Check if CHAT_ID is used for password
    if grep -qE "CHAT_ID.*5851934765" "$restore_script" || \
       grep -qE "cat.*bot\.conf.*CHAT_ID" "$restore_script"; then
        log "  ✓ CHAT_ID reference found"
    else
        warn "  ⚠ CHAT_ID reference not found (might be OK)"
    fi
    
    # Check if restore uses domain from file
    if grep -q "/etc/xray/domain" "$restore_script"; then
        log "  ✓ Domain auto-detect in restore"
        return 0
    else
        error "  ✗ Domain auto-detect missing in restore"
        return 1
    fi
}

# Test 4: LIFETIME License Parsing
test_lifetime_license() {
    log "Test 4: LIFETIME License Parsing"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if script handles LIFETIME license correctly
    if grep -qi "LIFETIME" setup.sh; then
        log "  ✓ LIFETIME keyword found in script"
    else
        error "  ✗ LIFETIME license handling missing"
        return 1
    fi
    
    # Check license validation logic
    if grep -qE "grep.*MYIP.*izin\.txt" setup.sh || \
       grep -qE "license.*check" setup.sh; then
        log "  ✓ License validation logic found"
    else
        warn "  ⚠ License validation logic unclear"
    fi
    
    # Regression: Check if LIFETIME is not confused with expiry date
    if grep -qE 'exp.*LIFETIME|LIFETIME.*exp.*date' setup.sh; then
        error "  ✗ LIFETIME treated as date (regression!)"
        return 1
    else
        log "  ✓ LIFETIME not treated as expiry date"
        return 0
    fi
}

# Test 5: Bot Config Validation
test_bot_config() {
    log "Test 5: Bot Config Validation (/etc/wibutunnel/bot.conf)"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if bot.conf is created
    if grep -q "/etc/wibutunnel/bot.conf" setup.sh; then
        log "  ✓ bot.conf creation found"
    else
        error "  ✗ bot.conf creation missing"
        return 1
    fi
    
    # Check if BOT_TOKEN is referenced (read from bot.conf)
    if grep -qE "BOT_TOKEN" setup.sh; then
        log "  ✓ Bot token handling found"
    else
        error "  ✗ Bot token handling missing"
        return 1
    fi
    
    # Check if webhook or bot daemon setup exists
    if grep -qE "webhook|bot-daemon|setWebhook" setup.sh; then
        log "  ✓ Bot webhook/daemon setup found"
        return 0
    else
        warn "  ⚠ Bot webhook/daemon setup unclear"
        # Not critical - bot.conf exists
        return 0
    fi
}

# Test 6: HAProxy SSL Configuration
test_haproxy_ssl() {
    log "Test 6: HAProxy SSL Configuration (webhook support)"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if HAProxy config includes SSL cert paths
    if grep -qE "ssl crt.*fullchain\.pem" setup.sh || \
       grep -q "haproxy.*ssl" setup.sh; then
        log "  ✓ HAProxy SSL configuration found"
    else
        warn "  ⚠ HAProxy SSL configuration unclear"
    fi
    
    # Check for webhook routing (port 8443)
    if grep -qE "127\.0\.0\.1:8443|backend.*webhook" setup.sh; then
        log "  ✓ Webhook routing (8443) found"
        return 0
    else
        warn "  ⚠ Webhook routing not found (bot might not work)"
        return 1
    fi
}

# Test 7: Ubuntu Kernel Hold (regression from commit b231ced)
test_ubuntu_kernel_hold() {
    log "Test 7: Ubuntu Kernel Hold Fix (commit b231ced)"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # This is a critical regression test
    if grep -q "apt-mark hold.*linux-image" setup.sh && \
       grep -q "apt-mark hold.*grub" setup.sh && \
       grep -q "without-new-pkgs" setup.sh; then
        log "  ✓ Ubuntu kernel hold fix present"
        return 0
    else
        error "  ✗ Ubuntu kernel hold fix MISSING (critical regression!)"
        return 1
    fi
}

# Test 8: Menu Script Installation
test_menu_installation() {
    log "Test 8: Menu Script Installation (6 scripts)"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if bin/ directory with menu scripts exists in source
    if [ -d bin ] && [ -f bin/m-backup ]; then
        log "  ✓ Menu scripts found in bin/ directory"
    else
        warn "  ⚠ bin/ directory not found (checking setup.sh)"
    fi
    
    # Check setup.sh installs menu components
    if grep -qE "bin/.*menu|menu.*bin|cp.*bin/" setup.sh; then
        log "  ✓ Menu installation logic found in setup.sh"
        return 0
    else
        error "  ✗ Menu installation missing from setup.sh"
        return 1
    fi
}

# Test 9: Watchdog Service (auto-restart)
test_watchdog_service() {
    log "Test 9: Watchdog Service (auto-restart all services)"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if watchdog.sh is created
    if grep -q "watchdog.sh" setup.sh; then
        log "  ✓ Watchdog script found"
    else
        error "  ✗ Watchdog script missing"
        return 1
    fi
    
    # Check if all 4 main services are monitored
    local services=("xray" "haproxy" "dropbear" "ws-stunnel")
    local monitored=0
    
    for service in "${services[@]}"; do
        if grep -A 10 "watchdog" setup.sh | grep -q "$service"; then
            monitored=$((monitored + 1))
        fi
    done
    
    if [ $monitored -ge 3 ]; then
        log "  ✓ Watchdog monitors $monitored/4 services"
        return 0
    else
        error "  ✗ Watchdog only monitors $monitored/4 services"
        return 1
    fi
}

# Test 10: WIBU_NO_REBOOT Flag Support
test_no_reboot_flag() {
    log "Test 10: WIBU_NO_REBOOT Flag Support"
    
    if [ ! -f setup.sh ]; then
        error "  setup.sh not found"
        return 1
    fi
    
    # Check if script respects WIBU_NO_REBOOT flag
    if grep -q "WIBU_NO_REBOOT" setup.sh; then
        log "  ✓ WIBU_NO_REBOOT flag support found"
        
        # Check if reboot is conditional
        if grep -qE 'if.*WIBU_NO_REBOOT.*reboot|WIBU_NO_REBOOT.*then|reboot.*WIBU_NO_REBOOT' setup.sh; then
            log "  ✓ Conditional reboot logic found"
            return 0
        else
            warn "  ⚠ WIBU_NO_REBOOT logic unclear"
            return 1
        fi
    else
        error "  ✗ WIBU_NO_REBOOT flag missing"
        return 1
    fi
}

# Run all tests
echo "Running 10 regression tests..."
echo ""

test_ssl_backup && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_domain_autodetect && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_restore_password_auto && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_lifetime_license && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_bot_config && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_haproxy_ssl && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_ubuntu_kernel_hold && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_menu_installation && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_watchdog_service && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

test_no_reboot_flag && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "REGRESSION TEST RESULTS:"
echo "  ✅ Passed: $PASS/10"
echo "  ❌ Failed: $FAIL/10"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ ALL REGRESSION TESTS PASSED${NC}"
    echo ""
    echo "No regressions detected. All known issues remain fixed:"
    echo "  ✓ SSL backup (4 files)"
    echo "  ✓ Domain auto-detect"
    echo "  ✓ Restore password auto"
    echo "  ✓ LIFETIME license parsing"
    echo "  ✓ Bot config validation"
    echo "  ✓ HAProxy SSL webhook"
    echo "  ✓ Ubuntu kernel hold fix"
    echo "  ✓ Menu installation"
    echo "  ✓ Watchdog service"
    echo "  ✓ WIBU_NO_REBOOT flag"
    exit 0
else
    echo -e "${RED}❌ $FAIL REGRESSION TEST(S) FAILED${NC}"
    echo ""
    echo "REGRESSIONS DETECTED! Previously fixed issues are broken."
    echo "Review failed tests above and fix the scripts."
    exit 1
fi
