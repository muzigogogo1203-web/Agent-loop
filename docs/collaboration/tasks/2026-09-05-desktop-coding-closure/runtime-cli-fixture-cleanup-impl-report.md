# CLI mechanics fixture cleanup implementation report

2026-09-06. Source implementation is ready for parent-owned compilation, focused verification, and a non-implementing review. This report does not claim a passing test or completed acceptance gate.

## Scope and ownership

- Authoritative checkout: `/Users/muzi/Agent-loop`, branch `codex/desktop-coding-closure-20260905`.
- Implementer writes were limited to `Sources/AgentLoopTestSuite/CliBackendTests.swift` and this report. The existing dirty tree was preserved. No production, runner, manifest, Provider, App, or unrelated test edits were made.
- The parent granted exclusive source ownership after all Swift commands ended. The implementer ran no compiler, tests, application, Provider calls, process signals, commit/push, or other agents. Source writer ownership is released with this report.
- Applied the approved executing-plans / test-driven-development workflow with the plan's retained behavioral RED and parent-owned verification boundary. No intentionally leaked RED run was added.

## Frozen evidence

| Input | SHA-256 |
| --- | --- |
| Approved plan, unchanged | `8dbb8ca9f5e25198ff3c2dc06f572f342381ecbffba451b04aac549fac41a421` |
| Source at writer entry and retained `runtime-cli-fixture-cleanup-before/CliBackendTests.swift` | `81e1ac4fe968b3e485b054318d64f188ae98f3a60e0192f25865c6477dcd93fd` |
| Source after implementation | `74c53a9b1769db189663d65d595b0c8d9279f9e58a71af687df053953498e933` |

The retained `runtime-owned-test-cleanup-verified.log` is the behavioral RED: completed test execution left the `c-346-B200` shell PID 10332 orphaned; the parent rechecked its start time and group and also rechecked the older `c-346-D502` / PID 78055 and `c-346-EBF7` / PID 85371 residues before removing those three exact shell processes. This implementation did not rediscover or signal those historical identities. They provide evidence of an abandoned failure path, not current cleanup authority.

## Implemented behavior

1. Converted only the two named cancellation tests and the grandchild-held-pipe test to `cliMechanicsRunOwned`. `backend.launch(request)` registers synchronously before the consumer task exists. The body result is retained, one cancellation task/result is reused even if it fails, and the uncancelled consumer is joined before a report returns. The report contains the actual stream result and the original body error object.
2. The recorder stores the consumer's real terminal result. The old recorder `finish(error:)` / `failure()` and the generic `StreamCompletion` had no remaining callers after these three conversions, so they were removed locally; stream-failure assertions now inspect the joined report's actual failure.
3. Each inspector records only successful real SIGCONT sends to its existing process group, under its existing lock. It does not derive identity from the broad child snapshot list. New cleanup observations require exactly one positive continued PID, equality with successful cancellation PID/group evidence, PID/group absence through signal 0 and ESRCH, non-consuming `waitid(P_PID, ..., WEXITED | WNOHANG | WNOWAIT)` and ECHILD, and checked socket `lstat` and ENOENT. Only EINTR from waitid is retried. Every failed observation includes operation, execution ID, PID when known, return value, and errno.
4. Cleanup classification preserves body, cancellation, and stream failures separately. Only an exact same-execution `processNotRegistered` can be classified as a completed-stream race after all resource observations pass and the joined result matches the test's permitted terminal result. The grandchild test alone permits the actual `pipeDrainIncomplete` stream failure. Missing cancellation or exited evidence cannot pass the cancellation tests.
5. All four tests begin with checked setup cleanup enabled, disable fixture removal immediately before launch, and re-enable it only after independent resource observations pass. Their defers report actual checked-close/removal errors, or explicitly retain the fixture path. `removeChecked()` attempts both socket-authority close and exact fixture removal and retains both errors; the existing `remove()` API and its unrelated callers remain unchanged.
6. Added `cliProcessBackendFixtureFailureStillJoinsRealCleanup` with previously unused identity `347`, real staged `/bin/sh`, and the escalation test's exact TERM-ignoring command and grace values. Its body waits for real stdout readiness, verifies the live positive PID and self-owned group, then throws `.afterReady` without requesting cancellation. Before accepting that marker, it requires actual TERM/KILL/reap/EOF evidence, the joined exited frame, successful independent observations, and no cleanup failures. An earlier readiness error remains the primary failure. Additional verification errors preserve that primary inside the aggregate.
7. Focused logs will include only the fixture's execution ID, actually continued PID list, fixture path, and resource-observation failure count. No tokens, environment, argv payload, or broad process dump is logged.

## Preserved contracts

- The existing three shell commands, harness/request construction, successful-path evidence/socket/signature checks, and cancellation-test login-environment prewarming are preserved.
- Readiness remains three seconds with the same 20 ms polling semantics.
- Grandchild watcher remains 200 iterations with 10 ms sleep; drain grace remains 50 ms. Its timeout is now a retained typed error followed by owned cleanup.
- Escalation remains 50 ms termination / 1 s kill / 1 s drain; checked-evidence remains 1 s / 1 s / 1 s.
- There is no consumer cancellation shortcut, test-side termination signal, global process kill, cancellation retry, liveness polling, production seam, timeout expansion, or suite serialization.

## Verification and remaining gates

Implementer static verification: `git diff --check` exited 0. Reviewed the scoped diff against the frozen preimage and reconfirmed its SHA-256 and the unchanged plan hash. Compilation and runtime behavior are intentionally unverified by the source writer.

Parent must now run the approved commands with complete uniquely captured stdout/stderr and real exit codes:

```text
swift run RunTests --filter cliProcessBackendFixtureFailureStillJoinsRealCleanup
swift run RunTests --filter cliProcessBackendCancellation
swift run RunTests --filter cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe
```

Then check the new exact PID/execution identities for surviving fixture processes and obtain review of the source diff and complete logs from an agent that did not implement this change. No fixture cleanup or focused pass alone is full-suite acceptance.

The full gate remains red under the separately recorded host memory pressure. This test-only ownership repair does not diagnose the three-second readiness miss and does not make the production completion join independently hard-bounded. If joining hangs or observations cannot prove resource absence, preserve the specific evidence and fixture path and stop at that boundary; do not add an unjoined escape or guessed process authority.
