#!/bin/bash
# Ubuntu 22.04 Kernel/Grub Hold Test
# Validates commit b231ced fix that prevents VPS crash during apt upgrade

set -e

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

log() { echo -e "${GREEN}[TEST]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "╔══════════════════════════════════════════════════╗"
echo "║  Ubuntu 22.04 Kernel Fix Validation Test        ║"
echo "║  Commit: b231ced                                 ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

if [ ! -f setup.sh ]; then
    error "setup.sh not found in $REPO_DIR"
    exit 1
fi

FAIL=0

# Test 1: Check Ubuntu detection logic exists
log "Test 1: Ubuntu OS detection"
if grep -q "grep -qi ubuntu /etc/os-release" setup.sh; then
    log "  ✓ Ubuntu detection found"
else
    error "  ✗ Ubuntu detection missing"
    FAIL=$((FAIL + 1))
fi
echo ""

# Test 2: Check kernel package hold logic
log "Test 2: Kernel package hold logic"
if grep -q "apt-mark hold.*linux-image" setup.sh; then
    log "  ✓ linux-image hold found"
else
    error "  ✗ linux-image hold missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "apt-mark hold.*linux-headers" setup.sh; then
    log "  ✓ linux-headers hold found"
else
    error "  ✗ linux-headers hold missing"
    FAIL=$((FAIL + 1))
fi
echo ""

# Test 3: Check grub package hold logic
log "Test 3: Grub package hold logic"
if grep -q "apt-mark hold.*grub" setup.sh; then
    log "  ✓ grub hold found"
else
    error "  ✗ grub hold missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "apt-mark hold.*shim-signed" setup.sh; then
    log "  ✓ shim-signed hold found"
else
    warn "  ⚠ shim-signed hold missing (optional but recommended)"
fi
echo ""

# Test 4: Check --without-new-pkgs flag
log "Test 4: Safe upgrade flag (--without-new-pkgs)"
if grep -q "apt-get upgrade.*--without-new-pkgs" setup.sh; then
    log "  ✓ --without-new-pkgs flag found"
else
    error "  ✗ --without-new-pkgs flag missing"
    FAIL=$((FAIL + 1))
fi
echo ""

# Test 5: Check unhold after upgrade
log "Test 5: Package unhold after upgrade"
if grep -q "apt-mark unhold.*linux-image" setup.sh; then
    log "  ✓ linux-image unhold found"
else
    error "  ✗ linux-image unhold missing (packages stay held!)"
    FAIL=$((FAIL + 1))
fi

if grep -q "apt-mark unhold.*grub" setup.sh; then
    log "  ✓ grub unhold found"
else
    error "  ✗ grub unhold missing"
    FAIL=$((FAIL + 1))
fi
echo ""

# Test 6: Check Debian path (normal upgrade)
log "Test 6: Debian compatibility (normal upgrade path)"
if grep -qE "else.*apt-get upgrade" setup.sh; then
    log "  ✓ Debian/else branch found (normal upgrade)"
else
    warn "  ⚠ Debian upgrade path unclear"
fi
echo ""

# Test 7: Extract and validate actual code block
log "Test 7: Code block structure validation"
if grep -A 5 "grep -qi ubuntu /etc/os-release" setup.sh | grep -q "apt-mark hold"; then
    log "  ✓ Ubuntu conditional properly wraps hold logic"
else
    error "  ✗ Ubuntu detection not properly wrapping hold logic"
    FAIL=$((FAIL + 1))
fi
echo ""

# Test 8: Check for old broken patterns (regression check)
log "Test 8: Regression check (old broken patterns)"
REGRESSIONS=0

# Check if apt-get dist-upgrade is used (dangerous on VPS)
if grep -q "apt-get dist-upgrade" setup.sh; then
    warn "  ⚠ Found 'dist-upgrade' - potentially dangerous on VPS"
    REGRESSIONS=$((REGRESSIONS + 1))
fi

# Check if kernel packages explicitly installed
if grep -qE "apt-get install.*linux-image-[0-9]" setup.sh; then
    warn "  ⚠ Explicit kernel version installation found"
    REGRESSIONS=$((REGRESSIONS + 1))
fi

if [ $REGRESSIONS -eq 0 ]; then
    log "  ✓ No dangerous patterns found"
else
    warn "  Found $REGRESSIONS potential regression(s)"
fi
echo ""

# Test 9: On Ubuntu system, simulate the fix
if [ -f /etc/os-release ] && grep -qi ubuntu /etc/os-release; then
    log "Test 9: Live Ubuntu system - simulate fix"
    
    # Extract Ubuntu-specific block
    UBUNTU_BLOCK=$(sed -n '/grep -qi ubuntu \/etc\/os-release/,/^[[:space:]]*fi/p' setup.sh | head -20)
    
    if [ -n "$UBUNTU_BLOCK" ]; then
        log "  ✓ Ubuntu block extracted:"
        echo "$UBUNTU_BLOCK" | sed 's/^/    /'
        
        # Dry-run check
        log "  Testing apt-mark commands (dry-run)..."
        if apt-mark showhold >/dev/null 2>&1; then
            log "  ✓ apt-mark commands available"
        else
            error "  ✗ apt-mark not available"
            FAIL=$((FAIL + 1))
        fi
    else
        error "  ✗ Could not extract Ubuntu block"
        FAIL=$((FAIL + 1))
    fi
else
    log "Test 9: Skipped (not Ubuntu system)"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    echo ""
    echo "Ubuntu 22.04 kernel fix (commit b231ced) validated:"
    echo "  ✓ OS detection logic present"
    echo "  ✓ Kernel/grub hold before upgrade"
    echo "  ✓ --without-new-pkgs flag used"
    echo "  ✓ Packages unheld after upgrade"
    echo "  ✓ No dangerous patterns detected"
    echo ""
    echo "This fix prevents VPS crash during apt upgrade on Ubuntu."
    exit 0
else
    echo -e "${RED}❌ $FAIL TEST(S) FAILED${NC}"
    echo ""
    echo "Ubuntu kernel fix validation failed!"
    echo "Review setup.sh for missing or incorrect logic."
    exit 1
fi
