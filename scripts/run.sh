#!/bin/bash
# Root wrapper for run.sh (템플릿 개발자용 스모크 테스트)
# Usage: ./scripts/run.sh --exp <name> <command>
#
# Note: 템플릿 레포 자체에서 run.sh 동작을 테스트할 때 사용
# 실제 프로젝트에서는 프로젝트 내 scripts/run.sh 사용

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../templates/scripts/run.sh" "$@"
