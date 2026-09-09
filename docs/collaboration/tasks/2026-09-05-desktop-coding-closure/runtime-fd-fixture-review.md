# Independent review — 075 FD fixture repair

Verdict: **changes requested: 0 P0, 0 P1, 1 P2**. The descriptor-ownership correction is sound on static inspection, but one required child-evidence path is lost. This is not runtime acceptance. The authoritative full gate remains red from the retained preimage guarded-FD crash; compilation, focused tests and the complete unfiltered suite remain the parent's responsibility.

## Reviewed boundary

- Compared the entire `Sources/AgentLoopTestSuite/CliBackendTests.swift` against `runtime-fd-fixture-before/Sources/AgentLoopTestSuite/CliBackendTests.swift`, including every diff hunk and surrounding caller/closed-stdio flow.
- Preimage SHA-256: `00b67a409c35c3fe10b2c2d8cb1c0bff71c64ac7288fb0eaa08e1a75528793de`.
- Reviewed postimage SHA-256, unchanged at end of source inspection: `4c9584f678f166d5c733619959b230313a4394785cf582de07c42a0c1d646012`.
- Read the diagnosis, approved implementation plan, plan review, task implementation report, existing self-exec helper and frozen runner entry point. Applied the independent code-review guidance. Existing unrelated dirty changes were left untouched.
- `git diff --check -- Sources/AgentLoopTestSuite/CliBackendTests.swift` passed. No build, test, app launch, source edit, commit or subagent was performed. The only reviewer-written artifact is this report.

## Finding

### P2 — Nested closed-stdio composition deletes child evidence after emitting it to `/dev/null`

Location: `Sources/AgentLoopTestSuite/CliBackendTests.swift:3481–3485`, with callers at `3920` and `3945`, and existing stdio routing at `2209–2224`.

The ordinary 075 invocation first runs its composition, whose new drain child correctly emits complete diagnostics into the top-level retained output. It then calls `p1f1d075RunClosedStdioSubprocess`. That existing helper self-execs another 075 runner with all standard streams opened on `/dev/null`. The nested runner still executes `p1f1d075AssertR9DCompositionContract()` at line 3920 before checking the closed-stdio mode, so it spawns another drain child. That new child itself has a good exclusive log, but its owner emits the log, PID/raw status and phase bytes to the nested runner's `/dev/null` stdout and immediately deletes the original fixture directory. Thus a successful write is mistaken for durable parent evidence, and the top-level retained output contains neither this second child's PID nor its full log/phase bytes. On failure, the child directory survives, but its reported path and PID are also swallowed by the nested runner's output sink; the outer helper exposes only its generic status error.

This violates the plan's requirement to retain the complete child diagnostics before successful deletion and to extract lifecycle events for recorded child PIDs. It does not invalidate the first child's correctly retained output or prove a resource safety failure.

**Concrete correction agreed with the parent during review:** after the FD-mode early-return branch, determine the existing `closedStdioFixture` flag before composition and invoke composition only when `!closedStdioFixture`. Keep the closed-stdio self-exec helper, its test body and every assertion unchanged. The nested composition currently runs before `p1f1d075CloseFixtureStandardDescriptors()` at line 3983, so it contributes duplicate ordinary-environment coverage, not closed-stdio coverage. The ordinary parent continues executing all composition phases 0–9, including exactly the three isolated drain helpers, and its child evidence is retained. The separate closed-stdio runner continues its real help/capability probe after closing its standard streams. This one guard is preferable to adding another log transport/ownership mechanism solely for redundant composition. Record the removal of duplicate composition as an explicit plan adjustment; it does not waive a unique assertion or relax a deadline. This recommendation is assessed statically; the reviewed source hash above does not yet contain the guard.

## Checks without additional findings

- Early environment routing validates a known child mode and absolute evidence path, then returns before composition/help/closed-stdio recursion. A drain child executes exactly the three original helper calls, in their original order; an expected-failure child throws before running them or writing markers.
- Vacant-slot acquisition uses atomic `F_DUPFD_CLOEXEC`. A collision closes only the newly acquired descriptor, never the occupied target. Source-equals-target ownership and sentinel teardown remain intact. Source closure failures preserve the primary error, and the regression owns both original descriptors and checks both remain valid.
- Spawn setup uses checked `POSIX_SPAWN_CLOEXEC_DEFAULT`, checked initialized attributes/actions destruction, one exclusive `0600` log open description duplicated to both child outputs, and a log FD normalized above stdio. Parent log ownership is consumed once before close; post-spawn resource-release errors enter owned-child cleanup.
- One named native thread owns each direct child and resumes its checked continuation exactly once. Cancellation does not abandon cleanup. The whole-child watchdog is 15 seconds and does not alter the original helper deadlines.
- All waits/signals target the exact spawned PID. Successful reap and `ECHILD` clear signaling authority. Unexpected wait errors enter checked cleanup; a failed ownership reconfirmation surfaces unresolved ownership rather than signaling blindly. Kill/reap failures are retained with the primary failure.
- For the normal top-level path, nonzero child status is rejected before marker acceptance, exact phase bytes are checked, and checked complete log/evidence output precedes deletion. Read/output errors retain the directory. The real expected-failure regression requires both nonzero status and `deliberateChildFailure` in the actual child log; an aggregate cleanup failure cannot pass as the expected error.
- The live-drain and surviving-group helper bodies are unchanged. Original output, EBADF, stop count, worker count, reap count, process-group failure and four-second assertions remain. The repeated-finish `managedPolicy` and sentinel-survival assertions remain. Composition phases 0–5 and 9, plus existing 075/079 closed-stdio behavior, were not weakened by this diff.

## Next gate

Address the P2 evidence transport gap and obtain review of the resulting delta. Then the parent must verify focused allocator/failure propagation, original 075 execution, and the unfiltered authoritative `swift run RunTests`, retaining actual exits and full output plus lifecycle events for every recorded parent/child PID. No static verdict or focused pass substitutes for the full gate.

## Fix 1 scoped rereview — P2 closed

**Current verdict: source review approved, 0 P0 / 0 P1 / 0 P2.** This supersedes the initial changes-requested verdict above for source SHA-256 `81e1ac4fe968b3e485b054318d64f188ae98f3a60e0192f25865c6477dcd93fd`.

Verified that the FD child early-return branch remains first, followed by the existing closed-stdio flag and exactly the approved `if !closedStdioFixture` composition guard. The ordinary invocation retains all composition phases 0–9 and emits its isolated child's evidence into retained parent output. The closed-stdio invocation now reaches its original body without spawning the redundant child; standard-descriptor closure, actual help/capability probes, their assertions and all deadlines are unchanged.

A read-only in-memory reversal of this one guard change reconstructed SHA-256 `4c9584f678f166d5c733619959b230313a4394785cf582de07c42a0c1d646012` exactly. Thus no other source bytes changed since the full review. `git diff --check` passed. The implementer's appended Fix 1 report records the explicit plan adjustment.

The evidence-loss P2 is closed. No new findings. This reviewer performed no source edits, builds, tests or app launches. Focused and full runtime gates remain parent-owned and must be reported from their retained evidence; this approval does not declare suite acceptance or authorize commit/release.
