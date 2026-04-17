# {{PROJECT_NAME}}

> Canonical operating rules for this repository.
> Keep this file short and treat it as the always-loaded authority.

## Authority

- `AGENTS.md` is the canonical instruction file.
- `CLAUDE.md` is a thin wrapper that points to `AGENTS.md`.
- `MEMORY.md` holds current state only.
- `README.md` is human-facing project orientation.
- Shared workflow support such as `reviews/` and `.codex/skills/` extends the repo contract without replacing this file.
- Profile-specific files such as `CONCEPT.md`, `EXPERIMENT_LOG.md`, `history/`, `decisions/`, or `ARCHIVE.md` are overlays, not replacements for this file.

## Session Start

1. Read `MEMORY.md`.
2. If present, check the last 20 lines of `EXPERIMENT_LOG.md`.
3. If present, read `CONCEPT.md`.
4. Before experiments or major edits, check `{{KNOWLEDGE_PATH}}/lessons_learned.md` if relevant.
5. If a relevant lesson exists, tell the user before proceeding.

## Operating Rules

- Keep current state in `MEMORY.md`, not in `CONCEPT.md`.
- Keep `EXPERIMENT_LOG.md` as a concise ledger or index, not a history dump.
- Put detailed experiment or phase history in dedicated files under `history/`.
- Update `MEMORY.md` immediately when experiment results, decisions, blockers, key paths, or user preferences change.
- Use review-cycle documents or reusable skills for repeated review workflows instead of expanding always-loaded instructions.

## Local Overrides

- More specific local `AGENTS.md` files override broader ones.
- Nested subprojects may define their own local memory, ledger, and profile files when needed.
