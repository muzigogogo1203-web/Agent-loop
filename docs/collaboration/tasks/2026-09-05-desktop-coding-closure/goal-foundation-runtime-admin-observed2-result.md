# Second administrator diagnostic — captured evidence, runtime gate still RED

2026-09-08 recovery checkpoint for the completed 2026-09-07 run. **Not a runtime repair, A1 acceptance, A2 entry, or product delivery.** The single renewed authorization was consumed. No additional authentication, workload, or sampling is authorized by this result.

## Completed launcher correction

The diagnostic selector now replaces its shell bridge with `exec`; the runner requires the exact direct osascript parent generation rather than expanding a shell-image allowlist. The ordinary-only regression failed before the correction (PID33547, exit1, observed `/bin/bash` bridge) and passed afterward (PID34207, exit0, exact direct parent). Both runs joined their owned dummy/osascript processes and observed the selector absent; neither ran administrator statements, RunTests, or sampling. The runner also records caught main errors immediately before bounded cleanup.

Only the two diagnostic launcher files changed, with one new ordinary regression, all in this task directory. The frozen three-file diff is `goal-foundation-runtime-admin-attempt2-implementation.diff`, SHA `f3e1067dbb0e2fb3b1206f50745ddb1521c7d460fb801ae8500ab5e1700d84ea`. Root fully read the independent implementation review, SHA `7369e519ef0f8a5a648c49692f90a229a6c13a0b27ee8907ea07f86427aacf67`, before the one renewed invocation. The consumed observed1 record and preimages remain unchanged.

## Actual execution and evidence

`goal-foundation-runtime-admin-observed2-location.json` identifies the retained private run directory:

`/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-admin-goal-foundation-runtime-admin-observed2-20260907-34931-1glsvj9`

Outer `goal-foundation-runtime-admin-launch2-process.jsonl`, `-stdout.log`, and `-stderr.log` retain the fixed command, pins and actual exit. The collector PID34931 requested authentication at01:10:29.758406 +08. Exact selector PID34972 was admitted at01:10:36.232259; ordinary-user workload `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests` started at01:10:36.234975 and ended at01:12:11.395874. The workload exec generation is PID34975/start1788714636.236924. Test and collector exited1; observer34977 and osascript34939 exited0. No diagnostic TERM/KILL was used.

Full test result: **1130 tests /33 suites /92.866 seconds /5 parent issues /exit1**. These are four failing parent tests, not five failing tests:

| Parent test | Issues | Retained `test.log` evidence |
| --- | ---: | --- |
| `rateLimitTriggersGlobalCooldownThenRecovers` | 2 | lines1501/1724: `blocked` and `done`; failed46.554s |
| `emergencyStopCancelsRunningBeforeWaitingForPlanner` | 1 | line1626: cancellation not observed before the fixture deadline; failed50.281s |
| `emergencyStopHaltsDispatchAndResumeContinues` | 1 | line1645: `done`; failed37.678s |
| `cliProcessBackendFinishesWithinGraceWhenGrandchildHoldsPipe` | 1 | line2284: mechanics watchdog plus cleanup certainty error; failed65.503s |

The sampled CLI347 is `cliProcessBackendFixtureFailureStillJoinsRealCleanup`, which actually **passed67.105s** (line2333) in this run. CLI346 is `cliProcessBackendCancellationEscalatesAfterGrace`, passed67.417s (line2340); CLI372 is `cliProcessBackendCancellationReturnsCheckedEvidence`, passed66.790s (line2323). The exact test-to-fixture mapping comes from the pinned same-run source, not nearby test-log ordering. Independent timeline review corrected the initial checkpoint's mistaken347/346 test-name mapping. The nested deliberate-failure and isolated FD-growth controls produce red child output, not extra parent failures. Root retains the full log instead of using a filtered pass as acceptance.

## What the target text stack establishes

The selected CLI347 child is PID35430/start1788714703.497530, PPID34975, UID501, PGID35430, `/bin/sh`, fixture `c-347-201D`. Two pre-capture selector observations were valid/quiet with zero user time, syscall/fault counts and pipe bytes. The fixed privileged spindump PID35445 sampled this target with:

`/usr/sbin/spindump 35430 1 100 -onlyTarget -timeline -timelimit 10 -noFile -noBinary`

The returned text report has one process-stack subsection, `sh [35430]` and its one thread (lines52–84). It also includes host metadata/locales, Kextstat and a WS frame-rate appendix: do not describe every byte of the text as target-only. The target subsection's01:11:44.098–01:11:45.099 +08 window contains10 samples at100ms spacing in `AppleSystemPolicy::evaluateScript` / `waitForEvaluation` / `ASPEvaluationManager::waitOnEvaluation` / `lck_mtx_sleep`. This identifies a system script-evaluation wait **during that sampled window**. It does not establish the policy service's reason, the entire startup delay, a product defect, or the cause of every historical/current failure. The target subsequently progressed and its same-run test passed. The independently checked same-run timeline establishes readiness success in2.688898542s, TERM→KILL62.227208ms, KILL→waitpid0.736167ms and complete checked cleanup; its actual owned-launch-to-stream interval was2.779603375s, not67.105s of script evaluation.

Spindump exited0 after approximately14.545s; the framed transport records complete stdout/stderr, no deadline-expired or cleanup-incomplete flag. The target was already absent at the post-capture query (`ESRCH`), so post-generation equality was unavailable, not fabricated as confirmed. Transport success is explicitly not overall scope/privacy acceptance.

## Unexpected extra diagnostic file — unresolved scope deviation

The tool's stderr says that its own stuck-processing diagnostic wrote:

`/var/tmp/spindump-stuck-stackshot.2026-09-07-01:11:53.35445.buf`

This occurred despite the fixed `-noFile -noBinary` argv. Its automatic warning says “over a minute,” but the measured tool duration was approximately14.545s; the warning is not elapsed-time evidence. The local manual does not establish the scope of this automatic buffer. **Do not infer that `-onlyTarget` constrains the extra file.**

Only metadata was inspected and retained in `goal-foundation-runtime-admin-observed2-extra-file-metadata.json`: regular file, UID0/GID0, mode0644,2,639,968 bytes, inode345640665, mtime2026-09-07T01:11:53.697060619+08. Its contents were **never** read, decoded, copied, or content-hashed. Its generation was an unapproved side effect, not an approved second capture. Overall diagnostic scope/privacy cannot be declared GREEN. The ordinary collector's empty error list does not erase this external side effect.

On09-08 the user explicitly replied “允许，仅删除这个文件” to one local administrator confirmation solely for this exact file. Root revalidated the non-symlink regular-file inode/size/UID/GID/mode/device/mtime and root-owned sticky parent `/private/var/tmp`, both ordinarily and inside the fixed privileged command. One exact `File.unlink` removed it; osascript21454 exited0 without a signal at22:05:49.434366 +08, and both privileged and ordinary postchecks returnedENOENT. No other file or setting was changed, and no test/sample was rerun. The file was not moved to Trash; no recoverable copy was created. Evidence: `goal-foundation-runtime-admin-observed2-extra-file-cleanup-location.json`, `-result.json`, and their retained raw request/stdout/stderr/result. Cleanup resolves retention of that exact extra file, **not** the original scope violation or unknown collection contents. This deletion-only authorization is consumed; no further administrator action is implied.

## Integrity, cleanup and remaining gates

- `source.sha256` and `source-after.sha256` each contain305 build inputs and SHA `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`; this manifest was also verified on09-08. All pinned diagnostic inputs remain unchanged.
- Native observer exited0. OSLog capture exited0 with2062 admitted exact-parent/runtime-category events, zero rejected events and matching count/finished metadata. This captures known scope; it does not describe the uninspected extra buffer.
- `goal-foundation-runtime-admin-observed2-post-identity.json` records the ten observed task-owned process identities subsequently absent with BSD errno3, including target/fixture children and diagnostic processes. Direct-child waits and nondirect-process absence remain distinct. No residual process is inferred solely from a historical PID.
- No product Sources/scripts/Package, real camp data, installed App, Provider, security setting, git index/commit, or release was changed by this diagnostic continuation. Prior strict App success is separate evidence, not package or live-App acceptance.
- Independent scope/evidence, same-run CLI timeline and HALT analyses are complete and were fully read by root. Their accepted findings and remaining gates are below. No additional default full rerun merely seeking GREEN, no further privileged sampling, and no speculative signal/timeout/concurrency change.

## Independent closure and the next bounded scope

Root fully read all three reports and checked their final hashes:

| Report | SHA256 | Ruling |
| --- | --- | --- |
| `goal-foundation-runtime-admin-observed2-evidence-review.md` | `475482d8828e68db1c05aee7d953cd8edcd8225abfdebcc610a2994c5440a95c` | Bounded target stack, transport, identities, cleanup and exact deletion accepted; overall capture scope/privacy WITHHELD: P1 extra buffer, P2 host/report appendices. |
| `goal-foundation-runtime-admin-observed2-timing-analysis.md` | `df4ff35ea74256dda8678c6392d5bc0e8c52de0077a575edf2b54cee271e50f1` | Correct347/346 mapping and same-run success; original/current failures are not universally attributed to the sampled wait. |
| `goal-foundation-runtime-admin-observed2-halt-analysis.md` | `cd95c610c169a674a7ebd0913b6581821ed81cdcc6a15b29ace0923c889ddd90` |68 exact-owner events establish delayed cancellation progress, not a timely cancellation missed by polling; deeper scheduling/lock cause remains unproven. |

The HALT observer returned false3,877.135ms after wait entry; actual `consumption.cancel()` occurred4,159.617ms after entry and the provider recorded cancellation5,274.794ms after entry. The installed gate's open operation had returned2,202.327ms before its wait returned. State-load1.443ms and cancellation persistence18.067ms do not account for that delay. The one-second requirement is unchanged and unmet. The other two HALT tests' three card-state assertions lack identity-correlated state timelines and remain unresolved.

The separate CLI152 held-pipe failure has11.356053416s before its backend task starts and52.703540667s inside the login-environment call boundary. It finally took a TERM/143 cleanup path, not the intended natural parent exit while a grandchild held stderr. Root inspected the called `LoginShellEnvironment` implementation: it shares a single-flight capture and uses a utility-queue login-shell operation, but there are no internal timestamps here. Do not label the entire52.704s as shell execution or assign it to the captured different process. No product repair follows merely from those source observations.

**Next selected unit, not executed by this result:** independently plan/review diagnostic-only internal cancellation-gate admission/publication/resumption markers, then at most one ordinary focused running-before-planner test under unchanged semantics. It must identify whether delay precedes gate readiness or follows readiness, with exact execution identity and complete output. A missing boundary or non-reproduction stops that experiment with the limitation recorded; it is not permission for another probe or a full rerun. This is not a behavioral-fix plan and does not open A2. CLI152 environment internals and the other card-state traces are separate unresolved work, not bundled into that unit.

The second diagnostic plan now ends with a completed evidence account **with scope deviation**, not successful overall scope acceptance or runtime repair. Reuse of this spindump path remains prohibited without a newly reviewed scope design and explicit sampling authority. Exact-file deletion is complete; no further user action is needed for that file. Product code/data/installed App were unchanged on09-08; the latest source check at22:09:27 confirms305 inputs and the frozen manifest. `git diff --check` also returned0; neither check is a new test run or product acceptance.

| Retained raw artifact | SHA256 |
| --- | --- |
| `process.log` | `7dad5653222ceb738686c5bfe4a2c6900aa57519b06df7bfd56ce0cde9668450` |
| `test.log` | `eab1a8e32ed85991b16661d58eac8c579a582a7a3a15f0410c5c58b48dabf4ea` |
| `observer.log` | `fc2fba19c4a64d6ef149cc13a36c18430a9df17b8c1aed2d9b3e0de3b32f47be` |
| `apple.log` | `533890ef58dfca8733e9552490e9210d4bcb325ea193196e2d3e37470d2534d2` |
| `sample-stdout.log` | `b6540ae83a78af53ba4a399d3b4461d685fbc5751ca0a16b6d5fc3b2ec8f51ce` |
| `sample-stderr.log` | `cc89a6fabcca9aad3721d19c4a916b0554319472b5caf6d38127254bcb56e94b` |
| `events-admitted.ndjson` | `cb5c21ddbd28706643e56af5b650749b0921abd13f8815d9e3f9f0051a8f5dec` |
