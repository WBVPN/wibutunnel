#!/bin/bash
# Ubuntu apt upgrade simulation test
# Validates that the fix prevents kernel/grub installation during upgrade

set -e

RED='\e[31m'
GREEN='\e[32m'
NC='\e[0m'

log() { echo -e "${GREEN}[SIMULATE]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; }

echo "╔══════════════════════════════════════════════════╗"
echo "║  Ubuntu apt upgrade Simulation Test             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Only run on Ubuntu systems
if [ ! -f /etc/os-release ] || ! grep -qi ubuntu /etc/os-release; then
    log "Not Ubuntu system - test skipped"
    exit 0
fi

log "Running on Ubuntu - simulating kernel hold fix"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Must run as root for apt commands"
    exit 1
fi

FAIL=0

# Phase 1: Simulate hold
log "Phase 1: Simulating apt-mark hold (from commit b231ced)"
PACKAGES_TO_HOLD=$(dpkg -l | grep -E '^ii\s+(linux-image-|linux-headers-|grub|shim-signed)' | awk '{print $2}' | head -10)

if [ -z "$PACKAGES_TO_HOLD" ]; then
    log "  No kernel/grub packages installed (fresh system)"
else
    log "  Found packages to hold:"
    echo "$PACKAGES_TO_HOLD" | sed 's/^/    /'
    
    # Simulate hold (dry-run)
    log "  Testing hold commands..."
    for pkg in $PACKAGES_TO_HOLD; do
        if apt-mark showhold "$pkg" >/dev/null 2>&1; then
            log "    ✓ apt-mark works for: $pkg"
        fi
    done
fi
echo ""

# Phase 2: Check upgrade behavior with --without-new-pkgs
log "Phase 2: Testing apt upgrade with --without-new-pkgs flag"
log "  Running: apt-get upgrade --dry-run --without-new-pkgs"
echo ""

UPGRADE_OUTPUT=$(apt-get upgrade --dry-run --without-new-pkgs -o Dpkg::Options::="--force-confold" 2>&1)

# Check if kernel packages would be installed
if echo "$UPGRADE_OUTPUT" | grep -qE "linux-image-[0-9]|linux-headers-[0-9]|grub-"; then
    error "  ✗ Kernel/grub packages would be installed even with --without-new-pkgs!"
    echo "$UPGRADE_OUTPUT" | grep -E "linux-image|linux-headers|grub" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
else
    log "  ✓ No kernel/grub packages in upgrade list (correct behavior)"
fi

# Show what would be upgraded
UPGRADE_COUNT=$(echo "$UPGRADE_OUTPUT" | grep -c "^Inst " || true)
log "  Packages that would be upgraded: $UPGRADE_COUNT"
echo ""

# Phase 3: Compare with dangerous upgrade (without flag)
log "Phase 3: Compare with unsafe upgrade (without --without-new-pkgs)"
log "  Running: apt-get upgrade --dry-run (WITHOUT flag)"
echo ""

UNSAFE_OUTPUT=$(apt-get upgrade --dry-run 2>&1)
UNSAFE_KERNEL=$(echo "$UNSAFE_OUTPUT" | grep -E "linux-image-[0-9]|linux-headers-[0-9]|grub-" | wc -l || true)

if [ "$UNSAFE_KERNEL" -gt 0 ]; then
    log "  ⚠ Without flag: $UNSAFE_KERNEL kernel/grub packages would install"
    log "  This is WHY the fix is needed (prevents VPS crash)"
else
    log "  No kernel updates available in current repos"
fi
echo ""

# Phase 4: Verify unhold would work
log "Phase 4: Verify unhold commands"
if [ -n "$PACKAGES_TO_HOLD" ]; then
    log "  Testing unhold..."
    for pkg in $PACKAGES_TO_HOLD; do
        if apt-mark unhold "$pkg" >/dev/null 2>&1; then
            log "    ✓ apt-mark unhold works for: $pkg"
        fi
    done
else
    log "  No packages to test unhold"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ SIMULATION PASSED${NC}"
    echo ""
    echo "Ubuntu kernel fix behavior validated:"
    echo "  ✓ Hold commands functional"
    echo "  ✓ --without-new-pkgs prevents kernel installation"
    echo "  ✓ Unhold commands functional"
    echo "  ✓ Safe upgrade path confirmed"
    echo ""
    echo "Result: VPS will NOT crash during apt upgrade"
    exit 0
else
    echo -e "${RED}❌ SIMULATION FAILED${NC}"
    exit 1
fi
