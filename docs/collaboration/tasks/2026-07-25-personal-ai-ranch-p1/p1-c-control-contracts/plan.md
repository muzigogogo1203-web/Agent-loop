# P1-C Control Contracts — Decision-Complete Implementation Plan

> Status: **REVISION 8 FROZEN CANDIDATE — successor-ownership closure pending Review01H**  
> Date: 2026-08-25  
> Slice: P1-C — Event / Input / Goal / Coach / Understanding  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Planner: current Codex implementation owner, acting under the user's explicit
> no-Claude override  
> Required reviewer: a disclosed read-only Codex self-review under the user's
> direct no-Claude/no-delegation override; no independence claim may be made

## 1. Authority, entry gate, and stop condition

The normative inputs are:

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`;
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
  §5, §10, §11, §12, and §13;
- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
  §5, §8–§11, §18.4, §20 P1-C, §21, §22, and §23;
- `AGENTS.md` and
  `docs/collaboration/claude-codex-protocol.md`; and
- the accepted P1-B closeout chain.

Frozen authority hashes at planning entry:

| Input | SHA-256 |
|---|---|
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Accepted master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| Existing `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |

P1-B is accepted and its documentation closeout is independently approved at
zero P0/P1/P2. Review01 is preserved at
`reviews/01-p1-c-plan-review.md`, SHA-256
`08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b`,
with `CHANGES REQUIRED — 0 P0 / 6 P1 / 0 P2`. Review01A is preserved at
`reviews/01a-p1-c-plan-review.md`, SHA-256
`cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a`,
with `CHANGES REQUIRED — 0 P0 / 4 P1 / 0 P2`. Review01B is preserved at
`reviews/01b-p1-c-plan-review.md`, SHA-256
`52391a6cf2612211f1a3612e5fb5379101cb2c90f644430c7fe04e5398a4e4de`,
with `CHANGES REQUIRED — 0 P0 / 8 P1 / 0 P2`. Review01C is preserved at
`reviews/01c-p1-c-plan-review.md`, SHA-256
`c07a305be3c0fae8e8f26fb02622c4d862997f20b5fc6b5ffe1778a89c7f9053`,
with `CHANGES REQUIRED — 0 P0 / 9 P1 / 0 P2`. Review01D is preserved at
`reviews/01d-p1-c-plan-review.md`, SHA-256
`b734b7e810f881945c8530a8ec5f9effe7e40dac9ef73c5d73e9063d987fb43b`,
with `CHANGES REQUIRED — 0 P0 / 4 P1 / 0 P2`. Review01E is preserved at
`reviews/01e-p1-c-plan-review.md`, SHA-256
`97c3171dcc7f86bb7c08ca48c06468380e0602be0503b9583faee1b8b24df2ad`,
with `APPROVED — 0 P0 / 0 P1`. Revision 6 then added only the exact compile-only
fixture repair in §3.3. It was approved by the disclosed Review01F self-review,
preserved at `reviews/01f-p1-c-plan-review.md`, SHA-256
`30a43932985d9a74009a6d70f03ddfe8822e54a9665d674db2c5fac32d2120be`,
with `APPROVED — 0 P0 / 0 P1`; the repaired App build exits zero. The first
unfiltered authoritative run after that repair executed 816 tests in 11 suites
and exited 1 with 10 issues while all 102 P1-C tests passed. Its exact red log is
frozen by §3.4. The failures reduce to three test-harness successor causes:
historical frozen-manifest ownership, a v13 helper that incorrectly requires
v13 to remain globally final after v14, and a one-second local socket deadline
that is insufficient only under full-suite load. Revision 7 added only the
exact test-only repairs and authentication gates in §3.4. It was approved by
the disclosed Review01G self-review, preserved at
`reviews/01g-p1-c-plan-review.md`, SHA-256
`18b744362a1732716af8f3c42128e06e4634df7e9e47902f21cf7e21483ba920`,
with `APPROVED — 0 P0 / 0 P1`, and all three planned post-images were produced
exactly. Its five-test focused run then proved the two v13 tests and the loaded
socket test green but left one A3 and one A4 hash mismatch. Read-only enumeration
proved both remaining paths are exactly the newly changed
`BoardServerTests.swift`: the Revision 7 helper transferred the original 24
P1-C paths but omitted its own authorized test-harness successor. Revision 8
adds only that path to the historical ownership helper as frozen by §3.5; every
prior review remains immutable.

Revision 8 test write and final-gate execution remain closed until the
disclosed Review01H self-review records
`APPROVED` with zero P0/P1 and the revised plan hash is unchanged after
materializing that review. This process exception implements the user's direct
instruction to continue without Claude or another agent and must not be
described as an independent review.

If Review01H finds P0/P1, preserve it as a new immutable review artifact and
revise only this plan before another fresh review. If implementation later
discovers an ambiguity that changes
the data model, public/package API, write set, event count, state transition,
or completion gate, write the exact question to `blocked.md` and stop. Do not
guess and do not widen the allowlist.

## 2. Goal and non-goals

### Goal

Deliver the P1-C contract foundation:

1. exact replayable `v14-p1-control-contracts` DDL;
2. a sealed canonical command envelope and Camp-safe receipt/event JSON;
3. transaction-only command receipt, domain event, outbox, and inbox behavior;
4. durable Input capture/parsing with no `parsing` projection;
5. Goal, CoachSession, CoachQuestion, and UnderstandingCard flows through
   `Goal.ready`;
6. local-capture installation identity and application-layer capture seam;
7. display-only legacy ingestion compatibility; and
8. contract, migration, crash/replay, CAS, and idempotency evidence.

### Non-goals and hard scope boundary

- No runtime SwiftUI or current screen-flow changes. Revision 6 permits only
  the compile-only preview-fixture constructor repair frozen in §3.3; Revision
  7 permits only the three test-harness successor repairs frozen in §3.4, and
  Revision 8 permits only the one historical ownership-set completion frozen in
  §3.5. The preview is not launched.
- No `OutcomeContract`, Outcome, Verification, Acceptance, Grant, Goal
  activation, `active`, pause/resume, or achieve command. The v14 Goal columns
  and enum cases required by the frozen DDL exist, but P1-C writes neither an
  outcome reference nor an active/paused/achieved transition.
- No fake v15 validator or placeholder OutcomeContract row.
- No P1-D/E/F implementation, Camp retirement, cloud dispatch, sync, external
  provider call, real user action, preview, packaging, release, or deployment.
- No backfill of historical Mission to Goal and no creation of fake
  InputEnvelope rows from legacy ingestion.
- No inference of a Camp from `campId == nil`, a candidate list, a default
  Camp, path, source type, or prior UI selection.
- No second JSON canonicalizer, no error-swallowing fallback, no secret,
  account identifier, raw prompt, path, URL, or external session/operation ID
  in append-only JSON.
- No commit, push, merge, reset, revert, release, destructive data operation,
  payment, public communication, or real-user operation.

The generic §9.2 statement that `startNow` ultimately produces an
OutcomeContract is staged at P1-D by the later and more specific §10.1,
canonical plan §5.6, and the current route override. P1-C may preserve
`explicitIntent = startNow`, create/confirm Understanding, and reach
`Goal.ready`; it must not report started/active or fabricate the v15 half.

## 3. Exact write allowlist

### 3.1 Product and contract tests

Only these product/test paths may change or be created:

1. `Sources/AgentLoopCore/Database/AppDatabase.swift`
2. `Sources/AgentLoopCore/Database/EventKind.swift`
3. `Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift` (new)
4. `Sources/AgentLoopCore/Domain/CommandEnvelope.swift` (new)
5. `Sources/AgentLoopCore/Domain/DomainEvent.swift` (new)
6. `Sources/AgentLoopCore/Domain/InputEnvelope.swift` (new)
7. `Sources/AgentLoopCore/Domain/GoalController.swift` (new)
8. `Sources/AgentLoopCore/Domain/CoachContracts.swift` (new)
9. `Sources/AgentLoopCore/Domain/UnderstandingCard.swift` (new)
10. `Sources/AgentLoopCore/Database/DomainEventStore.swift` (new)
11. `Sources/AgentLoopCore/Database/InputGoalStore.swift` (new)
12. `Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift` (new)
13. `Sources/AgentLoopCore/Work/InputParsingWorker.swift` (new)
14. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
15. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
16. `Sources/AgentLoopApplication/InputWorkflowController.swift`
17. `Sources/AgentLoopApplication/LocalCaptureIdentity.swift` (new)
18. `Sources/AgentLoopTestSuite/DomainEventContractTests.swift` (new)
19. `Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift` (new)
20. `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift` (new)
21. `Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift` (new)
22. `Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift`
23. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
24. `Sources/AgentLoopTestSuite/FailureVisibilityTests.swift`
25. `Sources/AgentLoopTestSuite/BoardServerTests.swift`

The upstream permissive list also names `DurableWork.swift`,
`DurableWorkSupervisor.swift`, `DurableWorkStore.swift`, and
`DurableWorkTests.swift`. Current inspection shows that `.inputParsing`,
`.coach`, canonical input validation, enqueue/claim/renew/adopt/complete/
retry/cancel, and transaction-local static mutations already exist. The generic
planning/rumination lifecycle remains byte-for-byte frozen. P1-C requires one
additional lease-fenced adoption entry point, so `DurableWorkStore.swift` is
writable only for one final marker-delimited
`ExpiredControlWorkAdoption` extension block. Removing that exact final block
must restore SHA-256
`3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa`;
the block may add only `adoptExpiredControlWork` as specified by §7.3.
`DurableWork.swift` and `DurableWorkTests.swift` remain read-only.
`DurableWorkSupervisor.swift` is writable only for one final, marker-delimited
P1-C `CoachTurnProcessor` declaration block. Removing that exact final block
must restore its planning-entry hash byte-for-byte; no existing A1/A2 byte may
change. Any broader edit to either carrier requires another reviewed plan
revision.

The other three existing product carriers are insertion-only and use the same
strip-to-preimage rule; no existing byte may be replaced, reordered, or
deleted:

- `AppDatabase.swift` receives exactly one block immediately before the
  existing `return m` in `AppDatabase.migrator`, delimited by
  `// P1-C-BEGIN V14ControlContractsMigration` and
  `// P1-C-END V14ControlContractsMigration`. The block contains only the one
  `m.registerMigration("v14-p1-control-contracts")` call and its exact §18.4
  SQL. Removing the complete marker block including its inserted terminal
  newline restores SHA-256 `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b`.
- `EventKind.swift` receives one final block delimited by
  `// P1-C-BEGIN ControlContractVocabulary` and
  `// P1-C-END ControlContractVocabulary`. Its only top-level declarations are
  the five closed enums `P1AggregateTypeV1`, `P1CommandTypeV1`,
  `P1EventTypeV1`, `P1ResultCodeV1`, and `P1AuditCodeV1`. Removing that final
  block restores SHA-256
  `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4`.
- `InputWorkflowController.swift` receives one final block delimited by
  `// P1-C-BEGIN LocalInputCaptureWorkflow` and
  `// P1-C-END LocalInputCaptureWorkflow`. Its only top-level declarations are
  `InputCapturePorts`, `LocalInputCaptureRequestV1`, and the separate
  `InputCaptureWorkflowController` actor specified by §9. The existing
  `InputWorkflowController` type, stored properties, initializer, methods, and
  every pre-existing byte remain unchanged. Removing the final block restores
  SHA-256 `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb`.

The executable gate strips all five existing-product blocks, hashes each
reconstruction, validates their exact top-level/package API surface, and scans
only the authenticated P1-C deltas plus new product files for P1-D behavior.
Thus a path allowlist is never treated as permission for arbitrary edits.

### 3.2 Mandatory migration verification carriers

The following two test-only carriers are additionally writable:

26. `Sources/P1MigrationMatrixRunner/main.swift`
27. `scripts/verify-p1-migrations-sqlite-matrix.sh`

This is not a product expansion. Canonical plan §10 requires the introducing C
slice to run every predecessor plus v13 through the v14 literal fence and the
same real GRDB migrator on SQLite 3.51 and 3.52. The current carriers terminate
at v13 and cannot prove that gate without this exact extension. Their delta is
limited to v14 schema extraction/argument binding, the new v13 predecessor,
v14 object/constraint/append-only/replay/rollback assertions, and corresponding
sentinels. They may not change package resolution, build graph, old fixture
semantics, old v12/v13 sentinels, or SQLite source/linkage selection.

### 3.3 Revision 6 App-build recovery

The first authoritative `swift build --product AgentLoopApp` after all P1-C
contract, migration, and source gates failed deterministically in
`CodingRanchPreviewFixtures.review`. P1-B changed
`RuminationReviewViewState` from a direct `missionDraft` field to the accepted
`SuggestedMissionReviewViewState` wrapper and added the opaque
`InputMissionDraftStartCapability?` field, but that committed preview-only
callsite was outside P1-B's write list and retained the old memberwise
initializer. The later SwiftUI `Group` diagnostics are compiler cascades from
that invalid fixture expression, not a separate view-design decision.

The one newly writable path has pre-image SHA-256
`35050a360d84cdac4c14c748a691bfbf277c62fb7b4fb96861dfcd910417a962`
and may receive exactly one replacement in `static let review`:

- replace the `missionDraft:` argument with
  `suggestedMission: SuggestedMissionReviewViewState(...)`;
- place the byte-identical existing `MissionDraftViewState` fixture inside its
  `draft:` field;
- set `canStart: false`,
  `startBlockReason: "预览不连接真实启动能力"`, and
  `startCapability: nil`, matching the production invariant that UI cannot
  manufacture an opaque start capability; and
- set wrapper `why` to
  `"原文和用户补充共同形成了明确目标与验收清单。"`.

No other byte in the fixture or any runtime view may change. The exact expected
post-image SHA-256 is
`c8afc50f5af67d4544ba399523aed34bb7c974e4e67dca259f813a3345ec5238`.
The existing failed `build.log` (467 lines, SHA-256
`bf6ff041aeb8686734000d40527ea2d564983ddadb5859e534876668cb4ea05e`)
is the pure red evidence and must first be atomically preserved unchanged as
`build-red.log`. After Review01F approval, apply only this replacement, require
the post-image hash, then rerun
the complete §11 final sequence in order. A second build failure invalidates
the single-root-cause hypothesis and returns this revision to blocked review;
it does not authorize another code change.

### 3.4 Revision 7 authoritative-full-test successor closure

The first authoritative unfiltered run after Revision 6 is preserved from the
current `verify.log` as `verify-red.log` before any test edit. It contains 1,680
lines, has SHA-256
`d156975e9b5018419e48f17c66cfce645ea1702fb990095dcb6facc4bdc5fca1`,
and records 816 tests in 11 suites, exit 1, with 10 issues. All 102 P1-C tests
passed. The only failing tests and causes are:

1. `a3Revision02EntryBoundaryRemainsByteExact` and
   `broadcastFailureDoesNotRewriteStartedFire` still treat successor-owned P1-C
   source nodes as immutable A3/A4 entry bytes;
2. `observabilityMigrationRollbackLeavesV12ScheduleUntouched` and
   `observabilityMigrationExactDDLAndConstraints` correctly inspect v13 in
   isolation via `migrate(upTo: "v13-p1-observability")`, but their shared
   helper also requires v13 to remain the final migration after accepted v14;
   and
3. `boardServerFramingForwardsToolCallsWhenSocketsAreAllowed` receives EOF from
   its test client's one-second `SO_RCVTIMEO` after 1.133 seconds under the
   816-test run. The exact test passes alone in 0.045 seconds, so the protocol,
   tool-call, and terminal assertions are sound and the defect is the
   load-sensitive harness deadline.

No product source, migration, public/package API, production timeout, or test
assertion may change in this revision. The three test paths have exact
pre-images and permitted post-images:

| Path | Pre-image SHA-256 | Exact post-image SHA-256 |
|---|---|---|
| `DurablePlanningTests.swift` | `c12b8594d96de9c59c3712a0e5446d53531ccec23e7e4279c2848d986ca308e9` | `4a2f01ba373247bd9912f2af84b405d98dc122e5e11ab421ef83342947d98d77` |
| `FailureVisibilityTests.swift` | `8bb8f168a150b4bae44163bbd8c86dedad81e5314a37a836517538f77906b553` | `1b12cab12cf4b1855ac1865c3314e60974b4df6f96c5952f252fe667ab8343d4` |
| `BoardServerTests.swift` | `2ab9a4cf8f843d3da6bca6f6bb2ad0fd82c007593ebbe46c0530bfc1eff5b1f9` | `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |

`DurablePlanningTests.swift` receives one new private
`a3P1CExactAllowlist() -> Set<String>` helper containing exactly these 24
successor-owned paths and no task-document path:

```text
Sources/AgentLoopCore/Database/AppDatabase.swift
Sources/AgentLoopCore/Database/EventKind.swift
Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
Sources/AgentLoopCore/Domain/CommandEnvelope.swift
Sources/AgentLoopCore/Domain/DomainEvent.swift
Sources/AgentLoopCore/Domain/InputEnvelope.swift
Sources/AgentLoopCore/Domain/GoalController.swift
Sources/AgentLoopCore/Domain/CoachContracts.swift
Sources/AgentLoopCore/Domain/UnderstandingCard.swift
Sources/AgentLoopCore/Database/DomainEventStore.swift
Sources/AgentLoopCore/Database/InputGoalStore.swift
Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift
Sources/AgentLoopCore/Work/InputParsingWorker.swift
Sources/AgentLoopCore/Database/DurableWorkStore.swift
Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
Sources/AgentLoopApplication/InputWorkflowController.swift
Sources/AgentLoopApplication/LocalCaptureIdentity.swift
Sources/AgentLoopTestSuite/DomainEventContractTests.swift
Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift
Sources/P1MigrationMatrixRunner/main.swift
scripts/verify-p1-migrations-sqlite-matrix.sh
```

In the A4 manifest assertion, require helper count 24, require its manifest
intersection to equal exactly `EventKind.swift` plus the preview fixture (count
2), filter both the existing P1-B intersection and that P1-C intersection, and
require 158 unaffected entries instead of 160. In the A3 Revision02 assertion,
require helper count 24 and raw manifest intersection count 4: `EventKind.swift`,
the preview fixture, matrix runner, and matrix script. Subtract the historical
A4 exclusions and P1-B successor exclusions and require the remaining P1-C
successor set to equal exactly `EventKind.swift` plus the preview fixture (count
2). Filter that set from `liveEntries` and the complete P1-C helper from live
source enumeration, changing both exact counts from 156 to 154. Remove only
`EventKind.swift` from the local historical `frozenEntryHashes`, changing that
count from 3 to 2; §11.2 separately strip-authenticates its frozen pre-image, so
this transfers ownership without weakening historical or current byte gates.
No manifest artifact is edited.

In `FailureVisibilityTests.swift`, remove only the
`finalMigration == "v13-p1-observability"` conjunct and its preceding comma from
`p1bRequireV13Migration`, and remove only the word `final` from the assertion
message. The helper must continue to require v13's presence and its exact
immediate-successor index after v12 schedule; the two tests continue to migrate
explicitly `upTo` v13 and retain every v13 schema, rollback, replay, and data
assertion. P1-C's own tests and matrix retain sole authority for v14 final order.

In `BoardServerTests.swift`, change only
`timeval(tv_sec: 1, tv_usec: 0)` to `timeval(tv_sec: 5, tv_usec: 0)` in
`BoardSocketTestClient.init`. Five seconds matches the suite's existing cleanup
bounds. EOF, hello, protocol, tool-result, database-terminal, and socket-safety
assertions remain unchanged; no retry is added.

Review01G approved this boundary. Execution atomically preserved `verify-red`,
produced all three exact post-images, and ran the one five-test filter in the
listed order. The migration and socket tests passed; the A3 and A4 tests each
reported one remaining hash mismatch. The complete focused evidence is the
terminal frame in the current 438-line `focused-verify.log`, SHA-256
`44a4c621e0d7c70da18d9080283bf56de5dd346e924aa23efdebe453a685c85f`,
with start `2026-08-26T01:26:59Z`, test exit 1, five tests, and two issues. Per
the stop rule, no final-gate rerun occurred.

### 3.5 Revision 8 historical-manifest ownership closure

Read-only enumeration of both manifests with the exact Revision 7 P1-B/P1-C
exclusions returns one and only one mismatch in each lane:

```text
A4_MISMATCH Sources/AgentLoopTestSuite/BoardServerTests.swift 2ab9a4cf8f843d3da6bca6f6bb2ad0fd82c007593ebbe46c0530bfc1eff5b1f9 249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b
A3_MISMATCH Sources/AgentLoopTestSuite/BoardServerTests.swift 2ab9a4cf8f843d3da6bca6f6bb2ad0fd82c007593ebbe46c0530bfc1eff5b1f9 249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b
```

This is not a fourth functional failure and does not add a write path:
`BoardServerTests.swift` is already an exact Revision 7 carrier, and its old and
new hashes are independently frozen. Revision 8 may change only
`DurablePlanningTests.swift` from exact pre-image
`4a2f01ba373247bd9912f2af84b405d98dc122e5e11ab421ef83342947d98d77`
to exact post-image
`f125868304f7f6929e3ec2f20ec15a90761ec131797db135d1f018eee2618ed4`
as follows:

- add exactly `Sources/AgentLoopTestSuite/BoardServerTests.swift` after
  `ControlContractMigrationTests.swift` in `a3P1CExactAllowlist`, changing both
  helper-count assertions from 24 to 25;
- require the A4 P1-C manifest intersection to equal EventKind, the preview
  fixture, and BoardServer (count 3), and change unaffected count 158 to 157;
- require the A3 raw P1-C intersection to equal those three paths plus the
  matrix runner and script (count 5), require the post-A4/P1-B successor set to
  equal those same three source paths (count 3), and change both live/enumerated
  counts from 154 to 153; and
- change no helper, manifest, historical hash, functional Board assertion,
  timeout, product source, or other byte.

After Review01H approval, first copy the hash-verified current
`focused-verify.log` unchanged to `focused-rev7-red.log`, apply the one exact
post-image, and rerun the same five-test filter exactly once under a
`/bin/bash` pipefail evidence wrapper into `focused-verify.log`. Only if all five
pass may the complete §11 matrix, source gate, App build, and unfiltered full
run execute in order. Any new failure requires fresh root-cause analysis and a
reviewed scope change; no blind retry, product edit, assertion reduction,
manifest rewrite, or fallback is authorized.

### 3.6 Task artifacts

Only these task-local artifacts may be created/updated:

- `plan.md`;
- `blocked.md` only on a real blocker;
- `red-tests.log`;
- `focused-verify.log`;
- `focused-rev7-red.log`;
- `migration-matrix.log`;
- `source-gates.log`;
- `build-red.log`;
- `build.log`;
- `verify-red.log`;
- `verify.log`;
- `impl-report.md`;
- `reviews/01-p1-c-plan-review.md`;
- `reviews/01a-p1-c-plan-review.md`;
- `reviews/01b-p1-c-plan-review.md` only for the fresh Revision 2 review;
- `reviews/01c-p1-c-plan-review.md` only for the fresh Revision 3 review;
- `reviews/01d-p1-c-plan-review.md` only for the fresh Revision 4 review;
- `reviews/01e-p1-c-plan-review.md` only for the fresh Revision 5 review;
- `reviews/01f-p1-c-plan-review.md` only for the disclosed Revision 6
  self-review;
- `reviews/01g-p1-c-plan-review.md` only for the disclosed Revision 7
  self-review;
- `reviews/01h-p1-c-plan-review.md` only for the disclosed Revision 8
  self-review;
- `reviews/02-p1-c-implementation-review.md`;
- `acceptance.md`.

No root status/master-spec/progress-ledger update occurs until reviewed P1-C
acceptance. Such a post-acceptance fact sync requires its own bounded
docs-only closeout or an acceptance-authorized append; it is not part of this
implementation write set.

### 3.7 Frozen pre-images and dirty-worktree guard

Existing writable carrier pre-images:

| Path | Planning-entry SHA-256 |
|---|---|
| `AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `DurableWorkStore.swift` strip pre-image | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` |
| Matrix runner | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` |
| Matrix script | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` |

Explicit read-only pre-images:

| Path | Planning-entry SHA-256 |
|---|---|
| `DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |

All new source/test paths were absent at planning entry. The NUL-safe,
mode/type/path/content preservation manifest excludes the exact write
allowlist, task artifacts, and the two individually hash-frozen read-only
durable-work carriers above. Those two are excluded from the aggregate only to
keep their existing accepted dirty bytes under individual SHA checks; they
remain outside implementation authority. The Store and Supervisor are excluded
because they are in the exact write allowlist, but their separate
strip-to-preimage gates are stronger than unrestricted writable carriers. The
original Revision 1 planning-entry snapshot was:

```text
dirty_total=457
allowlisted_dirty_count=9
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

The Revision 5 entry snapshot, after preserving Review01D, is:

```text
dirty_total=463
allowlisted_present_count=15
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

Revision 6 kept the same outside count and digest because its one compile-only
fixture and Review01F were explicitly allowlisted. Revision 7 transfers the two
already-dirty accepted P1-B successor tests `DurablePlanningTests.swift` and
`FailureVisibilityTests.swift` from the outside aggregate into exact hash-gated
write authority; `BoardServerTests.swift` is clean at Revision 7 entry. With
those exact exclusions, the frozen Revision 7/8 outside result is:

```text
outside_count=446
outside_manifest_v1=0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75
```

`dirty_total` and `allowlisted_present_count` may increase only as named task
artifacts or the clean Board test materialize; they are informational. Revision
8 changes only the already-allowlisted DurablePlanning carrier and adds named
task artifacts, so this outside result is unchanged. The
implementation must reproduce the exact outside count and digest and must
separately reproduce every protected SHA plus every strip-to-preimage proof.
Any outside or protected-byte drift blocks this slice. Only the exact existing
writable carriers named by §§3.1–3.5 may be patched; no checkout, reset, or
reconstruction from HEAD is allowed.

## 4. `v14-p1-control-contracts` migration

Append one migration after `v13-p1-observability` in `AppDatabase.migrator`,
named exactly `v14-p1-control-contracts`. Its SQL is byte-for-semantic-byte the
ten tables, thirteen named indexes, and four append-only triggers in stage spec
§18.4:

- `domain_command_receipt`;
- `domain_event`;
- `event_outbox`;
- `inbox_message`;
- `input_envelope`;
- `goal_controller`;
- `goal_mission_link`;
- `coach_session`;
- `coach_question`;
- `understanding_card_version`;
- all named indexes from §18.4; and
- the standard UPDATE/DELETE abort-trigger pair for both
  `domain_command_receipt` and `domain_event`.

No `IF NOT EXISTS`, no altered FK action, no omitted CHECK, no backfill, no
table copy, and no v15 field/table may be added. GRDB owns the migration
transaction. A failure anywhere leaves the v13 logical schema/data/trigger
snapshot and `grdb_migrations` unchanged.

The v14 contract tests and matrix assert:

- exact ordered columns, declared types/nullability/defaults, foreign keys,
  indexes, partial-index predicates, CHECK fragments, and trigger SQL;
- final real-migrator suffix
  `v12-p1-durable-work`, `v12-p1-schedule-fire`,
  `v13-p1-observability`, `v14-p1-control-contracts`;
- final checkpoints of 41 user tables, 94 indexes, and 8 triggers, with exact
  name sets rather than count-only acceptance;
- migrate twice is a byte-stable logical replay;
- foreign key check is empty and integrity check is `ok`;
- legal insert into each append-only table succeeds at introduction;
- ordinary and no-op UPDATE plus DELETE of each append-only table abort;
- duplicate `(aggregateType,aggregateId,aggregateVersion)`, duplicate event
  key/ordinal, invalid Input body retention, invalid Goal/Coach/Understanding
  shapes, and malformed inbox redaction are rejected; and
- an injected v14 object-name conflict rolls back the entire migration.

The matrix keeps fresh, v7, v8, v9, v10, v11, v12-durable, and v12-schedule,
and adds a real v13 predecessor checkpoint. Both SQLite lanes run all nine
fixtures to v14. The literal lane extracts §18.4 directly, binds its exact line
count/hash in the script, applies it only after the existing literal v12/v13
chain, and exercises the same v14 structure and append-only failures. Existing
v12/v13 diagnostics and sentinels remain unchanged and continue to pass.

## 5. Canonical command and safe JSON contracts

### 5.1 Exact types

`CommandEnvelope.swift` defines:

- `DomainActorType`: `user`, `system`, `coach`, `cow`, `engine`, `device`;
- `CommandEnvelopeV1` with exactly
  `idempotencyKey`, `actorType`, `actorId`, nullable `deviceId`,
  `correlationId`, nullable `causationId`, and `occurredAt`;
- `DomainCommandReplayConflictError`;
- typed validation errors for empty/whitespace/control-character identity,
  invalid user-device shape, and non-finite time.

Every initializer trims only for validation and stores the original value only
when it is already equal to its trimmed form. `idempotencyKey`, `actorId`, and
`correlationId` are nonempty; optional values are either nil or nonempty and
already trimmed. Dates must be finite. A UI user command requires non-nil
device ID. The narrower ordinary legacy-Ingestion deletion shape remains for
P1-E and is not exposed here.

`CanonicalContractCoding.swift` defines one thin façade over the existing
`CanonicalJSONV1`:

- canonical encode/string/hash of typed values;
- whole-command bytes/hash for the exact object
  `{"envelope": envelope, "payload": typedPayload}`;
- exact-key decoding that rejects missing, extra, duplicate/noncanonical, or
  re-encoded-different input; and
- checked lowercase 64-hex, nonnegative Int, finite time, code, enum, and ref
  validation.

It must call `CanonicalJSONV1.encode`, `validateCanonical`, and `sha256Hex`.
It may use `JSONDecoder` only after canonical validation and must verify that
re-encoding equals the input. Its sole decoder is configured with
`keyDecodingStrategy = .useDefaultKeys`,
`dateDecodingStrategy = .millisecondsSince1970`,
`dataDecodingStrategy = .base64`, and
`nonConformingFloatDecodingStrategy = .throw`. Every optional field in a
hash-bearing type has a manual `Codable` implementation: encoding calls
`encode(optionalValue, forKey:)`, so nil is an explicit JSON `null`; decoding
first requires `container.contains(key)` and then calls `decodeIfPresent`.
Missing and explicit-null therefore never collapse. It may not instantiate `JSONEncoder`, use
`JSONSerialization`, duplicate SHA logic, normalize via dictionaries, or
accept unknown keys.

The fixed append-only JSON DTOs are closed rather than caller-extensible:

- `CampSafeRefKindV1` is exactly `input|goal|coachSession|
  currentCoachQuestion|nextCoachQuestion|understanding|durableWork`; every
  associated ID must be a canonical `UUID.uuidString`
  (`UUID(uuidString: id)?.uuidString == id`). Existing arbitrary Camp IDs never
  enter these DTOs; Camp scope remains in the dedicated SQL column.
- `CampSafeHashKindV1` is exactly `commandPayload|inputContent|
  understandingContent|durableWorkInput`.
- `CampSafeVersionKindV1` is exactly `inputProjection|goalProjection|
  coachSessionProjection|understandingContent|durableWork|inputEvent|
  goalEvent|coachSessionEvent|understandingEvent`.
- `CampSafeCountKindV1` is exactly `domainEvent|outbox|candidateCamp|
  coachQuestion|attempt`.
- `CampSafeTimeKindV1` is exactly `capturedAt|occurredAt|deletedAt|
  confirmedAt|notBefore`.
- `CampSafeRefV1`, `CampSafeHashV1`, `CampSafeVersionV1`,
  `CampSafeCountV1`, and `CampSafeTimeV1` take those closed enums, not strings.
- `CampSafeCommandResultV1` is exactly
  `(schemaVersion=1,code:P1ResultCodeV1,refs,hashes,versions,counts,times)`.
- `CampSafeAuditPayloadV1` is exactly
  `(schemaVersion=1,code:P1AuditCodeV1,refs,hashes,versions,counts,times)`.

Callers never choose array order. Each initializer sorts by the enum order
written above, rejects duplicate kinds, and then requires the exact membership
for its sealed command/result branch. The base membership for every command
result is `hashes=[commandPayload]`,
`counts=[domainEvent,outbox]`, and `times=[occurredAt]`; §5.4 adds the only
legal members for each command. `domainEvent` and `outbox` counts both equal
the sealed event count. `commandPayload` is the whole-command hash and
`occurredAt` is the envelope value. Recursive exact-key decoding and
re-encoding preserve these bytes.

`result`, `eventPayload`, event/outbox IDs, `recordedAt`, inbox values,
created/updated projection times, and Camp IDs are deliberately not
representable in these DTOs. This avoids self-hash cycles and post-receipt
factory values. Event IDs are validated from stored rows during graph replay;
outbox identity is exactly its `eventId`, not a second ID. These types have no
generic dictionary escape hatch. The forbidden identity keys
`actorRef`, `actorId`, `actorType`, `deviceId`, `accountId`, and
`accountIdentifier` are therefore neither representable nor accepted as extra
keys. Body, prompt, path, URL, external session, and operation identifiers are
also not representable.

In addition to key rejection, all string values obey their semantic grammar:
closed enum raw values are exact, UUID refs are canonical UUIDs, hashes are
lowercase 64-hex, counts are checked nonnegative integers, versions are
positive post-mutation values, and times are finite. A
ref/hash/version/count/time `kind` cannot be supplied
as an arbitrary string, so an actor, device, account, path, URL, external
session, or operation identifier cannot be smuggled under an otherwise legal
`id` field.

### 5.2 Domain event values

`DomainEvent.swift` defines GRDB records and prepared values for command
receipts, events, outbox, and inbox. `PreparedDomainCommandV1` is exclusively
pre-receipt authority. Its only validating factories take the closed command
type, sealed envelope, exact-key typed payload, and the typed replay plan whose
case fixes the expected event count. The value stores canonical payload bytes
and the whole-command hash; it has no result, result bytes/hash, projection or
work version, generated ID, clock value, or post-mutation initializer.
`NewDomainCommandV1` is exclusively post-mutation authority and can be created
only after the receipt-absent `makeNew` branch produces the typed Camp-safe
result and ordered audit payloads. A result is never an input to a prepared
factory, and neither type can be initialized as the other. This is the single
prepared/new split used by §6 and replay.

`PreparedDomainEventV1` contains stable `campId`, aggregate type/id, expected
aggregate version, event type, payload version 1, and typed Camp-safe payload.
The persisted aggregate version is exactly expected + 1. For multiple events
for one aggregate, adjacent drafts must form a contiguous expected-version
chain. Ordinal is the array index beginning at zero. The event key is exactly:

```text
<command idempotency key>#<zero-padded 4-digit ordinal>:<aggregate type>:<aggregate id>
```

More than 10,000 events, integer overflow, empty IDs/types, malformed hashes,
and caller-supplied recorded time are rejected structurally before receipt
lookup. Existence/unarchived checks are current-state checks and therefore run
only on the receipt-absent branch before mutation. Event UUID and `recordedAt`
come from injected store-owned factories; `recordedAt <
envelope.occurredAt` fails instead of being clamped. The event's single
`recordedAt` value is also the initial outbox `createdAt`/`updatedAt`.

### 5.3 Frozen persisted vocabulary, ID ownership, and work keys

`EventKind.swift` adds exactly five closed package enums conforming, in order,
to `String, Codable, Sendable, Equatable, CaseIterable` for all new persisted
vocabulary. These raw values are the complete P1-C set; no Store accepts a
free-form command, event, aggregate, result, or audit code.

```text
P1AggregateTypeV1
input
goal
coachSession
understanding

P1CommandTypeV1
input.capture.v1
input.parse-result.v1
input.parse-failure.v1
input.requeue-parsing.v1
input.cancel-parsing-and-delete.v1
input.request-camp-assignment.v1
input.record-camp-ambiguity.v1
input.assign-camp.v1
input.archive.v1
input.mark-coaching.v1
input.convert-to-goal.v1
input.request-deletion.v1
input.complete-deletion.v1
coach.open-session.v1
coach.record-question.v1
coach.answer-question.v1
coach.propose-understanding.v1
coach.request-confirmation.v1
coach.confirm-understanding.v1
coach.request-understanding-revision.v1
coach.record-work-failure.v1
goal.abandon.v1
goal.fail.v1

P1EventTypeV1
input.captured.v1
input.parse-committed.v1
input.parse-attempt-failed.v1
input.parsing-requeued.v1
input.deleted.v1
input.camp-assignment-required.v1
input.camp-ambiguity-recorded.v1
input.camp-assigned.v1
input.archived.v1
input.coaching-started.v1
input.goal-created.v1
input.deletion-requested.v1
goal.created.v1
coach.session-opened.v1
coach.question-recorded.v1
coach.question-answered.v1
coach.understanding-proposed.v1
understanding.proposed.v1
coach.confirmation-requested.v1
understanding.confirmation-requested.v1
coach.understanding-confirmed.v1
understanding.confirmed.v1
goal.ready.v1
coach.understanding-revision-requested.v1
understanding.withdrawn.v1
coach.work-attempt-failed.v1
coach.session-failed.v1
coach.session-abandoned.v1
goal.abandoned.v1
goal.failed.v1

P1ResultCodeV1 / P1AuditCodeV1
input_captured
input_parse_committed
input_parse_retry_scheduled
input_parse_failed
input_parsing_requeued
input_deleted
input_camp_assignment_required
input_camp_ambiguous
input_camp_assigned
input_archived
input_coaching
input_goal_created
input_deletion_requested
goal_created
coach_session_opened
coach_question_recorded
coach_question_answered
coach_understanding_proposed
coach_confirmation_requested
coach_understanding_confirmed
coach_revision_requested
understanding_withdrawn
coach_work_retry_scheduled
coach_work_failed
goal_ready
goal_abandoned
goal_failed
```

`P1ResultCodeV1` contains the same raw-value set, but a command factory exposes
only its legal result subset. `P1AuditCodeV1` contains the same set, but each
event factory exposes only its row in the command/event table below. This
prevents code/event mismatches without duplicating strings.

Creation identity is fixed before a new transaction branch:

- `CaptureInputCommandV1` contains caller-owned canonical UUID `inputId`.
- `ConvertInputToGoalCommandV1` contains caller-owned canonical UUID `goalId`.
- `OpenCoachSessionCommandV1` contains caller-owned canonical UUIDs
  `sessionId` and `nextQuestionId`.
- `AnswerCoachQuestionCommandV1` contains caller-owned canonical UUID
  `nextQuestionId` for the next durable turn.
- `RequestUnderstandingRevisionCommandV1` contains caller-owned canonical UUID
  `nextQuestionId` for the reopened durable turn.
- `RecordCoachQuestionCommandV1` obtains `questionId` only from the claimed
  turn's sealed work input; the provider cannot return or replace it.
- P1-C defines `understandingId == goalId`; versions increment from persisted
  rows. A provider cannot choose either value.
- Existing generic DurableWork owns a random work UUID only on a new enqueue.
  The owning domain result records it. Receipt replay never calls enqueue.
- DomainEventStore owns one random event UUID per event only on the new branch.
  The corresponding outbox primary key is exactly that same `eventId`; there
  is no outbox UUID or outbox-ID factory. Replay calls neither the event-ID nor
  clock factory.

Every supplied new P1 aggregate ID is validated as a canonical UUID before SQL.
Existing Camp IDs are validated only as exact nonblank database identities and
are never copied into Camp-safe JSON.

The only derived durable-work idempotency keys are:

```text
inputParsing:v1:<64-lowercase-whole-command-hash>
coach:v1:<64-lowercase-whole-command-hash>
```

Capture and requeue use the first form; open-session, answer-question, and
request-revision use the second. `InputParsingWorkInputV1` is exactly
`(schemaVersion=1,inputId,contentHash)`. `CoachFailureScopeV1` is the closed
enum `clarifyingGoal|readyRevisionSessionOnly`. `CoachTurnWorkInputV1` is
exactly `(schemaVersion=1,goalId,sessionId,nextQuestionId,decisionKey,
turnCommandHash,expectedUnderstandingEventVersion,failureScope,
confirmedUnderstanding)`, where `confirmedUnderstanding` is an explicit-null
`UnderstandingHeadV1?` and:

- `decisionKey` is derived internally as exactly
  `decision:v1:<nextQuestionId>` and is validated against that UUID-derived
  value on encode, decode, claim, and terminal command construction; neither
  caller nor provider can choose or replace it;
- `turnCommandHash` is the whole hash of the command that enqueued the turn;
- `expectedUnderstandingEventVersion` is nonnegative: open-session writes
  zero; answer copies the sealed current Understanding event head;
  `withdrawDraft` and `withdrawAwaitingConfirmation` use a checked `+1` for
  the Understanding event emitted by that command; `reopenConfirmed` carries
  the unchanged positive head; and
- `failureScope` is derived from the transactionally validated Goal: a
  clarifying Goal writes `clarifyingGoal`; a ready Goal with its exact current
  confirmed Understanding head writes `readyRevisionSessionOnly`. Open-session
  admits only the first shape. Answer and subsequent withdraw/revision turns
  preserve the ready-revision scope by re-deriving it from that unchanged
  ready Goal/head, rather than from provider output or chat memory; and
- `confirmedUnderstanding` must be null for `clarifyingGoal`. For
  `readyRevisionSessionOnly` it is nonnull and contains the exact joined current
  Understanding ID, positive content version, lowercase content hash, and
  nonnegative event head. Its ID/version must equal the two fields stored by
  `goal_controller`; its event head must equal the separate
  `expectedUnderstandingEventVersion`. The Goal row deliberately stores no
  hash. The Store derives this sealed value by joining the Goal head to the
  exact `understanding_card_version` row before enqueue; neither caller nor
  provider supplies it.

All work input bytes are canonical and their claimed hash is recomputed.

`CommandEnvelope.swift` also defines the sole typed worker envelope factory:

```swift
package enum ControlWorkerCommandEnvelopeFactoryV1 {
    package static func make(
        work: DurableWorkRecord,
        attempt: DurableWorkAttemptRecord,
        claim: DurableWorkClaim
    ) throws -> CommandEnvelopeV1
}
```

The factory accepts only a persisted running `.inputParsing` or `.coach` work,
its exact open attempt row, and the initial claim for that attempt. It validates
the complete graph before constructing anything: work/attempt/claim IDs and
attempt numbers are equal; work and claim versions, lease owner, and worker ID
match; the attempt is open; attempt/work trace IDs match; work kind,
aggregate type/ID, canonical input bytes/hash, positive attempt/max-attempt,
and finite persisted times are valid. Its envelope is exactly:

```text
idempotencyKey = control-worker:v1:<kind.rawValue>:<work.id>:<attempt.attempt>
inputParsing actorType/actorId/deviceId = system/system:input-parser:v1/null
coach actorType/actorId/deviceId = coach/system:coach:v1/null
correlationId = work.traceId
causationId = work.idempotencyKey
occurredAt = attempt.startedAt
```

One attempt has one envelope identity shared by its success and failure
commands. Therefore a divergent second outcome conflicts against the same
receipt rather than creating two histories. Each processor synchronously
fetches the exact persisted work and attempt and invokes the factory
immediately after a claim (including the first claim after interrupted-work
adoption), before its first provider/parser `await`; it retains that envelope
for the whole attempt. Lease renewal changes only the mutable claim supplied in
the payload and never the attempt envelope. A crash before commit is adopted
and claimed as a new attempt with a new key; replay after a committed terminal
transaction reuses the same attempt key and returns the old graph.

The stable event mapping is:

| Command | Ordered aggregate / event type / audit code |
|---|---|
| capture | Input / `input.captured.v1` / `input_captured` |
| parse result | Input / `input.parse-committed.v1` / `input_parse_committed` |
| parse failure | Input / `input.parse-attempt-failed.v1` / `input_parse_retry_scheduled` or `input_parse_failed` |
| requeue | Input / `input.parsing-requeued.v1` / `input_parsing_requeued` |
| cancel parsing + delete | Input / `input.deleted.v1` / `input_deleted` |
| request assignment | Input / `input.camp-assignment-required.v1` / `input_camp_assignment_required` |
| record ambiguity | Input / `input.camp-ambiguity-recorded.v1` / `input_camp_ambiguous` |
| assign Camp | Input / `input.camp-assigned.v1` / `input_camp_assigned` |
| archive | Input / `input.archived.v1` / `input_archived` |
| mark coaching | Input / `input.coaching-started.v1` / `input_coaching` |
| convert to Goal | Input / `input.goal-created.v1` / `input_goal_created`; Goal / `goal.created.v1` / `goal_created` |
| request deletion | Input / `input.deletion-requested.v1` / `input_deletion_requested` |
| complete deletion | Input / `input.deleted.v1` / `input_deleted` |
| open Coach | CoachSession / `coach.session-opened.v1` / `coach_session_opened` |
| record question | CoachSession / `coach.question-recorded.v1` / `coach_question_recorded` |
| answer question | CoachSession / `coach.question-answered.v1` / `coach_question_answered` |
| propose Understanding | CoachSession / `coach.understanding-proposed.v1` / `coach_understanding_proposed`; Understanding / `understanding.proposed.v1` / `coach_understanding_proposed` |
| request confirmation | CoachSession / `coach.confirmation-requested.v1` / `coach_confirmation_requested`; Understanding / `understanding.confirmation-requested.v1` / `coach_confirmation_requested` |
| confirm | CoachSession / `coach.understanding-confirmed.v1` / `coach_understanding_confirmed`; Understanding / `understanding.confirmed.v1` / `coach_understanding_confirmed`; Goal / `goal.ready.v1` / `goal_ready` |
| request revision, unconfirmed | CoachSession / `coach.understanding-revision-requested.v1` / `coach_revision_requested`; Understanding / `understanding.withdrawn.v1` / `understanding_withdrawn` |
| request revision, confirmed | CoachSession / `coach.understanding-revision-requested.v1` / `coach_revision_requested` |
| Coach transient failure | CoachSession / `coach.work-attempt-failed.v1` / `coach_work_retry_scheduled` |
| Coach terminal failure, clarifying Goal | CoachSession / `coach.session-failed.v1` / `coach_work_failed`; Goal / `goal.failed.v1` / `goal_failed` |
| Coach terminal failure, ready revision | CoachSession / `coach.session-failed.v1` / `coach_work_failed`; Goal unchanged, no Goal event |
| abandon with session | CoachSession / `coach.session-abandoned.v1` / `goal_abandoned`; Goal / `goal.abandoned.v1` / `goal_abandoned` |
| abandon without session | Goal / `goal.abandoned.v1` / `goal_abandoned` |
| explicit fail with session | CoachSession / `coach.session-failed.v1` / `goal_failed`; Goal / `goal.failed.v1` / `goal_failed` |
| explicit fail without session | Goal / `goal.failed.v1` / `goal_failed` |

### 5.4 Exact sealed command payloads and event-version ownership

Every command payload is an exact-key manually coded value. The reusable
heads are exactly:

```text
InputHeadV1(inputId,auditCampId,expectedInputVersion)
GoalHeadV1(goalId,campId,expectedGoalVersion)
CoachHeadV1(sessionId,expectedSessionVersion)
UnderstandingHeadV1(
  understandingId,expectedContentVersion,contentHash,
  expectedUnderstandingEventVersion
)
WorkClaimV1(workId,attempt,workerId,version,leaseExpiresAt)
```

All IDs except existing Camp IDs are canonical UUID strings. Camp IDs are
exact nonblank database identities. Expected projection/content versions are
positive; capture alone has no `InputHeadV1`. Expected Understanding event
version is nonnegative. `understandingId` must equal `goalId`.
`InputHeadV1.expectedInputVersion`, `GoalHeadV1.expectedGoalVersion`, and
`CoachHeadV1.expectedSessionVersion` are also the pre-command domain-event
heads for their aggregates because every P1-C mutation of those projections
emits exactly one corresponding aggregate event. Understanding is the only
projection whose content version and event version diverge, so its event head
is always sealed separately.

The only branch values are exact-key enums with explicit-null inactive fields:

- `ActiveWorkBranchV1.none` or
  `.expected(workId,expectedVersion)`;
- `SessionBranchV1.none` or
  `.expected(sessionId,expectedSessionVersion)`; and
- `UnderstandingRevisionBranchV1.withdrawDraft`,
  `.withdrawAwaitingConfirmation`, or `.reopenConfirmed`.

The exact payload field order below is also the declaration order. Canonical
JSON sorting still determines encoded key order; declaration order is frozen
for API review and synthesized-value construction. No payload has an extra
metadata dictionary.

| Command type | Exact payload fields |
|---|---|
| `input.capture.v1` | `inputId,auditCampId,initialCampId,sourceType,sourceDeviceId,connectorId,authorId,capturedAt,inlineText,payloadRef,contentHash,candidateCampIds,explicitIntent,privacyLevel,parentInputId` |
| `input.parse-result.v1` | `input,claim,result` |
| `input.parse-failure.v1` | `input,claim,failure,terminalDisposition:InputParseFailureTerminalDispositionV1` |
| `input.requeue-parsing.v1` | `input` |
| `input.cancel-parsing-and-delete.v1` | `input,activeParsingBranch` (must be `expected`) |
| `input.request-camp-assignment.v1` | `input,activeParsingBranch,candidateCampIds` |
| `input.record-camp-ambiguity.v1` | `input,activeParsingBranch,candidateCampIds` |
| `input.assign-camp.v1` | `input,activeParsingBranch,targetCampId,targetStatus` |
| `input.archive.v1` | `input,activeParsingBranch` |
| `input.mark-coaching.v1` | `input,activeParsingBranch` |
| `input.convert-to-goal.v1` | `input,activeParsingBranch,goalId,title,rawIntent` |
| `input.request-deletion.v1` | `input,activeParsingBranch` |
| `input.complete-deletion.v1` | `input,activeParsingBranch` |
| `coach.open-session.v1` | `goal,sourceInputId,sessionId,nextQuestionId` |
| `coach.record-question.v1` | `goal,coach,claim,decisionKey,prompt,recommendation,reason` |
| `coach.answer-question.v1` | `goal,coach,currentQuestionId,answer,nextQuestionId,expectedUnderstandingEventVersion` |
| `coach.propose-understanding.v1` | `goal,coach,claim,expectedUnderstandingEventVersion,content` |
| `coach.request-confirmation.v1` | `goal,coach,understanding` |
| `coach.confirm-understanding.v1` | `goal,coach,understanding` |
| `coach.request-understanding-revision.v1` | `goal,coach,understanding,revisionBranch,nextQuestionId` |
| `coach.record-work-failure.v1` | `goal,coach,claim,expectedUnderstandingEventVersion,failure,failureScope,confirmedUnderstanding,failureBranch` |
| `goal.abandon.v1` | `goal,sessionBranch` |
| `goal.fail.v1` | `goal,sessionBranch` |

The Input provider/result boundary is exactly:

```swift
package enum InputParseRouteV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case campAssignmentRequired
    case campAmbiguous
    case coaching
    case archived
}

package struct InputParseResultV1:
    Sendable, Equatable, Codable
{
    package let schemaVersion: Int       // exactly 1
    package let route: InputParseRouteV1
    package let candidateCampIds: [String]
    package let assignedCampId: String?

    package init(
        route: InputParseRouteV1,
        candidateCampIds: [String],
        assignedCampId: String?
    ) throws
}

package enum InputParseFailureTerminalDispositionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case retryScheduled
    case parseFailed

    package static func derive(
        failure: ControlWorkerProviderFailureV1,
        attempt: Int,
        maxAttempts: Int
    ) throws -> Self
}

package typealias InputCaptureReceiptV1 = CampSafeCommandResultV1
```

`InputParseResultV1` uses manual exact-key Codable with keys exactly
`schemaVersion,route,candidateCampIds,assignedCampId`; `assignedCampId` is
always encoded, including explicit null, and unknown/missing/duplicate semantic
members reject. The initializer and decoder enforce:

- all candidate Camp IDs are exact nonblank database identities, sorted,
  unique, and contain no control scalar;
- `campAssignmentRequired` has at least one candidate and null assigned Camp;
- `campAmbiguous` has at least two candidates and null assigned Camp; and
- `coaching|archived` has an empty candidate array and one nonblank assigned
  Camp. The Store then requires that assigned Camp to equal `auditCampId` and
  requires every referenced Camp to exist and be unarchived inside the new
  transaction branch. No route can carry inactive data.

`InputParseFailureTerminalDispositionV1.derive` requires
`maxAttempts == 4` and `attempt` in `1...4`. It returns `retryScheduled` only
for `.transient` at attempts 1, 2, or 3; deterministic failure or attempt 4
returns `parseFailed`. The worker constructs it from the claimed persisted
work; the command factory encodes it, and `InputGoalStore` recomputes the same
value from claim/work/failure before mutation. Caller/provider disagreement is
a typed zero-write contract error. `InputCaptureReceiptV1` is deliberately an
exact typealias, so the Application seam returns the sealed `input_captured`
`CampSafeCommandResultV1` membership from §5.5 without another mapping or
parallel receipt shape.

`DurableWorkFailure`, `CoachWorkFailureBranchV1`, `CoachFailureScopeV1`,
`UnderstandingContentV1`, and `CoachAnswerV1(text)` are likewise exact-key
typed values. `CoachWorkFailureBranchV1` is exactly
`retryScheduledClarifyingGoal|retryScheduledReadyRevision|
terminalClarifyingGoal|terminalReadyGoalPreserved`. The failure command copies
`failureScope` and `confirmedUnderstanding` byte-for-byte from the claimed
canonical Coach work input. The branch is derived only from that scope plus the
validated attempt/max-attempt/disposition: retry + clarifying, retry + ready,
terminal + clarifying, or terminal + ready respectively. Nullable fields above
are encoded as explicit null. Candidate Camp arrays are sorted/unique.
`targetStatus` is exactly `coaching|archived`.

`P1CommandAuthorizationV1.validate(commandType:envelope:)` is the sole
authorization matrix and is called by every prepared-command factory before
SQL. It accepts exactly these 23 rows:

| Commands | Required `actorType` | Required `actorId` | `deviceId` |
|---|---|---|---|
| `input.capture.v1`, `input.requeue-parsing.v1`, `input.cancel-parsing-and-delete.v1`, `input.request-camp-assignment.v1`, `input.record-camp-ambiguity.v1`, `input.assign-camp.v1`, `input.archive.v1`, `input.mark-coaching.v1`, `input.convert-to-goal.v1`, `input.request-deletion.v1`, `input.complete-deletion.v1` | `user` | trimmed, nonempty | nonnull canonical UUID |
| `input.parse-result.v1`, `input.parse-failure.v1` | `system` | exactly `system:input-parser:v1` | null |
| `coach.open-session.v1`, `coach.answer-question.v1`, `coach.confirm-understanding.v1`, `coach.request-understanding-revision.v1`, `goal.abandon.v1` | `user` | trimmed, nonempty | nonnull canonical UUID |
| `coach.record-question.v1`, `coach.propose-understanding.v1`, `coach.request-confirmation.v1`, `coach.record-work-failure.v1`, `goal.fail.v1` | `coach` | exactly `system:coach:v1` | null |

No prefix, wildcard, alternate system actor, null user device, nonnull worker
device, whitespace-only actor ID, or command outside its row is legal. A typed
`P1CommandAuthorizationError` is thrown before receipt lookup, projection read,
ID/clock factory, or any SQL write. Input data remains an Input and never gains
command authority from source device, author, connector, or Camp fields.

Every ordinary Input transition in the table above carries
`activeParsingBranch = .none`; `cancelParsingAndDelete` alone requires
`.expected(workId,expectedVersion)`. `completeDeletion` also requires `.none`.
Supplying `.none` to cancel or `.expected` to any ordinary/complete-deletion
command is a typed pre-SQL validation error. On the receipt-absent branch the
Store checks the sealed branch transactionally before projection mutation;
receipt replay uses only the stored result/event/outbox graph.

All projection, question, confirmation, deletion, enqueue, and nonterminal
generic DurableWork logical `now` values in one command are exactly
`envelope.occurredAt`. `capturedAt` remains the sealed capture payload value.
Worker terminal commands are the sole exception: their attempt envelope keeps
the stable `occurredAt = attempt.startedAt`, while the processor reads a
separate injected finite `terminalNow` exactly once after provider and renewal
children have fully terminated and immediately before the terminal Store call.
On the receipt-absent branch, success/failure/retry uses that one value for
`durable_work.updatedAt`/`finishedAt`, attempt `endedAt`, the terminal attempt
event, and retry `notBefore = terminalNow + [5,30,120][attempt-1]` with checked
finite arithmetic. Before any mutation it must be finite and greater than or
equal to both persisted `work.updatedAt` and `attempt.startedAt`; otherwise a
typed timestamp error makes zero writes. It is never clamped.

The terminal clock is processor-owned, not a prepared-command field. Receipt
replay returns the persisted result/graph without invoking it or any terminal
mutation, so the attempt command identity remains stable while backoff starts
at actual failure/terminalization time. The injected DomainEventStore clock is
used only for `domain_event.recordedAt` and matching initial outbox timestamps,
after the receipt-absent transaction branch has succeeded through its
projection/work mutation. Thus replay never fabricates or refreshes a logical
timestamp.

The pure typed replay-plan factories for all rows above are package-visible
static methods owned by `InputGoalStore` or `CoachUnderstandingStore`; their
initializers are not exposed and no caller supplies a closure. They consume
only the sealed envelope/payload and branch enum, so they are constructible
before receipt lookup. Batch C2 may create these two files with only these
pure factories; their database mutation APIs remain C3/C4 work.

### 5.5 Exact result and audit-array shapes

`CampSafeCommandResultV1` membership is fixed by this table. Shorthand follows
the enum order and expands as:

```text
refs: I=input, G=goal, S=coachSession, Q=currentCoachQuestion,
      N=nextCoachQuestion, U=understanding, W=durableWork
hashes beyond base: IC=inputContent, UC=understandingContent,
                    WI=durableWorkInput
versions: IP=inputProjection, GP=goalProjection,
          SP=coachSessionProjection, UCv=understandingContent,
          WV=durableWork, IE=inputEvent, GE=goalEvent,
          SE=coachSessionEvent, UE=understandingEvent
counts beyond base: CC=candidateCamp, QC=coachQuestion, AT=attempt
times beyond base: CA=capturedAt, DA=deletedAt,
                   FA=confirmedAt, NB=notBefore
```

Every row additionally has base `hashes=[commandPayload]`,
`counts=[domainEvent,outbox]`, and `times=[occurredAt]`. Array order is always
the enum order in §5.1, never the shorthand order. Ref values come from the
sealed payload except a new `W`, which comes from the single new enqueue.
Hashes are recomputed canonical hashes. Projection/content/work versions are
the exact post-transaction values; event versions are the exact emitted post
versions (or the unchanged positive current `UE` in the confirmed-revision
row). `CC` is the post-projection candidate count, `QC` the number of open
questions after the command, `AT` the resulting work attempt, and time values
are exact persisted values. No other member is legal.

| Command/result branch | Result code | Refs | Extra hashes | Versions | Extra counts | Extra times |
|---|---|---|---|---|---|---|
| capture | `input_captured` | I,W | IC,WI | IP,WV,IE | CC,AT | CA |
| parse result | `input_parse_committed` | I,W | IC,WI | IP,WV,IE | CC,AT | CA |
| parse failure retry | `input_parse_retry_scheduled` | I,W | IC,WI | IP,WV,IE | CC,AT | CA,NB |
| parse failure terminal | `input_parse_failed` | I,W | IC,WI | IP,WV,IE | CC,AT | CA |
| requeue parsing | `input_parsing_requeued` | I,W | IC,WI | IP,WV,IE | CC,AT | CA |
| cancel parsing + delete | `input_deleted` | I,W | IC,WI | IP,WV,IE | CC,AT | CA,DA |
| request assignment | `input_camp_assignment_required` | I | IC | IP,IE | CC | CA |
| record ambiguity | `input_camp_ambiguous` | I | IC | IP,IE | CC | CA |
| assign Camp | `input_camp_assigned` | I | IC | IP,IE | CC | CA |
| archive | `input_archived` | I | IC | IP,IE | CC | CA |
| mark coaching | `input_coaching` | I | IC | IP,IE | CC | CA |
| convert to Goal | `goal_created` | I,G | IC | IP,GP,IE,GE | CC | CA |
| request deletion | `input_deletion_requested` | I | IC | IP,IE | CC | CA |
| complete deletion / no active work | `input_deleted` | I | IC | IP,IE | CC | CA,DA |
| open Coach | `coach_session_opened` | G,S,N,W | WI | GP,SP,WV,SE | QC,AT | — |
| record question | `coach_question_recorded` | G,S,Q,W | WI | GP,SP,WV,SE | QC,AT | — |
| answer question | `coach_question_answered` | G,S,Q,N,W | WI | GP,SP,WV,SE | QC,AT | — |
| propose Understanding | `coach_understanding_proposed` | G,S,U,W | UC,WI | GP,SP,UCv,WV,SE,UE | QC,AT | — |
| request confirmation | `coach_confirmation_requested` | G,S,U | UC | GP,SP,UCv,SE,UE | QC | — |
| confirm Understanding | `goal_ready` | G,S,U | UC | GP,SP,UCv,GE,SE,UE | QC | FA |
| revision / withdraw draft or awaiting | `coach_revision_requested` | G,S,N,U,W | UC,WI | GP,SP,UCv,WV,SE,UE | QC,AT | — |
| revision / reopen confirmed | `coach_revision_requested` | G,S,N,U,W | UC,WI | GP,SP,UCv,WV,SE,UE | QC,AT | — |
| Coach failure retry / clarifying Goal | `coach_work_retry_scheduled` | G,S,W | WI | GP,SP,WV,SE | QC,AT | NB |
| Coach failure retry / ready revision | `coach_work_retry_scheduled` | G,S,U,W | UC,WI | GP,SP,UCv,WV,SE,UE | QC,AT | NB |
| Coach failure terminal / clarifying Goal | `coach_work_failed` | G,S,W | WI | GP,SP,WV,GE,SE | QC,AT | — |
| Coach failure terminal / ready revision | `coach_work_failed` | G,S,U,W | UC,WI | GP,SP,UCv,WV,SE,UE | QC,AT | — |
| abandon / no session | `goal_abandoned` | G | — | GP,GE | — | — |
| abandon / expected session | `goal_abandoned` | G,S | — | GP,SP,GE,SE | QC | — |
| explicit fail / no session | `goal_failed` | G | — | GP,GE | — | — |
| explicit fail / expected session | `goal_failed` | G,S | — | GP,SP,GE,SE | QC | — |

For every event, `CampSafeAuditPayloadV1` copies the command result's refs,
hashes, versions, counts, and times byte-for-byte and replaces only `code`
with the exact audit code in §5.3. This rule plus the ordered event table is
the entire payload builder; no event-specific caller array exists. The builder
also verifies that each result version equals the sealed expected value plus
the exact mutation/event delta and that every count/time matches the new rows.
This makes receipt replay able to reconstruct every historical payload from
the sealed command plus decoded result without consulting current projections.

## 6. DomainEventStore transaction and delivery semantics

`DomainEventStore` is `Sendable`, initialized with `AppDatabase`, an injected
finite clock, and one injected event-ID factory. Production defaults use
`Date()` and `UUID().uuidString`; tests inject deterministic values. There is
no outbox-ID factory.

Its transaction-only core is exactly:

```swift
executeCommand(
    command: PreparedDomainCommandV1,
    replayPlan: DomainCommandReplayPlanV1,
    database: Database,
    makeNew: (Database) throws -> NewDomainCommandV1
) throws -> CampSafeCommandResultV1
```

The closure is synchronous and may not escape. The public/package owning
stores open `pool.write`; no public convenience opens a nested transaction.
`PreparedDomainCommandV1` contains only the sealed command type/envelope,
typed payload bytes/whole hash, and the event count fixed by `replayPlan`; it
does not allocate result, aggregate, event, outbox, or work IDs.
`DomainCommandReplayPlanV1` contains a closed command-specific case plus the
exact ordered
`(campId,aggregateType,aggregateId,aggregateVersion,eventType,auditCode)`
shapes derivable from §5.4 and a nonescaping internal builder that implements
only §5.5. Callers cannot supply an arbitrary builder: only the pure typed
factories in `InputGoalStore` and `CoachUnderstandingStore` can construct a
plan. Understanding shapes use the payload's sealed
`expectedUnderstandingEventVersion`; they never read the current event head to
construct replay authority.
`NewDomainCommandV1` contains the typed result and ordered audit payloads after
the projection/work mutation; it contains no closure.

Execution order is:

1. validate the envelope, whole hash, closed replay-plan case, sealed Camp
   identity strings, IDs, versions, ordinals, event keys, and expected count
   structurally without SQL or allocating an ID/time;
2. `SELECT` the receipt by idempotency key before inspecting a mutable
   projection branch or calling `makeNew`;
3. if it exists, require exact command type/hash/event count, validate and
   decode canonical stored result/hash, rebuild expected payloads, and validate
   the complete stored graph: exact event row count/order/key/shape/version/
   envelope columns/payload bytes/hash, canonical UUID event IDs, and exactly
   one structurally valid outbox row for every event with no missing/extra
   command event. The stored event Camp must equal the sealed command Camp and
   still satisfy its FK, but current `camp.archived` is deliberately not read;
   then return the old result without calling `makeNew`, any ID factory, clock,
   work enqueue, Camp-state check, or projection read;
4. if absent, require every event/audit Camp to exist and be unarchived,
   preflight every aggregate's current domain-event version from the replay
   plan, and only then call `makeNew` once;
5. `makeNew` performs the projection/CAS/durable-work mutation and returns its
   result/payloads; validate them exactly against the same replay plan and
   result-derived expected bytes;
6. insert the immutable receipt using that result, then allocate/insert ordered
   events with all envelope identity/time fields copied exactly;
7. insert exactly one initial pending outbox row whose primary key/identity is
   the already allocated event ID; and
8. verify actual receipt/event/outbox graph and canonical hashes before commit.

Any mismatch rolls back receipt, projections, work ledger, event, and outbox.
Same idempotency key with different command type, whole hash, or event count
throws `DomainCommandReplayConflictError`. Aggregate CAS throws a typed
version conflict. `events(aggregateType:id:)` returns ascending aggregate
version and validates canonical payload/hash on read.

The event-ID factory and clock are invoked exactly once per event in step 6;
step 7 reuses those values and invokes no factory.
A replay after the Input/Goal/Session projection has advanced therefore still
returns the original result and graph. State-dependent commands never infer
their old branch: `AbandonGoalCommandV1` and `FailGoalCommandV1` contain a
sealed `sessionBranch` of exactly `none` or
`expected(sessionId,expectedSessionVersion)`, encoded with explicit nulls.
That selector fixes one versus two events. On the new path it must exactly
match persisted state; on replay only the receipt/graph is authoritative.
`RecordCoachWorkFailureCommandV1` likewise seals exactly one
`CoachWorkFailureBranchV1`: `retryScheduledClarifyingGoal`,
`retryScheduledReadyRevision`, `terminalClarifyingGoal`, or
`terminalReadyGoalPreserved`. On the new path the Store checks it against the
claim, attempt/max-attempts, failure disposition, sealed work-input
`failureScope`, and exact Goal status/current joined confirmed Understanding.
For a ready branch, the Goal's stored ID/version must join to exactly one
confirmed row whose content hash and event head equal the sealed optional
`UnderstandingHeadV1`; the Goal itself has no hash column. The ready retry and
terminal results repeat that U/UC/UCv/UE authority, while the clarifying
branches require the optional head to be null and omit those members. On replay
only the stored result and one-versus-two-event graph are authoritative.

Outbox local methods use versioned claims:

- `claimOutbox(workerId:now:leaseDuration:limit:)` claims pending/due rows in
  created/event order, increments attempt/version, and sets dispatching lease;
- `releaseOutbox(claim:failure:notBefore:now:)` returns transient attempts to
  pending or marks deterministic/fourth attempts failed, clearing lease;
- `markOutboxSent(claim:now:)` CASes dispatching to sent; exact repeat returns
  the existing sent row, while a different/stale owner fails.

No cloud send occurs.

`applyInbox(envelope:handler:)` validates canonical incoming bytes and
recomputes their SHA-256 before opening one `pool.write`. A new message is
inserted as received in the outer transaction. The synchronous, mutation-capable
handler then runs inside `db.inSavepoint`. Success returns `.commit` from the
savepoint and the outer transaction stores `applied` plus `appliedAt`. A typed
`DomainInboxHandlerRejection` is caught only inside the outer closure: its exact
code is retained in a local value, the savepoint returns `.rollback`, and only
after that rollback has completed does the outer transaction update the inbox
row to `rejected` with that stable code. Thus every handler write is absent
while the received/rejected evidence commits. Any other handler, savepoint, or
database error rolls back the savepoint and is rethrown so the outer transaction
also rolls back, including the received row; it never becomes a fake rejection.
No handler is allowed to catch or suppress its own database failure as a typed
rejection.

An existing row with non-null `redactedAt` is classified before ordinary
replay/conflict comparison. It must have the exact authoritative v16-compatible
tombstone shape: nonblank ID/idempotency key, non-null nonblank Camp,
`sourceDeviceId='[deleted]'`, canonical `payloadJson='{}'`, a retained
lowercase 64-hex `payloadHash`, `state='rejected'`,
`errorCode='camp_deleted'`, positive version, finite `receivedAt` and
`redactedAt`, and nil-or-finite `appliedAt`. The redaction classifier does not
rehash `{}` because authoritative v16 preserves `OLD.payloadHash`; it likewise
accepts the preserved `OLD.appliedAt` as either nil or finite rather than
forcing null. All remaining retained fields are validated, but erased source
identity/payload is never guessed. A valid tombstone causes
`DomainInboxRedactedError` with zero mutation and no handler call for every
incoming replay. A malformed tombstone causes `DomainInboxIntegrityError`,
also with zero mutation. Tests construct valid tombstones from previously
received, applied, and rejected origins and prove the old hash/applied time is
preserved.

For a non-redacted row, replay requires exact equality of idempotency key,
nullable Camp identity, source-device identity, canonical payload bytes, and
recomputed/stored hash. The existing bytes are canonicalized and rehashed
before any equality verdict; stored-hash corruption throws
`DomainInboxIntegrityError` with zero mutation and no handler call. Thus
manually forged same-key/same-stored-hash/different-bytes data is never
accepted as replay.

For a well-formed existing row with a different identity or payload, the same
write transaction performs exactly one CAS:

```sql
UPDATE inbox_message
SET state = 'rejected',
    appliedAt = NULL,
    errorCode = 'inbox_payload_conflict',
    version = version + 1
WHERE id = ? AND version = ? AND redactedAt IS NULL;
```

The checked increment must not overflow. `id`, `campId`, `sourceDeviceId`,
`idempotencyKey`, original `payloadJson/payloadHash`, and `receivedAt` remain
byte/value exact; this branch requires `redactedAt` to remain null. A
non-redacted row already in this exact conflict
shape is not incremented again. The write closure returns an internal conflict
sentinel; only after `pool.write` commits does the public method throw
`DomainInboxReplayConflictError`. No handler mutation runs on either first or
repeated conflict. A CAS miss, noncanonical row, bad stored hash, redacted row,
or invalid state shape throws its specific typed error and never masquerades
as a conflict commit.

## 7. InputEnvelope, InputGoalStore, and parsing

### 7.1 Projection types and immutable audit scope

`InputEnvelope.swift` defines all §9.1 enums/fields as GRDB records plus typed
commands/results. It also defines `LegacyIngestionAdapter`, which maps an
existing `IngestionItemRecord` to a display-only projection. It has no database
write API and never manufactures an Input ID, idempotency key, or Goal.

An unassigned Input still needs a truthful non-null event Camp. Therefore
`captureAndEnqueueParsing` requires an explicit existing unarchived
`auditCampId` representing the capture context, separately from nullable
`initialCampId`. The complete P1-C Camp rule is intentionally fail-closed:

1. `auditCampId` is the single authorized Camp for the Input aggregate. It
   must exist and be unarchived on the receipt-absent branch of capture and
   every later ordinary command. Exact receipt replay remains valid after a
   later archive and never creates a new write.
2. `initialCampId` is either nil or exactly equal to `auditCampId`; any other
   value rejects before receipt/work/projection mutation. A nonnil equal value
   is copied to `input_envelope.campId`; nil remains nil.
3. The version-1 `input.captured.v1` event has `campId = auditCampId` and is the
   immutable audit-scope source. On a receipt-absent branch,
   `requireInputAuditCamp` reads that one event and rejects absence, duplicates,
   wrong type/version, sealed-command mismatch, or archived Camp. Receipt
   replay validates the stored command graph directly and does not call it.
4. The `.inputParsing` work row always has `campId = auditCampId`, including
   requeue. It never uses a candidate or inferred default.
5. Assignment/ambiguity events while the projection Camp is nil still use
   `auditCampId`. `assignCamp` may assign only `targetCampId == auditCampId`;
   another candidate Camp is a typed cross-Camp error with zero writes.
6. After assignment, projection Camp and every later Input event remain exactly
   `auditCampId`. A capture context/assigned Camp mismatch never creates an
   implicit bridge or splits work/events across Camps.
7. Every later Input command seals the same `auditCampId` inside
   `InputHeadV1`; a different value conflicts before projection access.
   Candidate Camp IDs may describe ambiguity and are validated as existing,
   sorted, and unique, but they confer no authority. Cross-Camp reassignment or
   a global inbox requires a later reviewed bridge contract and is not P1-C.

This does not infer a Camp: the caller must explicitly supply the only capture
context that P1-C can authorize. A caller with no stable capture context is
rejected. Archive between capture and any later mutation also rejects; no
event or work is written under an archived Camp.

### 7.2 Input commands and event counts

`InputGoalStore` owns these methods and exact event counts:

| Command | Legal transition/effect | Events |
|---|---|---:|
| `captureAndEnqueueParsing` | create `captured` Input + one `.inputParsing` work atomically | 1 Input |
| `commitParseResult` | claimed work succeeds + Input routes from `captured` | 1 Input |
| `recordParseFailure` | transient retry leaves Input `captured`; terminal/exhausted sets `parseFailed` | 1 Input |
| `requeueParsing` | `parseFailed -> captured` + new work/key | 1 Input |
| `cancelParsingAndDelete` | exact expected active parse canceled + exact tombstone | 1 Input |
| `requestCampAssignment` | no active parse; `captured -> campAssignmentRequired` | 1 Input |
| `recordCampAmbiguity` | no active parse; `captured -> campAmbiguous` | 1 Input |
| `assignCamp` | no active parse; assignment/ambiguous -> `coaching` or `archived`, with explicit Camp | 1 Input |
| `archive` | no active parse; captured/assignment/ambiguous/coaching -> archived | 1 Input |
| `markCoaching` | no active parse; captured/assignment/ambiguous -> coaching | 1 Input |
| `convertToGoal` | no active parse; resolved captured/assignment/ambiguous/coaching -> goalCreated + new clarifying Goal | 2: Input then Goal |
| `requestDeletion` | no active parse; active -> deletionRequested, status unchanged | 1 Input |
| `completeDeletion` | deletionRequested + no active parse -> exact tombstone | 1 Input |

Every command takes a `CommandEnvelopeV1` and expected projection aggregate
version. Event ordering above is frozen. Exact replay returns the prior result
before CAS. A changed envelope field, payload body/hash, expected version, or
event count conflicts.

For `requestCampAssignment`, `recordCampAmbiguity`, `assignCamp`, `archive`,
`markCoaching`, `convertToGoal`, `requestDeletion`, and `completeDeletion`, the
sealed `.none` branch requires transactionally zero queued, running, or
retryScheduled `.inputParsing` rows whose aggregate is this Input. Any such row
causes a typed zero-write conflict before Input/Goal/event/outbox mutation.
Terminal succeeded/failed/canceled historical work is not active and does not
block. `cancelParsingAndDelete` is the only command that may coexist with
active parsing; its `.expected` branch must name the exact active work ID and
version, and cancellation plus tombstone is one transaction. No command may
turn an Input away from `captured` while leaving claimable/recoverable parsing
work behind.

Capture validates the §9.1 body XOR, 64-hex content hash, sorted/unique
candidate Camp IDs, explicit intent, privacy, parent FK, optional source
identity, and the exact §7.1 Camp contract without choosing a default. It inserts canonical
`InputParsingWorkInputV1(inputId,contentHash,schemaVersion=1)` with max attempts
4, aggregate type `input`, and a derived work idempotency key inside the same
transaction. The Input remains `captured`; there is no `parsing` enum or
column.

`InputParseResultV1` may route only to `campAssignmentRequired`,
`campAmbiguous`, `coaching`, or `archived`. Assignment/ambiguity requires nil
projection Camp and nonempty candidate IDs; coaching/archive requires one
explicit valid Camp equal to the immutable `auditCampId`. A parser-proposed
different Camp is a deterministic parse failure, never an assignment. A parse
result can never directly write `goalCreated`.
`startNow` and `createGoal` route to coaching and later use `convertToGoal`.

Success, retry/failure, and cancel call existing transaction-local generic
DurableWork mutations inside `DomainEventStore.executeCommand`, so the work
terminal/retry state, attempt event, Input projection, receipt, domain event,
and outbox share one transaction. A stale claim or Input CAS changes nothing.

Deletion applies the exact §9.2 tombstone: retain only
`id/schemaVersion/aggregateVersion/idempotencyKey/sourceType/capturedAt/
contentHash/campId/createdAt`; clear all source device/connector/author/body/
payload/error/parent fields; force candidates `[]`, unspecified intent,
local-only privacy, status/retention tombstone, and equal non-null updated/
deleted time. Store code and DDL both enforce it.

### 7.3 InputParsingWorker

`InputParsingWorker` is a `Sendable` awaited processor, not an unowned
background Task. Its dependencies and provider boundary are exactly:

```swift
package typealias ControlWorkerSleepV1 =
    @Sendable (TimeInterval) async throws -> Void

package enum ControlWorkerLeasePolicyV1 {
    package static let leaseDuration: TimeInterval = 60
    package static let renewalInterval: TimeInterval = 15
}

package struct ControlWorkerProviderFailureV1: Sendable, Equatable {
    package let code: String
    package let safeMessage: String?
    package let disposition: DurableWorkFailureDisposition

    package init(
        code: String,
        safeMessage: String?,
        disposition: DurableWorkFailureDisposition
    ) throws
}

package struct InputParsingProviderRequestV1: Sendable, Equatable {
    package let schemaVersion: Int // exactly 1
    package let workId: String
    package let attempt: Int
    package let inputId: String
    package let auditCampId: String
    package let assignedCampId: String?
    package let sourceType: InputSourceTypeV1
    package let capturedAt: Date
    package let inlineText: String?
    package let payloadRef: String?
    package let contentHash: String
    package let candidateCampIds: [String]
    package let explicitIntent: InputExplicitIntentV1
    package let privacyLevel: InputPrivacyLevelV1
    package let parentInputId: String?
}

package enum InputParsingProviderOutcomeV1: Sendable, Equatable {
    case parsed(InputParseResultV1)
    case failed(ControlWorkerProviderFailureV1)
    case canceled
}

package typealias InputParserV1 =
    @Sendable (InputParsingProviderRequestV1) async
        -> InputParsingProviderOutcomeV1

package struct InputParsingWorker: Sendable {
    package init(
        database: AppDatabase,
        workerId: String,
        clock: @escaping @Sendable () -> Date,
        sleep: @escaping ControlWorkerSleepV1,
        parser: @escaping InputParserV1
    ) throws

    package func recoverInterrupted() throws -> [DurableWorkRecord]
    package func runNext() async throws -> Bool
}
```

`ControlWorkerProviderFailureV1` uses the exact nonempty error-code grammar,
optional nonempty/control-free at-most-1,000-scalar safe message, and closed
`transient|deterministic` disposition accepted by `DurableWorkFailure`; its
mapping is exactly `DurableWorkFailure(code:message:same disposition:
usageJson:nil)`. It has no raw error, prompt, stack, usage, account, external
operation/session, or arbitrary metadata field. `.canceled`, task cancellation,
or a cancellation observed after provider return propagates `CancellationError`
and performs no success/failure terminal command. The provider type does not
throw.

`ControlWorkerLeasePolicyV1` is the only control-worker lease policy. Both
processors pass its exact 60-second duration to initial `claimNext` and every
`renewLease`, and sleep its exact 15-second interval between renewals. The
initializer does not accept an alternate lease or cadence. Both constants are
positive and finite, claim and renew use the same duration, and the duration is
exactly four renewal intervals. Tests assert initial expiry `claimNow + 60`,
renewed expiry `renewNow + 60`, no adoption immediately before expiry, and
adoption at exact expiry for both control kinds.

After either provider returns, the worker revalidates the complete typed result
before constructing a domain command. Any empty/invalid question member,
invalid Understanding content, noncanonical `InputParseResultV1`, inactive
field, bad Camp identity/order, or other provider-output contract violation is
not thrown back into lease recovery. The worker constructs exactly one local
deterministic `ControlWorkerProviderFailureV1` with `safeMessage = nil` and:

- Input code `input_parser_invalid_output`; or
- Coach code `coach_provider_invalid_output`.

It then follows the same latest-claim, post-renewal, one-`terminalNow` failure
transaction as an explicit provider `.failed` outcome. Input derives
`terminalDisposition = .parseFailed`; Coach derives the appropriate
`terminalClarifyingGoal|terminalReadyGoalPreserved` branch from the sealed
work scope. The attempt closes once with a failed terminal event, the relevant
projection/event/outbox graph commits atomically, and replay of that terminal
command never calls the provider again. Only cancellation, renewal failure,
parent cancellation, or a pre-provider persisted-integrity/Store failure leaves
the running ledger for expired-lease recovery; provider-output validation is
never in that class.

Immediately after `claimNext` and before the first parser or renewal `await`,
one synchronous `database.pool.read` loads and validates the exact running work,
open attempt, canonical `InputParsingWorkInputV1`, and referenced non-tombstone
Input row. That one read constructs the request above: work ID/attempt come from
the claim, `inputId`/content hash must equal the sealed work input, audit Camp
must equal the work Camp, and every other field is copied from that persisted
Input snapshot. Candidate IDs are already canonical sorted/unique and body XOR
is revalidated. The worker builds the §5.3 envelope from the same work/attempt/
claim graph. Neither closure captures a database row, Store, chat memory, live
projection lookup, current UI state, path expansion, or mutable post-await
snapshot.

The dedicated Store entry point is exactly:

```swift
package func adoptExpiredControlWork(
    kind: DurableWorkKind,
    currentWorkerId: String,
    now: Date
) throws -> [DurableWorkRecord]
```

It exists only in a final block of `DurableWorkStore.swift` between these exact
markers, with the end marker plus newline as the final bytes:

```text
// P1-C-BEGIN ExpiredControlWorkAdoption
// P1-C-END ExpiredControlWorkAdoption
```

The method accepts only `.inputParsing` or `.coach`, a trimmed nonempty worker
ID, and finite `now`; opens one `pool.write`; and selects only running rows of
that exact kind with nonnull finite `leaseExpiresAt <= now`. It deliberately
does not filter by lease owner, so the same worker can recover its own expired
claim and a replacement worker can recover an expired foreign claim. A foreign
or same-owner live lease (`leaseExpiresAt > now`) is unchanged. Each selected
row is CASed on ID/state/version/lease expiry, closes the old attempt as
`interrupted`, appends the existing exact interrupted attempt event, and returns
the queued post-row with the same `worker_interrupted` semantics as generic
adoption. Any malformed selected row or CAS failure rolls back all adoptions.
The existing generic `adoptInterrupted`, its supported kinds, and every byte
before the marker remain unchanged. `InputParsingWorker.recoverInterrupted()`
calls this method only for `.inputParsing`; `CoachTurnProcessor` calls it only
for `.coach`.

`runNext()` claims at most one `.inputParsing` item using the exact 60-second
policy and returns false if none; while parsing it renews every 15 seconds
through the structured lease protocol
below. Success/failure calls the atomic Store methods in §7.2, and every child
task is awaited/canceled before `runNext` returns. Tests use a file database,
advance the clock to expiry, reopen, recover both same-owner and foreign-owner
expired claims, and complete them; they also prove a foreign live lease is
bit-for-bit unchanged. No watchdog changes the projection to success.

`InputParsingWorker.swift` also defines internal actor
`LatestControlWorkClaim`, shared with `CoachTurnProcessor`. It has exactly three
operations:

```swift
func current() throws -> DurableWorkClaim
func replace(expected: DurableWorkClaim, renewed: DurableWorkClaim) throws
func closeAndTakeLatest() throws -> DurableWorkClaim
```

It starts with the claim returned by `claimNext`. `replace` succeeds only while
open and only when `expected` equals the current claim; a stale/out-of-order
renewal throws. `closeAndTakeLatest` atomically marks the cell closed and
returns the last claim; all later reads/replacements throw. The actor is the
only mutable owner of claim version/lease state.

`runNext` uses `withThrowingTaskGroup` with one parser child and one renewal
child. Renewal reads `current`, calls the existing generic `renewLease`, then
CAS-replaces the cell. When the parser returns or throws, the parent cancels
renewal, awaits both children to termination, and only then calls
`closeAndTakeLatest`; the returned latest claim is the sole claim passed to a
terminal Store method. It then reads the one §5.4 `terminalNow` and passes it
with that latest claim. A renewal error cancels/awaits the parser and propagates
without a projection/domain terminal write. Parent cancellation cancels and
awaits both children, does not call success/failure, and leaves the running
ledger recoverable after lease expiry. There is no detached task, unchecked
shared variable, continuation, timeout-success, or pre-renewal terminal claim.
Before either child starts, `runNext` synchronously loads the just-claimed work
and open attempt, builds the exact §5.3 worker envelope, and retains it while
`LatestControlWorkClaim` alone advances lease/version state. Parse success and
typed failure submit that same envelope. The adoption, bounded-retry, renewal,
and committed-replay tests assert the exact request snapshot, attempt key,
actor/device, correlation/causation, persisted `startedAt`, monotonic
terminal time, and backoff-from-failure behavior.

## 8. Goal, Coach, and Understanding ownership

### 8.1 Goal creation and P1-C state fence

`GoalController.swift` defines `GoalControllerRecord`, statuses matching v14,
and pure validation/construction. Only `clarifying`, `ready`, `abandoned`, and
`failed` are writable by P1-C APIs. `active`, `paused`, and `achieved` are
decodable schema values for forward compatibility only. No activate/pause/
resume/achieve function exists.

`InputGoalStore.convertToGoal` is the database command that invokes the pure
`createFromInput` rule. It requires a non-tombstoned Input with one explicit
Camp. `campAssignmentRequired`, `campAmbiguous`, or nil Camp blocks creation;
the store never selects a candidate. It atomically CASes the Input to
`goalCreated`, inserts a clarifying Goal with nil Understanding/Outcome refs,
and appends Input then Goal events/outboxes.

### 8.2 Coach durable turn ownership

`CoachContracts.swift` defines CoachSession/Question records, fixed actor
`system:coach:v1`, states, work input, snapshots, and command DTOs.
P1-C permits exactly one `coach_session` row in total for a Goal across all
session statuses. This is a Store invariant, not a schema uniqueness claim:

- `openCoachSession` performs exact receipt replay first. Only the absent branch
  enters its serialized `pool.write` new path, where it requires the Goal's
  total session-row count to be zero before inserting the caller-owned session;
  any existing interviewing, waiting, ready-for-confirmation, confirmed,
  canceled, or failed row throws `CoachSessionAlreadyExistsError` with zero new
  writes;
- concurrent different opens serialize on the database writer; exactly one may
  insert. Exact replay of the winning command returns its old result before the
  zero-row check;
- answer/revision/reopen always reuse that same session ID and never insert a
  second session;
- every `SessionBranchV1.none` new path requires zero session rows for the Goal.
  Every `.expected` path requires exactly one total row and that row's ID/version
  to match the sealed branch. More than one row is always
  `CoachSessionIntegrityError`, never a “latest” selection; and
- `resumeSession(goalId:)` fetches the complete session set, returns only when
  there is exactly one row, throws `CoachSessionNotFoundError` for zero and
  `CoachSessionIntegrityError` for more than one, then validates its pointer
  against the at-most-one open question.

`CoachUnderstandingStore` owns:

- `openCoachSession`: creates an interviewing session and atomically enqueues
  one `.coach` work (`aggregateType=coachSession`, max attempts 4);
- `recordQuestion(claim:...)`: coach actor only; terminalizes the claimed coach
  work, requires the command `decisionKey` to equal both the sealed work input
  value and `decision:v1:<nextQuestionId>`, creates one open question, and sets
  waiting/pending pointer;
- `answerQuestion`: user actor only; answers the exact pending question, clears
  the pointer, returns to interviewing, and enqueues a new coach work whose
  failure scope is derived from the exact validated Goal/head shape in §5.3;
- `proposeUnderstanding(claim:...)`: coach actor only; terminalizes the claimed
  coach work, creates a new draft content version, and updates session head;
- `recordCoachWorkFailure(claim:failure:failureBranch:...)`: coach/system only;
  calls existing transaction-local `retryOrFail`. A transient/future-attempt
  failure requires `retryScheduledClarifyingGoal` or
  `retryScheduledReadyRevision` matching the sealed work scope, keeps the
  session `interviewing`, increments its aggregate version, writes one
  attempt-failed event, and schedules bounded retry. The ready retry additionally
  joins and preserves the exact sealed confirmed Understanding head. A
  deterministic or exhausted failure requires the terminal branch matching the
  sealed work scope. `terminalClarifyingGoal`
  atomically fails work/session and the clarifying Goal, writing Session then
  Goal events. `terminalReadyGoalPreserved` atomically fails only work/session,
  emits only the Session event, and leaves every Goal column—including ready
  status and the stored confirmed Understanding ID/version—byte/value
  unchanged; it validates the preserved hash on the joined Understanding row;
- `requestConfirmation`: coach actor only; changes the current draft to
  awaiting confirmation and the session to ready-for-confirmation;
- `confirmUnderstanding`: user actor only; confirms current awaiting version,
  supersedes the prior confirmed version if any, updates Goal head/status to
  ready, and marks the session confirmed;
- `requestUnderstandingRevision`: user actor only; seals the exact current
  Understanding status through `UnderstandingRevisionBranchV1`, advances the
  Session to interviewing, clears the pending pointer, and atomically enqueues
  one new `.coach` turn with caller-owned `nextQuestionId`. `withdrawDraft`
  requires session `interviewing` plus a draft head;
  `withdrawAwaitingConfirmation` requires session `readyForConfirmation` plus
  an awaiting head; both set that row to withdrawn and emit Session then
  Understanding events. `reopenConfirmed` requires a ready Goal with its exact
  confirmed head and permits session `confirmed` or a prior ready-revision
  `failed` session; it leaves the confirmed row and ready Goal unchanged,
  returns the session to interviewing, and emits only the Session event. This
  is the sole retry path after a terminal ready-revision failure. The new work
  carries the exact resulting Understanding event head and derived failure
  scope;
- `abandon`: user actor only; clarifying/ready Goal to abandoned, canceling any
  active coach and source-input parsing work in the same transaction; and
- `fail`: system/coach actor only; terminal deterministic failure of Goal and
  session plus active work cancellation.

All take the exact sealed payloads in §5.4, including Goal/session and every
emitting Understanding event head. All projection, work-ledger, receipt,
ordered event, and outbox writes are one transaction.
Question creation/answer is represented by the CoachSession aggregate; no
unversioned Question aggregate is invented. The partial unique index is backed
by store checks that `pendingQuestionId` equals the only open question.

Stable event counts/order:

| Command | Ordered events |
|---|---|
| open | CoachSession |
| record question | CoachSession |
| answer | CoachSession |
| propose Understanding | CoachSession, Understanding |
| request confirmation | CoachSession, Understanding |
| confirm | CoachSession, Understanding, Goal |
| request revision from draft/awaiting | CoachSession, Understanding |
| request revision from confirmed | CoachSession |
| Coach work transient retry | CoachSession |
| Coach work deterministic/exhausted failure, clarifying Goal | CoachSession, Goal |
| Coach work deterministic/exhausted failure, ready revision | CoachSession |
| abandon/fail without open session | Goal |
| abandon/fail with session | CoachSession, Goal |

The prepared command's event count comes from the sealed branch selector in
§6, not from mutable current state. The new path proves the selector matches
the work/session/Goal rows before mutation; replay validates the old complete
graph before any projection read.

The sole P1-C processor for `.coach` is package struct
`CoachTurnProcessor: Sendable`,
appended to existing authorized carrier `DurableWorkSupervisor.swift` between
the exact final-file markers below. All bytes before the begin marker remain
unchanged from the frozen pre-image, and the end marker plus newline are the
final bytes of the file:

```text
// P1-C-BEGIN CoachTurnProcessor
// P1-C-END CoachTurnProcessor
```

The processor is a separate awaited value; it does not alter the existing
`DurableWorkSupervisor` actor, its A1/A2 lifecycle, or its claimed-kind routes.
Its dependency and provider boundary is exactly:

```swift
package struct CoachQuestionHistoryEntryV1: Sendable, Equatable {
    package let questionId: String
    package let decisionKey: String
    package let prompt: String
    package let recommendation: String
    package let reason: String
    package let answer: CoachAnswerV1?
    package let state: CoachQuestionStateV1
    package let createdAt: Date
    package let answeredAt: Date?
}

package struct CoachUnderstandingHistoryEntryV1: Sendable, Equatable {
    package let understandingId: String
    package let version: Int
    package let content: UnderstandingContentV1
    package let status: UnderstandingStatusV1
    package let contentHash: String
    package let createdAt: Date
    package let confirmedAt: Date?
}

package struct CoachTurnProviderRequestV1: Sendable, Equatable {
    package let schemaVersion: Int // exactly 1
    package let workId: String
    package let attempt: Int
    package let goalId: String
    package let sessionId: String
    package let nextQuestionId: String
    package let decisionKey: String
    package let failureScope: CoachFailureScopeV1
    package let goalTitle: String
    package let goalRawIntent: String
    package let confirmedUnderstanding: UnderstandingHeadV1?
    package let understandingHistory: [CoachUnderstandingHistoryEntryV1]
    package let questionHistory: [CoachQuestionHistoryEntryV1]
}

package enum CoachTurnProviderOutcomeV1: Sendable, Equatable {
    case question(prompt: String, recommendation: String, reason: String)
    case understanding(UnderstandingContentV1)
    case failed(ControlWorkerProviderFailureV1)
    case canceled
}

package typealias CoachTurnProviderV1 =
    @Sendable (CoachTurnProviderRequestV1) async
        -> CoachTurnProviderOutcomeV1

package struct CoachTurnProcessor: Sendable {
    package init(
        database: AppDatabase,
        workerId: String,
        clock: @escaping @Sendable () -> Date,
        sleep: @escaping ControlWorkerSleepV1,
        provider: @escaping CoachTurnProviderV1
    ) throws

    package func recoverInterrupted() throws -> [DurableWorkRecord]
    package func runNext() async throws -> Bool
}
```

Recovery calls only §7.3 `adoptExpiredControlWork(kind:.coach,...)`.
`runNext` claims at most one `.coach` row with
`ControlWorkerLeasePolicyV1.leaseDuration`, then performs one synchronous
`database.pool.read` before its first provider or renewal `await`. That read
loads and validates the exact running work/open attempt, canonical
`CoachTurnWorkInputV1`, the sole Session, its Goal, every Question for the
Session, and every Understanding version for the Goal. The Session must be
`interviewing` with `pendingQuestionId == nil`; work/session/Goal IDs and Camps
must match; and the ready/clarifying Goal plus joined confirmed Understanding
must equal the sealed failure scope/head. It builds the §5.3 attempt envelope
and the provider request above from only those persisted values.

`understandingHistory` is sorted by positive version ascending and must have
unique `(understandingId,version)` values, canonical content/hash equality, and
valid status/confirmation metadata. `questionHistory` is sorted by `createdAt`
ascending then canonical question ID ascending; every answer JSON is decoded as
exact `CoachAnswerV1`, and state/answer/answeredAt plus unique decision keys are
validated. No created/confirmed actor identity is sent to the provider. The
request's next question/decision/work/attempt/scope/head are copied from sealed
work authority; title/raw intent and histories come from that one read. There
is no chat memory, UI state, database handle/record captured by the provider,
or post-await history/head lookup.

The processor uses the same
`LatestControlWorkClaim` and parser/renewal structured-task protocol from
§7.3. The provider outcome cannot return an ID, actor, Camp, status, version,
decision key, failure scope, event code, or arbitrary error. The sealed work
input supplies question ID and decision key; Understanding ID is the Goal ID.
Its sealed
`expectedUnderstandingEventVersion` is passed unchanged to
`recordQuestion`, `proposeUnderstanding`, or `recordCoachWorkFailure`; the
worker never queries a mutable Understanding event head after provider return.

On success, after cancellation and full await of renewal, the worker passes
only `closeAndTakeLatest()` to `recordQuestion` or `proposeUnderstanding`, reads
one finite §5.4 `terminalNow`, and calls the terminal Store once. A typed
provider failure maps through the exact §7.3 failure constructor and the
processor seals one of all four failure branches from the latest claim's
attempt/maxAttempts, disposition, and sealed failure scope/head, then reads one
`terminalNow` and calls `recordCoachWorkFailure` once. `.canceled`, task
cancellation, renewal failure, or parent cancellation performs no false
terminal mutation; the running work remains recoverable after expiry. Invalid
provider output instead follows the fixed deterministic failure path in §7.3
and cannot create an unbounded adopt/reclaim loop. A Store
failure rolls back work attempt, Session/Goal, receipt, domain events, and
outboxes together. No detached task, second supervisor, chat-memory recovery,
or generic success fallback exists. Renewal never regenerates its command
envelope. Adoption/retry produces a new attempt key; a repeated terminal call
for the same attempt reuses its old key.

### 8.3 Understanding versions

`UnderstandingCard.swift` defines the exact §11 fields. Content is a typed DTO
whose canonical bytes determine `contentHash`. A replacement proposal is
reachable only after `requestUnderstandingRevision`; it inserts exactly
`max(persisted content version) + 1` and never updates body columns in place.
The revision command first withdraws a prior draft/awaiting version in its own
atomic eventful transition. A prior confirmed version remains confirmed while
the reopened Session interviews and while the new draft awaits confirmation;
it becomes superseded only when that replacement is user-confirmed in the same
transaction that moves the Goal head.

Only status and confirmation metadata may change on an existing unconfirmed
row. Confirmed/superseded content is immutable. Confirmation requires a user
envelope and records that actor ID/time. A coach cannot confirm. Goal becomes
ready only after a confirmed version exists. `goal_controller` stores exactly
its Understanding ID/version and deliberately has no hash column; the same
transaction joins that pair to exactly one confirmed
`understanding_card_version`, validates the canonical content bytes/hash and
the sealed `UnderstandingHeadV1`, and returns U/UC/UCv/UE in the result.
Reopening a confirmed Session does not move a ready Goal back to clarifying and
does not clear its stored ID/version; every ready-revision enqueue/failure joins
and seals the referenced row's hash/event head. Confirming the replacement
keeps the Goal ready while swapping the stored ID/version to the newly confirmed
row. Outcome fields stay nil and v15 is not queried.

`resumeSession(goalId:)` applies the exact one-total-session rule in §8.2,
verifies its pointer against the unique open question, joins any Goal
Understanding ID/version to its exact hashed row, and returns session/question/
current Understanding solely from persisted rows. It does not read chat memory.

## 9. Application seam and local identity

`LocalCaptureIdentity.swift` defines exactly this synchronous injected
boundary, a locked UserDefaults adapter, and `LocalCaptureIdentity`:

```swift
package protocol LocalCaptureIdentityStore: Sendable {
    func getOrCreateCanonicalUUID(
        forKey key: String,
        makeUUID: @Sendable () -> UUID
    ) throws -> String
}
```

`LockedUserDefaultsCaptureIdentityStore` is a final `@unchecked Sendable`
adapter. It has no instance synchronization owner: one type-static process-wide
`NSLock` serializes the fixed production key across every independently
constructed adapter and every `.live()` controller. Its single protocol
operation holds that same static lock continuously across read, validation,
optional generation, write, and reread. Global serialization for this sole key
is intentional; no per-instance lock or check-then-set outside the lock is
allowed. The injected `makeUUID` is invoked inside the critical section only
when no value exists. `LocalCaptureIdentity` is a `Sendable` value holding a
store and an injected
`@Sendable () -> UUID`. The fixed key is exactly
`agentloop.localCaptureInstallationId`.

`installationID()` makes exactly one call to
`store.getOrCreateCanonicalUUID(forKey:makeUUID:)`. That operation:

1. under one lock, reads the stored value;
2. if present, requires a canonical UUID string and returns it;
3. if absent, generates one injected UUID, writes it, rereads it, and requires
   exact equality; and
4. propagates read/write/invalid-value errors. It never silently replaces a
   corrupt value.

It never replaces or repairs a corrupt existing value. The test in-memory store
is a final shared-reference implementation for copy semantics; the production
adapter's static lock additionally protects two distinct adapter instances over
the same `UserDefaults` storage. Tests cover both concurrent first calls across
copies and concurrent first calls across two independently constructed
live-equivalent adapters, proving one persisted canonical winner, no overwrite,
and no divergent returned IDs. They also prove corruption throws without write
or generator invocation. Production may use UserDefaults through the adapter
but generation remains lazy.

`InputWorkflowController.swift` adds a separate port so the existing large
`InputWorkflowPorts` initializer remains byte/API-compatible:

```swift
package struct InputCapturePorts: Sendable {
    package let capture:
        @Sendable (CaptureInputCommandV1) throws -> InputCaptureReceiptV1
    package let read:
        @Sendable (String) throws -> InputEnvelopeRecord?

    package init(
        capture: @escaping @Sendable (CaptureInputCommandV1) throws
            -> InputCaptureReceiptV1,
        read: @escaping @Sendable (String) throws -> InputEnvelopeRecord?
    )

    package static func live(database: AppDatabase) -> Self
}
```

`live` captures one `InputGoalStore(database:)`; `capture` calls only
`captureAndEnqueueParsing`, and `read` calls only `input(id:)`. It is the sole
Application-to-Core capture seam.

The application request is exact and owns the replay identities:

```swift
package struct LocalInputCaptureRequestV1: Sendable {
    package let inputId: String
    package let idempotencyKey: String
    package let auditCampId: String
    package let initialCampId: String?
    package let sourceType: InputSourceTypeV1
    package let connectorId: String?
    package let authorId: String?
    package let capturedAt: Date
    package let inlineText: String?
    package let payloadRef: String?
    package let contentHash: String
    package let candidateCampIds: [String]
    package let explicitIntent: InputExplicitIntentV1
    package let privacyLevel: InputPrivacyLevelV1
    package let parentInputId: String?
    package let causationId: String?

    package init(
        inputId: String,
        idempotencyKey: String,
        auditCampId: String,
        initialCampId: String?,
        sourceType: InputSourceTypeV1,
        connectorId: String?,
        authorId: String?,
        capturedAt: Date,
        inlineText: String?,
        payloadRef: String?,
        contentHash: String,
        candidateCampIds: [String],
        explicitIntent: InputExplicitIntentV1,
        privacyLevel: InputPrivacyLevelV1,
        parentInputId: String?,
        causationId: String?
    )
}
```

`inputId` is a canonical caller-owned UUID; `idempotencyKey` is the exact
domain command key. The caller must retain and reuse the whole request plus
the same `OperationTrace` for retry. The Application seam adds no generated
command ID or time.

The third and final top-level declaration in the marker block is a dedicated
actor. The existing `InputWorkflowController` declaration, initializer, stored
properties, methods, and all existing call sites remain byte-for-byte
unchanged:

```swift
package actor InputCaptureWorkflowController {
    private let reporter: FailureReporter
    private let capturePorts: InputCapturePorts
    private let localCaptureIdentity: LocalCaptureIdentity

    package init(
        database: AppDatabase,
        reporter: FailureReporter,
        capturePorts: InputCapturePorts? = nil,
        localCaptureIdentity: LocalCaptureIdentity? = nil
    )

    package func captureLocalInput(
        _ request: LocalInputCaptureRequestV1,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<InputCaptureReceiptV1>

    package func loadInput(
        id: String,
        trace: OperationTrace
    ) async -> WorkflowLoadState<InputEnvelopeRecord>
}
```

The initializer assigns `capturePorts ?? .live(database: database)` and
`localCaptureIdentity ?? .live()` to the exact three immutable stored
properties. `.live()` constructs the locked `UserDefaults.standard` adapter
but performs no read or write until capture. The dedicated actor exposes no
other initializer, stored property, package/public method, or conformance.

Local capture calls `installationID()` synchronously inside the awaited
operation and constructs `CaptureInputCommandV1` with:

- actor type `user`;
- actor ID `user:local-owner`;
- device ID and Input sourceDeviceId equal to the stable installation UUID;
- envelope correlation ID exactly `trace.traceId`;
- envelope occurredAt and Input capturedAt exactly `request.capturedAt`;
- causation exactly `request.causationId`, including explicit null; and
- no account ID or real account identifier.

It forwards every other request field unchanged. The method uses the existing
`captureAsyncOperation` with `onFailure: { .notCommitted($0) }`; because the
Core transaction is total, it never emits `committedWithVisibilityFailure`.
`loadInput` uses `captureAsyncLoad`; nil becomes
`RecordNotFoundError(table: "input_envelope", id: id)`. Neither method writes
GRDB, opens a Task, calls the legacy Feed/rumination ports, chooses a Camp, or
performs a post-commit navigation. No SwiftUI call site is added in P1-C.

## 10. TDD batches and pure red evidence

Before product code for each batch, add the named tests, run only that filter,
and append complete stdout/stderr plus command/cwd/start/end/exit framing to
`red-tests.log` under `set -o pipefail`. The expected nonzero exit must be due
to the missing v14/capability named by that batch, not an unrelated baseline
failure. A red run that fails for an unknown reason blocks implementation.

Each new test file has exactly one enclosing suite, respectively
`P1CControlContractMigrationTests`, `P1CDomainEventContractTests`,
`P1CInputEnvelopeContractTests`, and `P1CGoalCoachContractTests`. Every named
test is declared inside that file's suite. This gives the final gate an exact,
machine-extractable P1-C discovery namespace; an extra declaration or an extra
discovered test in any of the four suites fails.

### Batch C1 — migration red

Add `ControlContractMigrationTests.swift` first and run:

```bash
swift run RunTests --filter 'controlContractMigrationExactDDLAndConstraints|controlContractMigrationReplaysFromFreshAndV11Twice|controlContractMigrationRollbackLeavesV13Untouched|controlContractAppendOnlyTablesRejectNoopUpdateAndDelete|controlContractSchemaHasExactInboxRedactionShape|inputSchemaHasNoParseAttemptColumn|inputSchemaRejectsDeletedStatusWithActiveRetention|activeInputRequiresExactlyOneInlineOrPayloadRef|inputSchemaRejectsTombstoneRetentionWithLiveStatus'
```

Expected red root: final migration is v13 / v14 objects absent. Then implement
only the v14 migration and matrix carrier extension until this batch is green.

### Batch C2 — command/event red

Add `DomainEventContractTests.swift` and run its exact named alternation:

- `persistedControlContractConstantsAndWorkKeyDerivationsAreExact`;
- `workerCommandEnvelopeFactoriesAreExactAttemptScopedAndReplayStable`;
- `preparedCommandIsPreReceiptAuthorityAndNewResultIsPostMutationOnly`;
- `commandEnvelopeWholeHashCoversEveryFieldAndNullability`;
- `canonicalContractCodingReusesCanonicalJSONV1GoldenBytes`;
- `campSafeJSONRejectsUnknownForbiddenIdentityAndNoncanonicalBytes`;
- `campSafeJSONRejectsSemanticallyForbiddenReferenceValues`;
- `everyCommandResultAndAuditShapeIsExactAndOrdered`;
- `executeCommandCommitsReceiptProjectionEventsAndOutboxAtomically`;
- `executeCommandReplayReturnsOldResultWithoutMutation`;
- `creationReplayUsesPersistedResultBeforeIDFactoryOrProjectionBranch`;
- `replayValidatesCompleteStoredEventAndOutboxGraph`;
- `executeCommandRejectsTypeHashOrEventCountDriftTotally`;
- `multiAggregateCommandUsesStableOrdinalsAndVersionChains`;
- `eventCountOrdinalOrProjectionFailureRollsBackEverything`;
- `domainEventCopiesEnvelopeAndOwnsRecordedAt`;
- `domainEventRejectsMissingCampBadTimeAndVersionPreSQL`;
- `outboxClaimReleaseSentCASAndReplayAreDeterministic`;
- `inboxApplyReplayConflictAndTypedRejectionAreDurable`;
- `inboxTypedRejectionRollsBackHandlerSavepointBeforeDurableEvidence`;
- `inboxSameKeyAndStoredHashButDifferentBytesFailsClosedWithoutHandler`;
- `inboxConflictCASPersistsExactRejectedShapeAndThrowsAfterCommit`;
- `inboxConflictAgainstRedactedRowIsTerminalWithoutCASOrHandler`;
- `inboxRedactedTombstonesPreservePriorHashAndAppliedTimeAcrossOrigins`;
- `domainEventsReadInValidatedAggregateOrder`.

Expected red root: new contract/store types absent. Implement only §5–§6 until
green. This batch may create only the pure typed replay-plan factories in
`InputGoalStore.swift` and `CoachUnderstandingStore.swift` described by §5.4;
it may not add their database mutation APIs. DomainEvent tests use those real
closed factories, not an arbitrary replay-plan initializer or a test-only
production command. `executeCommandReplayReturnsOldResultWithoutMutation`
archives the sealed Camp after the first commit and proves exact replay still
validates/returns the stored graph without a current Camp-state read.
`creationReplayUsesPersistedResultBeforeIDFactoryOrProjectionBranch` also
asserts one event-ID/clock call per created event and zero independent outbox
ID calls. The worker-envelope test covers both allowed kinds, exact graph
rejection, shared success/failure identity within one attempt, divergent
outcome conflict, renewal stability, committed replay, and a distinct key only
after interrupted adoption creates the next attempt. The prepared/new test
proves no result/post-mutation initializer exists on the pre-receipt value. The
savepoint test writes a sentinel row inside the handler and then returns a typed
rejection: the sentinel must roll back while the exact rejected inbox evidence
commits.

### Batch C3 — Input/parsing red

Add `InputEnvelopeContractTests.swift` and run:

- `captureAndInputParsingWorkCommitAtomically`;
- `inputCaptureReplayAndPayloadDriftConflict`;
- `inputCaptureReplayUsesCallerOwnedIDAndExistingWorkResult`;
- `inputParsingCrashIsAdopted`;
- `controlWorkAdoptionRequiresExpiredLeaseAndRecoversSameOwnerAcrossKinds`;
- `inputParsingRenewalHandsLatestClaimToTerminalCommit`;
- `inputParsingTerminalTimeIsMonotonicAndRetryBackoffStartsAtFailure`;
- `inputParsingRenewalFailureCancelsParserWithoutProjectionCommit`;
- `inputParsingRetriesBoundedlyThenParseFailed`;
- `inputParsingCancelRejectsStaleResult`;
- `cancelParsingAndDeleteRejectsNoActiveBranchBeforeMutation`;
- `inputParsingTerminalMutationRollbackIsTotal`;
- `inputTransitionMatrixAcceptsOnlyStageSpecEdges`;
- `ordinaryInputTransitionsRejectEveryActiveParsingStateWithoutWrites`;
- `everyInputCommandEnforcesExactActorAndDeviceMatrixBeforeSQL`;
- `inputParserInterfaceUsesOnePersistedPreAwaitSnapshotAndClosedOutcome`;
- `inputParserInvalidOutputFailsDeterministicallyExactlyOnce`;
- `crossCampAmbiguityNeverSelectsDefaultCamp`;
- `inputCampScopeIsStableFromCaptureThroughAssignment`;
- `inputRejectsInitialOrAssignedCampDifferentFromAuditCamp`;
- `inputParsingWorkAlwaysUsesAuditCampAndArchivedCampFailsClosed`;
- `inputTombstoneRetainsOnlyExactIdentityHashAndTimes`;
- `inputTombstoneNullsDeviceConnectorAuthorBodyRefErrorAndParent`;
- `inputTombstoneForcesEmptyCandidatesUnspecifiedIntentLocalOnlyAndEqualDeleteTime`;
- `localCaptureIdentityPersistsOnceAndFailsOnCorruption`;
- `localCaptureIdentityConcurrentFirstUseAcrossCopiesIsAtomic`;
- `localCaptureIdentityConcurrentFirstUseAcrossIndependentAdaptersIsAtomic`;
- `localCaptureUsesLocalOwnerAndInstallationDeviceWithoutAccountIdentity`;
- `localCapturePortAndInitializerRemainSourceCompatible`;
- `localCaptureTraceCorrelationAndRequestIDsAreExact`;
- `loadInputUsesReadPortAndMapsMissingRecordToFailure`;
- `legacyIngestionAdapterIsDisplayOnlyAndCreatesNoInputOrGoal`;
- `nilInputCampNeverInfersAuthority`.

Expected red root: Input/store/worker/application identity capability absent.
Implement only §7 and §9 until green. The active-work matrix runs each ordinary
transition named in §7.2 against queued, running, and retryScheduled parsing
work and proves projection, Goal, work, receipt, event, and outbox counts/bytes
are unchanged. The cancel test proves `.none` is rejected before SQL and only
the exact `.expected` identity can cancel-and-delete. The adoption test covers
both control kinds, same-owner expired recovery, foreign expired recovery, and
foreign live-lease no-op while proving the generic adopter bytes/behavior stay
unchanged. The terminal-time test includes a long attempt and post-renewal
failure. The provider-interface test captures its only request and proves later
database mutation cannot alter that snapshot. The authorization and independent
adapter tests exercise every row and race boundary frozen above.
`inputParserInvalidOutputFailsDeterministicallyExactlyOnce` returns each
invalid route/result shape, proves the exact
`input_parser_invalid_output` deterministic failure is terminalized once with
the latest claim in one transaction, and proves receipt replay neither recalls
the provider nor adds work/event/outbox rows.

### Batch C4 — Goal/Coach/Understanding red

Add `GoalCoachContractTests.swift` and run:

- `crossCampAmbiguityBlocksGoalCreationWithoutWrites`;
- `convertToGoalCommitsInputGoalEventsAndOutboxesAtomically`;
- `convertToGoalReplayUsesCallerOwnedGoalIDAfterProjectionAdvances`;
- `goalP1CTransitionsOnlyClarifyingReadyAbandonedAndFailed`;
- `openCoachSessionEnqueuesDurableCoachWorkAtomically`;
- `openCoachReplayUsesCallerOwnedSessionAndQuestionIDs`;
- `oneCoachSessionPerGoalControlsConcurrentOpenResumeAndTerminalBranches`;
- `coachSessionAllowsExactlyOneOpenQuestion`;
- `coachQuestionAndAnswerEnforceCoachAndUserActors`;
- `everyGoalCoachCommandEnforcesExactActorAndDeviceMatrixBeforeSQL`;
- `coachSealedDecisionKeyNeverComesFromProvider`;
- `coachProviderInterfaceOrdersPersistedHistoryBeforeAwait`;
- `coachProviderInvalidOutputFailsDeterministicallyExactlyOnce`;
- `coachAnswerEnqueuesNextDurableTurnAtomically`;
- `coachAnswerReplayDoesNotEnqueueSecondTurn`;
- `coachProposalReplayUsesGoalIDAsUnderstandingID`;
- `coachFailureRetriesAtomicallyAndKeepsSessionInterviewing`;
- `coachFailureExhaustionFailsSessionAndGoalAtomically`;
- `coachReopenedTerminalFailuresAndReplayPreserveReadyGoalAndConfirmedHead`;
- `readyRevisionWorkSealsAndValidatesJoinedConfirmedUnderstandingHash`;
- `coachWorkerRestartAdoptsInterruptedTurn`;
- `coachRenewalHandsLatestClaimToTerminalCommit`;
- `coachTerminalTimeIsMonotonicAfterRenewalAndBackoffStartsAtFailure`;
- `coachWorkerCancellationLeavesRecoverableRunningWork`;
- `coachTerminalMutationRollbackRestoresWorkSessionGoal`;
- `understandingEditAlwaysCreatesNewVersion`;
- `requestConfirmationDoesNotRewriteUnderstandingBody`;
- `requestUnderstandingRevisionWithdrawsOrReopensAndEnqueuesTurn`;
- `coachCannotConfirmUnderstanding`;
- `confirmUnderstandingSupersedesPriorVersionAndMakesGoalReady`;
- `coachRestartRestoresExactlyOneOpenQuestionWithoutChatMemory`;
- `goalAbandonAndFailCancelActiveControlWorkAtomically`;
- `goalAbandonReplayUsesSealedSessionBranchAfterProjectionChanges`;
- `goalFailReplayUsesSealedSessionBranchAfterProjectionChanges`;
- `goalReadyDoesNotRequireV15Schema`.

Expected red root: Goal/Coach/Understanding capability absent. Implement only
§8 until green. The revision test covers all three sealed revision branches,
their one-versus-two event counts, work-input event-head propagation, and
unchanged ready Goal/confirmed head on reopen. The edit/supersession tests then
drive the reopened work through a higher content version and confirm it,
proving the old confirmed row is superseded only at that final transaction.
The reopened-terminal test covers deterministic and exhausted failures, exact
Session-only event/result membership, unchanged ready Goal/current confirmed
head, receipt replay after further session movement, and user
`reopenConfirmed` retry from both confirmed and failed session states. The
one-session test covers serialized concurrent opens, exact replay, all statuses,
resume zero/one/multiple integrity behavior, and `.none`/`.expected` terminal
branches. The provider request test proves exact history ordering and no
post-await read. The ready-hash test mutates/forges each joined carrier and
expects total rollback. The terminal-time test includes renewal and delayed
provider failure.
`coachProviderInvalidOutputFailsDeterministicallyExactlyOnce` returns every
invalid provider branch, proves the exact `coach_provider_invalid_output`
deterministic failure follows the sealed fresh/reopened terminal branch once
with the latest claim, and proves atomic receipt/projection/event/outbox/work
effects plus replay without another provider call.

For C2–C4, “run” means join the listed names in listed order with literal `|`
as one single-quoted `swift run RunTests --filter '<alternation>'` argument; no
name, wildcard, second filter, or retry is permitted. The frozen declaration
arithmetic is exactly `9 C1 + 25 C2 + 33 C3 + 35 C4 = 102` tests.

After every green batch, re-run its exact filter into `focused-verify.log`,
recompute the outside manifest and read-only hashes, and run `git diff --check`
on the exact write set. Do not weaken or delete a red assertion to obtain
green.

## 11. Final validation and evidence

All commands run from `/Users/muzi/Agent-loop` with `set -o pipefail` and full
stdout/stderr. Each log begins with command, cwd, branch, HEAD, UTC start and
ends with UTC finish, actual exit, and `RESULT: PASSED|FAILED`. Use unique
`mktemp` capture files and atomically install the final evidence; do not reuse
historical logs.

Run in this order after all focused tests are green:

1. `scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`
   -> `migration-matrix.log`;
2. the fail-fast source/hash/scope gates below -> `source-gates.log`;
3. `swift build --product AgentLoopApp` -> `build.log`;
4. authoritative, unfiltered `swift run RunTests` -> `verify.log` last.

Review01H must include exactly one machine-readable line
`approved_plan_sha256=<64 lowercase hex>` and exactly one line
`verdict=APPROVED — 0 P0 / 0 P1`. The implementation gate reads those lines;
it never hardcodes a self-referential plan hash.

### 11.1 Exact outside-worktree serializer

The following Ruby body is the complete serializer. It is not inherited by
reference from P1-B. It enumerates modified/untracked paths with terminal NUL,
excludes only the exact P1-C write/artifact set plus two individually frozen
dirty DurableWork carriers, preserves raw path bytes, `lstat.mode`, node type,
file byte length and raw SHA-256 (or raw symlink target), and fails on Git
stderr/read/type errors. It must print `outside_count=446` and the frozen
Revision 7 hash.

```ruby
require "digest"
require "open3"
require "set"

allow = Set.new(%w[
Sources/AgentLoopCore/Database/AppDatabase.swift
Sources/AgentLoopCore/Database/EventKind.swift
Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
Sources/AgentLoopCore/Domain/CommandEnvelope.swift
Sources/AgentLoopCore/Domain/DomainEvent.swift
Sources/AgentLoopCore/Domain/InputEnvelope.swift
Sources/AgentLoopCore/Domain/GoalController.swift
Sources/AgentLoopCore/Domain/CoachContracts.swift
Sources/AgentLoopCore/Domain/UnderstandingCard.swift
Sources/AgentLoopCore/Database/DomainEventStore.swift
Sources/AgentLoopCore/Database/InputGoalStore.swift
Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift
Sources/AgentLoopCore/Work/InputParsingWorker.swift
Sources/AgentLoopApplication/InputWorkflowController.swift
Sources/AgentLoopApplication/LocalCaptureIdentity.swift
Sources/AgentLoopTestSuite/DomainEventContractTests.swift
Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
Sources/AgentLoopTestSuite/DurablePlanningTests.swift
Sources/AgentLoopTestSuite/FailureVisibilityTests.swift
Sources/AgentLoopTestSuite/BoardServerTests.swift
Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift
Sources/P1MigrationMatrixRunner/main.swift
scripts/verify-p1-migrations-sqlite-matrix.sh
Sources/AgentLoopCore/Work/DurableWork.swift
Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
Sources/AgentLoopCore/Database/DurableWorkStore.swift
Sources/AgentLoopTestSuite/DurableWorkTests.swift
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/plan.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/blocked.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/red-tests.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/focused-verify.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/focused-rev7-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/migration-matrix.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/source-gates.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/build-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/build.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/verify-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/verify.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/impl-report.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01a-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01b-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01c-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01d-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01e-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01f-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01g-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01h-p1-c-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/02-p1-c-implementation-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/acceptance.md
])

raw, err, status = Open3.capture3(
  "git", "ls-files", "--modified", "--others", "--exclude-standard", "-z"
)
abort("git ls-files failed: #{err}") unless status.success?
abort("git ls-files stderr: #{err}") unless err.empty?
parts = raw.b.split("\0", -1)
abort("missing terminal NUL") unless parts.last == ""
parts.pop
paths = parts.reject { |path| allow.include?(path) }.sort
digest = Digest::SHA256.new
paths.each do |path|
  stat = File.lstat(path)
  digest << [path.bytesize].pack("Q>") << path
  digest << [stat.mode].pack("L>")
  if stat.file?
    bytes = File.binread(path)
    digest << "F" << [bytes.bytesize].pack("Q>")
    digest << Digest::SHA256.digest(bytes)
  elsif stat.symlink?
    target = File.readlink(path).b
    digest << "L" << [target.bytesize].pack("Q>") << target
  else
    abort("unsupported outside-allowlist node: #{path}")
  end
end
actual = digest.hexdigest
puts "dirty_total=#{parts.length}"
puts "allowlisted_present_count=#{parts.count { |path| allow.include?(path) }}"
puts "outside_count=#{paths.length}"
puts "outside_manifest_v1=#{actual}"
abort("outside count drift") unless paths.length == 446
abort("outside manifest drift") unless actual ==
  "0d9b78388c5cc2e01dc31dd6250d71c7a55c1ca76d12a8b974225077ae455c75"
```

### 11.2 Executable source/hash/discovery gate

The evidence wrapper invokes the following body under `/bin/bash` with
`set -euo pipefail`, while teeing its complete stdout/stderr to the unique
temporary body for `source-gates.log`. `rg` status 1 is accepted only by
`assert_rg_absent`; status 2 or stderr always fails.

```bash
set -euo pipefail

fail() {
    printf 'P1-C source gate: %s\n' "$*" >&2
    exit 1
}

gate_tmp="$(mktemp -d "${TMPDIR:-/tmp}/agentloop-p1c-source.XXXXXX")"
cleanup() {
    case "$gate_tmp" in
        "${TMPDIR:-/tmp}"/agentloop-p1c-source.*) rm -rf -- "$gate_tmp" ;;
        *) fail "unsafe temporary path: $gate_tmp" ;;
    esac
}
trap cleanup EXIT

assert_rg_absent() {
    local pattern="$1"
    shift
    local output="$gate_tmp/rg-absent.out"
    local errors="$gate_tmp/rg-absent.err"
    local status
    set +e
    rg -n -- "$pattern" "$@" >"$output" 2>"$errors"
    status=$?
    set -e
    test ! -s "$errors" || fail "rg stderr for absent [$pattern]"
    case "$status" in
        1) ;;
        0) cat "$output" >&2; fail "forbidden match [$pattern]" ;;
        *) fail "rg status $status for absent [$pattern]" ;;
    esac
}

assert_rg_count() {
    local pattern="$1"
    local path="$2"
    local expected="$3"
    local output="$gate_tmp/rg-count.out"
    local errors="$gate_tmp/rg-count.err"
    local status count
    set +e
    rg -n -- "$pattern" "$path" >"$output" 2>"$errors"
    status=$?
    set -e
    test ! -s "$errors" || fail "rg stderr for count [$pattern]"
    test "$status" -eq 0 || fail "rg status $status for count [$pattern]"
    count="$(wc -l <"$output" | tr -d ' ')"
    test "$count" = "$expected" \
        || fail "count [$pattern] in $path is $count, expected $expected"
}

assert_rg_present() {
    local pattern="$1"
    local path="$2"
    local output="$gate_tmp/rg-present.out"
    local errors="$gate_tmp/rg-present.err"
    local status
    set +e
    rg -n -- "$pattern" "$path" >"$output" 2>"$errors"
    status=$?
    set -e
    test ! -s "$errors" || fail "rg stderr for present [$pattern]"
    test "$status" -eq 0 || fail "missing required match [$pattern] in $path"
}

check_hash() {
    local expected="$1"
    local path="$2"
    local actual
    test -f "$path" || fail "missing protected file: $path"
    actual="$(shasum -a 256 "$path" | awk '{print $1}')"
    test "$actual" = "$expected" \
        || fail "protected hash drift: $path $actual"
    printf 'source.hash.%s=pass\n' "$path"
}

assert_swift_top_level() {
    local path="$1"
    local label="$2"
    local expected="$3"
    local ast="$gate_tmp/${label}.ast"
    local errors="$gate_tmp/${label}.parse.err"
    local actual status
    set +e
    xcrun swiftc -frontend -parse -dump-parse "$path" >"$ast" 2>"$errors"
    status=$?
    set -e
    test "$status" -eq 0 || fail "Swift parse failed for $label"
    test -z "$(tr -d '[:space:]' <"$errors")" \
        || fail "Swift parse stderr for $label"
    actual="$(ruby -e '
      path = ARGV.fetch(0)
      items = []
      File.foreach(path) do |line|
        match = line.match(/^  \(([a-z_]+)_decl\b(.*)$/)
        next unless match
        kind = match[1]
        rest = match[2]
        name = rest[/\bunbound "([^"]+)"/, 1] ||
          rest[/ "([^"]+)"/, 1] || "<anonymous>"
        kind = "class-actor" if kind == "class" && rest.match?(/\bactor\b/)
        items << "#{kind}:#{name}"
      end
      puts items.join("|")
    ' "$ast")"
    test "$actual" = "$expected" \
        || fail "top-level declarations for $label are [$actual], expected [$expected]"
    printf 'source.swift_top_level.%s=pass\n' "$label"
}

test "$(pwd -P)" = "/Users/muzi/Agent-loop" || fail "wrong checkout"
test "$(git branch --show-current)" = "codex/personal-ai-ranch-p0" \
    || fail "wrong branch"
test "$(git rev-parse HEAD)" = \
    "02334ec8d21533be81d93d39191bc7d9b9c24f7f" || fail "wrong HEAD"
printf 'source.checkout=pass\n'

check_hash 046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242 AGENTS.md
check_hash 9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1 docs/collaboration/claude-codex-protocol.md
check_hash d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md
check_hash bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md
check_hash 5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md
check_hash da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/acceptance.md
check_hash 3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/reviews/24-p1-b-closeout-review.md
check_hash 6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/verify.log
check_hash 08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01-p1-c-plan-review.md
check_hash cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01a-p1-c-plan-review.md
check_hash 52391a6cf2612211f1a3612e5fb5379101cb2c90f644430c7fe04e5398a4e4de docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01b-p1-c-plan-review.md
check_hash c07a305be3c0fae8e8f26fb02622c4d862997f20b5fc6b5ffe1778a89c7f9053 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01c-p1-c-plan-review.md
check_hash b734b7e810f881945c8530a8ec5f9effe7e40dac9ef73c5d73e9063d987fb43b docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01d-p1-c-plan-review.md
check_hash 97c3171dcc7f86bb7c08ca48c06468380e0602be0503b9583faee1b8b24df2ad docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01e-p1-c-plan-review.md
check_hash 30a43932985d9a74009a6d70f03ddfe8822e54a9665d674db2c5fac32d2120be docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01f-p1-c-plan-review.md
check_hash 18b744362a1732716af8f3c42128e06e4634df7e9e47902f21cf7e21483ba920 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01g-p1-c-plan-review.md
check_hash 7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79 Sources/AgentLoopCore/JSON/CanonicalJSON.swift
check_hash 5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433 Sources/AgentLoopCore/Work/DurableWork.swift
check_hash 061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad Sources/AgentLoopTestSuite/DurableWorkTests.swift
check_hash b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c Package.swift
check_hash d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a Package.resolved
check_hash 70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3 Sources/RunTests/main.swift
check_hash c8afc50f5af67d4544ba399523aed34bb7c974e4e67dca259f813a3345ec5238 Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift
check_hash bf6ff041aeb8686734000d40527ea2d564983ddadb5859e534876668cb4ea05e docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/build-red.log
check_hash d156975e9b5018419e48f17c66cfce645ea1702fb990095dcb6facc4bdc5fca1 docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/verify-red.log
check_hash 44a4c621e0d7c70da18d9080283bf56de5dd346e924aa23efdebe453a685c85f docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/focused-rev7-red.log
check_hash f125868304f7f6929e3ec2f20ec15a90761ec131797db135d1f018eee2618ed4 Sources/AgentLoopTestSuite/DurablePlanningTests.swift
check_hash 1b12cab12cf4b1855ac1865c3314e60974b4df6f96c5952f252fe667ab8343d4 Sources/AgentLoopTestSuite/FailureVisibilityTests.swift
check_hash 249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b Sources/AgentLoopTestSuite/BoardServerTests.swift

plan=docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/plan.md
review=docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-c-control-contracts/reviews/01h-p1-c-plan-review.md
assert_rg_count '^approved_plan_sha256=[0-9a-f]{64}$' "$review" 1
assert_rg_count '^verdict=APPROVED — 0 P0 / 0 P1$' "$review" 1
approved="$(sed -n 's/^approved_plan_sha256=//p' "$review")"
actual_plan="$(shasum -a 256 "$plan" | awk '{print $1}')"
test "$approved" = "$actual_plan" || fail "approved plan hash drift"
printf 'source.approved_plan=%s\n' "$actual_plan"

assert_rg_count '^```ruby$' "$plan" 1
awk '
    /^```ruby$/ && !capturing { capturing = 1; next }
    capturing && /^```$/ { exit }
    capturing { print }
' "$plan" >"$gate_tmp/outside.rb"
test -s "$gate_tmp/outside.rb" || fail "outside serializer extraction failed"
TMPDIR="$gate_tmp" ruby "$gate_tmp/outside.rb"

app_database=Sources/AgentLoopCore/Database/AppDatabase.swift
stage_spec=docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md
app_sanitized="$gate_tmp/v14-control-contracts-sanitized.swift"
ruby - "$app_database" "$stage_spec" "$app_sanitized" <<'RUBY'
require "digest"

path, authority_path, sanitized_path = ARGV
bytes = File.binread(path)
begin_line = "        // P1-C-BEGIN V14ControlContractsMigration\n"
end_line = "        // P1-C-END V14ControlContractsMigration\n"
abort("V14 begin marker count is not one") unless bytes.scan(begin_line).length == 1
abort("V14 end marker count is not one") unless bytes.scan(end_line).length == 1
start = bytes.index(begin_line)
finish = bytes.index(end_line, start)
abort("V14 markers missing or reversed") unless start && finish && finish > start
finish += end_line.bytesize
block = bytes.byteslice(start, finish - start)
reconstructed = bytes.byteslice(0, start) +
  bytes.byteslice(finish, bytes.bytesize - finish)
expected_preimage =
  "29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b"
abort("AppDatabase preimage drift outside V14 block") unless
  Digest::SHA256.hexdigest(reconstructed) == expected_preimage

authority = File.binread(authority_path)
heading = "### 18.4 `v14-p1-control-contracts`"
heading_at = authority.index(heading)
abort("V14 authority heading missing") unless heading_at
fence_at = authority.index("```sql\n", heading_at)
abort("V14 authority SQL fence missing") unless fence_at
sql_start = fence_at + "```sql\n".bytesize
sql_finish = authority.index("\n```", sql_start)
abort("V14 authority SQL fence is unterminated") unless sql_finish
sql = authority.byteslice(sql_start, sql_finish - sql_start) + "\n"
abort("V14 authority SQL line count drift") unless sql.lines.count == 292
abort("V14 authority SQL hash drift") unless
  Digest::SHA256.hexdigest(sql) ==
    "a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531"
indented_sql = sql.each_line.map { |line|
  line == "\n" ? line : "                #{line}"
}.join
expected_block =
  begin_line +
  "        m.registerMigration(\"v14-p1-control-contracts\") { db in\n" +
  "            try db.execute(sql: \"\"\"\n" +
  indented_sql +
  "                \"\"\")\n" +
  "        }\n" +
  end_line
abort("V14 block differs from exact authority-backed carrier") unless
  block == expected_block
sanitized = expected_block.sub(
  indented_sql,
  "                /* exact authenticated stage-spec SQL omitted */\n"
)
File.binwrite(sanitized_path, sanitized)
puts "source.app_database_strip_to_preimage=pass"
puts "source.v14_exact_authority_sql=pass"
RUBY

event_kind=Sources/AgentLoopCore/Database/EventKind.swift
event_block="$gate_tmp/control-contract-vocabulary.swift"
ruby - "$event_kind" "$event_block" <<'RUBY'
require "digest"

path, extracted_path = ARGV
bytes = File.binread(path)
begin_marker = "// P1-C-BEGIN ControlContractVocabulary"
end_marker = "// P1-C-END ControlContractVocabulary"
abort("Vocabulary begin marker count is not one") unless
  bytes.scan(begin_marker).length == 1
abort("Vocabulary end marker count is not one") unless
  bytes.scan(end_marker).length == 1
start = bytes.index(begin_marker)
abort("Vocabulary begin marker missing") unless start
block = bytes.byteslice(start, bytes.bytesize - start)
abort("Vocabulary block is not final or lacks final newline") unless
  block.end_with?(end_marker + "\n")
prefix = bytes.byteslice(0, start)
expected = "1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4"
abort("EventKind preimage drift outside Vocabulary block") unless
  Digest::SHA256.hexdigest(prefix) == expected
source = block.dup.force_encoding(Encoding::UTF_8)
abort("Vocabulary block is not UTF-8") unless source.valid_encoding?
expected_names = %w[
  P1AggregateTypeV1 P1CommandTypeV1 P1EventTypeV1
  P1ResultCodeV1 P1AuditCodeV1
]
declarations = source.scan(
  /^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:indirect\s+)?(?:final\s+)?(?:actor|class|struct|enum|protocol|extension|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)/
).flatten
abort("Vocabulary declaration surface differs") unless declarations == expected_names
expected_names.each do |name|
  pattern = /package\s+enum\s+#{Regexp.escape(name)}\s*:\s*String\s*,\s*Codable\s*,\s*Sendable\s*,\s*Equatable\s*,\s*CaseIterable\s*\{/
  abort("Vocabulary enum shape differs: #{name}") unless source.scan(pattern).length == 1
end
abort("Vocabulary block has executable/helper declaration") if
  source.match?(/^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:static\s+)?(?:func|init|let|var|subscript)\b/)
File.binwrite(extracted_path, block)
puts "source.event_kind_strip_to_preimage=pass"
puts "source.control_contract_vocabulary_surface=pass"
RUBY
assert_swift_top_level \
    "$event_block" \
    event-vocabulary \
    'enum:P1AggregateTypeV1|enum:P1CommandTypeV1|enum:P1EventTypeV1|enum:P1ResultCodeV1|enum:P1AuditCodeV1'

controller=Sources/AgentLoopApplication/InputWorkflowController.swift
controller_block="$gate_tmp/local-input-capture-workflow.swift"
ruby - "$controller" "$controller_block" <<'RUBY'
require "digest"

path, extracted_path = ARGV
bytes = File.binread(path)
begin_marker = "// P1-C-BEGIN LocalInputCaptureWorkflow"
end_marker = "// P1-C-END LocalInputCaptureWorkflow"
abort("Capture begin marker count is not one") unless
  bytes.scan(begin_marker).length == 1
abort("Capture end marker count is not one") unless
  bytes.scan(end_marker).length == 1
start = bytes.index(begin_marker)
abort("Capture begin marker missing") unless start
block = bytes.byteslice(start, bytes.bytesize - start)
abort("Capture block is not final or lacks final newline") unless
  block.end_with?(end_marker + "\n")
prefix = bytes.byteslice(0, start)
expected = "1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb"
abort("Controller preimage drift outside Capture block") unless
  Digest::SHA256.hexdigest(prefix) == expected
source = block.dup.force_encoding(Encoding::UTF_8)
abort("Capture block is not UTF-8") unless source.valid_encoding?
declarations = source.scan(
  /^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:final\s+)?(actor|class|struct|enum|protocol|extension|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)/
)
expected_declarations = [
  ["struct", "InputCapturePorts"],
  ["struct", "LocalInputCaptureRequestV1"],
  ["actor", "InputCaptureWorkflowController"],
]
abort("Capture top-level/type declaration surface differs") unless
  declarations == expected_declarations
abort("Capture actor declaration or conformance differs") unless
  source.scan(/^package actor InputCaptureWorkflowController \{$/).length == 1
api_funcs = source.scan(/^\s*package\s+(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)/).flatten
abort("Capture package function surface differs") unless
  api_funcs == %w[live captureLocalInput loadInput]
abort("Capture package initializer count differs") unless
  source.scan(/^\s*package\s+init\s*\(/).length == 3
package_values = source.scan(
  /^\s*package\s+(?:static\s+)?let\s+([A-Za-z_][A-Za-z0-9_]*)\s*:/
).flatten
expected_values = %w[
  capture read inputId idempotencyKey auditCampId initialCampId sourceType
  connectorId authorId capturedAt inlineText payloadRef contentHash
  candidateCampIds explicitIntent privacyLevel parentInputId causationId
]
abort("Capture package value surface differs") unless
  package_values == expected_values
abort("Capture block has extra package API kind") if
  source.match?(/^\s*package\s+(?:static\s+)?(?:var|subscript|typealias)\b/)
actor_properties = source.scan(/^\s*private\s+let\s+([A-Za-z_][A-Za-z0-9_]*)\s*:/).flatten
abort("Capture actor stored-property surface differs") unless
  actor_properties == %w[reporter capturePorts localCaptureIdentity]
abort("Capture block exposes public API") if source.match?(/^\s*public\b/)
File.binwrite(extracted_path, block)
puts "source.controller_strip_to_preimage=pass"
puts "source.local_capture_workflow_surface=pass"
RUBY
assert_swift_top_level \
    "$controller_block" \
    local-capture \
    'struct:InputCapturePorts|struct:LocalInputCaptureRequestV1|class-actor:InputCaptureWorkflowController'

store=Sources/AgentLoopCore/Database/DurableWorkStore.swift
adoption_block="$gate_tmp/expired-control-work-adoption.swift"
ruby - "$store" "$adoption_block" <<'RUBY'
require "digest"

path, extracted_path = ARGV
bytes = File.binread(path)
begin_marker = "// P1-C-BEGIN ExpiredControlWorkAdoption"
end_marker = "// P1-C-END ExpiredControlWorkAdoption"
abort("Adoption begin marker count is not one") unless
  bytes.scan(begin_marker).length == 1
abort("Adoption end marker count is not one") unless
  bytes.scan(end_marker).length == 1
start = bytes.index(begin_marker)
abort("Adoption begin marker missing") unless start
block = bytes.byteslice(start, bytes.bytesize - start)
abort("Adoption block is not final or lacks final newline") unless
  block.end_with?(end_marker + "\n")
prefix = bytes.byteslice(0, start)
expected = "3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa"
abort("Store preimage drift outside adoption block") unless
  Digest::SHA256.hexdigest(prefix) == expected
source = block.dup.force_encoding(Encoding::UTF_8)
abort("Adoption block is not UTF-8") unless source.valid_encoding?
abort("DurableWorkStore extension count is not one") unless
  source.scan(/^extension DurableWorkStore\b/).length == 1
declarations = source.scan(
  /^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:final\s+)?(actor|class|struct|enum|protocol|extension|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)/
)
abort("Adoption type declaration surface differs") unless
  declarations == [["extension", "DurableWorkStore"]]
functions = source.scan(
  /^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)/
).flatten
abort("Adoption function surface differs") unless
  functions == ["adoptExpiredControlWork"]
package_api = source.scan(
  /^\s*(?:public|package)\s+(?:static\s+)?(func|init|subscript|let|var|typealias)\s*([A-Za-z_][A-Za-z0-9_]*)?/
)
abort("Adoption package API surface differs") unless
  package_api == [["func", "adoptExpiredControlWork"]]
abort("Adoption block changes generic adopter") if
  source.match?(/\badoptInterrupted\b/)
File.binwrite(extracted_path, block)
puts "source.store_strip_to_preimage=pass"
puts "source.expired_control_adoption_block=pass"
RUBY
assert_swift_top_level \
    "$adoption_block" \
    expired-control-adoption \
    'extension:DurableWorkStore'

supervisor=Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
coach_block="$gate_tmp/coach-turn-processor.swift"
ruby - "$supervisor" "$coach_block" <<'RUBY'
require "digest"

path, extracted_path = ARGV
bytes = File.binread(path)
begin_marker = "// P1-C-BEGIN CoachTurnProcessor"
end_marker = "// P1-C-END CoachTurnProcessor"
abort("Coach begin marker count is not one") unless
  bytes.scan(begin_marker).length == 1
abort("Coach end marker count is not one") unless
  bytes.scan(end_marker).length == 1
start = bytes.index(begin_marker)
abort("Coach begin marker missing") unless start
block = bytes.byteslice(start, bytes.bytesize - start)
abort("Coach block is not final or lacks final newline") unless
  block.end_with?(end_marker + "\n")
prefix = bytes.byteslice(0, start)
expected = "decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095"
abort("Supervisor preimage drift outside Coach block") unless
  Digest::SHA256.hexdigest(prefix) == expected
source = block.dup.force_encoding(Encoding::UTF_8)
abort("Coach block is not UTF-8") unless source.valid_encoding?
abort("CoachTurnProcessor declaration count is not one") unless
  source.scan(/^package struct CoachTurnProcessor: Sendable \{/).length == 1
declarations = source.scan(
  /^\s*(?:(?:public|package|internal|fileprivate|private)\s+)?(?:final\s+)?(actor|class|struct|enum|protocol|extension|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)/
)
abort("Coach type declaration surface differs") unless
  declarations == [["struct", "CoachTurnProcessor"]]
package_funcs = source.scan(
  /^\s*package\s+(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)/
).flatten
abort("Coach package function surface differs") unless
  package_funcs == %w[recoverInterrupted runNext]
abort("Coach package initializer count differs") unless
  source.scan(/^\s*package\s+init\s*\(/).length == 1
abort("Coach block exposes public API") if source.match?(/^\s*public\b/)
abort("Coach block has extra package API") if
  source.match?(/^\s*package\s+(?:static\s+)?(?:let|var|subscript|typealias)\b/)
abort("Coach structured task-group count is not one") unless
  source.scan(/\bwithThrowingTaskGroup\b/).length == 1
abort("Coach worker envelope factory use count is not one") unless
  source.scan(/\bControlWorkerCommandEnvelopeFactoryV1\b/).length == 1
abort("Coach block contains detached Task") if source.match?(/\bTask\.detached\b/)
abort("Coach block contains unstructured Task") if source.match?(/\bTask\s*\{/)
File.binwrite(extracted_path, block)
puts "source.supervisor_strip_to_preimage=pass"
puts "source.coach_turn_processor_block=pass"
RUBY
assert_swift_top_level \
    "$coach_block" \
    coach-turn-processor \
    'struct:CoachTurnProcessor'

new_nodes=(
    Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
    Sources/AgentLoopCore/Domain/CommandEnvelope.swift
    Sources/AgentLoopCore/Domain/DomainEvent.swift
    Sources/AgentLoopCore/Domain/InputEnvelope.swift
    Sources/AgentLoopCore/Domain/GoalController.swift
    Sources/AgentLoopCore/Domain/CoachContracts.swift
    Sources/AgentLoopCore/Domain/UnderstandingCard.swift
    Sources/AgentLoopCore/Database/DomainEventStore.swift
    Sources/AgentLoopCore/Database/InputGoalStore.swift
    Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift
    Sources/AgentLoopCore/Work/InputParsingWorker.swift
    Sources/AgentLoopApplication/LocalCaptureIdentity.swift
    Sources/AgentLoopTestSuite/DomainEventContractTests.swift
    Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
    Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
    Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
)
for path in "${new_nodes[@]}"; do
    test -f "$path" && test ! -L "$path" \
        || fail "new path is absent/nonregular/symlink: $path"
done
printf 'source.new_nodes_regular=%s\n' "${#new_nodes[@]}"

new_product=(
    Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
    Sources/AgentLoopCore/Domain/CommandEnvelope.swift
    Sources/AgentLoopCore/Domain/DomainEvent.swift
    Sources/AgentLoopCore/Domain/InputEnvelope.swift
    Sources/AgentLoopCore/Domain/GoalController.swift
    Sources/AgentLoopCore/Domain/CoachContracts.swift
    Sources/AgentLoopCore/Domain/UnderstandingCard.swift
    Sources/AgentLoopCore/Database/DomainEventStore.swift
    Sources/AgentLoopCore/Database/InputGoalStore.swift
    Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift
    Sources/AgentLoopCore/Work/InputParsingWorker.swift
    Sources/AgentLoopApplication/LocalCaptureIdentity.swift
)
all_p1c_product=(
    Sources/AgentLoopCore/Database/AppDatabase.swift
    Sources/AgentLoopCore/Database/EventKind.swift
    "${new_product[@]}"
    Sources/AgentLoopApplication/InputWorkflowController.swift
)
p1c_blocks=(
    "$app_sanitized"
    "$event_block"
    "$controller_block"
    "$adoption_block"
    "$coach_block"
)
p1d_product=("${new_product[@]}" "${p1c_blocks[@]}")

assert_rg_absent '^import[[:space:]]+SwiftUI$' "${all_p1c_product[@]}" "${p1c_blocks[@]}"
assert_rg_absent 'JSONEncoder|JSONSerialization|\btry\?|fatalError|campId[[:space:]]*\?\?|ensureDefaultCamp|accountId|accountIdentifier' "${new_product[@]}" "${p1c_blocks[@]}"
assert_rg_absent '^import[[:space:]]+CryptoKit$|\bSHA256\b' "${new_product[@]}" "${p1c_blocks[@]}"
assert_rg_present 'CanonicalJSONV1\.encode' Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
assert_rg_present 'CanonicalJSONV1\.validateCanonical' Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
assert_rg_present 'CanonicalJSONV1\.sha256Hex' Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift
assert_rg_absent '(^|[^[:alnum:]_])Task\.detached|(^|[^[:alnum:]_])Task[[:space:]]*\{' Sources/AgentLoopCore/Work/InputParsingWorker.swift "${p1c_blocks[@]}"
assert_rg_count '^internal actor LatestControlWorkClaim\b' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '^package struct InputParsingWorker: Sendable\b' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '^package enum P1CommandAuthorizationV1\b' Sources/AgentLoopCore/Domain/CommandEnvelope.swift 1
assert_rg_count '^package enum InputParseRouteV1\b' Sources/AgentLoopCore/Domain/InputEnvelope.swift 1
assert_rg_count '^package struct InputParseResultV1\b' Sources/AgentLoopCore/Domain/InputEnvelope.swift 1
assert_rg_count '^package enum InputParseFailureTerminalDispositionV1\b' Sources/AgentLoopCore/Domain/InputEnvelope.swift 1
assert_rg_count '^package typealias InputCaptureReceiptV1 = CampSafeCommandResultV1$' Sources/AgentLoopCore/Domain/InputEnvelope.swift 1
assert_rg_count '^package enum ControlWorkerLeasePolicyV1\b' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '^    package static let leaseDuration: TimeInterval = 60$' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '^    package static let renewalInterval: TimeInterval = 15$' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '"input_parser_invalid_output"' Sources/AgentLoopCore/Work/InputParsingWorker.swift 1
assert_rg_count '"coach_provider_invalid_output"' "$coach_block" 1

ruby - "${p1d_product[@]}" <<'RUBY'
paths = ARGV
verbs = %w[
  start launch run execute begin activate pause resume achieve kickoff
  commence update transition set change move advance
]
goal_forward_lines = [
  /^case (active|paused|achieved)$/,
  /^(?:public|package) var currentOutcomeContract(Id|Version): (String|Int)\?$/,
  /^currentOutcomeContract(Id|Version): (String|Int)\?,$/,
  /^currentOutcomeContract(Id|Version): nil,$/,
  /^self\.currentOutcomeContract(Id|Version) = currentOutcomeContract(Id|Version)$/,
]
readonly_outcome_lines = [
  /^(?:guard |if )?.*currentOutcomeContract(Id|Version)\s*(?:==|!=)\s*nil.*$/,
  /^.*currentOutcomeContract(Id|Version): nil,?$/,
]

paths.each do |path|
  source = File.read(path)
  goal_file = path.end_with?("/GoalController.swift")

  if goal_file
    exact_forward = {
      /^\s*case active\s*$/ => 1,
      /^\s*case paused\s*$/ => 1,
      /^\s*case achieved\s*$/ => 1,
      /^\s*(?:public|package) var currentOutcomeContractId: String\?\s*$/ => 1,
      /^\s*(?:public|package) var currentOutcomeContractVersion: Int\?\s*$/ => 1,
      /^\s*currentOutcomeContractId: String\?,\s*$/ => 1,
      /^\s*currentOutcomeContractVersion: Int\?,\s*$/ => 1,
      /^\s*self\.currentOutcomeContractId = currentOutcomeContractId\s*$/ => 1,
      /^\s*self\.currentOutcomeContractVersion = currentOutcomeContractVersion\s*$/ => 1,
    }
    exact_forward.each do |pattern, expected|
      actual = source.each_line.count { |line| pattern.match?(line) }
      abort("Goal forward carrier count #{pattern.inspect}: #{actual}") unless
        actual == expected
    end
    lines = source.lines
    status_start = lines.index { |line|
      line.match?(/^\s*(?:public|package) enum GoalControllerStatusV1\b/)
    }
    abort("GoalControllerStatusV1 declaration missing") unless status_start
    depth = 0
    opened = false
    status_finish = nil
    lines.each_with_index do |line, index|
      next if index < status_start
      depth += line.count("{")
      opened ||= line.include?("{")
      depth -= line.count("}")
      if opened && depth == 0
        status_finish = index
        break
      end
    end
    abort("GoalControllerStatusV1 declaration unterminated") unless status_finish
    %w[active paused achieved].each do |name|
      positions = lines.each_index.select { |index|
        lines[index].match?(/^\s*case #{name}\s*$/)
      }
      abort("Goal forward case is outside status enum: #{name}") unless
        positions == [positions.fetch(0)] &&
          positions[0].between?(status_start, status_finish)
    end
  end

  source.each_line.with_index(1) do |line, number|
    stripped = line.strip

    if (match = line.match(/^\s*(?:public|package)\s+(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)/))
      name = match[1]
      lowered = name.downcase
      goalish = lowered.include?("goal")
      forbidden_name = verbs.include?(lowered) ||
        (goalish && verbs.any? { |verb|
          lowered.start_with?(verb) || lowered.end_with?(verb) ||
            lowered.include?("#{verb}goal") || lowered.include?("goal#{verb}")
        })
      abort("forbidden P1-D API #{path}:#{number}:#{line}") if forbidden_name
    end

    if line.match?(/\bOutcomeContract(?:V[0-9]+)?\b/)
      abort("forbidden OutcomeContract type #{path}:#{number}:#{line}")
    end

    if line.include?("currentOutcomeContract")
      allowed = (goal_file && goal_forward_lines.any? { |rule| rule.match?(stripped) }) ||
        readonly_outcome_lines.any? { |rule| rule.match?(stripped) }
      abort("forbidden Outcome reference write/API #{path}:#{number}:#{line}") unless allowed
    end

    if goal_file && line.match?(/\b(active|paused|achieved)\b/)
      allowed = goal_forward_lines.any? { |rule| rule.match?(stripped) }
      abort("forbidden Goal forward-case use #{path}:#{number}:#{line}") unless allowed
    end

    if line.match?(/GoalControllerStatusV1\.(active|paused|achieved)/) ||
        line.match?(/\b(?:goal[A-Za-z0-9_]*\.)?status\s*(?:=|:)\s*\.(active|paused|achieved)\b/i)
      abort("forbidden P1-D Goal transition #{path}:#{number}:#{line}")
    end

    if !goal_file && line.match?(/:\s*GoalControllerStatusV1\b/)
      abort("forbidden generic Goal status input #{path}:#{number}:#{line}")
    end

    if line.match?(/\b[A-Za-z0-9_]*[Gg]oal[A-Za-z0-9_]*\.status\s*=\s*(?!\.(?:clarifying|ready|abandoned|failed)\b)/)
      abort("forbidden nonclosed Goal status assignment #{path}:#{number}:#{line}")
    end
  end

  normalized = source.gsub(/\s+/, " ")
  normalized.scan(/(?:UPDATE|INSERT\s+INTO)\s+goal_controller\b.*?(?:;|\"\"\")/i) do |sql|
    update_status = sql.match?(/\AUPDATE\s+goal_controller\b.*\bSET\b.*\bstatus\b/i)
    outcome_write = sql.match?(/currentOutcomeContract(Id|Version)/i)
    if update_status || outcome_write
      abort("forbidden raw Goal status/outcome SQL in #{path}: #{sql[0, 240]}")
    end
  end
end
puts "source.p1d_delta_fence=pass"
RUBY

assert_rg_absent 'import[[:space:]]+GRDB|pool\.write|writeWithoutTransaction|db\.execute|\.insert\([^)]*db|\.update\([^)]*db' "$controller_block"
printf 'source.controller_no_direct_grdb_write=pass\n'

assert_rg_count 'm\.registerMigration\("v13-p1-observability"\)' Sources/AgentLoopCore/Database/AppDatabase.swift 1
assert_rg_count 'm\.registerMigration\("v14-p1-control-contracts"\)' Sources/AgentLoopCore/Database/AppDatabase.swift 1
v13_line="$(rg -n 'm\.registerMigration\("v13-p1-observability"\)' Sources/AgentLoopCore/Database/AppDatabase.swift | cut -d: -f1)"
v14_line="$(rg -n 'm\.registerMigration\("v14-p1-control-contracts"\)' Sources/AgentLoopCore/Database/AppDatabase.swift | cut -d: -f1)"
test "$v14_line" -gt "$v13_line" || fail "v14 is not after v13"
test "$(rg -n 'm\.registerMigration\(' Sources/AgentLoopCore/Database/AppDatabase.swift | tail -1 | cut -d: -f1)" = "$v14_line" \
    || fail "v14 is not final migration"
for trigger in \
    domain_command_receipt_reject_update \
    domain_command_receipt_reject_delete \
    domain_event_reject_update \
    domain_event_reject_delete
do
    assert_rg_count "CREATE TRIGGER $trigger" Sources/AgentLoopCore/Database/AppDatabase.swift 1
done
printf 'source.v14_order_and_triggers=pass\n'

test_specs=(
controlContractMigrationExactDDLAndConstraints:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
controlContractMigrationReplaysFromFreshAndV11Twice:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
controlContractMigrationRollbackLeavesV13Untouched:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
controlContractAppendOnlyTablesRejectNoopUpdateAndDelete:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
controlContractSchemaHasExactInboxRedactionShape:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
inputSchemaHasNoParseAttemptColumn:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
inputSchemaRejectsDeletedStatusWithActiveRetention:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
activeInputRequiresExactlyOneInlineOrPayloadRef:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
inputSchemaRejectsTombstoneRetentionWithLiveStatus:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
persistedControlContractConstantsAndWorkKeyDerivationsAreExact:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
workerCommandEnvelopeFactoriesAreExactAttemptScopedAndReplayStable:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
preparedCommandIsPreReceiptAuthorityAndNewResultIsPostMutationOnly:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
commandEnvelopeWholeHashCoversEveryFieldAndNullability:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
canonicalContractCodingReusesCanonicalJSONV1GoldenBytes:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
campSafeJSONRejectsUnknownForbiddenIdentityAndNoncanonicalBytes:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
campSafeJSONRejectsSemanticallyForbiddenReferenceValues:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
everyCommandResultAndAuditShapeIsExactAndOrdered:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
executeCommandCommitsReceiptProjectionEventsAndOutboxAtomically:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
executeCommandReplayReturnsOldResultWithoutMutation:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
creationReplayUsesPersistedResultBeforeIDFactoryOrProjectionBranch:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
replayValidatesCompleteStoredEventAndOutboxGraph:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
executeCommandRejectsTypeHashOrEventCountDriftTotally:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
multiAggregateCommandUsesStableOrdinalsAndVersionChains:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
eventCountOrdinalOrProjectionFailureRollsBackEverything:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
domainEventCopiesEnvelopeAndOwnsRecordedAt:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
domainEventRejectsMissingCampBadTimeAndVersionPreSQL:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
outboxClaimReleaseSentCASAndReplayAreDeterministic:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxApplyReplayConflictAndTypedRejectionAreDurable:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxTypedRejectionRollsBackHandlerSavepointBeforeDurableEvidence:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxSameKeyAndStoredHashButDifferentBytesFailsClosedWithoutHandler:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxConflictCASPersistsExactRejectedShapeAndThrowsAfterCommit:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxConflictAgainstRedactedRowIsTerminalWithoutCASOrHandler:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
inboxRedactedTombstonesPreservePriorHashAndAppliedTimeAcrossOrigins:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
domainEventsReadInValidatedAggregateOrder:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
captureAndInputParsingWorkCommitAtomically:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputCaptureReplayAndPayloadDriftConflict:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputCaptureReplayUsesCallerOwnedIDAndExistingWorkResult:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingCrashIsAdopted:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
controlWorkAdoptionRequiresExpiredLeaseAndRecoversSameOwnerAcrossKinds:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingRenewalHandsLatestClaimToTerminalCommit:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingTerminalTimeIsMonotonicAndRetryBackoffStartsAtFailure:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingRenewalFailureCancelsParserWithoutProjectionCommit:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingRetriesBoundedlyThenParseFailed:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingCancelRejectsStaleResult:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
cancelParsingAndDeleteRejectsNoActiveBranchBeforeMutation:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingTerminalMutationRollbackIsTotal:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputTransitionMatrixAcceptsOnlyStageSpecEdges:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
ordinaryInputTransitionsRejectEveryActiveParsingStateWithoutWrites:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
everyInputCommandEnforcesExactActorAndDeviceMatrixBeforeSQL:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParserInterfaceUsesOnePersistedPreAwaitSnapshotAndClosedOutcome:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParserInvalidOutputFailsDeterministicallyExactlyOnce:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
crossCampAmbiguityNeverSelectsDefaultCamp:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputCampScopeIsStableFromCaptureThroughAssignment:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputRejectsInitialOrAssignedCampDifferentFromAuditCamp:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputParsingWorkAlwaysUsesAuditCampAndArchivedCampFailsClosed:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputTombstoneRetainsOnlyExactIdentityHashAndTimes:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputTombstoneNullsDeviceConnectorAuthorBodyRefErrorAndParent:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
inputTombstoneForcesEmptyCandidatesUnspecifiedIntentLocalOnlyAndEqualDeleteTime:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCaptureIdentityPersistsOnceAndFailsOnCorruption:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCaptureIdentityConcurrentFirstUseAcrossCopiesIsAtomic:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCaptureIdentityConcurrentFirstUseAcrossIndependentAdaptersIsAtomic:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCaptureUsesLocalOwnerAndInstallationDeviceWithoutAccountIdentity:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCapturePortAndInitializerRemainSourceCompatible:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
localCaptureTraceCorrelationAndRequestIDsAreExact:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
loadInputUsesReadPortAndMapsMissingRecordToFailure:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
legacyIngestionAdapterIsDisplayOnlyAndCreatesNoInputOrGoal:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
nilInputCampNeverInfersAuthority:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
crossCampAmbiguityBlocksGoalCreationWithoutWrites:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
convertToGoalCommitsInputGoalEventsAndOutboxesAtomically:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
convertToGoalReplayUsesCallerOwnedGoalIDAfterProjectionAdvances:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
goalP1CTransitionsOnlyClarifyingReadyAbandonedAndFailed:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
openCoachSessionEnqueuesDurableCoachWorkAtomically:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
openCoachReplayUsesCallerOwnedSessionAndQuestionIDs:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
oneCoachSessionPerGoalControlsConcurrentOpenResumeAndTerminalBranches:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachSessionAllowsExactlyOneOpenQuestion:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachQuestionAndAnswerEnforceCoachAndUserActors:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
everyGoalCoachCommandEnforcesExactActorAndDeviceMatrixBeforeSQL:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachSealedDecisionKeyNeverComesFromProvider:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachProviderInterfaceOrdersPersistedHistoryBeforeAwait:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachProviderInvalidOutputFailsDeterministicallyExactlyOnce:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachAnswerEnqueuesNextDurableTurnAtomically:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachAnswerReplayDoesNotEnqueueSecondTurn:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachProposalReplayUsesGoalIDAsUnderstandingID:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachFailureRetriesAtomicallyAndKeepsSessionInterviewing:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachFailureExhaustionFailsSessionAndGoalAtomically:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachReopenedTerminalFailuresAndReplayPreserveReadyGoalAndConfirmedHead:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
readyRevisionWorkSealsAndValidatesJoinedConfirmedUnderstandingHash:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachWorkerRestartAdoptsInterruptedTurn:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachRenewalHandsLatestClaimToTerminalCommit:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachTerminalTimeIsMonotonicAfterRenewalAndBackoffStartsAtFailure:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachWorkerCancellationLeavesRecoverableRunningWork:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachTerminalMutationRollbackRestoresWorkSessionGoal:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
understandingEditAlwaysCreatesNewVersion:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
requestConfirmationDoesNotRewriteUnderstandingBody:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
requestUnderstandingRevisionWithdrawsOrReopensAndEnqueuesTurn:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachCannotConfirmUnderstanding:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
confirmUnderstandingSupersedesPriorVersionAndMakesGoalReady:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
coachRestartRestoresExactlyOneOpenQuestionWithoutChatMemory:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
goalAbandonAndFailCancelActiveControlWorkAtomically:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
goalAbandonReplayUsesSealedSessionBranchAfterProjectionChanges:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
goalFailReplayUsesSealedSessionBranchAfterProjectionChanges:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
goalReadyDoesNotRequireV15Schema:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
)
test "${#test_specs[@]}" = 102 || fail "test inventory is not 102"

suite_specs=(
P1CControlContractMigrationTests:Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift
P1CDomainEventContractTests:Sources/AgentLoopTestSuite/DomainEventContractTests.swift
P1CInputEnvelopeContractTests:Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift
P1CGoalCoachContractTests:Sources/AgentLoopTestSuite/GoalCoachContractTests.swift
)
for spec in "${suite_specs[@]}"; do
    suite="${spec%%:*}"
    path="${spec#*:}"
    assert_rg_count "^[[:space:]]*struct[[:space:]]+${suite}\\b" "$path" 1
done

expected_specs="$gate_tmp/expected-test-specs.txt"
declared_specs="$gate_tmp/declared-test-specs.txt"
expected_names="$gate_tmp/expected-test-names.txt"
declared_names="$gate_tmp/declared-test-names.txt"
printf '%s\n' "${test_specs[@]}" | LC_ALL=C sort >"$expected_specs"
printf '%s\n' "${test_specs[@]}" \
    | sed 's/:.*//' | LC_ALL=C sort >"$expected_names"
test "$(uniq "$expected_names" | wc -l | tr -d ' ')" = 102 \
    || fail "expected P1-C test names are not unique"

ruby - "${suite_specs[@]}" >"$declared_specs" <<'RUBY'
specs = ARGV.map { |spec| spec.split(":", 2) }
specs.each do |suite, path|
  text = File.read(path)
  abort("missing @Suite for #{suite}") unless
    text.match?(/@Suite(?:\([^\n]*\))?\s*\n\s*struct\s+#{Regexp.escape(suite)}\b/)
  text.each_line do |line|
    match = line.match(/^\s*@Test\s+func\s+([A-Za-z_][A-Za-z0-9_]*)\(/)
    puts "#{match[1]}:#{path}" if match
  end
end
RUBY
LC_ALL=C sort -o "$declared_specs" "$declared_specs"
cut -d: -f1 "$declared_specs" | LC_ALL=C sort >"$declared_names"
cmp -s "$expected_specs" "$declared_specs" \
    || fail "P1-C declaration set differs from exact manifest"
cmp -s "$expected_names" "$declared_names" \
    || fail "P1-C declaration names differ from exact manifest"
printf 'source.test_declarations=102_exact\n'

discovery="$gate_tmp/test-discovery.log"
NO_COLOR=1 swift run RunTests --list-tests 2>&1 | tee "$discovery"
discovered_names="$gate_tmp/discovered-p1c-test-names.txt"
P1C_SUITES="$(printf '%s\n' "${suite_specs[@]}" | sed 's/:.*//' | paste -sd: -)" \
    ruby - "$discovery" >"$discovered_names" <<'RUBY'
suites = ENV.fetch("P1C_SUITES").split(":")
File.foreach(ARGV.fetch(0)) do |line|
  next unless suites.any? { |suite| line.include?(suite) }
  match = line.match(/(?:^|[.\/])([A-Za-z_][A-Za-z0-9_]*)(?:\(\))?\s*$/)
  abort("unparseable P1-C discovery line: #{line}") unless match
  puts match[1]
end
RUBY
LC_ALL=C sort -o "$discovered_names" "$discovered_names"
cmp -s "$expected_names" "$discovered_names" \
    || fail "P1-C discovered set differs from exact manifest"
test "$(wc -l < "$discovered_names" | tr -d ' ')" = 102 \
    || fail "P1-C discovery count is not 102"
printf 'source.test_discovery=102_exact\n'

git diff --check
printf 'source.git_diff_check=pass\n'
printf 'source.result=pass\n'
```

The migration matrix must show both real GRDB lanes linked to the requested
SQLite runtime, all nine predecessor fixtures, literal v14, replay/FK/
integrity/DDL/append-only/rollback sentinels, and `matrix.result=pass` for each
lane. A partial lane, skipped fixture, `NULL/UNKNOWN`, or only-count proof is a
failure.

No preview execution is required or authorized because the Revision 6 change
only repairs a preview fixture's accepted constructor shape and performs no
external action. The App build is the application boundary proof for this leaf.

## 12. Implementation report, disclosed review, and acceptance

`impl-report.md` must include:

- exact changed/created paths and pre/post hashes;
- red-to-green evidence by batch and why each red was the intended capability;
- migration identifiers, object counts, matrix lane/fixture results;
- focused/full test counts and duration;
- App build result;
- source/outside-manifest results;
- expired-only control adoption, monotonic terminal/backoff, all-command actor
  matrix, provider-snapshot, inbox-savepoint, one-session, joined-head, and
  independent-adapter race results;
- confirmation that active/OutcomeContract/P1-D remained absent;
- deviations (expected none); and
- prohibited actions not performed.

Under the user's direct no-Claude/no-delegation override, the implementation
owner performs a separate read-only self-review pass and writes only
`reviews/02-p1-c-implementation-review.md`. It must inspect the
approved plan, complete diff, all evidence logs, v14 literal vs stage §18.4,
state/CAS/idempotency/atomicity/error paths, dirty-worktree preservation, and
recompute every protected hash/manifest before and after its artifact. The
artifact must disclose that it is not independent. Any P0/P1 returns
implementation to the exact failing TDD batch; no acceptance.

After Review02 is `APPROVED — 0 P0 / 0 P1`, a separate read-only acceptance
pass writes only `acceptance.md` and again discloses the user-directed process
override. Acceptance requires:

- Review01H and Review02 zero P0/P1, with approved Review01E/Review01F/Review01G and rejected
  Review01/Review01A/Review01B/Review01C/Review01D preserved;
- all four red/green chains intact;
- empty/v11 and full predecessor v14 replay green;
- Input parsing adoption/retry/cancel/rollback green with no `parsing`
  projection;
- same-owner expired recovery and foreign live-lease protection green for both
  control kinds, with terminal time/backoff monotonic after renewal;
- cross-Camp ambiguity does not assign or create Goal;
- Goal reaches ready with confirmed Understanding and no v15 dependency;
- every command actor/device row rejects before SQL when wrong;
- typed inbox rejection rolls back all handler writes but persists rejection;
- coach restart restores exactly one open question from the sole Goal session,
  provider histories are persisted/ordered, and ready hash joins are sealed;
- independent live-equivalent identity adapters converge atomically;
- authoritative full tests and App build green;
- outside worktree unchanged and no unexplained deviation; and
- Open Questions empty.

Only an accepted artifact may open P1-D planning. It does not authorize P1-D
implementation, commit, push, merge, release, data mutation, App launch, or
external action.

## 13. Completion gate

P1-C is complete only when all of the following are true:

1. this exact plan has a disclosed Review01H approval at zero P0/P1 under the
   user's no-Claude/no-delegation override;
2. every named red test failed first for its intended missing capability;
3. all §8–§11 and §18.4 contract tests pass;
4. v14 replays from fresh and every required predecessor in both SQLite lanes;
5. receipt/projection/event/outbox and work/projection terminal mutations are
   transactionally total;
6. replay, CAS, all-command actor permission, safe JSON, inbox/outbox/savepoint,
   tombstone, expired-lease restart, provider snapshot, one-session,
   joined-Understanding, terminal-time, and identity-race contracts pass;
7. Goal reaches ready only, and active/OutcomeContract remains P1-D;
8. `swift build --product AgentLoopApp` exits zero;
9. final unfiltered `swift run RunTests` exits zero;
10. Review02 and the disclosed acceptance pass have zero P0/P1;
11. frozen inputs/outside manifest have no drift; and
12. no unknown failure, open question, hidden fallback, scope expansion, or
    prohibited action remains.

Once this gate is reached, stop auditing P1-C and advance only to P1-D formal
planning.

## 14. Review finding-resolution matrices

### 14.1 Review01

| Finding | Frozen resolution |
|---|---|
| P1-01 creation/replay/vocabulary | §§5.3–5.5 fix every persisted string, command field, result/audit member/order, caller/deterministic/store ID owner, event head, and work key; §6 performs receipt-first replay and validates the complete result-derived event/outbox graph before any mutable branch or factory. |
| P1-02 durable lifecycle ownership | §§5.4 and 7.3 define actor-isolated latest-claim handoff, renewal shutdown, monotonic terminal time, and a marker-confined expired-control adoption method that includes same-owner expiry while protecting live leases; §8.2 adds the sole Coach processor plus atomic retry/terminal failure and restart/cancel/rollback evidence. |
| P1-03 audit/projection Camp | §7.1 makes capture Camp the sole P1-C authorization scope, fixes work/event ownership, requires equal initial/assigned Camp, rejects archive/mismatch, and adds negative tests. |
| P1-04 safe JSON/inbox | §5.1 closes every safe kind/value grammar and explicit-null/date decoding; §6 requires canonical byte plus recomputed-hash equality, a no-mutation redacted terminal, the exact non-redacted conflict CAS/commit/throw shape, and a rollback savepoint around mutation-capable typed-rejection handlers. |
| P1-05 Application seam | §9 freezes the identity-store protocol, process-shared production lock, separate ports, request DTO, defaulted initializer, controller signatures, trace mapping, result mapping, and read behavior. |
| P1-06 reproducible gates | §11 embeds the full binary serializer and executable fail-fast hash/source/Outcome/controller/migration/exact-102-test declaration-and-discovery gates. |

### 14.2 Review01A

| Finding | Frozen resolution |
|---|---|
| 01A-P1-01 persisted/replay inconsistency | §5.4 seals every command field and the separate Understanding event head; §5.5 freezes every result/audit array and value source; §6 puts Camp-state checks only on the receipt-absent branch and gives outbox exactly the event ID with no second factory. |
| 01A-P1-02 redacted inbox CHECK contradiction | §6 classifies a valid `camp_deleted` tombstone before replay comparison and returns `DomainInboxRedactedError` with zero mutation; only non-redacted rows may enter the `inbox_payload_conflict` CAS, and C2 names the redacted conflict test. |
| 01A-P1-03 C2 factory / exact test set | §5.4 authorizes only pure real typed store factories during C2. §10/§11 use four named suites and compare the exact 102-entry manifest against every declaration and every discovered P1-C suite test, rejecting extras as well as omissions. |
| 01A-P1-04 unreachable Understanding revision | §§5.3–5.5 and §8 add the user-only sealed revision command, draft/awaiting withdrawal or confirmed reopen branches, exact CAS/event/work behavior, event-head propagation, and tests that reach a new content version and later supersede the old confirmed version without `ready -> clarifying`. |

### 14.3 Review01B

| Finding | Frozen resolution |
|---|---|
| 01B-P1-01 production allowlist | §§3.1, 8.2, and 11.2 place the sole `CoachTurnProcessor` in one final marker-delimited block of canonical-allowlisted `DurableWorkSupervisor.swift`; the executable gate strips that block and requires the frozen pre-image hash exactly. No `CoachTurnWorker.swift` exists. |
| 01B-P1-02 worker envelopes | §§5.3–5.4 and 7.3 freeze one typed factory, complete work/attempt/claim validation, attempt-key grammar, actor/device/correlation/causation sources, stable start identity, separate terminal clock, renewal stability, lease-expired adoption, divergent-outcome conflict, and replay tests. |
| 01B-P1-03 decision key | §§5.3, 5.4, and 8.2 derive and validate `decision:v1:<nextQuestionId>` in sealed coach work input; the provider result cannot carry or replace it, and C4 has a named authority test. |
| 01B-P1-04 impossible Input result | §§5.4, 5.5, and 7.2 make cancel-and-delete `.expected`-only, complete deletion `.none`-only, remove the impossible expected-completion row, and replace the undefined shorthand with both exact withdrawal branches. |
| 01B-P1-05 redacted inbox | §6 validates the v16-compatible tombstone with preserved pre-redaction hash and preserved nil/non-nil applied time; C2 covers received/applied/rejected origins without reconstructing erased bytes. |
| 01B-P1-06 stranded parsing work | §§5.4 and 7.2 require `.none` plus transactional absence of queued/running/retryScheduled parsing work for every ordinary transition; C3 exercises the complete transition/state zero-write matrix. |
| 01B-P1-07 reopened Coach failure | §§5.3–5.5 and 8.2 seal failure scope, optional joined confirmed Understanding head, and all four retry/terminal branches. A ready-revision terminal failure emits Session only and preserves the ready Goal ID/version plus joined row hash; `reopenConfirmed` retries from confirmed or failed, with exact replay coverage. |
| 01B-P1-08 installation-ID atomicity | §9 replaces split get/set with one atomic get-or-create protocol operation; one static production lock covers the fixed key across independent adapters, the test store covers copy sharing, corruption never rewrites, and both races are tested. |

### 14.4 Review01C

| Finding | Frozen resolution |
|---|---|
| 01C-P1-01 prepared/new contradiction | §§5.2 and 6 make `PreparedDomainCommandV1` pre-receipt authority with no result and `NewDomainCommandV1` the only post-mutation result carrier; C2 proves the initializer/API split. |
| 01C-P1-02 unsafe/incomplete adoption | §§3.1, 7.3, and 11.2 authorize exactly one strip-gated Store extension whose control-only method selects finite expired leases, includes same-owner recovery, and leaves every live lease plus the generic adopter unchanged; C3 covers both kinds and owners. |
| 01C-P1-03 attempt-start terminal time | §§5.4, 7.3, and 8.2 retain `attempt.startedAt` only for envelope identity, read one post-await `terminalNow`, require monotonicity, and base checked retry delay on terminalization; C3/C4 cover long and renewed attempts. |
| 01C-P1-04 actor matrix | §5.4 enumerates all 23 command types across four exact actor/ID/device rows with one pre-SQL validator; C3/C4 exercise every positive and negative combination. |
| 01C-P1-05 multiple Coach sessions | §8.2 fixes one total Session row per Goal, receipt-first replay, serialized concurrent open, no replacement/reopen row, exact zero/one/multiple resume behavior, and session-branch cardinality; C4 covers the entire invariant. |
| 01C-P1-06 worker provider interfaces | §§7.3 and 8.2 freeze exact Sendable failure/request/outcome/sleep/provider types, package initializers, one persisted pre-await snapshot, deterministic history order, cancellation, and the absence of post-await mutable authority; C3/C4 test both boundaries. |
| 01C-P1-07 inbox partial writes | §6 runs the mutation-capable handler inside a savepoint, rolls that savepoint back on typed rejection, and commits only durable rejected evidence in the outer transaction; C2 proves a prior handler write is absent. |
| 01C-P1-08 missing Goal hash carrier | §§5.3–5.5 and 8.2 state that Goal stores only Understanding ID/version, seal the joined row's hash/event head in ready work/failure authority, and include U/UC/UCv/UE in ready retry/terminal results; C4 forges every carrier and requires rollback. |
| 01C-P1-09 per-instance installation lock | §9 uses a process-static lock for the fixed UserDefaults key across independently constructed adapters; C3 races two live-equivalent instances and proves one winner without overwrite. |

### 14.5 Review01D

| Finding | Frozen resolution |
|---|---|
| 01D-P1-01 undefined Input boundaries | §5.4 now freezes `InputParseRouteV1`, exact-key `InputParseResultV1`, `InputParseFailureTerminalDispositionV1.derive`, and the exact `InputCaptureReceiptV1` typealias, including every route invariant, canonical encoding rule, Store revalidation, and failure reducer. §§9–11 freeze the dedicated Application actor, usable request initializer, declaration gates, and positive/negative/replay tests. |
| 01D-P1-02 undefined lease duration | §7.3 makes `ControlWorkerLeasePolicyV1` the sole shared policy at exactly 60-second claim/renew and 15-second cadence, with no initializer override. C3/C4 assert exact initial and renewed expiries plus immediately-before/at-expiry adoption for both work kinds. |
| 01D-P1-03 invalid output recovery loop | §§7.3 and 8.2 map all invalid Input/Coach provider output to exact local deterministic codes and the same latest-claim terminal transaction, never lease recovery. The two added C3/C4 tests prove one terminal attempt, atomic projections/events/outboxes/work, bounded failure, and receipt replay without provider recall. |
| 01D-P1-04 incomplete source/scope fence | §§3.1 and 11.2 authenticate and strip all five existing-product marker blocks, require exact Swift top-level/package API surfaces, compare v14 against the protected §18.4 SQL bytes, and scan new files plus every authenticated delta. The P1-D fence rejects Outcome types/reference writes, forward-state reducers, raw Goal SQL, and alternative activation APIs while allowing only the exact v14 SQL and Goal record forward fields. |

## 15. Open questions

None.
