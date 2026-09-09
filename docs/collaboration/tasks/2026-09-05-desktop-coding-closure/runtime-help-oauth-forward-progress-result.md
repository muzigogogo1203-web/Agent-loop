# Help probe and OAuth wait — bounded fixes verified, integration still RED

2026-09-09. Branch codex/runtime-forward-progress-20260908; HEAD02334ec8d21533be81d93d39191bc7d9b9c24f7f unchanged. Existing dirty tree preserved. No commit/push/App/real-data/admin/Provider operation.

## Changes and independent review

- CliEngineAdapter.swift: real async help snapshot now offloads its complete synchronous probe operation onto BlockingProcessOperation and awaits its actual Result despite cancellation. All authority validation, live subprocess operation/order/argv, deadlines, parsing, cache and cleanup remain unchanged. Package-only synchronous runner dependency permits an actual-callsite regression without creating descendants.
- BlockingProcessOperationTests.swift: new strict-pool real-pipe regression calls actual snapshot, validates real file stat/hash authority, preserves exact sentinel/one version invocation and requires sibling progress before external release. Original generic regression remains unchanged.
- OpenAIOAuthSessionTests.swift: controlled pending-request wait now suspends its async caller while a dedicated worker performs the unchanged NSCondition wait. All five original matrix expectations/default5sdeadlines remain. Deterministic one-shot observer drives actual registration only at wait entry; inert nil-client URLProtocol, no URLSession/network/descendants. Checks and evidence stay on the original test task.
- AGENTS.md: one factual Codebase Facts line documents the test-only C helper dependency and actual blocking-operation ownership. No product/governance/authority change.

Independent forward_progress_review approved both plans, fixed source findings about success-evidence publication, admitted both actual RED and GREEN records and reviewed minimal placement changes. It explicitly withholds integration/full/App acceptance. Source-stage findings and decisions: runtime-help-oauth-forward-progress-review.md.

## Complete verification record

All commands were root-owned, with full stdout/stderr, actual spawn/wait2/exit, before/after309-input manifests and executable identities. No source drift during any run.

| Evidence label | Result |
|---|---|
|red-build1|swift build --product RunTests; exit0,90.054153s wall|
|red-focused1|two tests,1.158s,exit1; exactly two intended parent failures|
|green-build1|same ordinary build; exit0,48.940120s wall|
|green-focused1|identical two regressions,0.164s,exit0|
|integration-focused1|13tests/1suite,33.196s,exit1;6issues in3parents|

Help RED: canceled=true, invocation1, exactversion/sentinel/authority, read/write1byte199, all close errorsnil, controller/sibling joined, rescue=true; only no-rescue fails. GREEN: same checks, rescue=false, child0.012s. OAuth RED: wait=false after0.25s but eventual exactrequest/count1/noresidue; only progress assertion fails. GREEN: wait=true, same ownership checks, child0.004s. Success evidence was absent on RED and exact on GREEN; both owned children were reaped.

RED source manifesta3737e0778ef1db52f63fff0c09718e15cec40c2d9445ca09fd03b19f2ee6bed; reviewed pre-REDdiff e7f37d321afc869c9fee5b6968b57ef84ddd249e6fb0da4cf5071636ff230060. Final source manifest1c0af54fc6a24abc6f3c2bd501ac9beda9f298e874c2bf46cc5e10ac70570ecc; finaldiff ad8bb3640a3eee1eea0f1bed45614d039526ae5a5405099d50e5cf8e4597d9f1. Final RunTests d2454a3d610d69dcc3c456c676178f0e29341e4cefaee24a09558de923b4e1f0; Cfixture4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2 unchanged.

Raw log hashes: REDdb481fd256bf1dd5ac57198443220dda4acd131ce1fad4ec26fb097f4e04d67b; GREEN815640ff5baea41c462f46ef048da65f88f7581f14f4ee1c34415ce25ac44ec6; integration1ff9b30ad9192a1c29eab130b891dc1a47806ff3b0c85c74779dadccfa856213. Exact source pins/preimages are in runtime-help-probe-entry.json/runtime-oauth-wait-entry.json and the durable runtime-help-oauth-evidence directory/manifest. The OAuth entry's global manifest was captured while the separately authorized help writer was active; its own d6ed9f28... preimage matches the common original entry, and root verified the combined delta is exactly the three authorized paths with306others unchanged.

## Unresolved integration failures and safety boundary

1. CLI152: watchdog expired; subsequent cleanup reported a certain result instead of the expected held-pipe failure. Real resource observations report0failures, but the test contract is not met.
2. CLI346: ready was not observed within the original3sbudget. Cleanup resource observations report0failures; readiness remains unresolved.
3. 065 pre-registration-abort execution ending465: both joined results report processCleanupFailed("spawned process or pipe cleanup failed") instead of injected resume failure. Registry remains nonempty; directory close was consequently not attempted. These are4issues, not4independent roots. The later cold065/865 certificates do not certify abort465 cleanup.

Passing integration checks include347/372, environment paths, original generic bridge, exact A3 boundary, complete OAuth matrix container,075 live probe/integration and cold065forced-error. Two boundary fixes are real, but neither focused GREEN nor those passes clear integration.

Independent source review narrows465 to (a) signal failure with group still live, skipping reap/drain joins, or (b) after joins, group presence still true/throws. Descriptor-close failure alone cannot explain retained registry because unregister occurs earlier. The generic cleanup error discards the underlying stage/cause. Abort signal group/result/errno and random root existed only in memory; default logs do not retain an authoritative abort PID/root. The test's defer attempts root removal even with uncertified cleanup. Do not guess its PID, substitute later97271/97354, or claim fixture-file removal proves process absence.

A root read-only process-command filter for this test's abort-root prefix and known CLI fixture paths returned no matches, but this does not recover historical identity or certify cleanup. No signals or deletions followed. No extra OSLog export, sampling, admin action, new test or full retry occurred after this failure.

All further process workloads, full-suite and strict-App entry are paused. Next work requires a separately reviewed cleanup observability/retention correction preserving primary+cleanup causes, exact PID/group, signal/errno/reap/liveness outcomes and retaining fixture identity until cleanup is certified. This is missing evidence for a safe continuation, not a claim that the two fixes solved the whole runtime or that an external permission is pending.

Final responsibilities-separated review accepts this bounded status/evidence account only. It verified all36/36 help/OAuth and79/79 native durable manifest entries and final source/AGENTS pins; no documentation blocker. Integration and product acceptance remain withheld. Final git diff --check passes; no source change after the recorded integration workload.
