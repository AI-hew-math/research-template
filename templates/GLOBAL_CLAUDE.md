# Claude_projects 전역 설정

> 이 파일은 `Claude_projects/CLAUDE.md`에 위치합니다.
> 모든 하위 프로젝트에서 Claude가 참조합니다.

---

## 지식 베이스 구조

```
Claude_projects/
├── CLAUDE.md              ← 이 파일 (전역 지침)
├── _knowledge/
│   ├── INDEX.md           ← ⭐ 핵심: 항상 먼저 읽기
│   ├── concepts/
│   ├── papers/
│   ├── methods/
│   ├── MOCs/
│   └── lessons_learned.md
│
├── ProjectA/
├── ProjectB/
└── ...
```

---

## 🔴 필수 행동 규칙

### 규칙 0: INDEX.md 우선 (가장 중요)

**트리거**: 연구 관련 작업 시작 시

**행동** (순서대로 실행):
```
1. _knowledge/INDEX.md 읽기 (필수, 생략 불가)
2. 사용자 요청에서 주제 키워드 추출
3. INDEX.md "키워드 → MOC 매핑"에서 검색
4. 결과를 사용자에게 반드시 알리기:
   - 매칭됨: "기존에 [주제] 관련 자료가 있습니다: 논문 N개, 프로젝트 M개"
   - 매칭 안 됨: "새로운 주제입니다. 조사를 시작할까요?"
5. 매칭된 MOC가 있으면 읽기
```

**금지**: INDEX.md를 읽지 않고 바로 작업 시작

---

### 규칙 1: 지식 저장 위치

| 발견한 것 | 저장 위치 | INDEX.md 업데이트 |
|----------|----------|-------------------|
| 새 논문 | `_knowledge/papers/{Author}_{Year}_{Keyword}.md` | "최근 업데이트"에 추가 |
| 새 개념 | `_knowledge/concepts/{name}.md` | "최근 업데이트"에 추가 |
| 새 기법 | `_knowledge/methods/{name}.md` | "최근 업데이트"에 추가 |
| 새 MOC | `_knowledge/MOCs/MOC_{topic}.md` | "키워드 → MOC 매핑"에 추가 |
| 실험 교훈 | `_knowledge/lessons_learned.md` | - |
| 프로젝트 실험 | `{Project}/EXPERIMENT_LOG.md` | - |

---

### 규칙 2: MOC 생성 기준

**새 MOC 생성 조건** (하나라도 해당 시):
- 해당 주제 논문이 2개 이상 저장될 때
- 새 프로젝트가 해당 주제를 다룰 때
- 사용자가 명시적으로 요청할 때

**MOC 생성 시 필수 작업**:
1. `_knowledge/MOCs/MOC_{topic}.md` 생성
2. INDEX.md "키워드 → MOC 매핑"에 추가 (동의어 포함)
3. INDEX.md "통계" 업데이트

**MOC 주제 결정 기준**:
```
논문/지식이 여러 주제에 걸칠 때:

1. "핵심 기여"가 무엇인가?
   예: "Topology-aware loss for segmentation"
   → 핵심 기여: topology 기반 loss 제안
   → 주 MOC: MOC_topology
   → 부 MOC: MOC_segmentation (참조만)

2. 주 MOC vs 부 MOC:
   - 주 MOC: 논문의 핵심 기여가 해당 주제
   - 부 MOC: 응용/적용 분야

3. 논문 노트에 tags로 모든 관련 주제 표시:
   tags: [topology, segmentation, loss]

4. 주 MOC에 상세 기록, 부 MOC에는 링크만:
   MOC_topology.md: 상세 설명 + 링크
   MOC_segmentation.md: "topology 응용" 섹션에 링크만
```

**MOC 네이밍 기준**:
```
방법론 중심: MOC_topology, MOC_attention, MOC_contrastive_learning
태스크 중심: MOC_segmentation, MOC_depth_estimation
도메인 중심: MOC_medical_imaging, MOC_autonomous_driving

→ 방법론 > 태스크 > 도메인 순으로 우선
→ 예: "Medical image segmentation with topology"
   → 주 MOC: MOC_topology (방법론)
```

---

### 규칙 3: 프로젝트 CONCEPT.md vs _knowledge/concepts/ 구분

| 위치 | 내용 | 예시 |
|------|------|------|
| `{Project}/CONCEPT.md` | **이 프로젝트만의** 구체적 아이디어, 가설, 실험 계획 | "blur kernel 크기와 depth의 비선형 관계를 MLP로 학습" |
| `_knowledge/concepts/` | **프로젝트 무관한** 일반 개념 정의 | "Depth from Defocus의 광학 원리" |

**판단 기준**: "다른 프로젝트에서도 참조할 수 있나?"
- Yes → `_knowledge/concepts/`
- No → `{Project}/CONCEPT.md`

---

### 규칙 4: 실험 전 교훈 확인

**트리거**: 실험 설계/제출 전

**행동**:
```
1. _knowledge/lessons_learned.md 읽기
2. 현재 실험과 관련된 과거 교훈 확인
3. 관련 교훈 있으면 사용자에게 알리기:
   "과거 [프로젝트]에서 [교훈]이 있었습니다. 참고하시겠어요?"
```

---

### 규칙 5: 작업 완료 후 INDEX.md 업데이트

**트리거**: 논문/개념/기법/MOC 저장 후

**행동**:
```
1. INDEX.md "최근 업데이트" 섹션에 추가
2. 필요시 "키워드 → MOC 매핑" 업데이트
3. "통계" 숫자 업데이트
```

---

## 파일 명명 규칙

```
논문:  {FirstAuthor}_{Year}_{Keyword}.md    예: Chen_2024_TopoLoss.md
개념:  {concept_name}.md (snake_case)        예: persistent_homology.md
기법:  {method_name}.md (snake_case)         예: erosion_dilation.md
MOC:   MOC_{topic}.md                        예: MOC_topology.md
```

---

## 노트 작성 형식

### 논문 노트
```markdown
---
tags: [주제1, 주제2]
related_projects: [ProjectA]
status: read | skimmed | to-read
importance: key | relevant | background
---

# 논문 제목

## TL;DR
한 문장 요약

## 핵심 아이디어
1. ...

## 우리 연구와의 관련성
- ...
```

### 개념 노트
```markdown
---
tags: [분야]
related: [[개념1]], [[개념2]]
---

# 개념명

## 정의
한 문장 정의 (자기완결적)

## 핵심 내용
- ...

## 관련 논문
- [[Author_Year_Paper]]

## 사용된 프로젝트
- [[ProjectName]]
```

---

## 서버 환경

### 동기화 전략
- `_knowledge/`: 맥북에만 유지 (서버 동기화 안 함)
- 개별 프로젝트: 서버에 동기화 (`sync_to soda`)
- 실험 중 지식 필요 시: 맥북에서 Claude에게 질문

### 서버 정보
- soda: RTX3090, A100 (기본)
- vegi: RTX4090, A6000
- potato: A6000, RTX3090
