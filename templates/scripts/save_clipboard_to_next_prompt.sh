#!/bin/bash
# save_clipboard_to_next_prompt.sh - 클립보드 내용을 최신 cycle의 next_prompt.txt에 저장
#
# Usage:
#   ./scripts/save_clipboard_to_next_prompt.sh          # pbpaste 사용 (macOS)
#   echo "content" | ./scripts/save_clipboard_to_next_prompt.sh --stdin  # stdin 사용
#
# 출력: review_cycles/cycle_XXXX/to_claude/next_prompt.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REVIEW_CYCLES_DIR="$PROJECT_DIR/review_cycles"

# --- Parse arguments ---
USE_STDIN=0
for arg in "$@"; do
    if [[ "$arg" == "--stdin" ]]; then
        USE_STDIN=1
    fi
done

# --- Check review_cycles exists ---
if [[ ! -d "$REVIEW_CYCLES_DIR" ]]; then
    echo "Error: review_cycles/ 디렉토리가 없습니다." >&2
    echo "먼저 agent 세션을 실행하여 cycle을 생성하세요." >&2
    exit 1
fi

# --- Find latest cycle ---
LATEST_CYCLE=$(find "$REVIEW_CYCLES_DIR" -maxdepth 1 -type d -name "cycle_*" 2>/dev/null | sort -V | tail -1)

if [[ -z "$LATEST_CYCLE" ]]; then
    echo "Error: review_cycles/에 cycle_* 디렉토리가 없습니다." >&2
    echo "먼저 agent 세션을 실행하여 cycle을 생성하세요." >&2
    exit 1
fi

CYCLE_NAME=$(basename "$LATEST_CYCLE")

# --- Get content ---
if [[ $USE_STDIN -eq 1 ]]; then
    CONTENT=$(cat)
else
    # Check pbpaste exists (macOS only)
    if ! command -v pbpaste &> /dev/null; then
        echo "Error: pbpaste 명령어가 없습니다 (macOS 전용)." >&2
        echo "대안: echo \"내용\" | ./scripts/save_clipboard_to_next_prompt.sh --stdin" >&2
        exit 1
    fi
    CONTENT=$(pbpaste)
fi

if [[ -z "$CONTENT" ]]; then
    echo "Error: 클립보드가 비어있습니다." >&2
    exit 1
fi

# --- Save to to_claude/next_prompt.txt ---
TO_CLAUDE_DIR="$LATEST_CYCLE/to_claude"
mkdir -p "$TO_CLAUDE_DIR"

OUTPUT_FILE="$TO_CLAUDE_DIR/next_prompt.txt"
echo "$CONTENT" > "$OUTPUT_FILE"

echo "[save_clipboard] Saved to: $CYCLE_NAME/to_claude/next_prompt.txt"
echo "[save_clipboard] Size: $(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes"
