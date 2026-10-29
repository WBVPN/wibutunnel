#!/bin/bash
set -e
source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh

TEST_DB="/tmp/test_concurrency_$$.db"
rm -f "$TEST_DB"
touch "$TEST_DB"

trap 'rm -f "$TEST_DB" "/etc/wibutunnel/tmp/$(basename "$TEST_DB").lock"' EXIT

echo "1. Testing concurrent db_set (50 concurrent writers)..."
for i in $(seq 1 50); do
    (
        source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh
        db_set "$TEST_DB" "user$i" "val$i"
    ) &
done
wait

COUNT=$(wc -l < "$TEST_DB")
[[ "$COUNT" -eq 50 ]] || { echo "ASSERT_FAILED: expected 50 lines, got $COUNT"; exit 1; }

echo "2. Testing db_get and db_has..."
db_has "$TEST_DB" "user25" || { echo "ASSERT_FAILED: db_has user25 failed"; exit 1; }
VAL=$(db_get "$TEST_DB" "user25")
[[ "$VAL" == "val25" ]] || { echo "ASSERT_FAILED: db_get user25 got '$VAL'"; exit 1; }

! db_has "$TEST_DB" "nonexistent_user" || { echo "ASSERT_FAILED: db_has nonexistent should fail"; exit 1; }

echo "3. Testing special character handling (dot and dash in username)..."
db_set "$TEST_DB" "budi.subekti-vpn" "custom_val"
db_has "$TEST_DB" "budi.subekti-vpn" || { echo "ASSERT_FAILED: db_has special char failed"; exit 1; }
VAL_SPEC=$(db_get "$TEST_DB" "budi.subekti-vpn")
[[ "$VAL_SPEC" == "custom_val" ]] || { echo "ASSERT_FAILED: db_get special char got '$VAL_SPEC'"; exit 1; }

echo "4. Testing concurrent update & delete (25 delete, 25 update)..."
for i in $(seq 1 50); do
    (
        source /usr/local/bin/common.sh 2>/dev/null || source ./common.sh
        if (( i % 2 == 1 )); then
            safe_sed_delete "user$i" "$TEST_DB"
        else
            db_set "$TEST_DB" "user$i" "updated_val$i"
        fi
    ) &
done
wait

REMAINING=$(wc -l < "$TEST_DB")
# 25 even users + 1 special user = 26 lines
[[ "$REMAINING" -eq 26 ]] || { echo "ASSERT_FAILED: expected 26 lines, got $REMAINING"; exit 1; }

! db_has "$TEST_DB" "user1" || { echo "ASSERT_FAILED: user1 should be deleted"; exit 1; }
VAL_EVEN=$(db_get "$TEST_DB" "user2")
[[ "$VAL_EVEN" == "updated_val2" ]] || { echo "ASSERT_FAILED: user2 update failed: '$VAL_EVEN'"; exit 1; }

echo "ALL_DB_FLOCK_ASSERTS_PASSED"
