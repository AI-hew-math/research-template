# close-cycle

Use this skill after a meaningful Claude iteration finishes.

## Goal

Close the loop by updating current state, ledger, and detailed history without letting any one file absorb the whole narrative.

## Steps

1. Update `MEMORY.md` immediately with:
   - current phase
   - pending actions
   - blockers
   - decisions
   - important path or environment changes
2. If a meaningful checkpoint was reached, append one concise row to `EXPERIMENT_LOG.md`.
3. Update or create the relevant detail doc under `history/experiments/` or `history/phases/`.
4. Update a decision record when the cycle produced a durable decision.
5. Make sure the cycle docs point to the detail docs they created or used.

## Guardrails

- `MEMORY.md` is current state, not history.
- `EXPERIMENT_LOG.md` is a ledger, not a narrative dump.
- Keep one source of truth for each kind of information.
