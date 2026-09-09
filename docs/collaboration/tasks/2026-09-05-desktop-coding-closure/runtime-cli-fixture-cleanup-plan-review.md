# Independent parent review: CLI test ownership cleanup

2026-09-06. Approved for the bounded single-test-file implementation; this is not readiness diagnosis or full-suite acceptance.

The parent read all 269 plan lines, the three current tests, recorder/inspector/harness, backend registration/removal/cancellation and finalizer boundaries, and the independent completed-run analysis. Plan SHA-256: `8dbb8ca9f5e25198ff3c2dc06f572f342381ecbffba451b04aac549fac41a421`.

The real retained orphan evidence establishes the failure-path ownership defect. Synchronous `backend.launch` outside the consumer is necessary: a catch-only cancel while launch remains inside a delayed Task can run before registration and allow a subsequent orphan. The cancellation owner retains its first task/result, and the helper cannot throw between creation and joining its uncancelled consumer. Its returned stream result is actual terminal evidence, not a Boolean proxy. No termination shortcut or retry is introduced.

The completed-stream/registry-removal race is explicitly constrained. An exact same-execution `processNotRegistered` is not cleared until the real joined terminal result and every process/group/non-consuming waitid/socket observation pass. Other stream/cancel errors remain distinct from the primary body failure. Missing continuation identity, PID reuse, failed observations or surviving resources retain the exact fixture; only signal 0 observations are allowed in test-side certification. Production cancel remains the sole termination owner. `waitid` with WNOWAIT must never be replaced by a consuming waitpid probe.

The actual after-ready regression verifies live PID/group first, then throws without asking the body to cancel; the helper must supply real TERM/KILL/reap/EOF evidence, joined exited frame, and absence observations while preserving that deliberate marker. A readiness failure cannot masquerade as the marker. Existing three-second/200-by-10-ms/grace bounds and all original assertions remain intact. This is a test lifecycle repair, not permission to increase any deadline or serialize tests.

One known limitation stays explicit: the underlying cancellation/completion join is not independently hard-bounded by this helper. If it hangs or resource absence is unresolved, stop with that evidence; do not add an unjoined escape, broad process kill, or fixture deletion. The full default gate stays red and is not rerun under unchanged pressure just for this test repair.

Only CliBackendTests.swift and designated task evidence may change. Parent owns builds/tests after source-writer release; another non-implementer must review the complete resulting diff and focused logs. No production, runner, manifest, Provider or real-data action is authorized by this approval.
