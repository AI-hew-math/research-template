# Deprecated Compatibility Asset

This legacy memo format is retained only for helper-script compatibility.

## Status

- Compatibility-only.
- Not the canonical place for experiment history in v2.
- Prefer `history/experiments/EXPERIMENT_DETAIL.md` for detailed writeups and `EXPERIMENT_LOG.md` for index-level tracking.

## Mapping To v2

- Legacy memo observations and inferences map most naturally into `history/experiments/`.
- Any current blocker, go/stop decision, or next action discovered from a memo should also update `MEMORY.md`.
- Any meaningful checkpoint reached through memo analysis should add one concise row to `EXPERIMENT_LOG.md`.

## Why It Still Exists

`scripts/draft_memo.py` still creates files under `experiments/memos/` for compatibility with older research repos. Keep using it only when that legacy helper flow is still useful.
