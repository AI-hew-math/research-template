#!/bin/bash

# v2 project generator
# Default: create a sibling research repo next to research-template

set -euo pipefail

usage() {
    cat << 'EOF'
Usage:
  ./create_project.sh [--profile research|light|archive] [--dir PARENT_DIR] "ProjectName" ["Description"]
  ./create_project.sh [--profile research|light|archive] --subproject PATH ["Description"]

Examples:
  ./create_project.sh "MyProject" "Research project"
  ./create_project.sh --profile light "ToolingRepo" "Light technical repo"
  ./create_project.sh --profile archive --dir ~/projects "OldProject" "Frozen repo"
  ./create_project.sh --subproject subprojects/ParserSpike "Nested local subproject"
  ./create_project.sh --profile research --subproject subprojects/Ablation "Nested research subproject"

Notes:
  - Default profile is `research`.
  - `--dir` is the parent directory for a top-level project.
  - `--subproject` is the exact nested target path to create.
EOF
}

abspath() {
    python3 - "$1" << 'PY'
import os
import sys
print(os.path.abspath(sys.argv[1]))
PY
}

relpath() {
    python3 - "$1" "$2" << 'PY'
import os
import sys
print(os.path.relpath(sys.argv[2], sys.argv[1]))
PY
}

escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

find_existing_knowledge_dir() {
    local current="$1"
    while [[ -n "$current" && -d "$current" ]]; do
        if [[ -d "$current/_knowledge" ]]; then
            echo "$current/_knowledge"
            return 0
        fi

        local parent
        parent="$(dirname "$current")"
        if [[ "$parent" == "$current" ]]; then
            break
        fi
        current="$parent"
    done
    return 1
}

render_template() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"
    sed \
        -e "s|{{PROJECT_NAME}}|$(escape_sed "$PROJECT_NAME")|g" \
        -e "s|{{DESCRIPTION}}|$(escape_sed "$DESCRIPTION")|g" \
        -e "s|{{DATE}}|$(escape_sed "$DATE")|g" \
        -e "s|{{KNOWLEDGE_PATH}}|$(escape_sed "$KNOWLEDGE_PATH")|g" \
        "$src" > "$dst"
}

copy_raw_file() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

copy_tree_contents() {
    local src="$1"
    local dst="$2"
    mkdir -p "$dst"
    cp -R "$src"/. "$dst"/
}

write_gitignore() {
    local dst="$1"

    if [[ "$PROFILE" == "research" ]]; then
        cat > "$dst" << 'EOF'
__pycache__/
*.py[cod]
*.egg-info/
.ipynb_checkpoints/
*.pt
*.pth
data/
*.tar.gz
*.zip
.vscode/
.idea/
.DS_Store
.env
wandb/

# Legacy run outputs (keep run_card.md, ignore raw logs)
runs/*/stdout.log
runs/*/stderr.log
runs/*/env.txt
runs/*/nvidia-smi.txt

# Agent local state
.claude/state/

# Legacy review automation cache (canonical tracked docs live under reviews/cycles/)
review_cycles/**
!review_cycles/.gitkeep
!review_cycles/README.md

# Checkpoints
checkpoints/
*.ckpt
EOF
    else
        cat > "$dst" << 'EOF'
__pycache__/
*.py[cod]
*.egg-info/
.ipynb_checkpoints/
*.tar.gz
*.zip
.vscode/
.idea/
.DS_Store
.env

# Agent local state
.claude/state/
EOF
    fi
}

copy_research_support_assets() {
    mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/runs" "$TARGET_DIR/experiments/memos" "$TARGET_DIR/review_cycles" "$TARGET_DIR/src"

    if [[ -d "$TEMPLATE_DIR/scripts" ]]; then
        cp "$TEMPLATE_DIR/scripts/README.md" "$TARGET_DIR/scripts/" 2>/dev/null || true
        cp "$TEMPLATE_DIR/scripts/run.sh" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/run.sh"
        cp "$TEMPLATE_DIR/scripts/draft_memo.py" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/draft_memo.py"
        cp "$TEMPLATE_DIR/scripts/bootstrap_logging.sh" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/bootstrap_logging.sh"
        cp "$TEMPLATE_DIR/scripts/git_snap.sh" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/git_snap.sh"
        cp "$TEMPLATE_DIR/scripts/save_clipboard_to_gpt_review.sh" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/save_clipboard_to_gpt_review.sh"
        cp "$TEMPLATE_DIR/scripts/save_clipboard_to_next_prompt.sh" "$TARGET_DIR/scripts/" 2>/dev/null && chmod +x "$TARGET_DIR/scripts/save_clipboard_to_next_prompt.sh"
    fi

    if [[ -d "$TEMPLATE_DIR/.claude" ]]; then
        cp -R "$TEMPLATE_DIR/.claude" "$TARGET_DIR/.claude"
        if [[ -d "$TARGET_DIR/.claude/hooks" ]]; then
            chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
        fi
    fi

    render_template "$SHARED_DIR/compat/review_cycles/README.md" "$TARGET_DIR/review_cycles/README.md"
    render_template "$SHARED_DIR/compat/experiments/memos/README.md" "$TARGET_DIR/experiments/memos/README.md"
    touch "$TARGET_DIR/review_cycles/.gitkeep"
    touch "$TARGET_DIR/src/__init__.py"
}

copy_light_support_assets() {
    mkdir -p "$TARGET_DIR/src"
    touch "$TARGET_DIR/src/__init__.py"
}

copy_shared_review_assets() {
    render_template "$SHARED_DIR/reviews/README.md" "$TARGET_DIR/reviews/README.md"
    mkdir -p "$TARGET_DIR/reviews/cycles/CYCLE_TEMPLATE"
    copy_raw_file "$SHARED_DIR/reviews/cycles/REVIEW_PACKET.md" "$TARGET_DIR/reviews/cycles/CYCLE_TEMPLATE/REVIEW_PACKET.md"
    copy_raw_file "$SHARED_DIR/reviews/cycles/GPT_REVIEW.md" "$TARGET_DIR/reviews/cycles/CYCLE_TEMPLATE/GPT_REVIEW.md"
    copy_raw_file "$SHARED_DIR/reviews/cycles/NEXT_PROMPT.md" "$TARGET_DIR/reviews/cycles/CYCLE_TEMPLATE/NEXT_PROMPT.md"
}

copy_shared_skill_assets() {
    copy_tree_contents "$SHARED_DIR/skills" "$TARGET_DIR/.codex/skills"
}

PROFILE="research"
TARGET_PARENT=""
SUBPROJECT_PATH=""

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --dir)
            TARGET_PARENT="${2:-}"
            shift 2
            ;;
        --subproject)
            SUBPROJECT_PATH="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

while [[ $# -gt 0 ]]; do
    POSITIONAL+=("$1")
    shift
done

case "$PROFILE" in
    research|light|archive) ;;
    *)
        echo "Error: Unsupported profile '$PROFILE'" >&2
        usage >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
BASE_DIR="$TEMPLATE_DIR/base"
PROFILES_DIR="$TEMPLATE_DIR/profiles"
SHARED_DIR="$TEMPLATE_DIR/shared"
DEFAULT_PROJECTS_DIR="$SCRIPT_DIR/.."
DATE="$(date +%Y-%m-%d)"
IS_SUBPROJECT=0

if [[ -n "$SUBPROJECT_PATH" && -n "$TARGET_PARENT" ]]; then
    echo "Error: --dir and --subproject cannot be used together" >&2
    exit 1
fi

if [[ -n "$SUBPROJECT_PATH" ]]; then
    IS_SUBPROJECT=1
    TARGET_DIR="$(abspath "$SUBPROJECT_PATH")"
    PROJECT_NAME="$(basename "$TARGET_DIR")"
    DESCRIPTION="${POSITIONAL[0]:-Nested local subproject}"
else
    PROJECT_NAME="${POSITIONAL[0]:-}"
    DESCRIPTION="${POSITIONAL[1]:-}"

    if [[ -z "$PROJECT_NAME" ]]; then
        usage >&2
        exit 1
    fi

    if [[ -n "$TARGET_PARENT" ]]; then
        TARGET_PARENT="$(abspath "$TARGET_PARENT")"
    else
        TARGET_PARENT="$(abspath "$DEFAULT_PROJECTS_DIR")"
    fi

    TARGET_DIR="$TARGET_PARENT/$PROJECT_NAME"
fi

if [[ -d "$TARGET_DIR" ]]; then
    echo "Error: Target already exists: $TARGET_DIR" >&2
    exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"

KNOWLEDGE_PATH="../_knowledge"
if [[ "$PROFILE" == "research" ]]; then
    if [[ "$IS_SUBPROJECT" -eq 1 ]]; then
        EXISTING_KNOWLEDGE_DIR="$(find_existing_knowledge_dir "$(dirname "$TARGET_DIR")" || true)"
        if [[ -n "${EXISTING_KNOWLEDGE_DIR:-}" ]]; then
            KNOWLEDGE_PATH="$(relpath "$TARGET_DIR" "$EXISTING_KNOWLEDGE_DIR")"
        fi
    else
        KNOWLEDGE_ROOT="$(dirname "$TARGET_DIR")"
        KNOWLEDGE_DIR="$KNOWLEDGE_ROOT/_knowledge"
        if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
            echo "⚠️  _knowledge/ 폴더가 없습니다. 먼저 초기화합니다..."
            echo ""
            "$SCRIPT_DIR/init_knowledge.sh" "$KNOWLEDGE_ROOT"
            echo ""
        fi
        KNOWLEDGE_PATH="$(relpath "$TARGET_DIR" "$KNOWLEDGE_DIR")"
    fi
fi

echo "📁 프로젝트 생성 중: $PROJECT_NAME"
echo "   프로필: $PROFILE"
echo "   위치: $TARGET_DIR"
if [[ -n "$DESCRIPTION" ]]; then
    echo "   설명: $DESCRIPTION"
fi
if [[ "$IS_SUBPROJECT" -eq 1 ]]; then
    echo "   모드: nested subproject"
fi
echo ""

mkdir -p "$TARGET_DIR"

# Base files are always rendered
render_template "$BASE_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
render_template "$BASE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
render_template "$BASE_DIR/MEMORY.md" "$TARGET_DIR/MEMORY.md"
render_template "$BASE_DIR/README.md" "$TARGET_DIR/README.md"

# Shared review docs and repo-local skills are always scaffolded
copy_shared_review_assets
copy_shared_skill_assets

case "$PROFILE" in
    research)
        render_template "$PROFILES_DIR/research/CONCEPT.md" "$TARGET_DIR/CONCEPT.md"
        render_template "$PROFILES_DIR/research/EXPERIMENT_LOG.md" "$TARGET_DIR/EXPERIMENT_LOG.md"
        copy_raw_file "$PROFILES_DIR/research/decisions/DECISION_RECORD.md" "$TARGET_DIR/decisions/DECISION_RECORD.md"
        copy_raw_file "$PROFILES_DIR/research/history/experiments/EXPERIMENT_DETAIL.md" "$TARGET_DIR/history/experiments/EXPERIMENT_DETAIL.md"
        copy_raw_file "$PROFILES_DIR/research/history/phases/PHASE_DETAIL.md" "$TARGET_DIR/history/phases/PHASE_DETAIL.md"
        copy_research_support_assets
        ;;
    light)
        copy_light_support_assets
        ;;
    archive)
        render_template "$PROFILES_DIR/archive/ARCHIVE.md" "$TARGET_DIR/ARCHIVE.md"
        ;;
esac

write_gitignore "$TARGET_DIR/.gitignore"

echo "✅ 프로젝트 생성 완료!"
echo ""
echo "구조:"
echo "  $TARGET_DIR/"
echo "  ├── AGENTS.md          # canonical instructions"
echo "  ├── CLAUDE.md          # thin wrapper"
echo "  ├── MEMORY.md          # current state"
echo "  ├── README.md          # project orientation"
echo "  ├── reviews/README.md  # canonical review-loop guide"
echo "  ├── reviews/cycles/CYCLE_TEMPLATE/"
echo "  └── .codex/skills/     # reusable local workflow skills"

if [[ "$PROFILE" == "research" ]]; then
    echo "  ├── CONCEPT.md         # durable research brief"
    echo "  ├── EXPERIMENT_LOG.md  # concise experiment ledger"
    echo "  ├── history/           # detailed experiment/phase history"
    echo "  ├── decisions/         # decision templates"
    echo "  ├── scripts/           # legacy helper bundle (compatibility)"
    echo "  ├── .claude/           # legacy hook bundle (compatibility)"
    echo "  ├── review_cycles/     # deprecated compatibility cache"
    echo "  └── experiments/memos/ # deprecated memo area"
elif [[ "$PROFILE" == "archive" ]]; then
    echo "  ├── ARCHIVE.md         # frozen repo contract"
    echo "  └── src/               # add only if you intentionally reopen"
else
    echo "  └── src/               # lightweight code area"
fi

echo ""
echo "다음 단계:"
echo "  cd \"$TARGET_DIR\""
echo "  claude"
echo "  cp -R reviews/cycles/CYCLE_TEMPLATE reviews/cycles/CYCLE-0001"
if [[ "$PROFILE" == "research" ]]; then
    echo "  ./scripts/run.sh --exp baseline python train.py    # compatibility helper"
fi

if [[ "$PROFILE" == "research" && "$IS_SUBPROJECT" -eq 1 && "$KNOWLEDGE_PATH" == "../_knowledge" ]]; then
    echo ""
    echo "참고:"
    echo "  nested subproject라서 _knowledge 경로는 기본값($KNOWLEDGE_PATH)으로 남겨두었습니다."
    echo "  필요하면 로컬 AGENTS.md에서 shared knowledge 경로를 조정하세요."
fi
