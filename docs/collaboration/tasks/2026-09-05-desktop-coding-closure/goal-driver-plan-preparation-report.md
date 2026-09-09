# A2 driver plan preparation report — 2026-09-06

**Delivered:** `goal-driver-plan.md`, 385 lines, SHA-256 `7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d`.

**Status: PENDING parent approval, completed/reviewed A1 and the parent's runtime/resource entry gate.** This is doc-only preparation, not implementation authority or application acceptance. Docs ownership is released to the parent with this handoff. The parent's reported host resource block does not permit further source/build/test work; this subtask performed none.

## Seven implementable review boundaries

1. Private canonical request DTO and strict response DTO that reconstructs the real UnderstandingContent initializer.
2. Coach-only one-generation transport preparation, automatic auth resolution, OAuth support and source-safe diagnostics.
3. Exact worker body/preclaim request extraction, throwing persistence-error propagation and actor-gated desktop terminal commit.
4. Owned eligibility/consent/context CAS, claim+reservation+continuation atomicity and durable safe terminal receipts.
5. Actual producer/consumer/deadline ownership, cancellation joins and stop/revoke linearization.
6. Exact expired-lease adoption, ambiguity handling and future lease-expiry/event wake scheduling.
7. Exact four-file A2 source-inventory successor and responsibilities-separated Core handoff.

Each boundary lists source files, consumed/produced interfaces, tests-first steps and observable failure/rollback/count/state expectations. M1/M2 include concrete executable assertion examples; DB/lifecycle cases require actual domain commands, real transactions and real joined Tasks, not inserted success receipts or owner flags. No proposed test was executed in this preparation.

## Verified facts that changed the extraction

- CoachTurnProviderRequest/history entries are not Codable. The plan keeps explicit serialization DTOs in the new adapter rather than widening historical domain types.
- UnderstandingContent synthesized decode bypasses its throwing initializer/exact-key checks. Adapter response DTO calls that initializer with all 14 fields and proposes explicit local validation sizes without claiming model output control.
- CoachTurnProviderV1 cannot throw. A desktop throwing-provider initializer is needed so journal/storage errors escape the worker instead of turning into generic model failure/cancellation; old initializer/legacy execution remain intact.
- Exact transaction-taking DurableWorkStore.claim already exists, but desktop/global-dispatch/max-attempt/consent checks must surround it in the same write. No legacy claim behavior change is proposed.
- Existing completion handles own real Provider Tasks; default retries, malformed-stream fallback and independent OAuth refresh/reissue require coach-only factory configuration. Automatic Anthropic auth must be resolved, not passed through as Bearer.
- Anthropic's two stop-reason logs can expose StopReason.other(String), in addition to the three raw final-error sinks. Both are included in the exact closed-classification scope.
- Kind-wide expiry adoption is not an acceptable desktop recovery entry. Live leases need a future expiry wake; registered live local producers must be joined before adoption/replacement.
- A cancellation check immediately before a synchronous domain write is not an actor generation fence. The proposed desktop-only terminal-commit callback linearizes that existing command on the driver actor; it does not change Input/Coach domain commands or undo a commit that already won the boundary.

## Explicit pending addenda and uncertainty

- Beyond main A2 file scope: existing Provider/LLMProvider.swift and the three concrete Provider files for fixed safe logging, plus DurablePlanningTests.swift for exactly four new A2 source paths. No additional source file, SQL/migration, Package/RunTests or historical manifest edit is proposed.
- Review choices: local acceptance sizes (16,384 bytes/string, 64 entries/array/map, 262,144 final text bytes), workerAttemptsExhausted presentation, throwing/terminal-commit seams, source-sink and exact-inventory addenda. All remain proposals until this plan is reviewed.
- The actual redirect test must exercise production session redirect policy. macOS URLProtocol redirect support has not been run/verified here; if it cannot establish no replay, the plan blocks that test boundary pending a separately reviewed owned local fixture. A manually invoked delegate or static 307 body is not substituted as proof.
- Non-run-capable custom Providers remain unsupported. Local encoding/tests do not establish remote token-cap compliance, server-internal generation count or precise server cancellation acknowledgement.
- Parent explicitly chose **A2 Core-only**. A3 must inventory and bind all AppStore stop/shutdown/runtime-revoke paths to actual driver stop/join before app integration is claimed; passive halt notifications are insufficient. Direct Orchestrator/legacy contracts remain unchanged unless a separately reviewed exact Kernel addendum is required. No AppStore/Orchestrator edit is authorized here.

No discovered issue requires a new user privacy/payment decision: this plan preserves selected OAuth/API support, runtime-specific consent, unknown-usage continuation, eight conservative reservations and the 120-second client deadline plus cleanup. It does not authorize real credential access, Provider use or external action. A1 interface drift at implementation entry requires parent review rather than guessed adapters.

## Frozen inputs unchanged

Final read-only hashes still match the prior approved policy revision:

```text
a6166c3fb5b9622450a20d614c01dd5ea87dfbdf79ded48656c353e925a5d5c5  goal-flow-plan.md
c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc  goal-foundation-plan.md
f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82  .superpowers/sdd/goal-foundation-plan/task-1-brief.md
5412316a2d651e07d7be9a0cfecc2b88eb158faace7c9ac4ef7032dd2e4f0882  goal-output-policy-plan-review.md
```

Only this report and goal-driver-plan.md were authored for this subtask. The old seam proposal, accepted plans, source, AGENTS, tests and runtime artifacts were not edited. Source inspection, document reads/searches and hashes were performed; no build/test/app/Provider/network/key/signal/new-agent action occurred. Planning used writing-plans and source-first systematic-debugging guidance; no skill-triggered implementation or gate clearance is claimed.
