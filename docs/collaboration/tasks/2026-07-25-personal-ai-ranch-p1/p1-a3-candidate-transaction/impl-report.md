# P1-A3 Candidate Atomic Conversion Implementation Report

Date: 2026-08-10  
Branch: `codex/personal-ai-ranch-p0`  
Entry HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
Implementer result: implementation and evidence complete; ready for independent implementation review

This report does not declare A3 accepted and does not open A4. Implementation
followed the Revision 01 leaf plan and responsibility-isolated Review01A,
`APPROVED — 0 P0 / 0 P1 / 0 P2`.

No commit, push, merge, release, destructive or normal-data operation,
payment, public communication, external action, or real-user action was
performed.

## 1. Scope and changed files

Eight of the nine allowlisted product/test files changed. `AppDatabase.swift`
was inspected but remained byte-identical because the atomic entry point could
be implemented in its authorized `DurableWorkStore.swift` extension.

| File | Recorded entry SHA-256 prefix | Final SHA-256 |
|---|---|---|
| `Sources/AgentLoopCore/Product/MissionDraftFactory.swift` | `cf93d96f` | `f33e53d3d795cd913f722d1c5e3f71f5800b97083a9101db27514bcc566d0e26` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `80fdb085` | `49b61c58c07886904fdb16a1a4076081789749645459696f412e85ac672785ee` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `e7cde04d` | `cf6ece2fdd22842d093ea51b461e10bc4d1099360400d9ff254b0e457ff19d39` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `f8842cbd` | `4f2ab03002fbb113784e9586fc20a17bdd580b18aa954432562fbf0d5c728fa9` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `147fac78` | unchanged at `147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `b2f49eb` | `de215a23674fd724491459de319f84d18f8a62d96bd390c46769127e6fd8a9d0` |
| `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift` | `1bf853e7` | `42ccc982acee797a3f53e754763b606a51e46944cc38cdfc97278f631c4589d0` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `5e311070` | `38d20527135ace5035fc387daeead71f66a5798e4d4c090d9bb16cc03491b192` |
| `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` | `2929b9ae` | `0988714b01dd3c82fe6c10de11b50d813a2798647ac66ec4c14f6a69b4a18b47` |

The entry prefixes were recorded at the A3 entry gate; final identities are
listed in full. The following red-line files remain byte-identical to entry:

| Red-line file | Current SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c` |

No schema, migration, dependency, target edge, AppStore, EventKind, RunTests,
matrix-script, or other product/test/App file changed for A3. `git diff
--check` passes for the current worktree.

## 2. Implemented outcome

### 2.1 One atomic candidate-start owner

The candidate path is now exactly:

```text
CodingRanchStoreAdapter
  -> PlanningEntryCoordinator.startCandidate
  -> Orchestrator.convertCandidateAndEnqueuePlanning
  -> DurableWorkSupervisor.convertCandidateAndEnqueuePlanning
  -> AppDatabase.convertCandidateAndEnqueuePlanning
  -> PlanningDurableWorkLedgerOwner in one database transaction
```

`MissionDraftFactory` is read-only. Its former conversion/link helpers and
legacy public `convert` path were removed, so candidate conversion can no longer
commit a Mission and then link the Candidate in a later transaction.

The Adapter captures the complete immutable draft and runtime before its first
`await`. The Coordinator constructs the planning input and delegates once. The
Orchestrator and Supervisor retain their existing process, durable-dispatch,
and compatibility gates.

### 2.2 Transaction, replay, and dispatch behavior

For an absent idempotency key, the database owner resolves the exact captured
non-CLI runtime profile outside the write transaction, then rechecks durable
mode, concurrent-winner status, and the exact profile ID/kind fence inside the
write transaction. Only after the reviewed candidate/source/Camp/companion
graph checks pass does one transaction create the Squad, Mission, two start
events, planning work, Candidate link, and conversion audit event.

A same-key winner is validated and replayed before current profile/provider
availability checks. Replay accepts all six durable work states, returns the
original Mission/work IDs, preserves the first nonblank persisted trace, and
validates the full canonical command/business graph. Incoming replay trace is
not identity. Command mismatches fail as replay conflicts; an absent malformed
deterministic key fails before writes.

After commit, the Orchestrator re-reads current work state and durable mode.
Only queued or retry-scheduled work while durable dispatch remains running can
ensure a tick and kick the existing pump. Running or terminal replay does not
kick, and replay never emits a second start notification.

## 3. Failure-first evidence and corrections

The failure-first run changed only
`DurablePlanningTests.swift`. It failed at compile time because
`CandidatePlanningStartCommand` and `CandidatePlanningStartResult` did not yet
exist; the associated enum-inference errors were derivative. This was the
expected missing-capability red, not an unknown product failure. The complete
output is preserved in `red-tests.log`.

During green implementation, verification exposed and corrected three root
causes rather than hiding them:

1. async actor database reads/writes required `try await`; the call sites were
   corrected;
2. source sentinels depended on Swift line wrapping; they were changed to
   format-independent semantic tokens;
3. an absent-path deterministic-key guard initially ran before winner lookup,
   which incorrectly changed same-key winner conflicts into generic invalid
   state. The guard now runs only after replay-first winner lookup, preserving
   the reviewed conflict-priority contract.

No fallback, swallowed error, or default-success path was introduced.

## 4. Canonical A3 tests

The authoritative run includes and passes all four exact A3 tests:

| Test | Covered contract |
|---|---|
| `candidateConversionRollsBackWhenWorkInsertFails` | rollback on ledger failure, provider failure, halt boundary, profile drift, and halted replay |
| `candidateConversionReplayReturnsOneMission` | six-state replay, first-trace preservation, full conflict matrix, and replay without current credentials/profile |
| `candidateConversionNeverLeavesUnlinkedMission` | concurrent absent callers, one insert/one replay, zero orphan, plus concurrent-winner replay before profile drift fence |
| `candidateWithWrongCampCowFailsBeforeWrites` | wrong/nil companion residency fails with zero business writes |

Additional source sentinels prove the complete Adapter-to-ledger call chain,
capture-before-await order, removal of the old conversion path, absence of a
nested planning enqueue, and conditional post-commit dispatch ownership.

## 5. Final verification

| Gate | Result |
|---|---|
| Failure-first `swift run RunTests` | expected compile red; missing A3 command/result capability only |
| Authoritative unfiltered `swift run RunTests` | **PASS — 655 tests / 7 suites in 42.466 s** |
| Four exact A3 canonical tests | **PASS — one start and one pass each in the authoritative log** |
| `swift build --product AgentLoopApp` | **PASS — 1.87 s** |
| `git diff --check` | **PASS** |
| Four frozen red-line hashes | **PASS — unchanged** |

Raw evidence:

- `red-tests.log` — SHA-256
  `3a235fde59a8faa54487a2eeafb6c21281543abb01b92d6a5478c593c32ca84c`;
- `verify.log` — SHA-256
  `8eba08f8dd64f7999e24c2c0f90baac960db4c1ac077e42fe13c9abb4bc88eeb`;
- `build.log` — SHA-256
  `f3628f6464fd09fe1cf9a950cc83e45fcedaebc91a57c84dbd1caed25f4dcab6`.

## 6. Deviations and next gate

There is no behavioral or scope deviation from the approved Revision 01 leaf.
The only allowlisted file left unchanged is `AppDatabase.swift`; its extension
owner lives in the explicitly allowlisted `DurableWorkStore.swift`, so no
additional change was required.

A3 remains blocked from acceptance and A4 remains closed until a fresh
responsibility-isolated implementation review returns 0 P0 / 0 P1 and an
independent acceptance owner closes R-03.

## 7. Revision02 review closure and Revision03 harness correction

Review02 returned `CHANGES REQUIRED — 0 P0 / 3 P1 / 0 P2`: the canonical
tests did not dynamically cross the runtime owner, the required mutation and
concurrent-winner interleavings were incomplete, and the outside-allowlist
sentinel was not executable. Revision02 added the DEBUG-only Orchestrator
observation seam, complete snapshots and mutation counts, real runtime rows,
the halt/profile/concurrent-winner matrices, and the 206-entry fail-closed
source manifest. Its approved correction boundary was later extended only to
remove a nonthrowing `try` from the A3 writer-counter helper and its call sites.

The fresh unfiltered run after that mechanical cleanup did not complete. It is
permanently classified `HARNESS_REJECTED`, not green and not a product failure.
The partial `revision02-verify.log` has no terminal test summary. A five-second
sample captured `candidateConversionNeverLeavesUnlinkedMission` blocked in
`A3ResolveBarrier.enterAndWait()` on a Swift cooperative-executor thread while
the async release-side continuation was starved. That evidence is preserved
in `revision02-hang-sample.txt`; the exact process was interrupted only after
the sample was saved.

The responsibility-isolated Revision03 plan and Review03A approved a
test-only root-cause correction at `0 P0 / 0 P1 / 0 P2`. No Core or product
change was authorized or needed.

### 7.1 Failure-first evidence

The existing A3 source sentinel was extended before the harness change. The
selected command started exactly
`a3Revision02DebugObservationIsGuardedAndAdjacent`, terminated nonzero, and
reported only two expected issues: the unsafe `A3ResolveBarrier` was still
present and the dedicated-thread race helper was still absent. It had no
compile error, unsupported filter, unrelated test, crash, or timeout. The raw
output is `revision03-red-tests.log`.

### 7.2 Test-harness implementation

Revision03 changed only
`Sources/AgentLoopTestSuite/DurablePlanningTests.swift`:

- target-one winner/halt and winner/profile-drift interleavings now inject the
  winner and mutation synchronously inside the resolver's post-read,
  pre-writer callback; no async task is responsible for releasing them;
- the forced two-absent database race runs on exactly two named Foundation
  threads. Its target-two condition rendezvous is confined to those threads,
  broadcasts on early completion/failure, records indexed outcomes, and
  resumes one checked continuation only after both threads terminate;
- the two independent Orchestrators keep their shared async post-commit
  observation barrier, accept both legal replay preflight orderings, and still
  require one inserted result, one replayed result, one complete graph, and
  exact real-operation counts `ensureTick=2`, `planningStarted=1`, `kick=2`;
- the source sentinel rejects any return of the synchronous A3 resolver
  barrier or `Task.detached` owner race and proves the dedicated-thread and
  async-observer directions.

`Orchestrator.swift` remains byte-identical to the approved Revision02 bytes
at `f28331248a8ba50b641018456e3bbbc0e81e75111756a8ad2d11af9571f4088b`.
The final test-file identity is
`61e75605edfdcdaee3da163311dbbd86129f8c8074d9aca7704792302138a390`.

### 7.3 Fresh verification

| Gate | Revision03 result |
|---|---|
| Source sentinel selected green | PASS — exactly 1 selected test |
| Four canonical A3 tests selected independently | PASS — exactly 1 start and 1 pass each |
| Unfiltered `swift run RunTests` | **PASS — 657 tests / 7 suites in 43.419 s** |
| `swift build --product AgentLoopApp` | PASS |
| DEBUG `AgentLoopCore` and `AgentLoopTestSuite` | PASS |
| release `AgentLoopCore` and `AgentLoopTestSuite` | PASS |
| release/debug observer symbol direction | PASS — release 0, DEBUG 37 |
| 206-entry outside-allowlist manifest | PASS — 206/206 |
| 12 exact frozen-byte sentinels | PASS |
| source symlink scan | PASS — none |
| `git diff --check` | PASS |

The release build contains only the pre-existing unknown-driver diagnostic and
the two pre-existing `BoardServerTests.swift` weak-variable warnings. The
Revision02 A3 nonthrowing-`try` warning is absent.

Fresh evidence identities:

- `revision03-red-tests.log`:
  `53ae46c95183c3d2ed40d2338e2f9a1324e383c04387b9623397a4afb0628e32`;
- `revision03-green-tests.log`:
  `a94bd975e8c5f7a374d5c6416283ae7436c40cbee8999dfe2e7f8c6d5ea92465`;
- `revision03-verify.log`:
  `3af934b7d4632b315e63f747b103acce8dfeff7bf80ee247a534db7b30bbb6f7`;
- `revision03-build.log`:
  `51429d524eccf2122b1c2faa94e44f40954c7aff2a10607d674b6a68f2d59936`;
- `revision03-release.log`:
  `0d068caa3267e590ab18eb3700ebff7859a4e69e86c2e5847a750ed905932da3`.

There is no behavioral or source-scope deviation from approved Revision03.
A3 is ready for a fresh responsibility-isolated implementation rereview; this
report still does not declare acceptance or open A4.

## 8. Revision04 closure of Review03

Review03 independently confirmed the product implementation, database/runtime
evidence, 657/657 run, builds, symbol direction, manifest, and frozen bytes,
but returned `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2` for two exact completion
defects:

1. the task's required `verify.log` still contained the old 655-test run; and
2. the dedicated-thread continuation could resume from inside the second
   worker closure before that Foundation thread reported `isFinished`, while
   the source sentinel did not freeze the exact target-two/finish ownership.

The responsibility-isolated Revision04 plan and Review04A approved a one-test-
file and evidence-only correction at `0 P0 / 0 P1 / 0 P2`. No product, Core,
App, Package, dependency, schema, migration, runner, or script byte changed.

### 8.1 Final thread-completion ownership

The two named Foundation workers now own only their synchronous candidate
operation, target-two rendezvous/abort, and one indexed outcome store. The
state rejects duplicate/missing outcomes explicitly and contains no
continuation.

A private serial GCD completion queue is the sole continuation owner. It
observes both retained worker handles at `isFinished == true`, then validates
and snapshots outcomes 0 and 1 and performs the sole checked-continuation
resume. The handles are wrapped in a narrowly scoped `@unchecked Sendable`
test type whose only purpose is to expose the audited Foundation `Thread`
name/start/isFinished operations across that private queue. This removed the
strict-concurrency warnings produced by directly capturing non-Sendable
`Thread` values; the final release build has no A3 warning.

The strengthened sentinel checks masked/extracted implementation bodies. It
requires two real `Thread` constructions, two exact names/starts/rendezvous
calls, the target-two release and abort broadcasts, explicit indexed outcome
errors, both `isFinished` observations before the only resume, no continuation
inside worker state, no cooperative Task, and no rendezvous reference in the
canonical Orchestrator owner body.

### 8.2 Failure-first and final dynamic evidence

Before the completion-owner change, the exact selected sentinel failed only
because `withCheckedThrowingContinuation` and the post-finish coordinator
shape were absent. `revision04-red-tests.log` contains exactly that one started
and failed test and no compile failure, unrelated test, hang, or crash.

After implementation, the sentinel and four canonical A3 tests each started
and passed exactly once in independent selected runs. The final unfiltered
command wrote stdout/stderr directly to the task's required `verify.log` and
terminated:

```text
✔ Test run with 657 tests in 7 suites passed after 44.881 seconds.
```

The preceding 655-test `verify.log` was first preserved byte-for-byte as
`revision04-predecessor-verify.log` at its documented identity. Only after the
fresh direct run was validated was the new `verify.log` mirrored to
`revision04-verify.log`; the two current files are byte-identical.

### 8.3 Final Revision04 gates

| Gate | Result |
|---|---|
| Selected sentinel red | PASS — expected one-test failure on old finish owner |
| Selected sentinel + four canonical greens | PASS — 5/5 exact selections |
| Task `verify.log` | **PASS — 657 tests / 7 suites in 44.881 s** |
| `verify.log` ↔ Revision04 mirror | PASS — byte-identical |
| predecessor 655-test preservation | PASS — byte-identical to old task log |
| App + DEBUG Core/TestSuite builds | PASS |
| release Core/TestSuite builds | PASS |
| release/debug A3 observer symbols | PASS — 0 / 37 |
| outside-allowlist manifest | PASS — 206/206 |
| 12 frozen-byte source sentinels | PASS |
| source symlink scan / `git diff --check` | PASS / PASS |

Final identities:

- `revision04-red-tests.log`:
  `7be319aaf7440b243a3d07ac4a17f70e88c0f9a8c77ce7176f96442177f668ae`;
- `revision04-green-tests.log`:
  `d57c2ec2425670bf6325a98e68c9016fd9adfebc3b72ff06e1c0c3036f634048`;
- `revision04-predecessor-verify.log`:
  `8eba08f8dd64f7999e24c2c0f90baac960db4c1ac077e42fe13c9abb4bc88eeb`;
- current `verify.log` and `revision04-verify.log`:
  `5e0f9108664e4ef9165cb72d259fbbdfce8cdad4fc6afc083e0cd58a80b6d217`;
- `revision04-build.log`:
  `7b0158d9fd36b4b483314481c359964ba73ab1ca6cc198891e07d3c7d931916a`;
- `revision04-release.log`:
  `cab07c14500b5cd4a53a24e52912678e4a3d25169ea40322ad5316e2c21a53d9`;
- final `DurablePlanningTests.swift`:
  `0dbc6385b73b13cf70f2e3f3a739d1a387b43fc27b3660da5181ab884ffed403`.

The final release log contains only the pre-existing unknown-driver diagnostic
and two pre-existing `BoardServerTests.swift` weak-variable warnings. Review03's
premature “both threads terminated” wording is superseded by this section and
the actual post-`isFinished` implementation. A3 is ready for a fresh
responsibility-isolated implementation rereview, but remains unaccepted and
does not open A4 until that rereview and independent acceptance pass.
