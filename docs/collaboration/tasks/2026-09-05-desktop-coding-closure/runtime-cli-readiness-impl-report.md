# CLI readiness diagnostics implementation report

2026-09-06. The exact approved diagnostics source change is ready for parent review, compilation, and the single paired observation. Source writer ownership is released. No readiness fix or completed runtime acceptance is claimed.

## Scope, preimages, and authority

The implementer read the full 251-line approved plan and `runtime-cli-readiness-plan-review.md`. Plan SHA-256 remains `fc4a3fbce962ff68e9641da15c7644b3f522415c477528a71fe35263d9debb8d`. The three working files matched their parent-created `runtime-cli-readiness-before/` preimages before editing.

| Source | Preimage SHA-256 | Postimage SHA-256 |
| --- | --- | --- |
| `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` | `8512c0a9ec2dc864139688a3595e0ab43e902e5d379607231c8036414ef5282c` | `42ab4d8d418b6ebfc54d7c5d125fa17b0980250754558dbe80387cc9249d03c1` |
| `Sources/AgentLoopCore/Loop/CliProcessBackend.swift` | `f6e5ebff4bba307462edbe2092d10d55e8a50f95005cfc01b007e2590fb4cff1` | `20d5b42d7b768c6e3eb3f6c3ea770e358d7a328358ba7d1fa9da810a0241ed89` |
| `Sources/AgentLoopTestSuite/CliBackendTests.swift` | `74c53a9b1769db189663d65d595b0c8d9279f9e58a71af687df053953498e933` | `0a0821f7f9d283290c6db9b7f7a1723385228a63c7ef34fa0b89a69de5875f7d` |

Only these three source files and this report were edited. Existing cleanup, A4, and other dirty changes were preserved. No compiler/test invocation, OS-log capture/extraction, process signal, App/Provider call, new agent, or commit was performed by this implementer. Executing-plans guided the approved boundary; the plan's failed paired run is retained evidence, without a speculative behavioral change or a new RED run.

## Fixed stage and caller map

All stages are appended to `RuntimeLifecycleStage`; all existing stages remain. Every value below defaults to `0` unless explicitly listed. Core markers reuse the existing `CliProcessExecution.diagnosticId`; `spawn` copies it once to `diagnosticOwner` for workers without retaining self solely for diagnostics.

| Stage | Caller / exact boundary | Value |
| --- | --- | --- |
| `cliRunQueued` | `start()`, before the existing run Task | 0 |
| `cliRunStarted` | First statement of `run()` | 0 |
| `cliLaunchInputsValidated` | After successful `validateLaunchInputs()` | 0 |
| `cliEnvironmentRequested` | Before the existing login-environment await | 0 |
| `cliEnvironmentReady` | After that await returns | 0 |
| `cliEnvironmentValidated` | After the original merge, Board fields, and successful validation | 0 |
| `cliBoardStartCalled` | Immediately before existing `boardServer.start()` | 0 |
| `cliBoardStartReturned` | Immediately after successful Board start return | 0 |
| `cliSpawnPreparationStarted` | First statement of `spawn(environment:server:)` | 0 |
| `cliPosixSpawnCalled` | Before the original executable CString / posix_spawn block | 0 |
| `cliSpawnFailed` | Existing failed-code guard, before the unchanged throw | Actual posix_spawn return code |
| `cliSpawned` | Immediately after successful guard | Actual spawned PID |
| `cliSuspendedValidationCalled` | Before existing suspended-image validation | Actual PID |
| `cliSuspendedValidationReturned` | After successful validation return | Actual PID |
| `cliReapTaskQueued` | Before creation of the existing detached reap Task | 0 |
| `cliReapTaskStarted` | First statement in that same worker | 0 |
| `cliWaitpidReturned` | Terminal non-EINTR result of the original blocking waitpid | Actual syscall return |
| `cliWaitpidError` | Negative terminal waitpid result only | Captured errno |
| `cliStdoutTaskQueued` | Before creation of the existing detached stdout Task | 0 |
| `cliStdoutTaskStarted` | First statement in that same worker | 0 |
| `cliStdoutDrainEntered` | First statement of private `drainStdout` | 0 |
| `cliStdoutFirstBytes` | First original synchronous onData callback, before buffer append | Actual Data count, bounded by the unchanged 4096-byte read |
| `cliStdoutFirstLineYielded` | After the first original stdout yield returns, at either existing yield site | 0 enqueued; 1 dropped; 2 terminated; 3 unknown |
| `cliStderrTaskQueued` | Before creation of the existing detached stderr Task | 0 |
| `cliStderrTaskStarted` | First statement in that same worker | 0 |
| `cliSIGCONTCalled` | Before the existing process-inspector send | Actual process group/PID |
| `cliSIGCONTReturned` | After that inspector call returns | Actual process group/PID |

Fixture markers use one `recorderDiagnosticId` created in `cliMechanicsRunOwned`, passed to the recorder's private initializer, and exposed as immutable `nonisolated let diagnosticId` without adding an await.

| Stage | Caller / exact boundary | Value |
| --- | --- | --- |
| `cliFixtureLaunchCalled` | Before the existing synchronous backend launch | 0 |
| `cliFixtureLaunchReturned` | After that same launch returns its stream | 0 |
| `cliFixtureConsumerQueued` | Before creation of the existing consumer Task | 0 |
| `cliFixtureConsumerStarted` | First statement in that same consumer | 0 |
| `cliFixtureBodyStarted` | Before the existing body await | 0 |
| `cliFixtureFirstStdoutReceived` | First stdout frame returned to consumer, before existing array/actor appends | 0 |
| `cliFixtureFirstStdoutRecorded` | Recorder actor, after the first actual stdout append | 0 |
| `cliFixtureStreamFinished` | Recorder, after existing stored-result/error updates and `didFinish = true` | 0 success; 1 failure |
| `cliFixtureReadyAwaitQueued` | Before existing ready await in both cancellation tests and forced-after-ready regression | 0 |
| `cliFixtureReadyWaitStarted` | Immediately after the unchanged three-second deadline is created | 3000 |
| `cliFixtureReadyWaitEnded` | Deferred marker on every exit from the unchanged wait | 0 expected frame matched; 1 stored stream error; 2 finished without expected frame; 3 deadline without frame/finish; 4 throwing sleep escape |
| `cliFixtureConsumerJoined` | After awaiting the actual uncancelled consumer result | 0 success; 1 failure |

## Correlation, safety, and semantics

- The logger's original environment gate, subsystem/category, notice level, and `stage/owner/mono/value` format are unchanged. The only accessor is read-only `package static var isEnabled: Bool { enabled }`.
- The new identity print is gated by that same accessor and occurs before launch: `CLI readiness identity recorder=<UUID> execution=<validated fixture execution UUID>`. Existing checked-cleanup evidence remains unchanged. No other new default output exists.
- Parent must join recorder UUID → fixture execution ID → actual continued PID from existing cleanup evidence → Core owner UUID from the new `cliSpawned` event. Missing or ambiguous edges remain evidence gaps. Timestamps, ordering, and historical PIDs are not correlation authority.
- No new logged payload contains text, argv, environment, paths, credentials, Board tokens, or error descriptions. Only fixed stage codes, approved identities, actual PID, bounded count, return/errno, and fixed outcomes are added.
- The original reap worker now captures `waitError` directly after waitpid and before any logger call. Its EINTR branch uses that captured value and keeps its existing retry. The same final detail selection, markExited, and result remain; no per-interruption event is emitted.
- Both existing stdout yield calls run exactly once and decode once. Their actual return values supply disposition diagnostics without affecting flow or emitting dropped data. The final unterminated-line site's original `lineBuffer.removeAll()` remains directly after its yield; the diagnostic marker follows that removal. The read function, backoff, buffer size, reads, and EOF behavior are unchanged.
- The same stdout/stderr detached workers now use explicit `return await` because their bodies gained an entry marker. Their lifetime, priority, await, and capture ownership are otherwise unchanged; the UUID value is the only diagnostic capture addition.
- There are no new tasks, locks, waits, sleeps, scheduler yields, retries, signals, cancellation calls, public execution APIs, or correlation registries. No runtime grace or test assertion changed. The three-second deadline and 20 ms sleep, grandchild watcher, checked cleanup path, and joined uncancelled consumer remain intact.
- First-byte time describes delivery to the existing callback after its Data copy, not when the child wrote. Yield disposition does not prove actor receipt. Reap-start to waitpid-return includes the actual blocking wait and existing EINTR loop. Readiness-start follows the real deadline creation; measured marker intervals must not be described as an independent copy of its exact clock instant.

## Verification handoff

Implementer inspected all three scoped diffs against the frozen preimages. `git diff --check` exited 0. Postimage hashes above were captured after edits; the plan hash remains unchanged. Compilation, observed timings, and runtime effect are unverified by this writer.

Parent now owns source-only independent review and exactly one paired observation:

```text
AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests --filter cliProcessBackendCancellation
```

Capture the actual RunTests process identity, run interval, source hashes, exit code, complete CLI stdout/stderr, and complete process-scoped OSLog events. Attribute only exactly joined executions using full monotonic timestamps, and retain cleanup observation results. A failing pair is still useful diagnosis and stays red. If the pair passes with instrumentation, report that outcome and possible observation sensitivity; do not claim this diagnostics-only change repaired readiness or rerun for a preferred outcome. No full-suite run is part of this task.

No implementation blocker or material deviation was found. Completion still requires parent compilation, independent review, and one complete retained identity/timing report. Existing runtime and product-candidate gates remain red until separately satisfied.
