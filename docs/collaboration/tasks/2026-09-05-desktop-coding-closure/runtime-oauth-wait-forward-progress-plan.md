# OAuth controlled-test wait — bounded repair plan, 2026-09-09

## Cause and scope

The controlled URLProtocol fixture's synchronous NSCondition wait is called directly from an async test immediately after enqueueing refresh Tasks. On a constrained cooperative pool it blocks the same execution resource those Tasks need before URLSession can register the request. This wait overlaps the admitted CLI delayed-entry trace, but that does not prove it is the only cause.

Exactly one source path: `Sources/AgentLoopTestSuite/OpenAIOAuthSessionTests.swift`. No production OAuth/credentials/network behavior, CardRunner callback, suite scheduling, global serialization or timeout change. Root captures its current preimage and all309 input identities; separate writer from the two-path help-probe unit. No workloads while either writer owns source.

## Actual-callsite RED then GREEN

Make only the existing `OAuthControlledProtocol.waitUntilPending` facade async initially, retaining its INLINE synchronous state wait, and update its five matrix calls to await on the original test task. Add an independently addressable regression invoked in the existing exact-owned strict-cooperative-pool RunTests child. No URLSession/network/Provider or subprocess descendants are created inside that child.

Use a unique https://auth.test request and a one-shot onWillWait observer keyed to that request. Remove the observer before invoking it immediately before condition.wait while the pending-state lock is held. The observer only queues registration and retains its Task in a separate holder: no controlled-state re-entry, await, or assertions. Construct the inert URLProtocol inside that Task with nil client and invoke its real startLoading registration, avoiding a non-Sendable URLProtocol capture. Invoke the actual facade with a short explicit regression-only timeout. Old inline behavior must time out before the newly queued registration progresses on the sole worker. GREEN registration can take the lock after condition.wait releases it. Join registration and synchronously remove/verify the exact pending request before all assertions and before reporting RED. Require exactly one start, no pending/observer residue, and a true wait result. Use exact controlled child environment/label/evidence parsing and checked selfexec cleanup, with no recursion/fallback to a live request. Do not change the existing facade default five-second deadline or matrix predicates.

Independent forward_progress_review approves entry with the one-shot coordination above and in-task URLProtocol construction. If registration can happen before wait entry, the regression is not admitted; strengthen phase coordination rather than repeat unchanged runs. Actual RED must be the failed progress result after complete cleanup, not a compile/type error or missing fixture.

For GREEN, the facade awaits `BlockingProcessOperation.start { state.waitUntilPending(key, timeout: timeout) }.value`; inner NSCondition algorithm and deadlines remain byte-identical. Cancellation does not abandon the owned wait. Keep #expect and evidence writing on the original Swift Testing task. Rerun identical regression assertions and the original complete OAuth container test. Root alone builds/tests and saves full outputs/hashes.

## Integration and limits

This can share a compile/focused batch with the separately reviewed help-probe repair only after both source writers release their disjoint paths. Each unit needs its own discriminating RED/GREEN; one combined ordinary full gate may then assess their integrated causal delta after independent approval. Do not attribute success/failure exclusively to either unit without evidence.

No new file-inventory successor is required; preserve all existing frozen source manifests and count boundaries. No App/admin/capture/real-camp/secrets/payment/Provider/commit/push/release action. Remaining failures block acceptance, not permission for unchanged retries.
