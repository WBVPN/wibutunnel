#!/bin/bash
# Docker-based integration test runner
# Runs wibutunnel installation in isolated containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test matrix
TEST_IMAGES=(
    "ubuntu:22.04"
    "debian:11"
)

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
TEST_DOMAIN="${TEST_DOMAIN:-test.wibutunnel.local}"

echo "╔══════════════════════════════════════════════════╗"
echo "║  Wibutunnel Docker Integration Test Runner      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Check Docker availability
if ! command -v docker &>/dev/null; then
    echo "❌ Docker not installed"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon not running"
    exit 1
fi

PASSED=0
FAILED=0

# Store PIDs for parallel execution
declare -a TEST_PIDS
declare -A TEST_RESULTS

# Test function for parallel execution
test_image() {
    local image="$1"
    local result_file="$2"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing on: $image"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CONTAINER_NAME="wibutunnel-test-$(echo "$image" | tr ':/' '-')"
    
    # Create container with systemd support
    echo "Creating container: $CONTAINER_NAME"
    docker run -d \
        --name "$CONTAINER_NAME" \
        --privileged \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        "$image" \
        /sbin/init >/dev/null
    
    # Wait for systemd
    sleep 3
    
    # Install prerequisites
    echo "Installing prerequisites..."
    docker exec "$CONTAINER_NAME" bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y git curl systemd jq >/dev/null 2>&1
    " || {
        echo "❌ Failed to install prerequisites"
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
        echo "FAILED" > "$result_file"
        return 1
    }
    
    # Copy integration test script
    docker cp "$SCRIPT_DIR/integration_test.sh" "$CONTAINER_NAME:/root/"
    
    # Run test
    echo "Running integration test..."
    if docker exec \
        -e TEST_DOMAIN="$TEST_DOMAIN" \
        -e GITHUB_TOKEN="$GITHUB_TOKEN" \
        "$CONTAINER_NAME" \
        bash /root/integration_test.sh; then
        echo "✅ $image PASSED"
        TEST_STATUS="PASSED"
    else
        echo "❌ $image FAILED"
        echo ""
        echo "Last 30 lines of log:"
        docker exec "$CONTAINER_NAME" tail -30 /tmp/wibutunnel_integration_test.log 2>/dev/null || true
        TEST_STATUS="FAILED"
    fi
    
    # Cleanup
    echo "Cleaning up container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    
    # Write result to file
    echo "$TEST_STATUS" > "$result_file"
}

# Launch all tests in parallel
echo "⚡ Launching tests in parallel..."
echo ""

for image in "${TEST_IMAGES[@]}"; do
    RESULT_FILE="/tmp/test_result_$(echo "$image" | tr ':/' '-').txt"
    test_image "$image" "$RESULT_FILE" &
    TEST_PIDS+=($!)
    TEST_RESULTS["$image"]="$RESULT_FILE"
done

# Wait for all tests to complete
echo ""
echo "⏳ Waiting for all tests to complete..."
for pid in "${TEST_PIDS[@]}"; do
    wait "$pid"
done

# Collect results
for image in "${TEST_IMAGES[@]}"; do
    RESULT_FILE="${TEST_RESULTS[$image]}"
    if [ -f "$RESULT_FILE" ]; then
        RESULT=$(cat "$RESULT_FILE")
        if [ "$RESULT" = "PASSED" ]; then
            PASSED=$((PASSED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        rm -f "$RESULT_FILE"
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Test Results                                    ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  ✅ Passed: $PASSED/${#TEST_IMAGES[@]}                                   ║"
echo "║  ❌ Failed: $FAILED/${#TEST_IMAGES[@]}                                   ║"
echo "╚══════════════════════════════════════════════════╝"

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
