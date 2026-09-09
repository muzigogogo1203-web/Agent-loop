# Cold gate cleanup — parent plan review

2026-09-06. Approved plan SHA-256 `31d584d898287d64201e84c414c71dc57510e498043874586ef32d0f8f04fb0c`; responsibilities-separated from its author. Read the complete plan and cold-gate analysis against the inspected harness/backend lifetime. No actionable P0/P1/P2 plan findings.

The source change is test-private and limited to ExecutionEngineConformanceTests.swift. Synchronous launch and a stream unconsumed until the single actual cancellation settles preserve the cold-stream test. The joined detached cleanup owns both actual results even when the caller is cancelled; it neither races away from cleanup nor implies a hard bound. Independent actual SIGCONT identity, cancellation/stream evidence and non-consuming process/socket/registry observations gate checked teardown. Uncertified roots remain intact. Existing signature/pre-registration/main branches and original deadlines remain unchanged.

The retained failing 065 run is accepted as the pre-fix behavioral RED, with the specific limitation that it demonstrates the failed body entering a skipped-cleanup path, not a surviving orphan. Re-running that unmanaged lifetime merely for a fresh RED is not authorized. The new real forced-after-readiness case must verify the repair and preserve the exact primary error.

One source writer, then scoped independent source review, then parent-owned focused verification. Both named tests must actually execute; neither a compile nor a single pass substitutes. No full repetition under unchanged resource pressure, production readiness repair or stage acceptance follows from this approval.
