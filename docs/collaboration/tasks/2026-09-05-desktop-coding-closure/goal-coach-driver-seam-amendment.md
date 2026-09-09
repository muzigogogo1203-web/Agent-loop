# Proposed A2/A3 coach and driver seam amendment

Status: **proposal requiring separate independent review; not implementation authority**. A1 is unchanged and unstarted. This document does not edit or supersede the approved `goal-flow-plan.md`; approval must explicitly incorporate the decisions and additional file scope below before A2/A3 implementation.

## Source facts

- `Provider/OpenAIResponsesProvider.swift:66–102` accepts `maxTokens _: Int` but deliberately omits `max_output_tokens`; its comment says the ChatGPT Codex backend rejects that field. `OpenAIChatGPTAuthTests.swift:72–89` asserts the field is absent. This is a proven adapter limitation, not a newly verified claim about today's remote endpoint.
- `OpenAIResponsesProvider.swift:166–196` can retry generation requests three times by default and separately refresh/reissue after 401/403. Setting `maxRetries: 0` alone would not disable that refresh/reissue path.
- `OpenAIProvider.swift:156–208` and `AnthropicProvider.swift:120–174` share an attempt loop: default three retries, including another non-streaming generation after malformed streaming. Both branches require `attempt <= maxRetries`, so the already supported value `0` disables **both** application-level retries and streaming fallback.
- Final-error sinks use `String(describing: error)` in OpenAI/Responses and `readableError` in Anthropic. `ProviderError.description` includes HTTP body previews and API messages; `readableError` may include `URLError.localizedDescription`. Redacting only the coach's outer catch is too late.
- `InputParsingWorker.recoverInterrupted()` and `CoachTurnProcessor.recoverInterrupted()` call the kind-wide `DurableWorkStore.adoptExpiredControlWork`. At `DurableWorkStore.swift:7903–8020`, adoption correctly filters `leaseExpiresAt <= now` and closes the previous attempt before requeuing. Thus one startup call leaves live leases untouched **and misses their later expiry**; it must not be described as stealing live leases.
- `PlanningProviderResolver` returns generic `LLMProvider` through an injected factory; its existing App factory uses default retries. All three concrete transports support `LLMProviderRunDrivingV1`, whose `completion` is the actual producer task, while `streamTurn` alone exposes only events.

## 1. A2 eligibility: output and lifecycle limits must be enforceable

Keep **8 maximum generation dispatches including client retries, 4,096 hard output tokens, 120 s dispatch deadline, 49,152 UTF-8 request-body bytes**, and the existing 32,768 observed-token threshold. Unknown usage is never zero/free and never silently permits another generation.

**Explicit unsupported case:** the current ChatGPT OAuth transport cannot enforce the accepted 4,096-token server output bound. Desktop coaching must show `coachHardOutputLimitUnsupported` before claim/reservation/provider resolution, keep the work queued, and make zero generation/credential-refresh calls. Do not add a field already excluded by its contract, truncate locally and call that a generation cap, silently switch providers, or relax the cap. Existing non-coach OAuth behavior remains unchanged. CLI coaching remains unsupported as already planned. Enabling OAuth coaching requires a separately verified bounded transport or a user-approved policy change; neither is part of this amendment.

For API-key coaching, admit only a protocol/endpoint/model combination with an established server-enforced output-limit contract. Serialize the existing supported API request with `max_tokens: 4096`. Unsupported models or compatibility gateways whose cap behavior is not established remain visibly unsupported; merely accepting a numeric method argument is insufficient. Do not perform paid capability probes. Source/request tests establish what the app sends, not remote compliance; record that distinction in acceptance evidence.

Preflight must prepare the complete sorted-key provider JSON body using the same `OpenAIProvider.requestBody(..., stream: true)` or `AnthropicProvider.requestBody(..., stream: true)` and immutable inputs later sent. Include model/system/messages/tool-choice/wrapper fields; count encoded `Data.count`, not characters or history-only JSON. Reject `> 49_152` before claim. Store that exact body hash in the reservation and prove with an intercepted actual transport request that its bytes match. No body/config mutation or hidden non-streaming rebuild after reservation.

Require a joined-run-capable concrete provider before claim; a generic fixture/custom `LLMProvider` without `LLMProviderRunDrivingV1` is unsupported, not “best effort” cleanup. Start the 120 s deadline at dispatch, cancel the real `run.completion` and event consumer on timeout/halt/revoke, then join both and preserve completion failures before declaring stopped or launching another turn. Stream EOF alone is not producer completion.

The observable policy is a **120 s client dispatch deadline followed by checked cleanup**; cleanup is not silently abandoned at that deadline. If the accepted requirement instead means guaranteed server computation stops within 120 s, current transports provide no such cancellation acknowledgement: that guarantee is blocked, not established by a local timer. A transport that will not finish cancellation keeps the driver visibly stopping/blocked and prevents a replacement dispatch.

## 2. A2 single-generation transport, durable retry accounting

Add `DesktopCoachPlanningProviderFactory` within the already planned `Work/LLMCoachTurnProvider.swift`, injected into a **separate** `StrictPlanningProviderResolver` used only by the desktop coach. Reuse existing profile/catalog/credential validation; do not change the existing App planning factory or global provider defaults.

```swift
// In the coach-only factory; the resolver supplies the captured model/endpoint.
let authScheme = ProviderAuthScheme.automatic.resolved(for: format)
switch format {
case .openAIChatCompletions:
    return OpenAIProvider(apiKey: credential, model: model,
        session: coachSession, baseURL: baseURL,
        authScheme: authScheme, maxRetries: 0)
case .anthropicMessages:
    return AnthropicProvider(apiKey: credential, model: model,
        session: coachSession, baseURL: baseURL,
        authScheme: authScheme, maxRetries: 0)
}
```

Resolve the auth scheme as the existing `LLMProviderFactory` does: passing `.automatic` directly to Anthropic would incorrectly apply Bearer instead of `x-api-key`. The OAuth factory method also rejects safely as defense in depth; normal desktop preflight blocks it before the resolver reads credentials. Do not route the coach through `RuntimeCredentialResolver.provider`, which would restore default retries.

Use a coach-only URLSession with a narrow redirect delegate that returns `nil` from `willPerformHTTPRedirection`; fail on 3xx instead of transparently resending a generation POST. Disable automatic URL credential storage for this session. Test the actual session path. Transport/service-internal behavior is not an app-observable generation counter: count every application-issued generation request conservatively, and never call an ambiguous failed request free. Do not claim control over an untrusted gateway's internal generations.

One committed `coachAttempt` reservation may authorize at most one provider generation call, and that transport may issue at most one application-level generation HTTP request. Transition reserved → dispatching by CAS immediately before invoking it, after the already required generation/lease/consent/halt recheck. Once invocation may have happened, never recycle the slot. A proved non-dispatched reservation may close as notDispatched; a crash between dispatching and a terminal receipt is unknown, consumes its conservative slot, and blocks automatic repetition.

Only the durable worker may schedule a later retry, under its existing maximum four work attempts **and** the per-goal eight-dispatch cap. Each retry has a distinct existing workId/attempt reservation, rechecks policy/consent/runtime, and cannot bypass uncertain-usage continuation. With current generic results, failed/partial/no-terminal dispatch is unknown and success is observedUnproven; therefore a queued retry normally waits for explicit one-turn continuation. “Transient” does not itself authorize a free automatic redispatch. An explicit continuation still cannot exceed either cap.

Do not retry strict-output failures or reuse partial text. Map 429/5xx/exhausted transient errors to safe worker classifications without falsely claiming that the transport itself performed multiple retries when configured at zero.

## 3. Sanitize at the three actual Provider logging sinks

Add a small shared `ProviderFailureDiagnosticV1` in existing `Provider/LLMProvider.swift`, returning only a closed enum category plus optional integer status/code:

```text
ProviderError.http       → category=http, numeric HTTP status only
ProviderError.apiError   → category=api_error, no supplied type/message
ProviderError.malformedStream → category=malformed_stream, no detail
unauthorized / overloadedRetriesExhausted → fixed enum category
URLError                → category=transport, numeric URLError.Code only
CancellationError       → category=cancelled
DecodingError           → category=decoding, no codingPath/debugDescription
unknown Error           → category=unexpected, no description/type reflection
```

Replace each of the three final-error log expressions at its source with these fields. Remove Anthropic's now-unused raw `readableError` helper. Retain the original thrown error object and existing error propagation; this change sanitizes logging, not success/failure semantics. Existing fixed status/attempt/stop-reason logs may remain only after confirming they contain closed local enums or numbers, never server-provided strings.

The coach adapter separately converts errors into fixed safe classifications before any durable `safeMessage`, receipt, or FailureReporter projection. No raw provider body/text, URL, credential, `localizedDescription`, or reflected error description is persisted. Preserve trace/work/attempt/profile IDs and elapsed time at the owning coach layer for diagnosis.

## 4. A3 exact-owner recovery at expiry, not kind-wide startup recovery

Desktop code must not call either worker's kind-wide `recoverInterrupted()` at bootstrap. Retain those APIs and behavior for historical callers/tests. Add an exact transaction-taking adoption entry in the already scoped `DurableWorkStore.swift`:

```swift
adoptExpiredControlWork(workId: String, expectedVersion: Int,
    expectedLeaseOwner: String, expectedLeaseExpiresAt: Date,
    currentWorkerId: String, now: Date, in db: Database)
    throws -> DurableWorkRecord
```

Factor the existing one-row adoption mutation/attempt close/event insertion for reuse, preserving its checked version increment, lease-expiry condition, prior attempt number, interrupted code, and transaction rollback behavior. Validate exact work kind, running state, original lease owner/version/expiry and expiry `<= now`; never adopt a live lease or move another worker's deadline. This internal primitive grants no desktop ownership by itself.

`DesktopGoalWorkflowStore` selects and revalidates exact ownership **in the same write transaction**: live, unredacted desktop carrier; its exact input/goal/session IDs; correct work kind/aggregate and sealed input identity; matching camp; applicable lifecycle/dispatch state. Only then call the exact adoption primitive. No legacy/cross-camp/orphan work is swept up by kind. An expired coach attempt that may have dispatched is reconciled to unknown once via the existing journal CAS; adoption cannot erase its usage uncertainty or issue a new generation.

At bootstrap and subsequent wakes, driver reconciliation checks only these owned rows. Its next durable wake calculation includes the earliest **future live-lease expiry** of owned running parser/coach work, in addition to queued notBefore deadlines. At that wake, re-read/revalidate: another owner may have renewed the lease; then schedule the new future expiry without mutation. A past deadline that remains ineligible does not produce a zero-delay spin—wait for the relevant context/lifecycle/consent event. The existing maximum one parser and one coach loop per generation, halt cancellation/join, and actor generation fences remain intact.

## Exact additional scope and tests before acceptance

Beyond approved A2/A3 files, add source scope only for `Provider/LLMProvider.swift`, `Provider/OpenAIProvider.swift`, `Provider/OpenAIResponsesProvider.swift`, and `Provider/AnthropicProvider.swift` (shared safe diagnostics and three sinks). The coach factory/session lives in planned `LLMCoachTurnProvider.swift`; AppStore wiring, DesktopGoalWorkflowStore/Driver, worker exact-claim extraction, and DurableWorkStore are already scoped. `PlanningProviderResolver.swift` needs no behavior change. No schema/A1 change is required.

Add tests to planned `LLMCoachTurnProviderTests.swift` / `DesktopGoalWorkflowTests.swift`; source-level diagnostic formatter tests can live in the former. Use only URLProtocol/local scripted fixtures and real DB transactions, never paid Providers:

- OAuth profile → exact unsupported reason, queued work, attempt 0, no factory/credential refresh/network call; old OAuth body omission test remains unchanged.
- For each eligible API format, intercepted actual request body equals sealed bytes/hash, contains 4096 cap, tools empty; 49,152 boundary accepted, 49,153 rejected before claim including JSON wrapper/escaping bytes.
- 429, 503, malformed SSE after text, and 307 redirect each yield one actual application request for one reservation; no non-stream fallback/redirected second POST. Existing non-coach retry/fallback tests remain green.
- Across success/failure/restart/explicit continuations, maximum eight dispatches; ninth calls provider zero times. Existing worker four-attempt ceiling also holds. Duplicate terminal receipts do not double-count; no-terminal and default Usage() never become known zero.
- Cancellation fixture with delayed producer completion: timeout at injected 120 s deadline cancels producer, but adapter/driver do not finish or launch another generation until the real completion is released/joined; completion error remains observable. Non-run-capable provider rejected before claim.
- Sentinel secrets in HTTP body, API type/message, malformed detail, URL error userInfo and unknown CustomStringConvertible error: shared diagnostics contain only fixed category/numeric fields. Independent source check confirms all three final-error sinks use that formatter, not original descriptions; thrown error propagation remains unchanged.
- Restart with an owned live lease: bootstrap mutates nothing; wake at expiry adopts once. Renewal before wake postpones adoption. Unowned same-kind, another camp, tombstoned carrier, wrong aggregate/session, and active lease remain byte-identical. Inject failure between adoption and attempt/event close → transaction rolls back all writes.
- Recover a dispatching coach attempt with absent terminal evidence → unknown receipt once, no automatic generation; repeated wake/restart neither spins nor duplicates adoption/receipt. Halt during renewal/recovery joins old tasks and cannot launch through a stale generation.

Acceptance requires a separately reviewed executable A2/A3 plan incorporating this amendment and the explicit unsupported cases, followed by focused transport/DB evidence and independent implementation review. Do not describe OAuth hard caps, remote cancellation acknowledgement, or arbitrary gateway compliance as solved by local tests. The existing runtime full gate and A1 entry gate remain independent and uncleared.
