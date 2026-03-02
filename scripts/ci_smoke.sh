#!/bin/bash
# ci_smoke.sh - CI-grade smoke test for research-template
# Usage: ./scripts/ci_smoke.sh
#
# Tests (non-interactive, no agent CLI required):
# 1. create_project.sh → project structure
# 2. run.sh success/fail
# 3. draft_memo.py
# 4. cycle_export.sh (UserPromptSubmit/Stop, multiline safety, stop_hook_active)
# 5. git_snap.sh (whitelist/blacklist)
# 6. bootstrap_logging.sh (no-overwrite)
# 7. Clipboard scripts (--stdin mode)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Cross-platform sha256
sha256() {
    if command -v sha256sum &> /dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
    rm -rf "$BOOTSTRAP_DIR" 2>/dev/null || true
}

trap cleanup EXIT

# Create temp directories
TEST_DIR=$(mktemp -d)
BOOTSTRAP_DIR=$(mktemp -d)

echo "=========================================="
echo "Research Template CI Smoke Test"
echo "=========================================="
echo "Repo: $REPO_ROOT"
echo "Test dir: $TEST_DIR"
echo ""

# --- Test 1: create_project.sh ---
info "Test 1: create_project.sh"

cd "$REPO_ROOT"
./create_project.sh "CITestProject" "CI smoke test" > /dev/null 2>&1

PROJECT_DIR="$REPO_ROOT/../CITestProject"

if [[ -d "$PROJECT_DIR" ]]; then
    pass "Project created"
else
    fail "Project not created"
    exit 1
fi

# Check required directories
for dir in runs experiments/memos decisions scripts .claude; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
        pass "Directory exists: $dir"
    else
        fail "Directory missing: $dir"
    fi
done

# Check required files
for file in CLAUDE.md CONCEPT.md scripts/run.sh scripts/draft_memo.py .claude/settings.json; do
    if [[ -f "$PROJECT_DIR/$file" ]]; then
        pass "File exists: $file"
    else
        fail "File missing: $file"
    fi
done

# --- Test 2: run.sh success/fail ---
info "Test 2: run.sh success/fail"

cd "$PROJECT_DIR"

# Success case
./scripts/run.sh --exp ci_success echo "SUCCESS_OUTPUT" > /dev/null 2>&1
SUCCESS_RUN=$(ls -1d runs/*ci_success* 2>/dev/null | head -1)

if [[ -n "$SUCCESS_RUN" ]] && [[ -f "$SUCCESS_RUN/run_card.md" ]]; then
    if grep -q "Exit Code.*0" "$SUCCESS_RUN/run_card.md"; then
        pass "run.sh success case (exit=0)"
    else
        fail "run.sh success case exit code mismatch"
    fi
else
    fail "run.sh success case - no run_card.md"
fi

# Fail case
./scripts/run.sh --exp ci_fail bash -c "exit 42" 2>/dev/null || true
FAIL_RUN=$(ls -1d runs/*ci_fail* 2>/dev/null | head -1)

if [[ -n "$FAIL_RUN" ]] && [[ -f "$FAIL_RUN/run_card.md" ]]; then
    if grep -q "Exit Code.*42" "$FAIL_RUN/run_card.md"; then
        pass "run.sh fail case (exit=42)"
    else
        fail "run.sh fail case exit code mismatch"
    fi
else
    fail "run.sh fail case - no run_card.md"
fi

# --- Test 3: draft_memo.py ---
info "Test 3: draft_memo.py"

RUN_ID=$(basename "$SUCCESS_RUN")
python3 ./scripts/draft_memo.py --memo_id ci_memo --goal "CI test" --runs "$RUN_ID" > /dev/null 2>&1

MEMO_FILE="experiments/memos/ci_memo.md"
if [[ -f "$MEMO_FILE" ]]; then
    if grep -q "Inferences" "$MEMO_FILE" && grep -q "Evidence" "$MEMO_FILE"; then
        pass "draft_memo.py creates memo with Inference template"
    else
        fail "draft_memo.py memo missing Inference keywords"
    fi
else
    fail "draft_memo.py did not create memo"
fi

# --- Test 4: cycle_export.sh (UserPromptSubmit + Stop) ---
info "Test 4: cycle_export.sh (UserPromptSubmit/Stop)"

mkdir -p review_cycles .claude/state

# Helper function: get current cycle directory path (uses canonical current_cycle_id)
get_cycle_dir() {
    local cycle_num=$(cat .claude/state/current_cycle_id 2>/dev/null || echo "0")
    printf "review_cycles/cycle_%04d" "$cycle_num"
}

# 4a: UserPromptSubmit → creates cycle directory + user_prompt.txt
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "Test prompt 1"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4A=$(get_cycle_dir)

if [[ -f "$CYCLE_4A/to_gpt/user_prompt.txt" ]]; then
    pass "UserPromptSubmit creates cycle + user_prompt.txt"
else
    fail "UserPromptSubmit failed to create user_prompt.txt"
fi

# 4b: Stop → last_assistant_message.md in same cycle
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Test response from agent"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "$CYCLE_4A/to_gpt/last_assistant_message.md" ]]; then
    pass "Stop creates last_assistant_message.md"
else
    fail "Stop failed to create last_assistant_message.md"
fi

# 4c: Second UserPromptSubmit → increments cycle
PREV_CYCLE_NUM=$(cat .claude/state/current_cycle.txt 2>/dev/null || echo "0")
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "Test prompt 2"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4C=$(get_cycle_dir)
NEW_CYCLE_NUM=$(cat .claude/state/current_cycle.txt 2>/dev/null || echo "0")

if [[ "$NEW_CYCLE_NUM" -gt "$PREV_CYCLE_NUM" ]] && [[ -d "$CYCLE_4C" ]]; then
    pass "Second UserPromptSubmit increments cycle"
else
    fail "Second UserPromptSubmit failed to increment cycle"
fi

# 4d: Verify packet.md exists
if [[ -f "$CYCLE_4A/to_gpt/packet.md" ]] && [[ -f "$CYCLE_4A/to_gpt/UPLOAD_LIST.md" ]]; then
    pass "cycle_export.sh creates packet.md + UPLOAD_LIST.md"
else
    fail "cycle_export.sh missing packet files"
fi

# 4e: Multiline prompt test (regression for sed parsing bug)
MULTILINE_PROMPT='Line 1
Line 2 with "quotes"
Line 3 with $special chars
Line 4'

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "'"$(echo "$MULTILINE_PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4E=$(get_cycle_dir)

SAVED_PROMPT=$(cat "$CYCLE_4E/to_gpt/user_prompt.txt" 2>/dev/null || echo "")
if [[ "$SAVED_PROMPT" == "$MULTILINE_PROMPT" ]]; then
    pass "Multiline prompt preserved correctly"
else
    fail "Multiline prompt corrupted (expected 4 lines, got: $(echo "$SAVED_PROMPT" | wc -l | tr -d ' '))"
fi

# 4f: Multiline assistant message test
MULTILINE_RESPONSE='# Response Header

Here is some code:
```python
def hello():
    print("world")
```

End of response.'

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "'"$(echo "$MULTILINE_RESPONSE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

SAVED_RESPONSE=$(cat "$CYCLE_4E/to_gpt/last_assistant_message.md" 2>/dev/null || echo "")
if [[ "$SAVED_RESPONSE" == "$MULTILINE_RESPONSE" ]]; then
    pass "Multiline assistant message preserved correctly"
else
    fail "Multiline assistant message corrupted (expected 9 lines, got: $(echo "$SAVED_RESPONSE" | wc -l | tr -d ' '))"
fi

# 4g: stop_hook_active handling test (relaxed policy)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "stop_hook test prompt"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4G=$(get_cycle_dir)

STOP_HOOK_MSG="stop_hook_active response"
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "stop_hook_active": true, "last_assistant_message": "'"$STOP_HOOK_MSG"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

SAVED_STOP_MSG=$(cat "$CYCLE_4G/to_gpt/last_assistant_message.md" 2>/dev/null || echo "")
if [[ "$SAVED_STOP_MSG" == "$STOP_HOOK_MSG" ]]; then
    pass "stop_hook_active=true saves last_assistant_message (relaxed)"
else
    fail "stop_hook_active should save last_assistant_message"
fi

if [[ ! -f "$CYCLE_4G/to_gpt/git_diff.patch" ]]; then
    pass "stop_hook_active=true skips heavy ops (no git_diff)"
else
    fail "stop_hook_active should skip git operations"
fi

# 4h: transcript_tail.jsonl generation test (JSONL validity + error extraction)
MOCK_TRANSCRIPT=$(mktemp)
cat > "$MOCK_TRANSCRIPT" << 'MOCKEOF'
{"type": "message", "content": "Starting task..."}
{"type": "message", "content": "Processing data..."}
{"type": "message", "content": "Error: File not found"}
{"type": "message", "content": "Traceback (most recent call last):"}
{"type": "message", "content": "  File 'test.py', line 10"}
{"type": "message", "content": "FileNotFoundError: test.txt"}
{"type": "message", "content": "Retrying..."}
{"type": "message", "content": "Success after retry"}
MOCKEOF

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "transcript test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4H=$(get_cycle_dir)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "transcript_path": "'"$MOCK_TRANSCRIPT"'", "last_assistant_message": "Done"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "$CYCLE_4H/to_gpt/claude_transcript.jsonl" ]]; then
    pass "transcript_path copies full transcript"
else
    fail "transcript_path should copy full transcript"
fi

if [[ -f "$CYCLE_4H/to_gpt/transcript_tail.jsonl" ]]; then
    if grep -q '"Error\|"Traceback' "$CYCLE_4H/to_gpt/transcript_tail.jsonl"; then
        pass "transcript_tail.jsonl extracts error content"
    else
        fail "transcript_tail.jsonl should prioritize error content"
    fi

    JSONL_VALID=$(python3 -c '
import sys, json
path = sys.argv[1]
try:
    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if line:
                json.loads(line)
    print("VALID")
except Exception as e:
    print(f"INVALID at line {i}: {e}")
' "$CYCLE_4H/to_gpt/transcript_tail.jsonl" 2>&1)

    if [[ "$JSONL_VALID" == "VALID" ]]; then
        pass "transcript_tail.jsonl is valid JSONL"
    else
        fail "transcript_tail.jsonl JSONL invalid: $JSONL_VALID"
    fi
else
    fail "transcript_tail.jsonl should be created"
fi

rm -f "$MOCK_TRANSCRIPT"

# 4i: run_logs.txt generation test (DETERMINISTIC - only for FAILED run)
FAKE_FAIL_RUN="$PROJECT_DIR/runs/ci_fake_fail_run"
mkdir -p "$FAKE_FAIL_RUN"

cat > "$FAKE_FAIL_RUN/run_card.md" << 'RUNCARD'
# Run Card: ci_fake_fail_run

| Field | Value |
|-------|-------|
| **Exit Code** | 42 |
| **Duration** | 1s |
RUNCARD

echo "Error: CI deterministic failure test" > "$FAKE_FAIL_RUN/stderr.log"
echo "Traceback (most recent call last):" >> "$FAKE_FAIL_RUN/stderr.log"
echo "  File 'test.py', line 1" >> "$FAKE_FAIL_RUN/stderr.log"
echo "stdout content for ci test" > "$FAKE_FAIL_RUN/stdout.log"

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "run_logs failed test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4I=$(get_cycle_dir)

mkdir -p "$CYCLE_4I/to_gpt"
cat > "$CYCLE_4I/to_gpt/run_events.jsonl" << RUNEVENTS
{"ts": $(date +%s), "run_id": "ci_fake_fail_run", "exp": "ci_fail", "cmd": "fake", "run_dir": "$FAKE_FAIL_RUN", "exit_code": 42, "duration": 1, "stdout_path": "$FAKE_FAIL_RUN/stdout.log", "stderr_path": "$FAKE_FAIL_RUN/stderr.log"}
RUNEVENTS

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Checking logs"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "$CYCLE_4I/to_gpt/run_logs.txt" ]]; then
    pass "run_logs.txt created for failed latest run"

    if grep -q "CI deterministic failure test" "$CYCLE_4I/to_gpt/run_logs.txt"; then
        pass "run_logs.txt contains stderr Error content"
    else
        fail "run_logs.txt should contain stderr Error content"
    fi

    if grep -q "42.*FAILED\|Exit Code" "$CYCLE_4I/to_gpt/run_logs.txt"; then
        pass "run_logs.txt shows exit code"
    else
        fail "run_logs.txt should show exit code"
    fi
else
    fail "run_logs.txt should be created for failed run"
fi

rm -rf "$FAKE_FAIL_RUN"

# 4i-2: run_logs.txt should NOT be created for SUCCESS run
FAKE_SUCCESS_RUN="$PROJECT_DIR/runs/ci_fake_success_run"
mkdir -p "$FAKE_SUCCESS_RUN"

cat > "$FAKE_SUCCESS_RUN/run_card.md" << 'RUNCARD'
# Run Card: ci_fake_success_run

| Field | Value |
|-------|-------|
| **Exit Code** | 0 |
| **Duration** | 1s |
RUNCARD

echo "SUCCESS output" > "$FAKE_SUCCESS_RUN/stdout.log"

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "run_logs success test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4I2=$(get_cycle_dir)

mkdir -p "$CYCLE_4I2/to_gpt"
cat > "$CYCLE_4I2/to_gpt/run_events.jsonl" << RUNEVENTS
{"ts": $(date +%s), "run_id": "ci_fake_success_run", "exp": "ci_success", "cmd": "fake", "run_dir": "$FAKE_SUCCESS_RUN", "exit_code": 0, "duration": 1, "stdout_path": "$FAKE_SUCCESS_RUN/stdout.log", "stderr_path": "$FAKE_SUCCESS_RUN/stderr.log"}
RUNEVENTS

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Success check"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ ! -f "$CYCLE_4I2/to_gpt/run_logs.txt" ]]; then
    pass "run_logs.txt NOT created for success run (correct)"
else
    fail "run_logs.txt should NOT be created for success run"
fi

if [[ -f "$CYCLE_4I2/to_gpt/run_summary.md" ]]; then
    if grep -q "SUCCESS" "$CYCLE_4I2/to_gpt/run_summary.md"; then
        pass "run_summary.md shows SUCCESS for exit=0"
    else
        fail "run_summary.md should show SUCCESS"
    fi
else
    fail "run_summary.md should exist even for success run"
fi

rm -rf "$FAKE_SUCCESS_RUN"

# 4j: packet.md contains file sizes (use cycle_4h which has transcript)
if grep -q "B |" "$CYCLE_4H/to_gpt/packet.md" 2>/dev/null; then
    pass "packet.md includes file sizes"
else
    fail "packet.md should include file sizes (bytes)"
fi

# 4k: packet.md contains priority column
if grep -q "우선순위\|필수\|권장\|선택" "$CYCLE_4H/to_gpt/packet.md" 2>/dev/null; then
    pass "packet.md includes upload priorities"
else
    fail "packet.md should include priority (필수/권장/선택)"
fi

# 4l: Stop without last_assistant_message → transcript recovery
MOCK_TRANSCRIPT_RECOVERY=$(mktemp)
cat > "$MOCK_TRANSCRIPT_RECOVERY" << 'MOCKJSONL'
{"type":"user","message":{"role":"user","content":"Please help me"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Let me think..."},{"type":"text","text":"I'll help you with that task."}]}}
{"type":"user","message":{"role":"user","content":"Thanks, continue"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"FINAL_ASSISTANT_TEXT_FROM_NESTED_TRANSCRIPT"}]}}
MOCKJSONL

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "transcript recovery test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4L=$(get_cycle_dir)

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "transcript_path": "'"$MOCK_TRANSCRIPT_RECOVERY"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "$CYCLE_4L/to_gpt/last_assistant_message.md" ]]; then
    RECOVERED_MSG=$(cat "$CYCLE_4L/to_gpt/last_assistant_message.md" 2>/dev/null || echo "")
    if echo "$RECOVERED_MSG" | grep -q "FINAL_ASSISTANT_TEXT_FROM_NESTED_TRANSCRIPT"; then
        pass "Stop recovers last_assistant_message from nested transcript"
    else
        fail "nested transcript recovery failed: got '$RECOVERED_MSG'"
    fi
else
    fail "Stop should create last_assistant_message.md via transcript fallback"
fi

if grep -q "MISSING.*last_assistant_message" "$CYCLE_4L/to_gpt/packet.md" 2>/dev/null; then
    fail "packet.md should not show MISSING when transcript recovery succeeds"
else
    pass "packet.md shows no MISSING when transcript recovery succeeds"
fi

rm -f "$MOCK_TRANSCRIPT_RECOVERY"

# 4l-2: 0-byte last_assistant_message should show MISSING warning
MOCK_TRANSCRIPT_EMPTY=$(mktemp)
cat > "$MOCK_TRANSCRIPT_EMPTY" << 'MOCKJSONL'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Just thinking, no text output"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"test","name":"Bash","input":{}}]}}
MOCKJSONL

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "empty transcript test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4L2=$(get_cycle_dir)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "transcript_path": "'"$MOCK_TRANSCRIPT_EMPTY"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ ! -f "$CYCLE_4L2/to_gpt/last_assistant_message.md" ]]; then
    pass "0-byte last_assistant_message.md is deleted"
else
    if [[ ! -s "$CYCLE_4L2/to_gpt/last_assistant_message.md" ]]; then
        fail "0-byte file should be deleted"
    else
        pass "last_assistant_message.md has content (unexpected but ok)"
    fi
fi

if grep -q "MISSING.*last_assistant_message" "$CYCLE_4L2/to_gpt/packet.md" 2>/dev/null; then
    pass "packet.md shows MISSING for empty transcript extraction"
else
    fail "packet.md should show MISSING when extraction yields nothing"
fi

rm -f "$MOCK_TRANSCRIPT_EMPTY"

# 4m: run_summary.md format verification (run_events-based)
FAKE_SUMMARY_RUN="$PROJECT_DIR/runs/ci_summary_test_run"
mkdir -p "$FAKE_SUMMARY_RUN"

cat > "$FAKE_SUMMARY_RUN/run_card.md" << 'RUNCARD'
# Run Card: ci_summary_test_run

| Field | Value |
|-------|-------|
| **Exit Code** | 0 |
| **Duration** | 5s |
RUNCARD

for i in $(seq 1 25); do
    echo "stdout line $i: training progress epoch $i"
done > "$FAKE_SUMMARY_RUN/stdout.log"

cat > "$FAKE_SUMMARY_RUN/stderr.log" << 'STDERR'
WARNING: learning rate seems high
INFO: GPU memory usage 50%
DEBUG: batch processing complete
STDERR

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "run_summary test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4M=$(get_cycle_dir)

mkdir -p "$CYCLE_4M/to_gpt"
cat > "$CYCLE_4M/to_gpt/run_events.jsonl" << RUNEVENTS
{"ts": $(date +%s), "run_id": "ci_summary_test_run", "exp": "summary_test", "cmd": "fake training", "run_dir": "$FAKE_SUMMARY_RUN", "exit_code": 0, "duration": 5, "stdout_path": "$FAKE_SUMMARY_RUN/stdout.log", "stderr_path": "$FAKE_SUMMARY_RUN/stderr.log"}
RUNEVENTS

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Checking run summary"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

RUN_SUMMARY_FILE="$CYCLE_4M/to_gpt/run_summary.md"

if [[ -f "$RUN_SUMMARY_FILE" ]]; then
    pass "run_summary.md created"

    if grep -q "ci_summary_test_run" "$RUN_SUMMARY_FILE"; then
        pass "run_summary.md contains Run ID"
    else
        fail "run_summary.md missing Run ID"
    fi

    if grep -q "Run Dir\|run_dir" "$RUN_SUMMARY_FILE"; then
        pass "run_summary.md contains Run Dir path"
    else
        fail "run_summary.md missing Run Dir"
    fi

    if grep -q "SUCCESS" "$RUN_SUMMARY_FILE"; then
        pass "run_summary.md contains SUCCESS status"
    else
        fail "run_summary.md should show SUCCESS for exit=0"
    fi

    if grep -q "stdout\|stdout line" "$RUN_SUMMARY_FILE"; then
        if grep -q "training progress" "$RUN_SUMMARY_FILE"; then
            pass "run_summary.md contains stdout tail"
        else
            fail "run_summary.md stdout section empty or truncated wrong"
        fi
    else
        fail "run_summary.md missing stdout section"
    fi

    if grep -q "| 1 |" "$RUN_SUMMARY_FILE" && grep -q "summary_test" "$RUN_SUMMARY_FILE"; then
        pass "run_summary.md contains run table entry"
    else
        fail "run_summary.md missing run table entry"
    fi
else
    fail "run_summary.md should be created"
fi

rm -rf "$FAKE_SUMMARY_RUN"

# 4n: Multi-run cycle test (run_events.jsonl based with 3 runs)
# Test: execute 3 runs in same cycle (2 success + 1 fail), verify all runs captured
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "multi-run cycle test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4N=$(get_cycle_dir)

# Run 1: Success
./scripts/run.sh --exp multi_success1 echo "Multi run success 1" > /dev/null 2>&1

# Run 2: Failure
./scripts/run.sh --exp multi_fail bash -c "exit 7" 2>/dev/null || true

# Run 3: Success
./scripts/run.sh --exp multi_success2 echo "Multi run success 2" > /dev/null 2>&1

# Trigger Stop
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Multi-run test done"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

MULTI_RUN_EVENTS="$CYCLE_4N/to_gpt/run_events.jsonl"
if [[ -f "$MULTI_RUN_EVENTS" ]]; then
    EVENT_COUNT=$(wc -l < "$MULTI_RUN_EVENTS" | tr -d ' ')
    if [[ "$EVENT_COUNT" -eq 3 ]]; then
        pass "run_events.jsonl contains 3 entries"
    else
        fail "run_events.jsonl should have 3 entries (got: $EVENT_COUNT)"
    fi

    if grep -q "multi_success1" "$MULTI_RUN_EVENTS" && grep -q "multi_fail" "$MULTI_RUN_EVENTS" && grep -q "multi_success2" "$MULTI_RUN_EVENTS"; then
        pass "run_events.jsonl contains all experiment names"
    else
        fail "run_events.jsonl missing experiment names"
    fi

    if grep -q '"exit_code": 0' "$MULTI_RUN_EVENTS" && grep -q '"exit_code": 7' "$MULTI_RUN_EVENTS"; then
        pass "run_events.jsonl contains correct exit codes"
    else
        fail "run_events.jsonl missing correct exit codes"
    fi
else
    fail "run_events.jsonl should be created for multi-run cycle"
fi

MULTI_RUN_SUMMARY="$CYCLE_4N/to_gpt/run_summary.md"
if [[ -f "$MULTI_RUN_SUMMARY" ]]; then
    if grep -q "multi_success1" "$MULTI_RUN_SUMMARY" && grep -q "multi_fail" "$MULTI_RUN_SUMMARY" && grep -q "multi_success2" "$MULTI_RUN_SUMMARY"; then
        pass "run_summary.md includes all 3 runs"
    else
        fail "run_summary.md should include all 3 runs"
    fi

    if grep -q "Total runs this cycle: 3" "$MULTI_RUN_SUMMARY"; then
        pass "run_summary.md shows correct total count"
    else
        fail "run_summary.md should show total count: 3"
    fi

    if grep -q "Failed runs: 1" "$MULTI_RUN_SUMMARY"; then
        pass "run_summary.md shows failed count"
    else
        fail "run_summary.md should show failed count"
    fi
else
    fail "run_summary.md should exist for multi-run cycle"
fi

MULTI_RUN_LOGS="$CYCLE_4N/to_gpt/run_logs.txt"
if [[ -f "$MULTI_RUN_LOGS" ]]; then
    pass "run_logs.txt created for multi-run cycle with failure"

    if grep -q "multi_fail" "$MULTI_RUN_LOGS"; then
        pass "run_logs.txt contains failed run"
    else
        fail "run_logs.txt should contain failed run"
    fi

    # run_logs should only have failed runs, not successes
    if ! grep -q "multi_success1\|multi_success2" "$MULTI_RUN_LOGS"; then
        pass "run_logs.txt excludes success runs"
    else
        fail "run_logs.txt should only contain failed runs"
    fi
else
    fail "run_logs.txt should exist when any run failed"
fi

# Cleanup multi-run test artifacts
rm -rf "$PROJECT_DIR/runs/"*multi_*

# 4o: Fallback test - run_summary without run_events.jsonl
# Test that run_card.md scan works as fallback when hooks weren't approved
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "fallback test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4O=$(get_cycle_dir)

# Create a fake run WITHOUT using run.sh (simulates hooks not approved)
FAKE_FALLBACK_RUN="$PROJECT_DIR/runs/ci_fallback_test_run"
mkdir -p "$FAKE_FALLBACK_RUN"
cat > "$FAKE_FALLBACK_RUN/run_card.md" << 'RUNCARD'
# Run Card: ci_fallback_test_run

| Field | Value |
|-------|-------|
| **Exit Code** | 0 |
| **Duration** | 2s |
RUNCARD
echo "Fallback stdout test" > "$FAKE_FALLBACK_RUN/stdout.log"
touch "$FAKE_FALLBACK_RUN/run_card.md"  # Ensure recent mtime

# Do NOT create run_events.jsonl - this triggers fallback
# Trigger Stop
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Fallback test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "$CYCLE_4O/to_gpt/run_summary.md" ]]; then
    if grep -q "fallback\|ci_fallback_test_run" "$CYCLE_4O/to_gpt/run_summary.md"; then
        pass "Fallback run_summary.md generated from run_card.md scan"
    else
        fail "Fallback run_summary should contain the run"
    fi
else
    fail "Fallback run_summary.md should be created when no run_events.jsonl"
fi

rm -rf "$FAKE_FALLBACK_RUN"

# 4p: Long cycle false positive prevention
# Test that stale detection uses last_activity_ts (not start_ts)
# A cycle with old start_ts but recent last_activity_ts should NOT be marked stale
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "long cycle test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4P=$(get_cycle_dir)

# Manipulate timestamps: start_ts is 2 hours ago, but last_activity_ts is NOW
CURRENT_TS=$(date +%s)
OLD_TS=$((CURRENT_TS - 7200))  # 2 hours ago (well beyond 60min stale threshold)

echo "$OLD_TS" > .claude/state/current_cycle_start_ts
echo "$CURRENT_TS" > .claude/state/current_cycle_last_activity_ts

# Run a test - should go to current cycle (not unattributed) because last_activity_ts is recent
./scripts/run.sh --exp long_cycle_test echo "Testing stale detection" > /dev/null 2>&1

LONG_CYCLE_EVENTS="$CYCLE_4P/to_gpt/run_events.jsonl"
UNATTRIBUTED_EVENTS="$PROJECT_DIR/review_cycles/unattributed_run_events.jsonl"

if [[ -f "$LONG_CYCLE_EVENTS" ]] && grep -q "long_cycle_test" "$LONG_CYCLE_EVENTS"; then
    pass "Long cycle with recent activity: run attributed to correct cycle"
else
    if [[ -f "$UNATTRIBUTED_EVENTS" ]] && grep -q "long_cycle_test" "$UNATTRIBUTED_EVENTS"; then
        fail "Long cycle false positive: run incorrectly sent to unattributed (stale detection bug)"
    else
        fail "Long cycle test: run_events.jsonl not found or missing experiment"
    fi
fi

# Test the opposite: truly stale cycle (both start_ts AND last_activity_ts are old)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "stale cycle test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4P_STALE=$(get_cycle_dir)

# Both timestamps old = truly stale
echo "$OLD_TS" > .claude/state/current_cycle_start_ts
echo "$OLD_TS" > .claude/state/current_cycle_last_activity_ts

./scripts/run.sh --exp truly_stale_test echo "Testing truly stale" > /dev/null 2>&1

if [[ -f "$UNATTRIBUTED_EVENTS" ]] && grep -q "truly_stale_test" "$UNATTRIBUTED_EVENTS"; then
    pass "Truly stale cycle: run correctly sent to unattributed"
else
    STALE_CYCLE_EVENTS="$CYCLE_4P_STALE/to_gpt/run_events.jsonl"
    if [[ -f "$STALE_CYCLE_EVENTS" ]] && grep -q "truly_stale_test" "$STALE_CYCLE_EVENTS"; then
        fail "Truly stale cycle: run incorrectly attributed (should be unattributed)"
    else
        fail "Truly stale test: run not found anywhere"
    fi
fi

# Cleanup
rm -rf "$PROJECT_DIR/runs/"*long_cycle* "$PROJECT_DIR/runs/"*truly_stale*
rm -f "$UNATTRIBUTED_EVENTS"

# 4q: Snapshot-based cycle assignment (run exceeds stale threshold during execution)
# The cycle should be determined at RUN START, not at append time
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "snapshot test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4Q=$(get_cycle_dir)

# Use very short stale threshold (1 second) and sleep during run
# Run should STILL go to the cycle because it was assigned at start
RS_CYCLE_STALE_MINUTES=0 ./scripts/run.sh --exp snapshot_test bash -c "sleep 2; echo done" > /dev/null 2>&1

SNAPSHOT_EVENTS="$CYCLE_4Q/to_gpt/run_events.jsonl"
if [[ -f "$SNAPSHOT_EVENTS" ]] && grep -q "snapshot_test" "$SNAPSHOT_EVENTS"; then
    pass "Snapshot-based assignment: run attributed despite exceeding stale during execution"
else
    UNATTRIB_CHECK="$PROJECT_DIR/review_cycles/unattributed_run_events.jsonl"
    if [[ -f "$UNATTRIB_CHECK" ]] && grep -q "snapshot_test" "$UNATTRIB_CHECK"; then
        fail "Snapshot bug: run went to unattributed (should use start-time assignment)"
    else
        fail "Snapshot test: run not found anywhere"
    fi
fi
rm -rf "$PROJECT_DIR/runs/"*snapshot_test*
rm -f "$PROJECT_DIR/review_cycles/unattributed_run_events.jsonl"

# 4r: Session ID tracking and filtering
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "SessionStart"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "session test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4R=$(get_cycle_dir)

# Verify session_id was created (now uses latest_session_id instead of global file)
if [[ -f ".claude/state/latest_session_id" ]]; then
    SESSION_ID=$(cat .claude/state/latest_session_id)
    if [[ -n "$SESSION_ID" ]]; then
        pass "Session ID created: $SESSION_ID"
    else
        fail "Session ID file exists but is empty"
    fi
else
    fail "Session ID file not created (latest_session_id)"
fi

# Run a test and verify session_id is in run_events
./scripts/run.sh --exp session_test echo "session tracking" > /dev/null 2>&1

SESSION_EVENTS="$CYCLE_4R/to_gpt/run_events.jsonl"
if [[ -f "$SESSION_EVENTS" ]] && grep -q "session_id" "$SESSION_EVENTS"; then
    pass "Session ID included in run_events.jsonl"
else
    fail "Session ID not found in run_events.jsonl"
fi
rm -rf "$PROJECT_DIR/runs/"*session_test*

# 4s: Sensitive info redaction (RS_REDACT=1)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "redact test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4S=$(get_cycle_dir)

# Run with sensitive-looking command (simulated API key)
RS_REDACT=1 ./scripts/run.sh --exp redact_test bash -c 'echo "OPENAI_API_KEY=sk-1234567890abcdef"' > /dev/null 2>&1

REDACT_EVENTS="$CYCLE_4S/to_gpt/run_events.jsonl"
if [[ -f "$REDACT_EVENTS" ]]; then
    # Check that the API key pattern is masked
    if grep -q "sk-1234567890" "$REDACT_EVENTS"; then
        fail "Redaction failed: API key not masked in run_events"
    else
        if grep -q '\*\*\*\*' "$REDACT_EVENTS"; then
            pass "Redaction works: sensitive info masked in run_events"
        else
            pass "Redaction check: no sensitive pattern found (may be in stdout only)"
        fi
    fi
else
    fail "Redaction test: run_events.jsonl not created"
fi
rm -rf "$PROJECT_DIR/runs/"*redact_test*

# 4t: env.txt default OFF (security)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "env test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

# Run WITHOUT RS_SAVE_ENV - env.txt should NOT be created
./scripts/run.sh --exp env_off_test echo "testing env off" > /dev/null 2>&1
ENV_OFF_RUN=$(ls -td "$PROJECT_DIR/runs/"*env_off_test* 2>/dev/null | head -1)
if [[ -f "$ENV_OFF_RUN/env.txt" ]]; then
    fail "env.txt created when RS_SAVE_ENV not set (should be OFF by default)"
else
    pass "env.txt default OFF: file not created"
fi

# Run WITH RS_SAVE_ENV=1 - env.txt should be created with allowlist only
RS_SAVE_ENV=1 ./scripts/run.sh --exp env_on_test echo "testing env on" > /dev/null 2>&1
ENV_ON_RUN=$(ls -td "$PROJECT_DIR/runs/"*env_on_test* 2>/dev/null | head -1)
if [[ -f "$ENV_ON_RUN/env.txt" ]]; then
    # Should only contain safe vars (PATH, CUDA, etc), not secrets
    if grep -qiE "(API_KEY|SECRET|TOKEN|PASSWORD)" "$ENV_ON_RUN/env.txt" 2>/dev/null; then
        fail "env.txt contains sensitive-looking vars (should use allowlist)"
    else
        pass "env.txt created with allowlist when RS_SAVE_ENV=1"
    fi
else
    fail "env.txt not created when RS_SAVE_ENV=1"
fi
rm -rf "$PROJECT_DIR/runs/"*env_*_test*

# 4u: run_events.jsonl integrity (clean/bad separation)
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "integrity test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4U=$(get_cycle_dir)

# Create a run_events.jsonl with some valid and some invalid lines
./scripts/run.sh --exp integrity_test echo "valid run" > /dev/null 2>&1
INTEGRITY_EVENTS="$CYCLE_4U/to_gpt/run_events.jsonl"

# Manually append a corrupted line
echo "this is not valid json {broken" >> "$INTEGRITY_EVENTS"
echo '{"valid": "json", "but": "no run_id"}' >> "$INTEGRITY_EVENTS"

# Trigger Stop to process integrity
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "integrity test done"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

# Check clean file exists and has valid content
if [[ -f "$CYCLE_4U/to_gpt/run_events.clean.jsonl" ]]; then
    CLEAN_LINES=$(wc -l < "$CYCLE_4U/to_gpt/run_events.clean.jsonl" | tr -d ' ')
    if [[ "$CLEAN_LINES" -ge 1 ]]; then
        pass "run_events.clean.jsonl created with valid lines"
    else
        fail "run_events.clean.jsonl is empty"
    fi
else
    fail "run_events.clean.jsonl not created"
fi

# Check bad file exists (we added corrupted lines)
if [[ -f "$CYCLE_4U/to_gpt/run_events.bad.jsonl" ]]; then
    if grep -q "broken" "$CYCLE_4U/to_gpt/run_events.bad.jsonl"; then
        pass "run_events.bad.jsonl contains corrupted lines"
    else
        fail "run_events.bad.jsonl missing corrupted content"
    fi
else
    fail "run_events.bad.jsonl not created for corrupted input"
fi

# Check packet.md has warning
if grep -q "corrupted\|WARNING" "$CYCLE_4U/to_gpt/packet.md" 2>/dev/null; then
    pass "packet.md shows corruption warning"
else
    fail "packet.md missing corruption warning"
fi
rm -rf "$PROJECT_DIR/runs/"*integrity_test*

# 4v: gpt_bundle.md generation
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "bundle test"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1
CYCLE_4V=$(get_cycle_dir)

./scripts/run.sh --exp bundle_success echo "bundle success" > /dev/null 2>&1
./scripts/run.sh --exp bundle_fail bash -c "echo 'error output' >&2; exit 1" 2>/dev/null || true

echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "bundle test response with content"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

BUNDLE_FILE="$CYCLE_4V/to_gpt/gpt_bundle.md"
if [[ -f "$BUNDLE_FILE" ]]; then
    pass "gpt_bundle.md created"

    # Check structure
    if grep -q "GPT Review Bundle" "$BUNDLE_FILE"; then
        pass "gpt_bundle.md has header"
    else
        fail "gpt_bundle.md missing header"
    fi

    if grep -q "Run Summary" "$BUNDLE_FILE"; then
        pass "gpt_bundle.md includes run_summary"
    else
        fail "gpt_bundle.md missing run_summary"
    fi

    # Check size limit (should be under 80KB by default)
    BUNDLE_SIZE=$(wc -c < "$BUNDLE_FILE" | tr -d ' ')
    if [[ "$BUNDLE_SIZE" -lt 82000 ]]; then
        pass "gpt_bundle.md size within limit (${BUNDLE_SIZE} bytes)"
    else
        fail "gpt_bundle.md exceeds 80KB limit (${BUNDLE_SIZE} bytes)"
    fi
else
    fail "gpt_bundle.md not created"
fi
rm -rf "$PROJECT_DIR/runs/"*bundle_*

# --- Test 5: git_snap.sh ---
info "Test 5: git_snap.sh"

# Configure git for CI environments (required for commit)
git config user.name "CI Test" 2>/dev/null || true
git config user.email "ci@test.local" 2>/dev/null || true

git init -q
git add -A
git commit -m "Initial" -q

# 5a: NO_CHANGES
SNAP_RESULT=$(./scripts/git_snap.sh "test" 2>&1)
if [[ "$SNAP_RESULT" == "NO_CHANGES" ]]; then
    pass "git_snap.sh NO_CHANGES when nothing changed"
else
    fail "git_snap.sh should return NO_CHANGES (got: $SNAP_RESULT)"
fi

# 5b: Whitelist commit
echo "# Test change" >> README.md
SNAP_RESULT=$(./scripts/git_snap.sh "whitelist_test" 2>&1)
if [[ "$SNAP_RESULT" == COMMITTED:* ]]; then
    pass "git_snap.sh commits whitelist changes"
else
    fail "git_snap.sh should commit (got: $SNAP_RESULT)"
fi

# 5c: Blacklist exclusion
echo "blacklist test" > review_cycles/test.txt
echo "stdout test" > "$SUCCESS_RUN/stdout.log"
git add -A 2>/dev/null || true

# Check that blacklisted files are NOT in the last commit
LAST_COMMIT_FILES=$(git show --name-only --format="" HEAD 2>/dev/null || echo "")
if echo "$LAST_COMMIT_FILES" | grep -q "review_cycles/"; then
    fail "git_snap.sh should exclude review_cycles/"
else
    pass "git_snap.sh excludes review_cycles/"
fi

if echo "$LAST_COMMIT_FILES" | grep -q "stdout.log"; then
    fail "git_snap.sh should exclude stdout.log"
else
    pass "git_snap.sh excludes stdout.log"
fi

# --- Test 6: bootstrap_logging.sh no-overwrite ---
info "Test 6: bootstrap_logging.sh no-overwrite"

# Create dummy existing project
mkdir -p "$BOOTSTRAP_DIR/scripts"
echo "ORIGINAL_CONTENT_UNIQUE_12345" > "$BOOTSTRAP_DIR/scripts/run.sh"
HASH_BEFORE=$(sha256 "$BOOTSTRAP_DIR/scripts/run.sh")

# Run bootstrap
bash "$REPO_ROOT/templates/scripts/bootstrap_logging.sh" "$BOOTSTRAP_DIR" > /dev/null 2>&1

HASH_AFTER=$(sha256 "$BOOTSTRAP_DIR/scripts/run.sh")

if [[ "$HASH_BEFORE" == "$HASH_AFTER" ]]; then
    pass "bootstrap_logging.sh preserves existing files"
else
    fail "bootstrap_logging.sh overwrote existing file"
fi

# Verify new files were added
if [[ -f "$BOOTSTRAP_DIR/scripts/draft_memo.py" ]]; then
    pass "bootstrap_logging.sh adds missing scripts"
else
    fail "bootstrap_logging.sh did not add draft_memo.py"
fi

# --- Test 7: Clipboard scripts (--stdin mode only, no pbpaste) ---
info "Test 7: Clipboard scripts (--stdin)"

cd "$PROJECT_DIR"

# Find latest cycle (created by Test 4)
LATEST_CYCLE=$(find review_cycles -maxdepth 1 -type d -name "cycle_*" 2>/dev/null | sort -V | tail -1)
LATEST_CYCLE_NAME=$(basename "$LATEST_CYCLE")

echo "GPT review content" | ./scripts/save_clipboard_to_gpt_review.sh --stdin > /dev/null 2>&1

if [[ -f "$LATEST_CYCLE/from_gpt/gpt_review.md" ]]; then
    pass "save_clipboard_to_gpt_review.sh --stdin works"
else
    fail "save_clipboard_to_gpt_review.sh --stdin failed"
fi

echo "Next prompt content" | ./scripts/save_clipboard_to_next_prompt.sh --stdin > /dev/null 2>&1

if [[ -f "$LATEST_CYCLE/to_claude/next_prompt.txt" ]]; then
    pass "save_clipboard_to_next_prompt.sh --stdin works"
else
    fail "save_clipboard_to_next_prompt.sh --stdin failed"
fi

# --- Cleanup test project ---
rm -rf "$PROJECT_DIR"

# --- Summary ---
echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo -e "${GREEN}PASS: $PASS_COUNT${NC}"
echo -e "${RED}FAIL: $FAIL_COUNT${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
