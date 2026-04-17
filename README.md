# research-template

[![GitHub release](https://img.shields.io/github/v/release/AI-hew-math/research-template)](https://github.com/AI-hew-math/research-template/releases/latest)
[![Smoke Test](https://github.com/AI-hew-math/research-template/actions/workflows/smoke.yml/badge.svg)](https://github.com/AI-hew-math/research-template/actions/workflows/smoke.yml)

Stage 3 of the v2 redesign is now in place. This repo is the canonical upstream source for the new template contract, while older review and logging helpers remain available only as explicit compatibility paths.

## Canonical v2 Contract

For new repos, the authority and state model is:

1. `AGENTS.md`
   - canonical instruction file
   - always-loaded rules only
2. `CLAUDE.md`
   - thin wrapper to `AGENTS.md`
3. `MEMORY.md`
   - current state only
4. `EXPERIMENT_LOG.md`
   - concise ledger only
5. `history/`
   - detailed experiment or phase history
6. `reviews/`
   - canonical Claude↔GPT review loop
7. `.codex/skills/`
   - reusable workflow skills

`GLOBAL_CLAUDE.md` is no longer a live concept in v2.

The design rationale and compatibility decisions live in [V2_TEMPLATE_DESIGN.md](./V2_TEMPLATE_DESIGN.md).

## Create A Repo

The live scaffolder is [create_project.sh](/Users/mac_hew/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template-fresh/create_project.sh).

```bash
# Default: research profile, sibling repo next to research-template
./create_project.sh "MyProject" "Research project"

# Explicit profiles
./create_project.sh --profile research "ProbeX" "Active research repo"
./create_project.sh --profile light "ToolingRepo" "Light technical repo"
./create_project.sh --profile archive "OldProject" "Frozen archive repo"

# Top-level repo under a chosen parent directory
./create_project.sh --profile light --dir ~/projects "OpsTools" "Small utility repo"

# Nested local subproject
./create_project.sh --subproject subprojects/ParserSpike "Nested local subproject"
./create_project.sh --profile research --subproject subprojects/Ablation "Nested research subproject"
```

Notes:

- Default profile is `research`.
- `--dir` chooses a parent directory for a top-level repo.
- `--subproject` creates a nested local subtree with its own local authority files.

## Profile Matrix

| Profile | Canonical Files | Legacy Compat Copies |
|---------|-----------------|----------------------|
| `research` | `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, `README.md`, `CONCEPT.md`, ledger-only `EXPERIMENT_LOG.md`, `history/`, `decisions/`, `reviews/README.md`, `reviews/cycles/CYCLE_TEMPLATE/`, `.codex/skills/` | `scripts/`, `.claude/`, `review_cycles/`, `experiments/memos/`, `runs/` |
| `light` | `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, `README.md`, `reviews/README.md`, `reviews/cycles/CYCLE_TEMPLATE/`, `.codex/skills/`, `src/` | none |
| `archive` | `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, `README.md`, `ARCHIVE.md`, `reviews/README.md`, `reviews/cycles/CYCLE_TEMPLATE/`, `.codex/skills/` | none |

## Canonical Review Loop

New repos should follow the review loop documented in `reviews/README.md`.

Canonical cycle structure:

```text
reviews/
├── README.md
└── cycles/
    ├── CYCLE_TEMPLATE/
    │   ├── REVIEW_PACKET.md
    │   ├── GPT_REVIEW.md
    │   └── NEXT_PROMPT.md
    └── CYCLE-0001/
        ├── REVIEW_PACKET.md
        ├── GPT_REVIEW.md
        ├── NEXT_PROMPT.md
        └── artifacts/
```

Canonical loop:

1. Copy `reviews/cycles/CYCLE_TEMPLATE/` to a new `reviews/cycles/CYCLE-####/`.
2. Use `prepare-review-packet` to assemble `REVIEW_PACKET.md`.
3. Use `ingest-gpt-review` to store reviewer feedback in `GPT_REVIEW.md`.
4. Use `synthesize-next-prompt` to write `NEXT_PROMPT.md`.
5. Run Claude on that next prompt.
6. Use `close-cycle` to update `MEMORY.md`, `EXPERIMENT_LOG.md`, and the linked history or decision docs.

The canonical workflow does not depend on clipboard scripts or `review_cycles/`.

## What Gets Updated After Each Meaningful Cycle

- `MEMORY.md`
  - current phase
  - pending actions
  - blockers
  - live decisions
  - important path or environment changes
- `EXPERIMENT_LOG.md`
  - one concise row for a meaningful experiment, decision, phase checkpoint, or review checkpoint
- `history/experiments/` or `history/phases/`
  - detailed outcomes and evidence
- `decisions/`
  - durable decisions that need their own record

## Repo-Local Skills

Each scaffolded repo includes repo-local skills under `.codex/skills/`:

- `prepare-review-packet`
- `ingest-gpt-review`
- `synthesize-next-prompt`
- `close-cycle`
- `bootstrap-subproject`
- `freeze-repo`
- `migrate-v1-to-v2`

These are the reusable procedural workflow layer. They intentionally keep review and migration mechanics out of always-loaded instructions.

## Canonical vs Legacy

Stage 3 makes the boundary explicit:

| Path Or File | Status | Meaning |
|--------------|--------|---------|
| `templates/base/`, `templates/profiles/`, `templates/shared/` | canonical | v2 source of truth |
| `reviews/README.md` and `reviews/cycles/CYCLE_TEMPLATE/` | canonical | primary Claude↔GPT review loop |
| `.codex/skills/` | canonical | reusable workflow layer |
| `templates/GLOBAL_CLAUDE.md` | deprecated | kept only as a compatibility stub |
| `templates/.claude/` | compatibility-only | older hook-based review export flow |
| `review_cycles/` | deprecated compatibility cache | old hook/helper output area |
| `templates/scripts/` | compatibility-only helper bundle | older research helpers, not primary review path |
| `experiments/memos/` | deprecated compatibility area | old memo location |
| `templates/LOGGING_README.md` | deprecated | no longer the primary workflow guide |
| `templates/RUN_CARD.md` | deprecated | reference for old helper output |
| `templates/EXPERIMENT_MEMO.md` | deprecated | reference for old memo format |
| `scripts/bootstrap_logging.sh` | compatibility-only | for older repos, not new scaffolds |

## Canonical Template Tree

```text
templates/
├── base/
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── MEMORY.md
│   └── README.md
├── profiles/
│   ├── light/
│   ├── research/
│   │   ├── CONCEPT.md
│   │   ├── EXPERIMENT_LOG.md
│   │   ├── decisions/DECISION_RECORD.md
│   │   └── history/
│   │       ├── experiments/EXPERIMENT_DETAIL.md
│   │       └── phases/PHASE_DETAIL.md
│   └── archive/
│       └── ARCHIVE.md
└── shared/
    ├── compat/
    ├── knowledge/
    ├── paper_note_TEMPLATE.md
    ├── reviews/
    │   ├── README.md
    │   └── cycles/
    │       ├── REVIEW_PACKET.md
    │       ├── GPT_REVIEW.md
    │       └── NEXT_PROMPT.md
    └── skills/
```

## What Is Still Deferred

Later work can focus on:

- downstream repo migration execution
- further retirement of research-profile compatibility baggage once risk is lower
- migrating older helper outputs into the canonical review-cycle structure where useful
- optional automation on top of the new skill layer
