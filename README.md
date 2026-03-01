# Research Project Template

[![GitHub release](https://img.shields.io/github/v/release/AI-hew-math/research-template)](https://github.com/AI-hew-math/research-template/releases/latest)
[![Smoke Test](https://github.com/AI-hew-math/research-template/actions/workflows/smoke.yml/badge.svg)](https://github.com/AI-hew-math/research-template/actions/workflows/smoke.yml)

Claude Code와 함께하는 연구 프로젝트 템플릿

## 권장 워크플로우

1. `./create_project.sh "Name" "설명"` → 프로젝트 생성
2. `cd ../Name && claude` → hooks 승인 (SessionStart/End)
3. `./scripts/run.sh --exp name cmd` → 실험 실행 + Run Card
4. `./scripts/draft_memo.py` → 분석 Memo 작성
5. `review_cycles/` GPT 업로드 → `RS_GIT_SNAP=1` 스냅샷 (선택)

---

## Quickstart

```bash
./create_project.sh "MyProject" "연구 설명"
cd ../MyProject && claude          # hooks 승인
./scripts/run.sh --exp baseline python train.py
python3 ./scripts/draft_memo.py --memo_id memo_v1 --goal "목표" --runs <RUN_ID>
```

---

## 전체 구조

```
Claude_projects/
├── CLAUDE.md              # 전역 지침
├── _knowledge/
│   ├── papers/            # 논문 노트
│   └── lessons_learned.md # 프로젝트 간 교훈
│
├── research-template/     # 이 템플릿
├── ProjectA/
│   ├── runs/              # Run Cards (자동 생성)
│   ├── experiments/memos/ # Experiment Memos
│   ├── decisions/         # Decision Records
│   └── scripts/           # run.sh, draft_memo.py
└── ...
```

---

## 처음 시작하기

### 1. 템플릿 설치 (최초 1회)
```bash
# 원하는 위치에 클론
git clone https://github.com/AI-hew-math/research-template ~/Claude_projects/research-template

cd ~/Claude_projects/research-template
chmod +x *.sh
```

### 2. 전역 CLAUDE.md 설정 (최초 1회)
```bash
cp templates/GLOBAL_CLAUDE.md ../CLAUDE.md
```

### 3. 지식 베이스 초기화 (최초 1회)
```bash
./init_knowledge.sh
```

### 4. 탭 타이틀 설정 (선택)
```bash
./experiment-tracker/install.sh   # 탭에 프로젝트 폴더명 표시
```

---

## 새 프로젝트 만들기

```bash
cd ~/Claude_projects/research-template
./create_project.sh "ProjectName" "연구 주제 설명"
cd ../ProjectName
claude
```

그리고: **"연구 시작하자"**

---

## 3카드 로깅 시스템

### 1. 실험 실행 (Run Card 자동)

```bash
./scripts/run.sh --exp baseline python train.py --lr 0.001
```

→ `runs/YYYYMMDD_HHMMSS_baseline_host_gitsha/`에 자동 생성:
- `run_card.md` - FACT-only 실행 기록
- `stdout.log`, `stderr.log`
- `meta.txt`, `env.txt`, `git_diff.patch`

### 2. 분석 후 Memo 작성

```bash
python3 ./scripts/draft_memo.py \
  --memo_id memo_lr_sweep \
  --goal "learning rate 영향 분석" \
  --runs <RUN_ID1> <RUN_ID2>
```

→ `experiments/memos/memo_lr_sweep.md` 생성
- Observations: 자동 요약 (FACT)
- Inferences: 템플릿만 제공 (Evidence/Counter-evidence/Confidence)

### 3. 중요 결정 시 Decision Record

`decisions/DR-001_optimizer.md` 수동 작성:
- 고려한 대안들
- 정량적 성공 기준
- 롤백 계획

---

## 기존 프로젝트에 로깅 추가

```bash
./scripts/bootstrap_logging.sh /path/to/existing_project
```

- 기존 파일 덮어쓰기 없음
- 없는 디렉토리/스크립트만 추가

---

## Git Snapshot (Opt-in)

실험 실행 후 코드/문서 변경을 자동으로 커밋합니다.

### 사용법

```bash
# 수동 스냅샷
./scripts/git_snap.sh "checkpoint_v1"

# Push까지 포함
./scripts/git_snap.sh "release" --push

# run.sh 연동 (환경변수)
RS_GIT_SNAP=1 ./scripts/run.sh --exp baseline python train.py
RS_GIT_SNAP=1 RS_GIT_PUSH=1 ./scripts/run.sh --exp baseline python train.py
```

### 화이트리스트 (커밋 대상)

| 경로 | 설명 |
|------|------|
| `src/`, `scripts/`, `configs/` | 코드 |
| `*.md` (루트) | 문서 |
| `runs/*/run_card.md` | Run Cards |
| `runs/*/metrics.json` | 메트릭 |
| `experiments/memos/*.md` | Memos |
| `decisions/*.md` | Decision Records |

### 금지 파일 (절대 커밋 안 됨)

- `runs/*/stdout.log`, `stderr.log`, `env.txt`, `nvidia-smi.txt`
- `data/`, `checkpoints/`, `wandb/`
- `*.pt`, `*.pth`, `*.ckpt`
- `review_cycles/**` 전체

### 정책

- **기본**: commit만 (push는 opt-in)
- **review_cycles**: git에 포함되지 않음 (`.gitignore`로 차단)
- **runs/index.csv**: 파생물이므로 기본 화이트리스트에 미포함. 필요시 `git add runs/index.csv` 후 커밋.
- **서버 권장**: push가 번거로우면 로컬에서만 push

---

## Review Cycles (GPT 검토)

**cycle은 프롬프트 단위로 증가합니다.** 세션 종료 없이 매 프롬프트마다 패킷이 자동 생성됩니다.

### 구조

```
review_cycles/
├── cycle_0001/
│   ├── to_gpt/
│   │   ├── user_prompt.txt          # 사용자 프롬프트
│   │   ├── last_assistant_message.md # Claude 최종 응답
│   │   ├── packet.md, UPLOAD_LIST.md
│   │   └── git_diff.patch
│   ├── from_gpt/
│   └── to_claude/
├── cycle_0002/
└── ...
```

### 사용 흐름

1. `claude` 실행 → hooks 승인 (최초 1회)
2. 프롬프트 입력 → Claude 응답 완료
3. `review_cycles/cycle_XXXX/to_gpt/` 자동 생성
4. GPT에 업로드 → 피드백 받기

### 자동 생성 시점

- **UserPromptSubmit**: cycle +1, `user_prompt.txt` 저장
- **Stop**: `last_assistant_message.md` 저장, 패킷 갱신
- **SessionEnd**: 안전망 갱신

### 실동작 검증 (최초 1회)

```bash
cd MyProject && claude                    # 1. /hooks → UserPromptSubmit, Stop 승인
# 프롬프트 1회 입력
cat review_cycles/cycle_0001/to_gpt/user_prompt.txt   # 2. 프롬프트 저장 확인
# Claude 응답 완료 대기
ls review_cycles/cycle_0001/to_gpt/       # 3. last_assistant_message.md, packet.md 확인
```

---

## Claude가 자동으로 하는 것

| 상황 | Claude 행동 |
|------|------------|
| 세션 시작 | EXPERIMENT_LOG.md, CONCEPT.md 확인 |
| 새 논문 발견 | `_knowledge/papers/`에 저장 |
| 실험 교훈 | `_knowledge/lessons_learned.md`에 추가 |
| 실험 시작 전 | `lessons_learned.md` 확인 (과거 실수 방지) |

---

## 지식이 연결되는 방식

```
[ProbeX 프로젝트]
    ↓ topology loss 사용
    ↓
[_knowledge/papers/Chen_2024_TopoLoss.md]
    ↓
    ↓ 같은 논문 참조
    ↓
[SegPH 프로젝트]
```

---

## 운영 편의 (옵션)

### 클립보드 → GPT 리뷰 저장 (macOS)

```bash
# GPT 응답을 복사한 후
./scripts/save_clipboard_to_gpt_review.sh

# 또는 stdin 사용
echo "GPT 피드백 내용" | ./scripts/save_clipboard_to_gpt_review.sh --stdin
```
→ `review_cycles/cycle_XXXX/from_gpt/gpt_review.md`에 저장

### 클립보드 → 다음 프롬프트 저장 (macOS)

```bash
./scripts/save_clipboard_to_next_prompt.sh
# 또는
echo "다음 지시" | ./scripts/save_clipboard_to_next_prompt.sh --stdin
```
→ `review_cycles/cycle_XXXX/to_claude/next_prompt.txt`에 저장

### Run Index CSV

```bash
RS_RUN_INDEX=1 ./scripts/run.sh --exp baseline python train.py
```
→ `runs/index.csv`에 자동 append:
```
run_id,exp_name,exit_code,seconds,timestamp,host,git_sha
```

---

## 확장 기준

**필요할 때만 구조를 추가:**

| 트리거 | 액션 |
|--------|------|
| 한 주제 논문 10개+ | MOC (Map of Content) 생성 |
| 3개+ 프로젝트가 같은 기법 | methods/ 폴더 생성 |

---

## 요약

| 원칙 | 설명 |
|------|------|
| 최소 시작 | papers/ + lessons_learned.md 만으로 시작 |
| 필요시 확장 | 논문 10개+ 될 때 MOC 추가 |
| 간결한 규칙 | Claude 지침은 핵심 규칙만 |
| FACT 분리 | Run Card=사실, Memo=사실+가설 분리 |
