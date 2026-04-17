# research-template v2 design

> Stage-3 design contract for the canonical upstream template.

## Stage Status

Stage 1 established:

- canonical `AGENTS.md`
- thin `CLAUDE.md` wrapper
- the `base / profiles / shared` template tree
- separation between current state, ledger, history, and review artifacts

Stage 2 established:

- the live v2 scaffolder
- profile-aware project creation
- nested subproject support

Stage 3 establishes:

- an explicit canonical-vs-legacy boundary
- the canonical review loop around `reviews/cycles/CYCLE-####/`
- repo-local reusable skills
- deprecation or compatibility status for the remaining v1/v2 transition baggage

## Canonical v2 Authority Model

The canonical contract for new repos is:

1. `AGENTS.md`
   - canonical always-loaded operating rules
2. `CLAUDE.md`
   - thin wrapper to `AGENTS.md`
3. `MEMORY.md`
   - current state only
4. `EXPERIMENT_LOG.md`
   - ledger only
5. `history/`
   - detailed history
6. `reviews/`
   - canonical review-cycle documentation
7. `.codex/skills/`
   - reusable workflow layer

Removed as live concepts:

- separately installed `GLOBAL_CLAUDE.md`
- `CONCEPT.md` as a current-state tracker
- `EXPERIMENT_LOG.md` as a narrative history dump
- review-loop mechanics embedded in long always-loaded instructions
- platform-specific clipboard helpers as the primary review path

## Canonical Review Loop

The canonical loop is:

1. Claude plans or executes work.
2. A new cycle directory is created under `reviews/cycles/CYCLE-####/`.
3. `REVIEW_PACKET.md` is prepared from current state and linked detail docs.
4. External review is stored in `GPT_REVIEW.md`.
5. The next Claude handoff is written in `NEXT_PROMPT.md`.
6. `MEMORY.md`, `EXPERIMENT_LOG.md`, and any relevant detail docs are updated.

The scaffolded starting point is:

```text
reviews/
├── README.md
└── cycles/
    └── CYCLE_TEMPLATE/
        ├── REVIEW_PACKET.md
        ├── GPT_REVIEW.md
        └── NEXT_PROMPT.md
```

`reviews/README.md` explains the loop in the repo itself, and `.codex/skills/` supplies the repeatable procedures.

## What Updates After Each Meaningful Cycle

### `MEMORY.md`

Update immediately when:

- experiment results arrive
- a phase completes
- a key decision is made
- a blocker appears
- important paths or instructions change

### `EXPERIMENT_LOG.md`

Append one concise row only when a meaningful checkpoint exists:

- experiment or batch
- phase transition
- important review checkpoint
- major decision worth indexing

### Detailed docs

Update:

- `history/experiments/` for experiment detail
- `history/phases/` for phase detail
- `decisions/` for durable decisions

## Profile System

The template remains split into three layers:

### `templates/base/`

Always scaffolded:

- `AGENTS.md`
- `CLAUDE.md`
- `MEMORY.md`
- `README.md`

### `templates/profiles/`

Profile overlays:

- `research/`
  - `CONCEPT.md`
  - ledger-only `EXPERIMENT_LOG.md`
  - `history/`
  - `decisions/`
- `light/`
  - no heavy research overlay
- `archive/`
  - `ARCHIVE.md`

### `templates/shared/`

Reusable, non-always-loaded assets:

- `reviews/`
- `skills/`
- `knowledge/`
- `compat/`
- `paper_note_TEMPLATE.md`

## Live Scaffold Interface

```bash
./create_project.sh [--profile research|light|archive] "ProjectName" "Description"
./create_project.sh [--profile research|light|archive] --dir PARENT_DIR "ProjectName" "Description"
./create_project.sh [--profile research|light|archive] --subproject PATH "Description"
```

Behavior:

- default profile: `research`
- all profiles receive:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `MEMORY.md`
  - `README.md`
  - `reviews/README.md`
  - `reviews/cycles/CYCLE_TEMPLATE/`
  - `.codex/skills/`
- research additionally receives:
  - `CONCEPT.md`
  - `EXPERIMENT_LOG.md`
  - `history/`
  - `decisions/`
  - selected compatibility helpers

## Repo-Local Skills Added In Stage 3

The scaffold now includes these repo-local skills:

- `prepare-review-packet`
- `ingest-gpt-review`
- `synthesize-next-prompt`
- `close-cycle`
- `bootstrap-subproject`
- `freeze-repo`
- `migrate-v1-to-v2`

These are procedural and reusable by design. They replace long review-loop prose and reduce dependence on helper-script rituals.

## Canonical vs Legacy Decisions

| Item | Stage-3 Decision | Notes |
|------|------------------|-------|
| `templates/base/`, `templates/profiles/`, `templates/shared/` | canonical | only v2 source of truth |
| `reviews/README.md` | canonical | human-facing review-loop guide in new repos |
| `reviews/cycles/CYCLE_TEMPLATE/` | canonical | cycle blueprint for new repos |
| `.codex/skills/` | canonical | reusable workflow layer |
| `templates/GLOBAL_CLAUDE.md` | deprecated | compatibility stub only |
| `templates/.claude/` | compatibility-only | legacy hook bundle |
| `review_cycles/` | deprecated compatibility cache | old hook/helper output path |
| `templates/scripts/` | compatibility-only helper bundle | contains still-useful utilities plus deprecated helpers |
| `experiments/memos/` | deprecated compatibility area | old memo location |
| `templates/LOGGING_README.md` | deprecated | points back to v2 structure |
| `templates/RUN_CARD.md` | deprecated | documents old helper output shape only |
| `templates/EXPERIMENT_MEMO.md` | deprecated | documents old memo shape only |
| `bootstrap_logging.sh` | compatibility-only | safe helper for older repos, not new repo creation |

## Why Some Compatibility Baggage Still Exists

Stage 3 keeps some legacy pieces because immediate deletion is still risky:

- research-profile helper scripts are still useful for some old flows
- `.claude/` hook exports still support older repos
- `review_cycles/` may still receive output from those hooks
- `experiments/memos/` is still used by `draft_memo.py`

The important change is not full deletion. It is that none of these paths are ambiguous anymore: they are explicitly compatibility-only.

## Validation Expectations

Stage-3 validation should confirm:

- canonical v2 paths scaffold correctly
- `CLAUDE.md` remains a thin wrapper
- `MEMORY.md` exists where expected
- research `EXPERIMENT_LOG.md` stays ledger-only by design
- repo-local skills exist
- review-cycle templates exist in the canonical location
- legacy paths are marked as deprecated or compatibility-only
- new scaffolds do not rely on `GLOBAL_CLAUDE.md`
- canonical docs are enough to run the basic loop without reading deprecated docs

## Recommended Next Scope

The next stage should focus on downstream migration work:

- migration guidance or tooling for old repos
- repo-by-repo v1-to-v2 conversion work
- retiring compatibility helpers once downstream reliance is low enough
