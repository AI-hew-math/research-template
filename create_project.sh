#!/bin/bash

# Claude Research Project Generator
# Usage: ./create_project.sh "ProjectName" "One-line description"

PROJECT_NAME=$1
DESCRIPTION=$2
DATE=$(date +%Y-%m-%d)

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./create_project.sh \"ProjectName\" \"Description\""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
PROJECTS_DIR="$SCRIPT_DIR/.."
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
KNOWLEDGE_DIR="$PROJECTS_DIR/_knowledge"

# _knowledge 폴더 확인
if [ ! -d "$KNOWLEDGE_DIR" ]; then
    echo "⚠️  _knowledge/ 폴더가 없습니다. 먼저 초기화합니다..."
    echo ""
    "$SCRIPT_DIR/init_knowledge.sh"
    echo ""
fi

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' already exists!"
    exit 1
fi

echo "📁 프로젝트 생성 중: $PROJECT_NAME"
echo "   설명: $DESCRIPTION"
echo ""

# 디렉토리 생성 (기존 + 3카드 로깅 + review_cycles)
mkdir -p "$PROJECT_DIR"/{src,experiments/memos,runs,decisions,scripts,review_cycles}

# 플레이스홀더 치환 함수
replace_placeholders() {
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
        -e "s/{{DATE}}/$DATE/g" \
        "$1"
}

# 핵심 템플릿 복사
replace_placeholders "$TEMPLATE_DIR/CLAUDE.md" > "$PROJECT_DIR/CLAUDE.md"
replace_placeholders "$TEMPLATE_DIR/CONCEPT.md" > "$PROJECT_DIR/CONCEPT.md"
replace_placeholders "$TEMPLATE_DIR/EXPERIMENT_LOG.md" > "$PROJECT_DIR/EXPERIMENT_LOG.md"
replace_placeholders "$TEMPLATE_DIR/README.md" > "$PROJECT_DIR/README.md"

# 3카드 로깅 문서 복사
if [ -f "$TEMPLATE_DIR/LOGGING_README.md" ]; then
    cp "$TEMPLATE_DIR/LOGGING_README.md" "$PROJECT_DIR/LOGGING.md"
fi

# 스크립트 복사
if [ -d "$TEMPLATE_DIR/scripts" ]; then
    cp "$TEMPLATE_DIR/scripts/run.sh" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/run.sh"
    cp "$TEMPLATE_DIR/scripts/draft_memo.py" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/draft_memo.py"
    cp "$TEMPLATE_DIR/scripts/bootstrap_logging.sh" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/bootstrap_logging.sh"
    cp "$TEMPLATE_DIR/scripts/git_snap.sh" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/git_snap.sh"
    cp "$TEMPLATE_DIR/scripts/save_clipboard_to_gpt_review.sh" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/save_clipboard_to_gpt_review.sh"
    cp "$TEMPLATE_DIR/scripts/save_clipboard_to_next_prompt.sh" "$PROJECT_DIR/scripts/" 2>/dev/null && chmod +x "$PROJECT_DIR/scripts/save_clipboard_to_next_prompt.sh"
fi

# .claude/ 폴더 복사 (Claude Code hooks)
if [ -d "$TEMPLATE_DIR/.claude" ]; then
    cp -R "$TEMPLATE_DIR/.claude" "$PROJECT_DIR/.claude"
    # hooks 실행 권한 보장
    if [ -d "$PROJECT_DIR/.claude/hooks" ]; then
        chmod +x "$PROJECT_DIR/.claude/hooks/"*.sh 2>/dev/null || true
    fi
fi

# review_cycles/.gitkeep
touch "$PROJECT_DIR/review_cycles/.gitkeep"

# Python 패키지 초기화
touch "$PROJECT_DIR/src/__init__.py"

# .gitignore
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
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

# Logs (keep run cards, ignore raw logs)
runs/*/stdout.log
runs/*/stderr.log
runs/*/env.txt
runs/*/nvidia-smi.txt

# Claude Code state (local only)
.claude/state/

# Review cycles - ignore all contents, keep structure
review_cycles/**
!review_cycles/.gitkeep

# Checkpoints
checkpoints/
*.ckpt
EOF

echo "✅ 프로젝트 생성 완료!"
echo ""
echo "구조:"
echo "  $PROJECT_NAME/"
echo "  ├── CLAUDE.md          # Claude 지침"
echo "  ├── CONCEPT.md         # 연구 아이디어"
echo "  ├── EXPERIMENT_LOG.md  # 실험 기록 (레거시)"
echo "  ├── LOGGING.md         # 3카드 로깅 가이드"
echo "  ├── .claude/           # Claude Code hooks"
echo "  ├── src/               # 코드"
echo "  ├── experiments/memos/ # Experiment Memos"
echo "  ├── runs/              # Run Cards (자동 생성)"
echo "  ├── decisions/         # Decision Records"
echo "  ├── review_cycles/     # GPT 검토 사이클"
echo "  └── scripts/           # run.sh, draft_memo.py 등"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  다음 단계:"
echo ""
echo "  cd ../$PROJECT_NAME && claude"
echo ""
echo "  실험 실행:"
echo "  ./scripts/run.sh --exp baseline python train.py"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
