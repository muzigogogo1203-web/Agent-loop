# Desktop Goal Flow Implementation Plan

> **For agentic workers:** Implement task by task with `superpowers:executing-plans`; the parent owns integration and arranges responsibilities-separated review before implementation and acceptance. This plan does not authorize additional agents, commits, Provider calls, or a new user approval round.

**Goal:** Deliver the default camp goal → shared understanding → explicit contract/start → existing execution → real verification → user acceptance/return → traceable camp result path as part of the installable desktop candidate.

**Architecture:** Preserve existing Input/Coach/Outcome event contracts and the existing mission engine. Add a narrow application coordinator and snapshot read model, an atomic goal-bound planning entry, a real outcome/verification bridge, and SwiftUI composition. Legacy feed and direct missions retain their records and existing behavior.

**Tech Stack:** Swift 6 strict concurrency; GRDB 7; existing `LLMProvider`, runtime profiles, durable work/command receipts; macOS 14+ SwiftUI.

**Spec:** `docs/collaboration/tasks/2026-09-05-desktop-coding-closure/spec.md`, with product direction from `../2026-09-05-product-takeover-baseline/spec.md` and the accepted master spec.

## Global constraints and entry gate

- The parent first clears the default-concurrency runtime failure and has its fix reviewed. This sub-plan is preparation, not evidence that that gate passed.
- No commit, push, merge, release, real-user data operations, secret inspection, or paid Provider validation is authorized here. Real adapters are implemented using injected test supplies; user acceptance later exercises authorized real configurations.
- No success inferred from card completion, mock output, a file's existence, or a successful hash check. Tests/build checks and user judgment are separate claims.
- Use the existing operation outcome distinction: not committed, committed, committed with visibility failure. Retry after a visibility failure refreshes/reconciles the existing receipt.
- Full `swift run RunTests` is authoritative. Filtered checks are development diagnostics; neither filtered green nor fixtures replace the full gate or real-user acceptance.
- Capture complete test/build output in this task directory using unique output names. Preserve unrelated dirty files. No general Orchestrator refactor is included.
- Management/rumination closure and package/UI acceptance are sibling work in the parent plan; this file covers only the goal flow.

## Decisions fixed by this plan

1. A camp-local goal uses `InputExplicitIntentV1.createGoal`, `InputSourceTypeV1.text`, and its explicit camp. Routing is deterministic and described as routing, not AI analysis. No guessed cross-camp routing in this slice.
2. A real coach adapter uses the selected supported planning runtime through `PlanningProviderResolver.resolvePlanningProvider(profileId:model:)`. It never falls back to another profile/model. `StrictPlanningProviderResolver` currently rejects CLI-only planning profiles: the UI must ask the user to select a supported OAuth/API planning profile; execution companions may still use existing CLI engines. This is an explicit product limitation, not silently substituted runtime behavior.
3. Persist a tagged unconfigured/selected coach runtime before enqueueing work. Changing global defaults must not change an already captured goal. Changing this goal's profile is an explicit settings action while no control turn is running, increments its context version, and affects subsequent turns only. Queued unconfigured, non-consented or budget-blocked work does not consume an attempt.
4. Shared understanding is editable through a visible revision round: edited fields are persisted as the user's correction, sent through the real coach, and the resulting new card is shown for confirmation. Never overwrite an immutable understanding version or confirm model changes without showing them. The UI labels the action “提交修改给教练”; it does not claim that arbitrary edits were already confirmed.
5. The initial contract has `acceptanceOwner = .user`, no policy acceptance, no external send/payment/deletion/public-release permission, and includes the user's explicit deliverables and acceptance criteria. Unsupported requested external actions remain visible non-goals/permission needs; they are not dropped from the user's text.
6. Coding contracts require a user-visible deterministic verification command in addition to artifact readability/hash checks. A default may be proposed from the selected project, but the final command is shown in the contract and must be confirmed. No invented `echo success`/mock test command or hash-only “tests passed”. Non-Coding documents may use artifact integrity plus explicit subjective user acceptance, accurately labeled.
7. “确认并开始” is the execution authorization gesture. It activates the draft contract, creates the mission and contract link, and enqueues planning in one transaction. Merely confirming understanding does not start a Provider or mission execution.
8. Return requires a reason and a selected completed card to rework. Do not guess which card the user intended. The existing card rework mechanism handles dependency review flags; accepted Outcome versions remain historical.
9. Project memory is a deterministic accepted-result note with source/goal/contract/outcome/acceptance references. No extra LLM distillation is required for this slice. Note-write failure is separately visible and retryable, without undoing or repeating acceptance.

## Execution order, owners and first executable slice

There are **10 implementation tasks**, grouped into the four review boundaries below. The parent is implementation/integration owner; its appointed responsibilities-separated reviewer owns review only. This document does not create another task or assign a new coding agent. The runtime repair owner remains the parent and must finish that entry gate before application integration. Build order follows package layering: Core → Application → App → packaged app; test additions go in AgentLoopTestSuite.

| Task | Concrete deliverable | Dependencies | Owner |
|---|---|---|---|
| A1 | Local carrier migration, atomic capture, camp/goal snapshot | Reviewed plan, green runtime gate | Parent/Core |
| A2 | Deterministic routing, strict real coach adapter, owned control driver | A1, repaired process/provider lifecycle | Parent/Core |
| A3 | Answer/revision/confirmation actor, restart reconciliation | A2 | Parent/Application |
| D1 | Goal workspace host with input, question, correction and confirmation | A3 | Parent/App |
| B1 | Reviewed visible contract draft and atomic goal-bound enqueue | A3 | Parent/Core + Application |
| C1 | Real artifact/provenance collection and versioned Outcome | B1 | Parent/Core + Application |
| C2 | Actual command verification, durable evidence, delivery | C1, repaired process runner | Parent/Core + Application |
| C3 | Atomic return/card rework and acceptance/memory projection | C2 | Parent/Core + Application |
| D2 | Default-home switch, mission breadcrumb and honest return actions | D1, B1, C3 | Parent/App |
| V1 | Full tests, strict build, independent review, isolated app interaction and package | D2 plus parent management closure | Parent; independent reviewer approves |

**First executable slice is A1–A3 + D1.** It provides a real persistent goal workspace reachable from a secondary “目标工作台” action, displaying a real model question and editable revision round through explicit understanding confirmation. It intentionally stops at a visible “共同理解已确认，尚未开工” state until B/C are integrated; no fake execution/acceptance button or Provider fixture in production. Test it with injected providers and isolated state during development. This is one intermediate implementation checkpoint, not the user handoff. The default home remains feed-led during that checkpoint and switches in D2 only once the complete truthful path exists.

B1 can be developed after A3 while D1 presentation is being reviewed, but writes to shared AppStore/Orchestrator remain serialized by the parent. C2 cannot start an execution test with the old broken runtime primitive. No task may treat architecture review, a standalone model test, or intermediate workspace as completion of the requested installable candidate.

## Source evidence and existing interfaces

These are source observations, not test results:

- `Sources/AgentLoopApplication/InputWorkflowController.swift` ends with `InputCaptureWorkflowController.captureLocalInput(_:trace:) async -> OperationCommitOutcome<InputCaptureReceiptV1>` and `loadInput(id:trace:) async -> WorkflowLoadState<InputEnvelopeRecord>`. Existing `InputWorkflowController` remains the feed/rumination API.
- `InputGoalStore.captureAndEnqueueParsing(_:)`, `convertToGoal(_:)`, `requeueParsing(_:)` use durable commands. Conversion requires no active parsing work and a resolved camp.
- `InputParsingWorker(database:workerId:clock:sleep:parser:)` and `CoachTurnProcessor(database:workerId:clock:sleep:provider:)` expose `recoverInterrupted()` and `runNext() async throws -> Bool`. They have no live application callers in the inspected source.
- `CoachUnderstandingStore.resumeSession(goalId:) -> CoachSessionSnapshotV1` supplies goal/session/open question/current understanding. Read `session.currentUnderstandingVersion` to obtain an unconfirmed draft: the goal's confirmed head is not interchangeable with the session's draft head.
- `OpenCoachSessionCommandV1` carries envelope, `GoalHeadV1`, source input ID, caller-owned session ID and next question ID. `AnswerCoachQuestionCommandV1` additionally carries `CoachHeadV1`, question ID, `CoachAnswerV1(text:)`, next question ID and expected understanding event version.
- `ProposeUnderstandingCommandV1` requires an actual claimed coach work item and system coach authority. Do not call it with a fabricated claim from the UI. `RequestCoachConfirmationCommandV1` and `ConfirmUnderstandingCommandV1` carry exact goal/session/understanding heads.
- `RequestUnderstandingRevisionCommandV1` carries a branch and next question ID, **not correction text**. Persist and deliver the correction as a real user answer; do not discard it or put it into a provider-only prompt without a user record.
- `OutcomeStore.createDraft(CreateOutcomeContractDraftCommandV1)`, `activateContract(ActivateOutcomeContractCommandV1)`, `activateGoal(ActivateGoalCommandV1)` exist. Goal activation requires a ready goal, active exact contract, exact confirmed understanding and same-camp mission in `.planning`, `.executing` or `.delivering`.
- `Orchestrator.startMission(...,trace:) -> OperationCommitOutcome<String>` calls `AppDatabase.enqueueMissionPlanning`, then starts tick/emits/kicks. `enqueueMissionPlanning` performs provider preflight outside `pool.write`; `PlanningDurableWorkLedgerOwner.enqueueMissionPlanning(_ db: Database, ..., profileSnapshot:)` creates squad, mission, events and queued planning work inside the transaction. This is the required B transaction seam.
- `OutcomeStore.recordInitialOutcome`, `recordNewOutcomeVersion`, `beginVerification`, `recordVerification`, `markDelivered`, `acceptOutcome`, `returnOutcome` exist. No inspected live runtime caller currently bridges execution into the first five operations.
- `OutcomeStore.authorizeProducer` accepts only `.cow` or `.engine` with `envelope.actorId == producerActorId` and no device. Never manufacture a generic system producer to make collection pass.
- `ArtifactHashVerifier.verify(path:expectedHash:)` is real; `CommandExitVerifier<Runner: P1DProcessRunner>.verify(_:)` reduces an injected process result to passed/failed/blocked/invalid. A live process adapter must actually execute and retain evidence.
- `OutcomeStore.markDelivered` requires `.verified`, reduced verification `.verified`, zero current invalidations, and a manifest whose file hashes still match.
- `AppStore.closeoutCurrentMission()` already uses `AcceptanceWorkflowController` if an Outcome exists, and refuses legacy closeout for a contract-linked mission without an Outcome. `CodingRanchStoreAdapter.loadReturnSummary` currently calculates eligibility from legacy mission/cards; D must replace that calculation for linked missions.
- `OutcomeStore.acceptOutcome` atomically sets Outcome `.accepted`, Goal `.achieved`, Mission `.accepted` and metric. `returnOutcome` records the return and reopens accepted mission to `.delivering`; it does not start rework.
- `Orchestrator.returnCardForRework(cardId:feedback:)` calls `AppDatabase.returnCardForRework`, emits missionChanged and reconciles. The database method updates card `.ready`, appends `cardReturned`/`cardReady`, marks completed direct downstream cards `reviewFlag = "stale_upstream"`, and rolls up the mission.

## Minimal durable carrier gap

Existing domain contracts cannot encode two necessary pieces of desktop state: (a) the coach runtime selection, which is absent from `CoachTurnWorkInputV1` and `CoachTurnProviderRequestV1`; (b) a sealed pending user operation spanning existing separate commands, including correction text and caller-owned IDs/envelopes. UserDefaults or current global runtime settings cannot provide faithful restart/retry behavior. Do not overload `UnderstandingContentV1.budgetPolicy`, goal raw text, or old work JSON with hidden UI metadata.

Add one additive migration after the actual current migration head, named `desktop-goal-workflow-v1`, with two tightly scoped local carrier tables. The implementation must re-read the current migration tail because the parent may be editing adjacent source.

```sql
CREATE TABLE desktop_goal_context (
  inputId TEXT PRIMARY KEY NOT NULL,
  goalId TEXT NOT NULL UNIQUE,
  campId TEXT NOT NULL,
  version INTEGER NOT NULL CHECK(version > 0),
  contextJson TEXT,
  contextHash TEXT NOT NULL,
  retentionState TEXT NOT NULL CHECK(retentionState IN ('live','redacted')),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK((retentionState='live' AND contextJson IS NOT NULL)
     OR (retentionState='redacted' AND contextJson IS NULL))
);
CREATE TABLE desktop_goal_operation (
  id TEXT PRIMARY KEY NOT NULL,
  inputId TEXT NOT NULL,
  kind TEXT NOT NULL,
  ownerKind TEXT NOT NULL CHECK(ownerKind IN ('userMutation','system','coachAttempt','verificationAttempt')),
  version INTEGER NOT NULL CHECK(version > 0),
  requestJson TEXT,
  requestHash TEXT NOT NULL,
  phase TEXT NOT NULL CHECK(phase IN ('prepared','committed','failed','redacted')),
  resultJson TEXT,
  safeReceiptJson TEXT,
  safeErrorCode TEXT,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  FOREIGN KEY(inputId) REFERENCES desktop_goal_context(inputId),
  CHECK((phase='redacted' AND requestJson IS NULL AND resultJson IS NULL)
     OR (phase<>'redacted' AND requestJson IS NOT NULL))
);
CREATE UNIQUE INDEX desktop_goal_one_pending
  ON desktop_goal_operation(inputId)
  WHERE phase='prepared' AND ownerKind='userMutation';
```

`contextJson` is versioned canonical JSON for `DesktopGoalContextV1`: schema version 1, fixed input/goal/session UUIDs, tagged coach runtime, optional workspace path/bookmark, companions, separate coach/mission budgets, autonomy, and an explicit consent receipt reference. There are no credentials. IDs exist before input capture; therefore do not add a premature FK from context.goalId to a goal that is created in a later command. Every read and command validates the joined camp/input/goal graph, not merely this local carrier. Enforce live contextJson non-null and redacted contextJson null with a CHECK; redacted operations require requestJson and resultJson null.

`requestJson` seals the original gesture's intent, known heads, context version, correction text and caller-owned IDs; it does not invent future parser/worker heads. While live its bytes are immutable. `resultJson` is a CAS-versioned append-only sequence of sealed dependent commands and their receipts: each entry contains stage ordinal/name, exact canonical typed command bytes/hash/envelope, predecessor receipt hash, and eventual domain receipt. Before a dependent command, read its real head and seal that stage in a short transaction requiring the predecessor receipt and expected operation version. Replays use that sealed command unchanged. Receipts are appended without altering old entries. `safeReceiptJson` contains only allowlisted IDs, versions, hashes, counts and timestamps, never text/path/argv. Redaction is the explicit terminal exception to payload immutability.

Operation completion is finite: submit completes when the fixed session exists; answer completes after answer domain commit; revision completes after its exact correction question and user answer commit; explicit confirmation completes after confirmation commit; start/return/accept complete at their atomic domain receipts. Each releases the userMutation slot immediately. Waiting for a model question/understanding or next user answer never retains that slot. Automatic request-confirmation uses a separate `ownerKind=system` operation keyed by understanding ID/version/hash. Coach attempt and verification attempt rows use their own owners and cannot occupy a userMutation slot.

Attempt-specific states such as dispatching/awaitingApproval are tagged entries in resultJson. Top-level phase remains prepared until a terminal attempt receipt, then becomes committed (a real terminal success/failure/denial result) or failed (pre-dispatch preparation failure); redacted is the retention terminal. CAS rejects invalid state edges. Do not add a third table for these attempts.

A sealed stale command yields a visible `stageHeadConflict` with existing committed effects preserved. `resolveStageConflict(operationId:expectedVersion:decision:)` requires an explicit user decision `keepCommittedState` or `resubmitIntent` after showing refreshed state. First reconcile sealed domain keys; mark the original operation terminal failed with safe conflict receipt without undoing effects. Only `resubmitIntent` creates a new operation using fresh heads and a new key, and it must reuse an already created input/goal/session. Automatic code never reseals a stale stage or repeats start/accept under a new identity. Partial execution without conflict stays prepared for reconciliation, not a generic retry-from-zero action.

Retention is scoped to actual existing InputEnvelope deletion, not ingestion deletion or speculative goal deletion. Archive preserves carriers. Add `DesktopGoalWorkflowStore.redact(inputId:at:in: Database)` inside the SAME `InputGoalStore.cancelParsingAndDelete` businessMutation that updates the tombstone, and inside `completeDeletion`'s existing `executeOrdinary` mutation closure (use its Database argument). Null contextJson, every matching requestJson/resultJson, set terminal redacted state, preserve original hashes/IDs and safe receipts; rollback restores both input and carriers. `requestDeletion` excludes goalCreated, so this slice does not add post-goal permanent deletion. Declare these carriers dependencies of any future such feature.

Read/reconcile first checks InputEnvelope retention/tombstone and carrier retention before decoding text. Return a typed `DesktopGoalReadResultV1.deleted(inputId:goalId:)` terminal presentation, never an unexplained decoder error; do not replay a redacted prepared operation. A tombstoned input with live carrier data is an observable retention-integrity failure and cannot dispatch. Existing idempotent deletion replay also validates carrier redaction. This is two deletion hooks and one terminal representation, not a new retention engine.

## Shared proposed application interfaces

New names below are proposed implementation contracts, not assertions that they already exist.

```swift
package struct DesktopGoalContextV1: Codable, Sendable, Equatable {
    let schemaVersion: Int // exactly 1
    let inputId: String; let goalId: String; let sessionId: String
    let coachRuntime: DesktopCoachRuntimeV1
    let coachPolicy: DesktopCoachPolicyV1
    let remoteConsentReceiptId: String?
    let workspacePath: String?; let workspaceBookmark: Data?
    let companionIds: [String]; let budgetTokens: Int
    let autonomy: MissionAutonomy; let privacyLevel: InputPrivacyLevelV1
}
package enum DesktopCoachRuntimeV1: Codable, Sendable, Equatable {
    case unconfigured
    case selected(profileId: String, model: String)
}
package struct DesktopCoachPolicyV1: Codable, Sendable, Equatable {
    let maximumDispatches: Int // initially 8, retries included
    let reportedTokenStopThreshold: Int // initially 32_768, not an exact hard ceiling
    let maximumRequestUTF8Bytes: Int // 49_152 across system + history + wrappers
    let maximumOutputTokens: Int // 4_096
    let timeoutSeconds: Int // 120
}
package struct UpdateDesktopCoachContextCommandV1: Sendable {
    let operationId: String; let envelope: CommandEnvelopeV1
    let inputId: String; let expectedContextVersion: Int
    let runtime: DesktopCoachRuntimeV1
    let policy: DesktopCoachPolicyV1
    let authorizeSelectedRemoteRuntime: Bool
}
package enum DesktopGoalReadResultV1: Sendable {
    case live(DesktopGoalSnapshotV1)
    case deleted(inputId: String, goalId: String)
}
package enum DesktopControlClaimResultV1: Sendable {
    case claimed(DurableWorkClaim, DesktopGoalContextV1, attemptReceiptId: String?)
    case waiting(DesktopControlWaitReasonV1)
}
package enum DesktopControlWaitReasonV1: String, Sendable {
    case runtimeUnconfigured, runtimeUnsupported, remoteConsentRequired
    case coachBudgetReached, coachUsageUncertain, coachUsageInvalid, coachContextTooLarge
    case contextChanged, halted, workNotDue
}
package enum DesktopCoachUsageV1: Sendable, Equatable {
    case observedUnproven(Usage)
    case unknown
}
// Internal journal seam; command bytes are canonical encodings of the named
// concrete Input/Coach/Outcome command types, never an arbitrary tool payload:
// sealStage(operationId: String, expectedVersion: Int, ordinal: Int,
//   predecessorReceiptHash: String?, commandType: String,
//   commandBytes: Data, envelope: CommandEnvelopeV1) throws -> sealedStageHash
// appendStageReceipt(operationId: String, expectedVersion: Int,
//   sealedStageHash: String, domainReceiptBytes: Data, isTerminal: Bool) throws
package struct DesktopGoalHeadsV1: Sendable, Equatable {
    let goal: GoalHeadV1; let coach: CoachHeadV1?
    let understanding: UnderstandingHeadV1?
    let contextVersion: Int
}
package struct DesktopGoalSnapshotV1: Sendable {
    let context: DesktopGoalContextV1; let contextVersion: Int
    let input: InputEnvelopeRecord?; let goal: GoalControllerRecord?
    let session: CoachSessionRecord?; let question: CoachQuestionRecord?
    let draftUnderstanding: UnderstandingCardVersionRecord?
    let confirmedUnderstanding: UnderstandingCardVersionRecord?
    let contract: OutcomeContractSnapshotV1?
    let mission: MissionRecord?; let outcome: OutcomeSnapshotV1?
    let work: [DurableWorkRecord]
    let heads: DesktopGoalHeadsV1?
    let pendingOperationId: String?
}
```

`OutcomeContractSnapshotV1` is the existing contract snapshot. Add companion collections to this read bundle as `[VerificationRecordSnapshotV1]`, `[AcceptanceRecordSnapshotV1]`, `[CardRecord]`, `[ArtifactRecord]` and `[RunRecord]`; do not introduce a second contract representation. Compute “can accept” from Outcome `.delivered`, verification heads, mission `.delivering` and Goal `.active`; artifact-viewed UI state is separate.

`GoalWorkflowController` is an actor with an injected FailureReporter, local identity/envelope factory, read ports, command ports and worker-wake port. Its mutations accept caller-owned operation IDs and fixed request structs, return `OperationCommitOutcome<DesktopGoalSnapshotV1>`, and its loads return `WorkflowLoadState`. A generic string action switch is not the public interface. Define methods `submitGoal`, `answerQuestion`, `submitUnderstandingRevision`, `confirmUnderstanding`, `saveContractDraft`, `startConfirmedGoal`, `returnForRework`, `acceptDeliveredOutcome`, `retryPendingOperation`, and `loadGoal`; B and C supply their typed request structs below. A exposes journal prepare/resolve helpers privately.

```swift
package struct DesktopGoalSubmissionV1: Sendable {
    let operationId: String; let campId: String; let text: String
    let context: DesktopGoalContextV1; let envelope: CommandEnvelopeV1
}
package struct DesktopGoalRevisionV1: Sendable {
    let operationId: String; let inputId: String
    let heads: DesktopGoalHeadsV1; let edited: UnderstandingContentV1
    let envelope: CommandEnvelopeV1
}
// All these actor methods are async; trace is an OperationTrace argument.
// submitGoal(_: DesktopGoalSubmissionV1, trace:)
// answerQuestion(operationId: String, command: AnswerCoachQuestionCommandV1, trace:)
// submitUnderstandingRevision(_: DesktopGoalRevisionV1, trace:)
// confirmUnderstanding(operationId: String, command: ConfirmUnderstandingCommandV1, trace:)
// saveContractDraft(operationId: String, command: CreateOutcomeContractDraftCommandV1, trace:)
// startConfirmedGoal(_: GoalMissionStartCommandV1, trace:)
// returnForRework(_: GoalReturnRequestV1, trace:)
// acceptDeliveredOutcome(operationId: String, command: AcceptOutcomeCommandV1, trace:)
// retryPendingOperation(id: String, trace:)
// Each mutation returns OperationCommitOutcome<DesktopGoalSnapshotV1>.
// updateCoachContext(_: UpdateDesktopCoachContextCommandV1, trace:)
// loadGoal(inputId: String, trace:) returns WorkflowLoadState<DesktopGoalReadResultV1>.
```

## A — Control/read model and real coach

**Files:** create `Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift`, `Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift`, `Sources/AgentLoopCore/Work/DesktopGoalControlDriver.swift`, `Sources/AgentLoopCore/Work/LLMCoachTurnProvider.swift`, `Sources/AgentLoopApplication/GoalWorkflowController.swift`; modify migration registration in `Database/AppDatabase.swift`, transaction overloads and both tombstone hooks in `Database/InputGoalStore.swift`, exact-work entry/extraction in `Work/InputParsingWorker.swift` and `Work/DurableWorkSupervisor.swift`, transaction-scoped claim support in `Database/DurableWorkStore.swift`, `Sources/AgentLoopApp/AppStore.swift` bootstrap/owned driver, and `Sources/AgentLoopCore/Observability/FailureRecord.swift`; tests `Sources/AgentLoopTestSuite/DesktopGoalWorkflowTests.swift`, `LLMCoachTurnProviderTests.swift`, `DesktopGoalMigrationTests.swift`. No retention changes to IngestionDeletionStore or CampLifecycleStore are required by this slice.

- [ ] Add the migration and canonical context/operation records. `prepareSubmission` inserts context + sealed submit operation + input capture/enqueued parser in one `pool.write`, using an internal transaction-taking overload of the existing capture implementation. Existing public capture behavior stays unchanged. Empty trimmed goal rejects before context/input/work writes. Same operation with same hash returns the original receipt; same ID with different hash throws a conflict.
- [ ] Implement explicit `updateCoachContext` CAS with local-owner/device envelope and expected context version; runtime changes require no running control turn. Save selected runtime and consent receipt in a system-owned journal row (it can resolve waiting-for-config while submit still occupies its userMutation slot); receipt records actor/device/time/input/profile/model/context version and grant/revoke decision. Original InputEnvelope.privacyLevel and capture hash stay unchanged. Effective remote authority is the captured cloudExecution permission bound to this selected runtime, or a later explicit applicable consent receipt; localOnly without such receipt blocks dispatch. Runtime changes invalidate previous runtime-specific consent. Revocation with unchanged runtime is allowed while running: increment context/generation, cancel/join current dispatch and forbid future starts; never race-update a running turn's runtime.
- [ ] Add exact-work execution: preserve existing kind-wide `runNext()` for its current callers, extract its post-claim body to `InputParsingWorker.runClaimed(_ claim: DurableWorkClaim) async throws` and `CoachTurnProcessor.runClaimed(_ claim: DurableWorkClaim) async throws`. Each validates exact kind/aggregate/lease and uses the same renewal/terminal mutation implementation. Desktop driver NEVER calls kind-wide runNext. It selects only due work joined to a live desktop carrier and resolves supported runtime/preflight outside a write transaction. Then `DesktopGoalWorkflowStore.claimEligible(workId:expectedContextVersion:workerId:now:) -> DesktopControlClaimResultV1` checks exact owner/input/goal, due state, camp lifecycle/dispatch, context CAS, consent and budget in ONE write and calls the existing transaction-scoped `DurableWorkStore.claim(workId:workerId:now:leaseDuration:in:)`. Return `.claimed(claim, context, attemptReceiptId)` or `.waiting(reason)`; waiting does not claim or increment attempts. Parser claims require this carrier's explicit text/createGoal ownership, so unrelated captured inputs remain untouched.
- [ ] Recheck current lease, camp/dispatch and effective consent immediately before starting Provider; use an actor-owned generation reservation so a completed revoke/halt cannot be followed by a stale start. Missing/unsupported/unconfigured runtime, localOnly and exhausted/uncertain budget discovered before claim remain queued with reasons `runtimeUnconfigured`, `runtimeUnsupported`, `remoteConsentRequired`, `coachBudgetReached`, or `coachUsageUncertain`. Settings/consent/continuation wakes them. Never map these waiting conditions to provider failure or cancellation. Once a real attempt was claimed, a race revocation/halt aborts without Provider dispatch, records a not-dispatched reservation, and leaves the work safely recoverable through the existing lifecycle; a later settings change cannot silently replace its sealed runtime.
- [ ] The carrier-owned deterministic routing turn and exact application-authored revision-question turn need no remote consent/model budget reservation. Identify the latter by the sealed revision operation's workId and nextQuestionId before choosing this local adapter. All other coach work requires the full remote eligibility checks; no runtime/configuration failure is converted into a local revision question.
- [ ] Implement `DesktopGoalWorkflowStore.snapshot(inputId:)` and `list(campId:)` each under one `pool.read`. Explicitly join the draft understanding using the session version, confirmed understanding using the goal version, latest active link, contract/outcome refs and control work. Missing/cross-camp references throw integrity errors. A captured-but-not-yet-converted input is valid and visible. Sort by persisted createdAt plus ID.
- [ ] Implement deterministic parser as the following policy, passing actual work through `InputParsingWorker`:

```swift
guard request.explicitIntent == .createGoal,
      let camp = request.assignedCampId,
      request.candidateCampIds.isEmpty,
      request.sourceType == .text,
      request.inlineText?.trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty == false else { /* typed permanent routing failure */ }
return .parsed(try InputParseResultV1(
    route: .coaching, candidateCampIds: [], assignedCampId: camp))
```

Do not parse URLs, load files, choose another camp, or infer permission. Persist local text routing even when no coach runtime is available, and show “等待配置教练” rather than claiming coach processing started.

- [ ] After parser commit, seal the conversion command against the actual parser-produced head, call `convertToGoal` with the preallocated goal ID, then seal/open the fixed session against its actual goal head. Derive distinct keys from operation ID/stage; each stage gets its envelope at seal time and reuses it on replay. Submit completes as soon as that fixed session exists, before its first model answer. If conversion committed but session creation failed, resume that same goal. Do not recreate the input.
- [ ] Implement real coach using `PlanningProviderResolver`; request history is canonical serialization of `CoachTurnProviderRequestV1` plus explicit instruction to treat user/source text as data. Use `LLMProvider.streamTurn(system:history:tools:toolChoice:maxTokens:)` with no tools, `.auto`, a fixed output cap, bounded wall time, and cancellation propagation. If provider supports `LLMProviderRunDrivingV1`, await its completion/cleanup through the existing lifecycle convention before declaring the turn stopped.
- [ ] Apply `DesktopCoachPolicyV1` before coaching; it is shown with initial goal submission and is separate from the later mission budget. Bound the complete serialized outgoing request to 49,152 UTF-8 bytes; oversize history is a visible `coachContextTooLarge`, with no silent truncation or claim. Output is capped at 4,096 tokens and 120 seconds. Maximum eight actual Provider dispatch reservations, including retry attempts; threshold 32,768 reported input+output tokens stops subsequent automatic dispatch when observed counts reach it. These payload/turn bounds are not advertised as an exact aggregate token ceiling. One-turn uncertain-usage continuation does not override a reached policy limit; increasing that limit is a separate explicit `updateCoachContext` policy change with CAS and no running turn.
- [ ] Persist each attempt as ownerKind `coachAttempt`, ID `coach-attempt:<workId>:<attempt>`, sealed runtime/context/policy/consent/request hash and state reserved→dispatching→terminal. Claim and reservation occur in the same transaction. Append usage receipts once via CAS; duplicate terminal delivery must match hash or throw conflict. Use checked nonnegative integer addition for input/output/cache diagnostics and cumulative totals; overflow sets `coachUsageInvalid` and blocks further dispatch, never wraps/clamps. Retries get distinct attempt IDs and consume separate reservations. A reserved attempt proved never dispatched can be closed as notDispatched without a token charge; dispatching with no complete terminal evidence on restart is uncertain and is never counted as zero or automatically repeated.
- [ ] Current `TurnResult.usage` defaults to zero and has no availability flag. This adapter therefore reports `DesktopCoachUsageV1.observedUnproven(Usage)` for existing generic LLMProvider results, including all-zero values; it cannot call them known exact usage. Failed/interrupted/no-terminal runs report `.unknown`; never infer free usage. Unproven/unknown completion blocks further automatic model turns with `coachUsageUncertain`, while still showing a successfully persisted question/understanding. User may explicitly choose “继续一轮（上一轮用量未确认）” through a local-owner journaled continuation tied to the prior attempt and policy version, authorizing exactly one next dispatch; answer/confirmation do not silently authorize it. No new Provider-wide usage schema is required for this slice. Report observed counts as unverified estimates only. The deterministic revision-question adapter records no Provider dispatch and consumes no model reservation.
- [ ] Accept exactly one terminal turn containing one JSON object. Strict tagged schema: `{"kind":"question","prompt":...,"recommendation":...,"reason":...}` or `{"kind":"understanding","content":<all UnderstandingContentV1 keys>}`. Require exact keys, correct types, nonempty required fields, bounded arrays/text, no tool calls, no fenced/prose prefix, no truncation/tool stop. Unknown tags, extra keys, malformed/partial JSON or missing terminal turn become explicit permanent `ControlWorkerProviderFailureV1`. Transient transport errors use the existing worker retry policy (maximum four attempts); no second layer of unbounded retries or deterministic understanding fallback. Keep raw provider text out of logs; log trace/work/attempt/profile IDs, error classification and duration.
- [ ] Driver owns at most one parsing and one coach loop per application generation. Bootstrap calls recovery once; reconcile only when dispatch is running and camp is writable. Wake on pending due work and relevant committed operations; sleep until the next durable deadline rather than rapid polling. Halt/shutdown cancels and joins tasks, then stops claiming. A canceled provider task can leave a lease-recoverable `.running` work record, consistent with the existing worker contract; user cancellation instead uses `CoachUnderstandingStore.abandon(AbandonGoalCommandV1)` to cancel active work atomically. Do not mislabel application shutdown as user abandonment.
- [ ] On understanding output, create a separate system-owned request-confirmation operation keyed by its version/hash, seal its exact `UnderstandingHeadV1` (content version/hash AND event version), commit and finish that operation. Initial Goal stays `.clarifying`; session becomes `.readyForConfirmation`; only explicit user confirmation moves Goal `.ready` and Session `.confirmed`. In a confirmed revision, Goal deliberately remains `.ready` with its prior confirmed head until the new card is confirmed; start is blocked while that revision session is interviewing/waiting/awaiting confirmation.
- [ ] Revision saves the full edited `UnderstandingContentV1` as a user's correction. Seal/call the existing revision command for the actual branch. Its exact queued work/nextQuestionId is claimed and emits a clearly application-authored correction question through the revision adapter; never label it model speech or intercept unrelated turns. After the question commit, seal `AnswerCoachQuestionCommandV1` with its actual heads and exact submitted correction/local-owner identity. Revision operation completes at that answer receipt and releases the user slot. The following eligible turn is the real coach and produces the new understanding. Restart resumes the first uncommitted sealed stage; show the revised card and require confirmation. Do not expose revision while contract/mission is already active in this slice.

**Literal tests to add:**

```swift
@Test func explicitCampGoalRoutesAndResumesWithoutDuplicateGoal() async throws
// after capture: input.status == .captured; parsing.state == .queued
// after routing: input.status == .coaching
// after reconciliation twice: input.status == .goalCreated
// goal.status == .clarifying; count(goal_controller) == 1
// count(coach_session) == 1; count(open coach work) == 1

@Test func coachQuestionAnswerConfirmationUsesPersistedHeads() async throws
// question: session.status == .waitingForUser; openQuestion.count == 1
// answer/replay: answered question count == 1; next work count == 1
// proposal: understanding.status == .awaitingConfirmation
// goal.status == .clarifying; no goal_mission_link
// explicit confirm: goal.status == .ready; session.status == .confirmed

@Test func editedUnderstandingSurvivesRestartAsUserAnswer() async throws
// inject restart after revision question commit, before answer
// exact edited text occurs once in CoachQuestionRecord.answer
// prior understanding contentHash unchanged; next version > prior
// no goal transition to ready until confirmation of the new visible hash

@Test func malformedCoachJSONCannotCreateUnderstanding() async throws
// prose, extra keys, missing keys, tool use, truncated turn => work.failed
// no understanding row, no contract, no mission; visible safe failure

@Test func haltAndStaleGenerationCannotCommitCoachUIAdvance() async throws
// no provider start after halt; old generation cannot project over new camp
// shutdown cancellation is recoverable; explicit abandon => goal.abandoned

@Test func desktopContextMigrationPreservesLegacyAndRedactsDeletedInput() throws
// old camp/ingestion/mission counts and payload hashes unchanged on upgrade
// repeated migrator application has one migration receipt
// deleted input leaves no raw correction/provider context user text

@Test func exactClaimDoesNotTakeAnotherGoalsBlockedOrUnownedWork() async throws
// A configured+consented, B localOnly/unconfigured, C unrelated legacy parser
// execute A => only A's exact work claimed; B/C attempts == 0
// reopen DB, repeat wake => B/C attempts still 0; B visible waiting reason
@Test func contextSelectionRaceRejectsClaimBeforeAttemptIncrement() async throws
// preflight context v1; explicit selection commits v2; claim(v1) => contextChanged
// no claim, attempts == 0, no provider call; fresh v2/consent may dispatch
@Test func revokeAfterClaimPreventsStaleProviderLaunch() async throws
// pause before launch reservation; revoke completes; provider invocation == 0
// no fabricated question/failure; durable not-dispatched attempt receipt exists

@Test func bothInputTombstonesRedactCarriersInTheirOwnTransaction() throws
// capture before parsing: cancelParsingAndDelete => input.deletedTombstone
// parser done before goal conversion: requestDeletion+completeDeletion => tombstone
// both paths: contextJson/requestJson/resultJson == nil; hashes retained
// injected redaction error rolls back input tombstone and carrier mutation
@Test func restartWithRedactedPreparedOperationIsDeletedNotReplayable() async throws
// load => .deleted(inputId, goalId); no decoder failure or provider invocation
// no source/correction strings in either raw JSON column or safeReceiptJson

@Test func coachUsageAttemptReceiptSurvivesDuplicateAndUnknownCompletion() async throws
// same workId+attempt terminal twice => one receipt/reservation
// restart after model completion before receipt => unknown, next attempt unclaimed
// TurnResult default Usage() => observedUnproven, not known zero
// explicit continuation authorizes exactly one next dispatch; no silent auto retry
@Test func coachUsageOverflowAndOversizedInputBlockDispatch() async throws
// checked sum Int.max + 1 => coachUsageInvalid, no wrap or dispatch
// serialized full request > 49_152 UTF8 bytes => no claim/no provider call
// retries have separate workId+attempt receipts; maximumDispatches includes them

@Test func everyDependentStageReplaysItsOriginalHeadAndReleasesUserSlot() async throws
// restart before/after conversion/session/question/answer stage seal and commit
// each domain key commits once; sealed bytes/hash remain identical on replay
// submit terminal at session existence; answer terminal at domain answer receipt
// revision terminal at exact correction-answer receipt; user slot released
// pending future model work does not reserve the userMutation slot
@Test func staleSealedStageRequiresExplicitResolutionWithoutDuplicateGoal() async throws
// newer unrelated head => stageHeadConflict; sealed command is not rewritten
// keepCommittedState terminalizes original; resubmit reuses input/goal/session
// count(goal) == 1; no auto confirm/start/accept against an unseen newer head
```

Also cover changed global default preserving captured profile/model; unsupported CLI planning profile, missing runtime, permanent provider error, exactly bounded transient retry, refreshed head conflict, and committed capture with failed projection. Test providers are scripted real-interface injections, explicitly labeled fixtures.

## B — Atomic goal/contract mission start

**Files:** create `Sources/AgentLoopCore/Domain/GoalMissionStart.swift`; modify `Database/DurableWorkStore.swift`, `Database/OutcomeStore.swift`, `Kernel/Orchestrator.swift`, `Application/GoalWorkflowController.swift`, `DesktopGoalWorkflowStore.swift`; tests `Sources/AgentLoopTestSuite/GoalMissionStartTests.swift`.

**Proposed interface:**

```swift
package struct GoalMissionStartCommandV1: Sendable {
    let operationId: String
    let envelope: CommandEnvelopeV1
    let goal: GoalHeadV1
    let contract: OutcomeContractRef // previously saved draft shown to user
    let understanding: UnderstandingVersionRefV1
    let contextVersion: Int
    let goalText: String // exact visible understanding + contract, canonical rendering
    let companionIds: [String]; let workspacePath: String?
    let budgetTokens: Int; let autonomy: MissionAutonomy
    let planningInput: PlanningWorkInput
}
package struct GoalMissionStartReceiptV1: Codable, Sendable, Equatable {
    let missionId: String; let workId: String
    let goalId: String; let contract: OutcomeContractRef
}
// AppDatabase:
// enqueueGoalMissionPlanning(_:planningProviderResolver:) throws
//   -> GoalMissionStartReceiptV1
// Orchestrator:
// startGoalMission(_:trace:) async
//   -> OperationCommitOutcome<GoalMissionStartReceiptV1>
```

- [ ] Save draft contract from confirmed understanding before start. Show exact deliverables, criteria, verification command/config, no-go scope and permissions. Coding type uses at least one `.deterministic` command/tests/build requirement; `.artifactHash` is a separately labeled integrity requirement. Persist command argv and explicit workspace/config in `VerificationRequirementV1.config`, its canonical hash, timeout and environment policy. Initial acceptance owner is user and all high-impact flags false. Reject incompatible external-action requests rather than marking these false while authorizing such work in the prompt.
- [ ] Add internal transaction-taking overloads of `OutcomeStore.activateContract` and `activateGoal`; public methods still wrap a single `pool.write`. They must execute the SAME existing domain-event/receipt/projection code with the supplied `Database`; do not copy raw goal/link SQL into the App layer and do not nest `pool.write`.
- [ ] Add `AppDatabase.enqueueGoalMissionPlanning`. First check existing sealed operation/receipt and validate its full graph; a complete replay skips credential resolution. For a new command, provider resolution happens outside the transaction, using the captured profile, exactly as existing manual planning. Inside ONE `pool.write`: validate sealed command/context version and camp lifecycle/dispatch; activate exact draft contract; call `PlanningDurableWorkLedgerOwner.enqueueMissionPlanning` with deterministic key `mission-start:goal:<goalId>:contract:<id>:<version>:v1`; call transaction-taking `activateGoal` with returned missionId; save the complete start receipt and journal completion. If any step fails, contract activation, mission/squad/events/work/link/journal result all roll back.
- [ ] Start additionally requires the sole session `.confirmed`, its version matching the shown confirmed head, and no prepared revision stages. A reopened confirmed revision can leave Goal `.ready` with the old head; that does not authorize starting the old contract while the visible revision is pending.
- [ ] Start key is tied to one contract version. Complete replay verifies planning identity, exact goal/contract/mission/camp link, work graph and request hash, even after state progression. A changed command under the same key is a conflict. Do not create a second mission to resolve a mismatching replay. A previously active ready-goal contract is accepted only if it is exactly the shown ref; UI reloads after stale-understanding failure.
- [ ] Orchestrator start wrapper checks lifecycle/recovery, commits through that API, then wakes the existing planning supervisor. Kick failure returns `.committedWithVisibilityFailure(receipt, failure)`; retry repairs wake/refresh only. All provider dispatch occurs after transaction commit. A concurrent halt after commit can leave queued planning and a valid active goal; UI shows paused by global halt and restart uses normal recovery.

**Literal tests:**

```swift
@Test func startGoalCommitsContractMissionLinkAndPlanningAtomically() async throws
// contract.active; goal.active; mission.planning; work.queued
// exactly one squad/mission/link/planning work; link.ref == shown contract

@Test func linkFailureRollsBackEveryStartWrite() async throws
// inject at link stage: goal.ready; contract.draft
// zero new mission/squad/work/start events; operation remains retryable

@Test func replayAfterCrashReturnsSameMissionWithoutProviderResolution() async throws
// crash after commit before kick; replace resolver with throwing resolver
// replay => identical receipt; one mission; queued work may now be kicked

@Test func staleUnderstandingCrossCampAndChangedStartHashWriteNothing() throws
// all reject; input goal and contract heads unchanged

@Test func wakeFailureIsCommittedAndRetryDoesNotStartAgain() async throws
// committedWithVisibilityFailure; same mission/work IDs after recovery
```

Existing regression identities: `P1DOutcomeContractTests.activationRequiresExactConfirmedUnderstandingAndSnapshotRows`, `.codingActivationRequiresDeterministicRequirement`, `.goalReadyActivationRequiresActiveExactContractAndSameGoal`, `.goalMissionLinkIsCampExactCASAndCarriesContractRef` and manual/candidate/scheduled planning replay tests in their existing suites.

## C — Actual Outcome, verification, delivery, return and memory

**Files:** create `Sources/AgentLoopApplication/GoalOutcomeWorkflowController.swift`, `Sources/AgentLoopCore/Work/GoalOutcomeCollector.swift`, `Sources/AgentLoopCore/Work/DesktopCommandVerificationRunner.swift`, `Sources/AgentLoopApplication/OutcomeVerificationApprovalController.swift`; modify `Database/OutcomeStore.swift` for transaction-taking return/accept helpers and snapshot reads, `Database/AppDatabase.swift` to extract transaction-taking card rework implementation, `Kernel/Orchestrator.swift` for postcommit reconciliation, `DesktopGoalWorkflowStore.swift` for sealed verification/acceptance operations, and `AppStore.swift` event/boot reconciliation. Tests `GoalOutcomeWorkflowTests.swift`, `DesktopCommandVerificationRunnerTests.swift`, `OutcomeVerificationApprovalTests.swift`.

**Proposed interfaces:**

```swift
package struct GoalReturnRequestV1: Sendable {
    let operationId: String; let command: ReturnOutcomeCommandV1
    let card: GoalReworkCardHeadV1
}
package struct GoalReworkCardHeadV1: Sendable, Equatable {
    let cardId: String; let missionId: String
    let expectedStatus: CardStatus // .done for this action
    let latestRunId: String
    let handoffHash: String // canonical hash of persisted non-null handoff
}
// GoalOutcomeWorkflowController actor:
// reconcile(missionId: String, trace: OperationTrace) async
//   -> OperationCommitOutcome<OutcomeSnapshotV1>
// returnForRework(_:trace:) async
//   -> OperationCommitOutcome<AcceptanceCommitSnapshotV1>
// accept(_:trace:) async -> OperationCommitOutcome<AcceptanceCommitSnapshotV1>
// retryAcceptedMemory(acceptanceId: String, trace: OperationTrace) async
//   -> OperationCommitOutcome<CampNoteRecord>
```

`CardRecord` has no revision field. Seal and compare status, mission ID, latest run ID (ordered by attempt then ID) and canonical handoff hash in `GoalReworkCardHeadV1`. This prevents a stale return gesture from applying to a newer delivery without adding a fictitious card revision.

- [ ] Trigger reconciliation from a linked mission entering `.delivering` and on bootstrap for linked delivering missions, not from every UI refresh. Read mission/cards/artifacts/real successful producing runs together. Require nonempty valid manifest, same mission/camp, safe workspace-scoped readable regular files, actual producer/run provenance. Freeze file paths and real SHA-256 before recording. Do not create empty “outcome.txt” to satisfy delivery. Source text/card handoff remains explanatory text, not proof of successful verification.
- [ ] Collector uses `RecordInitialOutcomeCommandV1(envelope:outcomeId:goal:contract:missionId:producerActorId:runIds:manifest:)`. The final producing actor must come from actual engine/cow evidence and match `.engine`/`.cow` envelope authority. If multiple producers require aggregation, the selected final producing card/actor is explicitly designated as the delivery owner while all contributing run IDs remain included; do not pretend every artifact was made by an invented actor. Inconsistent or absent provenance blocks collection and shows the missing evidence.
- [ ] Seal collection ID/envelope/manifest/hash before committing; no rehash-and-replace under an existing idempotency key. Existing Outcome `.produced` advances with `BeginVerificationCommandV1`; an already delivered/accepted unchanged version is a read/revalidate path, not a new Outcome. Returned/revoked/invalidated/failed/blocked outcomes with genuinely new completed producing run IDs and manifest evidence use `RecordNewOutcomeVersionCommandV1`. A failed verification of the same runs/manifest offers explicit verification retry and never invents a new version. Old successful verification never transfers across a version/hash change.
- [ ] Add a narrow verification-attempt approval controller, not `ApprovalGateHandler` on a done producer. Store ownerKind `verificationAttempt` rows in the existing journal. Capability is fixed `outcome.verify.command.v1`; binding hash canonically covers attempt ID, exact outcome/contract/version/hash, requirement ID/version/hash, argv, validated workspace identity/bookmark hash, environment-policy hash, timeout and expiry. Record the current dispatch generation in the one-shot dispatch receipt/reservation, not in the durable approval hash, so an approved-but-never-dispatched attempt can be revalidated after restart. Classify command as dangerous using existing `ToolDef.risk("run_shell")`; this adapter requires an explicit local-owner approval for each process attempt in this slice, including free-mode missions, and labels that verification-specific choice before start. There is no policy grant or inherited card grant. Read-only artifact hashing needs no process approval. Do not manufacture a verification card/run or suspend a completed producer; existing card-only external-operation APIs cannot represent this owner and are not called.
- [ ] Define `OutcomeVerificationApprovalController.prepare(binding:trace:)`, `decide(attemptId:expectedVersion:bindingHash:approved:envelope:trace:)`, and `dispatchApproved(attemptId:expectedVersion:trace:)`. Persist append-only attempt states awaitingApproval→approved/denied; approved→dispatching→completed/ambiguous. `decide` checks user/local-owner/device authority, exact hash/versions, live camp, current Outcome/requirement and explicit decision; approval expiry is 15 minutes. `dispatchApproved` atomically CAS-consumes approval once and records a unique dispatch token before launching, after rechecking expiry/heads/workspace/context/halt. A denial is terminal for that attempt, not a provider failure; retry creates a new attempt and approval. Restart while approved but never dispatching can revalidate and dispatch once; restart in dispatching with no complete evidence is ambiguous and cannot relaunch. A new explicit retry warns that the previous process may have run and gets a distinct attempt. Revocation/halt invalidates launch reservations and cancels/joins running children. This is a one-shot approval/dispatch owner in the two-table carrier, not a generic permission framework.
- [ ] Define immutable `VerificationRunnerContextV1(attemptId:dispatchToken:bindingHash:workspace:environmentPolicyHash:evidenceDirectory:)` and `ValidatedVerificationWorkspaceV1(resolvedURL:bookmark:bookmarkHash:directoryIdentityHash:)`. `DesktopCommandVerificationRunner.init(context:processRunner:)` receives them; `P1DProcessRunner.run(_ request:)` cannot obtain cwd from its existing request, so always uses `context.workspace.resolvedURL`. Validate request argv/environment/timeout hash against the approved binding. Resolve supplied bookmarks strictly using Foundation: stale, corrupt, path-disagreeing or inaccessible bookmarks fail visibly; never use `WorkspaceScopedAccess`'s documented silent path fallback. When no bookmark exists on this unsandboxed build, validate the explicitly selected path and stable directory identity instead. Acquire security scope where applicable immediately before process start, check canonical directory identity again, and release only after child termination/join in every success/error/cancel path. Workspace changes require new approval.
- [ ] Implement the runner with the repaired bounded process primitive. Run argv directly with explicit cwd; no interpolated shell. Use an allowlisted explicit environment (PATH and user-visible approved variables), never inherited credentials. Preserve exact exit status/stdout/stderr/timedOut and include all in evidence. Arbitrary command side effects outside cwd are not prevented by cwd alone; the approval shows argv/workspace and existing workspace/process restrictions still apply. Do not describe this unsandboxed runner as a filesystem sandbox.
- [ ] Persist `VerificationEvidenceEnvelopeV1` as canonical immutable JSON bytes under the app-owned per-outcome evidence directory: complete approved binding/workspace identity, request, process result, start/end, dispatch token, and `commandEvidenceHash` returned by `CommandExitVerifier`. `RecordVerificationCommandV1.evidenceHash` is SHA-256 of those exact persisted envelope bytes, and `rawResultRef` points to that file. This is intentionally distinct from the verifier's inner request/result hash; store both and test both. Use atomic write before receipt commit. `CommandExitVerifier` maps timeout to `.blocked`, nonzero to `.failed`, no exit status to `.invalid`; never remap to passed. Requirement identity and actor remain exact. Artifact integrity and command correctness stay separate requirements.
- [ ] A process may end before its receipt is stored. Seal a verification attempt in the operation journal before launch and persist completion evidence before domain commit. On restart: existing valid evidence is committed idempotently; an interrupted attempt with no complete evidence is shown as interrupted/blocked and requires explicit retry before rerunning a potentially mutating command. Do not infer a successful exit or automatically rerun an ambiguous process. Hash-only read checks can be rerun safely.
- [ ] Call `markDelivered(MarkDeliveredCommandV1)` only after reducer returns `.verified`; it revalidates the manifest. On acceptance, additionally rehash current files and invalidate stale verification before presenting/committing acceptance if content changed since delivery. Existing domain acceptance validates reference/reduced verification but should not be treated as proof that an external file cannot have changed. Serialize snapshot/hash/commit as far as possible; document unavoidable external-file TOCTOU and bind accepted receipt to the exact stored content hash. Do not report that the current filesystem is permanently frozen.
- [ ] Return is one transaction: validate exact Outcome/selected card head, call transaction-taking `OutcomeStore.returnOutcome`, then transaction-taking existing `AppDatabase.returnCardForRework`, then journal receipt. Require nonempty reason before any write. Existing AppDatabase implementation silently returns on blank reason and uses `try?` for handoff decoding; the new boundary rejects blank reason and rejects malformed non-null handoff with an observable typed error. Do not silently alter unrelated legacy callers. After commit, Orchestrator emits/reconciles once; failure is committed with visibility failure. Outcome remains `.returned`, selected card `.ready`, mission rolls to execution; new completion produces a new Outcome version.
- [ ] Accept uses existing `AcceptOutcomeCommandV1` with actor local-owner/device identity and fixed acceptance UUID/key. On successful atomic acceptance, create/update an immutable generated camp note ID derived from the acceptance ID, title from goal, body with exact goal/input/contract/outcome/acceptance IDs, artifact references and criteria. `CampNoteRecord` supports campId/missionId/title/bodyMd. Use insert-if-absent and reject hash mismatch; never overwrite a user's edited note. If note was deliberately deleted, don't recreate it on every bootstrap: a committed memory operation receipt distinguishes “already projected” from “needs repair”. The return UI says accepted even if memory projection fails, with separate “成果已验收，营地记录待恢复”. On acceptance revocation/return, preserve the historic note and append a truthful status update/reference via a new event-derived note; don't leave it appearing as current active acceptance.

**Literal tests:**

```swift
@Test func realArtifactAndIndependentCommandProduceDeliveredOutcome() async throws
// temp file actual hash; executable fixture writes stdout and exits 0
// produced -> verificationPending -> verified -> delivered
// rawResultRef exists; evidence hash matches; verifier != producer

@Test func cardDoneWithoutArtifactOrProducerCannotDeliver() async throws
// zero Outcome writes; visible collection failure, canAccept == false

@Test func failingTimedOutAndCanceledVerificationNeverPass() async throws
// exit 7 => verificationFailed; timeout => blocked; canceled => blocked
// markDelivered throws; accept throws; no accepted metric

@Test func changedArtifactAfterDeliveryInvalidatesAcceptance() async throws
// mutate file after delivered; user accept => no acceptance record
// visible changed-file evidence; fresh verification required

@Test func returnAndReworkAreAtomicAndNewVersionRequiresFreshProof() async throws
// return failure injection: no acceptance-return or card state changes
// success: outcome.returned; card.ready; one feedback event
// restart replay: one rework only
// new run: outcome.version == old + 1; verificationPending, not delivered

@Test func acceptedOutcomeAndFailedMemoryHaveSeparateRetrySemantics() async throws
// accept: outcome.accepted; goal.achieved; mission.accepted; metric count 1
// injected note failure => accepted plus memory failure
// retry note twice => exactly one note; acceptance/metric count still 1

@Test func interruptedVerificationDoesNotRerunAmbiguousCommand() async throws
// restart with prepared attempt/no final evidence: runner invocations == 0
// state blocked; explicit retry creates distinct attempt, never passed by inference

@Test func verificationApprovalIsScopedDeniedExpiredAndOneShot() async throws
// denied => zero dispatches; expired => zero dispatches
// change outcome hash/requirement/argv/workspace/env => stale approval, zero dispatches
// approved before restart => revalidate then one dispatch; duplicate dispatch CAS fails
// restart after dispatching marker => ambiguous, zero automatic relaunches
// completed producer card/run status unchanged by approval waiting/denial
@Test func verificationWorkspaceAndEvidenceBindActualProcess() async throws
// runner initialized with validated cwd; fixture prints cwd; evidence matches it
// stale/corrupt/mismatched bookmark => failure before dispatch, no path fallback
// success/error/timeout/cancel all join child then release security scope
// RecordVerification.evidenceHash == sha256(exact persisted envelope bytes)
// nested commandEvidenceHash == CommandExitVerifier's request/result hash
```

Also exercise producer/verification identity mismatch, wrong-camp manifest, symlink/path escapes, stale acceptance aggregate versions, output-file partial writes, cancellation joins, preserved old artifact versions, and user-edited/deleted memory-note behavior. These tests use isolated files and executable fixtures only.

## D — Default SwiftUI composition and application state

**Files:** create `Sources/AgentLoopApp/GoalWorkflowStoreAdapter.swift`, `Sources/AgentLoopApp/Views/CodingRanch/GoalWorkspaceView.swift`; modify `CodingRanchContracts.swift`, `AppStore.swift`, `Views/RootView.swift`, `Views/CodingRanch/CodingRanchHomeView.swift`, `CodingRanchLiveHosts.swift`, `ReturnSummaryView.swift`, and `CodingRanchStoreAdapter.swift`; test pure presentation reducers in `Sources/AgentLoopTestSuite/DesktopGoalPresentationTests.swift` and update `CodingRanchTests.swift` fixtures that instantiate changed view contracts.

- [ ] Add `Destination.goal(inputId: String)` and a visible per-camp goal list. Input identity works before a GoalController exists and remains stable after conversion. Home primary hero is goal text + “与教练梳理”; secondary “添加知识资料” opens the current FeedComposer with its existing callbacks. Keep old missions visible in mission history; don't relabel old feed items as Goals or migrate them speculatively.
- [ ] Add adapter `loadGoal(inputId:)`, scoped submit/answer/revision/confirm/start/return/accept wrappers. AppStore owns one projection per selected input/camp and rejects stale completion results by scope and generation. Use persisted snapshot for status; local booleans represent only in-flight gestures. Each mutation disables its duplicate button, but journal idempotency remains the real protection. Empty input and unsupported/missing runtime get concrete inline errors with settings route; neither spins forever.
- [ ] GoalWorkspace shows original input, state, one open question with recommendation/reason, editable understanding fields, and visible scope/acceptance/verification details. Input capture is useful without credentials. No fake coach transcript appears while waiting for config. Revision drafts are scoped by input and saved before a submitted correction begins; switching camps cannot mix text. Confirmation buttons bind the exact displayed version/hash.
- [ ] After understanding confirmation, show contract draft plus workspace picker, companion/runtime choices, budget/autonomy and verification command. Require explicit workspace for Coding. “确认并开始” calls B and opens the returned mission; committed-with-visibility-failure shows the mission receipt and recovery action. Never reset the draft/create another command on a kick failure.
- [ ] Reuse Mission view and real pending-request/engine/cow status. Add goal/contract breadcrumb. Goal list attention counts come from persisted coach question/confirmation, execution request, verification failure, and deliverable Outcome; do not add all of those blindly to existing legacy counters and double-count one mission.
- [ ] ReturnSummary uses new Outcome-specific state for linked missions: artifact list with real paths/hash identity, verification requirements/evidence, accepted/returned history, exact available actions. CanAccept is true only for delivered current Outcome with valid current evidence, active goal, delivering mission; the action revalidates through C. For legacy unlinked missions, keep existing closeout behavior and accurately labeled legacy evidence.
- [ ] Return button requires reason and completed-card selection. Offer actual failed/interrupted verification retry distinctly from “退回重做”. Acceptance success routes to camp result; memory pending remains visible. Error UI includes safe trace ID and explicit retry/refresh action; not a generic success toast followed by navigation.

**Literal presentation expectations:**

```swift
@Test func defaultGoalEntryPreservesKnowledgeRoute()
// primaryAction == submitGoal; secondaryKnowledgeAction == openFeedComposer
// existing ingestion/mission IDs unchanged
@Test func coachWaitingAndDraftAreNotExecution()
// waitingForUser => one answer action, no start/accept
// awaitingConfirmation => confirm/revise, no running claim
@Test func linkedMissionNeedsDeliveredOutcomeToAccept()
// mission.delivering + all cards.done + no outcome => canAccept false
// outcome.verificationFailed/blocked => canAccept false
// outcome.delivered + exact valid heads => canAccept true
@Test func committedVisibilityFailureKeepsMissionIdentity()
// start receipt still links to same mission; retry action == refreshOrWake
@Test func oldCampLoadCannotOverwriteNewCampSelection()
// stale async response leaves current camp/input/projection untouched
```

## Verification and bounded handoff

- [ ] During each chunk, add the named test cases, observe the intended failure, implement the boundary, then run that suite using the already observed `swift run RunTests --filter <test-name>` form. Never use `--help`: this standalone SPI runner ignores it and starts tests; the aborted inspection is recorded in `runtime-repair-plan.md`. Expected new suite names are `DesktopGoalWorkflowTests`, `LLMCoachTurnProviderTests`, `DesktopGoalMigrationTests`, `GoalMissionStartTests`, `GoalOutcomeWorkflowTests`, `DesktopCommandVerificationRunnerTests`, `OutcomeVerificationApprovalTests`, `DesktopGoalPresentationTests`. Redirect complete stdout/stderr to a unique file and record the actual test exit status. Do not guess or invent shell filter flags in evidence logs.
- [ ] Run existing `P1CGoalCoachContractTests`, `P1DOutcomeContractTests`, `AcceptanceWorkflowTests`, `CodingRanchTests`, and affected migration/planning/halt/workspace suites; exact runner-discovered names govern any filter. Required existing coach tests include `coachWorkerRestartAdoptsInterruptedTurn`, `coachWorkerCancellationLeavesRecoverableRunningWork`, `understandingEditAlwaysCreatesNewVersion`, `coachRestartRestoresExactlyOneOpenQuestionWithoutChatMemory`, and `goalAbandonAndFailCancelActiveControlWorkAtomically`.
- [ ] Run unfiltered `swift run RunTests`, then `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`. Any red/unknown failure blocks acceptance; a filtered pass does not replace these results.
- [ ] Parent packages and launches the actual `.app` with an isolated state directory, exercises goal input/question/revision/confirmation and fixture execution/verification/accept-return states, checks restart, resources/helper/signature and readable error recovery, and records which interactions used fixtures. Real-provider acceptance remains a separate authorized user step.
- [ ] Update task impl-report with exact changed files, migration identity, full output paths, verified states, deviations, unimplemented edges and source/artifact identity. Obtain independent review of core transactions/lifecycle/privacy and the user flow. The output is an installable acceptance candidate, not a declaration of user or P2 acceptance.

## Self-review notes for the parent

The principal remaining risk is scope size: A/B/C are necessary backend integrations, not just UI polish. Keep these four chunks separate for review but do not declare the default path complete after A or D alone. Schema carrier addition and transaction-taking overloads deserve review before implementation. The limited new schema is justified by persisted runtime/correction/operation identity absent from existing contracts; it must not silently escape retention rules. The plan intentionally avoids introducing a new provider, planner, execution engine, acceptance policy, or generic workflow system.

Source inspection found the actual return-to-card seam and the supported-planning-profile limitation. No code, build, test, app or Provider execution was performed in producing this document.

## Review amendment mapping — 2026-09-05

The five findings in `goal-flow-plan-review.md` are addressed in this document only; source remains unchanged and implementation acceptance remains pending:

1. **Exact eligibility/claim:** A adds carrier-owned exact claims plus runClaimed extraction, tagged unconfigured runtime, explicit versioned consent/context command and prelaunch recheck. Three tests cover two-goal isolation, context-selection race and revoke-before-launch; unrelated parser items and zero attempts across restart are asserted.
2. **Verification permission/workspace/evidence:** C2 adds one narrow journal-backed approval/dispatch owner with denial/expiry/ambiguous-restart rules, strict immutable runner workspace context, and distinct envelope versus inner command evidence hashes. Two tests cover approval scope/restart and actual cwd/bookmark/lifecycle/hash behavior. No completed producer is passed to a card approval wrapper.
3. **Actual input retention:** migration adds nullable payload/redacted terminal constraints; only InputGoalStore.cancelParsingAndDelete and completeDeletion gain same-transaction carrier hooks. Deleted presentation is typed; goalCreated deletion remains unsupported. Two tests cover both tombstone points, rollback and redacted restart/no raw JSON retention.
4. **Coach accounting:** separate pre-coach policy plus workId/attempt receipts, checked sums, retry reservations, bounded full request, uncertain terminal handling and explicit one-turn continuation. Current default-zero Provider usage is always labeled unproven. Two tests cover duplicate/restart/unknown usage and overflow/request bounds; no exact total-token guarantee is claimed.
5. **Sealed dependent stages:** original intent is immutable; actual later heads are sealed stage-by-stage with CAS and predecessor receipts. Submit/answer/revision/system-confirmation completion points release the user slot; stale sealed stages require explicit resolution. Two tests cover every restart boundary and conflict/no duplicate goal. B also blocks starting a prior confirmed head while its revision is pending.

Task count remains 10 and owners/build dependencies remain unchanged. Review only these deltas and their interactions with the existing two-carrier design; no extra product approval or unrelated feature expansion is requested.
