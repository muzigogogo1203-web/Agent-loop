# Board FD negative-proof Fix 1

Parent checked the complete independent review and the actual captured negative output. The concern is valid: `status != 0` plus an earlier assertion/evidence does not exclude a later signal/crash. Current actual child PID 26564 terminated with raw status 256 and its final output has exactly one failed test / one suite / one issue. The six planned focused commands all exited 0 (`runtime-board-fd-focused.log`), but those passes do not resolve the source-level false-positive gap.

Approved single-file correction: BoardServerTests.swift, inside only `boardFDIsolatedLeakStillFailsParent`.

1. Strengthen its raw-status requirement to exactly `1 << 8`, the normal exit(1) observed from this runner. Do not accept other nonzero/signal statuses as the intended negative.
2. After reading complete child output, require exactly one final `Test run with` summary; it must identify one test, one suite, failure, and one issue. Allow the actual duration field to vary. Retain all existing sole-issue, original FD expression, actual PID/delta, iteration, completion and cleanup checks.
3. No production, positive-body, generic runner, deadline, or other source change. This is tightening the already running negative test oracle, not replacing behavior with a mock or changing the positive acceptance assertion.
4. Parent reruns the real held-32-FD negative and both positive Board child tests, retaining complete raw status/output and exact measured deltas. Independent reviewer checks the precise fix and the actual terminal output. Prior 075/A3 evidence remains unchanged because this fix touches neither their code nor shared mechanics.

Preimage is runtime-board-fd-before/BoardServerTests-fix1.swift; old released SHA 3fba9b83e8005573cef51f24e114dc0694b40457d38384fb6204e99e5c8de9c8. Current source writer is released and no Swift run remains. Overall runtime/product acceptance stays incomplete.
