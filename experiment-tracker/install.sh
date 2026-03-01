#!/bin/zsh
# project-title 설치 스크립트
# 사용법: ./install.sh (zsh 권장, bash에서도 자동으로 zsh로 재실행됨)

# zsh가 아니면 zsh로 재실행
if [ -z "$ZSH_VERSION" ]; then
  exec zsh "$0" "$@"
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_LINE="source \"${SCRIPT_DIR}/experiment-tracker.zsh\""

# Ghostty config: macOS vs Linux
if [[ -f "${HOME}/Library/Application Support/com.mitchellh.ghostty/config" ]]; then
  GHOSTTY_CONFIG="${HOME}/Library/Application Support/com.mitchellh.ghostty/config"
elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" ]]; then
  GHOSTTY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
else
  GHOSTTY_CONFIG=""
fi

echo "📂 project-title 설치"
echo "====================="
echo "탭 타이틀에 프로젝트 폴더명을 표시합니다."
echo

# 1) ~/.zshrc에 source 추가
if grep -qF "experiment-tracker.zsh" ~/.zshrc 2>/dev/null; then
  echo "✅ ~/.zshrc에 이미 등록됨"
else
  echo "" >> ~/.zshrc
  echo "# project-title: 탭 타이틀에 프로젝트명 표시" >> ~/.zshrc
  echo "${SOURCE_LINE}" >> ~/.zshrc
  echo "✅ ~/.zshrc에 추가 완료"
fi

# 2) Ghostty config 확인 (선택)
echo
if [[ -n "$GHOSTTY_CONFIG" && -f "$GHOSTTY_CONFIG" ]]; then
  if grep -q "shell-integration-features.*no-title" "$GHOSTTY_CONFIG"; then
    echo "✅ Ghostty no-title 설정 확인됨"
  else
    echo "ℹ️  Ghostty에서 프로그램이 타이틀을 제어하려면:"
    echo "   shell-integration-features = no-title"
    echo
    read -p "   자동으로 추가할까요? (y/n) " yn
    if [[ "$yn" == "y" ]]; then
      echo "" >> "$GHOSTTY_CONFIG"
      echo "# project-title: 프로그램이 타이틀 직접 제어" >> "$GHOSTTY_CONFIG"
      echo "shell-integration-features = no-title" >> "$GHOSTTY_CONFIG"
      echo "   ✅ 추가 완료"
    fi
  fi
else
  echo "ℹ️  Ghostty 사용 시 config에 추가 필요: shell-integration-features = no-title"
fi

# 3) Claude Code 래퍼 (선택)
echo
if type claude >/dev/null 2>&1; then
  CLAUDE_BIN=$(whence -p claude 2>/dev/null || command -v claude 2>/dev/null || which claude 2>/dev/null)
  if grep -qF "function claude" ~/.zshrc 2>/dev/null; then
    echo "✅ Claude Code 래퍼 이미 등록됨"
  else
    echo "ℹ️  Claude Code 래퍼를 추가하면:"
    echo "    - Claude가 탭 타이틀을 변경하지 않음"
    echo "    - Claude 종료 후 타이틀이 프로젝트명으로 복원"
    echo
    read -p "   래퍼 함수를 추가할까요? (y/n) " yn
    if [[ "$yn" == "y" ]]; then
      cat >> ~/.zshrc << EOFCLAUDE

# Claude Code: 타이틀 충돌 방지 + 종료 후 복원
unalias claude 2>/dev/null
function claude {
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 ${CLAUDE_BIN} "\$@"
  _rs_set_title
}
EOFCLAUDE
      echo "   ✅ 래퍼 추가 완료"
    fi
  fi
fi

echo
echo "====================="
echo "설치 완료!"
echo
echo "새 터미널을 열거나 source ~/.zshrc 실행 후,"
echo "프로젝트 폴더로 이동하면 탭 타이틀에 폴더명이 표시됩니다."
echo
echo "환경변수 옵션:"
echo "  RS_TITLE_DISABLE=1    타이틀 설정 비활성화"
echo "  RS_TITLE_PREFIX=\"X\"   타이틀 앞에 prefix 추가"
echo
