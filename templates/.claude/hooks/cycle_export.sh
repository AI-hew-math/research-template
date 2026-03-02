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
#   │   ├── last_assistant_message.md # [필수] Agent 최종 응답 (transcript fallback)
#   │   ├── run_summary.md           # [필수] 최신 Run 요약 (5항목)
#   │   ├── run_events.jsonl         # [권장] Run 이벤트 매니페스트
#   │   ├── git_head.txt             # [조건] git repo일 때
#   │   ├── git_status.txt           # [조건] git repo일 때
#   │   ├── git_diff.patch           # [조건] git repo일 때
#   │   ├── claude_transcript.jsonl  # [조건] transcript_path 제공 시 (전체 보관용)
#   │   ├── transcript_tail.jsonl    # [권장] 업로드용 요약본 (에러 우선 추출)
#   │   ├── run_logs.txt             # [조건] 실패한 run이 있을 때
#   │   └── hook_input_stop.json     # [디버그] RS_HOOK_DEBUG=1 시
#   ├── from_gpt/
#   └── to_claude/
#
# 환경변수:
#   RS_TRANSCRIPT_TAIL_LINES=400     # transcript_tail 기본 라인 수
#   RS_RUN_LOG_MAX_BYTES=51200       # run_logs.txt 최대 크기 (50KB)
#   RS_HOOK_DEBUG=1                  # Stop hook 입력 JSON 저장

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

    # Support multiple key variations for assistant message
    assistant_msg = (
        data.get('last_assistant_message') or
        data.get('lastAssistantMessage') or
        data.get('assistant_message') or
        data.get('assistantMessage') or
        ''
    )
    # Handle dict/list values (flatten to text)
    if isinstance(assistant_msg, dict):
        assistant_msg = assistant_msg.get('text') or assistant_msg.get('content') or str(assistant_msg)
    elif isinstance(assistant_msg, list):
        parts = []
        for item in assistant_msg:
            if isinstance(item, dict) and item.get('type') == 'text':
                parts.append(item.get('text', ''))
            elif isinstance(item, str):
                parts.append(item)
        assistant_msg = '\n'.join(parts)
    # Only save if non-empty string
    if assistant_msg and isinstance(assistant_msg, str) and assistant_msg.strip():
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

# --- State directory and cycle files ---
STATE_DIR="$CWD/.claude/state"
# Canonical names
CYCLE_ID_FILE="$STATE_DIR/current_cycle_id"
CYCLE_START_TS_FILE="$STATE_DIR/current_cycle_start_ts"
CYCLE_ACTIVITY_FILE="$STATE_DIR/current_cycle_last_activity_ts"
# Backwards compatibility
CYCLE_FILE_COMPAT="$STATE_DIR/current_cycle.txt"
mkdir -p "$STATE_DIR"

# --- Handle cycle number based on event type ---
case "$HOOK_EVENT" in
    "UserPromptSubmit")
        # Increment cycle on each new prompt
        # Read from canonical file first, fallback to compat
        if [[ -f "$CYCLE_ID_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "0")
        elif [[ -f "$CYCLE_FILE_COMPAT" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE_COMPAT" 2>/dev/null || echo "0")
        else
            CURRENT_CYCLE=0
        fi
        CURRENT_CYCLE=$((CURRENT_CYCLE + 1))

        # Write to canonical files
        echo "$CURRENT_CYCLE" > "$CYCLE_ID_FILE"
        CURRENT_TS=$(date +%s)
        echo "$CURRENT_TS" > "$CYCLE_START_TS_FILE"
        echo "$CURRENT_TS" > "$CYCLE_ACTIVITY_FILE"

        # Write to backwards-compat file for older run.sh versions
        echo "$CURRENT_CYCLE" > "$CYCLE_FILE_COMPAT"
        ;;
    "SessionStart")
        # Initialize only if no cycle file exists (don't increment)
        if [[ ! -f "$CYCLE_ID_FILE" && ! -f "$CYCLE_FILE_COMPAT" ]]; then
            echo "0" > "$CYCLE_ID_FILE"
            echo "0" > "$CYCLE_FILE_COMPAT"
        fi
        # Read from canonical first, fallback to compat
        if [[ -f "$CYCLE_ID_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "0")
        else
            CURRENT_CYCLE=$(cat "$CYCLE_FILE_COMPAT" 2>/dev/null || echo "0")
        fi
        # If cycle is 0, this is first session - wait for first prompt
        if [[ "$CURRENT_CYCLE" == "0" ]]; then
            exit 0  # Don't create cycle_0000
        fi
        ;;
    "Stop"|"SessionEnd")
        # Read existing cycle (don't increment) - canonical first, then compat
        if [[ -f "$CYCLE_ID_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "0")
        elif [[ -f "$CYCLE_FILE_COMPAT" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE_COMPAT" 2>/dev/null || echo "0")
        else
            CURRENT_CYCLE=0
        fi
        # If no cycle yet, nothing to export
        if [[ "$CURRENT_CYCLE" == "0" ]]; then
            exit 0
        fi
        ;;
    *)
        # Unknown event - try to read existing cycle (canonical first)
        if [[ -f "$CYCLE_ID_FILE" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "1")
        elif [[ -f "$CYCLE_FILE_COMPAT" ]]; then
            CURRENT_CYCLE=$(cat "$CYCLE_FILE_COMPAT" 2>/dev/null || echo "1")
        else
            CURRENT_CYCLE=1
            echo "$CURRENT_CYCLE" > "$CYCLE_ID_FILE"
            echo "$CURRENT_CYCLE" > "$CYCLE_FILE_COMPAT"
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

# --- Debug option: save hook input JSON ---
if [[ "${RS_HOOK_DEBUG:-}" == "1" && "$HOOK_EVENT" == "Stop" ]]; then
    cp "$TMPFILE" "$TO_GPT/hook_input_stop.json" 2>/dev/null || true
fi

# --- Save last_assistant_message.md on Stop (multiline-safe) ---
LAST_ASSISTANT_MISSING=""
if [[ "$HOOK_EVENT" == "Stop" ]]; then
    if [[ -s "$ASSISTANT_FILE" ]]; then
        cp "$ASSISTANT_FILE" "$TO_GPT/last_assistant_message.md"
    else
        # Fallback: extract from transcript if available
        if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
            python3 - "$TRANSCRIPT_PATH" "$TO_GPT/last_assistant_message.md" << 'PYEXTRACT_ASSISTANT' 2>/dev/null || true
import sys
import json

transcript_path = sys.argv[1]
output_path = sys.argv[2]

def extract_text_from_content(content):
    """Recursively extract text from content (str, list, or dict)."""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                # Prefer type=="text" blocks, skip thinking/tool_use
                if item.get('type') == 'text':
                    parts.append(item.get('text', ''))
                elif item.get('type') not in ('thinking', 'tool_use', 'tool_result'):
                    # Fallback for other dict types
                    text = item.get('text') or item.get('content') or ''
                    if text:
                        parts.append(extract_text_from_content(text))
            elif isinstance(item, str):
                parts.append(item)
        return '\n'.join(p for p in parts if p)
    if isinstance(content, dict):
        return content.get('text') or content.get('content') or ''
    return ''

# Read transcript and find last assistant message
last_assistant = None
try:
    with open(transcript_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)

                # Pattern 1: Claude Code transcript format
                # {type: "assistant", message: {role: "assistant", content: [...]}}
                if obj.get('type') == 'assistant':
                    msg = obj.get('message', {})
                    if msg.get('role') == 'assistant':
                        content = msg.get('content')
                        text = extract_text_from_content(content)
                        if text:
                            last_assistant = text
                    continue

                # Pattern 2: Direct role field (legacy/other formats)
                role = obj.get('role', '')
                if role in ('assistant', 'model'):
                    content = obj.get('content') or obj.get('text') or ''
                    text = extract_text_from_content(content)
                    if text:
                        last_assistant = text
                    continue

                # Pattern 3: type == 'response' or similar
                if obj.get('type') in ('response', 'model'):
                    content = obj.get('content') or obj.get('message') or obj.get('text') or ''
                    text = extract_text_from_content(content)
                    if text:
                        last_assistant = text

            except json.JSONDecodeError:
                continue
except Exception:
    pass

if last_assistant:
    with open(output_path, 'w') as f:
        f.write(last_assistant)
PYEXTRACT_ASSISTANT

            # Check if extraction succeeded
            if [[ ! -s "$TO_GPT/last_assistant_message.md" ]]; then
                LAST_ASSISTANT_MISSING="transcript parse failed"
            fi
        else
            LAST_ASSISTANT_MISSING="Stop payload missing last_assistant_message"
        fi
    fi

    # Final check: if file exists but is 0-byte, mark as missing and delete
    if [[ -f "$TO_GPT/last_assistant_message.md" && ! -s "$TO_GPT/last_assistant_message.md" ]]; then
        rm -f "$TO_GPT/last_assistant_message.md"
        LAST_ASSISTANT_MISSING="extracted content was empty"
    fi
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
        # Only create git_diff.patch if there are actual changes
        if [[ -n "$GIT_DIFF" ]]; then
            printf '%s\n' "$GIT_DIFF" > "$TO_GPT/git_diff.patch"
        fi
        # Note: if no changes, git_diff.patch is not created (packet.md will omit it)
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

    # --- Generate run_summary.md AND run_logs.txt from run_events.jsonl ---
    # run_events.jsonl contains all runs executed during this cycle
    # run_summary.md: always generated (lists all runs with stdout tail)
    # run_logs.txt: only generated if ANY run FAILED
    RUN_SUMMARY_MISSING=""
    RUN_EVENTS_FILE="$TO_GPT/run_events.jsonl"
    RS_RUNS_MAX="${RS_RUNS_MAX:-10}"
    RS_RUN_LOGS_MAX_BYTES="${RS_RUN_LOGS_MAX_BYTES:-51200}"

    if [[ -f "$RUN_EVENTS_FILE" && -s "$RUN_EVENTS_FILE" ]]; then
        python3 - "$RUN_EVENTS_FILE" "$TO_GPT/run_summary.md" "$TO_GPT/run_logs.txt" "$RS_RUNS_MAX" "$RS_RUN_LOGS_MAX_BYTES" << 'PYRUNEVENTS' 2>/dev/null || true
import sys
import json
from pathlib import Path
from datetime import datetime

events_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
runlogs_path = Path(sys.argv[3])
max_runs = int(sys.argv[4])
max_log_bytes = int(sys.argv[5])

def read_tail(path, n_lines):
    """Read last n lines from file."""
    try:
        p = Path(path)
        if p.exists():
            content = p.read_text()
            lines = content.splitlines()[-n_lines:]
            return lines
    except:
        pass
    return None

# Load all run events
runs = []
try:
    with open(events_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    runs.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
except:
    pass

if not runs:
    sys.exit(0)  # No runs in this cycle

# Limit to most recent RS_RUNS_MAX runs (by ts)
runs.sort(key=lambda r: r.get('ts', 0), reverse=True)
runs = runs[:max_runs]
runs.reverse()  # Chronological order for display

# Separate failed runs
failed_runs = [r for r in runs if r.get('exit_code', 0) != 0]

# ========== Generate run_summary.md ==========
lines = []
lines.append("# Run Summary (auto-generated)")
lines.append(f"Generated: {datetime.now().isoformat()}")
lines.append(f"Total runs this cycle: {len(runs)}")
if failed_runs:
    lines.append(f"**Failed runs: {len(failed_runs)}**")
lines.append("")

# Run table
lines.append("## Runs")
lines.append("")
lines.append("| # | Run ID | Exp | Exit | Duration | Status |")
lines.append("|---|--------|-----|------|----------|--------|")

for i, r in enumerate(runs, 1):
    run_id = r.get('run_id', 'unknown')
    exp = r.get('exp', '')
    exit_code = r.get('exit_code', '?')
    duration = r.get('duration', '?')
    status = "SUCCESS" if exit_code == 0 else f"**FAILED**"
    # Truncate long run_id for table
    run_id_short = run_id[:40] + "..." if len(run_id) > 43 else run_id
    lines.append(f"| {i} | `{run_id_short}` | {exp} | {exit_code} | {duration}s | {status} |")

lines.append("")

# Per-run details (stdout tail 20 for each)
for i, r in enumerate(runs, 1):
    run_id = r.get('run_id', 'unknown')
    exp = r.get('exp', '')
    exit_code = r.get('exit_code', 0)
    run_dir = r.get('run_dir', '')
    status = "SUCCESS" if exit_code == 0 else "FAILED"

    lines.append(f"## Run {i}: {exp} ({status})")
    lines.append(f"- **Run ID**: `{run_id}`")
    lines.append(f"- **Exit Code**: {exit_code}")
    lines.append(f"- **Run Dir**: `{run_dir}`")
    lines.append("")

    # stdout tail 20
    stdout_path = r.get('stdout_path', '')
    lines.append("### stdout (last 20 lines)")
    stdout_lines = read_tail(stdout_path, 20)
    if stdout_lines is not None:
        lines.append("```")
        lines.extend(stdout_lines)
        lines.append("```")
    else:
        lines.append("(no stdout.log)")
    lines.append("")

    # stderr tail 50 for FAILED runs only
    if exit_code != 0:
        stderr_path = r.get('stderr_path', '')
        lines.append("### stderr (last 50 lines)")
        stderr_lines = read_tail(stderr_path, 50)
        if stderr_lines is not None and stderr_lines:
            lines.append("```")
            lines.extend(stderr_lines)
            lines.append("```")
        else:
            lines.append("(empty or no stderr.log)")
        lines.append("")

summary_path.write_text('\n'.join(lines))

# ========== Generate run_logs.txt (only if ANY failed) ==========
if failed_runs:
    log_lines = []
    log_lines.append("# Failed Run Logs (auto-extracted)")
    log_lines.append(f"Generated: {datetime.now().isoformat()}")
    log_lines.append(f"Failed runs: {len(failed_runs)} of {len(runs)}")
    log_lines.append("")

    for r in failed_runs:
        run_id = r.get('run_id', 'unknown')
        exp = r.get('exp', '')
        exit_code = r.get('exit_code', 0)
        run_dir = r.get('run_dir', '')

        log_lines.append(f"## {exp}: {run_id}")
        log_lines.append(f"- Exit Code: **{exit_code}**")
        log_lines.append(f"- Run Dir: `{run_dir}`")
        log_lines.append("")

        # stdout tail 20
        stdout_path = r.get('stdout_path', '')
        log_lines.append("### stdout (last 20 lines)")
        stdout_lines = read_tail(stdout_path, 20)
        if stdout_lines is not None:
            log_lines.append("```")
            log_lines.extend(stdout_lines)
            log_lines.append("```")
        else:
            log_lines.append("(no stdout.log)")
        log_lines.append("")

        # stderr tail 50
        stderr_path = r.get('stderr_path', '')
        log_lines.append("### stderr (last 50 lines)")
        stderr_lines = read_tail(stderr_path, 50)
        if stderr_lines is not None and stderr_lines:
            log_lines.append("```")
            log_lines.extend(stderr_lines)
            log_lines.append("```")
        else:
            log_lines.append("(empty or no stderr.log)")
        log_lines.append("")

    # Check size limit
    output = '\n'.join(log_lines)
    if len(output.encode('utf-8')) > max_log_bytes:
        output_bytes = output.encode('utf-8')[:max_log_bytes]
        output = output_bytes.decode('utf-8', errors='ignore')
        output += f"\n\n... (truncated at {max_log_bytes} bytes) ..."

    runlogs_path.write_text(output)
# Note: if no failed runs, run_logs.txt is NOT created
PYRUNEVENTS

        if [[ ! -s "$TO_GPT/run_summary.md" ]]; then
            RUN_SUMMARY_MISSING="no run events in this cycle"
        fi
    else
        # --- Fallback: scan runs/*/run_card.md when no run_events.jsonl ---
        # This provides minimal safety net when hooks were not approved
        # Uses cycle start timestamp to filter runs from this cycle
        CYCLE_START_TS_FILE="$STATE_DIR/current_cycle_start_ts"
        if [[ -f "$CYCLE_START_TS_FILE" ]]; then
            CYCLE_START_TS=$(cat "$CYCLE_START_TS_FILE" 2>/dev/null || echo "0")
        else
            CYCLE_START_TS=0
        fi

        python3 - "$CWD/runs" "$TO_GPT/run_summary.md" "$CYCLE_START_TS" "$RS_RUNS_MAX" << 'PYFALLBACK' 2>/dev/null || true
import sys
import os
import re
from pathlib import Path
from datetime import datetime

runs_dir = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
cycle_start_ts = int(sys.argv[3])
max_runs = int(sys.argv[4])

if not runs_dir.exists():
    sys.exit(0)

# Multiple patterns for exit code extraction (fallback robustness)
EXIT_PATTERNS = [
    r'\*\*Exit Code\*\*\s*\|\s*(\d+)',           # Markdown table: **Exit Code** | 42
    r'Exit Code[:\s]+(\d+)',                       # Plain text: Exit Code: 42
    r'exit[_\s]code[:\s=]+(\d+)',                  # Various: exit_code=42, exit code: 42
    r'exited with (\d+)',                          # Prose: exited with 42
    r'return code[:\s]+(\d+)',                     # Alternative: return code: 42
]

# Find run directories with run_card.md
run_dirs = []
for run_card in runs_dir.glob("*/run_card.md"):
    run_dir = run_card.parent
    mtime = run_card.stat().st_mtime
    # Filter: only runs created after cycle start (with 5 min tolerance)
    if cycle_start_ts > 0 and mtime < (cycle_start_ts - 300):
        continue
    run_dirs.append((mtime, run_dir, run_card))

if not run_dirs:
    sys.exit(0)

# Sort by mtime, most recent first, limit
run_dirs.sort(key=lambda x: x[0], reverse=True)
run_dirs = run_dirs[:max_runs]
run_dirs.reverse()  # Chronological

def read_tail(path, n_lines):
    try:
        if path.exists():
            return path.read_text().splitlines()[-n_lines:]
    except:
        pass
    return None

def parse_exit_code(run_card_path):
    """Parse exit code using multiple patterns for robustness."""
    try:
        content = run_card_path.read_text()
        for pattern in EXIT_PATTERNS:
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                return int(match.group(1))
    except:
        pass
    return None

# Generate summary with FALLBACK MODE banner
lines = []
lines.append("# Run Summary")
lines.append("")
lines.append("> **⚠️ FALLBACK MODE**: run_events.jsonl not found.")
lines.append("> This summary was generated by scanning run_card.md files.")
lines.append("> For accurate tracking, approve hooks to enable run_events.jsonl.")
lines.append("")
lines.append(f"Generated: {datetime.now().isoformat()}")
lines.append(f"Total runs detected: {len(run_dirs)}")
lines.append("")

lines.append("## Runs")
lines.append("")
lines.append("| # | Run ID | Exit | Status |")
lines.append("|---|--------|------|--------|")

failed_count = 0
for i, (mtime, run_dir, run_card) in enumerate(run_dirs, 1):
    run_id = run_dir.name
    exit_code = parse_exit_code(run_card)
    if exit_code is None:
        status = "UNKNOWN"
    elif exit_code == 0:
        status = "SUCCESS"
    else:
        status = "**FAILED**"
        failed_count += 1
    exit_str = str(exit_code) if exit_code is not None else "?"
    run_id_short = run_id[:40] + "..." if len(run_id) > 43 else run_id
    lines.append(f"| {i} | `{run_id_short}` | {exit_str} | {status} |")

if failed_count > 0:
    lines.insert(8, f"**Failed runs: {failed_count}**")

lines.append("")

# Per-run details with both stdout AND stderr
for i, (mtime, run_dir, run_card) in enumerate(run_dirs, 1):
    run_id = run_dir.name
    exit_code = parse_exit_code(run_card)
    status = "SUCCESS" if exit_code == 0 else ("FAILED" if exit_code else "UNKNOWN")

    lines.append(f"## Run {i}: {run_id[:30]} ({status})")
    lines.append(f"- **Run Dir**: `{run_dir}`")
    if exit_code is not None:
        lines.append(f"- **Exit Code**: {exit_code}")
    lines.append("")

    # stdout tail (20 lines)
    stdout_lines = read_tail(run_dir / "stdout.log", 20)
    lines.append("### stdout (last 20 lines)")
    if stdout_lines:
        lines.append("```")
        lines.extend(stdout_lines)
        lines.append("```")
    else:
        lines.append("(no stdout.log)")
    lines.append("")

    # stderr tail (50 lines) - especially useful for failed runs
    stderr_lines = read_tail(run_dir / "stderr.log", 50)
    lines.append("### stderr (last 50 lines)")
    if stderr_lines and any(l.strip() for l in stderr_lines):
        lines.append("```")
        lines.extend(stderr_lines)
        lines.append("```")
    else:
        lines.append("(empty or no stderr.log)")
    lines.append("")

summary_path.write_text('\n'.join(lines))
PYFALLBACK

        if [[ -s "$TO_GPT/run_summary.md" ]]; then
            RUN_SUMMARY_MISSING=""  # Fallback succeeded
        else
            RUN_SUMMARY_MISSING="no runs executed this cycle"
        fi
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

    # Build MISSING warnings section
    MISSING_SECTION=""
    if [[ -n "$LAST_ASSISTANT_MISSING" ]]; then
        MISSING_SECTION="${MISSING_SECTION}
> **MISSING: last_assistant_message.md** - ${LAST_ASSISTANT_MISSING}"
    fi
    if [[ -n "$RUN_SUMMARY_MISSING" ]]; then
        MISSING_SECTION="${MISSING_SECTION}
> **MISSING: run_summary.md** - ${RUN_SUMMARY_MISSING}"
    fi

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
${MISSING_SECTION}

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
elif [[ -n "$LAST_ASSISTANT_MISSING" ]]; then
echo "| ~~last_assistant_message.md~~ | MISSING | 필수 | ${LAST_ASSISTANT_MISSING} |"
fi)
$(if [[ -f "$TO_GPT/run_summary.md" ]]; then
echo "| run_summary.md | $(file_size_bytes "$TO_GPT/run_summary.md")B | 필수 | 최신 Run 요약 |"
elif [[ -n "$RUN_SUMMARY_MISSING" ]]; then
echo "| ~~run_summary.md~~ | MISSING | 필수 | ${RUN_SUMMARY_MISSING} |"
fi)
$(if [[ -f "$TO_GPT/run_events.jsonl" ]]; then
echo "| run_events.jsonl | $(file_size_bytes "$TO_GPT/run_events.jsonl")B | 권장 | Run 이벤트 매니페스트 |"
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

- **필수**: GPT 검토에 반드시 필요 (MISSING 표시 시 주의)
- **권장**: 코드 품질/에러 분석에 도움
- **선택**: 상세 분석 시 참조
- **보관용**: 로컬 보관 전용 (업로드 비권장)
EOF

    cat > "$TO_GPT/UPLOAD_LIST.md" << EOF
# GPT Upload Guide: $CYCLE_ID
${MISSING_SECTION}

## 빠른 업로드 (권장)

다음 순서로 업로드:

1. **packet.md** (메타데이터)
$(if [[ -f "$TO_GPT/user_prompt.txt" ]]; then
echo "2. **user_prompt.txt** (프롬프트)"
fi)
$(if [[ -f "$TO_GPT/last_assistant_message.md" ]]; then
echo "3. **last_assistant_message.md** (Agent 응답)"
elif [[ -n "$LAST_ASSISTANT_MISSING" ]]; then
echo "3. ~~last_assistant_message.md~~ (MISSING: ${LAST_ASSISTANT_MISSING})"
fi)
$(if [[ -f "$TO_GPT/run_summary.md" ]]; then
echo "4. **run_summary.md** (최신 Run 요약)"
elif [[ -n "$RUN_SUMMARY_MISSING" ]]; then
echo "4. ~~run_summary.md~~ (MISSING: ${RUN_SUMMARY_MISSING})"
fi)
$(if [[ -f "$TO_GPT/git_diff.patch" ]]; then
echo "5. **git_diff.patch** (코드 변경)"
fi)
$(if [[ -f "$TO_GPT/transcript_tail.jsonl" ]]; then
echo "6. **transcript_tail.jsonl** (대화 요약, 에러 우선)"
fi)
$(if [[ -f "$TO_GPT/run_logs.txt" ]]; then
echo "7. **run_logs.txt** (실패 로그)"
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
elif [[ -n "$LAST_ASSISTANT_MISSING" ]]; then
echo "| ~~last_assistant_message.md~~ | MISSING | 필수 | ${LAST_ASSISTANT_MISSING} |"
fi)
$(if [[ -f "$TO_GPT/run_summary.md" ]]; then
echo "| run_summary.md | $(file_size_bytes "$TO_GPT/run_summary.md")B | 필수 | 최신 Run 요약 |"
elif [[ -n "$RUN_SUMMARY_MISSING" ]]; then
echo "| ~~run_summary.md~~ | MISSING | 필수 | ${RUN_SUMMARY_MISSING} |"
fi)
$(if [[ -f "$TO_GPT/run_events.jsonl" ]]; then
echo "| run_events.jsonl | $(file_size_bytes "$TO_GPT/run_events.jsonl")B | 권장 | Run 매니페스트 |"
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
4. **에러 분석**: run_summary/transcript_tail/run_logs에 문제가 보이는가?

## GPT 응답 저장

\`../from_gpt/gpt_review.md\`에 저장

## 다음 프롬프트

\`../to_claude/next_prompt.txt\`에 저장
EOF
fi

# IMPORTANT: Never output decision blocks (for Stop hook safety)
exit 0
