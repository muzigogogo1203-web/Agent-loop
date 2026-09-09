# Output-policy plan revision report — 2026-09-06

Status: **doc-only revision delivered; independent scoped review pending before A1 entry**. This implements the wording/contracts selected in [the owner decision](goal-coach-output-policy-decision.md), not application functionality or a runtime-gate clearance. Docs ownership is released to the parent after this report.

## Exact changed documents

- `goal-flow-plan.md`: policy type/default and strict nested JSON; A2 effective request/receipt modes, conservative generation reservations, coach-only no-reissue transport contract, client deadline plus producer join; corresponding request/transport/lifecycle and UI presentation tests.
- `goal-foundation-plan.md`: historical approval distinguished from this pending revision; provider-aware policy persistence/validation and canonical hash/replay/invalid-JSON tests.
- `.superpowers/sdd/goal-foundation-plan/task-1-brief.md`: same A1 contract/test changes and pending-review notice.

This report is the only additional authored file. Preimages under `goal-output-policy-before/`, earlier reviews/hashes, old seam proposal, owner decision, other plans, source, AGENTS and runtime artifacts were not modified by this task.

## Contract delta

- Replace the misleading uniform `maximumOutputTokens` field with closed `DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4_096)`. V1 accepts exactly the nested canonical shape `{"apiRequestedTokens":4096,"kind":"providerAware"}`; reject unsupported tags/values/types/keys and legacy-field fallback. Policy participates in canonical context/original-intent bytes, hashes and replay identity.
- A1 persists unresolved/unconfigured runtime configuration without claiming effective Provider semantics, consent, attempts or credential resolution. A2 seals `protocolRequested(tokens: 4_096)` for supported API versus `providerManaged` for OAuth with the captured runtime and actual request bytes/hash, and retains that mode in terminal receipts/restart presentation. This uses existing JSON carriers, not new SQL.
- Maximum eight conservative application-issued generation reservations includes explicit retries; it is not a count of server-internal generations. A request possibly sent cannot reuse its reservation. Existing maximum-four worker ceiling, request-byte bound, observed-token threshold, checked sums, unknown/unproven-usage continuation fence and ownership/consent/halt/revoke rules remain.
- Coach-only API/OAuth factories use `maxRetries: 0`; OAuth additionally uses `tokenRefresher: nil`. No hidden fallback, generation-POST redirect replay or auth refresh/reissue may evade reservation accounting. Authentication recovery remains explicit runtime flow; unrelated Provider defaults are unchanged.
- The 120-second limit is a client dispatch deadline followed by cancellation and joined actual producer cleanup before stopped/another dispatch. Cleanup may extend beyond the deadline; no exact remote stop or universal remote output compliance is promised. OAuth is not described as unlimited or capped at 4,096 by the app.
- Added A1 policy canonical/replay/drift and invalid-JSON expectations; added A2 actual intercepted request/mode replay, retry/auth/redirect accounting and real cancellation-join expectations; added UI mode/deadline presentation assertions. These are planned tests, not executed results.

## Review and checks performed

Read all three complete preimage diffs. Read-only document checks confirmed: main SQL code block unchanged; every main `Files` source list unchanged; A1 and brief exact allowlists unchanged; A1 and brief contents from phase-specific contracts through EOF identical. Search found old `maximumOutputTokens` only in explicit rejection requirements, not a live policy field. These checks are documentation consistency evidence only.

No implementation, build, tests, app launch, Provider/network call, credential read, signal or new agent. No source-safe logging or lease-expiry recovery proposal was integrated; those remain separately reviewable A2/A3 seams. Parent must review this policy diff independently and retain the runtime gate before A1; this report does not self-approve either gate.

## SHA-256 identities

Current revised documents (full paths are repository-relative):

```text
a6166c3fb5b9622450a20d614c01dd5ea87dfbdf79ded48656c353e925a5d5c5  docs/collaboration/tasks/2026-09-05-desktop-coding-closure/goal-flow-plan.md
c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc  docs/collaboration/tasks/2026-09-05-desktop-coding-closure/goal-foundation-plan.md
f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82  .superpowers/sdd/goal-foundation-plan/task-1-brief.md
```

Retained preimages, independently hashed here without edits:

```text
f235bc282ac837638171f6cb632eb5e163c29beafcc543c177bbc2e245030c70  goal-output-policy-before/goal-flow-plan.md
f8c33b3478b6815185274bc7378fee2ae357b2e2a3756fa76af3b29b0c77080b  goal-output-policy-before/goal-foundation-plan.md
d97edbc79223ed8338062538ad2fc6367b1b2bfb506283557058628f5820a968  goal-output-policy-before/task-1-brief.md
```
