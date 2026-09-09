# P1-E Plan Revision 06 — Board test-client ownership and deterministic concurrency proof

> Date: 2026-08-26  
> Scope: bounded correction after the first Revision-05 Board descriptor gate  
> Authority: accepted P1-E base plan; Revisions 01–05; Review01e; canonical
> P1 plan/stage authority; the user instruction to continue independently
> without Claude  
> Frozen history: all earlier plans, reviews, red logs, and evidence remain
> byte-immutable

## 1. Trigger and preserved evidence

Revision 05 was approved before writes and has a valid tests-first compile-red:

```text
Review01e=APPROVED — 0 P0 / 0 P1
review01e_sha256=714fd5c333ca098b64828fcc531a9b9fe3b79b7dedb38b85ce52e1491324cbdf
red_revision_05_tdd_sha256=90acaa76cc389d2fc62b16e7c1c9f9bbf266af804c1bd13f4cfe2e681ec5b426
red_revision_05_tdd_command_code=1
red_revision_05_tdd_tee_code=0
```

After the three Revision-05 roots were implemented, the combined canonical
gate passed 7/7 and the login-environment/shell-registry gate passed 2/2 in
each of three executions. The first combined Board gate then preserved a new
bounded red rather than retrying until green:

```text
red-revision-06-board-fd.log
sha256=9960c733280e44f6278adf28f3d889d3b92757ea6c6aeed50add81c037e5a7de
protocol_and_timeout_tests=3 passed
descriptor_iteration_1=failed, net_fd_delta=15
command_code=1
tee_code=0
```

The complete LLDB breakpoint/lsof diagnostic is frozen as:

```text
diagnostic-revision-06-board-fd.log
sha256=2b64b5cecc7656a5746c644d6120c199724e79c69ae5714cce927f32d4eb0711
```

No later Revision-05 gate can be acceptance evidence until this deterministic
failure is corrected. P1-E remains unaccepted and P1-F1 remains closed.

## 2. Proven root cause

Two independent read-only diagnostics reached the same descriptor accounting:

- the descriptor baseline had only standard descriptors;
- `connectClientWithRetry` caught exactly ten `ECONNREFUSED` failures in the
  measured run;
- immediately before the final assertion, lsof showed ten persistent
  unconnected UNIX sockets plus four descriptors belonging only to the last
  live test database;
- the ten unconnected sockets matched the ten caught connect failures exactly;
- the nineteen earlier database pools and all earlier servers had released;
  there was no cumulative GRDB or `BoardToolServer` leak.

`BoardSocketTestClient.init` opens a socket, configures `SO_NOSIGPIPE`, and
then calls throwing `connect`. If `connect` fails, initialization aborts before
an instance exists, so neither the current manual `close()` calls nor a future
instance deinitializer can own that descriptor. Each bounded retry therefore
leaks one `unix ->(none)` descriptor.

Revision 05's pre-baseline successful warm-up did not exercise this error path
and cannot fix it. Revision 06 supersedes only Revision 05 §4.3.3: the warm-up
call/helper must be removed and replaced by error-path ownership. The frozen
Revision-05 plan and review are not edited.

## 3. Independent static-review corrections

The post-write static audit found two additional P1 test-proof defects:

1. the 20-caller login-environment test proves one capture and one PATH value,
   but does not compare the complete merged dictionaries and uses a fixed
   number of `Task.yield()` calls as its concurrency window;
2. the Board timeout test suspends a dispatch queue before two throwing setup
   calls, but installs its `resume()` defer only after both succeed. A setup
   throw can release a suspended queue and terminate the test process.

These findings require only test-proof/harness corrections. Static review
found the production canonical seam, exact `Int64` planning payload,
single-flight lock/cache/cancellation implementation, shell-registry cleanup,
timeout-vs-EOF mapping, and historical intersections otherwise conformant.

## 4. Exact effective scope and pre-images

No new source or test path is admitted. The six new paths are task artifacts:

```text
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-06.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-06-board-fd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/diagnostic-revision-06-board-fd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-06-tdd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/revision-06-narrow-gates.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01f-p1-e-compatibility-plan-review.md
```

The executable allowlist is exact:

```text
allowlist_lines=121
allowlist_nonempty_unique=121
allowlist_sha256=390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46
outside_count=496
outside_manifest_v1=5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95
```

The only implementation-sensitive Revision-06 pre-images are:

| File | SHA-256 |
|---|---|
| `BoardServerTests.swift` | `86cd0314663e2ebb276d985472c3cc38372cd527e5eb1530b03927a4d4fc7997` |
| `ShellToolTests.swift` | `281929993fb000b60b0f03a0daa6c9dbb49654677b773194ebd4d20351e725a2` |
| `DurablePlanningTests.swift` | `17ec410555a1523dd649d3c12c8393a6f259b9d9a38d303602d879c8d97e8555` |

The relevant protected or already-correct Revision-05 bytes are:

| File | SHA-256 |
|---|---|
| `BoardToolServer.swift` | `ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea` |
| `LegacyEventScopeResolver.swift` | `12c676e70009738f532f1613bc1f8d10e5172b101e2aee7444c246d2a7fe0b60` |
| `ShellProcessRegistry.swift` | `753469a932406c56a0dd696f046acb0c5b6179f56cb0a5a194a737c3efc64154` |
| `OrchestratorTests.swift` | `5c4d0fe1f6ac9e4f4b2e1f329ce25d3ed8b1f47bd32b79aabe74b81d541a7bed` |
| `PlanningTokensTests.swift` | `65a433f62a1a23905aa4ce92309be89cc3b70fd6241c8e8ec7ba4781219cddbe` |
| `LegacyScopeMigrationTests.swift` | `c6a7ed4d03b6d3217df61c49ad84708413e15d56b279b6e3cd26fff7e639cd59` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |

Immediately before creating this plan, after admitting and copying only the
allowlisted raw evidence, live counters were `dirty_total=608` and
`allowlisted_present_count=112`. This plan may advance both by one; Review01f
may advance both by one. The outside count/hash must not change.

## 5. Decision-complete implementation map

### 5.1 Test-client descriptor ownership

1. Add `boardSocketClientClosesDescriptorWhenConnectFails` in
   `BoardServerTests.swift`. It uses a unique nonexistent UNIX socket path,
   attempts construction twenty times, requires the expected typed setup
   error each time, and requires exact zero net descriptor growth.
2. Change the private `BoardSocketTestClient` to own an `Int32` initialized to
   `-1`. Its initializer must hold the newly opened socket in a local variable
   until every throwing setup step has succeeded.
3. Every failure after `socket()` succeeds must close the local descriptor
   exactly once before rethrowing. The existing `SO_NOSIGPIPE` failure path
   remains fail-fast and must also close.
4. Assign the stored descriptor only after successful connect/setup. Make
   `close()` idempotent by swapping the stored descriptor to `-1` before
   calling `Darwin.close`, and call `close()` from `deinit`. Existing explicit
   close calls remain valid and harmless.
5. Do not change `connectClientWithRetry`, its bounded deadline, any socket
   timeout, any protocol assertion, the twenty descriptor iterations, or the
   `< 10` threshold.
6. Remove `warmBoardHarnessLifecycle` and its descriptor-test call. It was an
   evidence-disproved hypothesis and is not part of the root fix.

### 5.2 Suspended-queue error safety

Immediately after `queue.suspend()` in
`boardSocketClientDistinguishesTimeoutFromEOF`, install a defer that resumes
that queue exactly once. No throwing operation may occur between suspend and
defer installation. Client/server cleanup remains explicit or deferred, but
must not add a second resume. The test must still block the handler until the
unchanged five-second receive timeout throws `receiveTimedOut`.

### 5.3 Deterministic single-flight proof

1. Replace the fixed 100-yield window in `loginShellEnvironmentCapturesPath`
   with test-local async start-barrier and capture-release latch actors.
2. All twenty caller tasks must reach the start barrier before any caller is
   released to `environment()`. The injected capture waits on the latch, so
   concurrent first callers overlap while the first capture remains pending.
3. Release the capture only after the barrier is open and the first capture
   has been observed. The test must complete all tasks without timeout-based
   success or swallowed error.
4. Require exactly one capture, twenty results, the injected PATH override,
   and equality of every complete merged dictionary to the first result.
5. Do not change `LoginShellEnvironment` production bytes in Revision 06.

### 5.4 Historical sentinel

Only the executable allowlist assertions in `DurablePlanningTests.swift`
change:

```text
allowlist_lines=121
allowlist_sha256=390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46
A4 raw P1-E intersection=38
A4 unaffected entries=128
A3 raw P1-E intersection=40
A3 live/enumerated entries=124
```

The ten successor exclusions remain byte-identical. No frozen predecessor
manifest or production source is modified.

## 6. Ordered TDD and verification

1. Freeze this exact plan, allowlist, evidence, pre-images, and independent
   Review01f with `APPROVED — 0 P0 / 0 P1` before another source/test write.
2. Tests first: add the failed-connect FD regression and tighten the
   single-flight proof. Run only those tests and save complete stdout/stderr
   plus Bash pipeline statuses to `red-revision-06-tdd.log`. The FD regression
   must fail under the pre-image; no implementation change may precede it.
3. Apply the test-client ownership fix, queue-resume safety, warm-up removal,
   and exact sentinel update.
4. Save the following zero-issue commands, including every command/pipeline
   status, to `revision-06-narrow-gates.log`:
   - failed-connect FD regression;
   - timeout-vs-EOF plus the two original Board protocol reds;
   - descriptor lifecycle three separate executions;
   - complete `BoardServerTests` suite;
   - login-environment and shell-registry tests three separate executions;
   - the seven-test canonical cluster from Revision 05;
   - cooldown and cancellation-ignoring shutdown sentinels three executions.
5. Resume the remaining Revision-05 completion gates without chance reruns:
   the exact 112-test successor gate, exact 90-test P1-E gate, source/scope
   gates, app build, dual SQLite migration matrix, and isolated packaged-app
   preview.
6. Finish with exact, unfiltered, default-parallel `swift run RunTests`.
   Overwrite `verify.log` with complete stdout/stderr, snapshot Bash
   `PIPESTATUS` once, and require command/tee zero. Serial execution is not an
   acceptance substitute.
7. Any different deterministic or load failure is preserved and requires a
   new bounded reviewed revision. Do not rerun the full suite until green by
   chance.

## 7. Completion gate and red lines

Revision 06 and Revision 05 compatibility closure are complete only when:

- Review01f approves this exact plan/allowlist before writes;
- the new FD regression is red before ownership code and green after it;
- failed initializers and all live client instances close sockets exactly
  once, including throw/deinit/manual-close paths;
- the complete merged environment is identical across twenty barrier-started
  callers and capture count is exactly one;
- queue suspension has no throwing gap before its exactly-once resume defer;
- all named narrow, successor, P1-E, source, build, migration, preview, and
  exact default-parallel full gates pass;
- `BoardToolServer.swift`, `LoginShellEnvironment` production code, runner,
  product timeouts/cooldowns, Board retry/deadline, twenty iterations, and
  `< 10` assertion remain unchanged from their frozen Revision-06 pre-images;
- the outside boundary remains exactly 496 /
  `5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95`;
- no v17, P1-F1/F2 behavior, trigger weakening, fallback, assertion dilution,
  normal user-state mutation, or prohibited external action occurs.

P1-E remains unaccepted and P1-F1 remains closed until all conditions hold,
an independent implementation Review02 reports zero P0/P1, and acceptance is
written from the resulting evidence.
