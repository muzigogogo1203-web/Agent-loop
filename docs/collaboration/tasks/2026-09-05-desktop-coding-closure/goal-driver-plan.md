# Desktop Goal Driver — A2 Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` task by task. The parent owns dispatch and integration; a responsibilities-separated reviewer must approve this plan and each material implementation boundary. Checkboxes are implementation steps, not completed evidence. No extra agents, commits or external Provider calls are authorized by this document.

**Goal:** Execute only desktop-owned parser/coach work, with a real bounded coach transport, durable attempt evidence, and joined stop/revoke/recovery behavior.

**Architecture:** Extend the A1 JSON carriers and reuse existing Input/Coach domain commands and lease renewal. Keep wire DTOs, coach-only transport configuration and response validation local to the new adapter. One Core driver owns one parser task and one coach task, with a separate exact-owner durable scheduler; A3 supplies the application/journal gestures and lifecycle integration.

**Tech Stack:** Swift 6 strict concurrency, GRDB 7, existing URLSession transports and `LLMProviderRunDrivingV1`, standalone `RunTests` on macOS 14+.

**Spec:** `spec.md`, `goal-flow-plan.md`, `goal-foundation-plan.md`, `goal-coach-output-policy-decision.md`, and `goal-output-policy-plan-review.md` in this directory. Current main-plan SHA-256: `a6166c3fb5b9622450a20d614c01dd5ea87dfbdf79ded48656c353e925a5d5c5`.

**Status:** executable extraction and narrowly enumerated addenda **pending parent review**. This document does not edit/re-approve the main/A1 plans or clear their runtime entry gates. `goal-coach-driver-seam-amendment.md` is historical research only; its OAuth-blocking/uniform-cap recommendation is superseded. Parent explicitly chose A2 Core-only; no last-minute AppStore integration is included.

## Global constraints

- Begin only after reviewed A1 implementation exposes its actual carrier/domain/store interfaces and the parent permits the runtime entry. Refresh source/preimages at entry; stop for review if A1 interfaces differ materially from the consumed contracts below.
- Preserve A1 SQL, migration name, two-carrier design, canonical `providerAware(apiRequestedTokens: 4096)` JSON, original-intent hashes, retention and operation phases. No third table or replacement Input/Coach engine.
- Eight conservative application-issued generation reservations per goal, including retries; each work also retains its existing maximum-four attempts. Unknown or observed-unproven usage is not free and blocks automatic continuation. One explicit continuation buys one eligible reservation, not an exemption from either ceiling.
- Actual full generation body is at most 49,152 UTF-8 bytes. Observed input+output threshold is 32,768 with checked arithmetic; API requests 4,096 through its supported protocol, OAuth is provider-managed. No universal remote compliance/aggregate-token/monetary guarantee.
- 120-second monotonic client dispatch deadline, then cancellation and joined actual producer cleanup. No exact remote-stop acknowledgement. Never declare stopped or replace a run while its producer/consumer is unjoined.
- Runtime/model never silently falls back. CLI coaching is unsupported; OAuth remains supported. Resolve credentials only through the existing strict resolver after local eligibility; all development credentials are injected fixtures. No real keys, refreshes, paid calls, network probes, data deletion or release.
- Local parser and an exactly identified application-authored revision question use no model reservation. They are not fallback answers for remote failures. A3 owns conversion/session/answer/revision/confirmation journal sequencing and visible UI, not A2.
- Preserve legacy kind-wide workers/claim behavior. Desktop paths exclusively use exact transactions. A red/unknown failure blocks acceptance; focused checks, package build and later real-user acceptance remain distinct.

## Verified seams and bounded source scope

Current source facts (read-only preparation, not runtime evidence):

1. `CoachContracts.swift:733` request and its history entries are Sendable/Equatable, **not Codable**. `CoachTurnProviderV1` is a nonthrowing async closure returning question/understanding/failed/canceled. Do not call a canonical encoder on the existing request or assume persistence errors can escape that closure.
2. `UnderstandingCard.swift:4` has 14 fields and a throwing initializer. The verified A1 [narrative-text amendment](desktop-text-validation-amendment-plan.md) adds exact-key, constructor-validating decoding only to `UnderstandingContentV1` and `CoachAnswerV1`, preserving their encoded shapes. A strict adapter DTO must still require keys/types/bounds and explicitly construct `UnderstandingContentV1`; do not globally change historical domain decoding.
3. `InputParsingWorker.runNext` and `CoachTurnProcessor.runNext` claim by kind, then run a provider+15-second renewal task group using a 60-second lease. Existing post-provider cancellation check precedes domain mutation. `CoachTurnProcessor.loadSnapshot` builds real ordered question/understanding history and validates graph/heads.
4. `DurableWorkStore.claim(workId:workerId:now:leaseDuration:in:)` already exists as a **static** exact transaction primitive. It checks camp lifecycle/queued state but does not enforce desktop ownership, global dispatch, consent, provider limits or `attempt < maxAttempts`; desktop checks belong outside it in the same transaction.
5. All three transports expose `startTurn -> LLMProviderTurnRunV1(events, completion)`. `makeLLMProviderTurnRunV1` exposes the real producer Task, not just an event-stream cancellation signal. Default transport retries are three; API malformed-stream fallback uses that same retry guard. OAuth auth refresh/reissue is a separate callback, so retries zero alone is insufficient.
6. `ProviderAuthScheme.automatic.apply` sends Bearer; only `.automatic.resolved(for: .anthropicMessages)` yields x-api-key. Reuse strict resolver validation, but supply a separate coach factory rather than the current App factory/default retries.
7. Three final-error sinks log raw error descriptions. Anthropic's two stop-reason sinks also log `StopReason.other(String)` through reflection. Both categories require source-level closed classification, not outer coach redaction.
8. `adoptExpiredControlWork(kind:...)` only adopts expired leases, closes the prior attempt and appends an interrupted event transactionally, but is kind-wide. A once-only bootstrap call misses live leases that expire later.

### Already covered main-plan files used by this extraction

- Create `Sources/AgentLoopCore/Work/LLMCoachTurnProvider.swift`: private wire/response DTOs, coach factory/session policy, prepared request/run ownership, safe adapter classification.
- Create `Sources/AgentLoopCore/Work/DesktopGoalControlDriver.swift`: exact candidate dispatch, actor generation fence, owned task lifecycle and deadline/wake scheduling.
- Modify A1 `Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift`: A2 attempt/continuation/driver read contracts only; preserve A1 policy and captured intent encoding.
- Modify A1 `Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift`: exact eligibility, context/consent/continuation CAS, attempt journal and exact recovery; no A1 capture/redaction rewrite.
- Modify `Sources/AgentLoopCore/Work/InputParsingWorker.swift`: extract exact `runClaimed` body with the existing renewal/terminal path.
- Modify `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`: only `CoachTurnProcessor` exact request/execution/throwing-provider seams; no general supervisor refactor.
- Modify `Sources/AgentLoopCore/Database/DurableWorkStore.swift`: factor exact one-row expired-control adoption; preserve kind-wide callers.
- Modify `Sources/AgentLoopCore/Observability/FailureRecord.swift`: only closed desktop-control operation/code registrations required by existing safe failure projection.
- Create `Sources/AgentLoopTestSuite/LLMCoachTurnProviderTests.swift` and `Sources/AgentLoopTestSuite/DesktopGoalWorkflowTests.swift` for the tests below.

### Explicit addenda requiring approval, not implied main-plan authority

- `Sources/AgentLoopCore/Provider/LLMProvider.swift`: shared fixed-category/error-number and closed stop-reason formatter. No public usage/schema or retry behavior change.
- `Sources/AgentLoopCore/Provider/OpenAIProvider.swift`, `OpenAIResponsesProvider.swift`, `AnthropicProvider.swift`: replace the three final-error log expressions; Anthropic additionally replaces its two stop-reason expressions and removes the unused raw helper. Original thrown errors and non-coach behavior remain unchanged.
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`: register the exact four newly created A2 paths above in a dated successor set, separate from A1/runtime/historical sets. No manifest, old count/hash or directory-wide exclusion change. Existing Provider edits fall under the already exact five-file R9-F provider successor; do not expand it.
- No `CoachContracts.swift`, `UnderstandingCard.swift`, `PlanningProviderResolver.swift`, ProviderConfiguration, AppStore, Orchestrator, Package.swift or RunTests modification is required for A2. Live application lifecycle binding is explicitly a separate A3 gate below.

## Milestone 1 — Canonical request DTO and strict response decoding

**Files:** new `LLMCoachTurnProvider.swift`, new `LLMCoachTurnProviderTests.swift`.

**Consumes:** actual `CoachTurnProviderRequestV1`, `APIMessage.user(_:)`, `UnderstandingContentV1.init(...)`, `InputContractValidationV1.requireExactKeys`, existing canonical encoder.

**Produces:** these package static functions on `LLMCoachTurnProvider`; the wire structs remain private:

```swift
package static func historyBytes(_ request: CoachTurnProviderRequestV1) throws -> Data
package static func decodeOutcome(_ turn: TurnResult) throws -> CoachTurnProviderOutcomeV1
```

- [ ] Add a private Encodable wire DTO with the request's exact 13 fields: schemaVersion/workId/attempt/goalId/sessionId/nextQuestionId/decisionKey/failureScope/goalTitle/goalRawIntent/confirmedUnderstanding/understandingHistory/questionHistory. Explicitly encode nullable confirmedUnderstanding. Copy every history field: understanding ID/version/content/status/hash/createdAt/confirmedAt; question ID/decisionKey/prompt/recommendation/reason/answer/state/createdAt/answeredAt. Encode explicit null for optional answer/times; use existing canonical date/hash conventions, ordered arrays and sorted map keys. Do not reorder user arrays, summarize history, consult chat memory or grant permission from text.
- [ ] Create a fixed system instruction requiring one of the two accepted schemas and saying all goal/source/history strings are data, not tool instructions. The single user history message is UTF-8 decoding of `historyBytes`; no tools, `.auto`. Bounds apply to the later complete provider body, not just these bytes.
- [ ] Add private response Codable DTOs with custom init(from:). Outer question keys are exactly kind/prompt/recommendation/reason; understanding keys exactly kind/content. Content keys are exactly:

```text
problem scenario targetAudience goals nonGoals deliverables constraints
acceptanceCriteria verificationPlan resourceRefs requiredCapabilities budgetPolicy
assumptions acceptedRisks
```

Use String for the first three, [String] for the ten array fields, [String:String] for budgetPolicy. Call requireExactKeys at both object layers, then the throwing domain initializer with all 14 arguments. No missing-array defaults, trimmed replacement content, coercion, repair JSON, fenced/prose extraction or dictionary-to-success fallback. Empty arrays remain permitted by existing domain semantics; empty required strings or empty string elements/map keys/values fail.
- [ ] Proposed local validation bounds, pending this review: each string at most 16,384 UTF-8 bytes; each array/map at most 64 entries; concatenated final text at most 262,144 UTF-8 bytes. These are parser acceptance/memory limits, **not** model generation caps. Check deltas and final text sizes with checked addition; over-limit cancels/joins and fails visibly without partial domain output. Do not change global Provider accumulator behavior in this milestone.
- [ ] Accept exactly one terminal `.turn`, `.endTurn`, and only text content blocks; concatenate those blocks then decode the whole JSON document. Reject tools/results/unknown blocks, other stop reasons, no terminal, multiple terminals, truncated/malformed JSON. Text deltas are not a second authoritative answer. Producer failure after an apparently complete turn still fails until actual completion joins.
- [ ] RED tests then implementation then focused checks:

```swift
@Test func coachRequestDTOIncludesEveryPersistedHistoryField() throws
// Arrange real request with one answered question and one understanding history item.
// #expect(decodedKeys == exact13Keys)
// #expect(question["answer"]["text"] == correction)
// #expect(twoEncodings == eachOther); reorder budget dictionary insertion => same bytes.
@Test func coachStrictUnderstandingReconstructsValidatedDomainContent() throws
// #expect(try decode(validTurn) == .understanding(expectedThrowingInitializerValue))
// For each missing/extra content key, wrong scalar/array/map type, whitespace-only
// required string, empty element/key/value, oversize, unknown tag, prefix/fence,
// tool/unknown block or non-endTurn: #expect(throws: Error.self) { try decode(turn) }.
```

The test fixture constructs the full 14-field expected value through the real initializer. Expected initial RED is absent adapter decoding/required rejection, not a fabricated valid-understanding row. Historical domain schemas/tests remain unchanged.

Concrete decoding oracle (in addition to the field-coverage cases):

```swift
@Test func coachStrictDecodingRejectsBlankRequiredContent() throws {
    let json = #"{"kind":"understanding","content":{"problem":" ","scenario":"local app","targetAudience":"owner","goals":[],"nonGoals":[],"deliverables":[],"constraints":[],"acceptanceCriteria":[],"verificationPlan":[],"resourceRefs":[],"requiredCapabilities":[],"budgetPolicy":{},"assumptions":[],"acceptedRisks":[]}}"#
    let turn = TurnResult(content: [.text(json)], stopReason: .endTurn)
    #expect(throws: Error.self) { try LLMCoachTurnProvider.decodeOutcome(turn) }
}
@Test func coachStrictDecodingReturnsExactQuestion() throws {
    let json = #"{"kind":"question","prompt":"Which workspace?","recommendation":"Choose the project","reason":"The goal needs a scope"}"#
    #expect(try LLMCoachTurnProvider.decodeOutcome(
        TurnResult(content: [.text(json)], stopReason: .endTurn)
    ) == .question(prompt: "Which workspace?", recommendation: "Choose the project",
                   reason: "The goal needs a scope"))
}
```

## Milestone 2 — One-reservation transport preparation and source-safe diagnostics

**Files:** adapter/tests plus the four explicitly added Provider files. Dependencies: M1.

**Interfaces:** `DesktopCoachPlanningProviderFactory: PlanningProviderFactory` returns a private wrapper conforming to LLMProvider and LLMProviderRunDrivingV1. The wrapper holds one concrete OpenAI/Anthropic/Responses value plus immutable model/format. A package `prepare(request:context:)` returns `DesktopCoachPreparedTurnV1`: original request, canonical history bytes, system/history inputs, exact encoded body/hash/count, captured runtime/output mode and the same in-memory run-capable transport. No credentials, headers or tokens enter the persisted value. Generic non-run-capable providers are unsupported before claim.

- [ ] Construct coach sessions as ephemeral, no URL credential storage/cookie persistence and a retained per-session URLSessionTaskDelegate that rejects automatic HTTP redirects by returning nil. Keep TLS default verification. Inject session configuration for fixture protocol classes; do not use a global mutable handler or alter shared Provider sessions.
- [ ] Use the existing StrictPlanningProviderResolver with this factory; local ownership/consent eligibility precedes its credential resolution. Never use AppPlanningProviderFactory or RuntimeCredentialResolver.provider. Construction is:

```swift
let auth = ProviderAuthScheme.automatic.resolved(for: format)
// .openAIChatCompletions:
OpenAIProvider(apiKey: credential, model: model, session: session,
               baseURL: baseURL, authScheme: auth, maxRetries: 0)
// .anthropicMessages:
AnthropicProvider(apiKey: credential, model: model, session: session,
                  baseURL: baseURL, authScheme: auth, maxRetries: 0)
// OAuth factory receives accountId from strict resolver:
OpenAIResponsesProvider(accessToken: accessToken, accountID: accountId,
                        model: model, session: session,
                        maxRetries: 0, tokenRefresher: nil)
```

- [ ] Prepare bytes through the **same concrete static requestBody builder** and JSONEncoder.sortedKeys used in each transport, with immutable arguments/tools empty/auto/4096. API is `.protocolRequested(tokens: 4096)`; Responses is `.providerManaged` and omits unsupported output fields. Require body.count <= 49_152 before claiming. Hash/persist those exact body bytes; an intercepted actual request must equal them. No body rebuilding from newer defaults or fallback stream mode. The sealed runtime records actual kind/model and an opaque SHA-256 of the normalized endpoint URL in live request JSON, not the URL/userinfo/query itself; headers/credential values are excluded. Check profile kind/endpoint identity again at claim/launch so editing the same profile ID cannot silently redirect an already prepared turn.
- [ ] Implement a closed `ProviderFailureDiagnosticV1` formatter in existing LLMProvider.swift with `init(_ error: any Error)`, `category`, `numericCode: Int?`, `line: String`, and `static stopReasonCode(_ reason: StopReason) -> String`: http plus numeric status, unauthorized, retryable_http_exhausted, api_error (no supplied type/message), malformed_stream (no detail), transport plus URLError numeric code, cancelled, decoding, unexpected. Never interpolate description, localizedDescription, URL, codingPath or reflected error type. Closed stop-reason mapping returns fixed tokens for every case and literal `other` for `.other(_)`.
- [ ] Replace the actual three final-error sink expressions and Anthropic's two stop-reason sink expressions with that formatter. Delete only the unused raw readableError helper. Continue throwing the original error object. Existing fixed retry counts/status logs stay; no global logger rewrite. At the desktop outer boundary, map errors to fixed ControlWorkerProviderFailure codes/messages, never raw provider payloads or Foundation descriptions.
- [ ] RED tests use per-session/per-UUID fixture registries with locked access and defer removal, synthetic `.invalid` URLs and fake credentials. New tests must be parallel-safe; do not share existing serialized suites' static handlers or serialize the entire suite. Define a test-only URLProtocol fixture that records actual method/body/auth-header presence, serves complete/malformed SSE or HTTP statuses, handles cancellation, and reports request count. It must fail any unregistered URL rather than forward to the network.

```swift
@Test func coachPreparedBodyMatchesActualAPIAndOAuthRequest() async throws
// Both API formats: actual max_tokens == 4096; OAuth: max_output_tokens absent.
// #expect(actualBody == prepared.body); #expect(sha256(actualBody) == prepared.bodyHash)
// Anthropic x-api-key only; OpenAI Bearer only; OAuth Bearer + account header.
// body exactly 49_152 accepted; 49_153 rejected before claim, including escaping/wrappers.
@Test func coachSingleReservationHasNoRetryFallbackOrAuthReissue() async throws
// Per format 429/503, API partial malformed SSE, OAuth 401/403 => one actual request.
// #expect(requestCount == 1); #expect(refreshCount == 0); original error still thrown.
@Test func coachGenerationRedirectIsNotReplayed() async throws
// Use URLProtocol's actual redirect callback with production session delegate.
// #expect(initialPOSTCount == 1); #expect(destinationPOSTCount == 0)
// Merely returning an HTTP 307 from a stub, or directly calling delegate, is insufficient.
@Test func providerDiagnosticsNeverRenderUntrustedErrorOrStopReason() throws
// Sentinel in http/api/malformed/URLError userInfo/custom Error and .other(sentinel).
// #expect(allowedFixedCategories.contains(diagnostic.category)); rendered contains no sentinel.
// Inspect all five actual sink callsites in review; formatter-only green is not integration proof.
```

If macOS URLProtocol cannot faithfully drive the redirect path, stop that test boundary and obtain review for an owned loopback fixture; do not silently substitute a delegate unit call or external endpoint. Existing non-coach retry/fallback/OAuth-refresh tests remain required regressions.

```swift
@Test func providerFailureAndUnknownStopReasonHaveFixedSafeRendering() {
    let sentinel = "fixture-secret-body-and-url"
    let failure = ProviderFailureDiagnosticV1(ProviderError.http(status: 418, body: sentinel))
    #expect(failure.numericCode == 418)
    #expect(!failure.line.contains(sentinel))
    #expect(ProviderFailureDiagnosticV1.stopReasonCode(.other(sentinel)) == "other")
}
```

## Milestone 3 — Exact worker bodies, pure preclaim request and deterministic parser

**Files:** InputParsingWorker.swift, CoachTurnProcessor region, driver/workflow tests. Dependencies: M1 request encoding; no remote transport needed for this milestone.

**Produces:**

```swift
// Existing instance worker entry; preserve old runNext wrapper behavior.
package func runClaimed(_ initialClaim: DurableWorkClaim) async throws
// CoachTurnProcessor static preclaim read, using the caller's DB transaction:
package static func prepareRequest(workId: String, expectedWorkVersion: Int,
                                   in db: Database) throws -> CoachTurnProviderRequestV1
// Additional CoachTurnProcessor initializer label, all other arguments unchanged:
throwingProvider: @escaping @Sendable (CoachTurnProviderRequestV1) async throws
    -> CoachTurnProviderOutcomeV1
// Desktop-only optional terminal-commit parameter on the exact worker path:
typealias DesktopControlCommitV1 = @Sendable (
    @escaping @Sendable () throws -> Void
) async throws -> Void
```

- [ ] Extract each current runNext post-claim body into runClaimed, retaining snapshot validation, latest-claim actor, 15/60-second renewal, cancellation check and exact existing domain terminal commands. runNext continues legacy claimNext, calls runClaimed and returns true; no legacy behavior/scope change.
- [ ] Reject a runClaimed claim whose workerId differs from the configured worker, wrong kind/aggregate, expired/stale lease or invalid current attempt record. Reuse ControlWorkerCommandEnvelopeFactory validation; do not fabricate envelopes/claims just to authorize a domain command.
- [ ] Factor CoachTurnProcessor's existing graph/history construction into one DB-taking pure builder used by both preclaim preparation and running snapshot. Preclaim uses checked work.attempt + 1, actual immutable workInput and current heads/history; it must not require a future durable attempt/envelope. Running snapshot continues to require the real claim/attempt/envelope. Request bytes after claim must match prepared request bytes; renewal version changes alone do not change request history.
- [ ] Store a throwing provider closure internally; the existing initializer adapts its nonthrowing provider with `await provider(request)`. The new exact desktop caller uses throwingProvider. Task-group child uses `try await`; ledger/integrity errors therefore escape and cannot become `.failed` model results or `.canceled` success. Preserve legacy callers/tests and original failure-branch decisions.
- [ ] The desktop `runClaimed` overload additionally accepts `commit: DesktopControlCommitV1`; it passes its already constructed existing terminal domain command through this callback. The driver runs that closure synchronously on its actor after checking the captured generation and stop/revoke gate, without an await between check and command execution. Legacy runNext/runClaimed uses its current direct commit path. This closes the checkCancellation-before-synchronous-write race without changing domain commands or historical workers' cancellation contract. Both exact parser and coach use this boundary; model/storage failures still propagate normally.
- [ ] Supply a deterministic InputParserV1 requiring text/createGoal, assigned exact camp, empty candidates and nonempty inline text, then return `InputParseResultV1(route: .coaching, candidateCampIds: [], assignedCampId: camp)`. All mismatches yield fixed deterministic routing failure; no URL/file fetch/cross-camp choice. The exact revision adapter requires an A3-sealed revision operation workId/nextQuestionId and returns only its application-authored correction question; absent/mismatched seal is not remote-failure fallback.
- [ ] RED→implementation→focused checks:

```swift
@Test func exactWorkerCannotConsumeAnotherQueuedWorkItem() async throws
// Two actual domain-generated items; runClaimed(B) => only B mutates, A bytes/attempt unchanged.
// wrong-worker/kind/expired claim => thrown error, no provider/domain result.
@Test func coachPreclaimRequestEqualsClaimedRequestAfterRenewal() async throws
// prepare at version v, claim, renew real lease; provider sees same canonical request bytes.
// concurrent answer/head/work version drift => preparation/claim fails before dispatch.
@Test func throwingCoachLedgerFailureDoesNotBecomeModelFailure() async throws
// throwingProvider throws injected journal failure; runClaimed throws same failure.
// zero new question/understanding rows; work remains honestly recoverable, not fake succeeded.
@Test func desktopTerminalCommitGateRejectsStaleGeneration() async throws
// Gate before terminal callback: stop/revoke wins => no domain question/parse commit.
// Domain commit wins synchronous actor boundary => retain receipt; stop joins it, no rollback fiction.
@Test func desktopTextRoutingNeedsNoRemoteRuntimeOrReservation() async throws
// Real capture, exact claim/run => input.coaching, zero factory calls and coachAttempt rows.
// wrong camp/type/intent/candidates => fixed failure, not guessed routing.
```

Arrange DB graph through existing capture/parse/convert/open-session commands. Fixtures may insert corruption only for a declared negative case, never insert success receipts as substitutes for domain execution.

## Milestone 4 — Exact eligibility, policy/consent CAS and durable attempt journal

**Controlling entry amendment:** the independently approved
[`goal-driver-entry-amendment.md`](goal-driver-entry-amendment.md) controls M4's
attempt-ID grammar, closed carrier decoding, always-retained A2 provenance
witness, and corresponding test oracles. All other M4 clauses remain unchanged.

**Files:** A1 domain/store extensions, workflow tests, failure code registrations. Dependencies: M2/M3.

**Consumes:** A1 `prepareSubmission`, snapshot/list and immutable journal primitives; approved UpdateDesktopCoachContextCommandV1; existing static DurableWorkStore.claim.

**Produces:** main-plan `claimEligible(workId:expectedContextVersion:workerId:now:) -> DesktopControlClaimResultV1` plus a coach overload carrying expected work version and prepared request. Both delegate to a single DB-taking implementation. Add typed methods for dispatch CAS, terminal receipt, context update, and one-turn continuation; do not encode arbitrary executable JSON.

```swift
package func claimEligible(workId: String, expectedContextVersion: Int,
    expectedWorkVersion: Int, prepared: DesktopCoachPreparedTurnV1,
    workerId: String, now: Date) throws -> DesktopControlClaimResultV1
package func markCoachDispatching(attemptId: String, expectedVersion: Int,
    generationId: UUID, workerId: String, now: Date) throws
package func appendCoachTerminal(attemptId: String, expectedVersion: Int,
    terminal: DesktopCoachTerminalReceiptV1, now: Date) throws
package func updateCoachContext(_ command: UpdateDesktopCoachContextCommandV1) throws
```

The prepared transport object is memory-only; only its explicitly typed serializable request fields are persisted. `DesktopCoachTerminalReceiptV1` contains schema version, attempt/work/context/runtime/output-mode/request-hash identities, terminal category, usage tag/counters, fixed primary/cleanup categories, completion/join times and its canonical receipt hash. It contains no error descriptions. Original request and terminal receipt remain under A1 requestJson/resultJson retention; safeReceiptJson retains only the approved safe IDs/hashes/versions/counts/times.

- [ ] Select candidates by exact live carrier joins, ordered createdAt + ID. Revalidate inside ONE write: nonredacted input/carrier; fixed input/goal/session/camp/sourceInputId; createGoal/text ownership and workInput hash/key; actual allowed session/goal heads; active unarchived camp and captured lifecycle version; KernelControlRecord("global").dispatchMode == .running; exact due queued/retry state; `0 <= attempt < maxAttempts == 4`; context/work expected versions; selected supported runtime and unchanged resolved profile identity; effective consent and budgets. A missing global control record or broken graph throws an integrity error, not ordinary waiting.
- [ ] Valid waiting states do not claim/increment/create attempt: runtime unconfigured/unsupported, consent required, not due, context changed, halted, token/dispatch threshold, usage uncertain/invalid, request too large. Add proposed closed wait reason `workerAttemptsExhausted` for exhausted parser/coach work; do not call it free/retryable or increment a fifth attempt. This is presentation of the existing worker ceiling, not a new domain transition.
- [ ] Existing capture cloudExecution permits only its originally captured selected runtime. An unconfigured capture or later different profile/model requires the explicit runtime-bound receipt. Validate receipt actor/device/input/profile/model/context version/time/grant/revoke; runtime change invalidates earlier runtime consent, while original InputEnvelope privacy/hash remains unchanged. Context/policy changes require exact local owner/device/CAS and no running control turn; only revoke with unchanged runtime is allowed during a run. A3 calls the driver's fenced revoke boundary from M5, not the store method alone.
- [ ] In the same write, checked-count all prior conservative remote reservations for this goal, apply per-work ceiling, full request limit and observed-token threshold, consume at most one applicable continuation, call `DurableWorkStore.claim(..., in: db)`, then insert `coach-attempt:<workId>:<claim.attempt>`. Parser/local revision returns nil attempt receipt. Injected reservation insert failure must roll back claim, attempt/event, continuation consumption and journal together.
- [ ] Attempt request seals canonical request body bytes/hash, captured context/version/policy, selected runtime/profile kind/model/endpoint identity, consent identity and effective output mode. Top-level operation stays prepared; transitions are append-only tagged result entries reserved→dispatching→terminal with expected operation-version CAS. Terminal becomes committed for a real terminal result (including failure/denial), failed only for pre-dispatch preparation failure, redacted only through existing retention. Do not occupy the userMutation partial-unique slot.
- [ ] Dispatch CAS validates exact worker/attempt and latest persisted lease (renewals can advance version), still-live graph/context/consent/dispatch and actor generation before synchronous run creation. A race stop/revoke before dispatch records notDispatched; no generation call. A possibly sent request never gets a reused reservation. Proved notDispatched has no invented Usage(0); keep its conservative reservation history visible.
- [ ] Terminal CAS runs after actual producer/consumer join and before returning the domain outcome to CoachTurnProcessor. Successful generic Usage including zeros is observedUnproven; failed/interrupted/no terminal is unknown. Validate nonnegative Int counters and use addingReportingOverflow for input/output/cache and cumulative sums; overflow records coachUsageInvalid without wrapped/clamped totals. Same receipt hash replay is idempotent, different terminal hash is conflict. Storage/receipt failure throws through M3; never continue to domain success after it.
- [ ] Define a local-owner continuation command (operationId/envelope/inputId/expectedContextVersion/priorAttemptId/priorTerminalHash). Journal it as ownerKind system to avoid holding the user slot. It authorizes exactly one following eligible remote reservation, consumed in the claim transaction, and is rejected if prior attempt/context/hash differs. Replaying the same command cannot grant another turn. Answer/confirm, settings wake or transient worker retry never silently grants continuation.
- [ ] Test actual transactions and snapshots:

```swift
@Test func desktopEligibilityWaitsWithoutTakingLegacyOrBlockedWork() async throws
// A eligible, B localOnly, C unrelated same-kind, D tombstoned/cross-camp corruption.
// Run A; #expect(B.attempt == 0 && C == beforeC); corrupted owned graph throws.
@Test func claimAndAttemptReservationRollbackTogether() throws
// Abort coachAttempt INSERT via temp trigger; #expect(work == beforeWork)
// #expect(attemptRows == beforeAttempts && eventRows == beforeEvents)
// #expect(continuationReceipt == beforeContinuation && coachAttemptCount == 0).
@Test func runtimeConsentAndPreparedBodyAreRevalidatedAtClaim() throws
// Change context/profile endpoint or revoke after preflight => no claim/provider.
// new runtime cannot inherit original captured cloud permission or old receipt.
@Test func coachUsageAndContinuationNeverCreateFreeAutomaticRetries() async throws
// default Usage() => observedUnproven; error/no-terminal => unknown; next invocation == 0.
// duplicate terminal/continuation => exactly one grant; eighth reserved => ninth zero.
// explicit continuation cannot exceed work.attempt 4 or reduce retained reservation count.
// Int.max + 1, negative counters => invalid; no overflow trap or later dispatch.
```

Use at least two actual coach works under one goal to exercise the eight-goal ceiling without inventing a work with maxAttempts > 4: three transient failures with explicit continuations then a successful question on each work's fourth attempt; the real user answer queues the second work. Its next eligible work must not dispatch a ninth generation. Do not fabricate succeeded receipts, silently bypass unknown usage, or continue a terminally failed goal. Preserve historical context/intent bytes on context updates and redaction regression checks.

## Milestone 5 — Real producer ownership, stop/revoke linearization and safe completion

**Files:** adapter, driver, workflow/provider tests. Dependencies: M2–M4.

**Produces:** `DesktopGoalControlDriver` actor with explicit `start()`, `wake()`, `stop(reason:) async throws`, `revoke(_ command: UpdateDesktopCoachContextCommandV1) async throws`, and read-only control status. Stop reasons are a closed enum halt/shutdown/runtimeRevoked; status distinguishes idle/running/stopping/failed. No UI or AppStore is attached in A2.

- [ ] Register each parser/coach child Task in its actor-owned slot before it can request launch. At most one per kind per generation; all existing children are retained through success/failure/cancel. A new generation cannot replace a stopping task. Persistent/cleanup errors are surfaced through typed driver status and a throwing lifecycle result; no discarded Task errors or try? around ledger writes.
- [ ] The worker's throwing provider closure requests launch on the driver actor. Its actor-isolated method has **no await** between checking generation/stopped status, synchronously marking dispatching in the DB, constructing `startTurn(...)`, and retaining the returned real run handle. This is the local linearization boundary. Halt/revoke closes that actor gate before canceling tasks; completed stop cannot be followed by an older task starting a run. Preflight outside actor/DB may become stale and must pass M4 again.
- [ ] Start the monotonic 120-second deadline at that dispatch boundary, not after first token/consumer scheduling. Retain producer completion, event consumer and deadline task. A single terminal turn is only a candidate until stream validation and producer completion both succeed. On timeout, external cancel, schema failure or consumer error, cancel producer and consumer, then explicitly await both results and join/cancel the deadline task on every path. No detached cleanup or timeout abandonment.

```text
launch/retain real run -> race validated event consumption with deadline
  success: join real producer -> persist terminal -> return domain outcome
  failure/cancel/deadline: cancel real producer + consumer -> join both
                         -> persist safe terminal -> throw/return typed failure
```

- [ ] Preserve primary and unexpected cleanup failures separately in a typed safe result; expected cancellation is a cancellation terminal, not a generic provider error. A producer completion error after stream EOF is still failure. If cleanup does not finish, status remains stopping and no replacement dispatch occurs; if it joins with unexpected failure, lifecycle returns that error/status failed, not stopped-success. A canceled caller cannot skip the joins by canceling a separate cleanup waiter.
- [ ] Map malformed/truncated/tool/schema/local-validation failures to deterministic control-worker failure; retryable HTTP/transport to transient safe classification. OAuth unauthorized uses visible `coach_authentication_required` transient classification so existing worker policy can retain retryable work, but unknown usage blocks generation until explicit runtime recovery and continuation; it does not refresh inside the generation transport. Existing maximum-four branch still applies. An error classified retryable is never itself permission for another generation.
- [ ] `revoke` first closes the input's launch gate and advances local generation, commits the unchanged-runtime revocation/context CAS, cancels and joins that input's owned work, then returns. If persistence fails, keep the local gate closed, still perform owned cleanup, expose persistence plus cleanup failures, and do not claim durable revoke succeeded. It may not alter the run's sealed runtime/receipt. Ordinary runtime changes remain blocked while work runs.
- [ ] Before domain result publication, preserve the existing worker cancellation/current-claim fences and use M3's desktop terminal-commit callback on this actor. If the gate closed first, reject the stale commit; if a synchronous domain commit already won that actor boundary, stop/revoke waits for it and the owned task rather than pretending to undo it. Safe usage receipts may describe a completed old attempt even after context changed; they cannot overwrite current UI/runtime state. A journal failure or lost lease remains visible rather than manufactured as model failure.
- [ ] RED tests use a real `makeLLMProviderTurnRunV1` producer with gate-controlled cancellation observation and delayed completion, plus a separately retained consuming task. No owner Boolean substitutes for joined tasks:

```swift
@Test func coachDeadlineCancelsAndJoinsActualProducerBeforeNextDispatch() async throws
// Advance injected monotonic deadline by 120 s after actual launch; producer observes cancel.
// Keep producer cleanup gate closed: #expect(driver.status == .stopping)
// #expect(secondRunCount == 0 && stopResult == nil); release cleanup then await every Task.value.
@Test func haltAndRevokeFenceLaunchAndPreservePrimaryCleanupFailures() async throws
// Gate immediately before actor launch; completed stop/revoke => actual starts == 0.
// Gate after start: stop waits for real completion; stale generation can't publish a question.
// Inject primary schema failure and independent producer cleanup error; both safe codes retained.
@Test func streamTerminalBeforeProducerFailureIsNotCoachSuccess() async throws
// Emit valid turn then throw at producer cleanup; no question/understanding domain commit.
// Original error remains observable; receipt unknown and automatic next run blocked.
```

Use injected clock/sleeper only for deterministic test time; production policy stays 120 seconds and real producer completion is always awaited.

## Milestone 6 — Exact expired-lease adoption and durable future wake

**Files:** DurableWorkStore.swift, desktop store/driver, workflow tests. Dependencies: M3–M5.

**Produces:** exact DB-taking adoption and an owned wake snapshot. The recovery entry does not itself authorize model dispatch:

```swift
package static func adoptExpiredControlWork(workId: String, expectedVersion: Int,
    expectedLeaseOwner: String, expectedLeaseExpiresAt: Date,
    currentWorkerId: String, now: Date, in db: Database) throws -> DurableWorkRecord
// DesktopGoalWorkflowStore methods:
package func reconcileOwnedExpiredWork(workerId: String, now: Date) throws
package func nextOwnedWake(now: Date) throws -> Date?
```

- [ ] Factor the current adoption loop's one-row body without changing legacy kind-wide selection/results: exact current kind inputParsing/coach, running state, version/worker/expiry equality, positive attempt, finite expired lease, checked version; requeue/clear lease, close real attempt as interrupted and append real event in the same DB transaction. Add lease-owner equality to the exact CAS; retain old command/event metadata. No live-lease stealing or reset of attempt count.
- [ ] Desktop recovery selects only exact carrier-owned rows and revalidates the same graph in its write transaction before calling the primitive. Unrelated legacy/same-kind/other-camp rows remain byte-identical. Tombstoned/mismatched owned graphs fail closed. Never use either worker's kind-wide recoverInterrupted in this driver.
- [ ] Do not requeue a run still registered in this driver's in-memory task map, even if its lease expired; first cancel/join that actual producer, then reconcile. This prevents the same app from replacing its own still-running provider after a renewal failure. A restarted app can only establish durable prior ownership/lease expiry, not claim remote-server termination; ambiguous prior dispatch remains unknown.
- [ ] Recovery repairs attempt-journal state in the **same write** as adoption. Reserved with proof that dispatch marker was never committed becomes notDispatched, never fake observed zero. Dispatching without terminal evidence becomes terminal unknown once and consumes its conservative slot. An already terminal receipt is validated and retained, never overwritten from observedUnproven to invented exact usage. Existing succeeded/failed work plus interrupted journal is reconciled without a new Provider call. Any mismatch/receipt conflict throws and rolls back adoption.
- [ ] On startup and every wake, reconcile owned expired work, then consider eligible due candidates. Scheduler next date is minimum future owned retry notBefore or owned running leaseExpiresAt. A live lease at bootstrap is untouched but schedules its future expiry; at wake re-read, and renewal moves the wake forward without adoption. Owned rows already expired but blocked by camp/dispatch/context wait for an explicit relevant event, not zero-delay polling. Event wakes must be coalesced without losing a wake between scan and sleep; use one actor generation/wake counter and one retained cancelable sleeper.
- [ ] Stop cancels/joins sleeper and worker tasks and keeps the gate closed; resume/start uses a new generation and fresh durable scans, not old cached heads. Due retry with uncertain usage waits for continuation; expired maximum-attempt work is visible workerAttemptsExhausted, not a fifth run.
- [ ] RED tests run real leases/DB rows with injected dates; no wall-clock sleeps needed:

```swift
@Test func ownedLiveLeaseIsAdoptedOnlyAtItsFutureExpiry() async throws
// Bootstrap before expiry => work/attempt/events byte-identical and nextWake == expiry.
// Advance to expiry => one interrupted attempt/event, requeued work, unchanged attempt number.
// Repeat wake/restart => no duplicate adoption/event; unowned same-kind bytes unchanged.
@Test func renewedLeaseMovesWakeAndAdoptionRollbackIsAtomic() async throws
// Renew just before wake => new expiry scheduled; old snapshot cannot adopt.
// Abort receipt/event write via temp trigger => work/attempt/event/journal all rollback.
@Test func ambiguousRecoveredCoachAttemptWaitsInsteadOfRegenerating() async throws
// Dispatching/no terminal => one unknown receipt, provider calls == 0 across repeat wakes.
// Current registered producer past expiry => canceled/joined before any requeue/replacement.
// Halt while sleep/renewal/recovery active => all owned tasks joined, old generation starts zero.
```

## Milestone 7 — Exact source inventory and reviewed Core handoff

**Controlling entry amendment:** the independently approved
[`goal-driver-entry-amendment.md`](goal-driver-entry-amendment.md) controls only
M7's entry-date successor name and intersections with successor sets added after
the original review. The exact four paths and every other M7 gate remain
unchanged.

**Files:** explicitly added DurablePlanningTests.swift; existing new A2 test files/report. Dependencies: M1–M6.

- [ ] Add a separate `desktopCodingClosureA2DriverSuccessorFiles20260906` with exactly:

```swift
[
    "Sources/AgentLoopCore/Work/DesktopGoalControlDriver.swift",
    "Sources/AgentLoopCore/Work/LLMCoachTurnProvider.swift",
    "Sources/AgentLoopTestSuite/DesktopGoalWorkflowTests.swift",
    "Sources/AgentLoopTestSuite/LLMCoachTurnProviderTests.swift",
]
```

Assert count/exact membership, empty intersections with frozen manifest and all other exact successor sets, and regular nonsymlink files. Add only this set's membership exclusion to the enumerated-source filter. Keep frozen 206-entry manifest/hash, unaffected live/enumerated 102, sorted equality, every historical hash and A1/runtime/R9-F sets unchanged. A fifth new source file needs a new reviewed addendum.
- [ ] Parent-controlled RED/green sequence for each named test uses only observed `swift run RunTests --filter <literal-test-name>`, with complete stdout/stderr and actual exit status saved to unique task files. Do not probe `--help`, invent flags, truncate logs, loosen tests or run builds/tests during plan preparation. Tests first; an expected failure must identify the missing behavior, not a fixture setup accident.
- [ ] Run current GoalCoachContractTests/Input contract worker cancellation/restart suites, Anthropic/OpenAI/Responses encoding and existing retry/refresh tests, A1 foundation/migration/redaction tests, `a3Revision02EntryBoundaryRemainsByteExact`, and relevant halt/failure visibility suites. Parent then runs authoritative unfiltered `swift run RunTests` and strict App build at the integration gate. No commit/push/release unless separately authorized.
- [ ] Handoff exact diff/source list, intended RED and green outputs, cancellation joins/resource ownership, persisted request/receipt examples with fake data, migration-unchanged evidence, deviations and unresolved errors for independent review. A2 completion means Core behavior tested with real DB commands and controlled transports, not that the desktop workflow or a remote service was accepted.

## A3 lifecycle integration gate and non-goals

Parent decision during preparation: A2 remains Core-only. A3 must bind **all** AppStore stop/shutdown/runtime-revoke paths to this driver's gate/cancel/join, before claiming the app includes the new owner. Current `AppStore.emergencyStopCamp` only awaits `orchestrator.emergencyStop`; `Orchestrator.emergencyStop/shutdown` currently own existing engine/planning paths, not this new driver. Passive haltStateChanged observation after completion is not an owned stop boundary.

A3 must inventory AppStore's bootstrap/termination calls, emergencyStopCamp, runtime/profile/consent mutation entrypoints and their direct Orchestrator callers, and specify ordering plus repeated-stop/error joins. Use the M5 driver lifecycle interface; keep existing direct Orchestrator/legacy caller contracts unchanged unless an exact separately reviewed Kernel/Orchestrator addendum is genuinely required. This A2 plan does not authorize that source file or claim the app-wide race is solved. Runtime switches cannot retain old coach credentials or silently start before the new explicit consent/context receipt.

A3 also implements submit conversion/session stages, correction/answer/confirmation gestures and the application snapshot/controller; D1 renders pre-dispatch provider-aware limits and sealed historic modes. A2 exposes the real journal/read data and exact local revision adapter but does not fake those gestures, auto-confirm understanding, start a mission, fabricate verification, or write project memory.

## Preparation self-check / decisions for reviewer

- Covered: private DTO + initializer reconstruction; exact owned claims with attempt/global-dispatch checks; claim+reservation/continuation atomicity; OAuth-supported output policy, automatic auth resolution, zero internal retries/no refresher/redirect; source-safe error and other-stop sinks; throwing persistence seam; real producer joins; exact expiry recovery and future wakes; A3 lifecycle boundary.
- Proposed ordinary technical choices needing this review: local response-validation sizes, workerAttemptsExhausted presentation, throwing desktop initializer and actor-gated exact terminal commit, exact four-file source successor, and Provider sink addenda. They do not alter approved product/SQL/consent/attempt phases or user authority.
- Explicit unsupported evidence cases: a non-run-capable custom provider cannot coach; a fixture that cannot prove redirect nonreplay cannot clear that test; no local test proves remote output compliance or exact server stop. Report those accurately instead of paid probes, fallback transports or fake green.
