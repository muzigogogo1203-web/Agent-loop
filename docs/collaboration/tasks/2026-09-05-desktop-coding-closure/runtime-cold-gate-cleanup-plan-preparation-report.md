# 065 cold-gate cleanup plan preparation report

2026-09-06. Documentation preparation is complete; implementation and runtime acceptance have not started in this lane.

## Deliverables and boundary

- Created `runtime-cold-gate-cleanup-plan.md` in this task directory. Plan SHA-256: `31d584d898287d64201e84c414c71dc57510e498043874586ef32d0f8f04fb0c`.
- Created this preparation report. These are the only files written by this planning lane.
- Authoritative checkout/branch/HEAD verified: `/Users/muzi/Agent-loop`, `codex/desktop-coding-closure-20260905`, `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.
- Read repository `AGENTS.md`, writing-plans and systematic-debugging skills, the full `runtime-cold-gate-analysis.md`, complete original 065 test, relevant 065 fixture/inspector/backend helpers, backend launch/cancel/registration/spawn/finalization lifetime APIs, existing checked CLI cleanup owner/report/resource-observation/error-regression patterns, and the RunTests discovery entry point. A lightweight memory keyword check was followed by current source verification; no historical PID or directory was adopted as current authority.
- No source changes, compilation, test execution, application/Provider use, OS-log extraction, signals, external network operations, agents, commit or push. Read-only static searches and hashes only. Existing dirty work preserved.

## Concrete decisions ready for review

The source allowlist contains only `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`. Original 065 production-signature, injected-signature, pre-registration-abort and main cancellation/terminal-commit branches remain in place, in order, with all assertions. Only the shared gate fixture's teardown guard and original cold segment are converted. Existing unrelated harness teardown callers stay unchanged.

The old eager-consumer CLI lifetime helper is a reference for checked resource observations, not a reusable implementation for this gate. The cold plan leaves `launch` synchronous at the same call site, keeps the original post-launch three-second deadline and throwing 10 ms poll, and starts no iterator before the single actual cancel attempt settles. One explicitly joined detached task captures cancellation and then drains the stream, keeping cleanup uncancelled even when a body sleep throws. Its real results and original body error are retained separately.

Checked removal requires successful actual cancellation evidence, exact successful SIGCONT identity, PID/group absence, non-consuming `waitid` ECHILD, exact socket ENOENT, empty local registry and the real joined exited frame. Any uncertainty retains/reports the exact root. Close failure also retains the root. No process identity is inferred from the broad snapshot list; diagnostic output contains safe fixture identities, signed signal targets, syscall results/errno, readiness Bool, cancellation evidence and decoded exit status only.

The new real `p1f1_065ColdGateForcedFailureStillJoinsCleanup` regression runs in the same serialized suite with its own fixture and unchanged 5 s TERM / 2 s KILL / 1 s drain grace. It throws only after real readiness and live PID/group checks, then accepts that marker only after actual joined cleanup certification. Automatic Swift Testing discovery requires no runner or inventory source edit; the new test count belongs in new verification evidence, not historical log rewrites.

The retained combined-run timeout and traced skipped cleanup are the documented behavioral RED. No unowned failing run is requested. Parent's reviewed entry is one `swift run RunTests --filter p1f1_065` observation after writer release and resource-boundary check, with both original/new test names required in complete output. Full-suite repetition remains outside this plan. A blocked join or failed certification stops the observation without repeated runs or guessed cleanup.

## Static checks and unresolved limits

`git diff --check` completed successfully. The plan placeholder scan returned no matches. These static checks do not compile the proposed Swift snippets and do not establish runtime success.

The following hashes were checked before and after document preparation and remained identical:

| Input | SHA-256 |
| --- | --- |
| ExecutionEngineConformanceTests.swift | `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f` |
| CliProcessBackend.swift | `20d5b42d7b768c6e3eb3f6c3ea770e358d7a328358ba7d1fa9da810a0241ed89` |
| CliBackendTests.swift | `7e1ef3fb5f3b1a37b72cd21c4f0204f3a4aa5be6a0e98b3caec2c4f5f5f54d58` |
| ShellProcessRegistry.swift | `6fb67675a2291443fc2dfdec1212fa9edd2e5c8ecd8fb79b22b2010035ca3323` |
| BoardToolServer.swift | `33f7c9017e86d964e8ffc1ae387820a6aac0bed4543d3eab016af5cd27c5d079` |
| runtime-cold-gate-analysis.md | `e546c7931e0bbffaed1b4ab1cddd4926e3a5749055114dc136755bdc427003ad` |

The startup/file-publication cause remains unknown. The plan does not make production joining hard-bounded, prove every 065 harness lifetime safe, map Board owner identity, or clear the current red full-suite gate. Parent must independently review the plan before implementation; a non-implementing reviewer must review the resulting source diff and actual focused evidence before accepting this repair.

Documentation ownership is released to parent. Source/runtime ownership was never acquired by this lane.
