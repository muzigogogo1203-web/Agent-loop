# P1-A4 Independent Implementation Review02

> Date: 2026-08-11
>
> Reviewer: fresh, responsibility-isolated implementation reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author the A4 plan, Revision 01, Review01A, product
implementation, tests, scripts, evidence, or implementer report. The review was
read-only except for this exact new review file. It did not overwrite or rerun
the canonical test, build, migration, source-gate, or preview evidence. One
standalone compiler type-check probe was run from standard input to verify the
actual GRDB API surface; it changed no repository source or evidence.

The reviewed worktree is on `codex/personal-ai-ranch-p0` at HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`. The authority checked was the
accepted master spec, P1 Stage, `plan.md`, `plan-revision-01.md`, and approved
`reviews/01a-p1-a4-plan-review.md`. The implementation review covered the exact
13-file A4 partition and the current implementation bytes, not P1-B or any
later stage.

This review is not acceptance. Revision 01 requires a fresh review with zero
P0/P1 before a separate acceptance owner may close R-04 or open P1-B.

## 2. Inputs and evidence checked

The review read the complete plan and revision, Review01A, `impl-report.md`, all
13 implementation files, and the complete relevant source ranges for the
original/replay ledger, cursor/math, scheduler, post-commit effects, migration
runner, matrix script, and canonical tests. It also checked the current
`red-tests.log`, `targeted-tests.log`, `build.log`, `migration-matrix.log`,
`source-gates.log`, `verify.log`, and `preview.log`.

The preserved evidence is real and internally consistent:

| Evidence | Current SHA-256 | Observed terminal result |
|---|---|---|
| `red-tests.log` | `8093d025e9d2bbe704b81ff6ad3dc720041beaefcc7fe39679a12de54a793712` | expected pre-capability failures |
| `targeted-tests.log` | `40a360c45dc906f167fdbe4f8e44e552386a16ad298265df6cb307eba3db2562` | 10 canonical and 10 affected independent tests passed |
| `build.log` | `db7ad6ef2e80fc213829f14498629e5117c1340b7b761ec39dcc9fb3e72bbb20` | Core, TestSuite, and App debug/release gates passed |
| `migration-matrix.log` | `96326576a39daa81fbfd480611d8eb7fad8052227fb54f211c723f5e761e20b1` | SQLite 3.51/3.52 real/literal matrix passed |
| `source-gates.log` | `cf2e3ef04ed5d64cde9c15fa39a00f7630d0bd0e95435b8d0511aa46f72c505b` | recorded scope/source gates passed |
| `verify.log` | `8d0f6ef4fb8685ba65ca5e6446f3bb917145d280530d4ab7310f19df290ff466` | exactly 667 tests in 7 suites passed |
| `preview.log` | `6becf3bd82608eedef8adf7dc288be46b66ee16e34e1232a365499c9f6f986ea` | two isolated cold previews passed |

The source audit found no additional P0/P1 in the exact v12 migration,
29-table/60-index/4-trigger checkpoint, numeric Date decoding/storage, DST slot
identity, cursor ordering/advance, original atomic graph, fixed failure
precedence, provider error classification, post-commit wake/effect matrix,
13-file partition, or preview isolation. Those green areas do not close the two
API/integrity defects below: the existing tests do not exercise either
counterexample.

## 3. Findings

### P1-01 — The two purported fetch-only records expose GRDB's generic update/delete API

**Evidence**

`ScheduleFireRecord` at `Sources/AgentLoopCore/Database/ScheduleStore.swift:157-160`
and `ScheduleEvaluationCursorRecord` at
`Sources/AgentLoopCore/Database/ScheduleStore.swift:219-222` both conform to
package-visible `TableRecord`. The frozen leaf says the former gains no generic
save/update/delete API and the latter is fetch-only outside the fileprivate
ledger owner. Revision 01 likewise says that the fileprivate ledger is the only
writer.

In pinned GRDB 7.11.1, `TableRecord` itself—not `PersistableRecord`—provides
public static `deleteAll`, `deleteOne`, and `updateAll`, while the request
returned by `all()`/`filter(...)` also provides batch `deleteAll` and
`updateAll`. A same-package compiler probe successfully type-checked all of
these representative ordinary-product calls:

```swift
_ = try ScheduleFireRecord.deleteAll(db)
_ = try ScheduleEvaluationCursorRecord.updateAll(
    db,
    Column("version").set(to: 0)
)
_ = try ScheduleFireRecord
    .filter(Column("state") == "failed")
    .deleteAll(db)
```

The test at `Sources/AgentLoopTestSuite/DatabaseTests.swift:1156-1189` only
rejects `PersistableRecord` and a few project-specific method names. It does not
reject `TableRecord` or compile-check the actual inherited write surface, so it
passes while the forbidden APIs are available.

This is not merely cosmetic encapsulation. Any ordinary package product path
can delete retained fire history, delete/reset the evaluation cursor, or batch
rewrite ledger columns without passing the atomic owner. Deleting a cursor can
make an already consumed slot eligible again; deleting or rewriting fires can
break original/replay idempotency and provenance. The frozen ledger-only
durability boundary therefore is not implemented.

**Required closure**

1. Remove `TableRecord` conformance from both types while retaining their
   numeric-only `FetchableRecord` decoding and explicit table-name constants.
2. Replace every TableRecord-only key/query convenience used by
   `ScheduleStore.swift` and `DurableWorkStore.swift` with explicit read-only
   SQL fetches or narrowly scoped read helpers. Do not add an equivalent generic
   package write extension or widen a public/package API.
3. Strengthen `DatabaseTests.swift:1156-1189` so both declarations are proven
   free of `TableRecord` and `PersistableRecord`, and add a fail-closed regression
   against the inherited static/request update/delete surface. Keep every fire
   and cursor write inside the one fileprivate ledger owner.
4. Rerun the canonical/affected tests, full suite, six builds, source gates, and
   migration matrix after the fix.

### P1-02 — A replay-key winner is not fully bound to its hashed payload or original provenance

**Evidence**

Both the initial-read and concurrent-write winner paths call
`validateReplayWinner` (`Sources/AgentLoopCore/Database/DurableWorkStore.swift:2224-2234`
and `:2396-2404`). That validator at
`Sources/AgentLoopCore/Database/DurableWorkStore.swift:3161-3184` checks the
winner fire's replay key/hash/original ID and its schedule/template/slot/instant
fields against the command payload, then delegates to the generic
`validateCommittedFire`.

For a started replay, `validateCommittedFire` decodes and canonicalizes the
planning input at `DurableWorkStore.swift:3280-3296`, then only proves at
`:3339-3349` that `mission_created` and the durable work agree with each other.
It never requires that the persisted work/identity `runtimeProfileId` and
`plannerModel` equal the selected values in the replay payload whose hash is on
the fire. The winner path also never reloads `command.originalFireId`; therefore
it never proves that the retained original's schedule, original template, slot,
instant, failed-original eligibility, and canonical failed graph still match
the payload provenance.

Two concrete internally consistent corruptions therefore pass the current
validator:

1. coherently rewrite a successful replay's work `inputJson`/`inputHash` and
   its `mission_created` planning input to another valid nonblank runtime/model;
   or
2. coherently rewrite the referenced original fire and its canonical missed
   event to different but valid original provenance.

In the first case the current work and Mission identity still agree; in the
second case the winner validator never reads the source. In both cases the
winner fire still carries the caller's original payload hash, and the same
command is incorrectly returned as `.replayed`. This violates Revision 01
§4.1's complete canonical identity, §4.2's preserved provenance, and §4.3's
requirement that only the same original plus an intact stored graph may replay.

The corruption table at
`Sources/AgentLoopTestSuite/ScheduleTests.swift:493-503` and loop at
`:2848-2875` cover malformed/semantically invalid fields or internal graph
disagreement. They do not cover a graph that remains canonical and internally
self-consistent but differs from the hashed payload/source.

**Required closure**

1. Make `validateReplayWinner` reload and validate the referenced source as an
   intact failed original, without consulting current Schedule/template/profile
   or resolving a provider. Reconstruct the complete payload from that stored
   source, the payload's captured effective-template value, and its typed
   preparation; require exact DTO bytes/hash equality before returning a
   winner. Preserve durable-halt-first and winner-before-current-state ordering.
2. For a started replay winner, derive the exact `PlanningWorkInput` from the
   selected replay payload and require both the canonical durable-work input and
   canonical `mission_created` identity to equal it, not merely each other. An
   unavailable payload must never validate a started graph. Keep original-fire
   winner semantics unchanged, because runtime preparation is deliberately not
   original identity.
3. Add canonical regressions for (a) a valid-but-different runtime/model written
   coherently to work plus Mission identity and (b) valid-but-different original
   provenance written coherently to source fire plus event. Repeating the same
   replay command must fail with the frozen conflict/integrity error, perform
   zero provider resolution and zero writes, preserve first trace/timestamps,
   and exercise the shared validator used by both read and concurrent-winner
   paths.
4. Rerun the canonical/affected tests, full suite, six builds, source gates,
   migration matrix, and isolated previews after the fix.

## 4. Verdict and next gate

The v12 schema, original transaction, cursor/DST behavior, post-commit effect
ordering, migration matrix, 667/667 suite, and previews are substantive green
work. They do not compensate for an exposed ledger mutation API or a replay
winner that can accept a graph different from the identity it claims to hash.

Final verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**.

P1-A4 acceptance remains prohibited, R-04 remains open, and P1-B remains
closed. A bounded A4 correction must close both findings, produce fresh
post-fix evidence, and receive a new responsibility-isolated implementation
review with **0 P0 / 0 P1** before independent acceptance.
