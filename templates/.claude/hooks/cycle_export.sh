#!/bin/bash
# cycle_export.sh - GPT 검토 사이클용 파일 자동 export
#
# Agent hooks에서 호출됨:
#   - UserPromptSubmit: cycle +1, user_prompt.txt 저장
#   - Stop: 해당 cycle export, last_assistant_message.md 저장
#   - SessionStart: 초기화 (cycle 증가 없음)
#   - SessionEnd: 안전망 export
#
# stdin JSON 입력 예시:
#   UserPromptSubmit: {"hook_event_name", "cwd", "prompt", "session_id"}
#   Stop: {"hook_event_name", "cwd", "transcript_path", "stop_hook_active", "last_assistant_message"}
#
# 출력 구조:
#   review_cycles/cycle_XXXX/
#   ├── to_gpt/
#   │   ├── UPLOAD_LIST.md
#   │   ├── packet.md
#   │   ├── user_prompt.txt
#   │   ├── last_assistant_message.md
#   │   ├── git_head.txt, git_status.txt, git_diff.patch
#   │   └── claude_transcript.jsonl
#   ├── from_gpt/
#   └── to_claude/

set -e

# --- Temp files for multiline-safe parsing ---
TMPFILE=$(mktemp)
PROMPT_FILE=$(mktemp)
ASSISTANT_FILE=$(mktemp)

cleanup_temp() {
    rm -f "$TMPFILE" "$PROMPT_FILE" "$ASSISTANT_FILE" 2>/dev/null || true
}
trap cleanup_temp EXIT

cat > "$TMPFILE"

# --- Parse JSON using python3 (multiline-safe) ---
# Python writes multiline fields to temp files, prints single-line fields to stdout
PARSED=$(python3 - "$TMPFILE" "$PROMPT_FILE" "$ASSISTANT_FILE" << 'PYEOF'
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)

    # Write multiline fields directly to files (preserves newlines)
    prompt = data.get('prompt', '')
    if prompt:
        with open(sys.argv[2], 'w') as f:
            f.write(prompt)

    assistant_msg = data.get('last_assistant_message', '')
    if assistant_msg:
        with open(sys.argv[3], 'w') as f:
            f.write(assistant_msg)

    # Print single-line fields (safe for sed parsing)
    print(data.get('cwd', ''))
    print(data.get('transcript_path', ''))
    print(data.get('hook_event_name', ''))
    print(data.get('task_subject', ''))
    print(str(data.get('stop_hook_active', '')))
except Exception as e:
    for _ in range(5):
        print('')
PYEOF
)

# Read single-line values (safe since they cannot contain newlines)
CWD=$(echo "$PARSED" | sed -n '1p')
TRANSCRIPT_PATH=$(echo "$PARSED" | sed -n '2p')
HOOK_EVENT=$(echo "$PARSED" | sed -n '3p')
TASK_SUBJECT=$(echo "$PARSED" | sed -n '4p')
STOP_HOOK_ACTIVE=$(echo "$PARSED" | sed -n '5p')

# Multiline content will be read from temp files when needed

# --- Validate cwd ---
if [[ -z "$CWD" || ! -d "$CWD" ]]; then
    exit 0  # Graceful exit if cwd is invalid
fi

# --- State directory and cycle file ---
STATE_DIR="$CWD/.claude/state"
CYCLE_FILE="$STATE_DIR/current_cycle.txt"
mkdir -p "$STATE_DIR"

# --- Handle cycle number based on event type ---
case "$HOOK_EVENT" in
    "UserPromptSubmit")
        # Increment cycle on each new prompt
        if [[ -f "$CYCLE_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE" 2>/dev/null || echo "0")
        else
            CURRENT_CYCLE=0
        fi
        CURRENT_CYCLE=$((CURRENT_CYCLE + 1))
        echo "$CURRENT_CYCLE" > "$CYCLE_FILE"
        ;;
    "SessionStart")
        # Initialize only if no cycle file exists (don't increment)
        if [[ ! -f "$CYCLE_FILE" ]]; then
            echo "0" > "$CYCLE_FILE"
        fi
        CURRENT_CYCLE=$(cat "$CYCLE_FILE" 2>/dev/null || echo "0")
        # If cycle is 0, this is first session - wait for first prompt
        if [[ "$CURRENT_CYCLE" == "0" ]]; then
            exit 0  # Don't create cycle_0000
        fi
        ;;
    "Stop"|"SessionEnd")
        # Read existing cycle (don't increment)
        if [[ -f "$CYCLE_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE" 2>/dev/null || echo "0")
        else
            CURRENT_CYCLE=0
        fi
        # If no cycle yet, nothing to export
        if [[ "$CURRENT_CYCLE" == "0" ]]; then
            exit 0
        fi
        ;;
    *)
        # Unknown event - try to read existing cycle
        if [[ -f "$CYCLE_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE" 2>/dev/null || echo "1")
        else
            CURRENT_CYCLE=1
            echo "$CURRENT_CYCLE" > "$CYCLE_FILE"
        fi
        ;;
esac

# --- Format cycle number as 4-digit ---
CYCLE_ID=$(printf "cycle_%04d" "$CURRENT_CYCLE")

# --- Slugify task_subject ---
slugify() {
    local input="$1"
    local max_len="${2:-80}"
    if [[ -z "$input" ]]; then
        echo "prompt"
        return
    fi
    local slug=$(echo "$input" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')
    echo "${slug:0:$max_len}"
}

TASK_SLUG=$(slugify "$TASK_SUBJECT")

# --- Create cycle directories ---
CYCLE_DIR="$CWD/review_cycles/$CYCLE_ID"
TO_GPT="$CYCLE_DIR/to_gpt"
FROM_GPT="$CYCLE_DIR/from_gpt"
TO_CLAUDE="$CYCLE_DIR/to_claude"

mkdir -p "$TO_GPT" "$FROM_GPT" "$TO_CLAUDE"

# --- Save user_prompt.txt on UserPromptSubmit (multiline-safe) ---
if [[ "$HOOK_EVENT" == "UserPromptSubmit" && -s "$PROMPT_FILE" ]]; then
    cp "$PROMPT_FILE" "$TO_GPT/user_prompt.txt"
fi

# --- Save last_assistant_message.md on Stop (multiline-safe) ---
if [[ "$HOOK_EVENT" == "Stop" && -s "$ASSISTANT_FILE" ]]; then
    cp "$ASSISTANT_FILE" "$TO_GPT/last_assistant_message.md"
fi

# --- Handle stop_hook_active (relaxed policy) ---
# When stop_hook_active is True, we already saved last_assistant_message.md above.
# Now skip heavy operations (git, transcript, packet) to prevent infinite loops.
if [[ "$STOP_HOOK_ACTIVE" == "True" ]]; then
    exit 0
fi

# --- Event-based workload gating ---
# UserPromptSubmit: lightweight (cycle++, dirs, user_prompt.txt, minimal packet)
# Stop/SessionEnd: heavy (last_assistant_message.md, transcript, git info, full packet)

GIT_HEAD=""
GIT_STATUS=""
GIT_DIFF=""
IS_GIT_REPO=false

# Only gather git info on Stop/SessionEnd (expensive operations)
if [[ "$HOOK_EVENT" == "Stop" || "$HOOK_EVENT" == "SessionEnd" ]]; then
    if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
        IS_GIT_REPO=true
        GIT_HEAD=$(git -C "$CWD" rev-parse HEAD 2>/dev/null || echo "")
        GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null || echo "")
        GIT_DIFF=$(git -C "$CWD" diff HEAD 2>/dev/null || echo "")
    fi

    # Export git files
    if [[ "$IS_GIT_REPO" == true ]]; then
        printf '%s\n' "$GIT_HEAD" > "$TO_GPT/git_head.txt"
        printf '%s\n' "$GIT_STATUS" > "$TO_GPT/git_status.txt"
        if [[ -n "$GIT_DIFF" ]]; then
            printf '%s\n' "$GIT_DIFF" > "$TO_GPT/git_diff.patch"
        else
            echo "# No uncommitted changes" > "$TO_GPT/git_diff.patch"
        fi
    fi

    # Export transcript (only on Stop/SessionEnd)
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
        cp "$TRANSCRIPT_PATH" "$TO_GPT/claude_transcript.jsonl"
    fi
fi

# --- Generate packet.md (event-gated) ---
TIMESTAMP=$(date -Iseconds)

# On UserPromptSubmit: minimal packet (just metadata + user_prompt)
# On Stop/SessionEnd: full packet with all files
if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
    cat > "$TO_GPT/packet.md" << EOF
# Review Packet: $CYCLE_ID (In Progress)

## Metadata

| Field | Value |
|-------|-------|
| **Cycle** | $CYCLE_ID |
| **Event** | $HOOK_EVENT |
| **Task** | $TASK_SLUG |
| **Timestamp** | $TIMESTAMP |

## Status

프롬프트 수신 완료. Agent 응답 대기 중...

## Files

- \`user_prompt.txt\` - 사용자 프롬프트
EOF

    cat > "$TO_GPT/UPLOAD_LIST.md" << EOF
# GPT Upload Guide: $CYCLE_ID (In Progress)

Agent가 응답 중입니다. Stop 이벤트 후 전체 패킷이 생성됩니다.
EOF

else
    # Stop/SessionEnd: full packet
    cat > "$TO_GPT/packet.md" << EOF
# Review Packet: $CYCLE_ID

## Metadata

| Field | Value |
|-------|-------|
| **Cycle** | $CYCLE_ID |
| **Event** | $HOOK_EVENT |
| **Task** | $TASK_SLUG |
| **Timestamp** | $TIMESTAMP |
| **Git HEAD** | ${GIT_HEAD:-N/A} |
| **Transcript** | ${TRANSCRIPT_PATH:-N/A} |

## Context

이 패킷은 agent 프롬프트 완료 시 자동 생성됩니다.
GPT에게 검토를 요청할 때 이 폴더의 파일들을 업로드하세요.

## Files in This Packet

$(if [[ -f "$TO_GPT/user_prompt.txt" ]]; then
echo "- \`user_prompt.txt\` - 사용자 프롬프트"
fi)
$(if [[ -f "$TO_GPT/last_assistant_message.md" ]]; then
echo "- \`last_assistant_message.md\` - Agent 최종 응답"
fi)
$(if [[ "$IS_GIT_REPO" == true ]]; then
echo "- \`git_head.txt\` - 현재 커밋 SHA"
echo "- \`git_status.txt\` - git status 출력"
echo "- \`git_diff.patch\` - uncommitted 변경사항"
fi)
$(if [[ -f "$TO_GPT/claude_transcript.jsonl" ]]; then
echo "- \`claude_transcript.jsonl\` - Agent 대화 기록"
fi)
- \`UPLOAD_LIST.md\` - 업로드 가이드
- \`packet.md\` - 이 메타데이터 파일
EOF

    cat > "$TO_GPT/UPLOAD_LIST.md" << EOF
# GPT Upload Guide: $CYCLE_ID

## 읽는 순서

1. **이 파일 (UPLOAD_LIST.md)** - 업로드 가이드
2. **packet.md** - 메타데이터
3. **user_prompt.txt** - 사용자가 보낸 프롬프트
4. **last_assistant_message.md** - Agent 최종 응답
5. **git_diff.patch** - 코드 변경사항 (있는 경우)

## 검토 요청 질문

GPT에게 다음을 검토 요청하세요:

1. **코드 품질**: 버그, 보안 취약점, 개선점이 있는가?
2. **설계 결정**: 현재 접근 방식의 장단점은 무엇인가?
3. **누락된 부분**: 고려하지 않은 edge case나 요구사항이 있는가?
4. **대안 제안**: 더 나은 구현 방법이 있는가?

## 파일 목록

| 파일 | 설명 | 업로드 |
|------|------|--------|
| UPLOAD_LIST.md | 이 가이드 | 필수 |
| packet.md | 메타데이터 | 필수 |
$(if [[ -f "$TO_GPT/user_prompt.txt" ]]; then
echo "| user_prompt.txt | 사용자 프롬프트 | 권장 |"
fi)
$(if [[ -f "$TO_GPT/last_assistant_message.md" ]]; then
echo "| last_assistant_message.md | Agent 응답 | 권장 |"
fi)
$(if [[ -f "$TO_GPT/git_diff.patch" ]]; then
echo "| git_diff.patch | 코드 변경 | 권장 |"
fi)
$(if [[ -f "$TO_GPT/claude_transcript.jsonl" ]]; then
echo "| claude_transcript.jsonl | 대화 기록 | 선택 |"
fi)

## GPT 응답 저장

GPT의 검토 결과는 다음 위치에 저장하세요:
- \`../from_gpt/gpt_review.md\`

다음 agent 프롬프트는:
- \`../to_claude/next_prompt.txt\`
EOF
fi

# IMPORTANT: Never output decision blocks (for Stop hook safety)
exit 0
