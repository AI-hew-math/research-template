# Reviews

> Canonical review-loop guide for the v2 template.

## Canonical Files

- `reviews/cycles/CYCLE_TEMPLATE/REVIEW_PACKET.md`
- `reviews/cycles/CYCLE_TEMPLATE/GPT_REVIEW.md`
- `reviews/cycles/CYCLE_TEMPLATE/NEXT_PROMPT.md`
- `.codex/skills/prepare-review-packet/`
- `.codex/skills/ingest-gpt-review/`
- `.codex/skills/synthesize-next-prompt/`
- `.codex/skills/close-cycle/`

## Cycle Workflow

1. Create a new cycle directory, for example `reviews/cycles/CYCLE-0001/`, by copying `reviews/cycles/CYCLE_TEMPLATE/`.
2. Fill `REVIEW_PACKET.md` from `MEMORY.md`, `EXPERIMENT_LOG.md`, and the relevant detail docs.
3. Store external review feedback in `GPT_REVIEW.md`.
4. Synthesize the next Claude handoff in `NEXT_PROMPT.md`.
5. After execution, update `MEMORY.md`, append one concise ledger entry if needed, and update the linked history or decision docs.

## What Gets Updated After Each Meaningful Cycle

- `MEMORY.md` for current phase, blockers, decisions, and pending actions
- `EXPERIMENT_LOG.md` for one concise review or experiment checkpoint row when appropriate
- `history/experiments/` or `history/phases/` for detailed outcomes
- `decisions/` when a major decision was made

## Legacy Compatibility

If this repo also contains `.claude/`, `review_cycles/`, clipboard review helpers, or `experiments/memos/`, treat them as compatibility-only paths. They are not the primary v2 review loop.
