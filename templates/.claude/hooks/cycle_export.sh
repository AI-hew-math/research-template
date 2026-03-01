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
#   │   ├── UPLOAD_LIST.md           # [필수] 업로드 가이드
#   │   ├── packet.md                # [필수] 메타데이터 + 파일 크기
#   │   ├── user_prompt.txt          # [필수] 사용자 프롬프트
#   │   ├── last_assistant_message.md # [필수] Agent 최종 응답
#   │   ├── git_head.txt             # [조건] git repo일 때
#   │   ├── git_status.txt           # [조건] git repo일 때
#   │   ├── git_diff.patch           # [조건] git repo일 때
#   │   ├── claude_transcript.jsonl  # [조건] transcript_path 제공 시 (전체 보관용)
#   │   ├── transcript_tail.jsonl    # [권장] 업로드용 요약본 (에러 우선 추출)
#   │   └── run_logs.txt             # [조건] 실패한 run이 있을 때
#   ├── from_gpt/
#   └── to_claude/
#
# 환경변수:
#   RS_TRANSCRIPT_TAIL_LINES=400     # transcript_tail 기본 라인 수
#   RS_RUN_LOG_MAX_BYTES=51200       # run_logs.txt 최대 크기 (50KB)

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

        # --- Generate transcript_tail.jsonl (upload-friendly, valid JSONL) ---
        # Strategy: error-focused extraction + recent lines, output as valid JSON Lines
        TAIL_LINES="${RS_TRANSCRIPT_TAIL_LINES:-400}"

        # Extract via python - outputs valid JSONL format
        python3 - "$TRANSCRIPT_PATH" "$TO_GPT/transcript_tail.jsonl" "$TAIL_LINES" << 'PYEXTRACT' 2>/dev/null || true
import sys
import json

src_path = sys.argv[1]
dst_path = sys.argv[2]
max_lines = int(sys.argv[3])

# Error patterns to prioritize (case variations)
ERROR_PATTERNS = [
    'error', 'Error', 'ERROR',
    'fail', 'Fail', 'FAIL',
    'traceback', 'Traceback',
    'exception', 'Exception',
    'exit code', 'Exit Code',
    'CRITICAL', 'critical',
    'denied', 'Denied',
    'not found', 'Not found',
]

with open(src_path, 'r') as f:
    lines = f.readlines()

if not lines:
    # Empty file - write empty output
    open(dst_path, 'w').close()
    sys.exit(0)

# Score each line by error relevance
scored = []
for i, line in enumerate(lines):
    score = sum(1 for pat in ERROR_PATTERNS if pat in line)
    scored.append((i, score))

# Collect important indices: error lines + ±2 context
important_indices = set()
for i, score in scored:
    if score > 0:
        for j in range(max(0, i-2), min(len(lines), i+3)):
            important_indices.add(j)

# If not enough error-related lines, add tail lines as fallback
if len(important_indices) < max_lines // 2:
    tail_start = max(0, len(lines) - max_lines)
    for i in range(tail_start, len(lines)):
        important_indices.add(i)

# Sort and KEEP LAST max_lines (recent-first when truncating)
sorted_indices = sorted(important_indices)
if len(sorted_indices) > max_lines:
    # Truncate from FRONT (keep recent/tail)
    sorted_indices = sorted_indices[-max_lines:]

# Build score lookup for output
score_map = {i: s for i, s in scored}

# Write valid JSONL output
with open(dst_path, 'w') as f:
    prev_idx = -1
    for idx in sorted_indices:
        # Mark omitted lines as JSON object
        if prev_idx >= 0 and idx > prev_idx + 1:
            omit_count = idx - prev_idx - 1
            f.write(json.dumps({"type": "omitted", "count": omit_count}, ensure_ascii=False) + '\n')

        # Write line as JSON object (strip trailing newline from text)
        line_text = lines[idx].rstrip('\n\r')
        line_obj = {
            "type": "line",
            "idx": idx,
            "score": score_map.get(idx, 0),
            "text": line_text
        }
        f.write(json.dumps(line_obj, ensure_ascii=False) + '\n')
        prev_idx = idx
PYEXTRACT

        # Fallback if python extraction failed - wrap each line as JSON
        if [[ ! -s "$TO_GPT/transcript_tail.jsonl" ]]; then
            tail -n "$TAIL_LINES" "$TRANSCRIPT_PATH" 2>/dev/null | python3 -c '
import sys, json
for i, line in enumerate(sys.stdin):
    print(json.dumps({"type":"line","idx":i,"score":0,"text":line.rstrip("\n\r")}, ensure_ascii=False))
' > "$TO_GPT/transcript_tail.jsonl" 2>/dev/null || true
        fi
    fi

    # --- Collect run_logs.txt (failed runs only, space-safe) ---
    # Uses Python for: space-safe paths, mtime sorting, robust exit code parsing
    RUN_LOG_MAX="${RS_RUN_LOG_MAX_BYTES:-51200}"  # 50KB default
    RUNS_DIR="$CWD/runs"

    if [[ -d "$RUNS_DIR" ]]; then
        python3 - "$RUNS_DIR" "$TO_GPT/run_logs.txt" "$RUN_LOG_MAX" << 'PYRUNLOGS' 2>/dev/null || true
import sys
import os
import re
from pathlib import Path
from datetime import datetime

runs_dir = Path(sys.argv[1])
output_path = Path(sys.argv[2])
max_bytes = int(sys.argv[3])

# Exit code patterns (multiple formats supported)
EXIT_PATTERNS = [
    r'Exit Code[:\s|]+(\d+)',      # "Exit Code: 42" or "Exit Code | 42"
    r'exit[=:\s]+(\d+)',            # "exit=42" or "exit: 42"
    r'\*\*Exit Code\*\*\s*\|\s*(\d+)',  # Markdown table format
]

def parse_exit_code(run_card_path):
    """Parse exit code from run_card.md, returns 0 if not found or success."""
    try:
        content = run_card_path.read_text()
        for pattern in EXIT_PATTERNS:
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                return int(match.group(1))
    except:
        pass
    return 0  # Default to success if parsing fails

def get_mtime(path):
    """Get modification time, returns 0 on error."""
    try:
        return path.stat().st_mtime
    except:
        return 0

# Find all run_card.md files, sort by mtime descending, take top 10
run_cards = list(runs_dir.glob('*/run_card.md'))
run_cards.sort(key=get_mtime, reverse=True)
run_cards = run_cards[:10]  # Limit to recent 10

# Filter to failed runs only
failed_runs = []
for rc in run_cards:
    exit_code = parse_exit_code(rc)
    if exit_code != 0:
        failed_runs.append((rc.parent, exit_code))

if not failed_runs:
    sys.exit(0)  # No failed runs, don't create file

# Build output
output_lines = []
output_lines.append("# Failed Run Logs (auto-extracted)")
output_lines.append(f"# Generated: {datetime.now().isoformat()}")
output_lines.append(f"# Found {len(failed_runs)} failed run(s)")
output_lines.append("")

stderr_limit = max_bytes // 4
stdout_limit = max_bytes // 8

for run_dir, exit_code in failed_runs:
    run_id = run_dir.name
    output_lines.append(f"## Run: {run_id} (exit={exit_code})")
    output_lines.append("")

    # stderr first (usually more important)
    stderr_path = run_dir / "stderr.log"
    if stderr_path.exists():
        try:
            stderr_size = stderr_path.stat().st_size
            output_lines.append(f"### stderr.log ({stderr_size} bytes)")
            output_lines.append("```")
            content = stderr_path.read_bytes()
            if len(content) > stderr_limit:
                output_lines.append(f"... (truncated, showing last {stderr_limit // 1024}KB of {stderr_size} bytes) ...")
                content = content[-stderr_limit:]
            output_lines.append(content.decode('utf-8', errors='replace'))
            output_lines.append("```")
            output_lines.append("")
        except Exception as e:
            output_lines.append(f"(error reading stderr: {e})")
            output_lines.append("")

    # stdout tail
    stdout_path = run_dir / "stdout.log"
    if stdout_path.exists():
        try:
            stdout_size = stdout_path.stat().st_size
            output_lines.append(f"### stdout.log tail ({stdout_size} bytes total)")
            output_lines.append("```")
            content = stdout_path.read_bytes()
            if len(content) > stdout_limit:
                content = content[-stdout_limit:]
            output_lines.append(content.decode('utf-8', errors='replace'))
            output_lines.append("```")
            output_lines.append("")
        except Exception as e:
            output_lines.append(f"(error reading stdout: {e})")
            output_lines.append("")

# Join and check size
output = '\n'.join(output_lines)
if len(output.encode('utf-8')) > max_bytes:
    # Truncate at byte level
    output_bytes = output.encode('utf-8')[:max_bytes]
    output = output_bytes.decode('utf-8', errors='ignore')
    output += f"\n\n... (truncated at {max_bytes} bytes) ..."

output_path.write_text(output)
PYRUNLOGS
    fi
fi

# --- Helper: get file size in bytes ---
file_size_bytes() {
    if [[ -f "$1" ]]; then
        wc -c < "$1" | tr -d ' '
    else
        echo "0"
    fi
}

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
    # Stop/SessionEnd: full packet with file sizes
    # Calculate total packet size
    TOTAL_SIZE=0
    for f in "$TO_GPT"/*; do
        [[ -f "$f" ]] && TOTAL_SIZE=$((TOTAL_SIZE + $(file_size_bytes "$f")))
    done

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
| **Total Size** | ~${TOTAL_SIZE} bytes |

## Context

이 패킷은 agent 프롬프트 완료 시 자동 생성됩니다.
GPT에게 검토를 요청할 때 이 폴더의 파일들을 업로드하세요.

## Files in This Packet

| 파일 | 크기 | 우선순위 | 설명 |
|------|------|----------|------|
| UPLOAD_LIST.md | $(file_size_bytes "$TO_GPT/UPLOAD_LIST.md")B | 필수 | 업로드 가이드 |
| packet.md | ~1KB | 필수 | 이 메타데이터 |
$(if [[ -f "$TO_GPT/user_prompt.txt" ]]; then
echo "| user_prompt.txt | $(file_size_bytes "$TO_GPT/user_prompt.txt")B | 필수 | 사용자 프롬프트 |"
fi)
$(if [[ -f "$TO_GPT/last_assistant_message.md" ]]; then
echo "| last_assistant_message.md | $(file_size_bytes "$TO_GPT/last_assistant_message.md")B | 필수 | Agent 최종 응답 |"
fi)
$(if [[ -f "$TO_GPT/git_diff.patch" ]]; then
echo "| git_diff.patch | $(file_size_bytes "$TO_GPT/git_diff.patch")B | 권장 | 코드 변경사항 |"
fi)
$(if [[ -f "$TO_GPT/transcript_tail.jsonl" ]]; then
echo "| transcript_tail.jsonl | $(file_size_bytes "$TO_GPT/transcript_tail.jsonl")B | 권장 | 대화 요약 (에러 우선) |"
fi)
$(if [[ -f "$TO_GPT/run_logs.txt" ]]; then
echo "| run_logs.txt | $(file_size_bytes "$TO_GPT/run_logs.txt")B | 권장 | 실패 로그 |"
fi)
$(if [[ "$IS_GIT_REPO" == true ]]; then
echo "| git_status.txt | $(file_size_bytes "$TO_GPT/git_status.txt")B | 선택 | git status |"
echo "| git_head.txt | $(file_size_bytes "$TO_GPT/git_head.txt")B | 선택 | 커밋 SHA |"
fi)
$(if [[ -f "$TO_GPT/claude_transcript.jsonl" ]]; then
echo "| claude_transcript.jsonl | $(file_size_bytes "$TO_GPT/claude_transcript.jsonl")B | 보관용 | 전체 대화 (큰 파일) |"
fi)

## 업로드 우선순위 설명

- **필수**: GPT 검토에 반드시 필요
- **권장**: 코드 품질/에러 분석에 도움
- **선택**: 상세 분석 시 참조
- **보관용**: 로컬 보관 전용 (업로드 비권장)
EOF

    cat > "$TO_GPT/UPLOAD_LIST.md" << EOF
# GPT Upload Guide: $CYCLE_ID

## 빠른 업로드 (권장)

다음 순서로 업로드:

1. **packet.md** (메타데이터)
2. **user_prompt.txt** (프롬프트)
3. **last_assistant_message.md** (Agent 응답)
$(if [[ -f "$TO_GPT/git_diff.patch" ]]; then
echo "4. **git_diff.patch** (코드 변경)"
fi)
$(if [[ -f "$TO_GPT/transcript_tail.jsonl" ]]; then
echo "5. **transcript_tail.jsonl** (대화 요약, 에러 우선)"
fi)
$(if [[ -f "$TO_GPT/run_logs.txt" ]]; then
echo "6. **run_logs.txt** (실패 로그)"
fi)

## 파일 상세

| 파일 | 크기 | 우선순위 | 용도 |
|------|------|----------|------|
| packet.md | ~1KB | 필수 | 메타데이터 |
$(if [[ -f "$TO_GPT/user_prompt.txt" ]]; then
echo "| user_prompt.txt | $(file_size_bytes "$TO_GPT/user_prompt.txt")B | 필수 | 사용자 프롬프트 |"
fi)
$(if [[ -f "$TO_GPT/last_assistant_message.md" ]]; then
echo "| last_assistant_message.md | $(file_size_bytes "$TO_GPT/last_assistant_message.md")B | 필수 | Agent 응답 |"
fi)
$(if [[ -f "$TO_GPT/git_diff.patch" ]]; then
echo "| git_diff.patch | $(file_size_bytes "$TO_GPT/git_diff.patch")B | 권장 | 코드 diff |"
fi)
$(if [[ -f "$TO_GPT/transcript_tail.jsonl" ]]; then
echo "| transcript_tail.jsonl | $(file_size_bytes "$TO_GPT/transcript_tail.jsonl")B | 권장 | 대화 요약 |"
fi)
$(if [[ -f "$TO_GPT/run_logs.txt" ]]; then
echo "| run_logs.txt | $(file_size_bytes "$TO_GPT/run_logs.txt")B | 권장 | 실패 로그 |"
fi)
$(if [[ -f "$TO_GPT/claude_transcript.jsonl" ]]; then
echo "| claude_transcript.jsonl | $(file_size_bytes "$TO_GPT/claude_transcript.jsonl")B | 보관용 | 전체 기록 (큼) |"
fi)

## 검토 요청 질문

1. **코드 품질**: 버그, 보안 취약점, 개선점이 있는가?
2. **설계 결정**: 현재 접근 방식의 장단점은 무엇인가?
3. **누락된 부분**: 고려하지 않은 edge case나 요구사항이 있는가?
4. **에러 분석**: transcript_tail/run_logs에 문제가 보이는가?

## GPT 응답 저장

\`../from_gpt/gpt_review.md\`에 저장

## 다음 프롬프트

\`../to_claude/next_prompt.txt\`에 저장
EOF
fi

# IMPORTANT: Never output decision blocks (for Stop hook safety)
exit 0
