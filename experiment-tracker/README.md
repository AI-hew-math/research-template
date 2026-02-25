# 🧪 experiment-tracker v2

**터미널 탭 타이틀에 실험 상태를 실시간 표시하는 zsh 도구**

여러 서버에서 실험을 돌릴 때, 어떤 터미널에서 무슨 실험이 돌고 있는지 한눈에 파악할 수 있습니다.

```
탭 타이틀 형식:
  실험 있을 때 → PHScene : 🧪×3 fair_A:12727, topo_B:13000, baseline:88888
  실험 없을 때 → PHScene
```

---

## v2 변경사항

| 기능 | v1 | v2 |
|------|----|----|
| **실험 감지** | 수동 `st add`만 | 3-tier 자동 감지 |
| **경로 매칭** | substring | 경로 경계 매칭 |
| **dedup 키** | base_id | server:base_id |
| **파일 분리** | 단일 파일 | 수동 + 자동 분리 |
| **Claude Code** | /dev/tty만 | 부모 TTY 폴백 |
| **새 명령** | - | `rs_claim`, `rs_sbatch`, `st map` |

---

## 3-tier 자동 감지

claude 시작 시 서버를 스캔하여 현재 프로젝트의 실험을 자동 등록:

```
Tier 1: job metadata (가장 신뢰)
  (1a) SLURM comment에 "rs:ProjectName" 포함
  (1b) job name이 "ProjectName_"로 시작

Tier 2: 전역 경로 캐시 (~/.rs-path-map)
  rs_claim으로 등록한 workdir → project 매핑

Tier 3: 프로젝트 .experiment-paths (fallback)
  workdir이 파일의 경로 패턴과 경계 매칭
```

---

## 설치

```bash
cd experiment-tracker
bash install.sh
```

또는 수동으로 `~/.zshrc`에:
```bash
source "/path/to/experiment-tracker.zsh"
```

Ghostty config (`~/Library/Application Support/com.mitchellh.ghostty/config`):
```
shell-integration-features = no-title
```

---

## 사용법

```bash
# 수동 등록
st add "fair_A:12727" soda
st add "train:1234" local
st rm "fair_A:12727"
st off

# 상태 확인
st                    # 현재 실험 (자동/수동 구분)
st check soda         # 서버 큐 확인
st watch              # 실시간 모니터
st map                # 경로 캐시 보기

# 보조 명령
rs_claim soda 12345 PHScene       # workdir → 프로젝트 매핑 캐시
rs_sbatch soda scripts/train.sh   # 태그 포함 제출 + tracker 등록
```

### Claude Code 자동 감지

```bash
$ cd MyProject    # .experiment-paths 있는 프로젝트
$ claude
🔍 서버 실험 스캔 중... (project: MyProject)
✅ 2개 실험 감지 → tracker 등록
  🧪 train_run:13000 [soda]
  🧪 eval_run:13001 [vegi]
```

---

## 설정

```bash
export RS_POLL=60                      # 체크 주기 (초, 기본: 60)
export RS_SERVERS=(soda vegi potato)   # 서버 목록
export RS_PROJECT=MyProject            # rs_sbatch 프로젝트명 오버라이드
```

### .experiment-paths 예시
```
# 경계 매칭: /projects/OCRL → .../projects/OCRL/exp1 (O)
#            /projects/OCRL → .../projects/OCRL-backup (X)
/projects/PHScene
/projects/OCRL
```

---

## 파일 구조

| 파일 | 용도 | 수명 |
|------|------|------|
| `/tmp/research-exps` | 수동 등록 | st off까지 |
| `/tmp/research-exps.auto` | 자동 감지 | claude 시작마다 재생성 |
| `~/.rs-path-map` | 전역 경로 캐시 | 영구 (rs_claim) |
| `{project}/.experiment-paths` | 경로 패턴 | 영구 (수동 관리) |

---

## 호환성

| 터미널 | 지원 |
|--------|------|
| Ghostty | ✅ (`no-title` 설정 필요) |
| iTerm2 | ✅ |
| Terminal.app | ✅ |
| Kitty | ✅ |
| tmux | ⚠️ (`set -g set-titles on` 필요) |

---

## 라이선스

MIT
