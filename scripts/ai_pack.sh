#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
TEST_CMD="${TEST_CMD:-make test}"
PACKET_DIR=".ai/packets/${RUN_ID}"

# Persist RUN_ID for gate script
echo "$RUN_ID" > .ai/LAST_RUN_ID

mkdir -p "$PACKET_DIR"

echo "=== ai_pack: RUN_ID=${RUN_ID} ==="

# Git snapshots
git status               > "$PACKET_DIR/git_status.txt"   2>&1 || true
git diff                 > "$PACKET_DIR/git_diff.txt"     2>&1 || true
git diff --stat          > "$PACKET_DIR/git_diff_stat.txt" 2>&1 || true
git log --oneline -20    > "$PACKET_DIR/git_log.txt"      2>&1 || true

# Test run
echo "Running: $TEST_CMD"
eval "$TEST_CMD" > "$PACKET_DIR/test_output.txt" 2>&1 && TEST_EXIT=0 || TEST_EXIT=$?

# Packet summary
cat > "$PACKET_DIR/PACKET.md" <<EOF
# Packet ${RUN_ID}

## Test Result
- Command: \`${TEST_CMD}\`
- Exit code: ${TEST_EXIT}

## Files
- git_status.txt
- git_diff.txt
- git_diff_stat.txt
- git_log.txt
- test_output.txt
EOF

echo "Packet created: $PACKET_DIR/PACKET.md (test exit=$TEST_EXIT)"
echo "$RUN_ID"
