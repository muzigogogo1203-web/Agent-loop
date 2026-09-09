# P1-E Compatibility Plan Review — Review01f

> Date: 2026-08-26  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This review was performed by a separate Codex
> subagent. The reviewer did not author Revision 06 and did not modify product,
> test, plan, allowlist, or prior evidence bytes. The only repository write in
> this pass is this review artifact.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

```text
revision_05_sha256=e52cf5149ec235535971f04f5f741f38439c080b9907fde341b847ffa208e564
review_01e_sha256=714fd5c333ca098b64828fcc531a9b9fe3b79b7dedb38b85ce52e1491324cbdf
revision_05_tdd_red_sha256=90acaa76cc389d2fc62b16e7c1c9f9bbf266af804c1bd13f4cfe2e681ec5b426
revision_06_sha256=6894971b1a39bc004ffde1f71bc2954843b5b4eccc88dbeffc383aa30722b0f9
revision_06_board_red_sha256=9960c733280e44f6278adf28f3d889d3b92757ea6c6aeed50add81c037e5a7de
revision_06_board_diagnostic_sha256=2b64b5cecc7656a5746c644d6120c199724e79c69ae5714cce927f32d4eb0711
effective_allowlist_sha256=390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46
```

## Review scope and method

I reviewed `AGENTS.md`, the collaboration protocol, the immutable P1-E base
plan, Revisions 01–06, Review01e, the Revision-05 tests-first red, both
Revision-06 Board artifacts, the executable allowlist, the three
implementation-sensitive Revision-06 pre-images, all protected Revision-05
bytes named by the plan, and the current Board/login-environment/successor
sentinel seams. I did not run a build or the authoritative/full test suite.

For the FD root only, I also ran the already-built executable under LLDB with
the single filter
`boardServerHandlerBlockKeepsServerAliveUntilConnectionCloses`. This was a
read-only causal diagnostic, not acceptance evidence and not a chance-green
retry. The last fresh run recorded seven catches at the exact
`connectClientWithRetry` `ECONNREFUSED` catch and a final net descriptor delta
of eleven. Together with the four last-live-database descriptors established
by lsof, that independently reproduces the exact one-leaked-socket-per-failed-
initializer accounting.

## Frozen scope and boundary

The allowlist has exactly 121 LF-terminated, nonempty, unique paths. Removing
exactly the six Revision-06 task artifacts reconstructs the 115-line
Revision-05 allowlist byte-for-byte:

```text
revision_06_allowlist_lines=121
revision_06_allowlist_nonempty_unique=121
revision_06_allowlist_sha256=390534f89cb2f4826403ee1507976f9b0dd6047aa17c0c32acea87ff6b256d46
reconstructed_revision_05_lines=115
reconstructed_revision_05_sha256=a1f784a4f664c91583a1b3c758a32b3573a21810e0e722048ab7e7ada582085c
```

No source or test path is newly admitted. Replaying the base plan's NUL-safe
byte-count/mode/content serializer immediately before this review gave:

```text
dirty_total=609
allowlisted_present_count=113
outside_count=496
outside_manifest_v1=5324d448cdef76ceb5e01b34e1f1c910bb3d79ece38ec54af57085caf2299b95
```

Creating this allowlisted review may advance only the first two counters to
610 and 114. The post-plan edits to `blocked.md` and `impl-report.md` are
already-admitted paths that were already dirty/present; they changed neither
counter membership nor the outside boundary. They also did not alter any
implementation pre-image or protected byte listed below.

The three implementation-sensitive pre-images are exact:

| File | SHA-256 |
|---|---|
| `BoardServerTests.swift` | `86cd0314663e2ebb276d985472c3cc38372cd527e5eb1530b03927a4d4fc7997` |
| `ShellToolTests.swift` | `281929993fb000b60b0f03a0daa6c9dbb49654677b773194ebd4d20351e725a2` |
| `DurablePlanningTests.swift` | `17ec410555a1523dd649d3c12c8393a6f259b9d9a38d303602d879c8d97e8555` |

The protected or already-correct Revision-05 bytes are also exact:

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

## Findings

### Failed-initializer ownership is the demonstrated root

The frozen Board red is a deterministic failure of the unchanged `< 10`
descriptor assertion after the Revision-05 warm-up. The current private test
client opens its socket into a stored `let`, closes it only when
`SO_NOSIGPIPE` setup fails, then calls throwing `connect`. A connect throw
aborts initialization before any instance exists, so explicit `close()` and
an instance `deinit` cannot own that descriptor. The caught retry then loops
with the descriptor still open.

The frozen LLDB/lsof excerpt directly shows the first caught retry and its
new unconnected `unix ->(none)` descriptor. The fresh narrow LLDB run above
showed seven caught failures and `7 + 4 = 11` final delta. The retry count is
timing-dependent; the one-per-failure relationship is not. This independently
validates the plan's causal partition and rules out the successful warm-up as
a root fix. The product `BoardToolServer`, retry deadline, receive timeout,
twenty iterations, and `< 10` threshold correctly remain protected.

Revision 06 provides a complete ownership correction: keep the newly opened
fd local while setup may throw; close that local fd on every failure; publish
it to an instance only after successful setup; use `-1` as the released
sentinel; swap before close; make manual close idempotent; and invoke it from
`deinit`. The twenty-attempt nonexistent-socket regression must require the
typed failure each time and exact zero net FD growth. It is red against the
frozen pre-image and directly covers the previously ownerless path. Existing
explicit-close and complete Board gates retain live-instance coverage.

### Warm-up removal and queue ownership are exact

`warmBoardHarnessLifecycle` performs only a successful connect/hello/close
lifecycle. It cannot exercise a connect failure that prevents object
construction, so removing both its helper and call is a root-cause correction,
not assertion dilution.

The current timeout test calls `queue.suspend()` and performs two throwing
setup operations before installing its resume defer. Releasing a suspended
queue after such a throw can trap the process. Revision 06 requires the defer
immediately after suspension, before any throw, permits no second resume, and
retains the unchanged five-second timeout assertion and client/server cleanup.
That is an exactly-once ownership rule and is decision-complete.

### The 20-caller single-flight proof becomes deterministic

The current Revision-05 test relies on 100 `Task.yield()` calls inside capture
and asserts only the PATH entry. It can pass without proving that all callers
were poised together or that their complete merged environments are equal.

Revision 06 replaces that scheduler hint with two explicit test actors: a
20-party start barrier before `environment()` and a capture-release latch that
keeps the sole capture pending until the barrier is open and that capture has
been observed. The required sequence prevents callers from completing before
the overlap is established. The assertions pin exactly one capture, exactly
twenty results, the injected PATH precedence, and full dictionary equality to
the first result. No production `LoginShellEnvironment` byte is authorized to
change, and no error or timeout may be converted into success.

### Historical sentinels are arithmetically unchanged

Both protected historical manifests have 206 unique entries. Intersecting the
current 121-line allowlist gives:

```text
A4 raw P1-E intersection=38
A3 raw P1-E intersection=40
```

All six Revision-06 additions are task documents and intersect neither
manifest. The ten successor exclusions are byte-identical to Revision 05.
The existing disjoint owner partitions therefore remain:

```text
A4 unaffected entries=206-46-3-19-10=128
A3 live/enumerated entries=206-7-43-3-19-10=124
```

Only the executable allowlist count and SHA assertions in
`DurablePlanningTests.swift` need to advance. No predecessor manifest or
successor exclusion changes.

### TDD order and completion red lines are sufficient

The plan freezes approval before another source/test write, adds the failed-
connect regression and stronger concurrency proof first, and requires the FD
regression to fail under the exact Board pre-image before ownership code. It
then limits implementation to private test-client ownership, exactly-once
queue resume, warm-up removal, and the allowlist sentinel.

The named narrow sequence rechecks the new FD regression, timeout-vs-EOF and
both original Board protocol failures, three descriptor executions, the
complete Board suite, three login/shell executions, the seven canonical
tests, and three cooldown/shutdown executions. It then resumes the exact
112-successor and 90-test P1-E gates, source/build/migration/packaged-preview
evidence, and finishes with unfiltered default-parallel `swift run RunTests`
with a single `PIPESTATUS` snapshot. A serial run, chance rerun, threshold or
timeout increase, production Board/login change, v17/P1-F surface, fallback,
or assertion weakening cannot satisfy the gate.

No P0 or P1 finding remains. The frozen 83-line LLDB artifact is an excerpt
rather than a complete transcript of every historical retry; the independent
static proof and fresh narrow hit-count/delta reproduction above make that an
evidence-label precision note, not a blocker to this bounded root fix.

## Verdict

**APPROVED — 0 P0 / 0 P1.**
