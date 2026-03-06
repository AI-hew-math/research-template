# ── project-title: 프로젝트 폴더명으로 탭 타이틀 설정 ──────────
# https://github.com/AI-hew-math/research-template
#
# 설치: source 이 파일을 ~/.zshrc에 추가
# 요구: Ghostty는 shell-integration-features = no-title 필요
#
# 기능:
#   - 탭/윈도우 타이틀에 프로젝트 폴더명 표시
#   - cd로 이동해도 프로젝트 루트명 유지
#   - Claude Code가 타이틀 덮어쓰기 방지
#
# 프로젝트 루트 감지 우선순위:
#   (1) git repo: git rev-parse --show-toplevel
#   (2) 현재 디렉토리 basename
#
# 환경변수:
#   CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1  (자동 export)
#   RS_TITLE_DISABLE=1    타이틀 설정 비활성화
#   RS_TITLE_PREFIX="X"   타이틀 앞에 prefix 추가 (예: "X: ProjectName")
# ─────────────────────────────────────────────────────────────

export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1

# ── 프로젝트 루트 탐지 ──
_rs_find_project_root() {
  # (1) git repo (pwd -P로 실경로 정규화)
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$git_root" ]]; then
    (cd "$git_root" && pwd -P)
    return 0
  fi

  # (2) fallback: 현재 디렉토리 (실경로)
  pwd -P
}

# ── TTY 감지 (agent 내부에서도 동작) ──
_rs_find_tty() {
  if print -n "" > /dev/tty 2>/dev/null; then
    echo "/dev/tty"
    return 0
  fi
  local pid=$$ p_tty
  while (( pid > 1 )); do
    p_tty=$(ps -p $pid -o tty= 2>/dev/null | tr -d ' ')
    if [[ -n "$p_tty" ]] && [[ "$p_tty" != "??" ]] && [[ -w "/dev/$p_tty" ]]; then
      echo "/dev/$p_tty"
      return 0
    fi
    pid=$(ps -p $pid -o ppid= 2>/dev/null | tr -d ' ')
  done
  return 1
}

# ── 탭 타이틀 설정 ──
_rs_set_title() {
  # 비활성화 옵션
  [[ "${RS_TITLE_DISABLE:-}" == "1" ]] && return 0
  # 재진입 방지 (chpwd → _rs_find_project_root 내부 cd → chpwd 무한 재귀 차단)
  [[ "${_RS_IN_TITLE:-}" == "1" ]] && return 0
  _RS_IN_TITLE=1

  local project_root project_name title
  project_root=$(_rs_find_project_root)
  project_name="${project_root:t}"  # basename

  # prefix 옵션
  if [[ -n "${RS_TITLE_PREFIX:-}" ]]; then
    title="${RS_TITLE_PREFIX}: ${project_name}"
  else
    title="${project_name}"
  fi

  # OSC sequence로 탭/윈도우 타이틀 설정
  local tgt
  tgt=$(_rs_find_tty)
  if [[ -n "$tgt" ]]; then
    printf '\e]0;%s\a' "$title" > "$tgt" 2>/dev/null
  else
    print -Pn "\e]0;${title}\a"
  fi
  _RS_IN_TITLE=0
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _rs_set_title
add-zsh-hook precmd _rs_set_title

# claude wrapper: 타이틀 덮어쓰기 방지
unalias claude 2>/dev/null
function claude {
  _rs_set_title
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 command claude "$@"
  _rs_set_title
}

# 초기 타이틀 설정
_rs_set_title
# ── /project-title ─────────────────────────────────────────────
