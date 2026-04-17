# Deprecated Compatibility Asset

This file documents the legacy run-card shape used by helper scripts.

## Status

- Compatibility-only.
- Not part of the minimal v2 authority contract.
- New repos should treat `MEMORY.md`, `EXPERIMENT_LOG.md`, `history/`, and `reviews/` as the canonical state/history/review structure.

## Why It Still Exists

Research compatibility helpers such as `scripts/run.sh` still emit run cards under `runs/`.
That output can remain useful as evidence, but it should feed into:

- `history/experiments/` for detailed writeups
- `EXPERIMENT_LOG.md` for compact indexing
- `MEMORY.md` for current state changes

