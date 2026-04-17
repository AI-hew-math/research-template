# Legacy Compatibility Cache

`review_cycles/` is a deprecated compatibility path.

## Status

- Compatibility-only.
- Not the canonical v2 review location.
- Safe to ignore unless an older helper script or hook still writes here.

## Canonical Path

Use `reviews/cycles/CYCLE-####/` instead.

## Migration Guidance

- Put tracked review docs in `reviews/cycles/`.
- If old helper output lands here, treat it as temporary import material rather than the authoritative cycle record.
