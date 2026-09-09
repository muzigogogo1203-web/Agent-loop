# P1-C implementation report

Status: implementation and all stage-wide validation gates complete. Review02
and acceptance are the only remaining P1-C gates.

## Frozen authority

- plan SHA-256:
  `142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c`
- final approved plan review: Review01H, SHA-256
  `615392ebb1c051fec0d4ca63f8c4972cc0259f5b32d83a8890ac9d0b5afb92d9`,
  `APPROVED — 0 P0 / 0 P1`;
- preserved approved Review01E/01F/01G SHA-256 values:
  `97c3171dcc7f86bb7c08ca48c06468380e0602be0503b9583faee1b8b24df2ad`,
  `30a43932985d9a74009a6d70f03ddfe8822e54a9665d674db2c5fac32d2120be`,
  and `18b744362a1732716af8f3c42128e06e4634df7e9e47902f21cf7e21483ba920`;
- branch / HEAD:
  `codex/personal-ai-ranch-p0` /
  `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## Batch ledger

### C1 — v14 migration

- Exact `v14-p1-control-contracts` migration and SQLite matrix carrier are
  implemented.
- Focused result: 9 tests / 1 suite passed.
- Authenticated SQL SHA-256:
  `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531`.
- `AppDatabase.swift` strip-to-preimage SHA-256:
  `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b`.

### C2 — command/event contract

- Closed vocabulary, canonical command/result/audit contracts,
  `DomainEventStore`, outbox/inbox behavior, and pure replay-plan factories are
  implemented.
- Focused result: 25 tests / 1 suite passed; C2 was rerun after C3 and remained
  25/25 green.

### C3 — Input/parsing/application seam

Implemented:

- exact Input projection values, persisted record coding, command payloads,
  transition fence, Camp-scope validation, and tombstone construction;
- atomic capture + parsing-work enqueue, parse success, retry/exhaustion,
  cancellation, ordinary transition active-work fencing, and receipt replay;
- expired lease adoption for `.inputParsing` and `.coach` in the authenticated
  final `DurableWorkStore` extension;
- structured parsing worker with one pre-await persisted snapshot, renewable
  latest-claim ownership, deterministic invalid-output terminalization, and
  bounded recovery behavior;
- process-wide atomic local installation identity and the isolated
  Application capture/read seam; and
- display-only legacy ingestion projection.

Changed/created C3 carriers:

- `Sources/AgentLoopCore/Domain/InputEnvelope.swift`
- `Sources/AgentLoopCore/Database/InputGoalStore.swift`
- `Sources/AgentLoopCore/Work/InputParsingWorker.swift`
- final marker block in
  `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopApplication/LocalCaptureIdentity.swift`
- final marker block in
  `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift`

Focused result: 33 tests / 1 suite passed. The authoritative framed C1/C2/C3
stdout/stderr is in `focused-verify.log`; the latest C3 frame finished at
`2026-08-25T23:58:53Z` with exit 0.

Post-C3 gates:

- exact C3 discovery: 1 suite, 33 unique tests;
- `git diff --check`: passed;
- controller strip-to-preimage:
  `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb`;
- adoption-store strip-to-preimage:
  `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa`;
- outside dirty-worktree guard:
  `dirty_total=478`, `allowlisted_present_count=30`, `outside_count=448`,
  `outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0`.

### C4 — Goal / Coach / Understanding

Implemented:

- atomic Input-to-Goal conversion with caller-owned Goal identity, exact Input
  then Goal events, Camp ambiguity fail-closed behavior, and replay before
  projection reads;
- the v14 Goal projection and P1-C-only transition fence: only clarifying,
  ready, abandoned, and failed are writable; no P1-D activation or
  OutcomeContract API was introduced;
- one-total-Session and one-open-Question invariants, actor/device authority,
  caller-owned session/question IDs, persisted resume, and sealed branch
  replay;
- durable Coach turn work with canonical sealed input, derived decision key,
  one persisted pre-await provider snapshot, structured renewal, adoption,
  cancellation recovery, deterministic invalid-output failure, and latest
  claim terminalization;
- Understanding content hashing and append-only content versions, draft and
  awaiting transitions without body rewrite, user-only confirmation,
  supersession only on replacement confirmation, and ready-Goal head joins;
- clarifying-Goal versus ready-revision failure scopes, bounded retry,
  terminal Session-only preservation for ready Goals, and atomic Goal terminal
  cancellation of active control work; and
- exact result-shape correction for `proposeUnderstanding`: the terminalized
  existing Coach work contributes `durableWork`, but no nonexistent next
  Question reference. The C2 25-test contract batch remained green after this
  correction.

Changed/created C4 carriers:

- `Sources/AgentLoopCore/Domain/GoalController.swift`
- `Sources/AgentLoopCore/Domain/CoachContracts.swift`
- `Sources/AgentLoopCore/Domain/UnderstandingCard.swift`
- `Sources/AgentLoopCore/Database/InputGoalStore.swift`
- `Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift`
- `Sources/AgentLoopCore/Domain/DomainEvent.swift`
- final authenticated `CoachTurnProcessor` marker block in
  `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift`

Focused result: 35 tests / 1 suite passed. The authoritative frame in
`focused-verify.log` finished at `2026-08-26T00:48:39Z` with exit 0. C2 and C3
were rerun before that final C4 frame and remained 25/25 and 33/33 green.

## Exact source and test images

Sixteen new regular nodes were absent at planning entry and now have these
exact images:

| Path | Post-image SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift` | `b15c1f9fc8d602b834eb517cefc7e27437da3d576cc4d388d9f6472032ccdcaa` |
| `Sources/AgentLoopCore/Domain/CommandEnvelope.swift` | `a2117c80b0c7d052b35b38de98f9b9f846fc965cb9b2f9278c18455b6081f39e` |
| `Sources/AgentLoopCore/Domain/DomainEvent.swift` | `876896f4d48ab1614630dcbf7075b2a4bcb1a8ba309605c10eeb976c1e59b925` |
| `Sources/AgentLoopCore/Domain/InputEnvelope.swift` | `4dff9dcfa6032f1127bcfcbbd4a1d66753783c07c0c5d5f70c95460e079dd72c` |
| `Sources/AgentLoopCore/Domain/GoalController.swift` | `f2580c7393d9a9c1eef8455964ed0b3b3772ab438cd5c2d55471a68f53f7cfd8` |
| `Sources/AgentLoopCore/Domain/CoachContracts.swift` | `0cadfc98b6e03c3d7fc0e05123643cf3044c920b312426034aa04f9683c3f133` |
| `Sources/AgentLoopCore/Domain/UnderstandingCard.swift` | `e8accd2603279320014c567de1af852fb7f2efca615bfb57cf5ba8b0de35820e` |
| `Sources/AgentLoopCore/Database/DomainEventStore.swift` | `e41f3f9b0a06d7bdba5d8afb7cd9e0308ae46298dd58aa48ee27f688f9f26db5` |
| `Sources/AgentLoopCore/Database/InputGoalStore.swift` | `5f6dd93127b8b11cec76fd76e1645636d6438f8f6c6039b38317fd3195a1ff00` |
| `Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift` | `daa3a9bea1c7ad05e4553b5f13c616fba2d1542bf6afd9747eceb82e0f55a2e3` |
| `Sources/AgentLoopCore/Work/InputParsingWorker.swift` | `07057c5a47ac7631059393da30a1b44653349fc6ebfbb3f16560f948c279742b` |
| `Sources/AgentLoopApplication/LocalCaptureIdentity.swift` | `c40070d84c6e867a83cf259ef11fbce187077d2da0a284ca14b21cefa4a8ed35` |
| `Sources/AgentLoopTestSuite/DomainEventContractTests.swift` | `c05a7736b49dee3b83229f4777cca5928d6555ffa1e2f931a70551a0e96d4aec` |
| `Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift` | `81f3af4e05169595ec239a10668532d7e68f8a540d43c3180760613fa6114d89` |
| `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift` | `c7047d48e8e5d08fcbdf193b94234ac8de2d81a5ac3f88f62529330b217ad9b4` |
| `Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift` | `1d37bf962015a372f068b98561707697c1abb4165e493f799c3b23b2958eef35` |

Existing carriers changed only through their reviewed deltas:

| Path | Frozen pre-image SHA-256 | Post-image SHA-256 |
|---|---|---|
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` | `3a393821dc86d8ac9bdf89cff48453ed1866919c7dfcdf443e597a96737b878b` |
| `Sources/AgentLoopCore/Database/EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` | `67ca50ba59b0ec191a3543e7af5a39164e644909219a6b621a929d084991c117` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` | `71e2dd602cf59647fd9dc5c0bd5a74eeb770f6b4d91010744c4a40b91ae28b6e` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `Sources/AgentLoopApplication/InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` | `0021a0cb8b5d80624cc5bd49fd5d96cc96202bf8da73d3c911e2d5453aeca17f` |
| `Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift` | `35050a360d84cdac4c14c748a691bfbf277c62fb7b4fb96861dfcd910417a962` | `c8afc50f5af67d4544ba399523aed34bb7c974e4e67dca259f813a3345ec5238` |
| `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` | `c12b8594d96de9c59c3712a0e5446d53531ccec23e7e4279c2848d986ca308e9` | `f125868304f7f6929e3ec2f20ec15a90761ec131797db135d1f018eee2618ed4` |
| `Sources/AgentLoopTestSuite/FailureVisibilityTests.swift` | `8bb8f168a150b4bae44163bbd8c86dedad81e5314a37a836517538f77906b553` | `1b12cab12cf4b1855ac1865c3314e60974b4df6f96c5952f252fe667ab8343d4` |
| `Sources/AgentLoopTestSuite/BoardServerTests.swift` | `2ab9a4cf8f843d3da6bca6f6bb2ad0fd82c007593ebbe46c0530bfc1eff5b1f9` | `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` | `ef010fb358e0ecd84ffd1a4941c761341e6732edf2c5ab8d52cad049019bf4b9` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` | `2b4be14c268560aaf254a3026c70b27c208f30f6e1a1c99048382ec898dde97f` |

The five existing product carriers pass strip-to-preimage gates, and the source
gate separately proves their exact top-level/package surfaces. No byte outside
the reviewed deltas is claimed by P1-C.

## Full-gate closure

- Revision 6 preserved the 467-line failed App build as `build-red.log`
  (`bf6ff041…05e`) and repaired only the preview constructor. The final App
  build ran `2026-08-26T01:40:21Z`, completed in 0.34 seconds, and exited 0;
  `build.log` SHA-256 is
  `5bafc273fbd225c0bb2e64232c22cfaa984ea1bad79b8b524280e6c53967e731`.
- Revision 7 preserved the 1,680-line 816-test failure as `verify-red.log`
  (`d156975e…fca1`). Its three exact test-harness repairs made both v13 tests and
  loaded socket framing green. Revision 8 then transferred the already-changed
  Board test into both exact historical successor sets; the same five-test
  filter passed 5/5 at `2026-08-26T01:36:01Z`. The combined focused log SHA-256
  is `fcf88c948991543a0512774bde2a247d3e3a1a50cc5c9bccbcc6dbd0995f3424`;
  the 438-line pre-Revision-8 snapshot remains frozen as
  `focused-rev7-red.log` (`44a4c621…c85f`).
- The SQLite matrix ran from `2026-08-26T01:36:27Z` to `01:38:17Z` and passed
  real and literal v14 lanes on SQLite 3.51.0 and 3.52.0. Every required
  predecessor, replay, FK, integrity, DDL, append-only, and rollback sentinel
  passed; both lanes end at 41 tables / 94 indexes / 8 triggers.
  `migration-matrix.log` SHA-256 is
  `957fcc38bbcccdf6dabe465f4673e6e3c0dba890a67cc554133bfbca6374ccfe`.
- The first final source-gate wrapper wrote its capture inside the repository,
  so the serializer correctly rejected that transient unallowlisted file. The
  failure frame is preserved at the front of `source-gates.log`; after moving
  the capture to ignored `.build`, the exact unchanged gate passed from
  `2026-08-26T01:39:46Z` to `01:39:51Z`: approved plan hash, all protected
  hashes, 16 new regular nodes, P1-D fence, 102 exact declarations/discovery,
  outside manifest, and `git diff --check`. Final log SHA-256 is
  `8a8145219c4e54a48c089a3b2a75ba6b5e75ebc90be480b8dd3703c6b579a4e2`.
- The authoritative unfiltered `swift run RunTests` ran last from
  `2026-08-26T01:40:39Z` to `01:41:23Z`: 816 tests / 11 suites passed in
  44.151 seconds, exit 0. `verify.log` SHA-256 is
  `9262b2b9c9725a41215cecaf9d0c75151e5f2de6a4b91edd13e433b3e51d1cbe`.

The final source gate recorded `outside_count=446` and
`outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75`.
Only informational allowlisted counts change as report/review/acceptance
artifacts materialize.

## Contract assertions and boundaries

The green evidence covers expired-only same/foreign-owner recovery for both
control kinds, latest-claim renewal handoff, monotonic terminal time and checked
backoff, all-command actor/device authorization before SQL, one persisted
provider snapshot, inbox savepoint rollback with durable rejection, exactly one
Coach session and one open question, joined confirmed-Understanding head
validation, and independent local identity adapter convergence. Receipt,
projection, event, outbox, work, and terminal mutations remain transactionally
total; replay does not call providers or factories again.

P1-C ends at `Goal.ready`. No active/paused/achieved reducer,
`OutcomeContract`, v15 schema, fake validator, external provider action, Camp
retirement, or P1-D/E/F behavior was introduced. The preview and App were not
launched.

## Deviations and prohibited actions

There is no unreviewed product deviation. Revisions 6–8 were frozen and
approved before their exact writes: one compile-only preview repair, three
test-harness successor repairs, and one historical ownership-set completion.
The source-gate wrapper self-contamination was an evidence-path error, not a
gate or code failure; its red frame is retained and the unchanged gate then
passed with the outside digest restored.

No commit, push, merge, reset, revert, release, package publication, payment,
destructive data operation, public communication, real-user action, App launch,
or preview launch was performed.

## Remaining gate

Only the separate read-only Review02 and acceptance passes remain. No source,
test, migration, or build change is pending.
