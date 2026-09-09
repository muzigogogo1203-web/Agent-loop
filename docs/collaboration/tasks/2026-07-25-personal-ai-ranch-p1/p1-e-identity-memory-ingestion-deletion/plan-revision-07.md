# P1-E Plan Revision 07 — deterministic time and process-local Board proof

> Date: 2026-08-27  
> Scope: one bounded compatibility correction after the first complete
> Revision-06 default-parallel full gate  
> Authority: accepted P1-E base plan; Revisions 01–06 and their approved
> reviews; canonical P1 plan/stage authority; the user's instruction to
> continue independently without Claude  
> Frozen history: every earlier plan, review, red log, and completed gate
> remains byte-immutable

## 1. Trigger and preserved evidence

Revision 06 was independently approved before writes and its intended roots
are closed. The following gates are already valid:

```text
Review01f=APPROVED — 0 P0 / 0 P1
review01f_sha256=952228e9c714f33016bef7ec3f0e4f01a8bcaecd869435366a61a01344e225e5
revision06_narrow_sha256=6191e7a92b901eb0e3e6dc27e6a11da8e68bb64e303b7de3d4c9a0cf8d9821e1
focused_90_sha256=5c20c836cedcdbd0c0703505b3e0ff9f5d5b69b2db6ea70812bdbc3faa380649
source_gates_sha256=0b246595e599f32884fb822be839bf9d8cdafa126419dd9dccf849c829a8135f
build_sha256=ccdbf3fa5d4f12a953efdcf7ee1c739cf4da4450861223c6903e304a3195f8ab
migration_matrix_sha256=060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d
preview_sha256=2f7ecdc7c26f938fdd6179eff9fbd368d9a588c459a65ecce8d530fad760e042
```

The first exact, unfiltered, default-parallel `swift run RunTests` after those
gates was preserved without a chance rerun:

```text
verify-revision-07-red.log
sha256=8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d
tests=992
suites=24
issues=4
elapsed=60.079s
command_code=1
tee_code=0
```

The four issues were:

1. cancellation-ignoring shutdown returned the correct report after
   1.784 seconds, violating a test-only `< 1s` wall-clock assertion;
2. the 400ms real cooldown elapsed before the loaded test resumed and checked
   that the second card had no run;
3. Board framing timed out after 5.564 seconds before the shared utility
   handler completed its work;
4. the failed-connect regression observed a `+2` change in the process-global
   `/dev/fd` count.

The read-only diagnosis is frozen as `diagnostic-revision-07.log`, SHA-256
`162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b`.
No Revision-07 source or test write may precede approval of this plan.

## 2. Proven root-cause matrix

### 2.1 Shared scheduler versus causal shutdown contract

The exact default-parallel run reached 657 simultaneously active tests on a
10-logical-CPU machine. The shutdown test began with 491 active tests. The
same test is green in five isolated runs, five paired runs, and the serial
full run, taking about 0.10–0.15 seconds. Historical default-parallel runs
show the same 1.49–1.83 second wall-time failure.

`DurableWorkSupervisor` already injects its deadline sleep. The correct
contract is causal: shutdown must not report before that deadline completes,
and must report the exact still-uncooperative work after it completes. A
wall-clock upper bound on a saturated cooperative executor is not that
contract. The cancellation-ignoring provider double must remain synchronous
and genuinely uncooperative until the test releases it.

### 2.2 Real time consumed before cooldown observation

The cooldown failure reproduced at the same assertion in three large
default-parallel P1-E runs, while five isolated, five paired, and the serial
full executions were green. Production has exactly two time reads: one sets
`cooldownUntil`; one compares it during reconcile. Because both hard-code
`ContinuousClock.now`, the test cannot hold time fixed while it awaits the
complete 429 error path. A run for the second card proves that real time had
already reached the deadline before the observation; it does not prove a
cooldown product-state defect.

### 2.3 Process-global descriptors versus client ownership

Revision 06 closed the proven failed-initializer leak. Twenty failed
connections are green in ten isolated processes. The existing regression
still samples all descriptors in the test process. It observed `+2` during
the full run while 21 unrelated tests were active, and `-2` when only the
first four serialized Board tests ran. A process-global count that moves in
both directions cannot establish ownership for one private client.

The corrected proof must observe each descriptor opened by this client and
the result of its real `Darwin.close` synchronously on the failed initializer
path. Unrelated live descriptors must neither make it red nor make it green.

### 2.4 Shared utility handler versus protocol behavior

The framing test is green in ten isolated runs and three 112-test runs
(1.746–2.979 seconds). Three large default-parallel gates timed out near the
unchanged five-second receive deadline. At framing start the authoritative
red had 183 unrelated active tests. Sampling found the client blocked in the
hello/read path for 557 of 586 samples; the later tool-call bridge accounted
for only 27 samples. The test passes a shared global utility queue even though
`BoardToolServer` already exposes a handler-queue injection seam.

The evidence authorizes isolating this functional test on a dedicated ready
serial queue. It does not authorize a product async/semaphore rewrite,
timeout increase, EOF reclassification, or global test serialization.

## 3. Exact effective scope and frozen pre-images

Revision 07 admits one previously dirty test file and six new task artifacts:

```text
Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-07.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/verify-revision-07-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/diagnostic-revision-07.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-07-tdd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/revision-07-narrow-gates.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01g-p1-e-compatibility-plan-review.md
```

The executable boundary is exact:

```text
allowlist_lines=128
allowlist_nonempty_unique=128
allowlist_sha256=2929ab1de17cb24574790842b0661354707ef36373482a2ea6a855baf005c067
outside_count=495
outside_manifest_v1=917cf6611f701b4c0186fa5359b6432076a1f5a658ddbd8d5aed2d61c857da1e
```

The only implementation-sensitive pre-images are:

| File | SHA-256 |
|---|---|
| `Orchestrator.swift` | `4dcfa183d6a7e85d31651d7dded45a5adb624a4cda01677c010c7727efc1e087` |
| `HaltAndCooldownTests.swift` | `339d8ddf8c1bc0514590a813f3ebab671885c5b5ed2b6dfe231b3e5810a13b6a` |
| `DurablePlanningTests.swift` | `c05d633ff65e7f7edf25c35bbbf8ab2a18bd23c35887e7eba6c070011f8c07d5` |
| `BoardServerTests.swift` | `ea974b23b544fd353772935440f38f07916f406befccc0bfe245d3b30c6e1dda` |

Protected bytes are:

| File | SHA-256 |
|---|---|
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `BoardToolServer.swift` | `ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Package.swift` | `0a4b9d3c4eba1a06bda535e69c54c3a5186dcaf148bcb489f1667b4c069cba48` |

Before this plan was created, live counters were `dirty_total=614` and
`allowlisted_present_count=119`; the plan and Review01g may advance only the
allowlisted count. The outside count/hash must remain exact.

## 4. Decision-complete implementation map

### 4.1 Causal cancellation-ignoring shutdown proof

Only `DurablePlanningTests.swift` changes for this root.

1. Add a test-local actor-controlled deadline probe. Its injected `sleep`
   records the requested `Duration`, wakes observers, then remains suspended
   until explicitly released.
2. Start `supervisor.shutdown(gracePeriod: .milliseconds(25))` in a task and
   store its completion in a separate test-local probe.
3. Wait causally until the deadline probe has been invoked and require the
   requested duration to equal exactly 25ms.
4. Before releasing the deadline, require that shutdown has not completed and
   that the provider remains unreleased and cancellation-ignoring.
5. Release the deadline, await shutdown, and preserve the exact assertion
   `uncooperativeWorkIds == [ids.workId]`.
6. Release the provider only after the report assertion so cleanup can finish.
7. Delete only the scheduler-dependent `elapsed < .seconds(1)` measurement.

No real sleep, timeout race, retry, yield loop, weakened provider double, or
`DurableWorkSupervisor` change is allowed.

### 4.2 Package-only monotonic cooldown clock

`Orchestrator.swift` gains one stored dependency:

```swift
@Sendable () -> ContinuousClock.Instant
```

The public initializer must not expose a new parameter. It delegates with the
live closure `{ ContinuousClock.now }`. Both package designated initializer
paths accept a defaulted `rateLimitNow` closure and initialize the stored
dependency, so existing callers remain source-compatible. Exactly the two
cooldown time reads change:

- setting the deadline uses `rateLimitNow() + rateLimitCooldownDuration`;
- reconcile compares `rateLimitNow() < cooldownUntil`.

`HaltAndCooldownTests.swift` adds a lock-protected manual
`ContinuousClock.Instant`. The existing test selects the package initializer,
passes that clock, preserves the exact one-event assertion, creates the second
card, and reconciles without advancing time. It requires zero runs. It then
advances exactly 400ms, reconciles, and requires the second card to finish.
The test's real 100ms and 400ms sleeps are removed. The configured 400ms
product duration is unchanged.

### 4.3 Per-client failed-initializer ownership proof

The existing failed-connect test keeps its unique missing UNIX path and twenty
construction attempts. During the tests-first red phase it opens an unrelated
pipe after the current process-global baseline and leaves both pipe ends open
through the assertion. The old `/dev/fd == 0` assertion must fail by exactly
`+2` in the isolated filtered run, proving the observation defect.

The green implementation remains private to `BoardServerTests.swift`:

1. Add an optional lifecycle observer to `BoardSocketTestClient`; live/default
   clients pass no observer.
2. Emit an `opened(fd)` event immediately after this client successfully calls
   `socket()`.
3. Every client-owned close still calls the real `Darwin.close`. Only after
   that call, synchronously emit a `closed(fd, closeResult)` event. A zero
   syscall result is the ownership proof; no later process-global FD sample or
   reuse-sensitive `fcntl` probe is permitted.
4. Failed connect, `SO_NOSIGPIPE` failure, explicit close, and deinit continue
   to use the same exactly-once ownership paths established in Revision 06.
5. The regression records the event sequence under a lock, requires twenty
   ordered open/close pairs, identical descriptor identity within every pair,
   close result zero for every pair.
6. It separately proves the unrelated pipe ends remain valid until their
   defer closes them. It does not assert any process-global descriptor delta.

Existing lifecycle tests keep twenty iterations and `< 10`; connection retry,
socket timeout, and protocol assertions remain unchanged.

### 4.4 Dedicated ready handler for the framing functional test

Only `boardServerFramingForwardsToolCallsWhenSocketsAreAllowed` changes. It
creates a uniquely labelled serial `DispatchQueue` at `.userInitiated` QoS,
executes a synchronous ready barrier on that queue, and passes it through the
existing `makeBoardHarness(handlerQueue:)` seam before starting the server.

The test continues to use a real UNIX socket and the unchanged five-second
receive timeout. Hello, progress, search, complete, persisted card status, and
terminal snapshot assertions remain identical. The separate timeout test
continues to suspend its own queue and require `receiveTimedOut`; timeout must
never become EOF or success.

`BoardToolServer.swift` and the default production queue remain byte-identical.

### 4.5 Historical and scope sentinels

Only these expectations change in `DurablePlanningTests.swift`:

```text
allowlist_lines=128
allowlist_sha256=2929ab1de17cb24574790842b0661354707ef36373482a2ea6a855baf005c067
A4 raw P1-E intersection=39
A4 unaffected entries=127
A3 raw P1-E intersection=41
A3 live/enumerated entries=123
```

`HaltAndCooldownTests.swift` is added to
`a3P1EHistoricalSuccessorExclusions`. Direct lookup proves it is present in
both frozen 206-entry manifests; those manifests remain byte-immutable. All
other predecessor/successor sets and counts remain unchanged.

The source/scope gate must also require the exact 128-line allowlist and the
495-entry outside manifest above. It must preserve Package, runner, protected
source, v16 migration literal, raw SQLite owner, and P1-E 90-test identity
checks from the current green source gate.

## 5. Ordered tests-first execution

1. Freeze this plan, the 128-line allowlist, red full log, diagnosis, all
   pre-images, and an independent Review01g with
   `APPROVED — 0 P0 / 0 P1` before another source/test write.
2. FD measurement red: change only the failed-connect test to hold the two
   unrelated pipe descriptors across the existing global-count assertion.
   Run only that test and append full stdout/stderr plus Bash pipeline statuses
   to `red-revision-07-tdd.log`. Require an exact `+2` behavior red.
3. Cooldown seam red: change the cooldown test to pass the planned package-only
   `rateLimitNow` argument, without changing `Orchestrator.swift`. Run only
   that test and append the compiler failure and pipeline statuses. The error
   must be the missing planned initializer argument/seam, not an unrelated
   failure.
4. Apply exactly §§4.1–4.5. No product file other than `Orchestrator.swift`
   may change.
5. Run the following with complete output and one snapshot of every pipeline
   status in `revision-07-narrow-gates.log`:
   - shutdown and cooldown, five separate executions;
   - framing, timeout-vs-EOF, failed-connect ownership, and wrong-token,
     five separate executions;
   - complete `BoardServerTests`, three separate executions;
   - the six resource-sensitive Revision-07 tests plus
     `shellRegistryTerminateAllKillsRunning` and
     `loginShellEnvironmentCapturesPath`, three separate executions;
   - the exact Revision-06 112-test successor gate;
   - the exact P1-E 90-test gate.
6. Run the exact source/scope gate with the new frozen values. Update
   `source-gates.log` only after every section is green.
7. Run `swift build --product AgentLoopApp` and replace `build.log` only with
   full command/tee-zero evidence.
8. Migration source, runner, Package.resolved, v16 literal, and both SQLite
   versions are protected and unchanged. Revalidate their hashes and retain
   the current dual-version matrix SHA
   `060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d`;
   rerun the matrix only if any protected input differs.
9. Because `Orchestrator.swift` changes packaged Core bytes, append a fresh
   isolated `scripts/run-app.sh --preview` revalidation to `preview.log`.
   Require exact executable identity, isolated state, bundle/resources,
   codesign verification, SQLite integrity/FK, v16/v15/v14 migration tail,
   exact PID termination, and command/tee zero. Preserve all earlier preview
   evidence byte-for-byte as the prefix.
10. Finish with one exact, unfiltered, default-parallel
    `swift run RunTests`. Replace `verify.log` with complete stdout/stderr,
    snapshot Bash `PIPESTATUS` once, and require command/tee zero. A different
    failure is preserved and may authorize only another bounded root revision;
    the full gate is never rerun until green by chance.

## 6. Completion gate and red lines

Revision 07 and P1-E compatibility closure are complete only when:

- Review01g approves this exact plan and allowlist before writes;
- the controlled FD measurement and missing-clock compile red are preserved;
- shutdown proves the exact injected 25ms deadline causally, without a real
  wall-clock SLA or early provider release;
- cooldown proves zero dispatch at frozen time and recovery at exactly 400ms;
- every failed client-owned descriptor has one successful real close, while
  unrelated descriptors cannot affect the result;
- framing retains all real protocol assertions and the unchanged five-second
  timeout on a dedicated ready handler queue;
- every named narrow, successor, P1-E, source, build, migration-hash, preview,
  and exact default-parallel full gate passes;
- outside remains exactly 495 /
  `917cf6611f701b4c0186fa5359b6432076a1f5a658ddbd8d5aed2d61c857da1e`;
- `DurableWorkSupervisor.swift`, `BoardToolServer.swift`, runner,
  Package/lockfile, product durations, protocol semantics, Board retry, and
  lifecycle thresholds remain frozen;
- no parallel=false/`--no-parallel`, broad serialization, timeout increase,
  sleep/yield/retry paper-over, fallback, swallowed error, assertion dilution,
  P1-F behavior, normal user-state mutation, or prohibited external action
  occurs.

P1-E remains unaccepted and P1-F1 remains closed until all conditions pass,
an independent implementation Review02 reports zero P0/P1, and acceptance is
written from the resulting evidence.
