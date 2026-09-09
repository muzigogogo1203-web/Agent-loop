# P1-E Plan Revision 01 — Correct the v16 derived checkpoint

> Date: 2026-08-26  
> Scope: plan/evidence correction only; no product or test source changed  
> Authority: canonical P1 Stage §§18.5–18.7 and canonical P1 plan §§7, 10

## Finding

Revision 1 incorrectly assigned the accepted through-v17 table/index totals
`79/208` to the through-v16 E1 completion gate. The trigger total `67` was
already the correct through-v16 value. This was a derived checkpoint error in
the leaf plan, not a change to the canonical v16 SQL literal, migration order,
schema objects, ownership, product behavior, allowlist, or test manifest.

## Canonical derivation

The accepted v15 checkpoint is `55 tables / 134 indexes / 16 triggers`.
Stage §18.6 creates fifteen persistent-table statements, of which three are
same-name durable-work rebuilds, for a net gain of twelve tables. Its index
graph adds fourteen indexes for the twelve new tables and twenty-two new
autoindexes, while the rebuilt attempt-event table adds one new autoindex.
Therefore through-v16 is:

```text
tables:   55 + 12 = 67
indexes: 134 + 14 + 22 + 1 = 171
triggers: 67 (explicit canonical through-v16 fence)
```

Stage §18.7 then adds twelve tables and thirty-seven indexes, yielding the
already accepted through-v17 total `79 / 208 / 84`.

## Frozen delta

Revision 2 changes exactly four semantic references in `plan.md`:

1. the E1 band completion gate;
2. the frozen migration checkpoint decision;
3. the final completion condition;
4. the review reference from Review01 to Review01a.

All four now distinguish through-v16 `67/171/67` from through-v17
`79/208/84`. No other plan decision changes. Review01 remains frozen history;
Review01a reviews only this bounded correction plus the resulting full current
plan.
