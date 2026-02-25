# 🧪 experiment-tracker

**터미널 탭 타이틀에 실험 상태를 실시간 표시하는 zsh 도구**

여러 서버에서 실험을 돌릴 때, 어떤 터미널에서 무슨 실험이 돌고 있는지 한눈에 파악할 수 있습니다.

![tab title example](./screenshot.png)

```
탭 타이틀 형식:
  실험 있을 때 → TopoSceneGraph : 🧪×3 fair_A:12727, topo_B:13000, baseline:88888
  실험 없을 때 → TopoSceneGraph
```

---

## 기능

| 기능 | 설명 |
|------|------|
| **멀티 서버** | soda, vegi, potato 등 여러 SLURM 서버 동시 추적 |
| **로컬 프로세스** | 로컬 PID 추적 (`st add train:1234 local`) |
| **자동 완료 감지** | 60초마다 백그라운드에서 squeue/ps 체크 → 끝난 job 자동 제거 |
| **SSH 실패 안전** | 네트워크 끊김 시 job을 잘못 제거하지 않음 |
| **중복 폴링 방지** | lock 파일로 SSH 중첩 차단 |
| **Claude Code 호환** | `/dev/tty` 직접 출력으로 Claude Code 안에서도 타이틀 변경 |
| **백그라운드 watcher** | precmd 없이도 (Claude Code 실행 중에도) 자동 갱신 |

---

## 설치

### 요구사항
- **zsh** (macOS 기본 쉘)
- **Ghostty** 터미널 (OSC 타이틀 지원하는 다른 터미널도 가능)
- SSH 키 기반 인증 (서버 자동 체크에 필요)

### 자동 설치
```bash
cd experiment-tracker
bash install.sh
```

### 수동 설치

**1) ~/.zshrc에 추가:**
```bash
source "/path/to/experiment-tracker.zsh"
```

**2) Ghostty config에 추가** (`~/Library/Application Support/com.mitchellh.ghostty/config`):
```
shell-integration-features = no-title
```

**3) Ghostty 재시작** (`Cmd+Q` → 다시 열기)

---

## 사용법

### 기본 명령어

```bash
# 실험 추가 (서버 지정 → 자동 완료 감지)
st add "fair_A:12727" soda      # soda SLURM job
st add "topo_B:13000" vegi      # vegi SLURM job
st add "train:1234" local       # 로컬 PID

# 실험 추가 (서버 미지정 → 수동 관리)
st add "my_experiment"

# 실험 제거
st rm "fair_A:12727"

# 전부 해제
st off

# 현재 상태 확인
st

# 서버 squeue 직접 확인
st check soda

# 실시간 모니터 (별도 터미널)
st watch
```

### 실제 워크플로우

```bash
# 1) 서버에 실험 제출
ssh soda "cd ~/projects/MyProject && sbatch train.sh"
# → Submitted batch job 12727

# 2) 추적 등록
st add "fair_A:12727" soda
# → 탭: MyProject : 🧪×1 fair_A:12727

# 3) 추가 실험
st add "topo_B:13000" vegi
# → 탭: MyProject : 🧪×2 fair_A:12727, topo_B:13000

# 4) 자동 완료: 60초마다 squeue 체크 → 끝나면 자동 제거
# 5) 수동 제거도 가능
st rm "fair_A:12727"
```

### Claude Code에서 사용

```bash
# Claude Code 안에서도 동일하게 사용
st add "fair_A:12727" soda

# Claude에게 시키기:
# "soda에서 train.sh 제출하고 st로 추적해줘"
```

---

## label 형식

```
name:id
```

- `name`: 실험 이름 (자유 형식)
- `id`: SLURM job ID 또는 로컬 PID (숫자)
- 서버를 지정하면 `id`로 자동 완료 감지
- `id` 없이 이름만 → 수동 관리

**SLURM array job**: `st add "ablation:12734" soda` → 12734_0, 12734_1, ... 전부 추적

---

## 설정

환경변수로 동작을 조정할 수 있습니다:

```bash
export RS_POLL=60      # 체크 주기 (초, 기본: 60)
```

---

## 구조

```
/tmp/research-exps     ← 실험 목록 (label\tserver)
/tmp/rs-check-*        ← 서버별 squeue 결과 (임시)
/tmp/rs-poll.lock      ← 중복 폴링 방지 lock
/tmp/rs-watcher.pid    ← 백그라운드 watcher PID
```

---

## 안전 장치

| 상황 | 동작 |
|------|------|
| SSH 타임아웃/실패 | 해당 서버 job은 제거하지 않음 (오탐 방지) |
| 폴링 중첩 | lock 파일 + 30초 stale 타임아웃 |
| watcher 좀비 | PID 파일로 관리, `st off`에서 정리 |
| zsh glob 에러 | `setopt nonomatch`으로 안전 처리 |

---

## 호환성

| 터미널 | 지원 |
|--------|------|
| Ghostty | ✅ (`no-title` 설정 필요) |
| iTerm2 | ✅ (설정 불필요) |
| Terminal.app | ✅ (설정 불필요) |
| Kitty | ✅ (설정 불필요) |
| tmux | ⚠️ (`set -g set-titles on` 필요) |

---

## 문제 해결

**타이틀이 안 바뀜:**
- Ghostty `Cmd+Q` 재시작 했는지 확인
- `shell-integration-features = no-title` 설정 확인
- `printf '\e]0;TEST\a'` 로 OSC 타이틀 지원 확인

**자동 감지가 안 됨:**
- `ssh soda "squeue -u \$USER"` 가 동작하는지 확인
- SSH 키 인증 설정 확인 (`BatchMode=yes`로 비밀번호 프롬프트 차단)

**Claude Code에서 타이틀이 "claude"로 바뀜:**
- `install.sh`로 Claude 래퍼 함수 설치
- 또는 수동으로 `~/.zshrc`에 래퍼 추가

---

## 라이선스

MIT
