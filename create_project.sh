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

# 디렉토리 생성
mkdir -p "$PROJECT_DIR"/{experiments/{configs,scripts},src/{data,models,training,evaluation},notebooks,results/{checkpoints,figures,tables},docs}

# 플레이스홀더 치환 함수
replace_placeholders() {
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
        -e "s/{{DATE}}/$DATE/g" \
        "$1"
}

# 메인 템플릿 복사
replace_placeholders "$TEMPLATE_DIR/CLAUDE.md" > "$PROJECT_DIR/CLAUDE.md"
replace_placeholders "$TEMPLATE_DIR/CONCEPT.md" > "$PROJECT_DIR/CONCEPT.md"
replace_placeholders "$TEMPLATE_DIR/EXPERIMENT_LOG.md" > "$PROJECT_DIR/EXPERIMENT_LOG.md"
replace_placeholders "$TEMPLATE_DIR/README.md" > "$PROJECT_DIR/README.md"

# 하위 폴더 템플릿
replace_placeholders "$TEMPLATE_DIR/experiments_README.md" > "$PROJECT_DIR/experiments/README.md"
replace_placeholders "$TEMPLATE_DIR/notebooks_README.md" > "$PROJECT_DIR/notebooks/README.md"

# Python 패키지 초기화
touch "$PROJECT_DIR/src/__init__.py"
touch "$PROJECT_DIR/src/data/__init__.py"
touch "$PROJECT_DIR/src/models/__init__.py"
touch "$PROJECT_DIR/src/training/__init__.py"
touch "$PROJECT_DIR/src/evaluation/__init__.py"

# .gitignore
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
__pycache__/
*.py[cod]
*.egg-info/
.ipynb_checkpoints/
results/checkpoints/*.pt
results/checkpoints/*.pth
data/
*.tar.gz
*.zip
.vscode/
.idea/
.DS_Store
.env
*.log
wandb/
EOF

echo "✅ 프로젝트 생성 완료!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  다음 단계:"
echo ""
echo "  cd ../$PROJECT_NAME && claude"
echo ""
echo "  그리고 말하세요: \"연구 시작하자\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
