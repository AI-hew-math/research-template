main에서 `origin/main`을 pull하고 `ai/claude` 브랜치로 전환한 뒤, `.ai/HANDOFF_TO_CLAUDE.md`를 그대로 실행하세요.

1) 최신화/브랜치
git checkout main && git pull origin main
git checkout -B ai/claude

2) HANDOFF 실행 -> 테스트
(.ai/HANDOFF_TO_CLAUDE.md의 지시대로 변경)
make test

3) RUN_ID 생성
RUN_ID=$(TEST_CMD="make test" ./scripts/ai_pack.sh | tail -n 1)

4) transcript 생성/검증
- Claude 입력창에서 `/export .ai/transcripts/claude_${RUN_ID}.md` 시도
- Bash에서 `test -s .ai/transcripts/claude_${RUN_ID}.md` 확인
- 실패 시 fallback 규격(Objective / Commands run / Key outputs / Deviations)으로 동일 경로에 직접 작성 후 `test -s` 재확인

5) 커밋/푸시
git add -A
git status -sb
git commit -m "run: ${RUN_ID}"
git push origin ai/claude || git push --force-with-lease origin ai/claude

마지막 줄: READY_FOR_CODEX
