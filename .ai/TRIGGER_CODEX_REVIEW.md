완전한 REVIEW+ADVANCE 절차 (Brain/Codex)

P1 정책: Codex는 코드 직접 수정 금지. 예상 범위를 벗어난 변경이 있으면 REQUEST_CHANGES로 중단.

1) main 최신화
git checkout main && git pull origin main

2) ai/claude 가져오기
git fetch origin ai/claude:ai/claude
git checkout ai/claude

3) RUN_ID / transcript 확인
RUN_ID=$(cat .ai/LAST_RUN_ID | tr -d '[:space:]')
test -f .ai/transcripts/claude_${RUN_ID}.md && test -s .ai/transcripts/claude_${RUN_ID}.md

4) 리뷰 근거 수집
git diff origin/main...ai/claude
transcript 요약(의도/명령/출력/편차)을 3~6줄로 정리

5) (필수) Whitelist guard
main merge 전에 반드시 다음을 실행:
scripts/guard_codex_whitelist.sh origin/main ai/claude

guard 실패 시: 승인/merge/push 금지(절대 진행 금지). REQUEST_CHANGES 출력 후 즉시 종료:
scripts/guard_codex_whitelist.sh origin/main ai/claude || { echo "REQUEST_CHANGES"; echo "Do NOT approve/merge/push"; exit 1; }

6) 재현 실행(필수)
make test; echo EXIT=$?

7) 승인 파일 생성(필수)
.ai/approvals/${RUN_ID}.approved 를 생성하고 아래 최소 항목을 포함:
- verdict: APPROVE
- run_id: ${RUN_ID}
- reviewed_commit: <ai/claude HEAD SHA>
- base: <origin/main SHA>
- commands_run: make test (EXIT + 실제 출력 핵심 1~3줄)
- notes: 근거 1~3줄

8) 승인 커밋 -> ai/claude 푸시
git add .ai/approvals/${RUN_ID}.approved
git commit -m "approve: ${RUN_ID}"
git push origin ai/claude

9) main 머지 + gate 확인 + push
git checkout main
git merge --no-ff ai/claude
./scripts/ai_gate.sh  # OK 아니면 즉시 중단: origin/main push 금지
./scripts/ai_gate.sh || { echo "BLOCKED"; exit 1; }
git push origin main

10) 다음 사이클 준비
.ai/PLAN.md / .ai/HANDOFF_TO_CLAUDE.md / .ai/STATE.md 갱신 후 main에 커밋/푸시

마지막 줄: CYCLE_COMPLETE_READY_FOR_CLAUDE
