#!/bin/bash
# Centralized Test Configuration
# Single source of truth for all wibutunnel test scripts
# Source this file: source test/test_config.sh

# Services to validate
export WIBU_SERVICES="xray haproxy dropbear ws-stunnel"

# Binary paths to check
export WIBU_BINARIES="/usr/local/bin/xray /usr/local/bin/menu /usr/local/bin/m-backup /usr/local/bin/m-restore"

# SSL certificate files (for backup validation)
export WIBU_SSL_FILES="fullchain.pem privkey.pem cert.pem chain.pem"

# Menu scripts (in bin/ directory)
export WIBU_MENU_SCRIPTS="menu m-backup m-restore m-vless m-setting"

# Test timeouts
export WIBU_INSTALL_TIMEOUT=1800  # 30 minutes
export WIBU_SERVICE_TIMEOUT=30     # 30 seconds per service

# Test domain default
export WIBU_TEST_DOMAIN="${TEST_DOMAIN:-test.wibutunnel.local}"

# Log file location
export WIBU_LOG_FILE="${LOG_FILE:-/tmp/wibutunnel_integration_test.log}"
