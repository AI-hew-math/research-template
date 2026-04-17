#!/bin/bash
# bootstrap_logging.sh - 레거시 로깅 호환 부트스트랩
#
# Usage: ./scripts/bootstrap_logging.sh /path/to/existing_project
#
# 특징:
#   - 기존 파일 절대 덮어쓰지 않음
#   - 없는 디렉토리/스크립트만 추가
#   - EXPERIMENT_LOG.md가 있으면 마이그레이션 안내 생성
#
# Status:
#   - compatibility-only helper for older repos
#   - not the canonical way to start a new v2 repo
#   - prefer create_project.sh for new repos

set -e

TARGET_DIR="$1"

if [[ -z "$TARGET_DIR" ]]; then
    echo "Usage: ./scripts/bootstrap_logging.sh /path/to/existing_project" >&2
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory does not exist: $TARGET_DIR" >&2
    exit 1
fi

# 이 스크립트의 위치에서 템플릿 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 템플릿 위치 (두 가지 가능: research-template/scripts 또는 project/scripts)
# research-template에서 실행되는 경우
if [[ -f "$SCRIPT_DIR/../templates/scripts/run.sh" ]]; then
    TEMPLATE_DIR="$SCRIPT_DIR/../templates"
# 이미 복사된 프로젝트에서 실행되는 경우
elif [[ -f "$SCRIPT_DIR/run.sh" ]]; then
    TEMPLATE_DIR="$SCRIPT_DIR/.."
    # 이 경우 자기 자신을 템플릿으로 사용
    USE_SELF=1
else
    echo "Error: Cannot find template files" >&2
    exit 1
fi

echo "=========================================="
echo "Legacy Logging Compatibility Bootstrap"
echo "=========================================="
echo "Target: $TARGET_DIR"
echo "Note: new repos should be created with create_project.sh"
echo ""

CHANGES_MADE=0

# --- 디렉토리 생성 ---
create_dir_if_missing() {
    local dir="$1"
    if [[ ! -d "$TARGET_DIR/$dir" ]]; then
        mkdir -p "$TARGET_DIR/$dir"
        echo "✅ Created: $dir/"
        CHANGES_MADE=1
    else
        echo "⏭️  Exists: $dir/"
    fi
}

echo "--- Directories ---"
create_dir_if_missing "runs"
create_dir_if_missing "experiments/memos"
create_dir_if_missing "decisions"
create_dir_if_missing "scripts"
echo ""

# --- 스크립트 복사 ---
copy_script_if_missing() {
    local script="$1"
    local src

    if [[ -n "$USE_SELF" ]]; then
        src="$SCRIPT_DIR/$script"
    else
        src="$TEMPLATE_DIR/scripts/$script"
    fi

    local dst="$TARGET_DIR/scripts/$script"

    if [[ ! -f "$dst" ]]; then
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            chmod +x "$dst"
            echo "✅ Copied: scripts/$script"
            CHANGES_MADE=1
        else
            echo "⚠️  Source not found: $src"
        fi
    else
        echo "⏭️  Exists: scripts/$script"
    fi
}

echo "--- Scripts ---"
copy_script_if_missing "run.sh"
copy_script_if_missing "draft_memo.py"
copy_script_if_missing "bootstrap_logging.sh"
echo ""

# --- LOGGING.md 복사 ---
echo "--- Documentation ---"
if [[ ! -f "$TARGET_DIR/LOGGING.md" ]]; then
    if [[ -f "$TEMPLATE_DIR/LOGGING_README.md" ]]; then
        cp "$TEMPLATE_DIR/LOGGING_README.md" "$TARGET_DIR/LOGGING.md"
        echo "✅ Copied: LOGGING.md"
        CHANGES_MADE=1
    elif [[ -f "$TEMPLATE_DIR/templates/LOGGING_README.md" ]]; then
        cp "$TEMPLATE_DIR/templates/LOGGING_README.md" "$TARGET_DIR/LOGGING.md"
        echo "✅ Copied: LOGGING.md"
        CHANGES_MADE=1
    else
        echo "⏭️  LOGGING_README.md template not found"
    fi
else
    echo "⏭️  Exists: LOGGING.md"
fi
echo ""

# --- EXPERIMENT_LOG.md 마이그레이션 안내 ---
echo "--- Migration Check ---"
if [[ -f "$TARGET_DIR/EXPERIMENT_LOG.md" ]]; then
    if [[ ! -f "$TARGET_DIR/LOGGING_MIGRATION_NOTE.md" ]]; then
        cat > "$TARGET_DIR/LOGGING_MIGRATION_NOTE.md" << 'EOF'
# Logging System Migration Note

이 프로젝트에 3카드 로깅 시스템이 추가되었습니다.

## 기존 EXPERIMENT_LOG.md

기존 `EXPERIMENT_LOG.md`는 그대로 유지됩니다. 수동으로 마이그레이션할 필요는 없습니다.

## 새로운 워크플로우

새 실험부터는 다음 워크플로우를 권장합니다:

### 1. 실험 실행

```bash
./scripts/run.sh --exp <실험명> <명령어>
```

자동으로 `runs/<RUN_ID>/`에 Run Card와 로그가 생성됩니다.

### 2. 분석 후 Memo 작성

```bash
python3 ./scripts/draft_memo.py --memo_id <메모ID> --goal "<목표>" --runs <RUN_ID1> <RUN_ID2>
```

`experiments/memos/<메모ID>.md`에 초안이 생성됩니다.

### 3. 중요 결정 시 Decision Record 작성

`decisions/DR-NNN_<제목>.md` 파일을 수동으로 작성합니다.

## 권장 전환 방법

1. 기존 EXPERIMENT_LOG.md는 히스토리로 보존
2. 새 실험부터 `./scripts/run.sh` 사용
3. 기존 로그 참조가 필요하면 EXPERIMENT_LOG.md 참조

## 추가 정보

자세한 내용은 `LOGGING.md`를 참조하세요.
EOF
        echo "✅ Created: LOGGING_MIGRATION_NOTE.md (EXPERIMENT_LOG.md 발견)"
        CHANGES_MADE=1
    else
        echo "⏭️  Exists: LOGGING_MIGRATION_NOTE.md"
    fi
else
    echo "ℹ️  No EXPERIMENT_LOG.md found (clean start)"
fi
echo ""

# --- 요약 ---
echo "=========================================="
if [[ $CHANGES_MADE -eq 1 ]]; then
    echo "✅ Bootstrap complete!"
else
    echo "ℹ️  No changes needed (already set up)"
fi
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. ./scripts/run.sh --exp test echo hello"
echo "  3. Read LOGGING.md for usage guide"
echo "=========================================="
