# P1-E Plan Revision 05 — Canonical event bytes and bounded full-gate stability

> Date: 2026-08-26  
> Scope: final compatibility closure after the first post-Revision-04
> authoritative full gate  
> Authority: accepted P1-E base plan §§3, 8–12; Revisions 01–04; canonical
> P1 plan §7; canonical Stage §§14–15, 18.6, 19, 26–27; user instruction to
> continue independently without Claude  
> Frozen history: every earlier plan, review, red log, and acceptance artifact
> remains byte-immutable

## 1. Trigger and durable red evidence

Revision 04's focused, source, build, migration, and preview gates passed. The
next exact `swift run RunTests` exposed ten issues in 990 tests / 24 suites.
The full output is frozen as:

```text
verify-revision-05-red.log
sha256=73d01654ef40470f46a770ce0ad53266aab5ebbcb9e0886061a47e0bf2463e62
tests=990
suites=24
issues=10
test_command_status=1
```

The evidence wrapper itself then read Bash `PIPESTATUS` in two assignments;
the first assignment reset the array and the wrapper exited 127. The complete
test output and its own `run_status=1` are present. Revision 05 corrects only
future evidence wrappers by snapshotting the entire array in one assignment;
there is no repository source change for this wrapper defect.

Five deterministic canonical failures were reproduced together at low load:

```text
red-revision-05-canonical.log
sha256=275f82090c8a68c28015d2eaf52d988f0a41030930ce8a6ed951a9861f7accf6
tests=5
issues=5
command_code=1
tee_code=0
```

An unmodified serial diagnostic kept the same five canonical failures and
exposed one first-iteration Board descriptor-baseline failure while all five
default-full resource/timing failures passed:

```text
verify-serial-revision-05-red.log
sha256=362552121ec436911a860639654d0eb65d9bf54d3b2314f379a123dbe0897c6d
command=swift run RunTests --no-parallel
tests=990
suites=24
issues=6
command_code=1
tee_code=0
```

Serial mode is diagnostic evidence only. It is not an acceptance command and
does not authorize changing the protected runner or hiding cross-test races.

## 2. Root-cause partition

### 2.1 Typed legacy-event payloads are encoded noncanonically

Revision 02 made `appendLegacyEventAndScope(payloadJSON:createdAt:)` validate
canonical bytes. Its `JSONValue` overload still calls
`JSONValue.encodedString()`, which guarantees sorted keys but not the P1
canonical byte grammar:

- JSONEncoder escapes `/` as `\/`; the canonical serializer emits `/`;
- `Double(Int.max)` encodes as an exponent and has already lost the exact
  `Int64.max` integer.

That makes the fixed `complete_card / block_card` diagnostic fail in
CardRunner and three CLI terminal paths. The test-only legacy planning helper
also round-trips `Int.max` through `Double`, violating Revision 02 §4.1.3.
The CLI pipe, process termination, card state machine, and raw canonical
overload are not the cause.

### 2.2 Login-shell environment bootstrap is not single-flight

`LoginShellEnvironment.environment()` checks a cache, releases its lock, and
then captures `/bin/zsh -l -c env`. Concurrent first callers all observe an
empty cache and each launch a login shell. In the default full run, every
environment-dependent shell/CLI test remained at bootstrap for about 29
seconds. That uncontrolled process/utility-queue burst delayed otherwise
independent timers, Board handlers, and the shell registry precondition.

This is a real shared runtime defect: concurrent cards or MCP/CLI startup can
also request the environment together. It is not corrected by enlarging test
timeouts or serializing the entire suite.

### 2.3 Board test client conflates timeout with peer closure

`BoardSocketTestClient.readLine()` returns `nil` both for real EOF/reset and
for `EAGAIN`/`EWOULDBLOCK` after `SO_RCVTIMEO`. Under the bootstrap burst, the
framing test treated “no byte yet” as EOF; the wrong-token test treated the
same timeout as proof of server closure and raced its next connection.

The descriptor test also samples its baseline before the process has paid
one-time GRDB/Dispatch/socket initialization. A standalone three-repetition
run failed only iteration one with a +12 delta, then passed iterations two
and three. This is a baseline error, not evidence that the threshold should
be relaxed.

## 3. Exact effective scope

The executable allowlist contains exactly 115 unique LF-terminated paths:

```text
allowlist_sha256=a1f784a4f664c91583a1b3c758a32b3573a21810e0e722048ab7e7ada582085c
allowlist_lines=115
outside_count=496
outside_manifest_v1=5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95
```

Revision 05 adds exactly five source/test paths:

```text
Sources/AgentLoopCore/Support/ShellProcessRegistry.swift
Sources/AgentLoopTestSuite/BoardServerTests.swift
Sources/AgentLoopTestSuite/OrchestratorTests.swift
Sources/AgentLoopTestSuite/PlanningTokensTests.swift
Sources/AgentLoopTestSuite/ShellToolTests.swift
```

It adds exactly these plan/evidence/review artifacts:

```text
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-05.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-05-canonical.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/red-revision-05-tdd.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/verify-revision-05-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/verify-serial-revision-05-red.log
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01e-p1-e-compatibility-plan-review.md
```

The seven implementation-sensitive pre-images are frozen before writes:

| File | SHA-256 |
|---|---|
| `LegacyEventScopeResolver.swift` | `2fb0ef425b4e92b65b127f320d78f6943b47e2ec866e41297d224873ea4ad0e9` |
| `LegacyScopeMigrationTests.swift` | `59f7097956df9e5b6c5ab3e3c94ceef811ee289e8aad8acd65ca3e16495c2eee` |
| `ShellProcessRegistry.swift` | `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1` |
| `ShellToolTests.swift` | `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29` |
| `BoardServerTests.swift` | `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |
| `OrchestratorTests.swift` | `ec33b2a09c8d588488185afdc09ca534ae6312bc8736804d5030f745ced8fb4a` |
| `PlanningTokensTests.swift` | `2b361402c8bb2e990de7a72e1bc169b45b14df21cd66eee05480285347d1f524` |

`DurablePlanningTests.swift` is already allowlisted and is frozen at
`934a81b6318726ffcf2bb90da907659f86ffbe077ddb52fa52708c37cea18358`.
The protected runner remains byte-exact at
`70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`.

At plan freeze, before Review01e, `dirty_total=601`,
`allowlisted_present_count=105`; creation of this plan makes the latter 106.
Only allowlisted files may increase either counter. The outside count/hash
above must remain exact.

## 4. Decision-complete implementation map

### 4.1 Canonical event boundary

1. In `LegacyEventScopeResolver.swift`, the `JSONValue` overload of
   `appendLegacyEventAndScope` must use
   `CanonicalJSONV1.encode(payload)` and pass the resulting UTF-8 string to
   the raw overload.
2. The raw overload must continue to call `validateCanonical`, validate the
   timestamp, resolve typed scope before the event insert, and fail closed.
3. Do not change `JSONValue.encodedString()` globally, the canonical parser,
   event triggers, or any raw-string call site.
4. Extend existing `p1e35LegacyEventAppendScopeFirst` with one payload that
   contains both a slash-bearing string and `Double(Int.max)`. Assert the
   persisted bytes are canonical (including the Double's exact represented
   value) and the scope remains global/Camp as declared.
5. In the test-only `recordPlanningTokens` helper in `OrchestratorTests.swift`,
   construct `PlanningUsageCountersV1` with exact nonnegative `Int64` values,
   encode it with `CanonicalJSONV1`, and call the raw canonical overload.
   Never pass these counters through `JSONValue`, `Any`, or `Double`.
6. Extend `recordPlanningTokensSaturatesInsteadOfOverflowing` to assert the
   exact event bytes contain `9223372036854775807`, while the mission
   projection remains saturated at `Int.max`.

### 4.2 Login-shell environment single-flight

1. `LoginShellEnvironment` keeps one in-flight
   `Task<[String: String], Never>?` under its existing lock.
2. The first empty-cache caller creates a shared task that captures the login
   environment and merges it over the process environment exactly once.
   Concurrent callers take the same task, release the lock, and await it.
3. A completed result is cached before the in-flight slot is cleared. No lock
   is held across `await`; caller cancellation cannot cancel the shared
   capture; no environment values or secrets are logged.
4. The public initializer preserves current behavior. Add only a package
   initializer with a `@Sendable async` capture closure so the existing
   `loginShellEnvironmentCapturesPath` test can prove 20 concurrent first
   callers invoke the capture exactly once and receive the same merged value.
5. Keep the real capture command, five-second watchdog, environment merge
   precedence, `ShellProcessRegistry`, `ShellTool`, CLI backend, and MCP
   process logic otherwise unchanged.
6. In `shellRegistryTerminateAllKillsRunning`, finish shared environment
   preparation before measuring process registration. If registration still
   does not occur, cancel and await the task, record the failed precondition,
   and return; never call `terminateAll()` on an empty registry and then wait
   for a late `sleep 30` process.

### 4.3 Board test harness correctness

1. Keep the existing receive timeout value. Change `readLine()` so only real
   EOF, reset, or disconnected errors return `nil`; `EAGAIN`/`EWOULDBLOCK`
   throws an explicit timeout error. No protocol response or closure assertion
   may treat a timeout as success.
2. Do not add connection retries to the framing, token, or card-contract
   tests and do not modify `BoardToolServer.swift`.
3. Before the descriptor baseline, run one complete warm-up harness lifecycle
   (server start, authorized client, client close, server stop, weak release).
   Then retain the existing 20-iteration lifecycle test and `< 10` net-FD
   assertion unchanged.

### 4.4 Historical boundary sentinel

Update only the P1-E successor accounting in `DurablePlanningTests.swift`:

```text
allowlist_lines=115
allowlist_sha256=a1f784a4f664c91583a1b3c758a32b3573a21810e0e722048ab7e7ada582085c
A4 raw P1-E intersection=38
A3 raw P1-E intersection=40
A4 unaffected entries=128
A3 live/enumerated entries=124
```

Add exactly these three new successor exclusions:

```text
Sources/AgentLoopCore/Support/ShellProcessRegistry.swift
Sources/AgentLoopTestSuite/PlanningTokensTests.swift
Sources/AgentLoopTestSuite/ShellToolTests.swift
```

`BoardServerTests.swift` and `OrchestratorTests.swift` are already owned by the
frozen P1-C and P1-D predecessor sets, respectively; they change only the raw
intersection counts. No frozen manifest is rewritten.

## 5. Ordered TDD and verification

1. Freeze this plan, the 115-line allowlist, all pre-images, and independent
   Review01e with `APPROVED — 0 P0 / 0 P1` before any source/test write.
2. Apply only the new assertions/seams in the four named test files first.
   Run the canonical, environment single-flight, shell registry, and Board
   tests. Save the complete expected red/compile-red output with command and
   tee statuses to `red-revision-05-tdd.log`.
3. Apply the three root fixes and the exact successor-sentinel update.
4. Run these narrow gates with zero issues:
   - `p1e35LegacyEventAppendScopeFirst`;
   - both planning-token tests;
   - the CardRunner and three CLI canonical failures;
   - `loginShellEnvironmentCapturesPath` and
     `shellRegistryTerminateAllKillsRunning` three times;
   - the two Board red tests, descriptor test three times, then the complete
     `BoardServerTests` suite;
   - `rateLimitTriggersGlobalCooldownThenRecovers` and
     `shutdownWithCancellationIgnoringProviderReturnsBoundedly` three times.
5. Re-run the 112-test Revision-04 successor gate and the exact 90-test P1-E
   focused gate.
6. Regenerate source/scope gate, app build, dual SQLite migration matrix, and
   isolated `.app` preview revalidation when any relevant source hash changes.
7. Run exact, unfiltered, default-parallel `swift run RunTests` last. Save full
   stdout/stderr to `verify.log`; snapshot `PIPESTATUS` once; command and tee
   must both be zero. A serial run cannot satisfy this gate.
8. If any different deterministic or load failure remains, preserve the log
   and require another bounded reviewed revision. Do not retry the full suite
   until green by chance.

## 6. Completion gate and red lines

Revision 05 is complete only when:

- Review01e approves this exact plan/allowlist with zero P0/P1 before writes;
- pure red evidence precedes implementation and every named narrow successor
  passes without removed or weakened assertions;
- login environment capture is demonstrably single-flight under concurrent
  first use without logging values;
- raw canonical event callers remain strict and exact integers never pass
  through `Double`;
- the 90-test P1-E gate, source gate, build, migration matrix, preview, and
  default-parallel authoritative 990-test suite all pass;
- `Sources/RunTests/main.swift` and every production timeout/cooldown remain
  unchanged;
- the outside boundary remains exactly 496 / `5324d448...2299b95`;
- no v17, P1-F1/F2 behavior, trigger weakening, fallback, assertion dilution,
  normal user-state mutation, or prohibited external action occurs.

P1-E remains unaccepted and P1-F1 remains closed until all conditions hold.
