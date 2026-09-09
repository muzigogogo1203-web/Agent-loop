# External child observer observed1 — independent evidence review

Reviewed the complete retained `goal-foundation-runtime-child-observed1-*` evidence set against the accepted bounded observer plan. This reviewer did not author or execute the runner/helper, compile, self-check, workload, tests, OSLog capture, app, Provider, or any process-control operation, and changed no Source.

## Verdict

- Evidence integrity and capture admission: **PASS**
- Per-target identity, sampling, and cleanup joins: **PASS**
- Test failure accounting: **PASS**
- Findings: **0 P0 / 0 P1 / 0 P2**

The evidence is accepted as one complete diagnostic RED workload, not as a repair or a GREEN gate. It supports bounded child-side nonprogress at the observed instants. It does not by itself identify the kernel wait, prove the children remained on their first-observed image, or justify a production change.

## Frozen parent and retained evidence

- `process.txt:317-330` binds launcher PID 97559 to exact test PID 97570. The identity helper returned exit 0/no signal and `/usr/bin/swift`, with PID 97570, PPID 97559, UID 501, PGID 97559 and BSD start `1788709605.172305`; that birth falls inside the recorded invocation-start handshake interval. The observer subsequently required the pinned resolved RunTests image and ended with `image_seen=1` (`observer.ndjson:1126`). All admitted OSLog rows also carry process ID 97570 and the resolved RunTests image.
- RunTests ended at `2026-09-06T23:47:42.811781000+08:00`, exit 1 and no signal (`process.txt:324-326`). Its complete stdout reports a 0.22-second build and a top-level RED run of 1,130 tests in 33 suites, 56.098 seconds, with five issues (`log:1-3,2557`). Diagnostic success did not replace that exit.
- Exactly 305 `before` and 305 `after OK` records are present. Canonicalizing either set produces SHA-256 `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`, exactly the retained `source.sha256`; `source_drift=[]` (`process.txt:637`). The helper source/binary hashes in `process.txt:3-6` match the compile2 and successful self-check provenance: source `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`, binary `10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365`.
- All eight unique raw channels were retained. Identity, observer and OSLog stderr artifacts are empty. Key artifact hashes are: stdout `5588efa78bfd0265430f413f9bb986603757c8b99613009ea84eea6f2691dfea`, process `c19883951426aeef6a0bca13fab0b4a43b09f6080fbff8d03bb6c5134013dc29`, observer `ad16351748b532bfc9f30780323b277defa36416a08cb91c769c7c2d8923c493`, raw OSLog `bd2aae064595cd5459a8a55d5f0e4d9f456f2fffaa13db6e96e6ff4ae1dd05fb`, and admitted OSLog `66e0dc4b62305027540c35f3831de486688ed89c2bd144a4d0e2966dccb847a6`.

## OSLog capture admission

- The raw NDJSON has exactly 2,036 parseable rows: 2,035 event rows and one exact metadata row `{"count":2035,"finished":1}`. The admitted file has exactly the same 2,035 event objects as the raw stream after canonical JSON normalization (both canonical streams hash to `cfcf582e4e1f4668d1828499e67204f231a266fc588af71fcfd98014e6d43ffb`).
- Independently checked all 2,035 event rows: zero PID, subsystem or category mismatches; zero missing/malformed absolute timestamps. The event range `2026-09-06 23:46:49.134841+0800` through `23:47:39.912511+0800` is inside the recorded invocation interval `23:46:45.172001+08:00` through `23:47:42.811781+08:00`.
- Capture was requested at `23:47:43.372719+08:00`; the explicit ten-minute horizon prerequisite is true. Capture exited 0/no signal, parsing succeeded, rejected count is zero, metadata is exact and `capture_ok=true` (`process.txt:641-652`). The admitted count is 2,035 lifecycle events; the three entries discussed below are the three observer targets, not the total admitted OSLog count.

## Exact parent issue accounting

The five top-level issues are all retained and distinguishable:

1. Execution 346 / PID 97821: `cliProcessBackendCancellationEscalatesAfterGrace` failed readiness once (`log:2372-2375`).
2. Execution 372 / PID 97822: `cliProcessBackendCancellationReturnsCheckedEvidence` failed readiness once (`log:2366-2371`).
3. Execution 347 / PID 97824: `cliProcessBackendFixtureFailureStillJoinsRealCleanup` retained both the direct `killSent == false` expectation and the outer launch/cleanup error, for two issues (`log:2365,2369,2376-2377`).
4. Execution 065 retained one cleanup-publication ordering issue (`log:2277-2290,2458`).

Those are 1 + 1 + 2 + 1 = 5. The deliberate CLI-help child failure (`log:760-766`) and isolated blocked-handler FD child failure (`log:2318-2327`) are expected child-process outputs: their owning parent tests pass (`log:1456` and `log:2330-2331`, respectively). They are not misclassified as additional parent issues.

## Per-target identity and cleanup joins

- Observer admissions are exactly three and unambiguous (`observer.ndjson:257-262`): execution 347/PID 97824, execution 372/PID 97822, and execution 346/PID 97821. Each has PPID 97570, UID 501, PGID equal to its PID, its own BSD start generation, the exact canonical `c-{id}-FOURHEX/workspace` cwd beneath the pinned temp parent, first-observed `/bin/sh`, and one valid regular staged-wrapper record. No second generation was admitted.
- The test's readiness records map execution 346→97821, 372→97822 and 347→97824 (`log:2259-2261`). Its real cleanup records contain those same singleton `continuedPIDs`, the same fixture suffixes, and zero resource-observation failures (`log:2365-2368,2372-2373`). `/var/...` in test output and `/private/var/...` in observer output are the noncanonical/canonical spellings of the same retained suffixes.
- The admitted OSLog independently joins each PID to one Core owner at `cliSpawned`: 97821→`3981053E-87A0-45DD-A91A-37539F98A32D`, 97822→`B8325372-D4E5-4644-92C8-044942A37679`, and 97824→`4F5F340B-798F-4DD5-B455-517B479AE4FC`. Each owner retains the corresponding SIGCONT call/return, exact `cliWaitpidReturned` PID, `cliReaped`, stdout/stderr completion, server-stop completion and finalization. Thus observer admission, test execution suffix, cleanup `continuedPID`, and Core lifecycle all identify the same three process generations.
- All three children become unavailable only after the final valid samples and their Core waitpid returns; the observer records explicit `identity_unavailable` ends and releases all name ports successfully (`observer.ndjson:860-868`). It later stops when the original parent generation disappears and reports `missing_targets=0`, `no_valid_samples=0`, status 0, followed by exit 0 (`observer.ndjson:1122-1127`). Observer stderr is empty, and `process.txt:327-330` records observer exit 0/no signal with 1,127 parsed rows and no launch/parse error.

## Sample validity and bounded meaning

- Global sample serials are exactly 1 through 81. Each target has exactly 27 complete samples; all 81 task, thread-list, thread, Mach-basic, pipe and final identity records are valid. No thread list is truncated, every final generation check succeeds, pipe handle/peer-handle remains stable per target, and all 81 candidate byte counts are zero. Per-target gaps after the first sample range from 100.860 ms to 110.104 ms, and the final samples occur about 33 ms before the Core waitpid events.
- The same helper/binary's required pre-workload self-check proves this host's pipe interpretation for the owned write endpoint: valid required APIs observe the fixed nine-byte sentinel, then zero after the isolated read; the exact self-child is reaped with status 0 and the helper exits 0 (`goal-foundation-runtime-child-observer-selfcheck1.ndjson:2-22`). This makes the workload's zero counts meaningful at sampled instants without implying anything between samples.
- The target task/thread measurements are stationary across all 27 samples each: BSD status 2, one thread, zero running threads, zero user time, unchanged system time and context-switch/syscall counters; the one returned thread stays at numeric run state 3 with unchanged counters and zero reported CPU usage. The observed `PROC_PIDLISTTHREADS` slot is zero for these single-thread targets but is not a failed query: the public non-unique flavor and matching `PROC_PIDTHREADINFO` use the same `machine.cthread_self` value, and all returned sizes, task thread counts and thread records agree. [Apple XNU's `fill_taskthreadlist`/`fill_taskthreadinfo` implementation](https://github.com/apple/darwin-xnu/blob/main/osfmk/kern/bsd_kern.c) permits that field to be zero; the successful self-check separately demonstrates a nonzero instance.
- Relative to the Core owner's `cliStdoutDrainEntered`, PID 97824/execution 347 has seven valid pre-reader samples with zero queued bytes, PID 97822/execution 372 has one, and PID 97821/execution 346 has none because its reader entered about 63 ms before the first observer sample. Therefore 347 gives the strongest direct evidence against a populated pipe merely waiting for the Swift reader; 372 gives one bounded pre-reader observation; 346 cannot independently exclude a transient write immediately consumed between samples. After reader entry, 100 ms sampling cannot exclude transient bytes that were drained between observations.
- `suspend_count=0` is retained only as an uninterpreted Mach API value. This review does **not** treat it as proof that `POSIX_SPAWN_START_SUSPENDED` had cleared or that SIGCONT established runnable user progress. The first-observed `/bin/sh` image is also not proof that a later exec never occurred, because image continuity was intentionally not sampled after admission.

The accepted inference is limited to this run: at 27 generation-valid sampled instants over roughly 2.78 seconds, all three owned children had zero queued stdout bytes and stationary task/thread counters, including seven pre-reader observations for 347 and one for 372. This supports a child-side nonprogress interval, but does not identify the exact loader/security/kernel wait. No rerun is authorized or needed for this evidence audit. The separate root-only spindump capability barrier remains external to this review. The retained RED full gates remain RED; A1 acceptance and A2 entry remain closed.
