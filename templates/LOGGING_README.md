# Deprecated Compatibility Asset

This file is retained only for legacy research-helper compatibility.

## Status

- Do not treat this as the canonical v2 operating guide.
- New repositories should use `AGENTS.md`, `MEMORY.md`, `EXPERIMENT_LOG.md`, `history/`, `reviews/README.md`, and repo-local skills under `.codex/skills/`.
- The legacy 3-card helper scripts may still create `runs/`, `experiments/memos/`, and `decisions/`, but those are no longer the authoritative explanation of the full v2 workflow.

## Current Canonical Paths

- Current state: `MEMORY.md`
- Research ledger: `EXPERIMENT_LOG.md`
- Detailed history: `history/experiments/` and `history/phases/`
- Review loop: `reviews/cycles/CYCLE-####/`
- Reusable workflow instructions: `.codex/skills/`

## Legacy Helper Scope

The old logging helpers remain available only for safe compatibility:

- `scripts/run.sh`
- `scripts/draft_memo.py`
- `scripts/bootstrap_logging.sh`

If you need to keep using them, do so as auxiliary utilities. Do not let them replace the v2 authority model or the canonical review-cycle structure.
