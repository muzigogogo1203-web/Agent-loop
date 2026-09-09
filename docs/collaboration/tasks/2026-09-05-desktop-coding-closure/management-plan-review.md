# Independent management plan review

Date: 2026-09-05. Reviewer: responsibilities-separated Codex agent. I read `spec.md` and `management-plan.md` completely and inspected only the current records, controller boundaries, projection state, database reads, and presentation call sites needed to validate the three planned tasks. No source changes, build, test, app launch, Provider call, credential access, or data operation occurred. This report is the only file written. Runtime compilation and the execution-base gate remain owned by the parent.

Reviewed plan SHA-256: `0fd2aa997a1e969bda038c9328c91090f9650857d687ff3fe6f6735615c0bdc3`. Reviewed spec SHA-256: `58a6563c92e73b4a05dfbb3fe34e3df6c81da4043e7764a91e6ee577a43e1390`.

## Verdict

**Changes required before Task 2 is decision-complete; Tasks 1 and 3 are approved as bounded implementation plans.** There is 0 P0 / 1 P1 / 0 P2. The required correction is an application-result contract amendment, not a product redesign or new workflow framework. The three-task scope, permanent-deletion exclusion, no-Provider fixture boundary, and distinction between domain commit and projection visibility are otherwise sound.

## Required correction

### P1 — Rumination preflight cannot represent runtime failure or return its promised recovery action

The proposed input and output at `management-plan.md:53-69,71-80` cannot satisfy the plan's own safety and test contracts:

- `resolveRuminationStart(campId:runtime:)` receives only `LegacyRuminationStartupSnapshot?`. It therefore cannot distinguish `WorkflowLoadState.idle/loading` from `.failed(UserVisibleFailure)`. The distinction exists in production (`WorkflowLoadState.swift:4-9`) and is material: a failed runtime load must display its existing failure, while idle/loading should produce a reload preflight blocker.
- A failed or refreshing `WorkflowProjection` may retain `lastLoadedValue` (`WorkflowLoadState.swift:21-24,60-89`). The current AppStore reads that property directly (`AppStore.swift:5368-5384`). If the new path continues passing the retained snapshot, a start can dispatch using stale runtime authority; if it passes `nil`, it replaces the existing runtime load failure with the incorrect “loading” diagnosis. Neither matches line 71.
- `OperationCommitOutcome` carries only the committed value and/or `UserVisibleFailure` (`FailureRecord.swift:736-742`). `UserVisibleFailure` itself exposes trace, operation, scope, and message, but no typed recovery action (`FailureRecord.swift:713-722`). Therefore a controller that returns only `OperationCommitOutcome<InputRuminationStartReceipt>` cannot also expose the promised `RuminationStartRecoveryAction`, and the production-controller test at line 79 cannot assert it without testing a separate model that the UI does not consume.
- The new blockers are errors, but the current `FailureClassifier` has no mapping for them and otherwise produces non-retryable `unexpected_failure` with “发生未预期的错误。” (`FailureRecord.swift:1261-1288,1594-1600`). Consequently `FailureRecord.swift` is a required file for this task, not conditional if the blockers are reported through the existing reporter as planned.

Smallest safe amendment:

1. Replace the optional runtime argument at the new application entry point with a narrow preflight input that preserves production state, for example `loadingOrMissing`, `failed(UserVisibleFailure)`, and `loaded(LegacyRuminationStartupSnapshot)`. Only `.loaded(.valid(...))` may reach the existing durable-start path. A failed projection returns/presents the already reported runtime failure; it must not use a retained `lastLoadedValue` and must not synthesize a profile diagnosis.
2. Return a narrow presentation result containing the unchanged `OperationCommitOutcome<InputRuminationStartReceipt>` plus optional typed blocker/recovery metadata, or an equivalent single typed result consumed by AppStore and both retry surfaces. Do not add recovery metadata to or weaken `OperationCommitOutcome`; its three cases remain the actual-commit authority. For `.committedWithVisibilityFailure`, recovery is reload-only and must never invoke start again.
3. Make the safe `FailureClassifier` mapping for every new reported blocker mandatory, preserving the one generated `.inputRuminationStart` trace for ordinary preflight blocks. Keep runtime-bootstrap `.failed(UserVisibleFailure)` as the existing failure/trace rather than re-reporting it as a different cause. Keep UI recovery action typed; do not infer authority from localized message text.
4. Amend the table test to call the same controller/AppStore result consumed by production and assert both the actual `.notCommitted` outcome and typed recovery metadata. Add the failed-runtime-projection case with a distinct existing failure and assert zero start-port calls and no stale snapshot dispatch. This is application contract coverage, not a stdlib or source-text test.

Without this amendment Task 2 risks dispatch under stale configuration and cannot implement or verify its advertised recovery UX. Implementation should not begin for Task 2 on the current signature.

## Approved boundaries to retain

### Task 1 — Camp command feedback

- The current `InputWorkflowController.createCamp` and `setCampArchived` already return `OperationCommitOutcome<CampRecord>` (`InputWorkflowController.swift:1754-1767,1785-1798`). Preserving that full result through AppStore is the correct actual-commit boundary: `.notCommitted` keeps draft/selection and permits retry; both committed cases apply the returned record; visibility failure is warning/reload work, never permission to repeat the mutation.
- Synchronous `begin` before constructing the Task, one pending key per camp for archive/restore, throwing on unmatched `finish`, and resolving every exceptional exit to a reported noncommit are coherent. They neither invent storage nor hide failure. Retaining the create draft until a true commit fixes the current immediate-dismiss feedback loss without transactional cancellation.
- The proposed state/controller tests exercise production types and an actual injected controller port. The committed-visibility fixture is correctly identified as a state-contract branch rather than evidence that current create performs a postcommit read. UI dismissal, selection, and warning visibility appropriately remain later isolated-app evidence.
- The plan keeps archive/restore distinct from permanent deletion and retains existing active-task/custom-cow guards. No authority bypass or new destructive operation is introduced.

### Task 3 — Persisted shared cow projection

- `readInputCampBundle` already runs through one `pool.read` snapshot (`AppDatabase.swift:7072-7096`). Adding the camp-scoped active-mission/card/membership read inside that function is the correct atomic projection seam.
- The existing visible mission list is camp-scoped but capped at 50 (`AppDatabase.swift:7174-7185`); the planned separate unbounded query limited by active mission states is necessary for an old active mission and does not require widening the recent-history UI query. The regular roster already requires active `cow_identity` and includes only camp-local or shared companions (`AppDatabase.swift:7224-7237`), so using exactly those IDs preserves retirement and camp authority.
- Requiring the mission-to-squad camp join before accepting card or title evidence prevents shared global cows from leaking another camp's work. Throwing membership decode, fixed blocked summary, no use of `blockedReasonJson`, no invented `updatedAt`, explicit pending state, and deterministic precedence/ties are all source-valid and fail visibly.
- The named fixture tests use the actual database bundle and controller load, cover the >50 case, camp isolation, retirement, deterministic state, transition reload, and malformed membership. They are meaningful production-path regressions. Event-driven UI refresh remains a later isolated-app claim; the implementation must resolve the affected camp and call its reload with `makeVisible` true only when that camp is already visible, never switch camps as a side effect.

## Acceptance boundary

This is a static plan review, not implementation or runtime evidence. After incorporating only the Task 2 contract correction, the parent may serialize the three implementations with the shared AppStore/RootView work. Acceptance still requires the plan's production-path focused evidence, unfiltered `swift run RunTests`, strict App build, isolated interaction checks, independent implementation review, and a source-matched package. A committed command plus failed projection refresh must remain committed throughout those layers; a UI reload is not a command retry.

## Targeted Task 2 re-review — 2026-09-05

Reviewer: responsibilities-separated Codex agent `/root/goal_flow_plan_review`, distinct from the initial management reviewer and from the implementer. Reviewed amended management plan SHA-256 `2f819b0a488957cedc9bf96f678a2401c2607f16332e0a30a1ff91bdff371c35`. Scope: the one prior P1, amended Task 2 and its immediate contract dependencies. Tasks 1 and 3 retain their previous approval and were not re-audited. No source edits, builds, tests, app launch or Provider/data operations occurred; only this report was appended.

**Verdict: Task 2 approved as a bounded implementation plan. The prior P1 is closed; 0 P0 / 0 P1 / 0 P2 remain in this targeted re-review.** This is plan approval, not implementation acceptance or passage of the parent's execution-base gate.

- The production bridge now takes `WorkflowProjection.state` through `RuminationRuntimePreflightInput.init(state:)`. Only loaded snapshots can produce ready selections. Failed state preserves its exact existing failure; loading/idle cannot borrow retained `lastLoadedValue`. This directly closes both stale-dispatch paths identified by the initial review.
- `RuminationStartPresentationResult` preserves the existing three-case commit outcome and carries typed recovery metadata alongside it. The controller, AppStore and both surfaces consume that same result. Committed visibility failure retains the work ID and offers read-only reload; ordinary downstream noncommit is not mislabeled as a preflight block. No extension to core commit semantics or localized-string authority inference is needed.
- The five new blocker mappings are mandatory, with explicit existing codes, messages and retryability. The blocker error lives in Core/Ingestion; Application owns preflight/presentation types, and Core/Observability classifies the Core error. This preserves dependency direction. Existing runtime-load failure is passed through without creating a second report or trace.
- Behavioral tests exercise the production constructor and overload with actual WorkflowProjection retained-state behavior, exact original failure identity, zero start-port calls for every blocker, real classifier output, valid runtime forwarding, and reload without repeated start after committed visibility failure. These are sufficient plan-level regression contracts; isolated UI interaction remains explicitly separate.

Current source inspection confirmed the referenced WorkflowLoadState/WorkflowProjection cases and retention behavior, LegacyRuminationStartupSnapshot and selection equality, UserVisibleFailure identity fields, the unchanged startRumination commit/read split, and availability of the specified FailureCode cases. No new blocker was introduced by the amendment. Parent may implement Task 2 with Tasks 1 and 3 under the existing runtime gate and serialized shared-file ownership; later independent implementation review must check these exact boundaries.
