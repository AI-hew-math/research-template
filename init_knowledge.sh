#!/bin/bash

# Knowledge base initializer
# Usage: ./init_knowledge.sh [ROOT_DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${1:-$SCRIPT_DIR/..}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
KNOWLEDGE_DIR="$ROOT_DIR/_knowledge"
TEMPLATE_DIR="$SCRIPT_DIR/templates/shared/knowledge"
PAPER_TEMPLATE="$SCRIPT_DIR/templates/shared/paper_note_TEMPLATE.md"

if [[ -d "$KNOWLEDGE_DIR" ]]; then
    echo "⚠️  _knowledge/ 폴더가 이미 존재합니다: $KNOWLEDGE_DIR"
    echo "   기존 지식 베이스를 유지합니다."
    exit 0
fi

echo "🧠 지식 베이스 초기화 중..."
echo "   위치: $KNOWLEDGE_DIR"
echo ""

mkdir -p "$KNOWLEDGE_DIR/papers"

cp "$TEMPLATE_DIR/INDEX.md" "$KNOWLEDGE_DIR/"
cp "$TEMPLATE_DIR/lessons_learned.md" "$KNOWLEDGE_DIR/"
cp "$PAPER_TEMPLATE" "$KNOWLEDGE_DIR/papers/_TEMPLATE.md"

echo "✅ 지식 베이스 초기화 완료!"
echo ""
echo "구조:"
echo "  _knowledge/"
echo "  ├── INDEX.md            안내 파일"
echo "  ├── papers/             논문 노트"
echo "  └── lessons_learned.md  프로젝트 간 교훈"
echo ""
