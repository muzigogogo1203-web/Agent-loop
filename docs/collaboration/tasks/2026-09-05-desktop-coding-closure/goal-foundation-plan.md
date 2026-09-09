# Desktop Goal Foundation — A1 Task Extraction

> Execute this single task with `superpowers:executing-plans`. Parent owns dispatch, runtime entry gate, validation and integration; a responsibilities-separated reviewer reviews the implementation. No commit, Provider, app or real-user data authority is added.

**Authority:** historical approved `goal-flow-plan.md` SHA-256 `a17005f29899478ae2bbca5ce8ecf8334238d19a63423b16e0f1ab2750ce9428`, its scoped approval in `goal-flow-plan-review.md`, this directory's `spec.md`, and the parent's subsequently recorded runner-command erratum in `progress.md`. The [2026-09-06 owner output-policy decision](goal-coach-output-policy-decision.md) authorizes the policy-only revision below; its changed plan/brief bytes require independent scoped review before A1 entry. Earlier approvals/hashes remain history, not approval of this revision. All other A1 decisions and runtime gates remain unchanged.

**Goal:** persist a camp-local goal submission atomically with its original InputEnvelope/parsing work, provide a truthful scoped read model and sealed-stage journal, and redact its carriers in the two existing input tombstone transactions.

**Boundary:** Core persistence only. No driver, worker claim changes, coach/Provider calls, application controller, SwiftUI, contract creation, mission start, verification, approval execution or memory projection. A1 ends with actual `.captured` input and `.queued` parsing work; it must not simulate parser/coach/mission success to make a test or demo look complete. Later tasks consume the persisted foundation.

### Task 1: Persist and read the desktop goal foundation without changing historical contracts

**Owner/dependencies:** parent-designated Core implementer, after the parent's runtime entry gate permits implementation. Coordinate `AppDatabase.swift` edits with the runtime owner; do not change its unrelated process/bootstrap code. No parallel edits to overlapping files. Review this task's diff before A2/A3 use it.

**Exact file allowlist:**

- Create `Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift` — context, typed capture intent, operation/stage/receipt and foundation read contracts.
- Create `Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift` — carrier persistence, atomic capture, scoped reads, sealed-stage CAS, redaction.
- Modify `Sources/AgentLoopCore/Database/AppDatabase.swift` — append `desktop-goal-workflow-v1` migration after the existing V17 registration only.
- Modify `Sources/AgentLoopCore/Database/InputGoalStore.swift` — transaction-taking capture overload and two atomic tombstone redaction hooks; original public command semantics stay intact.
- Create `Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift` and `DesktopGoalMigrationTests.swift`.
- Modify `Sources/AgentLoopTestSuite/OutcomeContractTests.swift` **only** the setup/read receiver in `outcomeContractMigrationRemainsPresentUnderV17Head`, so this literal historical checkpoint actually stops at V17. Preserve its assertions and shared fixture helpers.
- Modify `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` **only** to register/check the exact four-file dated A1 successor set described below; no historical boundary relaxation.
- Update this task directory's implementation evidence/report as directed by the parent. Do not edit the approved main plan, frozen migration SQL/spec files, legacy fixture payloads, test counts or other source files to accommodate the new tables.

**Current API evidence:**

- `AppDatabase.init(path:)` always invokes `Self.migrator.migrate(pool)` to latest; there is no through-migration AppDatabase initializer. `AppDatabase.migrator` is public and GRDB already supports `migrate(queue, upTo: migrationID)`.
- `InputGoalStore.captureAndEnqueueParsing(_ command: CaptureInputCommandV1) throws -> InputCaptureReceiptV1` creates its prepared event command, performs one `database.pool.write`, inserts InputEnvelope and `.inputParsing` durable work, and commits domain event/outbox/receipt in that same write.
- `InputCaptureReceiptV1` is an existing typealias for `CampSafeCommandResultV1`; it is `Codable`, safe and replayable. Do not invent an unsafely serialized input record as the command receipt.
- `CaptureInputCommandV1` is `Encodable`, not `Decodable`, and excludes envelope from its payload coding. `CanonicalContractCodingV1.wholeCommandBytes(envelope:payload:)` / `wholeCommandHash` include the envelope. Seal both; do not assume decoding the existing command type is available.
- `InputGoalStore.cancelParsingAndDelete` uses `DurableWorkStore.cancel(..., businessMutation: { db, _ in try input.update(db) }, in: db)` inside its domain command transaction. Insert carrier redaction into that exact business mutation.
- `InputGoalStore.completeDeletion` calls `executeOrdinary(..., mutation: (inout InputEnvelopeRecord, Database) throws -> Void)`. Its closure currently ignores the Database argument; use it to redact when the same input becomes a tombstone, before the enclosing write commits.
- `requestDeletion` excludes `.goalCreated`. Do not add post-goal deletion or attach these hooks to `IngestionDeletionStore`; that store deletes a different legacy ingestion model.
- `CampLifecycleStore.requireActiveCampWrite(campId:expectedLifecycleVersion:database:)` validates the exact lifecycle version, active state and not archived. `DurableWorkStore.enqueue(...,in:)` already participates in the input capture transaction. No claim or dispatch is needed for A1.

#### Phase-specific contracts to implement

Use existing canonical UUID/camp/hash/time validators and checked increments. All newly persisted JSON uses the existing canonical encoder; decode validates canonical bytes and recomputed hash before exposing payload. Keep user text out of safe failure messages.

1. Implement `DesktopGoalContextV1`, `DesktopCoachRuntimeV1.unconfigured/.selected(profileId:model:)` and `DesktopCoachPolicyV1` with the revised main-plan fields/defaults: fixed input/goal/session UUIDs, optional workspace/bookmark, companion IDs, mission budget/autonomy, original privacy level, remote-consent receipt ID, separate coach policy (8 conservative application-issued generation reservations including retries, 32,768 observed-token stop threshold, 49,152 complete request bytes, `outputPolicy: DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4_096)`, 120-second client dispatch deadline followed by real producer cancellation/join). API requests will carry the protocol output parameter; OAuth output will be provider-managed, without a uniform app-guaranteed token cap. A1 merely persists/validates this configuration; it does not grant consent, resolve the effective output mode, change runtime or account for attempts. Initial remoteConsentReceiptId must be nil because A1 cannot create that receipt. A selected runtime can be stored without resolving it or reading credentials. User submission identity is local-owner plus device UUID.
2. Add a `Codable` `DesktopGoalCaptureIntentV1` containing operationId, campId, expectedCampLifecycleVersion, context, original text and CommandEnvelopeV1. Its initializer trims only outer whitespace once, rejects empty text, seals that normalized text, validates context IDs/budget/selection and verifies the explicit camp. Its `captureCommand() throws -> CaptureInputCommandV1` constructs sourceType `.text`, sourceDeviceId = envelope.deviceId, no connector/author/payloadRef/parent, initialCampId = auditCampId = campId, candidateCampIds `[]`, explicitIntent `.createGoal`, privacyLevel = context.privacyLevel, capturedAt = envelope.occurredAt, contentHash = SHA-256 of exact sealed text UTF-8. Fixed key is `desktop-goal:<operationId>:capture:v1`; envelope key must match. No generated ID or Date occurs during replay.
3. Add typed carrier record contracts: owner kinds userMutation/system/coachAttempt/verificationAttempt; phases prepared/committed/failed/redacted; context retention live/redacted. The migration supports all approved owner strings, but A1 has no methods which pretend to execute future attempts.
4. `DesktopGoalSealedStageV1` contains ordinal, closed supported command type, full canonical command bytes, whole-command hash, full envelope, optional predecessor receipt hash and optional appended `DesktopGoalStageReceiptV1`. For A1, the executable command type is only `.inputCapture`; allow later types through future real task changes rather than a default-success branch. The receipt contains canonical existing `InputCaptureReceiptV1` bytes/hash and safe IDs/versions. A typed capture intent remains available to reconstruct the command; generic JSON does not become executable code. Stage arrays are canonical and immutable by entry; appending a receipt replaces the stored array via CAS without rewriting old entry content.
5. `DesktopGoalOperationSnapshotV1` exposes operation ID/input ID/owner/kind/version/phase/requestHash, live typed intent when allowed, stages and safe receipt. `DesktopGoalCaptureReceiptV1` contains inputId/goalId/sessionId/operationId and the actual InputCaptureReceiptV1. These are persisted identities, not claims that goal/session were created.
6. Add `DesktopGoalFoundationReadV1.live(DesktopGoalFoundationSnapshotV1)` / `.deleted(inputId:goalId:)`. Live foundation snapshot has context/contextVersion, actual InputEnvelopeRecord, optional actual GoalControllerRecord and CoachSessionRecord (only when they exist), actual carrier operation records and owned inputParsing/coach work records. It has no contract/outcome/verification fields fabricated as nil placeholders; A3/B/C extend the composed application snapshot when those integrations exist. Camp list returns these foundation reads ordered by context createdAt then inputId, and includes retained deleted identities only as typed deleted entries. No current default-camp inference is allowed.

For contract 1, add only the closed Codable `DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: Int)` in the already allowed domain file. Supported V1 value is exactly 4,096, with nested canonical JSON `{"apiRequestedTokens":4096,"kind":"providerAware"}` under `coachPolicy.outputPolicy`. Require exactly those keys/tag/integer value; reject missing/extra keys, other tags/values/types and the old `maximumOutputTokens` field, with no fallback (A1 carrier data does not yet exist). Include this policy in context and original-intent bytes/hashes and exact replay identity. Existing valid limits still use checked validation; later context/policy changes require their explicit CAS, not reinterpretation of sealed capture intent. A2, not A1, seals `protocolRequested(tokens: 4_096)` versus `providerManaged` with the actual runtime and request. No SQL, migration, retention, file-allowlist or A1 completion-point change follows from this policy encoding.

**Store interfaces:**

```swift
package struct DesktopGoalWorkflowStore: Sendable {
    package init(database: AppDatabase)
    package func prepareSubmission(_ intent: DesktopGoalCaptureIntentV1)
        throws -> DesktopGoalCaptureReceiptV1
    package func snapshot(inputId: String, campId: String)
        throws -> DesktopGoalFoundationReadV1
    package func list(campId: String)
        throws -> [DesktopGoalFoundationReadV1]
    package func sealCaptureStage(
        operationId: String, expectedVersion: Int,
        intent: DesktopGoalCaptureIntentV1
    ) throws -> DesktopGoalSealedStageV1
    package static func redact(
        inputId: String, at: Date, in database: Database
    ) throws
}

// Existing public wrapper remains; add this overload to InputGoalStore:
package func captureAndEnqueueParsing(
    _ command: CaptureInputCommandV1, in transaction: Database
) throws -> InputCaptureReceiptV1
```

`sealCaptureStage` is a concrete A1 stage operation, not a generic future command dispatcher. Factor internal `sealStage`/append-receipt primitives with Database arguments so atomic capture uses them in the existing transaction. Seal ordinal 0 with no predecessor. Re-seal returns the existing stage only when input/operation IDs and exact canonical intent/command bytes/hash match; stale expected operation version can be accepted **only** for that verified exact already-sealed replay. Different content, stage ordinal, envelope or version lineage throws. Appending an identical receipt is idempotent; another receipt for the same stage throws a receipt conflict. Later stage types/predecessor sequencing are implemented with their real consuming task, not simulated in A1.

Errors should be concrete `DesktopGoalFoundationErrorV1` cases: invalidIntent, contextConflict, operationConflict, stageConflict, receiptConflict, staleOperationVersion, missingCarrier, graphScopeMismatch, corruptCanonicalPayload, retentionIntegrity, inputDeleted. Preserve the actual underlying existing typed domain/camp error where appropriate. Error text includes safe IDs/hash/trace only.

#### Implementation steps and invariants

- [ ] Add tests below and observe their intended failure through the parent's approved test runner, then implement the domain value types and strict coding. No pre-generated fixtures that already claim successful coaching.
- [ ] Append the two-table migration exactly as approved in main plan, including context live/null-redacted CHECK, operation request/result redaction CHECK, ownerKind/version, safeReceiptJson, FK operation.inputId→context.inputId and partial unique index only for prepared userMutation. Initial rows are empty; no legacy input/goal/feed backfill. No goal FK is added before its future goal exists. Do not rename V17, alter V17 SQL, or broaden old assertions. Add scoped triggers to protect live original request bytes/stage prefixes only if needed to enforce the store contract; new-trigger effects belong only to the new migration and its tests.
- [ ] Extract capture's current transaction body, including its existing replay plan/prepared command and event-store execution, into the `in transaction:` overload. Public wrapper calls `pool.write { try captureAndEnqueueParsing(command,in:$0) }`. Do not nest pool.write or duplicate input/work/event SQL. Use the existing command receipt and validation logic unchanged.
- [ ] `prepareSubmission` validates local-owner/device and canonical request before writes, then uses ONE pool.write: read existing carrier first; if absent validate current camp lifecycle version/active/not archived; insert context and prepared userMutation operation; seal ordinal-0 capture command; call the transaction-taking InputGoalStore capture; append its actual receipt and safe identifiers using checked operation version increments. Any exception rolls back context, journal, input, work, command receipt, events and outbox together. If existing operation matches exactly, validate its domain receipt/current graph and return the original capture receipt without inserting anything or calling a Provider. Replay after input progresses accepts the historical capture receipt plus valid current graph; it does not demand current input.status captured. Original context fields are compared to the sealed original intent, not to later legitimate context updates. Mutation-by-the-same-ID is a conflict.
- [ ] The submit operation **remains `.prepared` after A1 capture**, because the approved submit completion point is the future fixed coach session's existence. A1 does not mark it committed to free a slot prematurely and does not enqueue a fake session. Its capture stage has a real receipt; A2/A3 can resume from it. Retrying A1 returns that receipt. Tests distinguish stage committed from top-level submit prepared.
- [ ] Snapshot/list are one database read each. Read carrier retention and input tombstone status before JSON decode. For live carrier require actual input exists, context inputId matches record key, captured/assigned camp matches requested camp, source ownership/explicit createGoal invariants hold, and each included parsing work joins exactly to this input/camp. Goal/session UUIDs are reserved, not required before conversion. If input.status goalCreated, require the fixed actual goal/sourceInput/camp join; any actual session must use the fixed sessionId/goalId. No other goal's work/records may enter the bundle. Missing input after a purported atomic capture is integrity failure, not a loading state. Non-carrier legacy inputs are excluded from list; direct snapshot of an absent carrier returns missingCarrier. Archived camp remains readable; it cannot receive a new submission.
- [ ] Add redaction to both actual tombstone transaction points. Null contextJson and every operation requestJson/resultJson; mark context redacted, operations redacted and advance versions with checked arithmetic; preserve original payload hashes and safeReceiptJson only after validating its strict safe shape. No path/text/argv/response can remain there. If no carrier exists, redaction is a valid no-op for legacy inputs. Repeated redaction on already redacted rows is identity-preserving and validates null payloads. An input tombstone with live raw carriers makes replay/read fail retentionIntegrity; do not decode or return the raw intent.
- [ ] Idempotent domain deletion replay must also validate carrier redaction inside the same transaction after its existing event-store receipt path returns, because that replay can skip the businessMutation closure. It must reject inconsistent live carriers rather than claim deletion completed. Public wrapper semantics and returned InputCaptureReceiptV1 remain unchanged. This adds no new deletion permission or state transition. requestDeletion still rejects goalCreated.
- [ ] Deleted snapshot returns `.deleted` with safe reserved IDs; no decode attempt on NULL. An operation that was prepared before deletion cannot be replayed: prepareSubmission returns inputDeleted without writing. Archive never redacts. All redaction errors roll back the associated input tombstone and work cancellation.

#### Historical migration checkpoint decision

Source inspection found one concrete latest-head/historical-checkpoint mismatch that the additive migration would expose:

- `P1DOutcomeContractTests.outcomeContractMigrationRemainsPresentUnderV17Head` currently calls `p1dDatabase("literal")` → AppDatabase.init → latest schema, then asserts head **V17**, tables **79**, indexes **208**, triggers **84**. After an additive migration, changing those constants would erase the frozen V17 assertion.
- Existing `P1F1SQLiteMigrationCompatibilityTests` already uses private `p1f1MigrateToV17(queue)` → `AppDatabase.migrator.migrate(queue, upTo: "v17-p1-engine-coordination")` and asserts the same counts. Its source/spec/schema hashes and all its expectations must remain untouched.
- `ControlContractMigrationTests` already migrates explicitly up to V14. `CampLifecycleMigrationTests` uses explicit V15/V16 checkpoint helpers; it checks V17 registration order rather than assuming V17 remains latest. `FailureVisibilityTests` uses `.migrations.last` only for a missing-V13 error message and checks V13 adjacency. No changes are warranted in those files for A1.

Smallest correction is **only this one historical test's setup**:

```swift
let queue = try DatabaseQueue(path: FileManager.default.temporaryDirectory
    .appendingPathComponent("p1d-v17-checkpoint-\(UUID().uuidString).sqlite").path)
try AppDatabase.migrator.migrate(queue, upTo: "v17-p1-engine-coordination")
// Existing test reads become queue.read instead of database.pool.read.
// Keep migration == "v17-p1-engine-coordination" and 79 / 208 / 84 exactly.
```

Do not change shared p1dDatabase used by current domain tests; it should keep testing latest schema. Do not add an AppDatabase through-version constructor just for this assertion. The new `DesktopGoalMigrationTests` separately proves latest includes `desktop-goal-workflow-v1`, fresh and V17-upgrade results agree, new carrier table/index definitions are exact, foreign_key_check is empty and integrity_check is ok. Run the existing historical suites unchanged except the one setup correction; don't derive new baseline counts by updating old numbers until green.

#### Exact A3 source-inventory successor boundary

Current `a3Revision02EntryBoundaryRemainsByteExact` in `DurablePlanningTests.swift` enumerates **all** Sources files, then removes explicit historical allowlists/successors and requires exactly 102 remaining paths with their original hashes. A new source file therefore needs a separately reviewed exact successor; leaving this implicit would fail the sentinel or tempt an invalid broad exclusion. `desktopCodingClosureRuntimeDiagnosticsSuccessorFiles` already contains only RuntimeLifecycleDiagnostics.swift and must remain an unchanged singleton.

Add this separate set with a dated A1 comment and exact equality/count assertions:

```swift
// 2026-09-05 desktop Coding closure A1 foundation only.
// Separate from frozen manifests and the runtime-diagnostics singleton.
private let desktopCodingClosureA1FoundationSuccessorFiles20260905: Set<String> = [
    "Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift",
    "Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift",
    "Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift",
    "Sources/AgentLoopTestSuite/DesktopGoalMigrationTests.swift",
]
```

In the sentinel, assert count 4, exact membership as above, empty intersection with frozen manifestPaths, empty intersection with the existing runtime diagnostics singleton and all historical exact allowlists, and `a3RequireRegularNonSymlink` for every new path. Add **only** `!desktopCodingClosureA1FoundationSuccessorFiles20260905.contains($0)` to the current enumerated-source filter. These files are absent from the historical manifest, so no `liveEntries` filter change is needed. Existing edited AppDatabase.swift/DurablePlanningTests.swift are already original A3 allowlisted; InputGoalStore.swift and OutcomeContractTests.swift belong to their established P1-C/P1-D exact paths. Do not add them again to the new set or change their historical allowlists.

Keep byte-frozen manifest SHA-256 `3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`, 206 entries, all historical intersection/partition counts, liveEntries 102, enumerated 102, exact sorted array equality, every live-entry hash and frozen Package.resolved/RunTests hashes unchanged. No directory/prefix/suffix exclusion, wildcard, auto-discovered expected set, rewritten manifest or reduced assertion is permitted. A fifth new source file requires a separate reviewed exact change; A1 does not preauthorize future driver/coach/UI files.

The boundary test and source-file ownership are explicit A1 acceptance evidence. This is a narrowly dated successor, not an exemption from testing new behavior.

#### Required red tests with literal assertions

New suite `DesktopGoalFoundationTests`, with isolated temp database per test and caller-owned deterministic IDs/time. Reuse existing real input command/claim helpers as appropriate; tests may drive existing domain commands locally to arrange a parsed/converted state, never add production fake execution.

```swift
@Test func atomicCaptureCreatesActualInputWorkAndPreparedSubmission() throws
// one context, one operation, one input; input.status == .captured
// one owned .inputParsing work; state == .queued; attempt == 0
// capture receipt IDs/hash agree with input/work and domain receipt
// operation.phase == .prepared; capture stage receipt != nil
// zero new goal_controller, coach_session, mission or outcome rows

@Test func captureReceiptFailureRollsBackEveryCarrierAndDomainWrite() throws
// install temporary trigger aborting journal receipt UPDATE after input/work insert
// prepareSubmission throws the injected error
// before/after counts AND existing-row hashes unchanged for context, operation,
// input_envelope, durable_work, domain events, outbox, command receipts

@Test func exactReplayBeforeAndAfterRestartOrInputProgressReturnsSameReceipt() throws
// invoke same sealed intent twice, reopen database, invoke again
// original receipt == each result; one input/work/context/operation
// drive parser domain result, retry original capture: still same historical receipt
// work attempts never increase just from prepareSubmission/replay

@Test func providerAwareOutputPolicyIsCanonicalAndReplayBound() throws
// unconfigured and unresolved selected runtimes store providerAware(apiRequestedTokens: 4_096)
// assert exact nested JSON keys/tag/integer and outputPolicy included in canonical hashes
// reopen and replay => identical context/intent bytes, hashes and original receipt; no extra rows
// no effective attempt mode, remote consent receipt, Provider call or attempt is fabricated
// valid policy drift (e.g. maximumDispatches 8 -> 7) changes context/intent hashes;
// reuse original operation identity => conflict and unchanged original bytes/receipt

@Test func outputPolicyRejectsUnsupportedOrLegacyJSONWithoutWrites() throws
// missing/extra keys, unknown tag, wrong type, non-4_096 value, maximumOutputTokens => reject
// no default/fallback decode; invalid prepare writes no input/work/context/operation
// corrupt persisted policy/hash => corruptCanonicalPayload, not repaired success

@Test func changedIntentEnvelopeContextOrStageUnderSameIdentityRejectsWithoutWrites() throws
// vary text/profile/camp/device/time/goalId and reuse operation ID/key
// each is operationConflict/contextConflict/stageConflict as applicable
// counts and raw original canonical bytes unchanged

@Test func sealedStageAndReceiptCASIsReplayableButNotReplaceable() throws
// exact existing stage/receipt retry => original hash/version, no append
// changed stage bytes or different receipt => conflict, unchanged prefix
// invalid expectedVersion with no exact sealed replay => staleOperationVersion
// submit remains prepared; no fake future-stage receipt is accepted

@Test func scopedReadRejectsCrossCampBrokenAndUnownedGraphs() throws
// A/B inputs + unrelated legacy input; list(A) contains only A carrier
// snapshot(A,campB) => graphScopeMismatch; corrupt hash => corruptCanonicalPayload
// injected missing input or wrong goal/source join => integrity failure
// reserved goal/session absent before conversion is valid, not an error

@Test func archivedOrInactiveCampCannotCaptureButExistingRecordsRemainReadable() throws
// new submission => camp authorization error and no rows
// previously captured snapshot remains readable; no raw payload redaction

@Test func cancelParsingDeleteRedactsWithinSameTransaction() throws
// capture, call actual cancelParsingAndDelete using active parsing head
// input.deletedTombstone; work.canceled; context.redacted; operation.redacted
// contextJson/requestJson/resultJson == nil; hashes unchanged; safe receipts only
// injected redaction failure => input still captured, work queued, carrier live

@Test func completedParsingDeleteRedactsAndReplayCannotRecoverRawRequest() throws
// capture, drive actual parse result locally, requestDeletion then completeDeletion
// same null/redacted assertions; restart => .deleted, not decoding error
// replay original capture => inputDeleted, no new work
// repeat exact delete => same safe receipt and still redacted

@Test func tombstoneWithLiveCarrierFailsClosedAndLegacyDeleteStillWorks() throws
// intentionally corrupt only test carrier after tombstone: replay/read reject
// no raw return/decode, no spontaneous repair success
// input without desktop carrier still follows its existing deletion behavior
```

`DesktopGoalMigrationTests` must include `freshAndV17UpgradeProduceSameDesktopCarrierSchema`, `desktopMigrationIsIdempotentAndLegacyRowsUnchanged`, `redactedCarrierNullAndSafeReceiptConstraintsFailClosed`, and `desktopMigrationFailureDoesNotRewriteHistoricalCheckpoint`. Verify real schema objects and migration receipts rather than a fabricated expected success string. For rollback, migrate an isolated queue to V17, snapshot its schema/data, then create a test-only conflicting `desktop_goal_operation` table before applying the new migration. Its conflict must roll back the earlier context-table creation and leave no new migration receipt. Remove only that deliberately inserted probe table and compare the original V17 snapshot and 79/208/84 checkpoint unchanged. This failure injection requires no production migration-test hook.

Additional exact existing regression identities:

- `P1CInputEnvelopeContractTests.captureAndInputParsingWorkCommitAtomically`
- `P1CInputEnvelopeContractTests.inputCaptureReplayAndPayloadDriftConflict`
- `P1CInputEnvelopeContractTests.inputCaptureReplayUsesCallerOwnedIDAndExistingWorkResult`
- `P1CInputEnvelopeContractTests.inputTombstoneRetainsOnlyExactIdentityHashAndTimes`
- `P1CInputEnvelopeContractTests.inputTombstoneNullsDeviceConnectorAuthorBodyRefErrorAndParent`
- `P1CInputEnvelopeContractTests.inputTombstoneForcesEmptyCandidatesUnspecifiedIntentLocalOnlyAndEqualDeleteTime`
- `P1DOutcomeContractTests.outcomeContractMigrationRemainsPresentUnderV17Head`
- `P1DOutcomeContractTests.outcomeContractMigrationReplaysFreshAndEveryPredecessorTwice`
- `a3Revision02EntryBoundaryRemainsByteExact` with its unchanged historical evidence plus the new exact four-file successor assertions.
- Existing `P1F1SQLiteMigrationCompatibilityTests`, V14 control migration and V16 camp lifecycle migration suites.

#### Validation and completion evidence

- [ ] Use only the already observed `swift run RunTests --filter <test-name>` form. Concrete focused examples: `swift run RunTests --filter atomicCaptureCreatesActualInputWorkAndPreparedSubmission`, `swift run RunTests --filter freshAndV17UpgradeProduceSameDesktopCarrierSchema`, and `swift run RunTests --filter a3Revision02EntryBoundaryRemainsByteExact`. Never invoke `--help` or probe unknown flags: this SPI runner starts tests instead of displaying help, as recorded in `progress.md`/`runtime-repair-plan.md`. Capture complete stdout/stderr and actual exit status in unique task files; do not truncate with head or interpret a pipeline's status as test success. Focused green is not authoritative full acceptance.
- [ ] Parent runs unfiltered `swift run RunTests` and the strict App build at the appropriate integration gate. A1 cannot claim the full desktop flow or product acceptance based on foundation tests. No tests/builds are executed by this task-extraction activity.
- [ ] Review the diff for transaction nesting, JSON/envelope hash identity, harmless exact replay versus payload drift, graph scope, both tombstone hooks, safe receipt leakage and unchanged frozen V17 checkpoint assertions. No broadened error catch/fallback or silently ignored deletion failure.
- [ ] Handoff exact file list, migration name/schema definition, red/green tests and full-output paths, changed historical test setup explanation, and remaining A2/A3 dependencies. The verifiable A1 outcome is persisted input + queued work + restart-safe carrier; no driver/coach/UI functionality is claimed.

Prepared by source inspection only. The historical checkpoint mechanism above was verified in source, not by running migrations or tests.
