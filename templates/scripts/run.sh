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

# --- Append to run_events.jsonl (for cycle-based collection) ---
# Features:
#   - Atomic append with fcntl file locking (race-safe for concurrent runs)
#   - Stale cycle detection: if cycle > 60min old, write to unattributed_run_events.jsonl
#   - Graceful fallback: if no cycle active (hooks not approved), just skip
CYCLE_ID_FILE="$PROJECT_DIR/.claude/state/current_cycle_id"
CYCLE_TS_FILE="$PROJECT_DIR/.claude/state/current_cycle_start_ts"
RS_CYCLE_STALE_MINUTES="${RS_CYCLE_STALE_MINUTES:-60}"

if [[ -f "$CYCLE_ID_FILE" ]]; then
    CYCLE_NUM=$(cat "$CYCLE_ID_FILE" 2>/dev/null || echo "")
    if [[ -n "$CYCLE_NUM" && "$CYCLE_NUM" =~ ^[0-9]+$ ]]; then
        # Check if cycle is stale (older than RS_CYCLE_STALE_MINUTES)
        IS_STALE=false
        if [[ -f "$CYCLE_TS_FILE" ]]; then
            CYCLE_START_TS=$(cat "$CYCLE_TS_FILE" 2>/dev/null || echo "0")
            CURRENT_TS=$(date +%s)
            STALE_SECONDS=$((RS_CYCLE_STALE_MINUTES * 60))
            if [[ $((CURRENT_TS - CYCLE_START_TS)) -gt $STALE_SECONDS ]]; then
                IS_STALE=true
            fi
        fi

        if [[ "$IS_STALE" == "true" ]]; then
            # Stale cycle: write to unattributed_run_events.jsonl
            RUN_EVENTS_FILE="$PROJECT_DIR/review_cycles/unattributed_run_events.jsonl"
            mkdir -p "$(dirname "$RUN_EVENTS_FILE")"
        else
            # Active cycle: write to cycle-specific run_events.jsonl
            CYCLE_DIR=$(printf "cycle_%04d" "$CYCLE_NUM")
            RUN_EVENTS_FILE="$PROJECT_DIR/review_cycles/$CYCLE_DIR/to_gpt/run_events.jsonl"
            mkdir -p "$(dirname "$RUN_EVENTS_FILE")"
        fi

        # Atomic append with fcntl file locking (macOS/Linux compatible)
        python3 - "$RUN_EVENTS_FILE" "$RUN_ID" "$EXP_NAME" "$EXIT_CODE" "$DURATION" "$RUN_DIR" "$COMMAND_STR" "$CYCLE_NUM" "$IS_STALE" << 'PYAPPEND' 2>/dev/null || true
import sys
import json
import time
import fcntl

events_path = sys.argv[1]
run_id = sys.argv[2]
exp = sys.argv[3]
exit_code = int(sys.argv[4])
duration = int(sys.argv[5])
run_dir = sys.argv[6]
cmd = sys.argv[7]
cycle_num = sys.argv[8]
is_stale = sys.argv[9] == "true"

entry = {
    "ts": int(time.time()),
    "run_id": run_id,
    "exp": exp,
    "cmd": cmd,
    "run_dir": run_dir,
    "exit_code": exit_code,
    "duration": duration,
    "stdout_path": f"{run_dir}/stdout.log",
    "stderr_path": f"{run_dir}/stderr.log"
}

# Add cycle info for unattributed runs
if is_stale:
    entry["stale_cycle"] = int(cycle_num)
    entry["note"] = "cycle was stale (>60min), run unattributed"

# Atomic append with exclusive lock
# Prepare line BEFORE acquiring lock to minimize lock hold time
line = json.dumps(entry, ensure_ascii=False) + '\n'

with open(events_path, 'a') as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)  # Exclusive lock
    try:
        f.write(line)
        f.flush()  # Ensure write is complete before releasing lock
    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)  # Release lock
PYAPPEND
    fi
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
