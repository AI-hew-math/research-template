# {{PROJECT_NAME}}

> {{DESCRIPTION}}
> 시작일: {{DATE}}

---

## 세션 시작 시

```
1. EXPERIMENT_LOG.md 마지막 20줄 확인 → 최근 작업 파악
2. CONCEPT.md 읽기 → 연구 목표 파악
3. 실험 예정이면 ../_knowledge/lessons_learned.md 확인
```

---

## Operator Mode (자동 실행)

**"해줘/실행해줘/돌려줘" → 명령어 안내 대신 직접 실행**

| 사용자 표현 | Agent 행동 |
|------------|------------|
| "실험 돌려줘: exp=baseline, python train.py" | `./scripts/run.sh --exp baseline python train.py` 실행 |
| "분석해줘/정리해줘" | `python3 ./scripts/draft_memo.py ...` 실행 |
| "명령어만 알려줘" | 안내만 (유일한 예외) |

**규칙:**
1. 실험은 반드시 `run.sh`로 래핑 → Run Card 자동
2. 분석은 `draft_memo.py`로 → Experiment Memo 자동
3. "명령어만"이 없으면 무조건 실행

---

## 3카드 로깅 시스템

### 실험 실행 (Run Card 자동 생성)

```bash
./scripts/run.sh --exp <실험명> <명령어>
# 예: ./scripts/run.sh --exp baseline python train.py --lr 0.001
```

→ `runs/<RUN_ID>/`에 Run Card + 로그 자동 생성

### Run Card 규칙 (FACT-ONLY)

| 허용 | 금지 |
|------|------|
| "loss가 0.5에서 0.1로 감소" | "빠르게 수렴했다" (해석) |
| "epoch 10에서 OOM 발생" | "메모리가 부족한 것 같다" (추정) |

### Experiment Memo 규칙

```bash
python3 ./scripts/draft_memo.py --memo_id <ID> --goal "<목표>" --runs <RUN_ID1> <RUN_ID2>
```

- **Observations**: 관측된 사실만 (Run Card에서 추출)
- **Inferences**: 각 가설에 반드시 포함:
  - Evidence (지지 사실)
  - Counter-evidence (반증, 없으면 "None observed")
  - Confidence (High/Medium/Low)

### Decision Record 규칙

중요 결정 시 `decisions/DR-NNN_제목.md` 작성:
- 고려한 대안들 (최소 2개)
- 정량적 성공 기준
- 롤백 계획

---

## 주제 키워드

<!-- agent가 관련 논문 검색에 사용 -->

---

## 지식 저장 위치

| 발견한 것 | 저장 위치 |
|----------|----------|
| 새 논문 | `../_knowledge/papers/{Author}_{Year}_{Keyword}.md` |
| 이 프로젝트 아이디어 | `./CONCEPT.md` |
| 실험 결과 | `./runs/<RUN_ID>/run_card.md` + Memo |
| 프로젝트 간 교훈 | `../_knowledge/lessons_learned.md` |

---

## Cross-Review

> 전역 CLAUDE.md의 Cross-Review 규칙을 따릅니다.

---

## Git Snapshot (Opt-in)

```bash
# 수동 스냅샷
./scripts/git_snap.sh "tag"

# run.sh 연동
RS_GIT_SNAP=1 ./scripts/run.sh --exp baseline python train.py
```

- **기본**: commit만 (push는 `--push` 또는 `RS_GIT_PUSH=1`)
- **review_cycles**: git에 포함되지 않음
- **금지 파일**: `stdout.log`, `data/`, `*.pt`, `checkpoints/` 등 대형 파일

---

## 운영 편의 (옵션)

```bash
# GPT 피드백 저장 (macOS pbpaste, 또는 --stdin)
./scripts/save_clipboard_to_gpt_review.sh
echo "피드백" | ./scripts/save_clipboard_to_gpt_review.sh --stdin

# 다음 프롬프트 저장
./scripts/save_clipboard_to_next_prompt.sh --stdin < feedback.txt

# Run Index CSV (runs/index.csv에 자동 append)
RS_RUN_INDEX=1 ./scripts/run.sh --exp baseline python train.py
```

---

## 서버 경로 (사용자 환경에 맞게 수정)

<!-- 아래는 예시입니다. 실제 환경에 맞게 수정하세요. -->
- 로컬: `~/projects/{{PROJECT_NAME}}/`
- 서버: `~/projects/{{PROJECT_NAME}}/`
- 동기화: 사용자 정의 스크립트 또는 rsync
