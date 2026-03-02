#!/bin/bash
# run.sh - 실험 실행 래퍼 (Run Card 자동 생성)
# Usage: ./scripts/run.sh --exp <EXP_NAME> <command...>
#
# 예시:
#   ./scripts/run.sh --exp baseline python train.py --lr 0.001
#   ./scripts/run.sh --exp ablation_v2 bash train.sh
#
# 생성물:
#   runs/<RUN_ID>/
#   ├── run_card.md    # FACT-only 실행 기록
#   ├── stdout.log
#   ├── stderr.log
#   ├── meta.txt
#   ├── env.txt        (가능하면)
#   ├── git_diff.patch (git repo일 때)
#   └── nvidia-smi.txt (GPU 있을 때)

set -o pipefail

# --- Parse arguments ---
EXP_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --exp)
            EXP_NAME="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

if [[ -z "$EXP_NAME" ]]; then
    echo "Error: --exp <name> is required" >&2
    echo "Usage: ./scripts/run.sh --exp <EXP_NAME> <command...>" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Error: No command specified" >&2
    echo "Usage: ./scripts/run.sh --exp <EXP_NAME> <command...>" >&2
    exit 1
fi

# 명령을 배열로 저장 (안전한 실행을 위해)
CMD=("$@")

# 기록용 명령 문자열 (재현 가능한 형태)
COMMAND_STR=""
for arg in "${CMD[@]}"; do
    COMMAND_STR+="$(printf '%q ' "$arg")"
done
COMMAND_STR="${COMMAND_STR% }"  # 마지막 공백 제거

# --- Build RUN_ID ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME_SHORT=$(hostname | cut -d. -f1)

# Git SHA (nogit if not a repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
else
    GIT_SHA="nogit"
fi

# SLURM suffix
SLURM_SUFFIX=""
if [[ -n "$SLURM_JOB_ID" ]]; then
    SLURM_SUFFIX="_job${SLURM_JOB_ID}"
    if [[ -n "$SLURM_ARRAY_TASK_ID" ]]; then
        SLURM_SUFFIX="${SLURM_SUFFIX}_${SLURM_ARRAY_TASK_ID}"
    fi
fi

RUN_ID="${TIMESTAMP}_${EXP_NAME}_${HOSTNAME_SHORT}_${GIT_SHA}${SLURM_SUFFIX}"

# --- Create run directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUN_DIR="$PROJECT_DIR/runs/$RUN_ID"

mkdir -p "$RUN_DIR"

# --- Collect metadata ---
CWD=$(pwd)

# meta.txt
{
    echo "RUN_ID: $RUN_ID"
    echo "TIMESTAMP: $(date -Iseconds)"
    echo "HOSTNAME: $(hostname)"
    echo "USER: $USER"
    echo "CWD: $CWD"
    echo "COMMAND: $COMMAND_STR"
    echo "EXP_NAME: $EXP_NAME"
    echo "GIT_SHA: $GIT_SHA"
    if [[ -n "$SLURM_JOB_ID" ]]; then
        echo "SLURM_JOB_ID: $SLURM_JOB_ID"
        echo "SLURM_JOB_NAME: ${SLURM_JOB_NAME:-}"
        echo "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID:-}"
        echo "SLURM_NODELIST: ${SLURM_NODELIST:-}"
        echo "SLURM_GPUS: ${SLURM_GPUS:-}"
    fi
} > "$RUN_DIR/meta.txt"

# env.txt (선택적)
env > "$RUN_DIR/env.txt" 2>/dev/null || true

# git_diff.patch (git repo일 때만)
if [[ "$GIT_SHA" != "nogit" ]]; then
    git diff HEAD > "$RUN_DIR/git_diff.patch" 2>/dev/null || true
fi

# nvidia-smi.txt (GPU 있을 때)
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi > "$RUN_DIR/nvidia-smi.txt" 2>/dev/null || true
fi

# --- SNAPSHOT cycle assignment BEFORE run starts ---
# This ensures long-running experiments stay in the cycle they started in
# Features:
#   - Cycle assignment is determined at RUN START (not end)
#   - Touch last_activity_ts at both start and end
#   - Session ID tracking for multi-session separation
#   - Optional sensitive info redaction (RS_REDACT=1)
STATE_DIR="$PROJECT_DIR/.claude/state"
CYCLE_ID_FILE="$STATE_DIR/current_cycle_id"
CYCLE_ID_FILE_COMPAT="$STATE_DIR/current_cycle.txt"  # Backwards compat
CYCLE_ACTIVITY_FILE="$STATE_DIR/current_cycle_last_activity_ts"
SESSION_ID_FILE="$STATE_DIR/current_session_id"
RS_CYCLE_STALE_MINUTES="${RS_CYCLE_STALE_MINUTES:-60}"

# Snapshot cycle info at run START
SNAPSHOT_CYCLE_NUM=""
SNAPSHOT_RUN_EVENTS_FILE=""
SNAPSHOT_IS_STALE="false"
SNAPSHOT_SESSION_ID=""

# Read cycle ID with backwards compatibility
if [[ -f "$CYCLE_ID_FILE" ]]; then
    SNAPSHOT_CYCLE_NUM=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "")
elif [[ -f "$CYCLE_ID_FILE_COMPAT" ]]; then
    SNAPSHOT_CYCLE_NUM=$(cat "$CYCLE_ID_FILE_COMPAT" 2>/dev/null || echo "")
fi

# Read session ID (for multi-session tracking)
if [[ -f "$SESSION_ID_FILE" ]]; then
    SNAPSHOT_SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "")
fi

if [[ -n "$SNAPSHOT_CYCLE_NUM" && "$SNAPSHOT_CYCLE_NUM" =~ ^[0-9]+$ ]]; then
    # Check stale at START (not end) - based on last_activity_ts
    if [[ -f "$CYCLE_ACTIVITY_FILE" ]]; then
        LAST_ACTIVITY_TS=$(cat "$CYCLE_ACTIVITY_FILE" 2>/dev/null || echo "0")
        CURRENT_TS=$(date +%s)
        STALE_SECONDS=$((RS_CYCLE_STALE_MINUTES * 60))
        if [[ $((CURRENT_TS - LAST_ACTIVITY_TS)) -gt $STALE_SECONDS ]]; then
            SNAPSHOT_IS_STALE="true"
        fi
    fi

    if [[ "$SNAPSHOT_IS_STALE" == "true" ]]; then
        # Stale cycle: will write to unattributed_run_events.jsonl
        SNAPSHOT_RUN_EVENTS_FILE="$PROJECT_DIR/review_cycles/unattributed_run_events.jsonl"
    else
        # Active cycle: will write to cycle-specific run_events.jsonl
        CYCLE_DIR=$(printf "cycle_%04d" "$SNAPSHOT_CYCLE_NUM")
        SNAPSHOT_RUN_EVENTS_FILE="$PROJECT_DIR/review_cycles/$CYCLE_DIR/to_gpt/run_events.jsonl"
    fi

    # Touch last_activity_ts at RUN START (keeps cycle alive during long runs)
    mkdir -p "$STATE_DIR"
    echo "$(date +%s)" > "$CYCLE_ACTIVITY_FILE"
fi

# --- Run the command (배열로 안전하게 실행) ---
START_TIME=$(date +%s)

# 실행 (stdout/stderr 분리, eval 없이 배열 실행)
"${CMD[@]}" > "$RUN_DIR/stdout.log" 2> "$RUN_DIR/stderr.log"
EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# --- Generate Run Card ---
SLURM_INFO="N/A"
if [[ -n "$SLURM_JOB_ID" ]]; then
    SLURM_INFO="$SLURM_JOB_ID"
    [[ -n "$SLURM_ARRAY_TASK_ID" ]] && SLURM_INFO="${SLURM_INFO}[${SLURM_ARRAY_TASK_ID}]"
fi

cat > "$RUN_DIR/run_card.md" << EOF
# Run Card: $RUN_ID

> **FACT-ONLY**: 이 문서에는 관측된 사실만 기록합니다.
> 원인 추정, 해석, 가설은 Experiment Memo에 작성하세요.

## Run Info

| Field | Value |
|-------|-------|
| **Run ID** | $RUN_ID |
| **Experiment** | $EXP_NAME |
| **Created** | $(date -Iseconds) |
| **Host** | $(hostname) |
| **Git SHA** | $GIT_SHA |
| **SLURM Job** | $SLURM_INFO |
| **Exit Code** | $EXIT_CODE |
| **Duration** | ${DURATION}s |

## Command

\`\`\`bash
$COMMAND_STR
\`\`\`

## Working Directory

\`\`\`
$CWD
\`\`\`

## Key Metrics (fill manually or via script)

| Metric | Value |
|--------|-------|
| Loss | |
| Accuracy | |
| Other | |

## Files in This Run

- \`stdout.log\` - 표준 출력
- \`stderr.log\` - 표준 에러
- \`meta.txt\` - 실행 메타데이터
- \`env.txt\` - 환경 변수
$(if [[ "$GIT_SHA" != "nogit" ]]; then echo "- \`git_diff.patch\` - uncommitted 변경사항"; fi)
$(if [[ -f "$RUN_DIR/nvidia-smi.txt" ]]; then echo "- \`nvidia-smi.txt\` - GPU 상태"; fi)

## Notes (FACT only)

<!-- 관측된 사실만 기록. 예: "epoch 50에서 loss가 0.001 도달", "OOM 발생" -->

EOF

# --- Summary output ---
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "[run.sh] SUCCESS: $RUN_ID (${DURATION}s)"
else
    echo "[run.sh] FAILED (exit=$EXIT_CODE): $RUN_ID (${DURATION}s)" >&2
fi
echo "[run.sh] Run dir: $RUN_DIR"

# --- Append to run_events.jsonl (using SNAPSHOT from run start) ---
# Features:
#   - Cycle assignment determined at RUN START (not end) - avoids long-run stale false positives
#   - Touch last_activity_ts at run END (already touched at start)
#   - Session ID tracking for multi-session separation
#   - Optional sensitive info redaction (RS_REDACT=1)
#   - Atomic append with fcntl file locking (3 retries with backoff)
#   - JSON corruption detection and isolation

if [[ -n "$SNAPSHOT_RUN_EVENTS_FILE" ]]; then
    # Create directory for the target file
    mkdir -p "$(dirname "$SNAPSHOT_RUN_EVENTS_FILE")"

    # Touch last_activity_ts at RUN END (keeps cycle alive for next run)
    if [[ "$SNAPSHOT_IS_STALE" != "true" ]]; then
        echo "$(date +%s)" > "$CYCLE_ACTIVITY_FILE"
    fi

    # Atomic append with fcntl file locking (3 retries with backoff)
    python3 - "$SNAPSHOT_RUN_EVENTS_FILE" "$RUN_ID" "$EXP_NAME" "$EXIT_CODE" "$DURATION" "$RUN_DIR" "$COMMAND_STR" "$SNAPSHOT_CYCLE_NUM" "$SNAPSHOT_IS_STALE" "$SNAPSHOT_SESSION_ID" "${RS_REDACT:-0}" << 'PYAPPEND' 2>&1 | grep -v "^$" || true
import sys
import json
import time
import fcntl
import re
import os

events_path = sys.argv[1]
run_id = sys.argv[2]
exp = sys.argv[3]
exit_code = int(sys.argv[4])
duration = int(sys.argv[5])
run_dir = sys.argv[6]
cmd = sys.argv[7]
cycle_num = sys.argv[8]
is_stale = sys.argv[9] == "true"
session_id = sys.argv[10] if len(sys.argv) > 10 else ""
redact = sys.argv[11] == "1" if len(sys.argv) > 11 else False

# Sensitive info redaction patterns
REDACT_PATTERNS = [
    (r'(OPENAI_API_KEY|ANTHROPIC_API_KEY|HF_TOKEN|HUGGING_FACE_HUB_TOKEN)=[^\s]+', r'\1=****'),
    (r'(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY)=[^\s]+', r'\1=****'),
    (r'(GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN)=[^\s]+', r'\1=****'),
    (r'(DATABASE_URL|DB_PASSWORD|POSTGRES_PASSWORD)=[^\s]+', r'\1=****'),
    (r'(sk-[a-zA-Z0-9]{20,})', '****'),  # OpenAI API key pattern
    (r'(ghp_[a-zA-Z0-9]{36})', '****'),  # GitHub personal access token
    (r'(gho_[a-zA-Z0-9]{36})', '****'),  # GitHub OAuth token
    (r'(password|passwd|secret|token|key|credential)[=:]\s*[^\s]+', r'\1=****'),
]

def redact_sensitive(text):
    if not redact or not text:
        return text
    for pattern, replacement in REDACT_PATTERNS:
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
    return text

entry = {
    "ts": int(time.time()),
    "run_id": run_id,
    "exp": exp,
    "cmd": redact_sensitive(cmd),
    "run_dir": run_dir,
    "exit_code": exit_code,
    "duration": duration,
    "stdout_path": f"{run_dir}/stdout.log",
    "stderr_path": f"{run_dir}/stderr.log"
}

# Add session_id if available (for multi-session tracking)
if session_id:
    entry["session_id"] = session_id

if is_stale:
    entry["stale_cycle"] = int(cycle_num)
    entry["note"] = "cycle was stale (>60min inactivity), run unattributed"

line = json.dumps(entry, ensure_ascii=False) + '\n'

# Atomic append with 3 retries and exponential backoff
MAX_RETRIES = 3
BACKOFF_BASE = 0.1  # 100ms, 200ms, 400ms

append_success = False
for attempt in range(MAX_RETRIES):
    try:
        with open(events_path, 'a') as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            try:
                f.write(line)
                f.flush()
                append_success = True
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        break
    except (IOError, OSError) as e:
        if attempt < MAX_RETRIES - 1:
            time.sleep(BACKOFF_BASE * (2 ** attempt))
        else:
            # Final failure: warn to stderr (quiet)
            print(f"[run.sh] WARN: run_events append failed after {MAX_RETRIES} retries: {e}", file=sys.stderr)

# Optional: validate last line wasn't corrupted
if append_success:
    try:
        with open(events_path, 'r') as f:
            lines = f.readlines()
            if lines:
                last_line = lines[-1].strip()
                if last_line:
                    json.loads(last_line)  # Validate JSON
    except json.JSONDecodeError:
        # Last line is corrupted - move to corrupt file
        corrupt_path = events_path.replace('.jsonl', '_corrupt.jsonl')
        try:
            with open(corrupt_path, 'a') as cf:
                cf.write(f"# Corrupted at {time.time()}\n")
                cf.write(lines[-1] if lines else "")
            # Remove corrupted line from original (rewrite without last line)
            with open(events_path, 'w') as f:
                f.writelines(lines[:-1])
            print(f"[run.sh] WARN: corrupted line moved to {corrupt_path}", file=sys.stderr)
        except:
            pass
    except:
        pass  # File read failed, ignore
PYAPPEND
fi

# --- Git snapshot (opt-in via RS_GIT_SNAP=1) ---
if [[ "${RS_GIT_SNAP:-}" == "1" ]]; then
    GIT_SNAP_SCRIPT="$SCRIPT_DIR/git_snap.sh"
    if [[ -x "$GIT_SNAP_SCRIPT" ]]; then
        # Tag includes failure status if run failed
        if [[ $EXIT_CODE -eq 0 ]]; then
            SNAP_TAG="run:$RUN_ID"
        else
            SNAP_TAG="run_fail:$RUN_ID"
        fi

        # Build args
        SNAP_ARGS=("$SNAP_TAG")
        if [[ "${RS_GIT_PUSH:-}" == "1" ]]; then
            SNAP_ARGS+=("--push")
        fi

        echo "[run.sh] Creating git snapshot..."
        SNAP_RESULT=$("$GIT_SNAP_SCRIPT" "${SNAP_ARGS[@]}" 2>&1) || true
        echo "[run.sh] git_snap: $SNAP_RESULT"
    fi
fi

# --- Run index CSV (opt-in via RS_RUN_INDEX=1) ---
if [[ "${RS_RUN_INDEX:-}" == "1" ]]; then
    INDEX_CSV="$PROJECT_DIR/runs/index.csv"
    TIMESTAMP_ISO=$(date -Iseconds)

    # Create header if file doesn't exist
    if [[ ! -f "$INDEX_CSV" ]]; then
        echo "run_id,exp_name,exit_code,seconds,timestamp,host,git_sha" > "$INDEX_CSV"
    fi

    # Append row (no stdout/stderr content)
    echo "$RUN_ID,$EXP_NAME,$EXIT_CODE,$DURATION,$TIMESTAMP_ISO,$HOSTNAME_SHORT,$GIT_SHA" >> "$INDEX_CSV"
    echo "[run.sh] Indexed: $INDEX_CSV"
fi

# Return original exit code
exit $EXIT_CODE
