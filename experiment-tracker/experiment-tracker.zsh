# ── project-title: 프로젝트 폴더명으로 탭 타이틀 설정 ──────────
# https://github.com/AI-hew-math/research-template
#
# 설치: source 이 파일을 ~/.zshrc에 추가
# 요구: Ghostty는 shell-integration-features = no-title 필요
#
# 기능:
#   - 탭/윈도우 타이틀에 프로젝트 폴더명 표시
#   - cd로 이동해도 프로젝트 루트명 유지
#
# 프로젝트 루트 감지 우선순위:
#   (1) git repo: git rev-parse --show-toplevel
#   (2) 상위에 .claude/ 또는 CLAUDE.md 있는 디렉토리
#   (3) 현재 디렉토리 basename
#
# 환경변수:
#   RS_TITLE_DISABLE=1    타이틀 설정 비활성화
#   RS_TITLE_PREFIX="X"   타이틀 앞에 prefix 추가 (예: "X: ProjectName")
# ─────────────────────────────────────────────────────────────

# ── 프로젝트 루트 탐지 ──
_rs_find_project_root() {
  # (1) git repo (pwd -P로 실경로 정규화)
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$git_root" ]]; then
    (cd "$git_root" && pwd -P)
    return 0
  fi

  # (2) 상위로 올라가며 .claude/ 또는 CLAUDE.md 탐색
  local dir
  dir=$(pwd -P)
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.claude" ]] || [[ -f "$dir/CLAUDE.md" ]]; then
      echo "$dir"
      return 0
    fi
    dir="${dir:h}"
  done

  # (3) fallback: 현재 디렉토리 (실경로)
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
}

# ── zsh hooks ──
_rs_chpwd() {
  _rs_set_title
}

_rs_precmd() {
  _rs_set_title
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _rs_chpwd
add-zsh-hook precmd _rs_precmd

# 초기 타이틀 설정
_rs_set_title
# ── /project-title ─────────────────────────────────────────────
