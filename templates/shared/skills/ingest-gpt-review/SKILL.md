# ingest-gpt-review

Use this skill when external feedback has arrived and needs to be normalized into the v2 review structure.

## Goal

Store reviewer feedback in `reviews/cycles/CYCLE-####/GPT_REVIEW.md` and separate strong criticism from weaker commentary.

## Steps

1. Locate the target cycle directory under `reviews/cycles/`.
2. Copy the review content into `GPT_REVIEW.md` in a structured way.
3. Separate:
   - valid criticism
   - weak or lower-confidence criticism
   - missed opportunities
   - recommended next move
   - open questions
4. Preserve links or artifact references when the feedback depends on them.
5. Note any immediate blocker or important decision candidate for later `MEMORY.md` and ledger updates.

## Guardrails

- Do not treat all criticism as equally valid.
- Do not overwrite the original review meaning just to fit a template.
- Keep the normalized review concise enough to drive the next step.
