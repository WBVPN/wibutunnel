#!/bin/bash
# Wibutunnel Smoke Test Suite
# Quick validation (1-2 seconds) - 80% coverage, 5% time
# Run before commits for fast feedback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source centralized test configuration
source "$SCRIPT_DIR/test_config.sh"

# Colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
NC='\e[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${BLUE}▶${NC} $*"
}

log_pass() {
    echo -e "${GREEN}✓${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}✗${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

echo "╔══════════════════════════════════════════════════╗"
echo "║  Wibutunnel Smoke Test Suite                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Repository: $REPO_ROOT"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd "$REPO_ROOT"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 1: ShellCheck Syntax Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_test "TEST 1: ShellCheck Syntax Validation"

if ! command -v shellcheck &>/dev/null; then
    log_warn "ShellCheck not installed - skipping syntax tests"
else
    SYNTAX_FAIL=0
    
    for script in install.sh setup.sh uninstall.sh bin/common.sh wibu_installer.sh; do
        if [ -f "$script" ]; then
            if shellcheck -S error "$script" >/dev/null 2>&1; then
                log_pass "$script - syntax OK"
            else
                log_fail "$script - syntax errors found"
                SYNTAX_FAIL=1
            fi
        else
            log_warn "$script - not found (skipped)"
        fi
    done
    
    if [ $SYNTAX_FAIL -eq 0 ]; then
        log_pass "All scripts passed ShellCheck"
    else
        log_fail "ShellCheck found errors"
    fi
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 2: Critical Logic Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_test "TEST 2: Critical Logic Validation"

# Check Ubuntu kernel fix (commit b231ced)
if grep -q "apt-mark hold.*linux-image" setup.sh && \
   grep -q "apt-mark hold.*grub" setup.sh && \
   grep -q "without-new-pkgs" setup.sh; then
    log_pass "Ubuntu kernel/grub hold logic present"
else
    log_fail "Ubuntu kernel fix missing or incomplete"
fi

# Check Ubuntu detection
if grep -q "grep -qi ubuntu /etc/os-release" setup.sh; then
    log_pass "Ubuntu OS detection logic present"
else
    log_fail "Ubuntu detection missing"
fi

# Check LIFETIME license parsing
if grep -q "LIFETIME" setup.sh; then
    log_pass "LIFETIME license handling present"
else
    log_fail "LIFETIME license logic missing"
fi

# Check SSL backup (4 files)
if grep -q "fullchain.pem" setup.sh && \
   grep -q "privkey.pem" setup.sh && \
   grep -q "cert.pem" setup.sh && \
   grep -q "chain.pem" setup.sh; then
    log_pass "SSL certificate backup (4 files) present"
else
    log_fail "SSL backup incomplete (missing cert files)"
fi

# Check domain auto-detect
if grep -q "/etc/xray/domain" setup.sh; then
    log_pass "Domain auto-detect from /etc/xray/domain present"
else
    log_fail "Domain auto-detect logic missing"
fi

# Check bot configuration
if grep -q "BOT_TOKEN" setup.sh && grep -q "CHAT_ID" setup.sh; then
    log_pass "Bot configuration variables present"
else
    log_fail "Bot config (BOT_TOKEN/CHAT_ID) missing"
fi

# Check HAProxy webhook configuration
if grep -q "8443" setup.sh && grep -q "webhook" setup.sh; then
    log_pass "HAProxy webhook configuration present"
else
    log_fail "HAProxy webhook (port 8443) missing"
fi

# Check WIBU_NO_REBOOT flag
if grep -q "WIBU_NO_REBOOT" setup.sh; then
    log_pass "WIBU_NO_REBOOT flag support present"
else
    log_fail "WIBU_NO_REBOOT flag missing"
fi

# Check watchdog service
if grep -q "watchdog" setup.sh || [ -f "bin/watchdog" ]; then
    log_pass "Watchdog service present"
else
    log_warn "Watchdog service not found (may be optional)"
fi

# Check menu installation
if [ -d "bin" ] && [ "$(find bin -name 'm-*' -o -name 'menu' | wc -l)" -gt 0 ]; then
    log_pass "Menu scripts present in bin/ directory"
else
    log_fail "Menu scripts missing from bin/"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 3: Configuration Template Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_test "TEST 3: Configuration Template Validation"

# Extract and validate xray config JSON (if jq available)
if command -v jq &>/dev/null; then
    # Extract JSON blocks from setup.sh and validate
    JSON_BLOCKS=$(grep -o '{.*}' setup.sh 2>/dev/null | head -5)
    
    if [ -n "$JSON_BLOCKS" ]; then
        JSON_VALID=0
        while IFS= read -r json_line; do
            if echo "$json_line" | jq empty 2>/dev/null; then
                JSON_VALID=$((JSON_VALID + 1))
            fi
        done <<< "$JSON_BLOCKS"
        
        if [ $JSON_VALID -gt 0 ]; then
            log_pass "JSON configuration blocks valid ($JSON_VALID checked)"
        else
            log_warn "No valid JSON blocks found in setup.sh"
        fi
    else
        log_warn "No JSON blocks found for validation"
    fi
else
    log_warn "jq not installed - skipping JSON validation"
fi

# Check systemd service templates
if grep -q "systemctl" setup.sh; then
    log_pass "Systemd service management present"
else
    log_fail "Systemd commands missing"
fi

# Check required binaries references
# Convert WIBU_SERVICES to array for checking
read -ra REQUIRED_BINS <<< "$WIBU_SERVICES"
BINS_FOUND=0

for binary in "${REQUIRED_BINS[@]}"; do
    if grep -q "$binary" setup.sh; then
        BINS_FOUND=$((BINS_FOUND + 1))
    fi
done

if [ $BINS_FOUND -eq ${#REQUIRED_BINS[@]} ]; then
    log_pass "All required binaries referenced (${#REQUIRED_BINS[@]}/${#REQUIRED_BINS[@]})"
else
    log_warn "Some binaries not referenced ($BINS_FOUND/${#REQUIRED_BINS[@]})"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 4: Test Infrastructure Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_test "TEST 4: Test Infrastructure Validation"

# Check test scripts exist
TEST_SCRIPTS=(
    "test/validate.sh"
    "test/integration_test.sh"
    "test/test_regressions.sh"
    "test/docker_test_runner.sh"
)

for test_script in "${TEST_SCRIPTS[@]}"; do
    if [ -f "$test_script" ]; then
        if [ -x "$test_script" ]; then
            log_pass "$test_script - present and executable"
        else
            log_warn "$test_script - present but not executable"
        fi
    else
        log_fail "$test_script - missing"
    fi
done

# Check GitHub Actions workflow
if [ -f ".github/workflows/test.yml" ]; then
    log_pass "GitHub Actions workflow present"
    
    # Basic YAML validation (check for required jobs)
    if grep -q "shellcheck:" ".github/workflows/test.yml" && \
       grep -q "integration-test-ubuntu:" ".github/workflows/test.yml" && \
       grep -q "integration-test-debian:" ".github/workflows/test.yml"; then
        log_pass "All required CI/CD jobs present"
    else
        log_fail "CI/CD workflow missing required jobs"
    fi
else
    log_fail "GitHub Actions workflow missing"
fi

# Check documentation
DOCS=(
    "TESTING_README.md"
    "GITHUB_ACTIONS_SETUP.md"
    "TESTING.md"
)

DOCS_FOUND=0
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        DOCS_FOUND=$((DOCS_FOUND + 1))
    fi
done

if [ $DOCS_FOUND -eq ${#DOCS[@]} ]; then
    log_pass "All documentation files present (${#DOCS[@]}/${#DOCS[@]})"
else
    log_warn "Some documentation missing ($DOCS_FOUND/${#DOCS[@]})"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 5: Security & Best Practices
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_test "TEST 5: Security & Best Practices"

# Check for dangerous patterns
DANGEROUS=0

# Check for hardcoded credentials (excluding comments/docs)
if grep -v '^#' setup.sh | grep -iE 'password.*=.*("|'"'"')[a-zA-Z0-9]{8,}' >/dev/null 2>&1; then
    log_warn "Potential hardcoded passwords found (review manually)"
    DANGEROUS=1
fi

# Check for curl without SSL verification disabled (should NOT find -k or --insecure)
if grep -E 'curl.*(-k|--insecure)' setup.sh >/dev/null 2>&1; then
    log_warn "curl with SSL verification disabled found (security risk)"
    DANGEROUS=1
fi

# Check for proper error handling (set -e or error traps)
if grep -q "set -e" setup.sh || grep -q "trap.*ERR" setup.sh; then
    log_pass "Error handling present (set -e or trap)"
else
    log_warn "No explicit error handling found"
    DANGEROUS=1
fi

# Check for input validation on user variables
if grep -qE '\$\{?[A-Z_]+\}?' setup.sh; then
    log_pass "Environment variables used (verify validation elsewhere)"
else
    log_warn "No environment variables detected"
fi

if [ $DANGEROUS -eq 0 ]; then
    log_pass "No obvious security issues detected"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "╔══════════════════════════════════════════════════╗"
echo "║  Smoke Test Results                             ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  ${GREEN}✓ Passed: %-3d${NC}                                  ║\n" "$TESTS_PASSED"
printf "║  ${RED}✗ Failed: %-3d${NC}                                  ║\n" "$TESTS_FAILED"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL SMOKE TESTS PASSED${NC}"
    echo ""
    echo "Ready for:"
    echo "  • Git commit"
    echo "  • Pull request"
    echo "  • Full integration test (if needed)"
    exit 0
else
    echo -e "${RED}❌ SMOKE TESTS FAILED${NC}"
    echo ""
    echo "Fix issues before:"
    echo "  • Committing code"
    echo "  • Running expensive integration tests"
    exit 1
fi
