# P1-D Implementation Report

Status: implementation complete; awaiting Review02 at report creation  
Checkout: `/Users/muzi/Agent-loop`  
Branch / HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
Implementation authority: `plan.md`, `plan-revision-01.md`, and
`plan-revision-02.md`

## 1. Delivered product behavior

P1-D now provides the accepted durable Outcome truth:

- exact v15 Outcome/Verification/Acceptance/ApprovalGrant schema and migration;
- immutable versioned OutcomeContract and Outcome evidence;
- Goal activation, pause, resume, achieve, and system reopen with exact
  Understanding/Contract/Mission/Camp authority;
- independent deterministic and cow verification with reducer-owned current
  heads, invalidation, delivery, and dependency propagation;
- post-commit acceptance, return/revoke/invalidate handling, Mission/Goal
  projection changes, and exactly-once metric credit;
- typed, scoped, expiring, single-use ApprovalGrant reservation/dispatch/
  receipt/refund/reconciliation state machines;
- one Application-owned external-operation coordinator injected through model
  and CLI execution paths, with missing authority failing closed;
- UI acceptance failure that stays on Return Summary and exposes a stable
  trace instead of navigating or celebrating;
- legacy closeout kept separate from Outcome/Acceptance/metric truth.

No P1-E/F table or behavior was introduced.

## 2. Changed and new product paths

The following 38 present dirty product/test/script paths are inside the exact
P1-D allowlist. Pre-existing dirty work outside this set was preserved.

### App and Application

- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopApplication/AcceptanceWorkflowController.swift`
- `Sources/AgentLoopApplication/ExternalOperationWorkflowCoordinator.swift`

### Core

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/ApprovalGrantStore.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Domain/Acceptance.swift`
- `Sources/AgentLoopCore/Domain/ApprovalGrant.swift`
- `Sources/AgentLoopCore/Domain/GoalController.swift`
- `Sources/AgentLoopCore/Domain/Outcome.swift`
- `Sources/AgentLoopCore/Domain/OutcomeContract.swift`
- `Sources/AgentLoopCore/Domain/Verification.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
- `Sources/AgentLoopCore/Mcp/McpToolBridge.swift`
- `Sources/AgentLoopCore/Tools/ApprovalGate.swift`
- `Sources/AgentLoopCore/Tools/ApprovalPolicy.swift`
- `Sources/AgentLoopCore/Tools/ExternalOperationAdapter.swift`

### Tests and matrix runner

- `Sources/AgentLoopTestSuite/AcceptanceWorkflowTests.swift`
- `Sources/AgentLoopTestSuite/ApprovalGateTests.swift`
- `Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift`
- `Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift`
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
- `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/MissionRollupTests.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`
- `Sources/AgentLoopTestSuite/VerificationContractTests.swift`
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`

## 3. Reviewed revisions and root-cause fixes

### Revision 01 — full-suite compatibility and persisted timestamps

The first full-suite red exposed accepted-history compatibility and a real
Foundation/GRDB timestamp boundary issue. The product fix is
`P1DTimestampV1.restorePersisted`: it accepts only finite persisted values
within `0.01 ms` of the nearest integer millisecond, restores the exact
contract millisecond, and fails closed outside that storage tolerance.
Approval request, grant, grant-use, and receipt reads apply it at the
persistence boundary; business equality and CAS were not weakened.

Historical tests were updated only where P1-D intentionally changes accepted
behavior: accepted Mission rework resumes executing, P1-C migration tests
remain exactly through v14 while allowing v15 to follow, ready Goals remain
contract-free before explicit activation, the cold-start golden path uses a
real existing artifact without an ungranted write, and frozen planning
manifests exclude only the exact P1-D allowlist.

### Revision 02 — cancellation terminalization race

The authoritative concurrent suite showed
`cliProcessBackendCancellationReturnsCardToReady` leaving the card `running`
and run outcome `nil`, although the isolated control passed. The root cause was
that stream termination only canceled the producer; database terminalization
waited for that producer to regain scheduling.

`CliProcessBackend` now has one lock-backed per-run terminal finalizer shared
by completion, block, cancellation, and failure paths. `.cancelled` stream
termination synchronously terminates the process intent, snapshots lock-backed
metrics, returns a still-running card to ready, and finalizes the run. The
producer catch is idempotent. The card transition occurs before run
finalization so a retry after a partial database failure cannot account spend
twice. Finalization failures are logged with card/run identity and no secret.

Current key hashes:

- `CliProcessBackend.swift`:
  `5a3f6e59c17a8ca5e8da24098c185d6926fd98db7a85eb0cb3b7c67295f70fa4`
- `Outcome.swift`:
  `8cc741e07ae7dbe27d9599986143a42ed3a442614e36fcecfc5657b972ba355c`
- `ApprovalGrantStore.swift`:
  `22b0d2475c068f4d5b4813903998e3645bc74c9e465178b8629c7c567ae5ce2b`

## 4. Red-to-green evidence

- `red-tests.log` (`60c12ed41af7bfdbef6aadeb106a83207447b6b8e1278d79f4e71abcc4508134`)
  preserves the intended missing P1-D type/API compile red.
- `verify-red.log` (`dc18a58ce6eb5d6f6de4b6b9b2c496ecdca1ddf58e8eca93036333edb26bd676`)
  preserves the 900-test concurrent red, including the compatibility failures,
  ApprovalGrant conflict/crash window, and the two CLI cancellation assertions.
- `revision01-regression.log`
  (`6de55c85862a26ad9a87ae528b25c4f96b402665fdcd4e6715590cb3025e8959`):
  10/10 grant replay runs, 15/15 compatibility filter, three isolated
  controls, diagnostic-absence, and diff gate passed.
- `revision02-regression.log`
  (`349cd3b7bbee4643a6c7b5a2a74164632c785f74aa48f8b019b6083ad6cd7bb7`):
  CLI cancellation passed 10/10 sequential runs; denial and rumination
  controls, diagnostic-absence, and diff gate passed.

## 5. Completion evidence

| Gate | Result | Evidence SHA-256 |
|---|---|---|
| Exact P1-D focused manifest | 80 tests / 4 suites passed in 2.951s | `focused-verify.log` — `80d6f87bd280bea1da5fe9d14762e581a07c6191dc1f6288c828d50a96105191` |
| SQLite migration matrix | 3.51 and 3.52 real/literal/replay/rollback/FK/integrity/DDL/append-only passed; final v15 checkpoint 55 tables / 134 indexes / 16 triggers | `migration-matrix.log` — `490704939aba695596ddbd65c0403b1e92feada43043cdfc8cc30f6a799f9a42` |
| Source/scope gate | exact 14 new canonical files, exact 80 declaration/discovery set, protected hashes, v15 authority bytes, no P1-E/F symbols; outside count 487 and manifest `3341ccc95c70eb184c6df8f5ac18e7a00f18fc0edc7bfb26cb185f35bfd0cf86` | `source-gates.log` — `7454c56160ceba0da3c3236aca6f74c05cebde93d4473a34696eae4ec286c1bb` |
| App build | `swift build --product AgentLoopApp` passed | `build.log` — `0012a6e9183d82074a84b6dde7da4e8f4ecf9485b9d67c8de284a14cd8a12c11` |
| Isolated UI failure preview | packaged app launched from a fresh state root; 27 resources; one app process/no child; failed acceptance stayed on Return Summary with a trace; mission remained delivering; Outcome/Acceptance/metric counts remained zero; graceful Cmd+Q; integrity/FK passed | `preview.log` — `9da6a3147f3bd2ff05620fda9854e8beef0fca64c8ebdfdfb2fe69006da1fbac` |
| Concurrent precheck | 900 tests / 15 suites passed in 46.218s | `revision02-full-precheck.log` — `efab7cfeb00f6c78b858ea05bf67571fcf19c31dfd83702499a6d98dcf167d15` |
| Authoritative final suite | 900 tests / 15 suites passed in 45.212s; command 0; tee 0 | `verify.log` — `b37571c23456add5b0ca197551fa4149defe318ca1b571c17684907908e5a970` |

The latest preview screenshot was 900×732 with SHA-256
`eca74402227e06ef993dc28d7f2eb41de0a78649674dfc4739a06c84ef6e6dca`.
It lived in the temporary Computer Use capture directory and is no longer
present; `preview.log` retains its path, hash, dimensions, UI text, process
facts, and database postconditions.

## 6. Evidence/harness disclosures

- The first narrow Revision 02 test itself passed 1/1, but its wrapper then
  exited nonzero because `status` is a zsh read-only variable. The corrected
  Bash wrapper and all later command/tee statuses are green; the disclosure is
  also embedded in `revision02-regression.log`.
- An early focused wrapper opened `focused-verify.log` for output before
  reading its prior filter and therefore ran an empty filter, which means the
  complete suite. That run passed and was preserved honestly as
  `revision02-full-precheck.log`. The focused filter was then rebuilt from the
  frozen 80-name plan manifest and rerun successfully.
- `verify-red.log` is the retained full concurrent red. The named `verify.log`
  was intentionally replaced only after the final authoritative run passed.
- Test warnings and deliberate migration constraint errors remain visible in
  their full logs; none was converted into a fallback or hidden.

## 7. Scope and prohibited actions

- Protected P1-C/master/Package/RunTests hashes passed.
- Dirty paths outside P1-D remain byte-identical to the accepted outside
  manifest.
- No reset, revert, commit, push, merge, release, payment, provider call,
  normal user-data mutation, public communication, or real-user action was
  performed.
- No secret or raw external response was logged.
- Claude and delegated agents were not used, per the user's instruction.

Open implementation questions: none.
