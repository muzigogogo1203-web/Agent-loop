# Management and rumination closure: source scope

2026-09-05. Read-only source inspection plus this plan artifact only. No build, test, app launch, screenshot, live UI observation, real database read, or data mutation was performed for this assessment. Parent task owns execution gates. This plan does not declare a stage accepted.

## Existing contracts to preserve

- `InputWorkflowController.startRumination` (around line 1354) returns `InputRuminationStartReceipt(work, refreshedCamp)`, distinguishing noncommit from committed visibility failure. `AppStore.executeRuminationCommand` applies the receipt; `CodingRanchStoreAdapter.startRumination` shares an ingestion-ID in-flight guard with retry. Inbox queued/retry controls show progress and disable themselves. The Aug 31 projection fix is present; do not rewrite the durable start protocol. `DurableWorkTests.swift` already covers atomic start, replay, conflict, replacement, cancellation and startup recovery.
- `RootView.swift` already contains a persistent new-camp row, archive context/menu entry, archive impact confirmation, and an archived section with restore. `AppDatabase.setCampArchived` preserves history and blocks active missions, enabled schedules, ruminating items and active rumination work. Archive is not deletion.
- Permanent camp deletion is **not an available execution contract**: `DurableWorkStore.swift:1221` and `:1236` reject ordinary camp-deletion creation with `CampDeletionRequiresRetirementCapabilityError`; engine paths use `deferCampDeletion`. Do not expose a working permanent-delete button, invent a cascade, or repurpose archive. Explain this limitation in candidate instructions; a permanent-delete implementation is outside this closure.
- `CompanionEditorView.swift:209` already offers confirmed remove-from-herd; `:403` excludes nonregular, base and test cows. `CowResidencyStore.retireCow` additionally blocks active mission membership/assignment, enabled schedules, and requested/authorized residencies, then revokes eligible residency and retires identity while retaining companion/history. Replays preserve retirement. Do not turn this into hard deletion or automatic task/schedule cancellation.
- Sept 1 timestamp normalization is present in `IngestionDeletionStore.swift`; keep it and `p1e68aDeletionModernCanonicalEnvelopeCommitsPersistedGraph`. Existing source-deletion UI/controller retains scope preview, explicit confirmation, the same pending execution handle, unknown/integrity/conflict states and committed-refresh retry. No evidence found here requiring deletion-transaction redesign. Historical full-run failures are subject to the Sept 5 correction in that report, not proof of an all-green baseline.

## Bounded implementation, in priority order

### 1. Finish management command feedback

Files: `Sources/AgentLoopApp/Views/RootView.swift`, `Sources/AgentLoopApp/AppStore.swift`; a small application-level command-state helper only if needed for behavioral testing.

- New-camp sheet currently starts an unawaited task and closes immediately (`RootView:183–194`); on failure, typed name/prompt disappear and only a toast remains. Make creation callback async and return a typed outcome preserving commit versus visibility failure. Keep the draft and inline safe failure on noncommit; close/navigate once committed; display pending state and reject concurrent submission. A committed visibility failure must not offer another create that duplicates the camp. Respect existing blank-name UI validation and do not alter persistence naming rules.
- Archive and restore currently await store calls but lack a per-camp pending state. Guard and display the existing operation while pending, restore controls after failure, preserve the selected camp on noncommit, and select the next active camp only after confirmed archive commit. Clear/disable dismissal while a commit outcome is pending instead of implying cancellation undoes a committed mutation. Existing transactions remain the authority for blockers.
- Keep remove-from-herd placement and existing confirmation/protection. Its pending state already exists. Do not add another removal implementation. Candidate instructions should explicitly identify the entry under cow editing.

### 2. Finish rumination retry and preflight feedback

Files: `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`, `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`, `Sources/AgentLoopApp/AppStore.swift`; use existing failure types/reporting, adding a bounded typed preflight reason only if necessary.

- `RuminationDetailHost.failedView` (`:215–234`) has an always-enabled Retry button. Use the same ingestion-ID pending state already used by inbox and queued detail, show “正在重试…”, and disable during the awaited action. Retain store coalescing as the command guard.
- `executeRuminationCommand` (`:5360–5384`) collapses missing ingestion mapping, unloaded runtime, missing/unavailable default model and unsupported CLI profile into `RuminationStartRecoveryRequiredError`. `safeRuminationStartMessage` does not map that error and shows generic “稍后重试”. Separate recoverable projection/loading from configuration errors at this preflight boundary; show a concrete safe action (reload or runtime settings) and record the operation trace/reason without credentials or source text. Existing `onOpenSettings` wiring can be carried into inbox/detail as required. Do not dispatch when preflight fails or automatically switch Provider/model.
- Preserve the successful-start snapshot application and committed visibility-failure distinction. Any refresh-only affordance must reload the projection, not resubmit work. Continue showing `.recovering` when no verified live phase identity exists.

### 3. Replace invented idle cow state with a shared persisted projection

Files: `Sources/AgentLoopCore/Database/AppDatabase.swift` (`InputCampReadBundle` and `readInputCampBundle`), `Sources/AgentLoopApplication/InputWorkflowController.swift` (`InputCampSnapshot`), `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`, `Sources/AgentLoopApp/CodingRanchContracts.swift`, `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`; optional small `Sources/AgentLoopCore/Product/CowActivityProjection.swift` for the pure reducer.

Evidence: adapter `cowViewState` (`:1353`) always returns `.idle`, no activity, no mission. Dashboard selects `regularCompanions.first` (`:968`), not an active cow. `CowRosterHost.rosterState` (`:335–358`) independently rebuilds hardcoded idle cows from the global store. `InputCampReadBundle` currently contains no card/assignee activity, and the mission list is limited to the newest 50.

- Add `cowActivityById` to the atomic camp read and pass it through `InputCampSnapshot`; derive activity from persisted card assignee, mission and squad ownership. Read activity independently from the 50-row recent-mission window so old but active work cannot disappear. Preserve the existing roster membership/retirement contract; this is a read projection, not a residency migration or permission grant.
- Produce one projected cow array for both dashboard and roster. Rank a cow with verified active work before an idle cow; use deterministic tie-breaking by activity time and IDs. Select work only within the viewed camp, label activity as belonging to that camp, and never expose another camp's title through a globally shared cow.
- Minimal status rules: assigned running card in executing mission → working; assigned blocked card without another running card → blocked; membership in planning mission → planning; participation in delivering mission → waitingForUser; no active evidence in a successfully loaded projection → idle. Other nonterminal assignment can use an explicit pending activity message without claiming execution. Do not derive validating/returning from specialty, random animation, or a test-cow ID. Missing/failed read stays load failure or unavailable, not idle success.
- Carry mission title/ID and existing persisted status/update time as traceable activity. Do not add event ingestion, timers, new background workers, or imaginary completion estimates. Refresh via existing camp/mission projection invalidation; prove updates reach the visible roster after card/mission changes.

## Verification work to perform later

- `ApplicationWorkflowTests.swift`: delayed/noncommitting/committed-with-visibility-failure command outcomes; duplicate create while pending invokes the mutation once; noncommit retains draft; committed outcome never offers mutation retry. Use a testable command helper if the app target cannot be imported; source-string checks alone are not sufficient behavioral proof.
- `CodingRanchTests.swift`: existing start receipt and recovery wiring checks; add only necessary wiring assertions for shared retry state and shared cow projection. Actual visual controls require isolated UI evidence later.
- Add behavioral cow projection tests (small new `CowActivityProjectionTests.swift` or established database projection suite): running/blocked/planning/delivering/idle, deterministic concurrent work choice, retired exclusion, cross-camp isolation, active work older than 50 recent missions, and transition refresh. New enum/reducer must compile in the normal authoritative runner.
- Preserve/re-run existing `CowResidencyContractTests` p1e24–27, durable rumination atomic/replay/recovery tests, and `IngestionDeletionContractTests` including modern-millisecond commit and same-handle resolution coverage. No real source/camp/cow deletion is part of verification. Add archive active-rumination blocker regression only if current coverage lacks it; do not loosen the blocker.
- Parent executes default unfiltered `swift run RunTests`, strict app build, isolated app management interactions, independent review, and matching package evidence once the execution-base gate is green. No focused suite or source inspection substitutes for those gates.

## Stop scope

No permanent camp deletion, hard cow deletion, resurrection, schema migration, automatic external action, paid Provider invocation, or generalized management redesign. The original defects already repaired are regression obligations, not justification to replace their contracts. Finish these bounded feedback/projection changes and report the unavailable permanent deletion explicitly.
