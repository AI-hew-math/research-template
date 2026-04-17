# Legacy Compatibility Bundle

This `.claude/` directory is retained only as a compatibility path for older hook-based workflows.

## Status

- Compatibility-only for research profile scaffolds.
- Not the canonical v2 review loop.
- Do not depend on this directory to understand the primary template contract.

## Canonical v2 Path

Use these paths first:

- `AGENTS.md`
- `MEMORY.md`
- `EXPERIMENT_LOG.md`
- `reviews/README.md`
- `reviews/cycles/CYCLE_TEMPLATE/`
- `.codex/skills/`

## What Still Uses This

- Legacy hook exports into `review_cycles/`
- Older helper flows that expect Claude hook integration

If those helpers are not needed, ignore this directory.
