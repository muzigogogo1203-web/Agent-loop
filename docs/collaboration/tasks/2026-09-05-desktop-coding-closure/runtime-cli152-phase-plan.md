# CLI152 completion-watchdog phase repair

2026-09-09. Source-only entry proposal; independent review before implementation. The known integration RED and earlier numeric trace show the current 200x10ms completion watchdog begins immediately after queuing startup, rather than after observing the parent-exited marker. This plan changes no product timeout and does not attribute CLI346 to the same cause.

## Scope

Only `Sources/AgentLoopTestSuite/CliBackendTests.swift`. Preserve the current dirty codex branch and all existing runtime source changes; capture a fresh preimage at entry. Root alone runs builds/tests, no concurrent source writer. No C fixture, Package, runner, inventory, production backend, App, Provider or user data changes.

## Task 1: Make phase ordering deterministic without another process

- Extract the current CLI152 body verbatim into private async throwing `cliMechanicsWaitForHeldPipeResult(_ frames: CliMechanicsFrameRecorder)`. The actual held-stderr subprocess test invokes this helper. Its later cleanup assessment, joined-stream recheck, socket, signature and exact `[.stdoutLine("parent-exited")]` assertions stay unchanged.
- Add private recorder phase state `.notStarted`, `.waiting`, `.satisfied`; `waitForStdout` moves to waiting before its existing3s deadline and to satisfied only after its exact-marker guard succeeds. `completedResult()` records a sticky audit bit if requested before satisfied. A snapshot returns readyWaitStarted, readyWaitSatisfied, and completedResultRequestedBeforeReadyWaitSatisfied. These test-only state observations do not change existing readiness outcomes or deadlines.
- Add `cliHeldPipeCompletionWatchdogStartsAfterParentMarker`: instantiate the actual recorder, append exactly the parent marker, finish with the exact existing pipeDrainIncomplete error case, and call the actual extracted helper. Assert the exact one-frame snapshot and audit `(true, true, false)`. No child, socket, environment gate, external effect or time delay is required. PRE-RED extraction keeps old ordering, so the helper returns normally but audit is `(false, false, true)`; only that strict audit requirement should fail.
- After exact source review, root builds and runs only this new test, freezes it after meaningful RED, then changes the helper to `try await frames.waitForStdout("parent-exited")` before the unchanged200x10ms completion loop. Keep `.watchdog`, `.heldPipeCleanupReportedCertain`, the exact pipeDrainIncomplete check and final marker check. Existing readiness failure semantics may report their actual stored error/launch timeout; do not peek at audited completion before readiness just to preserve an obsolete wrong-phase diagnostic.
- Root rebuilds and runs the identical no-child test for GREEN. Independent spec/quality/evidence review before real CLI152 inclusion in the later contained integration gate. The seeded unit verifies the test's phase logic only; the preserved real C held-parent/grandchild test remains necessary production mechanics evidence.

## Stop rules

Any deadline/iteration/grace change, weaker failure/frame/signature/resource assertion, real child in the seeded regression, global serialization, or manufacturing terminal success via cancellation is out of scope. Any unexplained test/build failure must be interpreted before retry. The historical integration failure remains RED until new contained real-process verification; this unit alone is not full/App acceptance.
