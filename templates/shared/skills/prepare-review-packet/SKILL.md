# prepare-review-packet

Use this skill when you need to assemble a compact review handoff for the current cycle.

## Goal

Create or refresh `reviews/cycles/CYCLE-####/REVIEW_PACKET.md` without turning it into a history dump.

## Steps

1. Find the active cycle directory or create a new one by copying `reviews/cycles/CYCLE_TEMPLATE/`.
2. Read `MEMORY.md`, the most relevant ledger rows in `EXPERIMENT_LOG.md`, and the linked detail or decision docs.
3. Summarize only the current goal, the meaningful changes since the last checkpoint, the strongest evidence, and the concrete review questions.
4. Link to the detailed docs instead of duplicating long narratives.
5. If bulky outputs are needed, place them under `reviews/cycles/CYCLE-####/artifacts/` and mention them in the packet.

## Output

- Updated `REVIEW_PACKET.md`
- Optional `artifacts/` references

## Guardrails

- Do not move current state into `CONCEPT.md`.
- Do not paste large experiment history into the review packet.
- Prefer one cycle per meaningful iteration, not one cycle per prompt by default.
