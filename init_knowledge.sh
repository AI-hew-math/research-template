#!/bin/bash

# Knowledge Base 초기화 스크립트
# 처음 한 번만 실행
# Usage: ./init_knowledge.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/.."
KNOWLEDGE_DIR="$PROJECTS_DIR/_knowledge"
TEMPLATE_DIR="$SCRIPT_DIR/templates/knowledge"

if [ -d "$KNOWLEDGE_DIR" ]; then
    echo "⚠️  _knowledge/ 폴더가 이미 존재합니다: $KNOWLEDGE_DIR"
    echo "   기존 지식 베이스를 유지합니다."
    exit 0
fi

echo "🧠 지식 베이스 초기화 중..."
echo "   위치: $KNOWLEDGE_DIR"
echo ""

# 디렉토리 생성
mkdir -p "$KNOWLEDGE_DIR/papers"

# 핵심 파일 복사
cp "$TEMPLATE_DIR/INDEX.md" "$KNOWLEDGE_DIR/"
cp "$TEMPLATE_DIR/lessons_learned.md" "$KNOWLEDGE_DIR/"

# 논문 템플릿 복사
cp "$SCRIPT_DIR/templates/paper_note_TEMPLATE.md" "$KNOWLEDGE_DIR/papers/_TEMPLATE.md"

echo "✅ 지식 베이스 초기화 완료!"
echo ""
echo "구조:"
echo "  _knowledge/"
echo "  ├── INDEX.md            안내 파일"
echo "  ├── papers/             논문 노트"
echo "  └── lessons_learned.md  프로젝트 간 교훈"
echo ""
