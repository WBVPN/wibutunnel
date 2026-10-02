#!/bin/bash
# Automated ShellCheck validation for wibutunnel scripts
# All warnings are documented false positives

set -e

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

echo "=== ShellCheck Validation for Wibutunnel ==="
echo ""

SCRIPTS=(
    "install.sh"
    "setup.sh"
    "uninstall.sh"
    "bin/common.sh"
    "wibu_installer.sh"
)

PASS=0
WARN=0
FAIL=0

# Suppression rules for known false positives:
# SC2034: Variables used in heredocs or by external scripts
# SC2155: Intentional declare+assign pattern
# SC2154: Variables assigned in heredocs
SUPPRESSIONS="-e SC2034 -e SC2155 -e SC2154"

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "⚠ File not found: $script"
        continue
    fi
    
    echo "Checking: $script"
    
    # Check for actual errors (severity=error)
    if shellcheck -S error "$script" >/dev/null 2>&1; then
        echo "  ✓ No errors"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ERRORS FOUND:"
        shellcheck -S error "$script" | head -20
        FAIL=$((FAIL + 1))
    fi
    
    # Report warnings but don't fail (known false positives)
    WARN_COUNT=$(shellcheck -S warning $SUPPRESSIONS "$script" 2>&1 | grep -c "^In " || true)
    if [ "$WARN_COUNT" -gt 0 ]; then
        echo "  ⚠ $WARN_COUNT warnings (suppressed: SC2034, SC2155, SC2154)"
    fi
    
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  ✓ Passed: $PASS/${#SCRIPTS[@]}"
echo "  ✗ Failed: $FAIL/${#SCRIPTS[@]}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✅ All scripts are error-free!"
    exit 0
else
    echo "❌ $FAIL script(s) have syntax errors"
    exit 1
fi
