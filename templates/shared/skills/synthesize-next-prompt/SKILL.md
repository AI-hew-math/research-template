# synthesize-next-prompt

Use this skill after review ingestion to prepare the next Claude handoff.

## Goal

Write `reviews/cycles/CYCLE-####/NEXT_PROMPT.md` so the next Claude iteration has a clear objective, constraints, and required stop updates.

## Steps

1. Read the current cycle's `REVIEW_PACKET.md` and `GPT_REVIEW.md`.
2. Re-check `MEMORY.md` and any linked detail docs to confirm the live state.
3. Distill the next step into:
   - one objective
   - a short state recap
   - required actions
   - constraints
   - required updates before stopping
   - a clear stop condition
4. Keep the prompt actionable and specific to the repo's current state.

## Guardrails

- Do not restate the whole project history.
- Do not hide important constraints or blockers.
- Make sure the prompt explicitly names the docs that must be updated before the cycle closes.
