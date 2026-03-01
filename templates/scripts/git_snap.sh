#!/bin/bash
# git_snap.sh - Opt-in git snapshot for research projects
# Usage: ./scripts/git_snap.sh "tag" [--push]
#
# Features:
#   - Whitelist-based staging (only safe files)
#   - Blacklist enforcement (no large logs/data)
#   - Lock mechanism to prevent concurrent runs
#   - Optional push (--push or RS_GIT_PUSH=1)
#
# Exit codes: always 0 (safe for automation)
# Output: NOT_A_GIT_REPO | NO_CHANGES | LOCKED | commit hash

set -e

TAG="${1:-snapshot}"
DO_PUSH=0

# Parse --push flag
for arg in "$@"; do
    if [[ "$arg" == "--push" ]]; then
        DO_PUSH=1
    fi
done

# RS_GIT_PUSH=1 also enables push
if [[ "${RS_GIT_PUSH:-}" == "1" ]]; then
    DO_PUSH=1
fi

# --- Check if git repo ---
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "NOT_A_GIT_REPO"
    exit 0
fi

GIT_DIR=$(git rev-parse --git-dir)
LOCK_DIR="$GIT_DIR/.git_snap_lock"

# --- Lock mechanism (mkdir-based, works on macOS/Linux) ---
cleanup_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "LOCKED"
    exit 0
fi
trap cleanup_lock EXIT

# --- Whitelist: paths to consider for staging ---
# These patterns are checked explicitly
WHITELIST_DIRS=(
    "src"
    "scripts"
    "configs"
)

WHITELIST_FILES=(
    "*.md"                      # Root markdown files
    "runs/*/run_card.md"
    "runs/*/metrics.json"
    "experiments/memos/*.md"
    "decisions/*.md"
)

# --- Blacklist definitions (prefix-based for reliability) ---

# Directories to skip entirely (any depth)
BLACKLIST_DIR_PREFIXES=(
    "review_cycles/"
    "data/"
    "checkpoints/"
    "wandb/"
)

# Filenames to skip inside runs/ directory
BLACKLIST_RUNS_FILES=(
    "stdout.log"
    "stderr.log"
    "env.txt"
    "nvidia-smi.txt"
    "git_diff.patch"
)

# Extensions to skip globally
BLACKLIST_EXTENSIONS=(
    ".pt"
    ".pth"
    ".ckpt"
)

# --- Helper: check if path should be blacklisted (prefix-based) ---
is_blacklisted() {
    local path="$1"
    local basename="${path##*/}"

    # 1. Check directory prefixes (any depth)
    for prefix in "${BLACKLIST_DIR_PREFIXES[@]}"; do
        if [[ "$path" == "$prefix"* ]]; then
            return 0
        fi
    done

    # 2. Check runs/ log files (prefix + basename)
    if [[ "$path" == runs/* ]]; then
        for fname in "${BLACKLIST_RUNS_FILES[@]}"; do
            if [[ "$basename" == "$fname" ]]; then
                return 0
            fi
        done
    fi

    # 3. Check blacklisted extensions
    for ext in "${BLACKLIST_EXTENSIONS[@]}"; do
        if [[ "$path" == *"$ext" ]]; then
            return 0
        fi
    done

    return 1
}

# --- Stage whitelisted files ---
staged_count=0

# 1. Stage whitelisted directories (tracked + untracked)
for dir in "${WHITELIST_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        # Get all files in directory (tracked and untracked)
        while IFS= read -r -d '' file; do
            if ! is_blacklisted "$file"; then
                git add "$file" 2>/dev/null && ((staged_count++)) || true
            fi
        done < <(find "$dir" -type f -print0 2>/dev/null)
    fi
done

# 2. Stage whitelisted file patterns
for pattern in "${WHITELIST_FILES[@]}"; do
    # Handle glob patterns
    for file in $pattern; do
        if [[ -f "$file" ]] && ! is_blacklisted "$file"; then
            git add "$file" 2>/dev/null && ((staged_count++)) || true
        fi
    done
done

# --- Check if anything was staged ---
if git diff --cached --quiet; then
    echo "NO_CHANGES"
    exit 0
fi

# --- Generate commit message ---
# Get short summary of staged files
STAGED_FILES=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
FILE_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')

if [[ $FILE_COUNT -gt 5 ]]; then
    SUMMARY="${STAGED_FILES}... (+$((FILE_COUNT - 5)) more)"
else
    SUMMARY="$STAGED_FILES"
fi

COMMIT_MSG="snap: $TAG | $SUMMARY"

# --- Commit ---
git commit -m "$COMMIT_MSG" --no-verify >/dev/null 2>&1

COMMIT_HASH=$(git rev-parse --short HEAD)
echo "COMMITTED: $COMMIT_HASH"

# --- Push (if requested) ---
if [[ $DO_PUSH -eq 1 ]]; then
    # Check if origin exists
    if git remote get-url origin >/dev/null 2>&1; then
        BRANCH=$(git branch --show-current)
        if git push origin "$BRANCH" >/dev/null 2>&1; then
            echo "PUSHED: $BRANCH"
        else
            echo "PUSH_FAILED: check remote access"
        fi
    else
        echo "PUSH_SKIPPED: no origin remote configured"
    fi
fi

exit 0
