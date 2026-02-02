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

# 핵심 파일 복사
cp "$TEMPLATE_DIR/INDEX.md" "$KNOWLEDGE_DIR/"
cp "$TEMPLATE_DIR/lessons_learned.md" "$KNOWLEDGE_DIR/"

# 템플릿 복사 (참고용)
cp "$TEMPLATE_DIR/MOC_TEMPLATE.md" "$KNOWLEDGE_DIR/MOCs/_TEMPLATE.md"
cp "$TEMPLATE_DIR/concept_TEMPLATE.md" "$KNOWLEDGE_DIR/concepts/_TEMPLATE.md"
cp "$TEMPLATE_DIR/methods_TEMPLATE.md" "$KNOWLEDGE_DIR/methods/_TEMPLATE.md"
cp "$SCRIPT_DIR/templates/paper_note_TEMPLATE.md" "$KNOWLEDGE_DIR/papers/_TEMPLATE.md"

# README 생성
cat > "$KNOWLEDGE_DIR/README.md" << 'EOF'
# Knowledge Base

프로젝트 간 공유되는 지식 베이스입니다.

## 구조

```
_knowledge/
├── INDEX.md            ⭐ Claude가 가장 먼저 읽는 파일
├── concepts/           원자적 개념 노트
├── papers/             논문 노트
├── methods/            재사용 가능한 기법
├── MOCs/               Map of Content (주제별 가이드)
└── lessons_learned.md  축적된 교훈
```

## Claude 연동

1. Claude는 항상 INDEX.md를 먼저 읽습니다
2. INDEX.md의 키워드 매핑으로 관련 MOC를 찾습니다
3. 새 지식 저장 시 INDEX.md를 업데이트합니다

## 파일 명명 규칙

- **논문**: `{Author}_{Year}_{Keyword}.md`
- **개념**: `{concept_name}.md` (snake_case)
- **기법**: `{method_name}.md` (snake_case)
- **MOC**: `MOC_{topic}.md`
EOF

echo "✅ 지식 베이스 초기화 완료!"
echo ""
echo "구조:"
echo "  _knowledge/"
echo "  ├── INDEX.md           ⭐ 핵심 인덱스"
echo "  ├── concepts/          개념 노트"
echo "  ├── papers/            논문 노트"
echo "  ├── methods/           재사용 기법"
echo "  ├── MOCs/              주제별 가이드"
echo "  └── lessons_learned.md 교훈 기록"
echo ""
