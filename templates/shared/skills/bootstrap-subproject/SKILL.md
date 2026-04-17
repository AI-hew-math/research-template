# bootstrap-subproject

Use this skill when a nested local subproject should get its own local authority and memory files.

## Goal

Create a subproject with local `AGENTS.md`, local `CLAUDE.md`, local `MEMORY.md`, and an optional profile overlay.

## Steps

1. Choose the nested target path inside the current repo.
2. Decide whether the subproject needs:
   - base only
   - research overlay
   - archive overlay
3. Run the scaffold using:
   - `./create_project.sh --subproject path/to/SubProject "Description"`
   - or add `--profile research|light|archive`
4. Verify the new subproject has its own local authority files and that the local `AGENTS.md` overrides the parent for that subtree.
5. If the subproject is research-oriented, confirm the knowledge path and review-cycle structure make sense locally.

## Guardrails

- Do not force the heavy research overlay into every subproject.
- Keep the subproject's local rules close to the subtree they govern.
