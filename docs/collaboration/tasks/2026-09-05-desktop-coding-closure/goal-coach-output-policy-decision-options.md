# Coach output policy — two decision options

Status: **recommendation to product owner, not an accepted amendment**. No source or approved plan changed. A1 has not started, so its policy encoding can still be corrected before any new carrier exists.

## Facts that determine the decision

- Master spec §7.2 treats Provider/model/CLI as interchangeable engines; §24.5 requires kernel control of rounds, budgets, timeouts, retries and concurrency. Neither it nor the accepted takeover spec specifies a uniform **4,096 output-token** cap. The takeover explicitly authorizes ordinary reversible product/technical decisions, with independent review and existing authority gates.
- The uniform cap originates in our `goal-flow-plan.md:153–158,266` and is copied into `goal-foundation-plan.md:41`. It is a reviewed implementation choice, not a user-specified exact token budget or immutable product invariant.
- Current `OpenAIResponsesProvider.requestBody` discards `maxTokens`, and the existing OAuth body test asserts no `max_output_tokens`. Its comment describes backend rejection; we have not reverified the remote endpoint. API transports serialize `max_tokens`. Neither a local request test nor a generic Usage result proves a remote gateway's actual generation count or compliance.
- Responses has both ordinary retries and a separate token-refresh/reissue branch; `maxRetries: 0` does not disable the latter. The three transports expose actual producer completion handles. These facts apply regardless of output-policy choice.

## Comparison

| | Option 1 — uniform protocol cap, API-only coach | Option 2 — explicit provider-aware output contract |
| --- | --- | --- |
| Output promise | 4,096 enforced through a conforming API protocol; unsupported combinations blocked. | API requests 4,096 through its supported protocol; OAuth output is provider-managed, with **no app guarantee of exactly 4,096 or less**. |
| OAuth desktop coach | Blocked before claim/credential resolution, despite existing OAuth runtime support elsewhere. | Remains eligible under captured runtime/consent and the shared controls below. Do not send a speculative unsupported field. |
| User impact | An OAuth user cannot use the new core goal flow without configuring a suitable API runtime; may require a paid service they did not choose. | Preserves the existing runtime path while showing its real limit semantics before dispatch. |
| Risk/cost statement | Uniform per-response protocol bound, not a universal aggregate-token or monetary guarantee. | No uniform hard output-token bound; verbose OAuth responses remain possible within the provider's own limits and client deadline. Unknown usage still blocks the next automatic generation. |
| Product judgment | Legitimate safety-oriented option, but narrows engine compatibility to preserve a self-imposed parameter. Do not silently switch users to paid API access. | Better fits the accepted interchangeable-engine direction without pretending all engines offer identical controls. |

**Recommendation: Option 2.** This is a normal product/technical tradeoff the appointed owner can decide, record and independently review. Option 1 is not compelled by the master spec. My earlier seam proposal treated the draft cap as fixed; it should remain a historical proposal, not force an API-only product by default.

## Controls unchanged in both options

- Maximum **eight conservatively reserved application-issued generation attempts**, including retries; durable worker attempts and per-goal cap both apply. No reservation reuse after a request may have been sent, and no assertion that we control a remote service's internal generations.
- Coach-only factories set API/Responses `maxRetries: 0`; for eligible OAuth in Option 2 also set `tokenRefresher: nil` inside the generation transport. A 401/403 becomes a visible authentication stop; recovery/re-authentication occurs through the existing explicit runtime flow, and another generation requires a new reservation. No silent generation reissue after refresh. Keep unrelated provider defaults unchanged.
- No hidden streaming fallback or automatic generation-POST redirect replay. Retain the previously proposed coach-only transport restriction and intercepted-request tests.
- **120 s client dispatch deadline**, cancellation of the real producer, and joined cleanup before stopped/another dispatch. Cleanup may finish later; neither option guarantees a remote server stopped computing at exactly 120 s.
- Complete encoded request-body limit **49,152 UTF-8 bytes**, observed-token stop threshold **32,768**, checked counters, strict terminal JSON, and permanent rejection of malformed/truncated/tool output.
- Generic successful usage remains `observedUnproven`; failed/interrupted/no-terminal usage remains unknown, never free. Explicit one-turn continuation is required where usage is unconfirmed and cannot override the eight-attempt cap.
- Captured camp/privacy/runtime, runtime-specific remote consent, halt/revoke fences, exact desktop ownership, and cancellation joins remain unchanged. Local truncation or byte limits must never be advertised as an exact model token limit.

## Exact A1/A2 impact before A1 starts

**Option 1:** A1's existing `maximumOutputTokens: Int` default/validation and SQL remain as drafted. A2 adds the explicit OAuth unsupported eligibility branch and conforming-API capability checks. Tests must show queued work/zero attempt/no provider resolution on unsupported OAuth, and no runtime substitution.

**Option 2:** replace A1's misleading uniform `maximumOutputTokens` field with a closed Codable output-policy value in the already planned `Domain/DesktopGoalWorkflow.swift`:

```text
DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4096)
DesktopCoachPolicyV1.outputPolicy: DesktopCoachOutputPolicyV1
```

The policy may be persisted while runtime is unconfigured; it does not claim a runtime has been selected or grant remote permission. Validate its exact supported tag/value, include it in canonical context/intent bytes and hashes, and require normal context CAS for any later policy change. No old-field decoding fallback is needed because A1 has not created these records.

No SQL table/column/check, migration name, retention rule, scope allowlist or A1 completion point changes: both tables already store context/request JSON. Update A1 canonical round-trip/hash/replay/conflict/invalid-tag tests and its implementation brief before execution; review the changed contract. No new production file is needed.

In A2, derive and seal `effectiveOutputLimit` in each existing attempt request/receipt: `protocolRequested(tokens: 4096)` for supported API versus `providerManaged` for OAuth, alongside captured runtime/model/policy version and exact request hash. UI/read model must display that distinction before dispatch and after restart; never label provider-managed output “unlimited” or “guaranteed 4096.” Request-body tests cover both actual formats and OAuth field omission; retry/auth/redirect fixtures prove one application generation request per reservation; unknown-usage/timeout/join tests remain mandatory.

A3 exact-owner recovery and lease-expiry scheduling are unaffected, apart from reading the new policy value and retaining its sealed per-attempt mode on replay. A later runtime change must not reinterpret a past attempt under the new provider's limit semantics.

## Decision versus authority

Choosing either policy and implementing/testing it locally is within ordinary reviewed ownership. It does **not** authorize reading real secrets, invoking paid Providers, refreshing a real user's credentials for validation, buying API access, changing the user's selected runtime, changing privacy defaults, or dispatching user data without its existing consent. Those remain separate user/runtime actions and authority gates.

Root should record its choice, amend/re-review the exact affected passages in the main plan and A1 extraction/brief, and supersede only the conflicting paragraph of the earlier coach-seam proposal before A1 begins. No user clarification is intrinsically required merely to correct this self-imposed parameter; ask if a real cost/privacy decision or an explicitly promised personal hard budget would be changed. No such user-specified 4,096 promise was found in the inspected source-of-truth documents.
