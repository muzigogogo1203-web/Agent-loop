# Cold gate cleanup — implementation handoff

2026-09-06. Source implementation is complete and **source ownership is released to parent**. This is a static handoff, not runtime acceptance. The independent actual-diff review and parent-owned focused verification remain required.

## Scope and integrity

Only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift` was edited. Existing dirty files, the original signature/pre-registration branches, and the complete main harness body were preserved. No production source, timeout/grace, scheduling, task priority, runner inventory, app, provider, key, network, OS-log, process signal, build, Swift invocation, test run or commit was performed by this writer.

Entry branch: `codex/desktop-coding-closure-20260905`; HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

The exact current source was copied before editing into the freshly created directory `runtime-cold-gate-cleanup-before/ExecutionEngineConformanceTests.swift`. The scoped `runtime-cold-gate-cleanup.diff` compares that dirty preimage directly with the result; it is not a diff against HEAD.

SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Source preimage | `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f` |
| Approved plan | `31d584d898287d64201e84c414c71dc57510e498043874586ef32d0f8f04fb0c` |
| Released source | `404db276fd96e1a69ba30763dccbc09ae8ee42b62f1744a3d5b3916584d11716` |
| Scoped diff | `113e901a068a6ce26d070d7908e67bbf13676ade642acad25ad9b23a9f338924` |

## Implemented behavior

- Added cold-specific, test-private identity, signal-observation, owned-body/report and aggregate-error types. The primary body error object, actual cancellation failure and actual joined-stream failure remain separate. Error rendering uses controlled timeout/forced-marker names or error type names and never renders arbitrary backend/stream error payloads.
- Synchronous launch remains at each call site. Every throwing readiness operation and forced-path assertion after launch is inside the owned body. The helper captures the body result, then creates one detached cleanup task, performs exactly one backend cancellation, and only after that attempt settles begins stream iteration. The cleanup task is not cancelled or raced against an abandonment timeout and is explicitly joined before report return.
- Both inspector kill sites evaluate the existing syscall once and immediately capture return/errno. The original attempt list, injection-gate ordering, accepted ESRCH behavior, polling and thrown errors remain. Only actual successful SIGCONT observations establish the fixture PID. Lock-protected cold diagnostics can be configured once per inspector.
- Both cold paths print safe fixture/execution identity, root, launch/readiness phases, actual signal results, cancellation PID/group/status/TERM/KILL/EOF/reap evidence, stream join and decoded exited status. Final signal snapshots and resource results are printed unconditionally after the join. No payload frames, token, command/argv, stdin, environment or raw error descriptions are printed.
- The nonthrowing assessment independently collects actual continuation identity, cancellation identity/EOF/reap evidence, signal-zero PID/group absence, non-consuming `waitid(WEXITED|WNOHANG|WNOWAIT)` with EINTR-only retry, exact socket `lstat` and registry count, and joined-stream exited-frame evidence. It retains all failed actual cancellation/stream results under separate operation labels. Only a complete six-condition certificate enables checked removal; inability to identify the real child conservatively retains the exact root. Primary body failure does not prevent removal after resource certification.
- Added `removeChecked()` without altering old `remove()` or unrelated callers. The gate root and new regression guard checked close/removal against uncertified lifetime state; checked teardown failures become test issues. The existing gate's prelaunch setup retains checked cleanup.
- Added `p1f1_065ColdGateForcedFailureStillJoinsCleanup`, using its own `cold-error` harness, local registry, normal revalidator/backend, execution ID `00000000-0000-4000-8000-000000000865`, token `8`, and identical cold command. It requires real readiness, one successful SIGCONT, positive PID, matching actual process group and a live process before deliberately throwing `.afterReady`. After the same cleanup certificate it checks actual TERM and KILL evidence, matching positive PID/group, exact signature sequence and exited frame. Any thrown evidence assertion is appended to the aggregate while retaining the original primary. The marker is accepted only when it is the exact primary and no cleanup/evidence failure exists.

## Preserved contracts and static checks

Both readiness loops retain the original three-second deadline and ten-millisecond polling. The original gate still creates its ready URL/deadline immediately after synchronous launch, before invoking the ownership helper. No stream consumer exists before cancellation settles. The gate factory remains byte-identical, preserving default five-second TERM grace, two-second KILL grace and explicit one-second drain grace. No prewarming, priority change, retry or timeout expansion was added.

Read-only Ruby substring comparisons against the exact preimage passed (exit 0):

```text
UNCHANGED: signature and pre-registration bodies
UNCHANGED: cold success assertions and main body
UNCHANGED: gate backend defaults
```

`git diff --check` passed with exit 0 and empty output. The scoped `git diff --no-index --check <preimage> <source>` produced no whitespace diagnostics; exit 1 denotes that the compared files differ. Scoped diff generation likewise exited 1 because changes exist. These are static checks only; no compiler or runtime claim follows.

## Retained RED exception and limits

The parent-approved retained behavioral RED is `runtime-combined-full.log:2314–2315` (`coldGateReadinessTimedOut`) together with `runtime-cold-gate-analysis.md` tracing how the old throw skipped explicit cancellation/join. It proves the unsafe lifetime path was reached. It does not prove a surviving orphan, identify the original cold PID/root, establish a readiness root cause, or authorize present signals/cleanup. No unmanaged fresh RED was run.

The implementation follows the reviewed plan without scope deviations. Diagnostic phase prints are always enabled for these configured cold fixtures, an allowed plan choice. Parent cancellation safety is a construction/review claim pending independent review; no separate real cancellation-injection test is claimed. A stuck production cleanup/join can still block, with the fixture root retained; this code does not create a new hard bound. Other 065 harness lifetimes remain outside scope. Additional forced-path behavioral assertion failures remain test failures even when the independently complete resource certificate permits safe removal.

## Required next gate

The parent must obtain independent actual-diff review, then own the single bounded focused observation `swift run RunTests --filter p1f1_065`, freezing source/plan hashes and capturing complete stdout/stderr and actual exit code. Confirm that both `p1f1_065CancellationCleansProcessAndCommitsOnce` and `p1f1_065ColdGateForcedFailureStillJoinsCleanup` actually run and that identity/resource certificates are present. No test has been run by this writer and no runtime result is asserted here.

A failed/blocked join, uncertified fixture or changed pressure boundary requires retained evidence and bounded diagnosis, not repeated runs or guessed cleanup. The existing full-suite/runtime delivery gate remains red and this test-lifetime work cannot clear it. Independent reviewer acceptance and both focused passes are still outstanding.

## Fix 1 — reviewed SIGCONT publication race

Parent authorized `runtime-cold-gate-fix1-brief.md` after the independent review identified a P2: the child can create its ready file after successful SIGCONT but before the inspector appends that syscall's observation. The new regression's immediate exact-count assertion could therefore fail despite successful readiness.

Only that regression's readiness polling condition and start/end diagnostic state were changed. It now polls until both the ready file exists and at least one successful SIGCONT observation is published, under the same original three-second deadline and throwing ten-millisecond sleep. It then retains the unchanged file guard and exact-one assertion, so duplicate observations still fail and absent publication at the deadline cannot reach the expected marker. Start/end logs include ready-file state and successful-observation count. No task, barrier, timeout, early stream consumer, cancellation or assertion relaxation was added.

Fresh reviewed preimage: `runtime-cold-gate-fix1-before/ExecutionEngineConformanceTests.swift`, SHA-256 `404db276fd96e1a69ba30763dccbc09ae8ee42b62f1744a3d5b3916584d11716`. Fix-only diff: `runtime-cold-gate-fix1.diff`, SHA-256 `be481f5f33ccf4bc77f6aea55a2ed89b0a09c7911a1374a1e5440f9085380a69`. Released fixed source: `ce476a5f42732d61983eb405bb35db8337cf45d988cb463a2dfd127fbd6012bb`. Original preimage, overall diff, report history and review were preserved.

Static verification: `git diff --check` exit 0; scoped no-index whitespace check emitted no diagnostics (exit 1 because content differs). Read-only substring comparisons passed for all source outside the new forced regression and for its post-loop ready-file guard, exact-count/PID/group/live assertions, marker and cleanup. No runtime, Swift, build, test, signal or OS-log action was performed. Fix source ownership is released; scoped re-review and parent-owned original-plus-forced focused execution remain pending. All retained-RED and runtime-acceptance limits above remain unchanged.

## Fix 2 — explicit Bool input at the confirmed macro boundary

The first parent-owned compile exited 1 before any tests executed. The complete 141-line `runtime-cold-gate-cleanup-focused.log` was read and preserved, SHA-256 `8aae063940741b282b46363d04424c5e8b1598a812d38d1460555d2f6b092e64`. It records three new `#require` macro failures: `pid > 0`, `Darwin.kill(pid, 0) == 0`, and `evidence.pid > 0` each expand to an invalid Void-to-Bool coercion. This is actual compile RED, not a failed runtime cleanup observation; neither planned test ran. GRDB comparison/integer-literal overloads are a possible contributing context, not a proven cause.

Under the parent's Fix 2 brief, each exact predicate is now bound to an explicitly declared `Bool` local immediately before its existing throwing required assertion. Predicate semantics and evaluation order are preserved, including exactly one signal-zero probe. The real process-group comparison and all other checks remain unchanged. No helper, import, cast, catch, disabled warning, test skip, timing change or unrelated warning repair was added.

Fresh preimage `runtime-cold-gate-fix2-before/ExecutionEngineConformanceTests.swift` SHA-256: `ce476a5f42732d61983eb405bb35db8337cf45d988cb463a2dfd127fbd6012bb`. Fix-only `runtime-cold-gate-fix2.diff` SHA-256: `3420fc97e743269c487b105d74dd677dc3bd9bb1ac9dd107834aa5d0ea03509e`. Released source SHA-256: `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`. All earlier preimages/diffs/reviews/logs/manifests remain untouched.

Static checks: `git diff --check` exit 0; scoped whitespace check emitted no diagnostics (exit 1 denotes differing files); read-only exact replacement comparison passed, proving the complete source differs by only the three authorized Bool bindings. Source ownership is released. The worker ran no Swift/build/tests/process/OSLog/network/Provider/commit/subagent actions. Parent-owned scoped re-review and corrected compile plus the same two real focused tests remain required. This writer does not claim that compilation is repaired until that compiler result exists. All retained-RED and wider acceptance limits remain unchanged.
