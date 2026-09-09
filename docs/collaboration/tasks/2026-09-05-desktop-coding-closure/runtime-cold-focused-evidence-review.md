# Independent review of retained 065 focused cleanup evidence

Decision: **PASS for the historical focused cold-cleanup repair gate at the reviewed coroutine-split test revision.** Both required 065 tests actually compiled and ran, and both logged complete identity-bound cleanup certificates. The forced path preserved its deliberate primary error while completing cancellation and stream join. This closes the pending focused-evidence requirement of the cold-cleanup/Fix 1/Fix 2 source reviews for that run. It does **not** accept the final ongoing CLI repair revision, diagnose the original readiness delay, or clear full-runtime/product acceptance.

## Exact artifacts and execution

Read the complete 98-line `runtime-coro-split-focused-065.log`, complete five-line `runtime-coro-split-focused-process.txt`, complete 25-line `runtime-coro-split-focused-resources.log`, complete `runtime-cold-gate-cleanup-plan.md`, `runtime-cold-gate-cleanup-review.md`, `runtime-cold-gate-fix1-review.md`, `runtime-cold-gate-fix2-review.md`, and `runtime-coro-split-review.md`. Inspected the frozen forced-path source and verified the historical preimage/diff hashes below. Filenames were resolved from the actual task directory.

The retained command is `swift run --jobs 2 RunTests --filter p1f1_065`, owned process PID 50828, started 2026-09-06 03:56:36 and ended 03:57:21, actual `EXIT_STATUS=0`. Log lines 1–27 show normal debug compilation and linking, completed in 24.78 seconds. Warnings remain visible; there is no compilation error. The ordinary 065 test passed in 12.175 seconds and the forced-failure 065 test passed in 5.522 seconds; final discovery/result is exactly **2 tests in 1 suite**, passed in 17.702 seconds. This is runtime evidence, not a zero-test build or a source-only review.

| Artifact | SHA-256 verified in this review |
| --- | --- |
| `runtime-coro-split-focused-065.log` | `b6d77bf4be4f4e83d2626a9ac881ba7719d8ce3f0055a7ed15fd74dea876d46d` |
| `runtime-coro-split-focused-process.txt` | `a3a03072731bd6d290055a1c8f169c189aa1aa999c4d4c6d1e80d46d66e30953` |
| `runtime-coro-split-focused-resources.log` | `018da0607a33b57370d803d45839eb39cce1eadb8810824f91eac1bd912e7c50` |

## Actual cleanup certificates

| Certificate field | Ordinary cold branch | Forced post-readiness error |
| --- | --- | --- |
| Fixture UUID | `8B3C2F02-8E7F-4232-8CC2-C013969926BA` | `4DD0FAAD-AFF8-40CA-8D19-C013E58354D7` |
| Execution ID | `00000000-0000-4000-8000-000000000065` | `00000000-0000-4000-8000-000000000865` |
| Exact root recorded | `/tmp/al65-gate-cf61dcaf` | `/tmp/al65-cold-error-c305e2aa` |
| Successful SIGCONT identity | signal 19, group 50884, target -50884, result 0/errno 0; count 1 | signal 19, group 50887, target -50887, result 0/errno 0; count 1 |
| Subsequent signal sequence | TERM 15, KILL 9, same group/negative target, both result 0/errno 0 | TERM 15, KILL 9, same group/negative target, both result 0/errno 0 |
| Cancellation result | success, pid=group=50884, status 137 | success, pid=group=50887, status 137 |
| Cancellation flags | term, kill, stdoutEOF, stderrEOF, childReaped all true | term, kill, stdoutEOF, stderrEOF, childReaped all true |
| Real stream join | success, decoded exited status 137 | success, decoded exited status 137 |
| Signal-zero PID/group absence | both result -1/errno 3 (`ESRCH`), passed | both result -1/errno 3 (`ESRCH`), passed |
| Non-consuming child observation | `waitid(WEXITED|WNOHANG|WNOWAIT)` result -1/errno 10 (`ECHILD`), passed | same result/errno, passed |
| Exact socket observation | `lstat` result -1/errno 2 (`ENOENT`), passed | same result/errno, passed |
| Registry | activeCount 0 | activeCount 0 |
| Final certificate | `cleanup-certified=true retained-root=none` | `cleanup-certified=true retained-root=none` |

Each sequence consistently binds the fixture UUID and execution ID to the observed successful continuation target, then to the actual cancellation PID/group and joined decoded exit status. There is no need to infer process identity from timestamps or reuse a historical PID. All six certification categories required by the plan are present for each fixture. The final certificates authorize the checked teardown path; the passing tests contain no reported defer-close/removal issue. This reviewer did not access or probe the historical roots/PIDs and does not claim a fresh filesystem/process observation.

## Forced primary preservation and review chain

The forced fixture logs `readiness-end observed=true successfulContinuations=1`, followed by `body-error category=forcedFailure.afterReady`, **then** cancellation start/result, actual stream join and full certification. Frozen source at the coroutine-split preimage retains the guard requiring `(assessment.primary as? P1F1D065ColdForcedFailure) == .afterReady` and `assessment.cleanupFailures.isEmpty`; otherwise it throws the aggregate. The post-cleanup checks additionally require TERM/KILL evidence, matching positive PID/group, signature sequence `[.cli, .boardBridge]`, and exited-frame evidence. Consequently its pass is consistent with the exact expected primary surviving cleanup; it is not a generic catch accepting arbitrary readiness/cancel/stream failure. The ordinary test remains a passing success path and would fail on a body primary.

Historical scope chain, with stored file/diff hashes rechecked here:

- Cleanup preimage: `cf4c84f2fe5c60bf527db60f48d699539208eb6fb4b86b2f330ca18506ffc75f`.
- Cleanup source / Fix 1 preimage: `404db276fd96e1a69ba30763dccbc09ae8ee42b62f1744a3d5b3916584d11716`. Initial cleanup review requested the successful-SIGCONT-publication ordering fix; it otherwise approved owned cleanup, error preservation and certification.
- Fix 1 diff: `be481f5f33ccf4bc77f6aea55a2ed89b0a09c7911a1374a1e5440f9085380a69`. Fix 1 source / Fix 2 preimage: `ce476a5f42732d61983eb405bb35db8337cf45d988cb463a2dfd127fbd6012bb`. Its independent re-review marked the publication race addressed without changing the original three-second deadline or ten-millisecond sleep.
- Fix 2 diff: `3420fc97e743269c487b105d74dd677dc3bd9bb1ac9dd107834aa5d0ea03509e`. Fix 2 source / coroutine-split preimage: `a4d4e488a512aa587e4cb23980edc0fe94a5ebc2a3ded5096e6488f4dfe8478a`. Its source review independently proved the three explicitly typed Bool bindings preserve the original required predicates and ordering. The successful ordinary compilation in this retained run supplies the previously missing compiler evidence.
- Coroutine-split review identifies its compiled reviewed postimage as `e5a3ce4fae3ae1c0487ffe3c62b43360f49c7c6ef49ddf1d2d2538397ca2380e` and independently reconstructed the complete preimage byte-for-byte. It proved both 065 tests were unchanged by the 21-helper 069 decomposition.

As a supplemental current read-only check, this reviewer extracted the exact 065 span from the frozen coroutine-split preimage and current test source, from the leading spaces before the original 065 `@Test` through immediately before the 066 `@Test`. The spans match byte-for-byte: **23,370 bytes**, SHA-256 `c0330a8291412e8cf345656f5acc93da73ff52c59d7e73069751b460d5b65064`. This corroborates the prior split review's exact 065 proof even after subsequent 069-only diagnostics/assertion work. It does not validate any production code being edited concurrently by the exclusive writer, nor substitute for executing the final compiled revision.

## Resource boundary and remaining acceptance limits

The retained resource snapshots show pressure level 1 throughout, available disk from 14,633,716 to 14,627,456 KiB (about 13.95 GiB), and unchanged swap used at 18,317.50 MiB. The two sampled compiler RSS values are 431,856 and 318,208 KiB; the later sample shows RunTests under the same owned parent PID. These observations support this bounded compile/run having proceeded within its recorded resource margin. They are discrete RSS snapshots, not a continuous peak physical-footprint measurement or permission for unrestricted full-suite work.

This focused gate demonstrates the known cold-stream lifetime repair on the original success path and the real forced-after-readiness failure path. It does not explain why readiness previously missed three seconds; observed successful readiness now is not causal evidence about that historical miss. It does not prove every production join is bounded, repair every other fixture lifetime, or supply a separate parent-task cancellation-injection runtime test.

The ongoing CLI error-provenance production change requires the parent's planned final-hash 065 rerun and its own review/069 validation. Unresolved halt/readiness investigation and the authoritative full `swift run RunTests` remain independent gates. No full-runtime, package, release, commit or product-stage acceptance is granted here.

Only this review artifact was written. No tests, compiler, source edits, process signals/probes, OS-log extraction, App/DB operation or subagents were used.
