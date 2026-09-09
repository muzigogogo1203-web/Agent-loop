# Owner decision — truthful provider-aware coach limits

2026-09-06. Root read the complete options analysis and the relevant current request builders/plan fields. Choose Option 2 from `goal-coach-output-policy-decision-options.md`: preserve the existing OAuth runtime path with explicit provider-aware output semantics, not an API-only coach imposed by a draft uniform limit.

The 4,096 uniform cap was an implementation-plan choice, not a user-specified exact budget or master-spec invariant. This is an ordinary recorded technical/product correction before A1 persistence exists. It does not authorize paid calls, credential reads, real refreshes, runtime substitution, privacy changes, or dispatch without existing consent. No source implementation has started.

Accepted direction for the revised plan:

- Persist the closed `DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4096)` policy. API requests carry the protocol output parameter; OAuth is explicitly provider-managed. Neither local request tests nor the UI claim universal remote compliance or a uniform 4,096 OAuth bound.
- Seal each attempt's effective output mode with its captured runtime and request bytes. Show it before dispatch and after restart; past attempts never acquire a later runtime's semantics. No local truncation presented as a server token cap.
- Retain eight conservatively reserved application-issued generation attempts, the durable worker ceiling, 49,152 request bytes, 32,768 observed-token threshold, unknown/unproven usage blocking automatic continuation, exact ownership, runtime-specific consent and halt/revoke fences.
- Retain the 120-second client dispatch deadline followed by joined real producer cleanup; do not promise an exact remote-server stop acknowledgement. Coach-only retries/fallback/redirect/auth reissue must not bypass reservations. OAuth generation transport uses no internal retries or token-refresh/reissue callback; authentication recovery remains the explicit runtime flow.

A1 requires only policy type/JSON validation, canonical hash/replay tests and brief updates before first implementation; no SQL/table/retention or source-file scope change. A2's existing request/receipt/UI contracts require the effective-mode distinction and transport tests. Other useful portions of the earlier seam proposal (source-safe error logging and lease-expiry-aware exact recovery) remain proposals for explicit integration/review; its OAuth-blocking recommendation is superseded by this decision.

Next gate: revise only affected main-plan/A1/brief passages, preserve preimages, and independently review the resulting diff. This decision does not clear the runtime full gate, approve unreviewed A2 source changes, or mark any application functionality delivered.
