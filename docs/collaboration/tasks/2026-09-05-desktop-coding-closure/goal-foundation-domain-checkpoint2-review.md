# Independent A1 checkpoint 2 domain review

## Verdicts

**Spec verdict: PASS for checkpoint 2 only.** Zero P0, P1, or P2 findings in the frozen 370-line `DesktopGoalWorkflow.swift` domain slice.

**Quality verdict: PASS for checkpoint 2 only.** The implementation is closed and fail-fast at its Codable boundaries, preserves canonical replay identity, and contains no scaffold fallback, generated identity/time, store behavior, Provider action, or fabricated receipt. The retained five-test RED/GREEN evidence is valid for this microstep. This verdict does not mark A1 complete.

## Frozen review inputs

- Domain implementation: `Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift`, SHA-256 `06f55681625d1450476d119c70c6855c3f29b2f5bc5a9b771a339d072c7f7bc4`, reviewed as the complete new file against `/dev/null`, not as an incremental approval of the temporary throw-all scaffold.
- Approved plan inputs: `goal-flow-plan.md` `a6166c3f...`, `goal-foundation-plan.md` `c2f0a874...`, `.superpowers/sdd/goal-foundation-plan/task-1-brief.md` `f476f42d...`, owner decision `goal-coach-output-policy-decision.md` `8d2bd0e4...`, and its independent review `goal-output-policy-plan-review.md` `5412316a...`.
- Test boundary: only the first five `desktopDomain...` tests preserved by `desktop-text-validation-before/DesktopGoalFoundationTests.swift` are checkpoint-2 evidence. The appended sixth multiline/interior-formatting test is an explicit separate RED amendment and is excluded from this verdict. Live test-file drift by its current writer is likewise outside this review.

## Concrete review results

1. **No finding — output policy has one exact V1 wire value.** `DesktopGoalWorkflow.swift:17-45` exposes only `providerAware(apiRequestedTokens:)`, requires exactly `kind` and `apiRequestedTokens`, requires tag `providerAware`, validates the associated value as exactly `4_096`, and emits canonical fields without a legacy `maximumOutputTokens` fallback. This matches the approved provider-aware decision (`goal-coach-output-policy-decision.md:7-14`) and brief (`task-1-brief.md:40`). Unsupported values cannot be encoded into persisted canonical data.

2. **No finding — runtime selection is closed but need not be resolved.** `DesktopGoalWorkflow.swift:48-93` admits only `unconfigured` or `selected(profileId:model:)`; selected runtime validates a canonical profile UUID and nonempty model. Decode selects on the literal tag and then requires the exact per-case key set, while encode revalidates. No credential lookup, runtime resolution, effective A2 output mode, or Provider action is present.

3. **No finding — policy fields and defaults match the accepted contract.** `DesktopGoalWorkflow.swift:95-146` carries `maximumDispatches`, `reportedTokenStopThreshold`, `maximumRequestUTF8Bytes`, closed `outputPolicy`, and `timeoutSeconds`, with defaults `8 / 32_768 / 49_152 / providerAware(4_096) / 120`. Every integer is checked positive and decode requires the exact five keys before re-entering the validating initializer.

   Positive-only validation is not an A1 defect. The accepted main plan describes these as initial values (`goal-flow-plan.md:158-162`) and permits later limit changes only through explicit context CAS (`goal-flow-plan.md:278`); the brief also names `8 -> 7` as valid policy drift (`task-1-brief.md:151-157`). No immutable numeric upper bounds are specified. Adding `1...default` bounds here would invent a configuration policy. A2 remains responsible for checked consumption, request-size/deadline enforcement, reservation counting, and authorized CAS updates.

4. **No finding — context fields, nil shape, and initial-receipt boundary are correct.** `DesktopGoalWorkflow.swift:148-257` carries exactly schema/input/goal/session IDs, runtime/policy, consent receipt, workspace/bookmark, companions, mission budget/autonomy, and original privacy. It validates schema version 1, canonical UUIDs, selected runtime, optional receipt/path/bookmark consistency, duplicate companion IDs, and positive budget; exact-key decode reuses that initializer, and encoding preserves explicit null optionals. A nonnil receipt remains representable for a later legitimate context version, but `DesktopGoalWorkflow.swift:295-307` rejects it in the initial capture intent, so A1 cannot claim a consent receipt it did not create.

5. **No finding — capture intent and replay command preserve exact caller-owned identity.** `DesktopGoalWorkflow.swift:260-315` trims only outer whitespace on public construction, rejects empty or nonsealed decoded text, validates operation/camp/lifecycle version, requires user/local-owner plus canonical device UUID, binds the literal `desktop-goal:<operationId>:capture:v1` key, and accepts no initial remote-consent receipt. Decode at `DesktopGoalWorkflow.swift:317-338` requires exact intent keys and the complete exact envelope key set before reusing the same validation path. No UUID or `Date` is generated.

6. **No finding — command projection matches the A1 capture contract.** `DesktopGoalWorkflow.swift:350-369` derives the real `CaptureInputCommandV1` with context input ID; explicit audit/initial camp; text source; envelope device/time; nil connector, author, payload reference, and parent; empty candidates; `createGoal`; context privacy; exact sealed text; and SHA-256 of its exact UTF-8 bytes. The existing command initializer remains the downstream authorization/body validator, and the whole-command envelope remains available to the later sealing store.

7. **No finding — source scope is exactly the admitted five Codable contracts plus the shared error enum.** The 370-line file defines `DesktopCoachOutputPolicyV1`, `DesktopCoachRuntimeV1`, `DesktopCoachPolicyV1`, `DesktopGoalContextV1`, and `DesktopGoalCaptureIntentV1`, plus the plan's closed foundation error cases. It contains no stage/store/snapshot/retention implementation, temporary `checkpoint2` error, TODO, catch/default fallback, or fake success branch.

## Evidence assessment

- `goal-foundation-domain-red1.log:1944-1964` records five selected tests against the temporary scaffold: four fail on explicit `DesktopGoalDomainNotImplemented.checkpoint2`, while the negative policy test alone passes because the scaffold throws. This is correctly treated as the suite RED, not as proof of strict decoding.
- `goal-foundation-domain-green1.log:1943-1955` records the same five tests all passing in `0.012s`, exit 0. The tests cover exact policy JSON, both runtime variants and policy/hash binding, normalized deterministic capture/replay bytes and fields, unsupported/legacy policy payload rejection, and wrong key/owner/empty text rejection.
- The RED and GREEN source manifests each contain 304 entries; both process records contain 304 before and 304 matching after hashes with zero mismatches. Their manifest diff changes only `DesktopGoalWorkflow.swift`, from scaffold `a5173d30...` to reviewed implementation `06f55681...`; the test hash remains `ba0a788e...`. PIDs are 66532 and 67168, with exits 1 and 0 respectively.
- The current `desktop-text-validation-before` snapshot retains the first five test bodies byte-for-byte before its separately scoped sixth test. The reviewer did not require the concurrently edited live test file to equal the earlier GREEN hash.

## Scope limitations

- This verdict excludes the acknowledged multiline/interior-formatting validator RED and its shared-source repair. It neither blocks this frozen checkpoint nor approves that repair.
- It does not review or preapprove stage/receipt types, the workflow store, migration follow-ups, capture transactions, replay persistence, graph reads, retention/redaction, source-inventory successor, A2/A3, Provider/App/UI work, full `RunTests`, strict App build, packaging, or product acceptance.
- The reviewer ran no compiler or test and changed no source, test, real data, App/process, or Provider state. Only this designated review artifact was written.
