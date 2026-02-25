# ── experiment-tracker v2: 3-tier detection ──────────────────
# https://github.com/AI-hew-math/research-template
#
# 설치: source 이 파일을 ~/.zshrc에 추가
# 요구: Ghostty 터미널 + shell-integration-features = no-title
#
# 감지 우선순위:
#   (1) job metadata: --comment="rs:ProjectName" 또는 job name prefix "ProjectName_"
#   (2) 전역 path cache: ~/.rs-path-map (rs_claim으로 등록)
#   (3) 프로젝트 .experiment-paths 파일 (경계 매칭)
#
# 사용법:
#   st add fair_A:12727 soda    ← SLURM job, soda에서 자동 완료 감지
#   st add topo_B:13000 vegi    ← SLURM job, vegi에서 자동 완료 감지
#   st add train:1234 local     ← 로컬 PID 자동 완료 감지
#   st add my_experiment        ← 수동 관리 (자동 감지 없음)
#   st rm  fair_A:12727         ← 제거 (수동+자동 모두)
#   st off                      ← 전부 해제
#   st                          ← 현재 상태 (자동/수동 구분 표시)
#   st check soda               ← 서버 squeue 직접 확인
#   st watch                    ← 실시간 모니터
#   st map                      ← 경로 캐시 보기
#
# 보조 명령:
#   rs_claim <server> <jobid> [project]  ← job workdir → 프로젝트 매핑 캐시
#   rs_sbatch <server> <script> [args]   ← 프로젝트 태그 자동 삽입 + tracker 등록
#
# 파일 구조:
#   /tmp/research-exps       ← 수동 등록 (st add)
#   /tmp/research-exps.auto  ← 자동 감지 (claude 시작 시)
#   ~/.rs-path-map           ← 전역 경로→프로젝트 캐시 (rs_claim)
#   {project}/.experiment-paths ← 프로젝트별 경로 패턴 (Tier 3 fallback)
#
# 탭 타이틀 형식:
#   실험 있을 때: "폴더명 : 🧪×N label1, label2, ..."
#   실험 없을 때: "폴더명"
# ─────────────────────────────────────────────

zmodload zsh/datetime 2>/dev/null

_RS_FILE="/tmp/research-exps"
_RS_AUTO="/tmp/research-exps.auto"
_RS_MERGED="/tmp/research-exps.merged"
_RS_PATH_MAP="$HOME/.rs-path-map"
_RS_SERVERS=(${RS_SERVERS:-soda vegi potato})
_RS_POLL=${RS_POLL:-60}
_RS_LAST_POLL=0

# ── 헬퍼 함수 ──

# 경로 경계 매칭: substring이 아니라 / 경계에서만 매칭
# /projects/OCRL → .../projects/OCRL (O), .../myprojects/OCRL (X)
_rs_path_match() {
  local workdir="${1%/}" pattern="${2%/}"
  [[ "$workdir" == "$pattern" ]] && return 0
  [[ "$workdir" == "$pattern"/* ]] && return 0
  if [[ "$pattern" == /* ]]; then
    [[ "$workdir" == *"$pattern" ]] && return 0
    [[ "$workdir" == *"$pattern"/* ]] && return 0
  else
    [[ "$workdir" == */"$pattern" ]] && return 0
    [[ "$workdir" == */"$pattern"/* ]] && return 0
  fi
  return 1
}

# 수동 + 자동 파일 병합 (읽기 전용 뷰)
_rs_merge() {
  : > "$_RS_MERGED"
  [[ -f "$_RS_FILE" ]] && cat "$_RS_FILE" >> "$_RS_MERGED"
  [[ -f "$_RS_AUTO" ]] && cat "$_RS_AUTO" >> "$_RS_MERGED"
  [[ -s "$_RS_MERGED" ]] || rm -f "$_RS_MERGED"
}

_rs_count() {
  _rs_merge
  [[ -f "$_RS_MERGED" ]] && wc -l < "$_RS_MERGED" | tr -d ' ' || echo 0
}

# ── TTY 감지 (Claude Code 내부에서도 동작) ──
# /dev/tty → 부모 프로세스 체인에서 실제 TTY 탐색
_rs_find_tty() {
  if print -n "" > /dev/tty 2>/dev/null; then
    echo "/dev/tty"; return
  fi
  local pid=$$ p_tty
  while (( pid > 1 )); do
    p_tty=$(ps -p $pid -o tty= 2>/dev/null | tr -d ' ')
    if [[ -n "$p_tty" ]] && [[ "$p_tty" != "??" ]] && [[ -w "/dev/$p_tty" ]]; then
      echo "/dev/$p_tty"; return
    fi
    pid=$(ps -p $pid -o ppid= 2>/dev/null | tr -d ' ')
  done
  return 1
}

_rs_set_title() {
  _rs_merge
  local dir=${PWD##*/} n=$(_rs_count) title
  if (( n > 0 )); then
    local all=$(awk -F'\t' '{printf "%s%s",(NR>1?", ":""),$1}' "$_RS_MERGED" 2>/dev/null)
    title="${dir} : 🧪×${n} ${all}"
  else
    title="${dir}"
  fi
  local tgt=$(_rs_find_tty)
  if [[ -n "$tgt" ]]; then
    printf '\e]0;%s\a' "$title" > "$tgt" 2>/dev/null
  else
    print -Pn "\e]0;${title}\a"
  fi
}

# ── 3-tier 자동 감지 ──
_rs_auto_detect() {
  local proj_name="${PWD##*/}"
  [[ -z "$proj_name" ]] && return 0

  local paths_file="${PWD}/.experiment-paths"

  echo "🔍 서버 실험 스캔 중... (project: $proj_name)"

  # auto 파일만 초기화 (수동 등록은 보존)
  rm -f "$_RS_AUTO"

  # Tier 3 패턴 읽기
  local -a t3_patterns=()
  if [[ -f "$paths_file" ]]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      t3_patterns+=("${line%/}")
    done < "$paths_file"
  fi

  # Tier 2 경로 캐시 읽기
  local -A t2_map=()
  if [[ -f "$_RS_PATH_MAP" ]]; then
    while IFS=$'\t' read -r mpath mproj; do
      [[ "$mpath" =~ ^#.*$ || -z "$mpath" ]] && continue
      t2_map["${mpath%/}"]="$mproj"
    done < "$_RS_PATH_MAP"
  fi

  # 서버별 SLURM job 스캔 (병렬, %k = comment)
  local tmpdir=$(mktemp -d)
  {
    setopt localoptions NO_MONITOR
    for srv in "${_RS_SERVERS[@]}"; do
      ssh -o ConnectTimeout=3 -o BatchMode=yes "$srv" \
        "squeue -u \$USER -h --format='%i|%j|%Z|%k'" > "${tmpdir}/${srv}" 2>/dev/null &
    done
    wait
  } 2>/dev/null

  local -A seen=()
  local found=0

  for srv in "${_RS_SERVERS[@]}"; do
    local result="${tmpdir}/${srv}"
    [[ -f "$result" && -s "$result" ]] || continue

    while IFS='|' read -r jobid jobname workdir comment; do
      local base_id="${jobid%%_*}"
      base_id="${base_id%%\[*}"
      base_id=$(echo "$base_id" | tr -d ' ')
      local dedup_key="${srv}:${base_id}"
      [[ -n "${seen[$dedup_key]+x}" ]] && continue

      local matched=false

      # TIER 1a: comment 태그 (rs:ProjectName)
      if [[ "$comment" == *"rs:${proj_name}"* ]]; then
        matched=true
      fi
      # TIER 1b: job name prefix (ProjectName_*)
      if ! $matched && [[ "$jobname" == "${proj_name}_"* ]]; then
        matched=true
      fi

      # TIER 2: 전역 경로 캐시 (경계 매칭)
      if ! $matched; then
        for mpath in "${(@k)t2_map}"; do
          if [[ "${t2_map[$mpath]}" == "$proj_name" ]] && _rs_path_match "$workdir" "$mpath"; then
            matched=true; break
          fi
        done
      fi

      # TIER 3: 프로젝트 .experiment-paths (경계 매칭)
      if ! $matched; then
        for pat in "${t3_patterns[@]}"; do
          if _rs_path_match "$workdir" "$pat"; then
            matched=true; break
          fi
        done
      fi

      if $matched; then
        seen[$dedup_key]=1
        printf '%s:%s\t%s\n' "$jobname" "$base_id" "$srv" >> "$_RS_AUTO"
        (( found++ ))
      fi
    done < "$result"
  done
  rm -rf "$tmpdir"

  if (( found > 0 )); then
    echo "✅ ${found}개 실험 감지 → tracker 등록"
    while IFS=$'\t' read -r label server; do
      printf '  🧪 %s [%s]\n' "$label" "$server"
    done < "$_RS_AUTO"
  else
    echo "✅ 실행 중인 실험 없음"
  fi
  if [[ -f "$_RS_FILE" ]] && [[ -s "$_RS_FILE" ]]; then
    echo "📌 수동 등록: $(wc -l < "$_RS_FILE" | tr -d ' ')개"
  fi
}

# ── rs_claim: job의 workdir를 프로젝트에 매핑 → 전역 캐시 저장 ──
rs_claim() {
  local srv="$1" jobid="$2" proj="${3:-${PWD##*/}}"
  if [[ -z "$srv" || -z "$jobid" ]]; then
    echo "사용법: rs_claim <server> <jobid> [project_name]"
    echo "  서버 job의 WORK_DIR을 project에 매핑 → ~/.rs-path-map 저장"
    return 1
  fi
  echo "[$srv] Job $jobid 경로 조회 중..."
  local workdir
  workdir=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$srv" \
    "squeue -j $jobid -h --format='%Z'" 2>/dev/null | tr -d ' ')
  if [[ -z "$workdir" ]]; then
    echo "❌ Job $jobid 없음 (완료됐거나 존재하지 않음)"
    return 1
  fi
  workdir="${workdir%/}"
  if [[ -f "$_RS_PATH_MAP" ]] && awk -F'\t' -v p="$workdir" '$1==p {found=1} END{exit !found}' "$_RS_PATH_MAP" 2>/dev/null; then
    local existing=$(awk -F'\t' -v p="$workdir" '$1==p {print $2}' "$_RS_PATH_MAP")
    echo "⚠️  이미 매핑됨: $workdir → $existing"
    return 1
  fi
  printf '%s\t%s\n' "$workdir" "$proj" >> "$_RS_PATH_MAP"
  echo "✅ 매핑 저장: $workdir → $proj"
  local base_id="${jobid%%_*}"
  local jobname
  jobname=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$srv" \
    "squeue -j $jobid -h --format='%j'" 2>/dev/null | tr -d ' ')
  [[ -z "$jobname" ]] && jobname="claimed"
  printf '%s:%s\t%s\n' "$jobname" "$base_id" "$srv" >> "$_RS_AUTO"
  _rs_set_title
  echo "  🧪 ${jobname}:${base_id} [${srv}] → tracker에 추가됨"
}

# ── rs_sbatch: project 태그 자동 삽입 + tracker 등록 ──
rs_sbatch() {
  local srv="$1" script="$2"
  if [[ -z "$srv" || -z "$script" ]]; then
    echo "사용법: rs_sbatch <server> <script> [sbatch_args...]"
    echo "  --comment='rs:project' 자동 추가 + tracker 등록"
    return 1
  fi
  shift 2
  local proj="${RS_PROJECT:-${PWD##*/}}"
  local comment_tag="rs:${proj}"
  local user_comment=""
  local -a pass_args=()
  for arg in "$@"; do
    if [[ "$arg" == --comment=* ]]; then
      user_comment="${arg#--comment=}"
    else
      pass_args+=("$arg")
    fi
  done
  local final_comment
  if [[ -n "$user_comment" ]]; then
    final_comment="${user_comment},${comment_tag}"
  else
    final_comment="${comment_tag}"
  fi
  echo "[${srv}] sbatch ${script} (project: ${proj})"
  local output
  output=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$srv" \
    "sbatch --comment='${final_comment}' ${pass_args[*]} ${script}" 2>&1)
  echo "$output"
  local new_jobid
  new_jobid=$(echo "$output" | grep -oE '[0-9]+$')
  if [[ -n "$new_jobid" ]]; then
    local jobname="${proj}_${script%.*}"
    jobname="${jobname##*/}"
    printf '%s:%s\t%s\n' "$jobname" "$new_jobid" "$srv" >> "$_RS_AUTO"
    _rs_set_title
    echo "  🧪 ${jobname}:${new_jobid} [${srv}] → tracker에 추가됨"
  fi
}

# ── 서버별 squeue/ps 체크 (동기) ──
_rs_poll_sync() {
  _rs_merge
  [[ -f "$_RS_MERGED" ]] || return
  setopt localoptions nonomatch
  local -a servers=()
  while IFS=$'\t' read -r label server; do
    local jid=${label##*:}
    [[ $jid =~ ^[0-9]+$ && -n "$server" && "$server" != "-" ]] || continue
    (( ${servers[(I)$server]} )) || servers+=("$server")
  done < "$_RS_MERGED"
  (( ${#servers} )) || return
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
  _rs_poll_apply
}

# ── 끝난 job 제거 (수동/자동 파일 각각 처리) ──
_rs_poll_apply() {
  setopt localoptions nonomatch
  local has_checks=false
  for f in /tmp/rs-check-*; do [[ -f "$f" ]] && { has_checks=true; break; }; done
  $has_checks || return
  local src
  for src in "$_RS_FILE" "$_RS_AUTO"; do
    [[ -f "$src" ]] || continue
    local changed=false tmp="${src}.tmp"
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
    done < "$src"
    if $changed; then
      [[ -s "$tmp" ]] && mv "$tmp" "$src" || rm -f "$tmp" "$src"
    else
      rm -f "$tmp"
    fi
  done
  rm -f /tmp/rs-check-*
}

# ── 비동기 폴링 (precmd용) ──
_rs_poll_start() {
  _rs_merge
  [[ -f "$_RS_MERGED" ]] || return
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
  done < "$_RS_MERGED"
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

# ── 백그라운드 watcher ──
_rs_watcher_alive() {
  [[ -f /tmp/rs-watcher.pid ]] && kill -0 $(cat /tmp/rs-watcher.pid) 2>/dev/null
}

_rs_watcher_start() {
  _rs_watcher_alive && return
  (
    echo $$ > /tmp/rs-watcher.pid
    while true; do
      sleep "$_RS_POLL"
      _rs_merge
      [[ -f "$_RS_MERGED" ]] || break
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
      for src in "$_RS_FILE" "$_RS_AUTO"; do
        if [[ -f "$src" ]]; then
          awk -F'\t' -v lbl="$2" '$1 != lbl' "$src" > "${src}.tmp"
          mv -f "${src}.tmp" "$src"
          [[ -s "$src" ]] || rm -f "$src"
        fi
      done
      _rs_set_title
      ;;
    off|clear)
      _rs_watcher_stop
      rm -f "$_RS_FILE" "$_RS_AUTO" "$_RS_MERGED" /tmp/rs-poll.lock
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
        _rs_merge
        if [[ -f "$_RS_MERGED" ]]; then
          while IFS=$'\t' read -r label server; do
            [[ "$server" == "local" ]] || continue
            local pid=${label##*:}
            if kill -0 "$pid" 2>/dev/null; then echo "  ✅ $label (running)"
            else echo "  ❌ $label (finished)"; fi
          done < "$_RS_MERGED"
        fi
      else
        ssh -o ConnectTimeout=5 "$srv" \
          "squeue -u \$USER --format='%.8i %.30j %.8T %.10M'" 2>/dev/null \
          || echo "연결 실패"
      fi
      _RS_LAST_POLL=0
      ;;
    "")
      _rs_merge
      local n=$(_rs_count)
      if (( n > 0 )); then
        echo "🧪 실행 중: ${n}개"
        if [[ -f "$_RS_AUTO" ]] && [[ -s "$_RS_AUTO" ]]; then
          echo "  [자동 감지]"
          while IFS=$'\t' read -r label server; do
            printf '    %s [%s]\n' "$label" "$server"
          done < "$_RS_AUTO"
        fi
        if [[ -f "$_RS_FILE" ]] && [[ -s "$_RS_FILE" ]]; then
          echo "  [수동 등록]"
          while IFS=$'\t' read -r label server; do
            [[ "$server" == "-" ]] && printf '    %s\n' "$label" \
                                   || printf '    %s [%s]\n' "$label" "$server"
          done < "$_RS_FILE"
        fi
      else echo "✅ 실험 없음"; fi
      ;;
    watch)
      while true; do
        clear; _rs_poll_apply; _rs_merge
        local n=$(_rs_count)
        if (( n > 0 )); then
          echo "🧪 실행 중: ${n}개"
          while IFS=$'\t' read -r label server; do
            [[ "$server" == "-" ]] && printf '  %s\n' "$label" \
                                   || printf '  %s [%s]\n' "$label" "$server"
          done < "$_RS_MERGED"
        else echo "✅ 실험 없음"; fi
        echo "\n(2초마다 갱신, Ctrl+C 종료)"
        _rs_poll_start; sleep 2
      done
      ;;
    map)
      if [[ -f "$_RS_PATH_MAP" ]]; then
        echo "📂 경로 매핑 (~/.rs-path-map):"
        while IFS=$'\t' read -r mpath mproj; do
          [[ "$mpath" =~ ^#.*$ || -z "$mpath" ]] && continue
          printf '  %s → %s\n' "$mpath" "$mproj"
        done < "$_RS_PATH_MAP"
      else
        echo "매핑 없음 (rs_claim <server> <jobid> 로 추가)"
      fi
      ;;
    *)
      echo "사용법: st {add|rm|off|check|watch|map}"
      echo "  st add <name:id> [server]  수동 등록"
      echo "  st rm <label>              제거 (수동+자동)"
      echo "  st off                     전부 해제"
      echo "  st check <server>          서버 큐 확인"
      echo "  st watch                   실시간 모니터"
      echo "  st map                     경로 캐시 보기"
      echo "보조 명령:"
      echo "  rs_claim <server> <jobid> [project]  경로 매핑 등록"
      echo "  rs_sbatch <server> <script> [args]   태그 포함 제출"
      ;;
  esac
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _rs_precmd
# ── /experiment-tracker ──────────────────────────────────────
