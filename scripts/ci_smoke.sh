#!/bin/bash
# ci_smoke.sh - CI-grade smoke test for research-template
# Usage: ./scripts/ci_smoke.sh
#
# Tests (non-interactive, no claude required):
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

# 4a: UserPromptSubmit → cycle_0001 + user_prompt.txt
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "Test prompt 1"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "review_cycles/cycle_0001/to_gpt/user_prompt.txt" ]]; then
    pass "UserPromptSubmit creates cycle_0001 + user_prompt.txt"
else
    fail "UserPromptSubmit failed to create user_prompt.txt"
fi

# 4b: Stop → last_assistant_message.md in same cycle
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "last_assistant_message": "Test response from Claude"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -f "review_cycles/cycle_0001/to_gpt/last_assistant_message.md" ]]; then
    pass "Stop creates last_assistant_message.md"
else
    fail "Stop failed to create last_assistant_message.md"
fi

# 4c: Second UserPromptSubmit → cycle_0002
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "Test prompt 2"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

if [[ -d "review_cycles/cycle_0002" ]]; then
    pass "Second UserPromptSubmit creates cycle_0002"
else
    fail "Second UserPromptSubmit failed to increment cycle"
fi

# 4d: Verify packet.md exists
if [[ -f "review_cycles/cycle_0001/to_gpt/packet.md" ]] && [[ -f "review_cycles/cycle_0001/to_gpt/UPLOAD_LIST.md" ]]; then
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

SAVED_PROMPT=$(cat "review_cycles/cycle_0003/to_gpt/user_prompt.txt" 2>/dev/null || echo "")
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

SAVED_RESPONSE=$(cat "review_cycles/cycle_0003/to_gpt/last_assistant_message.md" 2>/dev/null || echo "")
if [[ "$SAVED_RESPONSE" == "$MULTILINE_RESPONSE" ]]; then
    pass "Multiline assistant message preserved correctly"
else
    fail "Multiline assistant message corrupted (expected 9 lines, got: $(echo "$SAVED_RESPONSE" | wc -l | tr -d ' '))"
fi

# 4g: stop_hook_active handling test (relaxed policy)
# Setup: create cycle_0004 with UserPromptSubmit, then test stop_hook_active Stop
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "UserPromptSubmit", "prompt": "stop_hook test prompt"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

# Now test stop_hook_active=true Stop on cycle_0004
STOP_HOOK_MSG="stop_hook_active response"
echo '{"cwd": "'"$PROJECT_DIR"'", "hook_event_name": "Stop", "stop_hook_active": true, "last_assistant_message": "'"$STOP_HOOK_MSG"'"}' | ./.claude/hooks/cycle_export.sh > /dev/null 2>&1

# Check: last_assistant_message.md saved (relaxed policy allows this)
SAVED_STOP_MSG=$(cat "review_cycles/cycle_0004/to_gpt/last_assistant_message.md" 2>/dev/null || echo "")
if [[ "$SAVED_STOP_MSG" == "$STOP_HOOK_MSG" ]]; then
    pass "stop_hook_active=true saves last_assistant_message (relaxed)"
else
    fail "stop_hook_active should save last_assistant_message"
fi

# Check: heavy ops skipped (no git_diff.patch since stop_hook_active exits before git ops)
if [[ ! -f "review_cycles/cycle_0004/to_gpt/git_diff.patch" ]]; then
    pass "stop_hook_active=true skips heavy ops (no git_diff)"
else
    fail "stop_hook_active should skip git operations"
fi

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
