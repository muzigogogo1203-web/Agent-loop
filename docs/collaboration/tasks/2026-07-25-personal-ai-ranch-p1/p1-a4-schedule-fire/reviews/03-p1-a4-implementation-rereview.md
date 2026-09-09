# P1-A4 Independent Implementation Re-review03

> Date: **2026-08-11**
>
> Reviewer: fresh, responsibility-isolated implementation re-reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and boundary

This reviewer did not author the A4 plan, Revision 01, Review01A, Review02,
implementation, tests, scripts, evidence, or implementer report. The reviewed
worktree is `codex/personal-ai-ranch-p0` at HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

The review read the accepted master/stage authority as relevant, `plan.md`,
`plan-revision-01.md`, Reviews 01A and 02, `impl-report.md`, the exact 13-file
A4 allowlist, and all final red/targeted/build/migration/source/full-suite/
preview evidence. The review did not rerun or overwrite any canonical gate.
Read-only source searches, manifest checks, and standalone compiler probes
were used; they changed no repository source, test, script, or evidence file.

This is an implementation review, not acceptance. It does not write
`acceptance.md`, close R-04, or open P1-B.

## 2. Evidence checked

| Evidence | Current SHA-256 | Observed terminal result |
|---|---|---|
| `red-tests.log` | `8093d025e9d2bbe704b81ff6ad3dc720041beaefcc7fe39679a12de54a793712` | preserved failure-first run contains only missing reviewed A4 capabilities |
| `targeted-tests.log` | `b6bd683e69da9e87f5dd05eefaf80b56d6b388dc6adf38f8004fee96b40ee101` | all 10 canonical and 10 affected tests pass independently |
| `build.log` | `90e3d049de6fa4ad6f91e3103b44937f4937a2f9d9ef1164b3aaecd48201049a` | Core, TestSuite, and App debug/release gates all pass |
| `migration-matrix.log` | `e14da0ac9ae79e1a7449e4f4fd33abef4fe3002532792d10bc965cfd533b3777` | SQLite 3.51/3.52 real and literal lanes pass |
| `source-gates.log` | `07cd5eb5ac83ad00948f93b26f26bff043c48593ae38eea93792ebc3d0e0fb70` | all 17 scope/source/build/migration gates pass |
| `verify.log` | `35f2e0923604259a8db5b578e37a195231aeaf2a8583724d786f0f9feb9f0a27` | exactly 667 tests in 7 suites pass |
| `preview.log` | `6becf3bd82608eedef8adf7dc288be46b66ee16e34e1232a365499c9f6f986ea` | two distinct isolated cold previews pass and exit cleanly |
| `a4-entry-source-manifest.sha256` | `6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71` | 206-entry outside-partition boundary remains byte-exact |

The build log contains only the recorded environment driver notice and two
pre-existing `BoardServerTests.swift` weak-variable warnings. The migration
log's constraint and forced-missing-table errors are the expected negative
probes; it terminates with `p1_migration_matrix.result=pass`.

## 3. Review02 findings are closed

### P1-01 — Closed: fire and cursor records are now genuinely fetch-only

`ScheduleFireRecord` and `ScheduleEvaluationCursorRecord` at
`Sources/AgentLoopCore/Database/ScheduleStore.swift:157-249` now conform to
`FetchableRecord` but neither `TableRecord` nor `PersistableRecord`. Their
package-visible table-name constants and numeric-only date decoding remain,
without restoring any generic mutation conformance or equivalent package API.

All production reads of these types are explicit SQL. This includes the three
package store-side reads at `ScheduleStore.swift:503-542`, cursor reads at
`DurableWorkStore.swift:2697-2710` and `:2745-2758`, source-fire loading at
`:3144-3157`, and fire/replay lookups at `:3540-3581`. A repository-wide use
audit found no query-interface `filter`/`deleteAll`/`updateAll` mutation path
for either record. Fire/cursor writes remain raw SQL inside the one nested
`fileprivate ScheduleDurablePlanningLedgerOwner` beginning at
`DurableWorkStore.swift:2055`.

An independent same-package `swiftc -typecheck` probe confirmed the actual
GRDB surface, rather than relying only on source spelling:

- explicit SQL `fetchOne` calls for both record types compile;
- `ScheduleFireRecord.deleteAll`,
  `ScheduleEvaluationCursorRecord.updateAll`, and
  `ScheduleFireRecord.filter(...).deleteAll` all fail to type-check with the
  expected missing-member diagnostics.

The canonical regression at `DatabaseTests.swift:1156-1290` now checks both
declarations and extension conformances, executes the positive read probe,
and fail-closes on all three inherited mutation counterexamples. This closes
the concrete GRDB mutation surface identified by Review02 without widening
the API or changing the schema.

### P1-02 — Closed: both replay-winner paths bind source, payload, work, and identity

Both possible winner entry paths use the same strengthened validator:

1. `replayReadSnapshot` requires the durable-running gate, validates command
   identity, looks up the replay key, and calls `validateReplayWinner` at
   `DurableWorkStore.swift:2225-2241`. Only winner absence proceeds to source,
   current Schedule/template/profile capture, or provider preflight.
2. `commitReplay` repeats the durable-running gate and calls the same validator
   for a writer-race winner at `:2396-2412`. Only continued absence enters the
   current-state fences and insert path.

`validateReplayWinner` at `:3179-3228` first binds the winner row to the
caller's original ID, global replay key, payload hash, schedule, captured
effective template, slot, and exact instant bits. It then:

- reloads the referenced source through explicit SQL;
- requires a non-replay failed original and validates its canonical missed
  graph through `validateCommittedFire`;
- reconstructs the complete `ScheduleReplayPayloadV1` from that stored source,
  the already captured effective-template value, and the typed payload
  preparation, and requires DTO, canonical bytes, and hash equality; and
- derives the exact `PlanningWorkInput` for a selected payload, while an
  unavailable payload is forbidden from validating a started graph.

For a started winner, `validateCommittedFire` at `:3231-3428` independently
canonicalizes and hashes the stored work input, requires it to equal the
payload-derived input for `.replaySelected`, and then requires the canonical
`mission_created` identity's `planningInput` to equal that same work input in
addition to the Mission/Squad/camp/goal/cow/workspace/budget/autonomy graph.
The `.original` branch deliberately retains its prior semantics: incoming
runtime preparation is not added to original-fire replay identity.

The strengthened winner path reads only durable dispatch state and already
committed fire/event/work/Mission graph state. It does not read current
Schedule/template/profile truth and does not resolve a provider. Durable halt
therefore still wins, while later current-state drift cannot invalidate an
intact first winner.

The canonical replay regression now includes both Review02 counterexamples:

- `ScheduleStartedWinnerCorruption.planningWorkInputPayloadMismatch`
  coherently rewrites work input/hash and `mission_created` identity to a
  different valid runtime/model; replay fails with the exact winner integrity
  error;
- the `source-provenance-mismatch` case coherently rewrites the retained source
  fire and its canonical missed event to different valid provenance; replay
  fails with the frozen replay conflict.

For both, the tests require zero provider calls, unchanged SQLite
`total_changes`, an unchanged complete mutation snapshot, and preservation of
the source/winner rows. The real two-caller replay race at
`ScheduleTests.swift:3221-3285` records two preflights, one inserted result,
and one replayed result over the same graph, which exercises the
concurrent-writer winner entry path as well as the statically shared validator.

## 4. Broader adversarial audit

No new P0/P1/P2 or scope drift was found in the exact 13-file partition:

- Stage §18.2 remains exact: 29 tables, 60 indexes, 4 triggers, required
  columns/FKs/partial indexes/CHECKs, numeric date storage, rollback, replay,
  and predecessor preservation are covered in both real and literal SQLite
  3.51/3.52 lanes.
- Gregorian/POSIX context capture, finite/range/bit-exact instant validation,
  DST slot identity, raw UTF-8 cursor ordering, checked cursor versioning, and
  startup latest-unconsumed-slot behavior match the frozen leaf.
- Original insert still commits fire, cursor, `lastFiredAt`, Mission/Squad,
  planning work, identity, and canonical events in one transaction. Typed
  failures use the fixed precedence/messages; unknown, database, decoding,
  constraint, and resolver errors fail or roll back instead of becoming a
  generic failed fire.
- Conditional wake and inserted/replayed post-commit effects preserve the
  frozen matrix. Broadcast/callback failures cannot rewrite committed fire
  truth, and replayed outcomes do not duplicate inserted-only effects.
- The 206-entry manifest is LF-clean, sorted, unique, and byte-exact; a fresh
  pathname-exact enumeration produced its exact 13-file complement and no
  Source/script symlink. No Package/public API/target/dependency edge,
  unplanned schema, or P1-B expansion was found.
- Evidence order and terminal markers are internally consistent: post-fix
  targeted tests, six builds, migration matrix, source gates, 667/667 suite,
  and two isolated previews are all green.

## 5. Findings and verdict

| Severity | Count |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |

Final verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**.

Review02 P1-01 and P1-02 are closed. This approval satisfies the fresh
implementation-review prerequisite only. P1-A4 still requires a separate
independent acceptance before R-04 may close or P1-B may open.
