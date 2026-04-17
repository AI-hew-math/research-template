# migrate-v1-to-v2

Use this skill when an older downstream repo created from the v1 template should be retrofitted to the v2 structure.

## Goal

Plan and execute a safe migration from legacy instruction/logging/review sprawl into the v2 authority contract.

## Steps

1. Inventory the current instruction stack and identify competing authority files.
2. Add or confirm:
   - canonical `AGENTS.md`
   - thin `CLAUDE.md`
   - root `MEMORY.md`
3. Split current-state material away from old summary/history documents.
4. Convert `EXPERIMENT_LOG.md` into a ledger and move long history into detail docs.
5. Introduce `reviews/cycles/` as the canonical review path.
6. Keep `.claude/`, `review_cycles/`, old memos, or helper scripts only as compatibility paths when removal would be risky.
7. Verify the migrated repo's docs clearly say what is canonical and what is legacy-only.

## Guardrails

- Do not overwrite downstream history blindly.
- Prefer wrappers and migration notes over destructive cleanup.
- Migration tooling and repo-by-repo execution are separate from the template change itself.
