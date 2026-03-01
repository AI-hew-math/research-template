# 📂 project-title

**터미널 탭 타이틀에 프로젝트 폴더명을 표시하는 zsh 도구**

여러 프로젝트를 오가며 작업할 때, 탭 타이틀로 현재 프로젝트를 쉽게 구분할 수 있습니다.

```
탭 타이틀: PHScene
```

서브폴더로 이동해도 프로젝트 루트 이름이 유지됩니다.

---

## 설치

```bash
cd experiment-tracker
./install.sh   # zsh 권장, bash에서도 자동으로 zsh 재실행
```

또는 수동으로 `~/.zshrc`에:
```bash
source "/path/to/experiment-tracker.zsh"
```

### Ghostty 사용자

```
# ~/Library/Application Support/com.mitchellh.ghostty/config
shell-integration-features = no-title
```

---

## 프로젝트 루트 감지

우선순위:
1. **git repo**: `git rev-parse --show-toplevel`
2. **Agent 프로젝트**: 상위에 `.claude/` 또는 `CLAUDE.md` 있는 디렉토리
3. **fallback**: 현재 디렉토리

---

## 환경변수

```bash
RS_TITLE_DISABLE=1      # 타이틀 설정 비활성화
RS_TITLE_PREFIX="Work"  # 타이틀 앞에 prefix 추가 → "Work: ProjectName"
```

---

## Agent CLI 연동 (예: claude)

설치 시 선택적으로 래퍼를 추가할 수 있습니다:
- Agent가 탭 타이틀을 변경하지 않음
- Agent 종료 후 타이틀이 프로젝트명으로 복원

수동 추가 (claude 예시):
```bash
# ~/.zshrc
unalias claude 2>/dev/null
function claude {
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 /path/to/claude "$@"
  _rs_set_title
}
```

---

## 호환성

| 터미널 | 지원 |
|--------|------|
| Ghostty | ✅ (`no-title` 필요) |
| iTerm2 | ✅ |
| Terminal.app | ✅ |
| Kitty | ✅ |
| tmux | ⚠️ (`set -g set-titles on`) |

---

## 라이선스

MIT
