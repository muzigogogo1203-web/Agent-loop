# Management implementation plan

2026-09-05. Three tasks only; supersedes implementation suggestions in `management-scope.md` where more specific. This is a plan, not execution evidence. No code/build/test/app/data operation occurred while preparing it. Serialize shared `AppStore.swift`/`RootView.swift` edits with the main goal implementation. Enter implementation only after the parent execution-base gate and plan review permit it.

## Task 1 — Preserve committed/pending camp command outcomes

Production files: `Sources/AgentLoopApplication/CampManagementState.swift` (new, narrowly scoped state helper), `Sources/AgentLoopApp/AppStore.swift`, `Sources/AgentLoopApp/Views/RootView.swift`. Existing controller contracts remain: `InputWorkflowController.createCamp(name:guidePrompt:trace:)` and `setCampArchived(id:archived:trace:)` return `OperationCommitOutcome<CampRecord>`.

API/data:

```swift
package struct CampCreationDraft: Sendable, Equatable {
    package var name: String
    package var guidePrompt: String
}
package enum CampManagementAction: Sendable, Equatable {
    case create
    case archive(campId: String, archived: Bool)
}
package struct CampManagementState: Sendable {
    package var creationDraft: CampCreationDraft
    package private(set) var creationPending: Bool
    package private(set) var pendingCampIDs: Set<String>
    package private(set) var creationFailure: UserVisibleFailure?
    package private(set) var campFailures: [String: UserVisibleFailure]
    package mutating func begin(_ action: CampManagementAction) -> Bool
    package mutating func finish(
        _ action: CampManagementAction,
        outcome: OperationCommitOutcome<CampRecord>
    ) throws
}
```

`begin` returns false for an already pending action and leaves its failure/draft untouched. Different archive/restore actions for the same camp share the pending key. `finish` requires a matching pending action; an impossible completion throws the existing projection-contract error, not silent success. Noncommit retains the creation draft and safe failure; commit clears it; committed visibility failure clears the draft and preserves its warning. The helper is stored as a value in observable AppStore and is the actual state bound by RootView, not a parallel testing-only model. New-sheet dismissal resets a draft only on explicit user cancel before submission or after commit. Disable cancel/interactive dismissal during submission; this does not add transactional cancellation.

AppStore's create/archive wrappers return the controller's full `OperationCommitOutcome<CampRecord>` instead of `CampRecord?`/`Bool`. The initiating UI acquires `begin` synchronously before creating its Swift Task, then awaits the wrapper and applies `finish`; duplicate button/keyboard input cannot launch a second wrapper. RootView derives navigation/dismissal from committed cases, never failure. AppStore upserts the committed camp and preserves warning visibility. Archive/restore rows disable and display pending state from `pendingCampIDs`; selection changes only after commit. No new persistence write or create-idempotency storage is required. Ensure every exceptional exit resolves pending state through a reported noncommit; wrappers themselves remain nonthrowing typed outcomes.

Production-observable red tests, in new `Sources/AgentLoopTestSuite/CampManagementStateTests.swift` plus the existing controller harness in `ApplicationWorkflowTests.swift`:

1. `campCreateNoncommitKeepsDraftAndReleasesPending`: enter the production state helper with name/prompt, call the real controller with a fixture create port that fails, finish its actual outcome; assert draft equality, safe failure+trace, no returned committed camp, no extra camp row, pending false. Current immediate-dismiss flow cannot preserve this production state.
2. `campCreatePendingRejectsSecondSubmission`: use a continuation/latch to hold an injected command between begin and finish; attempt a second begin through the same production helper; assert false, mutation invocation count exactly one, pending stays true until release. No sleeps.
3. `campCreateCommittedVisibilityFailureDoesNotOfferCreateRetry`: finish with a committed camp plus visibility failure; assert draft cleared, warning retained and caller uses the committed camp ID. Then reload the existing camp, never invoke create as warning recovery. This outcome is fixture-supplied because the current controller normally has no postcommit visibility step; do not invent one merely to reach this branch.
4. `campArchiveRestoreSharePendingKeyAndPreserveNoncommitSelection`: pending archive rejects restore for that same ID, permits a different ID; controller failure leaves original camp archived flag/selection input unchanged, finish enables retry. Commit selects/restores the returned ID through the production UI outcome handling; verify selection/dismissal with isolated UI later rather than claiming the state test proves rendering.

Green handoff requires these executable state/controller tests and later isolated UI checks showing retained draft after failure, no duplicate camp, archive impact confirmation, successful restore, and visible blocker. Preserve `CowResidencyContractTests` p1e24–27 and existing cow-removal UI; no new retirement code.

## Task 2 — Actionable rumination preflight and shared retry pending state

Production files: new `Sources/AgentLoopApplication/RuminationStartPreflight.swift`, `Sources/AgentLoopApplication/InputWorkflowController.swift`, `Sources/AgentLoopApp/AppStore.swift`, `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`, `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`, `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`, `Sources/AgentLoopApp/Views/RootView.swift`; **required** `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift` for the shared blocker error and `Sources/AgentLoopCore/Observability/FailureRecord.swift` for exhaustive safe `FailureClassifier` mappings. Keeping the error in Core avoids a Core-to-Application dependency cycle.

API/data:

```swift
// In Core/Ingestion/IngestionRecords.swift:
package enum RuminationStartBlocker: String, Error, Sendable {
    case campProjectionMissing, runtimeProjectionLoading
    case defaultProfileMissing, modelUnavailable, cliProfileUnsupported
}
// Remaining types in Application/RuminationStartPreflight.swift:
package enum RuminationRuntimePreflightInput: Sendable, Equatable {
    case loadingOrMissing
    case failed(UserVisibleFailure)
    case loaded(LegacyRuminationStartupSnapshot)
    package init(state: WorkflowLoadState<RuntimeWorkflowSnapshot>)
}
package enum RuminationStartResolution: Sendable, Equatable {
    case ready(campId: String, runtime: InputRuminationRuntimeSelection)
    case blocked(RuminationStartBlocker)
    case runtimeLoadFailed(UserVisibleFailure)
}
package enum RuminationStartRecoveryAction: Sendable, Equatable {
    case reloadCamp, reloadRuntime, openSettings
}
package enum RuminationStartRecoveryReason: Sendable, Equatable {
    case preflight(RuminationStartBlocker)
    case runtimeLoadFailure
    case committedVisibilityFailure
}
package struct RuminationStartRecoveryMetadata: Sendable, Equatable {
    package let reason: RuminationStartRecoveryReason
    package let action: RuminationStartRecoveryAction
}
package struct RuminationStartPresentationResult: Sendable {
    package let outcome: OperationCommitOutcome<InputRuminationStartReceipt>
    package let recovery: RuminationStartRecoveryMetadata?
}
package func resolveRuminationStart(
    campId: String?, runtime: RuminationRuntimePreflightInput
) -> RuminationStartResolution
// New overload on InputWorkflowController; old valid-command method stays intact:
package func startRumination(
    ingestionId: String, expectedCampId: String?,
    runtime: RuminationRuntimePreflightInput, trace: OperationTrace
) async -> RuminationStartPresentationResult
```

`RuminationRuntimePreflightInput.init(state:)` maps actual `.idle/.loading` to `.loadingOrMissing`, `.failed(failure)` to `.failed(failure)`, and **only** `.loaded(snapshot)` to `.loaded(snapshot.legacyRuminationSnapshot)`. AppStore constructs this from `runtimeProjection.state` at submission; it never reads `lastLoadedValue` to authorize start. A retained valid snapshot during refreshing/failed state is display history only and cannot dispatch. The constructor is the same production bridge called by behavioral tests.

Resolve runtime `.failed` first: return `.runtimeLoadFailed` with the **existing** failure unchanged, including message, trace, operation and scope. Controller returns `.notCommitted(existingFailure)` and metadata `.runtimeLoadFailure/.reloadRuntime`, without reporting it again. `.loadingOrMissing` produces `.runtimeProjectionLoading/.reloadRuntime`. For loaded runtime, missing camp produces `.campProjectionMissing/.reloadCamp`; otherwise legacy unresolved profile -> `.defaultProfileMissing/.openSettings`, unavailable model -> `.modelUnavailable/.openSettings`, unsupported CLI -> `.cliProfileUnsupported/.openSettings`; only loaded `.valid` with a known camp reaches unchanged profile/model dispatch. No settings switch or automatic retry follows a blocker.

Ordinary preflight blockers are captured by the existing reporter with the one generated `.inputRuminationStart` trace, returning noncommit plus `.preflight(blocker)` and its typed action. `FailureClassifier` must explicitly cover all five Core blockers using existing codes: camp missing/runtime loading -> `.ruminationStartFailed`, retryable true, safe messages respectively “营地资料尚未载入，请重新载入营地后再开始反刍。” and “运行配置尚未载入完成，请重新载入运行配置后再试。”; default missing/CLI unsupported -> `.runtimeProviderUnavailable`, retryable false, safe messages respectively “请先在设置中选择默认供给线。” and “当前命令行供给线不支持反刍，请在设置中选择受支持的供给线。”; model unavailable -> `.runtimeModelUnsupported`, retryable false, safe message “当前反刍模型不可用，请在设置中选择可用模型。” Use existing diagnostic categories/domains; no new schema or secret-bearing diagnostics. No blocker may fall into `.unexpectedFailure`. Existing runtime-load failures bypass these mappings and retain their original classified record.

For `.ready`, the overload invokes the existing valid-command controller method and wraps its unchanged `OperationCommitOutcome`. `.committed` has no recovery; `.committedWithVisibilityFailure` has `.committedVisibilityFailure/.reloadCamp`, including when the receipt already contains a refreshed snapshot, and retains the work identity. Ordinary downstream `.notCommitted` retains its original failure with no invented preflight metadata. `OperationCommitOutcome` and `UserVisibleFailure` themselves do not acquire fields or change semantics. AppStore consumes `RuminationStartPresentationResult` directly, applies its outcome as before, and stores the returned typed recovery alongside the displayed failure for both inbox/detail. UI must never infer recovery authority from localized message strings. All start paths enter this reported boundary rather than throwing generic preflight errors in AppStore.

Detail failed Retry reads `ruminationActionInFlightIds`, shows “正在重试…”, and disables just like inbox. Keep the existing store-level guard and shared `retry -> start` path. Thread typed recovery callbacks through live hosts and error panel: openSettings uses RootView's settings destination; reloadRuntime uses the existing runtime projection refresh; reloadCamp uses the known ingestion camp or the currently displayed camp when recovering its missing mapping and never switches to another camp. All reload actions are read-only projection recovery; **none calls start**. Committed visibility failure remains “started, refresh failed”. Failure trace remains visible. Do not generate a new phase when durable work identity is unavailable.

Production-observable red tests in `ApplicationWorkflowTests.swift` (fixture ports with invocation recorder) and focused `RuminationStartPreflightTests.swift`:

1. `ruminationPreflightBlockedNeverCallsStartPort`: table test all five blockers through the production controller overload consumed by AppStore. Assert `result.outcome` is `.notCommitted`, the same generated start trace is persisted, safe message/code/retryability match the explicit classifier mapping (never unexpected failure), `result.recovery` exactly equals expected reason/action, and start-port invocation count is zero. These are assertions on the actual presentation result, not a separate UI-only model.
2. `ruminationFailedRuntimePreservesOriginalFailureAndNeverDispatchesStaleSnapshot`: load a valid `RuntimeWorkflowSnapshot` into the real `WorkflowProjection`, begin refresh, then apply a `.failed` terminal using an existing reported runtime failure with a distinct trace. Confirm `lastLoadedValue` is still valid, construct input via production `init(state: projection.state)`, and call the controller. Assert `.notCommitted` carries the exact original failure/operation/scope/trace/message, metadata is `.runtimeLoadFailure/.reloadRuntime`, start count zero, original failure record retained, and no replacement `.inputRuminationStart` record was created for it.
3. `ruminationRefreshingRuntimeNeverDispatchesRetainedSnapshot`: start from loaded valid projection, call `beginRefresh` leaving retained value present, bridge its actual state and call controller; assert the reported runtime-loading blocker, `.reloadRuntime`, and zero start calls. Also exercise initial idle state through the same bridge. This catches using `lastLoadedValue` even without a failure.
4. `ruminationPreflightValidPreservesRuntimeAndCommitReceipt`: bridge a currently `.loaded` valid projection, assert exact camp/profile/model passed once, committed refreshed snapshot returned, and recovery nil; no Provider invoked by fixture tests.
5. `ruminationCommitRefreshFailureIsCommittedAndReloadDoesNotRestart`: start port returns work, read port fails; assert result's unchanged committed-visibility outcome, same work identity, and exact `.committedVisibilityFailure/.reloadCamp` metadata. Recover read through normal camp load, assert start count remains one. Test uses the same result consumed by production recovery UI; later isolated UI verifies that clicking reload uses this path.
6. Preserve existing executable durable atomic/replay/cancel/recovery coverage. Retry control busy/disabled behavior is verified via isolated app interaction with controlled delayed port; do not replace that with source-text matching. No duplicate guard framework is needed for an existing working guard.

## Task 3 — Persisted, camp-scoped shared cow activity

Production files: new `Sources/AgentLoopCore/Product/CowActivityProjection.swift`; `Sources/AgentLoopCore/Database/AppDatabase.swift` (`InputCampReadBundle`, atomic `readInputCampBundle`); `Sources/AgentLoopApplication/InputWorkflowController.swift` (`InputCampSnapshot`); `Sources/AgentLoopApp/CodingRanchContracts.swift`, `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`, `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`, `Sources/AgentLoopApp/AppStore.swift` (existing event refresh). No schema change.

Core data, scoped to one camp:

```swift
package enum CowActivityState: Sendable, Equatable {
    case idle, planning, working, blocked, waitingForUser, pending
}
package struct CowActivitySnapshot: Sendable, Equatable {
    package let cowId: String
    package let campId: String
    package let state: CowActivityState
    package let missionId: String?
    package let missionTitle: String?
    package let cardId: String?
    package let cardTitle: String?
}
// New field on InputCampReadBundle and InputCampSnapshot:
package let cowActivityById: [String: CowActivitySnapshot]
```

Within the same read transaction, load all active missions joined through `squad.campId = requestedCampId` (planning/executing/delivering), their assignee cards, and squad member IDs. Do not derive from the existing newest-50 mission list. Eligible IDs are exactly the returned active regular-companion roster; retired cows remain absent. Card evidence requires that mission/squad camp join; shared global companions do not permit another camp's title to leak. Decode squad membership with throwing JSON decoding; invalid projection fails the read, not a fabricated idle state.

Derivation precedence per cow: running assigned card in executing mission -> working; otherwise blocked assigned card in executing mission -> blocked; otherwise participating in delivering mission -> waitingForUser; otherwise planning squad membership -> planning; otherwise assigned ready/todo card in executing mission -> pending; otherwise idle. For delivering participation, require squad membership or an assigned card. Competing evidence picks precedence first, then mission.createdAt descending, card.createdAt descending when present, then lexical mission/card IDs. These records have **no updatedAt**; do not invent an activity timestamp or label creation time as last activity. Blocked presentation uses a safe fixed summary and linked card title, not unfiltered `blockedReasonJson`. `.pending` receives an honest awaiting-execution label; extend `CowStatusViewState`/label exhaustiveness if needed rather than calling it working/idle.

Project one `[CowSummaryViewState]` from this dictionary into the per-camp dashboard/cache and use that same array for `CowRosterHost`; remove its independent global-companion hardcoded idle mapping. Dashboard chooses the highest-ranked nonidle cow with deterministic ID tie-break, otherwise first idle. `recentMission` derives from selected persisted mission title; `lastActivity` is a status description, not a fabricated event. Read failures remain the existing load failure state, preserving stale data as stale rather than claiming idle.

Refresh in `handleKernelEvent`: mission planning/completion/change and card terminal/status transitions invalidate/refresh the affected visible camp projection before guards limited to `currentMissionId`. Resolve ownership via existing mission/squad/card read APIs; no cross-camp makeVisible switch. Do not refresh on every text/token event. Opening/reopening roster always loads the projection. Existing projection generation guards remain authoritative against stale completion.

Production-observable red tests in new `Sources/AgentLoopTestSuite/CowActivityProjectionTests.swift` using isolated GRDB fixtures and the actual `readInputCampBundle`/`InputWorkflowController.loadCamp`:

1. `cowActivityReadsAssignedRunningCard`: insert active roster cow, owned executing mission and running assigned card; returned activity must be working with exact mission/card IDs. Baseline hardcoded idle cannot satisfy this.
2. `cowActivityIncludesOldActiveMissionBeyondRecentFifty`: insert one older active mission plus 51 newer terminal missions; recent list may omit old mission but activity still names it.
3. `cowActivityDoesNotExposeSharedCowOtherCampWork`: same global companion, two camps, work only in B; A idle/no B IDs or titles, B working. Retired identity excluded from both roster and activity.
4. `cowActivityUsesDeterministicPrecedenceAndPending`: table fixtures cover all six states and conflicting running/blocked/planning evidence in reversed insertion order; exact stable selection, no assumption that test-cow identity means validating.
5. `cowActivityReloadReflectsCardAndMissionTransition`: obtain actual controller camp snapshot; update owned card running -> blocked, reload; then mission -> delivering, reload; then accepted, reload; assert working -> blocked -> waitingForUser -> idle and IDs coherent. This proves read/state evolution; isolated UI later proves event listener actually invokes refresh and both dashboard/roster change without reopening.
6. `cowActivityMalformedMembershipFailsProjection`: malformed squad membership produces failed controller load with trace, not an empty/idle success. Preserve existing atomic read/concurrent writer test when adding fields; fixture initializers explicitly supply activity so no default silently hides missing implementation.

## Completion and fixed exclusions

For each task record red/green output from executable production-path tests, final files, deviations and unresolved concerns. No source-string-only tests count as behavioral evidence. Parent subsequently runs the default unfiltered `swift run RunTests`, strict app build, isolated interaction checks and independent review, then packages matching source. Do not call focused tests, reducer tests or source inspection visual/live acceptance.

Permanent camp deletion remains sealed: no button pretending archive deletes data, no capability bypass, no cascade or new deletion work. Candidate documentation explicitly says archive/restore are supported, custom-cow removal retains history and is guarded, permanent camp deletion is unavailable. Retain existing ingestion-deletion same-handle preview/confirmation/resolution contract and Sept 1 timestamp regression. No real deletion, Provider use, release or unrelated feature is authorized by this plan.
