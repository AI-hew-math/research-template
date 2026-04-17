# freeze-repo

Use this skill when an active repo should become frozen or archive-like.

## Goal

Move the repo toward archive mode without losing the final state trail.

## Steps

1. Add or update `ARCHIVE.md` with the archive reason, owner, and reopen conditions.
2. Update `MEMORY.md` with the final active state or reopen note.
3. Add a concise archive or freeze row to `EXPERIMENT_LOG.md` if the repo uses that ledger.
4. Link the final relevant phase detail, experiment detail, and decision records.
5. Make it clear that new work should not resume until the archive status is lifted.

## Guardrails

- Do not delete history when freezing.
- Preserve the authority model: `AGENTS.md` remains canonical, `CLAUDE.md` remains a wrapper.
