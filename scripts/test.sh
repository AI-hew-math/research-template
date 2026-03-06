#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

# --- 1. Syntax check ---
echo "=== Syntax check ==="
for f in scripts/ai_pack.sh scripts/ai_gate.sh scripts/test.sh; do
  if bash -n "$f"; then
    echo "  OK: $f"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $f"
    FAIL=$((FAIL + 1))
  fi
done

# --- 2. Required files/dirs exist ---
echo "=== Required paths ==="
for p in scripts/ai_pack.sh scripts/ai_gate.sh .ai/approvals .ai/transcripts; do
  if [ -e "$p" ]; then
    echo "  OK: $p"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $p missing"
    FAIL=$((FAIL + 1))
  fi
done

# --- 3. Executable check ---
echo "=== Executable check ==="
for f in scripts/ai_pack.sh scripts/ai_gate.sh; do
  if test -x "$f"; then
    echo "  OK: $f is executable"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $f is not executable"
    FAIL=$((FAIL + 1))
  fi
done

# --- Summary ---
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "✅ All checks passed"
