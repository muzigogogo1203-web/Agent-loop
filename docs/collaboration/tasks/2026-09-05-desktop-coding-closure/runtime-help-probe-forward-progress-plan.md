# CLI help probe forward progress — bounded repair plan, 2026-09-09

## Evidence and contract

The admitted boundary1 trace proves that three CLI backend tasks entered after their readiness budgets expired, but does not identify the worker occupying the executor. Independent source investigation has identified a separate concrete violation: `CliHelpProbeV1.snapshot` is async yet performs its complete version/help sequence synchronously, including poll, process termination sleeps and waitpid. Its cache's Task.detached still executes that synchronous body on the cooperative pool. Repair this specific boundary; do not claim it is the sole cause of boundary1 or adjust any readiness/cancellation budget.

The public/package async snapshot contract, canonical/staged authority validation, subprocess argv/environment, suspended-image validation, signal/descriptor/group ownership, checked cleanup, cache single-flight behavior, result contents and errors remain unchanged. Cancellation of the awaiting task must not abandon the actual synchronous work or cleanup.

## Exact scope and ownership

Two source files only: `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift` and `Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift`. No C/Package/runner/CLI backend/DB/test-placement change. Existing historical206/102 source accounting is untouched; these paths already have their exact prior successor registrations. Root captures fresh preimages and all309 input hashes before any edits. Same preserved dirty codex branch, no commits/worktree/reset. One writer implements; root alone builds/runs; responsibilities-separated reviewer approves entry and source/evidence.

## Regression before implementation

Exercise the actual async help-probe snapshot entry in a strict cooperative-pool owned test child. Reuse the existing real pipe/controller/sibling-progress pattern rather than repeating only the generic bridge test. A narrow package-only synchronous probe-run dependency may replace the actual run operation for this test, after the original snapshot authority checks and before any subprocess creation. Production construction must retain exactly the current live operation. The injected operation blocks on the real pipe, records its invocation and argv, then throws an exact sentinel; no probe child is spawned. A regular owned fixture file provides real stat/hash authority validation but is never executed. This avoids introducing separate-group descendants into the existing self-exec containment helper.

The external controller waits for operation entry, queues an async sibling, and releases the pipe after sibling progress or a recorded bounded rescue. Every FD, controller and retained task is joined before asserting; cancellation of the caller is tested without abandonment. Require exact sentinel propagation, one version-probe invocation, authority/argv identity, correct byte/FD results, sibling progress before release and no rescue. Preserve the original generic bridge test's behavior/assertions; shared helper extraction is allowed only with unchanged original semantics. Child absence of the injected dependency must fail clearly, never fall through to launching a real process.

Run the new focused regression against old inline snapshot behavior first; expected RED is the no-rescue/forward-progress assertion, not compilation or arbitrary process failure. Preserve full log, source/test hashes and exit. Unknown failure or unsafe cleanup blocks further execution.

## Implementation and gates

Extract the original synchronous snapshot body without semantic changes. The actual async entry uses `BlockingProcessOperation.start` with a Sendable Result, retains/awaits its task and rethrows the same error. No Task.detached-only substitute, priority tweak, deadline increase, swallowing, timeout race or cancellation early return.

After independent delta review, rerun the identical regression bytes to demonstrate GREEN at the repaired actual boundary. Then run existing generic bridge, help/capability075, relevant CLI focused lifecycle group and exact source-boundary gate. Required complete outputs and source/binary identities are retained. Only after focused GREEN and independent evidence/full-entry review may root run one ordinary `swift run RunTests` for the causal delta. Any remaining RED blocks acceptance and requires an identified next cause, not an unchanged retry. Strict App build and product acceptance remain separate later gates.

No administrator tool, stack capture, extra logging workload, App installation/launch, real-camp operation, paid Provider, secrets, commit, push or release is authorized by this plan.
