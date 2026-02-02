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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# Create project in Claude_projects directory (parent of research-template)
PROJECT_DIR="$SCRIPT_DIR/../$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' already exists!"
    exit 1
fi

echo "Creating research project: $PROJECT_NAME"
echo "Description: $DESCRIPTION"
echo "Location: $PROJECT_DIR"
echo ""

# Create directory structure
mkdir -p "$PROJECT_DIR"/{survey/notes,experiments/{configs,scripts},src/{data,models,training,evaluation},notebooks,results/{checkpoints,figures,tables},docs}

# Function to replace placeholders
replace_placeholders() {
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
        -e "s/{{DATE}}/$DATE/g" \
        "$1"
}

# Copy main templates to root
replace_placeholders "$TEMPLATE_DIR/CLAUDE.md" > "$PROJECT_DIR/CLAUDE.md"
replace_placeholders "$TEMPLATE_DIR/CONCEPT.md" > "$PROJECT_DIR/CONCEPT.md"
replace_placeholders "$TEMPLATE_DIR/EXPERIMENT_LOG.md" > "$PROJECT_DIR/EXPERIMENT_LOG.md"
replace_placeholders "$TEMPLATE_DIR/README.md" > "$PROJECT_DIR/README.md"

# Copy survey templates
replace_placeholders "$TEMPLATE_DIR/survey_README.md" > "$PROJECT_DIR/survey/README.md"
replace_placeholders "$TEMPLATE_DIR/reading_list.md" > "$PROJECT_DIR/survey/reading_list.md"
replace_placeholders "$TEMPLATE_DIR/paper_note_TEMPLATE.md" > "$PROJECT_DIR/survey/notes/TEMPLATE.md"

# Copy other templates
replace_placeholders "$TEMPLATE_DIR/experiments_README.md" > "$PROJECT_DIR/experiments/README.md"
replace_placeholders "$TEMPLATE_DIR/notebooks_README.md" > "$PROJECT_DIR/notebooks/README.md"
replace_placeholders "$TEMPLATE_DIR/docs_workflow.md" > "$PROJECT_DIR/docs/workflow.md"

# Create empty files
touch "$PROJECT_DIR/survey/papers.bib"
touch "$PROJECT_DIR/src/__init__.py"
touch "$PROJECT_DIR/src/data/__init__.py"
touch "$PROJECT_DIR/src/models/__init__.py"
touch "$PROJECT_DIR/src/training/__init__.py"
touch "$PROJECT_DIR/src/evaluation/__init__.py"

# Create .gitignore
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.eggs/
dist/
build/

# Jupyter
.ipynb_checkpoints/

# Results (large files)
results/checkpoints/*.pt
results/checkpoints/*.pth
results/checkpoints/*.ckpt

# Data
data/
*.tar.gz
*.zip

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Environment
.env
*.log

# W&B
wandb/
EOF

echo ""
echo "✅ Project created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Next: cd ../$PROJECT_NAME && claude"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Then just talk to Claude:"
echo "  \"연구 시작하자\""
echo "  \"관련 논문 조사해줘\""
echo "  \"이 논문 정리해줘: [link]\""
echo ""
