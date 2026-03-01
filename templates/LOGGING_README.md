# 3-Card Logging System

이 프로젝트는 **3카드 로깅 시스템**을 사용합니다.

## 핵심 원칙

1. **FACT와 INFERENCE 분리**: 관측 사실과 해석/가설을 물리적으로 분리
2. **재현성**: 모든 실험 실행은 자동으로 환경/명령/로그 기록
3. **의사결정 추적**: 중요한 결정은 대안, 정량 기준, 롤백 계획과 함께 기록

---

## 3카드 구조

```
runs/                      # Run Cards (자동 생성)
├── 20250301_143022_exp1_host_abc123/
│   ├── run_card.md        # FACT-only 실행 기록
│   ├── stdout.log
│   ├── stderr.log
│   ├── meta.txt
│   └── ...

experiments/memos/         # Experiment Memos (분석 후 작성)
├── memo_baseline.md       # Observations(FACT) + Inferences(가설)
└── ...

decisions/                 # Decision Records (중요 결정 시)
├── DR-001_optimizer.md    # 대안, 정량기준, 롤백계획 포함
└── ...
```

---

## 사용법

### 1. 실험 실행 (Run Card 자동 생성)

```bash
./scripts/run.sh --exp baseline python train.py --lr 0.001

# 결과: runs/YYYYMMDD_HHMMSS_baseline_<host>_<gitsha>/ 생성
```

### 2. Memo 초안 생성

```bash
python3 ./scripts/draft_memo.py \
  --memo_id memo_lr_sweep \
  --goal "learning rate 영향 분석" \
  --runs <RUN_ID_1> <RUN_ID_2> <RUN_ID_3>

# 결과: experiments/memos/memo_lr_sweep.md 생성
# → Observations는 자동 채움, Inferences는 템플릿만 제공
```

### 3. Decision Record 작성

중요한 설계 결정 시 `decisions/DR-NNN_제목.md` 작성:
- 고려한 대안들
- 정량적 성공 기준
- 롤백 계획

---

## Run Card 규칙 (FACT-ONLY)

Run Card에는 **관측된 사실만** 기록합니다.

| 허용 | 금지 |
|------|------|
| "loss가 0.5에서 0.1로 감소" | "loss가 빠르게 수렴했다" |
| "epoch 10에서 OOM 발생" | "메모리가 부족한 것 같다" |
| "accuracy 92.3%" | "좋은 성능을 보였다" |

원인 분석, 해석, 가설은 **Experiment Memo**에 작성합니다.

---

## Experiment Memo 규칙

### Observations (FACT)
- Run Card에서 추출한 사실만 기록
- 숫자, 로그 메시지, 에러 등 객관적 데이터

### Inferences (HYPOTHESIS)
각 추론에 반드시 포함:
- **Evidence**: 이 가설을 지지하는 관측 사실
- **Counter-evidence**: 반하는 사실 (없으면 "None observed")
- **Confidence**: High / Medium / Low

---

## Decision Record 규칙

1. **대안 명시**: 최소 2개 이상의 대안과 각각의 pros/cons
2. **정량적 성공 기준**: 측정 가능한 목표치
3. **롤백 계획**: 실패 시 되돌리는 구체적 방법

---

## 기존 프로젝트 마이그레이션

```bash
./scripts/bootstrap_logging.sh /path/to/existing_project
```

- 기존 파일은 **절대 덮어쓰지 않음**
- 없는 디렉토리/스크립트만 추가
- EXPERIMENT_LOG.md가 있으면 마이그레이션 안내 파일 생성

---

## 파일 위치 요약

| 파일 | 위치 | 생성 시점 |
|------|------|----------|
| Run Card | `runs/<RUN_ID>/run_card.md` | `run.sh` 실행 시 자동 |
| Experiment Memo | `experiments/memos/<memo_id>.md` | `draft_memo.py` 또는 수동 |
| Decision Record | `decisions/DR-NNN_<title>.md` | 수동 |
