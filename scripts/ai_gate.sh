#!/usr/bin/env bash
set -euo pipefail

# ---- 1. Read RUN_ID from .ai/LAST_RUN_ID ----
RUN_ID_FILE=".ai/LAST_RUN_ID"

if [ ! -f "$RUN_ID_FILE" ] || [ ! -s "$RUN_ID_FILE" ]; then
  echo "BLOCKED: .ai/LAST_RUN_ID is missing or empty."
  echo "  → Run  TEST_CMD=\"make test\" ./scripts/ai_pack.sh  first."
  exit 1
fi

RUN_ID="$(cat "$RUN_ID_FILE" | tr -d '[:space:]')"
echo "Checking gate for RUN_ID=${RUN_ID}"

# ---- 2. Approval file ----
APPROVAL=".ai/approvals/${RUN_ID}.approved"

if [ ! -f "$APPROVAL" ]; then
  echo "BLOCKED: No approval file — expected ${APPROVAL}"
  echo "  → Codex(Brain) must create this file with 'verdict: APPROVE'."
  exit 1
fi

if ! grep -qi "verdict: APPROVE" "$APPROVAL"; then
  echo "BLOCKED: Approval file exists but does not contain 'verdict: APPROVE'."
  echo "  → File: ${APPROVAL}"
  exit 1
fi

if ! grep -qi "run_id:[[:space:]]*${RUN_ID}" "$APPROVAL"; then
  echo "BLOCKED: Approval file does not contain 'run_id: ${RUN_ID}'."
  echo "  → The approval must reference the current RUN_ID."
  echo "  → File: ${APPROVAL}"
  exit 1
fi

# ---- 3. Transcript file ----
TRANSCRIPT=".ai/transcripts/claude_${RUN_ID}.md"

if [ ! -f "$TRANSCRIPT" ]; then
  echo "BLOCKED: No transcript — expected ${TRANSCRIPT}"
  echo "  → Claude(Hands) must export the session transcript."
  exit 1
fi

if [ ! -s "$TRANSCRIPT" ]; then
  echo "BLOCKED: Transcript exists but is empty — ${TRANSCRIPT}"
  echo "  → Re-export or write the transcript with actual content."
  exit 1
fi

# ---- 4. All checks passed ----
echo "OK: Gate passed for RUN_ID=${RUN_ID}"
exit 0
