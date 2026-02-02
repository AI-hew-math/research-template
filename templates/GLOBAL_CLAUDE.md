# Claude_projects 전역 설정

> 이 파일은 `Claude_projects/CLAUDE.md`에 위치합니다.
> 모든 하위 프로젝트에서 Claude가 참조합니다.

---

## 지식 베이스 구조

```
Claude_projects/
├── CLAUDE.md              ← 이 파일 (전역 지침)
├── _knowledge/            ← 공유 지식 베이스
│   ├── concepts/          # 원자적 개념 노트
│   ├── papers/            # 논문 노트
│   ├── methods/           # 재사용 기법
│   ├── MOCs/              # 주제별 가이드
│   └── lessons_learned.md # 축적된 교훈
│
├── ProjectA/              ← 개별 프로젝트들
├── ProjectB/
└── ...
```

---

## Claude 필수 행동 규칙

### 규칙 1: 새 주제 작업 전 MOC 확인

**어떤 주제든 작업 시작 전에:**
```
1. _knowledge/MOCs/ 에서 관련 MOC 파일 검색
2. MOC가 있으면 먼저 읽고 관련 자료 파악
3. MOC가 없으면 작업 후 생성
```

예시:
- "topology loss" 관련 작업 → `_knowledge/MOCs/MOC_topology.md` 먼저 읽기
- "depth estimation" 작업 → `_knowledge/MOCs/MOC_depth.md` 먼저 읽기

### 규칙 2: 새로운 지식 발견 시 저장

**논문 발견/분석 시:**
```
→ _knowledge/papers/{저자}_{연도}_{키워드}.md 에 저장
→ 관련 MOC에 링크 추가
```

**새 개념 정리 시:**
```
→ _knowledge/concepts/{개념명}.md 에 저장
→ 관련 MOC에 링크 추가
```

**재사용 가능한 기법 발견 시:**
```
→ _knowledge/methods/{기법명}.md 에 저장
```

### 규칙 3: 실패/성공 경험 기록

**실험에서 중요한 교훈 발견 시:**
```
→ _knowledge/lessons_learned.md 에 추가
→ 형식: [프로젝트] 날짜: 교훈 내용
```

### 규칙 4: 프로젝트 간 연결 인식

**현재 프로젝트와 관련된 다른 프로젝트가 있는지 항상 확인:**
```
→ _knowledge/MOCs/ 에서 관련 프로젝트 확인
→ 관련 프로젝트의 EXPERIMENT_LOG.md 참조 가능
```

---

## MOC (Map of Content) 활용법

### MOC란?
특정 주제에 대한 "목차" 역할. 관련된 모든 개념, 논문, 프로젝트를 링크.

### MOC 읽는 시점
- 새 프로젝트 시작 시
- 특정 주제 질문받았을 때
- 논문 서베이 시작 시

### MOC 업데이트 시점
- 새 논문 추가 시
- 새 개념 정리 시
- 프로젝트에서 관련 실험 완료 시

---

## 파일 명명 규칙

### 논문 노트
```
_knowledge/papers/{FirstAuthor}_{Year}_{Keyword}.md

예: Chen_2024_TopoLoss.md
    Wang_2023_DepthFromDefocus.md
```

### 개념 노트
```
_knowledge/concepts/{concept_name}.md

예: persistent_homology.md
    betti_numbers.md
    depth_from_defocus.md
```

### MOC
```
_knowledge/MOCs/MOC_{topic}.md

예: MOC_topology.md
    MOC_depth_estimation.md
    MOC_segmentation.md
```

---

## 노트 작성 형식

### 논문 노트 형식
```markdown
---
tags: [주제1, 주제2, 방법론]
related_projects: [ProjectA, ProjectB]
status: read | skimmed | to-read
importance: key | relevant | background
---

# 논문 제목

## TL;DR
한 문장 요약

## 핵심 아이디어
1.
2.

## 우리 연구와의 관련성
- 어떻게 활용 가능한지

## BibTeX
```

### 개념 노트 형식
```markdown
---
tags: [분야]
related: [[개념1]], [[개념2]]
---

# 개념명

## 정의
한 문장 정의

## 핵심 내용
- 자기완결적으로 설명

## 관련 논문
- [[논문1]]
- [[논문2]]

## 사용된 프로젝트
- [[ProjectA]]
```

---

## 세션 시작 시 Claude 체크리스트

새 세션이 시작되면:

1. [ ] 현재 위치 확인 (어느 프로젝트인지)
2. [ ] 해당 프로젝트 CLAUDE.md 읽기
3. [ ] 사용자 요청의 주제 파악
4. [ ] 관련 MOC가 있으면 읽기 (`_knowledge/MOCs/`)
5. [ ] 필요시 관련 concepts, papers 참조
6. [ ] 작업 완료 후 지식 베이스 업데이트

---

## 서버 환경

(기존 서버 설정 - soda, vegi, potato 등)

