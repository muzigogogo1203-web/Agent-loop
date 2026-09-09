# P1-A3 Independent Implementation Review02

> Date: 2026-08-10
>
> Reviewer: responsibility-isolated implementation reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 3 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not author the A3 leaf, Review01/01A, product implementation,
tests, logs, or implementer report. The review was read-only except for this
exact file. It did not rerun tests, builds, the migration matrix, an App, or UI,
and did not modify product, test, plan, evidence, or report bytes.

The reviewed worktree is on `codex/personal-ai-ranch-p0` at HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`. This review is not acceptance and
does not open A4. Leaf §9 requires 0 P0 / 0 P1 before an independent acceptance
owner may close R-03.

## 2. Inputs and immutable evidence checked

The review read the complete Revision 01 leaf, immutable Review01, approved
Review01A, the nine-file implementation boundary, all current implementation
bytes, `red-tests.log`, `verify.log`, `build.log`, and `impl-report.md`.

The three evidence identities independently match the report:

| Evidence | Current SHA-256 | Result |
|---|---|---|
| `red-tests.log` | `3a235fde59a8faa54487a2eeafb6c21281543abb01b92d6a5478c593c32ca84c` | expected missing command/result compile capability; derivative enum inference only |
| `verify.log` | `8eba08f8dd64f7999e24c2c0f90baac960db4c1ac077e42fe13c9abb4bc88eeb` | terminal 655 tests / 7 suites passed |
| `build.log` | `f3628f6464fd09fe1cf9a950cc83e45fcedaebc91a57c84dbd1caed25f4dcab6` | `AgentLoopApp` build passed |

Each of the four exact A3 test names has one start and one pass in the
authoritative log. The current red-line hashes also match the report:

- `Package.swift`: `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d`;
- `EventKind.swift`: `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4`;
- `Sources/RunTests/main.swift`: `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`;
- `scripts/verify-p1-migrations-sqlite-matrix.sh`:
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`.

An independent comparison against the accepted A2/R28 source boundary found
only the expected A3 source changes plus the already accepted A2
`ShellToolTests.swift` delta. The separately established entry hashes for
`MissionDraftFactory.swift` and `DurablePlanningTests.swift` also lead to the
reported A3 changes. This review is therefore not alleging an observed
out-of-allowlist product delta.

## 3. Product-code audit

The main product implementation is structurally consistent with the approved
design:

- the Adapter captures the core draft, runtime, deterministic key, and trace
  before its first `await`, then delegates through the Coordinator;
- the only production call chain is Coordinator → Orchestrator → Supervisor →
  AppDatabase → the fileprivate planning ledger owner;
- the initial database path gates durable running, replays a winner before
  profile/provider checks, and resolves only an absent captured profile/model
  outside the write transaction;
- the write owner re-gates durable running, checks a concurrent winner before
  the profile fence, validates the candidate/source/Camp/companion graph, and
  writes Squad, Mission, work, candidate link, and three start events in one
  GRDB write transaction;
- replay does not restrict the durable state, ignores the incoming trace,
  validates canonical work/Mission/Squad/candidate/source/event identity, and
  returns the original Mission/work;
- `MissionDraftFactory` is read-only and its old `existingMissionId`,
  `linkConverted`, and `convert` bypasses are absent;
- the post-return Orchestrator source re-reads work and durable mode, emits only
  for an inserted queued/retry start, and invokes `kick()` only in the
  queued/retry branch.

No P0 product defect was found in that source audit. The blocking findings are
that the frozen completion tests and fail-closed evidence do not actually
prove several mandatory contracts. A green full suite cannot substitute for
cases the suite never executes.

## 4. Findings

### P1-01 — The four canonical tests never execute the runtime owner, so exact tick/kick/event gates are unproved

**Evidence**

Leaf §3 lines 137–152 and §8 lines 296–327 require dynamic exact counts:
queued/retry replay wakes once after current-state and durable-mode
revalidation; running and terminal replay has tick=0/kick=0; inserted may emit
once only after commit; replay/rejection/rollback/halt/wrong-Camp cow emits and
kicks zero; the concurrent two-caller row has dispatch counts consistent with
the current queued state.

All four canonical functions call `a3Convert`, whose complete body at
`DurablePlanningTests.swift:740-748` directly invokes
`AppDatabase.convertCandidateAndEnqueuePlanning`. There is no runtime test call
to `PlanningEntryCoordinator.startCandidate` or
`Orchestrator.convertCandidateAndEnqueuePlanning` anywhere in the test suite.
The only check of the runtime branch is a source-token assertion at
`DurablePlanningTests.swift:2550-2576`.

Consequently the tests have no tick counter, kick counter, in-memory
`planningStarted` probe, or actor-gate observation. A regression that calls
`kick()` twice, kicks a terminal replay, emits on replay, or dispatches after a
rolled-back/halted command can still leave all four canonical DB-level tests
green. `verify.log` therefore does not satisfy these exact leaf rows.

**Required closure**

Keep the four exact test names and add deterministic runtime coverage through
the reviewed Coordinator/Orchestrator/Supervisor path (or a separately reviewed
allowlisted observation seam). Prove exact tick, kick, and in-memory start-event
counts for all six replay states, every conflict/rejection/rollback/halt row,
the inserted path, and the two-caller race. Source-token order may remain as an
additional guard, but cannot replace runtime observations. If a new seam or
API decision is needed beyond the leaf, stop for a bounded plan revision.

### P1-02 — The mandatory interleavings and zero-mutation snapshots are incomplete

**Evidence**

Leaf §8 requires one deterministic halt/concurrent-winner ordering and a full
concurrent-winner/profile-drift preservation snapshot, with DB reads separated
from zero mutations.

The halt-after-preflight case at `DurablePlanningTests.swift:1717-1765` creates
no concurrent winner. The halted-replay case at lines 1843–1882 creates the
winner before the replay caller's initial read. Neither forces the critical
ordering:

```text
loser absent read + provider preflight
  -> concurrent winner commits
  -> durable mode becomes halted
  -> loser enters its write transaction
```

That is the row which proves the write transaction checks durable halt before
replaying the concurrent winner. The source currently has the right order, but
the required regression does not exercise it.

The concurrent-winner/profile-deletion row at lines 2069–2132 checks returned
IDs, one resolver count, winner trace, and three start-event counts. It does not
take a complete before/after winner graph snapshot and therefore does not prove
preservation of the winner's timestamps, state, attempt, version, candidate,
Mission, Squad, work, total row counts, or all resolver counts as required by
leaf lines 306–312.

More generally, `A3BusinessSnapshot` at lines 496–509 compares selected final
values and row counts; it has no mutation observer/count and omits durable
attempt tables. Thus the assertions do not distinguish reads from writes as
leaf lines 329–330 explicitly require. The current product source appears
read-only on replay/rejection, but that source inspection is not the frozen
dynamic zero-mutation gate.

**Required closure**

Add the exact combined halt+winner barrier sequence and require the durable-halt
error before winner replay, resolver count unchanged after preflight, and zero
A3 business mutation. For concurrent winner plus profile deletion/kind drift,
capture the complete winner graph before releasing the paused caller and prove
byte-for-byte work trace/timestamps/state/attempt/version plus exact
Mission/Squad/candidate/row/start-event and resolver counts afterward. Add a
deterministic mutation counter/observer, distinct from read counts, for replay
and every rejection row.

### P1-03 — The required fail-closed red-line/outside-allowlist source sentinel is absent

**Evidence**

Leaf §8 lines 334–344 requires allowlisted tests to fail closed on five source
boundaries, including unchanged `Package.swift`, `EventKind.swift`, migrations,
RunTests, matrix scripts, and every file outside the nine-file A3 allowlist.

`candidateAppCallsiteCapturesCoordinatorCommandBeforeFirstAwait` at
`DurablePlanningTests.swift:2504-2595` covers only the call-chain order, Adapter
ownership, removed factory bypasses, and absence of nested
`enqueueMissionPlanning`. Neither A3 test file contains a sentinel for
`Package.swift`, the EventKind or RunTests path, the matrix script, migrations,
or an outside-nine manifest. The implementer report lists four current hashes,
but a prose/current-hash table is not a fail-closed test and does not cover the
full boundary.

The independent review comparison found no current unauthorized product delta;
the finding is the missing mandatory regression/evidence gate. Without it,
future or same-run red-line drift can pass the claimed A3 canonical suite.

**Required closure**

Add the exact fail-closed baseline/manifest sentinel required by the leaf,
covering all named red lines, schema/migrations, and every product/test/App file
outside the nine-file allowlist. Preserve the accepted predecessor delta
partition explicitly, record complete entry-to-final identities, and update the
report from that machine-checkable result rather than four manually listed
current hashes.

## 5. Verdict and next gate

The transaction/replay implementation source is promising and the preserved
655/655 plus App build are real green evidence. They do not close the three
missing mandatory gates above.

Final verdict: **CHANGES REQUIRED — 0 P0 / 3 P1 / 0 P2**.

P1-A3 acceptance remains prohibited, R-03 remains open, and P1-A4 remains
closed. A bounded correction must address all three findings and produce a
fresh responsibility-isolated implementation review with 0 P0 / 0 P1 before
acceptance.
