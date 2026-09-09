# Management command test-entry readiness

2026-09-10. Optional read-only preparation for item 1 of `management-scope.md`; not management stage entry, an implementation plan, or acceptance evidence. Inspection was limited to that scope document and related portions of RootView, AppStore, InputWorkflowController, and ApplicationWorkflowTests. No source/build/test/UI/real-data work was performed.

## Smallest existing seam

Reuse `OperationCommitOutcome<CampRecord>` at the AppStore-to-application boundary. The application controller already preserves commit status; RootView and AppStore currently lose presentation detail. No persistence protocol or generalized management coordinator is needed.

| Existing interface | Location | Relevant behavior |
| --- | --- | --- |
| `InputWorkflowController.createCamp(name:guidePrompt:trace:) async -> OperationCommitOutcome<CampRecord>` | `Sources/AgentLoopApplication/InputWorkflowController.swift:1754` | Calls one synchronous `ports.createCamp`; returns committed record or captured noncommit failure |
| `InputWorkflowController.setCampArchived(id:archived:trace:) async -> OperationCommitOutcome<CampRecord>` | same file, line 1785 | One existing archive/restore port, selected by Bool; no per-camp pending guard |
| `InputWorkflowPorts.createCamp: @Sendable (String, String?) throws -> CampRecord`; `.setCampArchived: @Sendable (String, Bool) throws -> CampRecord` | same file, lines 591/617 | Existing mutation injection; initializer is package-visible but requires many unrelated ports |
| `InputWorkflowController.init(database:orchestrator:resolver:reporter:reads:ports:activeIngestionDeletionPorts:)` | same file, line 1241 | Existing controller test entry; unnecessary fixture weight for draft/pending presentation tests alone |
| `AppStore.createCamp(name:guidePrompt:) async -> CampRecord?`; `.setCampArchived(id:archived:) async -> Bool` | `Sources/AgentLoopApp/AppStore.swift:4623/4675` | Generate existing operation trace, apply committed record, show safe failure toast; erase typed failure/visibility distinction from caller |
| `AppStore.upsertCampProjection(_:)` | same file, line 4753 | ID-based insert/update; existing ordering is createdAt then ID; keep this projection path |
| `AppStore.refreshInputCampProjection(campId:makeVisible:) async -> WorkflowLoadState<InputCampSnapshot>`; `InputWorkflowController.loadCamp(campId:trace:)` | AppStore line 4203; controller line 1264 | Existing read-only projection refresh and generation handling; available if a refresh-only affordance is required |

The existing outcome cases are `.notCommitted(UserVisibleFailure)`, `.committed(CampRecord)`, and `.committedWithVisibilityFailure(value: CampRecord, failure: UserVisibleFailure)`. Preserve the committed record and safe failure together instead of adding a second outcome enum.

RootView owns the missing presentation behavior:

- New-camp sheet: lines 183–195 launch a Task and dismiss immediately. `NewCampSheet` at line 778 has synchronous `onCreate`, local name/prompt draft, and only blank-name disabling at line 832. It has no pending state or inline failure.
- Restore: lines 73–94 await a Bool and select the restored camp; no same-camp guard/progress.
- Archive: lines 381–408 clear the confirmation target before awaiting, then select the next active camp only if the current destination is exactly `.camp(archivedID)`. Preserve this current-destination check; a navigation change during the await must not be overwritten using an old selection snapshot.

## One bounded helper only if behavioral testing requires it

`ApplicationWorkflowTests.swift` imports AgentLoopApplication/Core, not AgentLoopApp; `AppStore` is internal `@MainActor @Observable` and `NewCampSheet` is private. The inspected application file has no existing camp-command/draft state owner. `MemoryKnowledgeProjectionCoordinator` (controller file, line 1004) is a useful package-visible MainActor value-state precedent, but is memory-specific and should not be repurposed.

If needed, place one small package-visible MainActor command-state helper in `Sources/AgentLoopApplication/CampManagementCommandState.swift`, used by the actual AppStore/RootView path. Its bounded responsibility is the current create draft/submission lifetime, per-camp archive/restore admission, safe inline outcome state, and committed-versus-retry disposition. A same-camp archive/restore pair must share one pending slot. Acquire it before the first await and consume only the matching attempt's terminal result. A committed create attempt cannot be resubmitted until an explicit new-draft action.

For deterministic tests, let its real submit entry await narrow injected async closures returning the existing typed outcome. Production closures call the existing controller; test closures count invocations and suspend on an explicitly released continuation. This tests actual duplicate admission, not a fake reproducing the helper's predicate. Keep database mutation semantics and synchronous ports unchanged; do not block an actor/cooperative worker with the WAL semaphore fixture. Unconditionally release/join test-owned continuations/tasks before assertions can escape.

Keep SwiftUI `Destination`, concrete view dismissal, and camp-array upsert in the app. If selection decisions need application-layer coverage, move only the camp-ID decision into this same helper; otherwise mark that behavior as requiring isolated UI evidence. Do not introduce a second navigation owner or claim helper state proves actual buttons are disabled.

## At most six discriminating behavioral cases

Use parameters within the cases below, not a second management roadmap. These belong in existing `ApplicationWorkflowTests.swift` and must exercise the helper actually wired into production.

1. **Create admission while pending:** whitespace-only name invokes no mutation; a valid draft enters pending before suspension, cannot dismiss, and a second submission invokes the mutation only once. Release to committed; terminal disposition closes/navigates once to that record, preserving existing optional-prompt conversion.
2. **Create noncommit retains draft:** exact name and prompt survive a `.notCommitted` result, inline failure keeps its safe message/trace, pending clears, no committed/navigation disposition appears, and a deliberate retry remains available. No trim/rename persistence-rule change.
3. **Create committed visibility failure is not mutation retry:** parameterize ordinary commit and committed-with-visibility-failure. Both retire the submitted draft and retain the same committed camp; the latter retains the failure separately. Repeated submit on that completed attempt performs no second create; any offered recovery invokes only the read path. Explicit new draft is a distinct permitted create.
4. **Archive/restore pending and noncommit:** parameterize archived true/false. A repeated or opposite operation on the same camp is rejected while pending, another camp's slot is not falsely marked pending, and no selection/projection mutation is emitted before commit. Noncommit preserves selection, releases the slot/confirmation restriction, and retains the safe failure; transaction blockers are not bypassed.
5. **Archive commit selection:** parameterize ordinary/visibility-failed commit and selected/unselected target. Only a confirmed commit emits archive application; if the target is still the selected camp, choose the first remaining active camp in existing projection order or no camp when none remain. Preserve a different current destination. Visibility failure must not turn this into another archive mutation.
6. **Restore commit and read-only recovery:** both committed outcomes apply/select the returned unarchived camp once and clear pending. A visibility failure remains visible; recovery must not call restore again. Noncommit behavior is covered by case 4, not treated as success.

## Material interface gaps / evidence limits

- Current create/archive controller implementations have **no post-commit read step**: they cannot presently generate committed-with-visibility-failure through a failing `InputWorkflowReads.camp`. AppStore's matching cases are defensive. Inject that valid outcome at the command boundary to verify UI policy; do not invent a production refresh merely to trigger a test or claim an end-to-end post-commit read fault was reproduced.
- The synchronous ports and actor serialization are not a presentation duplicate guard. Direct controller tests cannot prove draft retention, pending rejection, dismissal, or selection. The proposed helper is justified only if the UI consumes its decisions, with actual async callback results still propagated through AppStore.
- `inputRefreshFailurePreservesDashboardAndInbox` (tests line 1710) already uses `ApplicationInputReadHarness` and `WorkflowProjection<InputCampSnapshot>` to prove last-loaded camp projection survives read failure. Reuse its read-failure pattern, not its large bootstrap as the default for all six command tests.
- `committedVisibilityFailureCannotRepeatMutation` (tests line 3970) covers memory visibility state and calls existing OAuth/schedule rows; it is **not camp management coverage**. Schedule rows around line 3168 demonstrate concrete mutation-count checks across repair. `applicationWorkflowFailure` (line 805) supplies a safe fixture failure but its operation is `.memoryNoteLoad`; camp-specific trace assertions require the existing reporter/trace factory with `.campCreate` or `.campArchive`, not that mismatched operation.
- Existing read-only refresh can repair a projection, but there is no camp-management visibility-repair owner in the inspected code. Before adding a retry button, bind it to the committed camp/attempt and a read-only closure; otherwise show the committed status plus safe failure without implying resubmission is safe.
- Isolated UI evidence must still verify progress/disabled controls, cancel/escape/dismiss behavior, draft survival, confirmation lifecycle, and navigation. Full authoritative runner, strict app build, independent review, and package evidence remain later parent-owned gates. Source-string assertions alone are insufficient.

Permanent camp deletion and cow retirement are not touched by this readiness note. Archive remains archive. Management implementation still requires the existing stage-entry approval after runtime closure.
