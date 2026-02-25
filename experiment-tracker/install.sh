#!/bin/zsh
# experiment-tracker v2 설치 스크립트
# 사용법: zsh install.sh  또는  bash install.sh

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

echo "🧪 experiment-tracker v2 설치"
echo "=============================="
echo

# 1) ~/.zshrc에 source 추가
if grep -qF "experiment-tracker.zsh" ~/.zshrc 2>/dev/null; then
  echo "✅ ~/.zshrc에 이미 등록됨"
else
  echo "" >> ~/.zshrc
  echo "# experiment-tracker v2: 터미널 탭에 실험 상태 표시" >> ~/.zshrc
  echo "${SOURCE_LINE}" >> ~/.zshrc
  echo "✅ ~/.zshrc에 추가 완료"
fi

# 2) 서버 설정
echo
echo "ℹ️  기본 서버: soda, vegi, potato"
echo "   변경하려면 ~/.zshrc에 추가: export RS_SERVERS=(server1 server2 ...)"

# 3) Ghostty config 확인
echo
if [[ -n "$GHOSTTY_CONFIG" && -f "$GHOSTTY_CONFIG" ]]; then
  if grep -q "shell-integration-features.*no-title" "$GHOSTTY_CONFIG"; then
    echo "✅ Ghostty no-title 설정 확인됨"
  else
    echo "⚠️  Ghostty config에 아래 줄 추가 필요:"
    echo "   shell-integration-features = no-title"
    echo
    read -p "   자동으로 추가할까요? (y/n) " yn
    if [[ "$yn" == "y" ]]; then
      echo "" >> "$GHOSTTY_CONFIG"
      echo "# experiment-tracker: 프로그램이 타이틀 직접 제어" >> "$GHOSTTY_CONFIG"
      echo "shell-integration-features = no-title" >> "$GHOSTTY_CONFIG"
      echo "   ✅ 추가 완료"
    fi
  fi
else
  echo "⚠️  Ghostty config 파일을 찾을 수 없습니다."
  echo "   iTerm2 등 다른 터미널에서는 OSC 타이틀이 기본 지원될 수 있습니다."
fi

# 4) Claude Code 래퍼 (선택)
echo
if type claude >/dev/null 2>&1; then
  CLAUDE_BIN=$(whence -p claude 2>/dev/null || command -v claude 2>/dev/null || which claude 2>/dev/null)
  if grep -qF "function claude" ~/.zshrc 2>/dev/null; then
    echo "✅ Claude Code 래퍼 이미 등록됨"
  else
    echo "ℹ️  Claude Code 래퍼를 추가하면:"
    echo "    - claude 시작 시 서버 실험 자동 감지"
    echo "    - 탭 타이틀 자동 복원"
    read -p "   래퍼 함수를 추가할까요? (y/n) " yn
    if [[ "$yn" == "y" ]]; then
      cat >> ~/.zshrc << EOFCLAUDE

# Claude Code 시작 시 실험 자동 감지 + 타이틀 복원
unalias claude 2>/dev/null
function claude {
  _rs_auto_detect
  _rs_set_title
  _rs_watcher_start 2>/dev/null
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 ${CLAUDE_BIN} "\$@"
  _rs_set_title
}
EOFCLAUDE
      echo "   ✅ 래퍼 추가 완료"
    fi
  fi
fi

echo
echo "=============================="
echo "설치 완료! 다음 단계:"
echo "  1. Ghostty를 Cmd+Q로 종료 후 재시작"
echo "  2. 프로젝트에 .experiment-paths 파일 생성:"
echo "     echo '/projects/MyProject' > .experiment-paths"
echo "  3. 새 터미널에서: st add \"my_exp:12345\" soda"
echo "  4. 탭 타이틀 확인: 폴더명 : 🧪×1 my_exp:12345"
echo
echo "v2 새 기능:"
echo "  - claude 시작 시 서버 실험 자동 감지 (3-tier)"
echo "  - rs_claim: job workdir → 프로젝트 매핑 캐시"
echo "  - rs_sbatch: 프로젝트 태그 자동 삽입 제출"
echo "  - st map: 경로 캐시 보기"
echo
