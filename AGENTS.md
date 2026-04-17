# research-template v2

> Canonical operating rules for this repository.
> Keep this file short and treat it as the always-loaded authority.

## Authority

- `AGENTS.md` is the canonical instruction file for this repo.
- `CLAUDE.md` must remain a thin wrapper that points to `AGENTS.md`.
- `V2_TEMPLATE_DESIGN.md` explains the human-facing design and migration intent.
- `templates/base/`, `templates/profiles/`, and `templates/shared/` are the v2 template source of truth.
- Repo-local skills for scaffolded projects live under `templates/shared/skills/`.
- Legacy top-level files under `templates/` and legacy research helpers remain compatibility assets only. Do not treat them as the v2 source of truth.

## Editing Rules

- Keep always-loaded instructions short.
- Do not reintroduce long workflow manuals into `AGENTS.md`.
- Keep `MEMORY.md` as current state only.
- Keep `EXPERIMENT_LOG.md` as a concise ledger only.
- Put detailed history in dedicated history docs, not in `MEMORY.md`, `CONCEPT.md`, or `EXPERIMENT_LOG.md`.
- Keep review-loop mechanics in reusable templates and later skills, not in long always-loaded prose.
- Keep the canonical review loop centered on `reviews/cycles/CYCLE-####/`, not on legacy clipboard or hook exports.

## Working In This Repo

- When changing the template contract, update the design doc and README in the same pass.
- Preserve the `base / profiles / shared` split.
- Prefer deprecating risky legacy pieces over deleting them when compatibility risk is unclear.
- Do not make the heavy research profile the default mental model for every future repo.

## Stage Boundary

- Stage 1 established the authority model and the new template tree.
- Stage 2 makes the v2 scaffolder live while keeping legacy compatibility shims.
- Stage 3 makes the v2 path clearly canonical, adds reusable skills, and demotes legacy review/logging helpers.
- A later stage can focus on downstream migration execution and deeper legacy retirement.
