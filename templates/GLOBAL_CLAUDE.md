# Claude_projects 전역 설정

> 모든 프로젝트에서 Claude가 참조하는 지침입니다.

---

## 지식 베이스 구조

```
Claude_projects/
├── CLAUDE.md              ← 이 파일 (전역 지침)
├── _knowledge/
│   ├── papers/            ← 논문 노트
│   └── lessons_learned.md ← 프로젝트 간 교훈
│
├── ProjectA/
│   ├── runs/              ← Run Cards (자동)
│   ├── experiments/memos/ ← Experiment Memos
│   ├── decisions/         ← Decision Records
│   └── scripts/           ← run.sh, draft_memo.py
├── ProjectB/
└── ...
```

---

## 핵심 규칙 (4개)

### 1. 세션 시작 시

```
1. 프로젝트 EXPERIMENT_LOG.md 마지막 20줄 확인 → 최근 작업 파악
2. 프로젝트 CONCEPT.md 읽기 → 연구 목표 파악
```

### 2. 지식 저장

| 발견한 것 | 저장 위치 |
|----------|----------|
| 새 논문 | `_knowledge/papers/{Author}_{Year}_{Keyword}.md` |
| 이 프로젝트 아이디어 | `{Project}/CONCEPT.md` |
| 실험 결과 | `{Project}/runs/<RUN_ID>/run_card.md` |
| 실험 분석 | `{Project}/experiments/memos/<memo_id>.md` |
| 중요 결정 | `{Project}/decisions/DR-NNN_<title>.md` |
| 프로젝트 간 교훈 | `_knowledge/lessons_learned.md` |

### 3. 실험 전

```
1. _knowledge/lessons_learned.md 확인 (과거 실수 방지)
2. 관련 교훈 있으면 사용자에게 알리기
```

### 4. 3카드 로깅 규칙

**Run Card (FACT-ONLY)**
- 관측된 사실만 기록
- 금지: 원인 추정, 해석, "~인 것 같다"

**Experiment Memo (Observation/Inference 분리)**
- Observations: Run Card에서 추출한 사실만
- Inferences: 각 가설에 Evidence/Counter-evidence/Confidence 필수

**Decision Record (정량 기준)**
- 최소 2개 대안 비교
- 정량적 성공 기준 명시
- 롤백 계획 포함

---

## 파일 명명 규칙

```
논문: {Author}_{Year}_{Keyword}.md    예: Chen_2024_TopoLoss.md
```

---

## 확장 기준

필요할 때만 구조를 추가합니다:

| 트리거 | 액션 |
|--------|------|
| 한 주제 논문 10개+ | 해당 주제 MOC 생성 |
| 3개+ 프로젝트가 같은 기법 사용 | methods/ 폴더 생성 |

---

## 서버 정보

- soda: RTX3090, A100 (기본)
- vegi: RTX4090, A6000
- potato: A6000, RTX3090
