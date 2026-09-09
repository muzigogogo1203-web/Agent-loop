# P1-E Plan Revision 08 — close both Board scheduling boundaries

> Date: 2026-08-27  
> Scope: the single P1 correction required by Review01g  
> Authority: accepted P1-E base plan; Revisions 01–07; Review01g; canonical
> P1 authority; the user's instruction to continue independently without
> Claude  
> Frozen history: Revision 07 and Review01g remain byte-immutable; Review01g
> authorized no source/test implementation

## 1. Trigger and exact supersession

Revision 07 correctly bounded the shutdown, cooldown, and failed-client
descriptor roots. Review01g independently recomputed every boundary and found
those sections conformant, but returned:

```text
Review01g=NEEDS CHANGES — 0 P0 / 1 P1
review01g_sha256=6aa406c379e7200946e61307ec843078333df7f580c4634c1383709bd44dc247
revision07_sha256=1a7bf9e4fb83816baab1551984d390c0e595f12e0d163040387de0ff48fbbebc
```

The finding is exact: Revision 07 isolates only the injected handler queue,
but `BoardToolServer.start()` schedules `acceptLoop` on a separate hard-coded
global utility queue. A client can therefore remain in the initial hello/read
wait before the dedicated handler queue is reached. The frozen sampling
evidence shows that pre-handler wait dominated the failure.

Revision 08 supersedes only Revision 07 §§3–6 where needed to admit and
control the accept queue. Revision 07 §§1–2 and §§4.1–4.3 remain effective;
§4.4 is replaced by §4 below; §4.5 and all gates use the Revision-08 boundary
values below. No source or test byte changed between Review01g and this plan.

The preserved full red and diagnosis remain:

```text
verify-revision-07-red_sha256=8ab32c3445412823bf0f4ccf117c79f3b7d5ed464a4da43cebdf81dd66640f7d
diagnostic-revision-07_sha256=162dd725a87b3ce0b12dc715f8c08ff16fe3f386310798a1bb56453384543b6b
tests=992
suites=24
issues=4
command_code=1
tee_code=0
```

## 2. Exact effective scope and pre-images

Revision 08 adds one source path and four task artifacts to the 128-line
Revision-07 boundary:

```text
Sources/AgentLoopCore/Loop/BoardToolServer.swift
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-08.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-08-tdd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/revision-08-narrow-gates.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01h-p1-e-compatibility-plan-review.md
```

The exact executable boundary is:

```text
allowlist_lines=133
allowlist_nonempty_unique=133
allowlist_sha256=581f9e5bafc80e9f480ca7faff519f6f11f02ff6ab79e6a278da392707670bbc
outside_count=494
outside_manifest_v1=b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740
```

Implementation-sensitive pre-images are:

| File | SHA-256 |
|---|---|
| `BoardToolServer.swift` | `ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea` |
| `BoardServerTests.swift` | `ea974b23b544fd353772935440f38f07916f406befccc0bfe245d3b30c6e1dda` |
| `Orchestrator.swift` | `4dcfa183d6a7e85d31651d7dded45a5adb624a4cda01677c010c7727efc1e087` |
| `HaltAndCooldownTests.swift` | `339d8ddf8c1bc0514590a813f3ebab671885c5b5ed2b6dfe231b3e5810a13b6a` |
| `DurablePlanningTests.swift` | `c05d633ff65e7f7edf25c35bbbf8ab2a18bd23c35887e7eba6c070011f8c07d5` |

Protected pre-images remain:

| File | SHA-256 |
|---|---|
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Package.swift` | `0a4b9d3c4eba1a06bda535e69c54c3a5186dcaf148bcb489f1667b4c069cba48` |

Immediately before this plan, live counters were `dirty_total=616` and
`allowlisted_present_count=122`; only this plan and Review01h may advance the
allowlisted count before tests-first writes. Outside must remain exact.

## 3. Effective implementation map retained from Revision 07

The following Revision-07 decisions are adopted without expansion:

1. `DurablePlanningTests.swift` replaces only the real `<1s` shutdown
   measurement with an actor-controlled injected 25ms deadline and a causal
   pre-release/non-completion assertion. The provider remains genuinely
   cancellation-ignoring; the exact uncooperative work ID assertion remains.
2. `Orchestrator.swift` adds a package-only stored
   `@Sendable () -> ContinuousClock.Instant`, live-defaulted without expanding
   the public initializer. Exactly the cooldown set/check reads use it.
   `HaltAndCooldownTests.swift` freezes time, requires no second-card run,
   advances exactly 400ms, and requires recovery; its real sleeps are removed.
3. The failed-connect Board test first proves the old process-global observer
   red with two unrelated pipe descriptors. Its green form observes twenty
   ordered client-local `opened(fd)` / `closed(fd, closeResult)` pairs around
   the real `socket` and `Darwin.close` calls, requires each close result zero,
   and separately proves the unrelated pipe stays open. Revision-06 RAII,
   twenty lifecycle iterations, and `<10` remain.

No `DurableWorkSupervisor`, duration, timeout, protocol, retry, or threshold
change is admitted.

## 4. Replacement Board accept-and-handler decision

### 4.1 Product seam with unchanged live default

`BoardToolServer` gains one stored `acceptQueue: DispatchQueue`. Its existing
public initializer adds a source-compatible defaulted parameter:

```swift
acceptQueue: DispatchQueue = DispatchQueue.global(qos: .utility)
```

The existing `handlerQueue` default remains exactly global utility. The new
property is assigned directly. `start()` replaces only:

```swift
DispatchQueue.global(qos: .utility).async { ... }
```

with:

```swift
acceptQueue.async { ... }
```

Listener creation, bind/listen, ownership transfer, weak-self capture,
accept-loop logic, stop/wake behavior, connection claim, and handler dispatch
remain byte-semantically identical. Production callers that omit the new
argument retain the exact old global-utility behavior.

### 4.2 Functional test controls both independent queues

`makeBoardHarness` adds an optional/defaulted `acceptQueue` input and passes it
to `BoardToolServer`. Existing tests that do not supply it retain the product
default. The framing functional test alone creates two distinct serial queues:

```text
accept queue: unique label, userInitiated QoS
handler queue: different unique label, userInitiated QoS
```

They must be distinct because the accept loop blocks in `accept()` while the
handler must execute concurrently. Before server construction, the test runs
one synchronous no-op on each queue to prove both queues can execute. It then
passes both queues into the harness and preserves the real socket plus every
existing hello/progress/search/complete/persistence/terminal assertion.

The five-second `SO_RCVTIMEO` is unchanged. The separate timeout-vs-EOF test
keeps its suspended handler queue and requires `receiveTimedOut`; it uses the
live/default accept queue unless explicitly named by its existing contract.
Wrong-token, second-connection, stop, and descriptor tests retain their
protocol semantics.

## 5. Historical sentinels and source boundary

The effective `a3P1EHistoricalSuccessorExclusions` remains the eleven-entry
Revision-07 set including `HaltAndCooldownTests.swift`. `BoardToolServer.swift`
exists in both frozen 206-entry manifests but is already owned by the P1-D
successor intersection, so adding it to the raw P1-E allowlist changes only
the raw counts:

```text
allowlist_lines=133
allowlist_sha256=581f9e5bafc80e9f480ca7faff519f6f11f02ff6ab79e6a278da392707670bbc
A4 raw P1-E intersection=40
A4 unaffected entries=127
A3 raw P1-E intersection=42
A3 live/enumerated entries=123
```

No frozen manifest or predecessor/successor ownership set changes. The
source/scope gate uses the exact 494-entry outside manifest and otherwise
retains every Revision-07/Revision-06 source, Package, runner, v16, raw SQLite,
and P1-E 90-test identity requirement.

## 6. Ordered tests-first and verification

1. Freeze this plan, the 133-line allowlist, Review01g finding, all pre-images,
   and independent Review01h with `APPROVED — 0 P0 / 0 P1` before writes.
2. Append two pure reds to `red-revision-08-tdd.log` with full stdout/stderr
   and one Bash `PIPESTATUS` snapshot per command:
   - first change only the failed-connect test to hold the unrelated pipe over
     its old global-count assertion; filtered execution must fail at exact
     `+2`;
   - then write the planned test calls for `rateLimitNow` and `acceptQueue`
     without source seams; filtered compilation must fail only because those
     planned arguments are absent.
3. Apply exactly §§3–5. No other source/test file may change.
4. Save complete zero-status output to `revision-08-narrow-gates.log` for:
   - shutdown and cooldown, five separate executions;
   - framing, timeout-vs-EOF, failed-connect ownership, and wrong-token, five
     separate executions;
   - complete `BoardServerTests`, three separate executions;
   - those six resource-sensitive tests plus
     `shellRegistryTerminateAllKillsRunning` and
     `loginShellEnvironmentCapturesPath`, three separate executions;
   - the exact Revision-06 112-test successor gate;
   - the exact P1-E 90-test gate.
5. Rebuild the exact source/scope gate with Revision-08 values and replace
   `source-gates.log` only after all sections pass.
6. Run `swift build --product AgentLoopApp`; replace `build.log` only with
   complete command/tee-zero evidence.
7. Revalidate the protected migration inputs. Retain the current dual SQLite
   matrix SHA `060c9af4f9b8c336918871e4324a304efd6d39b554a2d3919d255c13c0aea40d`
   only if every matrix input remains exact; otherwise rerun it.
8. Both `Orchestrator.swift` and `BoardToolServer.swift` change packaged Core
   bytes. Append a fresh isolated packaged preview revalidation to the
   existing `preview.log`, preserving its current bytes as prefix. Require
   executable/environment identity, isolated database, bundle/resources,
   codesign, SQLite integrity/FK and v16/v15/v14 tail, exact PID termination,
   and command/tee zero.
9. Finish with one exact, unfiltered, default-parallel
   `swift run RunTests`. Replace `verify.log` with complete stdout/stderr and
   a single `PIPESTATUS` snapshot. Command and tee must both be zero. A new
   failure is preserved, not chance-rerun.

## 7. Completion gate and red lines

Revision 08 and P1-E compatibility close only when:

- Review01h approves before implementation;
- both pure red phases have only their expected root;
- both accept and handler scheduling boundaries are isolated in the framing
  test while live defaults remain global utility;
- shutdown, cooldown, owned-FD, protocol, historical, source, build,
  migration-hash, preview, and exact default-parallel gates all pass;
- outside remains exactly 494 /
  `b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740`;
- runner/default parallelism, `DurableWorkSupervisor`, all durations and
  socket semantics, Board ownership/stop/retry, twenty iterations, and `<10`
  remain frozen;
- there is no async/semaphore rewrite, broad serialization,
  `--no-parallel`, timeout/duration increase, retry-until-green, yield/sleep
  paper-over, fallback, swallowed error, assertion dilution, P1-F behavior,
  normal user data mutation, or external action.

P1-E remains unaccepted and P1-F1 remains closed until the final full gate is
green, independent implementation Review02 reports zero P0/P1, and acceptance
is written from the resulting evidence.
