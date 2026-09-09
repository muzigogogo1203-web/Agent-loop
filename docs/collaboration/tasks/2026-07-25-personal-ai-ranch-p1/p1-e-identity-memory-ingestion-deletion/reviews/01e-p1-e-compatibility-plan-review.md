# P1-E Compatibility Plan Review — Review01e

> Date: 2026-08-26  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This review was performed by a separate Codex
> subagent in a read-only pass. The reviewer did not author Revision 05 and did
> not modify product, test, plan, allowlist, or evidence bytes.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

```text
base_plan_sha256=e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727
revision_01_sha256=a490e3408ae4deb227980a2af8a382fe47e2d2ff8651546baf7fc72e90a56198
revision_02_sha256=597646e6ee2152ddfff523fbe67d0651e3a0050dc3fae8e65496bd0dd6d4bca9
revision_03_sha256=3ffec577b9045c8796bf44f21a504851630bf2c73ccf9eed2e59d6f513b05492
revision_04_sha256=e1f12961edcadf02dd2c404037235c19a5ad43673e5c87d8c231a02a6204c41a
revision_05_sha256=e52cf5149ec235535971f04f5f741f38439c080b9907fde341b847ffa208e564
effective_allowlist_sha256=a1f784a4f664c91583a1b3c758a32b3573a21810e0e722048ab7e7ada582085c
full_red_sha256=73d01654ef40470f46a770ce0ad53266aab5ebbcb9e0886061a47e0bf2463e62
serial_red_sha256=362552121ec436911a860639654d0eb65d9bf54d3b2314f379a123dbe0897c6d
canonical_red_sha256=275f82090c8a68c28015d2eaf52d988f0a41030930ce8a6ed951a9861f7accf6
```

## Review scope and method

I reviewed `AGENTS.md`, the collaboration protocol, the immutable base plan,
Revisions 01–05, Review01d, the canonical P1 plan/stage authority, all three
Revision-05 red logs, the executable allowlist, the seven implementation
pre-images, the protected runner, and the current source/test seams named by
Revision 05. I did not run a build or test command and did not edit any
implementation surface.

I independently recomputed the allowlist delta and the base plan's NUL-safe
outside serializer. Immediately before creating this review the live counters
were `dirty_total=602` and `allowlisted_present_count=106`; this review is an
allowlisted artifact, so only those two counters may advance by one. The
frozen boundary is exact:

```text
allowlist_lines=115
allowlist_nonempty_unique=115
outside_count=496
outside_manifest_v1=5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95
```

Removing exactly the five source/test paths and six Revision-05 artifact
paths reconstructs the 104-line Revision-04 allowlist SHA
`fa6fb13794903e66ce316f69a5f39922e9edca0fea69f72099a258c12cd3b43c`.
There is no hidden path admission.

The seven implementation pre-images are byte-exact:

| File | SHA-256 |
|---|---|
| `LegacyEventScopeResolver.swift` | `2fb0ef425b4e92b65b127f320d78f6943b47e2ec866e41297d224873ea4ad0e9` |
| `LegacyScopeMigrationTests.swift` | `59f7097956df9e5b6c5ab3e3c94ceef811ee289e8aad8acd65ca3e16495c2eee` |
| `ShellProcessRegistry.swift` | `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1` |
| `ShellToolTests.swift` | `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29` |
| `BoardServerTests.swift` | `249a9bae89e99c4e5608ae9b6677e13bd571cba26c8343f9708ee9fad85dc63b` |
| `OrchestratorTests.swift` | `ec33b2a09c8d588488185afdc09ca534ae6312bc8736804d5030f745ced8fb4a` |
| `PlanningTokensTests.swift` | `2b361402c8bb2e990de7a72e1bc169b45b14df21cd66eee05480285347d1f524` |

`DurablePlanningTests.swift` remains
`934a81b6318726ffcf2bb90da907659f86ffbe077ddb52fa52708c37cea18358`,
and protected `Sources/RunTests/main.swift` remains
`70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`.
Canonical Stage/Plan, master spec, P1-D acceptance, `Package.resolved`, and the
four protected contract/canonical-JSON inputs also match the hashes frozen by
the base plan.

## Findings

### The red partition is complete and causal

- The default-parallel red has 990 tests / 24 suites / 10 issues: five
  canonical-boundary failures, two Board failures, one environment-dependent
  shell-registration failure, and two independent timer/cooldown observations.
- The five canonical failures reproduce together at low load. The serial
  diagnostic retains exactly those five and exposes only the first-iteration
  Board descriptor baseline error; all five default-run resource/timing
  observations pass serially. Serial mode is therefore correctly treated as
  diagnostic evidence, not an acceptance workaround.
- Concurrent first use of the current `LoginShellEnvironment` can launch one
  login shell per caller because the cache check and capture are separated by
  an unlocked interval. The approximately 29-second clustering across the
  environment-dependent tests is consistent with this exact shared-runtime
  defect. The plan does not convert that observation into wider timeout or
  suite-serialization changes.

### Canonical event correction preserves the strict boundary

The only production canonical change is to route the existing `JSONValue`
overload through `CanonicalJSONV1.encode`. The raw overload remains the single
strict sink: it still validates byte canonicality and finite time, resolves
typed scope before insertion, writes scope first, and fails closed. The plan
explicitly forbids changing `JSONValue.encodedString()`, the canonical parser,
raw-string callers, triggers, or validators.

The slash plus `Double(Int.max)` extension proves the formerly missing
canonical serializer behavior without pretending a `Double` is an exact
integer carrier. The test-only planning helper separately constructs exact
nonnegative `Int64` counters, encodes the typed payload with
`CanonicalJSONV1`, and calls the already-strict raw overload. Its successor
assertion pins `9223372036854775807`, so the accepted fix cannot reintroduce an
`Any`/`JSONValue`/`Double` round trip.

### Login environment single-flight is a root fix

Revision 05 specifies one shared in-flight `Task` protected by the existing
lock, cache publication before slot clearing, and no lock held across `await`.
All first callers await the same unstructured capture; waiter cancellation
does not cancel that shared work. Capture failure keeps the existing process-
environment fallback, merge precedence stays unchanged, the five-second
watchdog stays unchanged, and neither environment values nor secrets may be
logged. The public initializer remains source-compatible; the package-only
capture seam adds no product capability.

The 20-caller first-use test must prove exactly one capture and one identical
merged result. The shell-registry fixture must prepare that shared environment
before measuring registration and must cancel and await its task on a failed
precondition. This is stricter cleanup and prevents a late `sleep 30`; it does
not call `terminateAll()` on an empty registry or weaken the registration
assertion. Three-run narrow gates plus the final default-parallel suite are
appropriate evidence for both the concurrency contract and the original load
symptom.

### Board harness changes tighten rather than dilute assertions

The current client maps receive timeout and peer closure to the same `nil`.
The plan requires `EAGAIN`/`EWOULDBLOCK` to throw an explicit timeout while
only EOF/reset/disconnection may return `nil`. Consequently framing and
closure tests can no longer pass on “no byte yet.” The receive timeout value,
protocol assertions, connection count, production `BoardToolServer`, and all
production timing values remain unchanged.

The one complete pre-baseline warm-up pays one-time GRDB/Dispatch/socket
initialization before measurement, then retains the existing 20 lifecycle
iterations and exact `< 10` net-descriptor assertion. It does not raise the
threshold, remove a lifecycle, or add retries to the two red protocol tests.

### Historical sentinels and stage boundary are exact

Independent intersection against both 206-entry manifests gives:

```text
A4 raw P1-E intersection=38
A4 P1-E successor exclusions=10
A4 unaffected entries=128
A3 raw P1-E intersection=40
A3 P1-E successor exclusions=10
A3 live/enumerated entries=124
```

The ten successor exclusions are the prior seven plus exactly
`ShellProcessRegistry.swift`, `PlanningTokensTests.swift`, and
`ShellToolTests.swift`. `BoardServerTests.swift` and `OrchestratorTests.swift`
increase only raw intersections because their predecessor ownership already
excludes them. No historical manifest is rewritten.

Revision 05 admits no v17/P1-F1/P1-F2 surface, migration, retirement command,
trigger weakening, normal-state mutation, or protected-runner change. The
ordered gate is decision-complete: approve/freeze first; add tests and capture
pure red before source changes; apply the three roots; run named narrow and
three-repetition gates; rerun the 112-successor and exact 90-test gates; then
regenerate source/build/matrix/preview evidence and finish with the exact,
unfiltered, default-parallel `swift run RunTests`. A serial run or retry-only
green cannot satisfy completion.

No P0, P1, or necessary P2 finding remains.

## Verdict

**APPROVED — 0 P0 / 0 P1.**
