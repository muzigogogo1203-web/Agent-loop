# 069 coroutine split actual-diff review

Decision: **APPROVE for normal compiler/focused-test verification.** Spec compliance and source code quality pass this scoped review. No actionable source finding or blocking deviation was identified. Normal object compilation, focused runtime tests, full-suite acceptance, and later product gates remain pending.

## Exact reviewed change

- Checkout/branch: `/Users/muzi/Agent-loop`, `codex/desktop-coding-closure-20260905`.
- Unchanged HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.
- Frozen preimage SHA-256: `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`.
- Reviewed `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift` SHA-256: `e5a3ce4fae3ae1c0487ffe3c62b43360f49c7c6ef49ddf1d2d2538397ca2380e`.
- Reviewed `runtime-coro-split.diff` SHA-256: `524b1207cf3d0929f390582e960028950a9a4ea5a694b723193fcbcd6915a873`.

Read `.superpowers/sdd/runtime-coro-split-plan/task-1-brief.md`, its `task-1-report.md`, the actual patch, and the current helper/caller structure. This review compares the task's frozen source with its postimage, not the aggregate dirty HEAD diff. The prior `runtime-coro-split-plan-review.md` supplies the detailed approved boundary/lifetime analysis; exact body equivalence below confirms that this implementation preserves those reviewed bodies.

## Independent mechanical verification

A separate read-only Ruby audit used the actual implemented helper bodies, rather than substituting trusted frozen bodies without checking them:

1. Parsed the 21 named ranges from the brief and located the inserted block directly before `@Suite(.serialized)`.
2. Consumed the entire insertion in order. Required each exact `private func NAME() async throws` signature once, its closing brace/separator, and no extra inserted bytes.
3. Extracted each actual body, restored four leading spaces on nonempty lines, and compared it byte-for-byte against its specified frozen inclusive range. All 21 matched.
4. Removed the insertion and expanded each actual body at its exactly-one direct `try await NAME()` call. Verified all 21 calls occur in the original 069 test in the prescribed order.
5. Compared the reconstructed entire file to the preimage: exact equality and reconstructed SHA-256 `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`.
6. Independently applied all three saved unified-diff hunks to the frozen file in memory, validating every context/deletion line and old/new hunk length. The result exactly equals the reviewed postimage and its hash.

The audit exited 0. Its inventory was:

| Property | Independently checked result |
| --- | --- |
| New signatures and sequential calls | 21 signatures / 21 calls, exact names and order |
| Registered tests | 10 before / 10 after; exactly one original 069 identity |
| Serialized suite | Exactly one, unchanged |
| Expanded 069 assertions | 438 `#expect` / 5 `#require` |
| Expanded 069 marker sites | 10 stage / 6 case strings |
| Kept caller spans | Frozen 8650–8685, 8825–8920, 8922–8933, 9560–9589 all exact |
| Failed-removal retained-count check | Original `snapshotCount() == 1` remains exactly once |
| All other source bytes | Exact after removing only the approved insertion and expanding its calls |

Both 065 tests are independently unchanged. For a reproducible supplemental hash, the exact 23,370-byte span beginning at the four leading spaces before `@Test func p1f1_065CancellationCleansProcessAndCommitsOnce` and ending immediately before the four leading spaces before `@Test func p1f1_066UsageCostAndOverflowMatrix` has SHA-256 `c0330a8291412e8cf345656f5acc93da73ff52c59d7e73069751b460d5b65064` and occurs once unchanged in the postimage. This explicitly bounded span is independent of the implementer's differently reported combined-065 digest; whole-file reconstruction establishes preservation without depending on that report digest.

## Spec compliance and code quality

The actual implementation uses direct, readable file-private functions and adds no abstraction, concurrency, global state, parameters, compiler attributes, catches, retries, conditional skips, or teardown. The caller still expresses scenario order and keeps stage prints at their original logical boundaries. All complete case loops, diagnostics, assertions, cleanup, and timing policy are preserved inside their corresponding helpers.

The three whole-test guard returns remain in the caller at current lines 9503, 9587, and 9661. The exact-live-CLI guard remains inside its original complete false/true loop at current line 6868, retaining `continue`. Callback-local guard returns/throws retain their original lexical targets. Exceptions from helpers propagate directly through `try await` to the original test.

The approved lifetime boundary is implemented exactly: local fixtures can release at helper return after their existing scenario observations, while existing per-iteration defers stay inside the original loops. Task/claim joins and callback captures are byte-equivalent to the preflight-reviewed versions. The known unjoined probe-recording tasks retain their own probes/events; the wiring tasks keep their original loop boundary. There is no added early return, split join, cross-group local reference, or resource use after a newly shortened boundary. The intentionally retained failed-removal registry entry remains after both original task/waiter joins at current line 6716; it was not erased to manufacture a clean state.

These findings satisfy the bounded test-only decomposition brief. Existing expected-failure catches and fixture cleanup behavior are unchanged; this review does not endorse unrelated pre-existing behavior or claim production ownership was re-audited.

## Diagnostic evidence and remaining gates

Read the parent's `runtime-coro-split-ir-metrics.log`: the original 069 caller is now 4,961 IR body lines / 62 suspension sites, and the largest new helper is 4,533 / 101, compared with the frozen 216,814 / 747 cost center. This supports the intended decomposition; it does not establish normal object compilation or runtime correctness. The parent reports the bounded pre-LLVM invocation completed with exit 0 in 14.05 seconds and stable headroom. This reviewer did not rerun it or independently sample its process.

Normal monitored compilation and focused execution of both 065 cases plus 069 remain required. The unresolved halt/readiness work and authoritative full `swift run RunTests` remain separate gates. This source approval permits the next planned verification step; it is not runtime acceptance or permission for packaging, release, or commit.

Only this review artifact was written. No source modification, compiler/test invocation, sampling, process signal, App operation, subagent, or commit was performed by this review.
