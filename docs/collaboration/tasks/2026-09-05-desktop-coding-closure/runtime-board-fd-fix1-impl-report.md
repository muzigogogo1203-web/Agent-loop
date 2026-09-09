# Board FD negative-proof Fix 1 implementation

2026-09-06. The approved single-function correction is implemented; source writer ownership is released for parent verification and independent review.

- Source: `Sources/AgentLoopTestSuite/BoardServerTests.swift`, only `boardFDIsolatedLeakStillFailsParent` changed (+7 / -1 against `runtime-board-fd-before/BoardServerTests-fix1.swift`).
- Preimage SHA-256: `3fba9b83e8005573cef51f24e114dc0694b40457d38384fb6204e99e5c8de9c8`.
- Postimage SHA-256: `87b370af82e4ae273e6793ac9d655efcd72c8be5a1f41913430943a85ed86240`.

The negative oracle now requires raw child status exactly `1 << 8` (normal exit 1), not merely nonzero. It requires exactly one `Test run with` summary whose fixed prefix identifies one test, one suite, and failure, and whose fixed suffix identifies one issue; the duration remains variable. That summary must also be the last nonempty child-output line. All previous PID, sole recorded issue, original FD expression/threshold, exact mode/PID measurement, delta, completed iterations, exact completion bytes, and cleanup checks remain unchanged.

The review concern was verified against the actual retained focused output before implementation: `runtime-board-fd-focused.log` records negative raw status 256 and the final `1 test in 1 suite ... 1 issue` line. Existing positive/shared-runner/075 code and queued unrelated work were untouched. No build/test, process signal, agent, or commit was performed.

Static verification: `git diff --check` exited 0, and the full scoped diff contains exactly the status change and six summary-check lines. Runtime verification remains parent-owned: rerun the held-32-FD negative and both positive Board filters, preserve their raw statuses/full summaries/deltas, then obtain independent review. Prior six focused passes are historical evidence and do not substitute for validating this correction; overall runtime/product acceptance remains incomplete.
