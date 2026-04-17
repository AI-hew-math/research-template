# {{PROJECT_NAME}}

> {{DESCRIPTION}}

## Overview

<!-- High-level project overview -->

## Operating Docs

- `AGENTS.md` - canonical operating rules
- `CLAUDE.md` - thin wrapper for tool compatibility
- `MEMORY.md` - current state only
- `reviews/README.md` - canonical Claude↔GPT review loop
- `.codex/skills/` - reusable local skills for repeated workflows

Shared workflow support:

- `reviews/` - canonical review-cycle docs
- `.codex/skills/` - reusable local workflow skills

Optional profile overlays:

- `CONCEPT.md` - durable project brief
- `EXPERIMENT_LOG.md` - concise ledger
- `history/` - detailed history
- `decisions/` - decision records
- `ARCHIVE.md` - frozen repo contract

## Current State

See `MEMORY.md` for the live project state.

## Structure

```text
{{PROJECT_NAME}}/
├── AGENTS.md
├── CLAUDE.md
├── MEMORY.md
├── README.md
└── ...
```

## Notes

Choose additional profile overlays based on the repo type. Do not assume every repo needs the full research structure.

If legacy compatibility paths such as `.claude/`, `review_cycles/`, or `experiments/memos/` appear in this repo, treat them as compatibility-only helpers rather than the primary v2 workflow.
