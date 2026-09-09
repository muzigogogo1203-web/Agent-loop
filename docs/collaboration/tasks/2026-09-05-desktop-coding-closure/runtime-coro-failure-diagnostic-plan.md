# 069 failure-localization supplement

2026-09-06. This bounded supplement does not change the accepted decomposition or runtime contract. After independent source approval, ordinary compilation completed in24.78s and both065 tests passed. The next069 invocation failed with an uncaught CancellationError in0.480s before its existing stage markers. Exact PID50925 events prove active-registry work through retry2, but do not identify the throwing join.

## Scope and ownership

One exclusive writer may modify only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`, starting from SHA256 `e5a3ce4fae3ae1c0487ffe3c62b43360f49c7c6ef49ddf1d2d2538397ca2380e`. Root preserves that preimage, owns compiler/test/log commands, and obtains an independent actual-diff review before running. No production changes, new tasks, catches, waits, assertion changes, cancellation changes, timeouts, helper reordering, fixture lifetime changes or source-boundary exemptions.

## Exact diagnostic change

1. At entry to each of the21 existing `private func p1f1d069Exercise...() async throws` helpers, print a fixed literal `P1F1D069_SCENARIO=<helper suffix>` naming that helper. Do not interpolate data or errors.
2. In `p1f1d069ExerciseSharedAdapterCleanup` only, immediately before and after the existing `try await modelConsumer.value` and `try await cliConsumer.value`, print fixed literals `P1F1D069_JOIN=model-begin`, `model-end`, `cli-begin`, `cli-end` with that same prefix. Keep the original joins untouched.
3. Save a scoped preimage diff and report. Removing exactly these25 added print lines must reproduce the preimage bytes. This is a diagnostic-only refactor, not a behavioral fix; no artificial source-text test is needed. The existing failing069 is the behavioral RED.
4. Independent reviewer checks all25 literal-only insertions and byte reconstruction. Root then runs one ordinary incremental compile plus focused069 invocation with complete stdout/stderr, actual exit/PID, current source hashes and resources. Do not repeat an unchanged failure just to seek green. A pass would only be non-reproduction; it would not disprove the source-grounded cancellation race hypothesis.

## Question under investigation

CLI cancellation currently catches a downstream cleanup error but still cancels its outer stream task; model cancellation explicitly avoids this when teardown fails. An outer checkCancellation or canceled stream iteration could replace the CLI's specific teardown error with CancellationError. This remains a hypothesis until the failing join is localized; blindly copying the model condition is not admitted because CLI error paths must still prove producer/outer settlement, including validation failures whose streams may not have completed.

Full runtime and product/package gates remain closed. No commit, external App, real data or paid Provider actions.
