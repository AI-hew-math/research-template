#!/usr/bin/env bash
set -euo pipefail

# Codex whitelist guard:
# Blocks review/merge if ai/claude contains changes outside the allowed files.

usage() {
  echo "Usage: $0 <base_ref> <review_ref>" >&2
  echo "Example: $0 origin/main ai/claude" >&2
}

BASE_REF="${1:-}"
REVIEW_REF="${2:-}"

if [ -z "$BASE_REF" ] || [ -z "$REVIEW_REF" ]; then
  usage
  exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "BLOCKED: not a git repository (run from repo root)." >&2
  exit 1
fi

if ! git rev-parse --verify -q "$BASE_REF" >/dev/null; then
  echo "BLOCKED: base ref not found: $BASE_REF" >&2
  exit 1
fi

if ! git rev-parse --verify -q "$REVIEW_REF" >/dev/null; then
  echo "BLOCKED: review ref not found: $REVIEW_REF" >&2
  exit 1
fi

# Allowed paths (regex):
# - .ai/approvals/*
# - .ai/transcripts/*
# - .ai/LAST_RUN_ID
# - README.md
# - .ai/{PLAN,HANDOFF_TO_CLAUDE,STATE,REVIEW}.md
ALLOW_RE='^(README\.md|\.ai/(LAST_RUN_ID$|approvals/|transcripts/|(PLAN|HANDOFF_TO_CLAUDE|STATE|REVIEW)\.md$))'

# Files changed in the reviewed branch relative to base.
mapfile -t files < <(git diff --name-only "$BASE_REF...$REVIEW_REF" | sed '/^$/d')

if [ "${#files[@]}" -eq 0 ]; then
  echo "OK: no changes detected between $BASE_REF...$REVIEW_REF"
  exit 0
fi

blocked=()
for f in "${files[@]}"; do
  if ! [[ "$f" =~ $ALLOW_RE ]]; then
    blocked+=("$f")
  fi
done

if [ "${#blocked[@]}" -gt 0 ]; then
  echo "BLOCKED: unexpected file changes detected (whitelist policy)." >&2
  echo "  This run must be treated as REQUEST_CHANGES." >&2
  echo "  Do NOT approve/merge/push. Ask Claude to adjust the change set." >&2
  echo "Unexpected files:" >&2
  for f in "${blocked[@]}"; do
    echo "- $f" >&2
  done
  exit 1
fi

echo "OK: whitelist guard passed for $BASE_REF...$REVIEW_REF"
exit 0
