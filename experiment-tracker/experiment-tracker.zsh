# ── experiment-tracker: 터미널 탭에 실험 상태 표시 ──
# https://github.com/AI-hew-math/research-template
#
# 설치: source 이 파일을 ~/.zshrc에 추가
# 요구: Ghostty 터미널 + shell-integration-features = no-title
#
# 사용법:
#   st add fair_A:12727 soda    ← SLURM job, soda에서 자동 완료 감지
#   st add topo_B:13000 vegi    ← SLURM job, vegi에서 자동 완료 감지
#   st add train:1234 local     ← 로컬 PID 자동 완료 감지
#   st add my_experiment        ← 수동 관리 (자동 감지 없음)
#   st rm  fair_A:12727         ← 수동 제거
#   st off                      ← 전부 해제
#   st                          ← 현재 상태
#   st check soda               ← 서버 squeue 직접 확인
#   st watch                    ← 실시간 모니터
#
# 탭 타이틀 형식:
#   실험 있을 때: "폴더명 : 🧪×N label1, label2, ..."
#   실험 없을 때: "폴더명"
# ─────────────────────────────────────────────

zmodload zsh/datetime 2>/dev/null

_RS_FILE="/tmp/research-exps"
_RS_POLL=${RS_POLL:-60}
_RS_LAST_POLL=0

_rs_count() {
  [[ -f "$_RS_FILE" ]] && wc -l < "$_RS_FILE" | tr -d ' ' || echo 0
}

# ── 타이틀 설정 ──
# /dev/tty로 직접 출력 → Claude Code 내부에서도 동작
_rs_set_title() {
  local dir=${PWD##*/} n=$(_rs_count) title
  if (( n > 0 )); then
    local all=$(awk -F'\t' '{printf "%s%s",(NR>1?", ":""),$1}' "$_RS_FILE" 2>/dev/null)
    title="${dir} : 🧪×${n} ${all}"
  else
    title="${dir}"
  fi
  { print -Pn "\e]0;${title}\a" > /dev/tty } 2>/dev/null || print -Pn "\e]0;${title}\a"
}

# ── 서버별 squeue/ps 체크 (동기, watcher용) ──
_rs_poll_sync() {
  [[ -f "$_RS_FILE" ]] || return
  setopt localoptions nonomatch
  local -a servers=()
  while IFS=$'\t' read -r label server; do
    local jid=${label##*:}
    [[ $jid =~ ^[0-9]+$ && -n "$server" && "$server" != "-" ]] || continue
    (( ${servers[(I)$server]} )) || servers+=("$server")
  done < "$_RS_FILE"
  (( ${#servers} )) || return
  for srv in "${servers[@]}"; do
    if [[ "$srv" == "local" ]]; then
      ps -eo pid= | tr -d ' ' > "/tmp/rs-check-${srv}" 2>/dev/null
    else
      # SSH 실패 → check 파일 안 생김 → 해당 서버 job 제거 안 함 (안전)
      ssh -o ConnectTimeout=3 -o BatchMode=yes "$srv" \
        "squeue -u \$USER -h -o %i" > "/tmp/rs-check-${srv}.tmp" 2>/dev/null \
      && mv "/tmp/rs-check-${srv}.tmp" "/tmp/rs-check-${srv}" \
      || rm -f "/tmp/rs-check-${srv}.tmp"
    fi
  done
  _rs_poll_apply
}

# ── 체크 결과 적용: 끝난 job 자동 제거 ──
_rs_poll_apply() {
  [[ -f "$_RS_FILE" ]] || return
  setopt localoptions nonomatch
  local has_checks=false
  for f in /tmp/rs-check-*; do [[ -f "$f" ]] && { has_checks=true; break; }; done
  $has_checks || return
  local changed=false tmp="${_RS_FILE}.tmp"
  : > "$tmp"
  while IFS=$'\t' read -r label server; do
    local jid=${label##*:}
    if [[ $jid =~ ^[0-9]+$ && -n "$server" && "$server" != "-" ]]; then
      local cf="/tmp/rs-check-${server}"
      if [[ -f "$cf" ]] && ! grep -qw "$jid" "$cf"; then
        changed=true
        continue
      fi
    fi
    printf '%s\t%s\n' "$label" "$server" >> "$tmp"
  done < "$_RS_FILE"
  if $changed; then
    [[ -s "$tmp" ]] && mv "$tmp" "$_RS_FILE" || rm -f "$tmp" "$_RS_FILE"
  else
    rm -f "$tmp"
  fi
  rm -f /tmp/rs-check-*
}

# ── 비동기 폴링 (precmd용, 프롬프트 안 막힘) ──
_rs_poll_start() {
  [[ -f "$_RS_FILE" ]] || return
  # 중복 방지: lock + 30초 stale 타임아웃
  if [[ -f /tmp/rs-poll.lock ]]; then
    local lock_ts now
    lock_ts=$(stat -f %m /tmp/rs-poll.lock 2>/dev/null || stat -c %Y /tmp/rs-poll.lock 2>/dev/null || echo 0)
    now=${EPOCHSECONDS:-$(date +%s)}
    (( now - lock_ts > 30 )) && rm -f /tmp/rs-poll.lock || return
  fi
  local now=${EPOCHSECONDS:-$(date +%s)}
  (( now - _RS_LAST_POLL < _RS_POLL )) && return
  _RS_LAST_POLL=$now
  local -a servers=()
  while IFS=$'\t' read -r label server; do
    local jid=${label##*:}
    [[ $jid =~ ^[0-9]+$ && -n "$server" && "$server" != "-" ]] || continue
    (( ${servers[(I)$server]} )) || servers+=("$server")
  done < "$_RS_FILE"
  (( ${#servers} )) || return
  {
    echo $$ > /tmp/rs-poll.lock
    for srv in "${servers[@]}"; do
      if [[ "$srv" == "local" ]]; then
        ps -eo pid= | tr -d ' ' > "/tmp/rs-check-${srv}" 2>/dev/null
      else
        ssh -o ConnectTimeout=3 -o BatchMode=yes "$srv" \
          "squeue -u \$USER -h -o %i" > "/tmp/rs-check-${srv}.tmp" 2>/dev/null \
        && mv "/tmp/rs-check-${srv}.tmp" "/tmp/rs-check-${srv}" \
        || rm -f "/tmp/rs-check-${srv}.tmp"
      fi
    done
    rm -f /tmp/rs-poll.lock
  } &!
}

# ── 백그라운드 watcher (Claude Code 등 장시간 프로세스용) ──
_rs_watcher_alive() {
  [[ -f /tmp/rs-watcher.pid ]] && kill -0 $(cat /tmp/rs-watcher.pid) 2>/dev/null
}

_rs_watcher_start() {
  _rs_watcher_alive && return
  (
    echo $$ > /tmp/rs-watcher.pid
    while [[ -f "$_RS_FILE" ]]; do
      sleep "$_RS_POLL"
      [[ -f "$_RS_FILE" ]] || break
      _rs_poll_sync
      _rs_set_title
    done
    rm -f /tmp/rs-watcher.pid
  ) &!
}

_rs_watcher_stop() {
  [[ -f /tmp/rs-watcher.pid ]] && kill $(cat /tmp/rs-watcher.pid) 2>/dev/null
  rm -f /tmp/rs-watcher.pid
}

# ── precmd hook (일반 쉘용) ──
_rs_precmd() {
  _rs_poll_apply
  _rs_set_title
  _rs_poll_start
}

# ── 메인 명령어: st ──
st() {
  case "${1:-}" in
    add|exp)
      [[ -z "${2:-}" ]] && {
        echo "사용법: st add <name:id> [server]"
        echo "  server: soda, vegi, potato, local (생략=수동)"
        return 1
      }
      printf '%s\t%s\n' "$2" "${3:--}" >> "$_RS_FILE"
      _rs_set_title
      _rs_watcher_start
      ;;
    rm)
      [[ -z "${2:-}" ]] && { echo "사용법: st rm <label>"; return 1; }
      if [[ -f "$_RS_FILE" ]]; then
        awk -F'\t' -v lbl="$2" '$1 != lbl' "$_RS_FILE" > "${_RS_FILE}.tmp"
        mv -f "${_RS_FILE}.tmp" "$_RS_FILE"
        [[ -s "$_RS_FILE" ]] || rm -f "$_RS_FILE"
      fi
      _rs_set_title
      ;;
    off|clear)
      _rs_watcher_stop
      rm -f "$_RS_FILE" /tmp/rs-poll.lock
      setopt localoptions nonomatch; rm -f /tmp/rs-check-*
      _rs_set_title
      ;;
    check)
      local srv="${2:-}"
      if [[ -z "$srv" ]]; then
        echo "사용법: st check <server>  (soda, vegi, potato, local)"
        return 1
      fi
      echo "[$srv] 확인 중..."
      if [[ "$srv" == "local" ]]; then
        if [[ -f "$_RS_FILE" ]]; then
          while IFS=$'\t' read -r label server; do
            [[ "$server" == "local" ]] || continue
            local pid=${label##*:}
            if kill -0 "$pid" 2>/dev/null; then echo "  ✅ $label (running)"
            else echo "  ❌ $label (finished)"; fi
          done < "$_RS_FILE"
        fi
      else
        ssh -o ConnectTimeout=5 "$srv" \
          "squeue -u \$USER --format='%.8i %.30j %.8T %.10M'" 2>/dev/null \
          || echo "연결 실패"
      fi
      _RS_LAST_POLL=0
      ;;
    "")
      local n=$(_rs_count)
      if (( n > 0 )); then
        echo "🧪 실행 중: ${n}개"
        while IFS=$'\t' read -r label server; do
          [[ "$server" == "-" ]] && printf '  %s\n' "$label" \
                                 || printf '  %s [%s]\n' "$label" "$server"
        done < "$_RS_FILE"
      else echo "✅ 실험 없음"; fi
      ;;
    watch)
      while true; do
        clear; _rs_poll_apply
        local n=$(_rs_count)
        if (( n > 0 )); then
          echo "🧪 실행 중: ${n}개"
          while IFS=$'\t' read -r label server; do
            [[ "$server" == "-" ]] && printf '  %s\n' "$label" \
                                   || printf '  %s [%s]\n' "$label" "$server"
          done < "$_RS_FILE"
        else echo "✅ 실험 없음"; fi
        echo "\n(2초마다 갱신, Ctrl+C 종료)"
        _rs_poll_start; sleep 2
      done
      ;;
    *)
      echo "사용법: st {add <name:id> [server]|rm|off|check <server>|watch}"
      ;;
  esac
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _rs_precmd
# ── /experiment-tracker ──────────────────────
