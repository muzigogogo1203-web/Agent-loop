# P1-D Plan Revision 02 — CLI cancellation terminalization race

Status: FROZEN FOR IMPLEMENTATION  
Authority: accepted P1-D `plan.md`, `plan-revision-01.md`, and the failed authoritative `verify.log`  
Original plan SHA-256: `3b34e4f699a568d2be5cf345dfa260615d29c5708fd21b29772c723858598acf`  
Revision 01 SHA-256: `e644c521d4c8898d49b0fa163c68afff9dfb3e3026e7a816ea7c847b4bf2c945`

## 1. Trigger and proven failure

The final unfiltered `swift run RunTests` gate discovered one pre-existing
regression with two assertions:

- `cliProcessBackendCancellationReturnsCardToReady`: card remained `running`;
- the same test: run outcome remained `nil` instead of `canceled`.

The test passed in the prior isolated control and failed only in the concurrent
900-test run. The implementation starts the run synchronously, but
`AsyncThrowingStream.onTermination` only cancels the producer task. Database
terminalization is deferred to that producer's later `CancellationError` catch.
Under scheduler or login-environment contention, the consumer has already
finished while the producer has not yet committed the cancel outcome. This is
the known prohibited class “cancellation leaving cards stuck in `running`”.

## 2. Exact product allowlist

- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`

No test source is changed. The failed authoritative suite is the saved red
test. Existing P1-D task artifacts may be appended or regenerated as required
by the completion gates.

## 3. Decision-complete implementation

1. Add a private lock-backed, per-run finalizer in
   `CliProcessBackend.swift`. Every completed, blocked, canceled, and failed run
   path must acquire the same finalizer and may commit at most one terminal
   result.
2. Move CLI metrics to an equivalent private lock-backed snapshot so the
   synchronous stream-termination callback can preserve the current metrics;
   do not change saturation, stderr-tail, timeout, or exit-status semantics.
3. On `.cancelled` stream termination, synchronously:
   - remember/issue process termination;
   - finalize the run as `canceled` with the current metrics;
   - return the card from `running` to `ready` through the existing
     `card_interrupted` transition.
4. Cancel the producer task after the synchronous terminalization attempt. Its
   cancellation catch must use the same finalizer and therefore become an
   idempotent no-op if stream termination already won.
5. Normal completion, blocking, and failure paths must also use the finalizer.
   They yield a terminal stream event only when their own finalization wins.
6. Do not change CLI commands, permissions, tool visibility, sockets, process
   signals, timeout values, database schema, or any P1-D product contract.

## 4. Red evidence

`verify.log` ending at `2026-08-26T07:39:17Z` is the authoritative red:

- 900 tests / 15 suites;
- one failing test / two assertion issues;
- command status 1, tee status 0.

No new or weakened assertion is permitted.

## 5. Completion gates

Run with `set -o pipefail` and preserve full stdout/stderr:

1. the exact failing test at least ten sequential times;
2. the prior three isolated concurrency controls from Revision 01;
3. the P1-D exact 80-test focused gate;
4. dual SQLite 3.51/3.52 migration matrix;
5. revised source/scope gate and `git diff --check`;
6. `swift build --product AgentLoopApp`;
7. authoritative unfiltered `swift run RunTests`, exactly 900 tests / 15 suites;
8. implementation review with 0 P0/P1 before acceptance.

The already completed isolated UI preview remains valid because this revision
does not touch UI, app composition, persistence schema, or acceptance flow.

## 6. Red lines

- no timing inflation, sleeps, retries, test serialization, assertion changes,
  swallowed errors, or fallback outcome;
- no terminal overwrite and no duplicate run spend accounting;
- no product file outside the exact allowlist;
- no commit, push, merge, release, or real-user action.
