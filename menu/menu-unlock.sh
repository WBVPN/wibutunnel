#!/bin/bash
# ==========================================
# WIBU TUNNELING - menu-unlock.sh (v4.0.6 KURUMI)
# Alias to menu-recovery
# ==========================================
if command -v menu-recovery &>/dev/null; then
    exec menu-recovery "$@"
else
    exec "$(dirname "$0")/menu-recovery.sh" "$@"
fi
