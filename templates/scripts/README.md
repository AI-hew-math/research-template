# Legacy Compatibility Scripts

This directory contains legacy research-helper scripts that remain available for safe compatibility.

## Status

- Compatibility-only as a directory-level bundle.
- Not the canonical explanation of the v2 workflow.
- Some individual scripts are still useful utilities, but the review loop itself should be driven from `reviews/README.md` and `.codex/skills/`.

## Canonical v2 Path

Prefer these first:

- `reviews/README.md`
- `reviews/cycles/CYCLE_TEMPLATE/`
- `.codex/skills/prepare-review-packet/`
- `.codex/skills/ingest-gpt-review/`
- `.codex/skills/synthesize-next-prompt/`
- `.codex/skills/close-cycle/`

## Script Status

- `run.sh`: compatibility utility for reproducible run capture
- `draft_memo.py`: compatibility utility for old memo flow
- `git_snap.sh`: compatibility utility
- `bootstrap_logging.sh`: deprecated bootstrap helper for older repos
- `save_clipboard_to_gpt_review.sh`: deprecated import helper
- `save_clipboard_to_next_prompt.sh`: deprecated import helper
