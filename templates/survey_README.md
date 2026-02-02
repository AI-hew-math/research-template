# Paper Survey

논문 서베이 관리 디렉토리입니다.

## 구조

```
survey/
├── README.md           # 이 파일
├── papers.bib          # BibTeX 레퍼런스
├── reading_list.md     # 논문 목록 및 상태
└── notes/              # 개별 논문 노트
    ├── TEMPLATE.md     # 노트 템플릿
    └── *.md            # 논문별 노트
```

## 사용법

### 1. 논문 추가하기
```
사용자: "이 논문 reading list에 추가해줘: [arxiv 링크]"
Claude: reading_list.md에 추가
```

### 2. 논문 읽고 정리하기
```
사용자: "이 논문 읽고 정리해줘: [논문 제목]"
Claude: notes/에 논문 노트 생성, reading_list.md 상태 업데이트
```

### 3. 관련 논문 조사하기
```
사용자: "defocus depth estimation 관련 논문 조사해줘"
Claude: WebSearch로 조사 후 reading_list.md에 추가
```

## 논문 노트 명명 규칙

```
{FirstAuthor}_{Year}_{Keyword}.md

예시:
- Li_2023_DefocusNet.md
- Wang_2024_BlurDepth.md
```

## 논문 상태

| 상태 | 의미 |
|------|------|
| 📋 TODO | 읽을 예정 |
| 📖 Reading | 읽는 중 |
| ✅ Done | 완료 |
| ⭐ Key | 핵심 논문 |
| ❌ Skip | 관련성 낮음 |

## Tips

- 논문 PDF는 Zotero/Paperpile 등 별도 관리 권장
- Connected Papers로 관련 논문 탐색
- 3-pass reading: skim → detail → understand
