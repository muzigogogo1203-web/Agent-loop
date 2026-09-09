# CLI signal attribution implementation report

2026-09-06. The approved signal/report diagnostics are implemented and exclusive source writer ownership is released. Source-only independent review, compilation, and the later parent-owned combined observation remain pending.

## Frozen scope and hashes

The full 98-line plan and `runtime-cli-signal-plan-review.md` were read. Plan SHA-256 remains `b53902f981f98443d13dddbc8d64bb01569ae74893b4e63c36ba8f06919d181d`. All three sources matched their fresh `runtime-cli-signal-before/` preimages before editing. The plan's old CLI planning hash was not restored; the completed Board runner extraction is retained.

| File | Fresh preimage SHA-256 | Postimage SHA-256 |
| --- | --- | --- |
| `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` | `42ab4d8d418b6ebfc54d7c5d125fa17b0980250754558dbe80387cc9249d03c1` | `a79a0fd1572c9b8934fcce36a3527ded89f0d3bfe81a63c1447e93bb25ba293a` |
| `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift` | `753469a932406c56a0dd696f046acb0c5b6179f56cb0a5a194a737c3efc64154` | `6fb67675a2291443fc2dfdec1212fa9edd2e5c8ecd8fb79b22b2010035ca3323` |
| `Sources/AgentLoopTestSuite/CliBackendTests.swift` | `8dd4c162a666e59ab21180c443d05a0802fdfdca504f59b5fab0b896becf1d80` | `7e1ef3fb5f3b1a37b72cd21c4f0204f3a4aa5be6a0e98b3caec2c4f5f5f54d58` |

Only these three source files and this report were edited. The backend, Board files, shared self-exec mechanics/075 checks, halt task, and all unrelated dirty changes remain untouched. No build/test, OS signal, App/Provider operation, new agent, or commit was performed. The executing-plans workflow stayed within the approved diagnostic boundary.

## Exact source changes

`RuntimeLifecycleDiagnostics` retains its existing opt-in gate, subsystem/category, notice level, and fixed `stage/owner/mono/value` format. It gains only the planned enum cases and `signalWillSend` / `signalDidSend` helpers. A distinct ephemeral UUID is allocated per instrumented syscall only when diagnostics are enabled.

| Signal stage | Value / boundary |
| --- | --- |
| `processSignalPath` | 0 fixture inspector; 1 non-shared registry; 2 shared registry |
| `processSignalTarget` | Exact signed target supplied to kill, preserving group-target sign |
| `processSignalNumber` | Actual signal number, emitted before the existing call |
| `processSignalResult` | Actual syscall result, emitted after immediate errno capture |
| `processSignalErrno` | 0 on successful syscall; captured errno on failure |

`CliMechanicsProcessInspector.send` brackets its one existing `Darwin.kill` and logs only after its existing immediate errno snapshot. The original ESRCH guard and lock-protected successful-SIGCONT continuation record are byte-preserved. Signal-zero observation paths are untouched.

`ShellProcessRegistry.terminateAll` retains its existing locked Set snapshot, clear, unlock, and unsorted iteration. Only the loop's existing kill call is bracketed, still one SIGTERM per entry and with unchanged result/control semantics. The shared-instance comparison is inside the enabled branch, outside the registry lock. Register, unregister, activeCount, and LoginShellEnvironment are unchanged.

The joined `cliMechanicsRunOwned` report hoists the original single `await cancellation.resultIfRequested()` from the return expression into `cancellationResult`. There is still exactly one such await; the exact value is returned unchanged alongside the retained body and joined stream results. Diagnostic fields are emitted before outer tests can throw a readiness/body failure, so a failed readiness path does not discard actual cleanup evidence.

| Fixture stage | Value |
| --- | --- |
| `cliFixtureCancellationState` | 0 no request; 1 actual failure without invented fields; 2 actual success evidence |
| `cliFixtureCancellationPID` | Actual successful cancellation PID |
| `cliFixtureCancellationGroup` | Actual successful cancellation process group |
| `cliFixtureCancellationStatus` | Existing decoded cancellation status |
| `cliFixtureTermSent` / `cliFixtureKillSent` | Actual successful evidence flags, 0/1 |
| `cliFixtureChildReaped` | Actual successful evidence flag, 0/1 |
| `cliFixtureStdoutEOF` / `cliFixtureStderrEOF` | Actual successful evidence flags, 0/1 |
| `cliFixtureExitFrameCount` | Number of actual exited frames in a successful joined stream, including zero |
| `cliFixtureExitFrameStatus` | First actual exited frame's decoded status, emitted only when one exists |

Both fixture field-array construction and exited-frame collection occur only inside the diagnostic gate. No payload/error descriptions, text, arguments, environment values, paths, credentials, or Board tokens are added to logs. No task, actor, lock, sleep, await count, signal count, cancellation call, retry, probe, grace value, test assertion, or cleanup decision changed.

## Static verification and interpretation limits

`git diff --check` exited 0. The full three-file diffs were inspected against the fresh preimages. Registry changes are confined to the terminateAll loop; the CLI diff contains only the inspector signal bracket and joined report emission. The sole cancellation-result await remains visible at its new local assignment. Postimage hashes above were captured after edits.

No runtime outcome is claimed. The parent must independently review this source before the single combined observation, which also waits for the separately assigned halt source review. No standalone full run or repeated observation was started here.

Each signal UUID joins its own path/target/number/result/errno records; its before/after markers bracket a syscall rather than identifying an exact kernel timestamp. Join the signed target to the fixture's actual lifetime through the existing recorder → execution → continued/cancellation PID → Core spawned-PID evidence. A successful path-2 call shows a shared-registry signal attempt to that target succeeded; it does not identify the calling Orchestrator/test or establish sole readiness causation. ESRCH is not successful delivery, and missing logs are not proof no signal happened.

Cancellation and frame statuses are decoded statuses, not raw wait status. In particular, 143 alone cannot distinguish normal exit(143) from SIGTERM. Logging has observation overhead. If the later preserved combined run still lacks attribution, report the exact remaining gap instead of widening scope, selecting a behavior repair, or repeating the full suite. No implementation blocker or material deviation was found.
