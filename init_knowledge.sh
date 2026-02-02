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
mkdir -p "$KNOWLEDGE_DIR"/{concepts,papers,methods,MOCs}

# 템플릿 복사
cp "$TEMPLATE_DIR/lessons_learned.md" "$KNOWLEDGE_DIR/"
cp "$TEMPLATE_DIR/MOC_TEMPLATE.md" "$KNOWLEDGE_DIR/MOCs/"
cp "$TEMPLATE_DIR/concept_TEMPLATE.md" "$KNOWLEDGE_DIR/concepts/"
cp "$TEMPLATE_DIR/methods_TEMPLATE.md" "$KNOWLEDGE_DIR/methods/"

# 논문 노트 템플릿 복사
cp "$SCRIPT_DIR/templates/paper_note_TEMPLATE.md" "$KNOWLEDGE_DIR/papers/TEMPLATE.md"

# README 생성
cat > "$KNOWLEDGE_DIR/README.md" << 'EOF'
# Knowledge Base

프로젝트 간 공유되는 지식 베이스입니다.

## 구조

```
_knowledge/
├── concepts/           # 원자적 개념 노트
├── papers/             # 논문 노트
├── methods/            # 재사용 가능한 기법
├── MOCs/               # Map of Content (주제별 가이드)
└── lessons_learned.md  # 축적된 교훈
```

## 파일 명명 규칙

- **논문**: `{Author}_{Year}_{Keyword}.md`
- **개념**: `{concept_name}.md` (snake_case)
- **기법**: `{method_name}.md` (snake_case)
- **MOC**: `MOC_{topic}.md`

## Claude 연동

- 각 프로젝트의 CLAUDE.md가 이 폴더를 참조합니다
- Claude가 새 지식 발견 시 자동으로 여기에 저장합니다
- 프로젝트 작업 전 관련 MOC를 먼저 확인합니다
EOF

echo "✅ 지식 베이스 초기화 완료!"
echo ""
echo "구조:"
echo "  _knowledge/"
echo "  ├── concepts/    # 개념 노트"
echo "  ├── papers/      # 논문 노트"
echo "  ├── methods/     # 재사용 기법"
echo "  ├── MOCs/        # 주제별 가이드"
echo "  └── lessons_learned.md"
echo ""
