# External child-state observer — independent implementation review

## Verdict

**CHANGES REQUIRED before self-check or workload execution: 0 P0 / 0 P1 / 1 P2.**

This is a source/spec/quality review of the diagnostic helper, not a production repair, runtime-cause conclusion, successful self-check, workload acceptance, A1 completion or A2 entry. The reviewer did not implement the helper, compile it, run it, run tests, change Source or inspect real-user databases.

Reviewed the complete 618-line helper against the complete accepted plan and its closure review:

- Helper `goal-foundation-runtime-child-observer.c`: SHA-256 `492570d7c15896b52943fbe4bda570c56d1ab4c363f1fdefc39a7c0a12b11361`.
- Plan `goal-foundation-runtime-child-observer-plan.md`: SHA-256 `f1bd629503919a7c6ae1ee038fc8d87981cea54832501162b649592743fb0ecd`.
- The 305 existing build inputs, including 298 files under Sources plus the seven package/script companions, match the frozen integration manifest and the exact regular-file inventory. No source/build-input drift was found. The only review write is this artifact.

## P2 — enumeration errors can be accepted as empty child lists

Location: `goal-foundation-runtime-child-observer.c:426-432`.

`proc_listpids` does not propagate the underlying syscall's `-1` directly: the public libproc wrapper returns `0` on that failure, with the syscall error in `errno`. The helper resets `errno` before the call but only rejects negative lengths, capacity exhaustion and non-PID-sized lengths. Thus `bytes == 0` with a nonzero error is accepted as an ordinary empty enumeration. If every target already has valid samples, subsequent enumeration failures can still leave `observed_error == 0` and allow a successful observer terminal status. This conflates unavailable discovery with a valid empty list, contrary to the plan's explicit capability/error boundary. The emitted errno is also used after `printf` rather than retained immediately. [Apple libproc implementation](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/libsyscall/wrappers/libproc/libproc.c).

Required bounded correction: save `errno` immediately after `proc_listpids`; distinguish a successful zero-byte result with no error from `bytes == 0 && saved_errno != 0`; report and terminate the latter as a capability failure. Use the saved value consistently in the enumeration and error rows. Preserve the existing truncation and byte-divisibility rejection and do not alter the workload, cadence, deadlines or process ownership.

This is the only blocking implementation finding from this revision. Do not execute the self-check while it is open.

## Accepted implementation boundaries

- **Process ownership and PID reuse:** the runner-supplied parent PID/start and same-user identity are pinned; parent executable readiness gates discovery. Discovery is immediate-child-only. Child PID/start/PPID/UID/real-UID/PGID are checked before cwd inspection and rechecked after image inspection, with parent identity rechecked before admission. An already selected fixture cannot admit a second generation. Each sample brackets its reads with generation checks; invalid final identity requires discarding that sample, and identity loss ends the target without following a reused PID.
- **Durable, narrow admission:** `PROC_PIDVNODEPATHINFO` accepts only canonical `c-{346,347,372}-FOURHEX/workspace` paths under the given canonical temporary parent. Fixture/workspace checks use actual directories and canonical-path/symlink rejection. Initial executable acceptance is `/bin/sh`, or the source-defined `/bin/sleep` progression for 372. The actual fixture and spawn source support this cwd join. No foreign argv/environment query exists; command bodies, environment, thread names and pipe payloads are not printed. Optional wrapper provenance is bounded directory enumeration plus stat, not a prerequisite for process identity.
- **Non-consuming workload observation:** workload mode uses process metadata, public matching `PROC_PIDLISTTHREADS` handles with `PROC_PIDTHREADINFO`, and `PROC_PIDFDPIPEINFO` on FD1. It does not read or duplicate a test child's descriptors, signal/suspend it, attach a debugger, obtain a task-control port, reap test children or modify their environment/scheduling. The optional name port is attempted once per selected generation and deallocated on target end; Mach failure stays unknown rather than becoming suspend-count zero.
- **Numeric validity and timing:** task/thread/pipe rows retain API lengths and errors; truncated thread enumeration is not a valid complete sample. Numeric task/thread fields are emitted only for appropriately sized results. A failed or negative pipe result does not become an empty pipe. Monotonic timestamps use a 128-bit intermediate for timebase conversion; per-sample start/end and actual gaps are recorded. Native sleeps and bounded enumerations implement the planned observation loop; no Swift cooperative task is added.
- **Isolated self-check:** the only fork/descriptor duplication/read/wait operations occur in self-check mode, against its own pipe descriptors and direct child. A fixed nine-byte sentinel is checked before and after the parent's isolated read, with the same required task/thread/pipe sample path. Control-pipe closure releases the child; its own finite timeout and the parent's five-second deadline bound cleanup attempts. The parent checks the exact child's wait status and exposes failure/unreaped status. Own descriptors and optional name ports have explicit cleanup paths; numeric descriptors are not blindly retried after close errors.

The code does not itself prove these APIs are supported for this host's child, nor that the pipe count has the intended meaning. The planned real self-check remains mandatory after source approval. Apple XNU currently fills the write endpoint's reported size from its peer buffer, but that source is only the rationale for the host capability check, not proof of the running kernel or of a workload interval. [Apple pipe implementation](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/sys_pipe.c).

## Required evidence after the source finding closes

Root must retain the actual frozen helper/hash and warning-clean compilation result, then the bounded self-check's nine-to-zero assertions, at least one valid matching thread observation, successful owned-child reap, cleanup evidence and process exit. This reviewer has not supplied or claimed those execution results.

Any subsequently admitted workload remains the single unchanged opt-in run from the accepted plan. Its command status must remain independent of the observer's status. Exact same-run cleanup `executionId -> continuedPID` and OSLog spawned-PID/Core-owner joins are still needed before interpreting a selected target. A missed target or API gap is unavailable coverage, not an empty pipe or permission to rerun. Positive queued bytes may support a reader-service interval; valid zero samples describe only sampled instants and do not identify a loader, security, resource or scheduling root cause. A GREEN workload would be non-reproduction, not a repair. Existing full-run RED and A1/A2 gates remain unchanged.

## Closure re-review — enumeration error propagation

Independently compared the actual retained `goal-foundation-runtime-child-observer-before-fix1.c` (SHA-256 `492570d7c15896b52943fbe4bda570c56d1ab4c363f1fdefc39a7c0a12b11361`, exactly the reviewed original) with the corrected helper (SHA-256 `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`). The complete diff contains only the one enumeration hunk; no other helper behavior changed.

The corrected lines 427-435 save `errno` immediately after `proc_listpids`, reject zero bytes with a nonzero saved error, and preserve the original negative-length, capacity and PID-width checks. The enumeration row now states validity and uses the saved error; its failure path uses that same value, sets capability status 3 and terminates enumeration. A legitimate zero-byte/no-error result remains accepted. This closes the sole P2 without modifying sampling, identity, cleanup or workload boundaries.

Fresh read-only verification again found all 305 existing build-input hashes and the exact regular-file inventory unchanged. No helper, compiler, self-check or workload was executed by this reviewer; only this closure was appended to the original report.

Final verdict for corrected helper SHA `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`, superseding the initial source verdict for the prior helper revision:

- Specification: **PASS**.
- Code quality: **PASS**.
- Open findings: **0 P0 / 0 P1 / 0 P2**.

The source-review blocker to the planned bounded self-check is closed. Root still owns warning-clean compilation of this exact revision and the real self-check evidence before any workload admission. This closure does not claim host API capability, nine-to-zero pipe validation, a successful self-check, workload GREEN, a repaired runtime cause, A1 completion or A2 entry.

## Independent self-check evidence review

**PASS for the one retained local self-check only; no new findings.** The reviewer read the complete compile2 log/process record and selfcheck1 NDJSON/process/stderr, independently parsed all 22 NDJSON objects, compared archived stdout/stderr with their retained raw files byte-for-byte, and re-hashed the actual helper and binary. No compiler, helper or test was run by this reviewer.

### Frozen artifact and execution linkage

- Corrected C source remains `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf` before/after both compilation and self-check, and at this review.
- compile2 executed `xcrun clang -std=c11 -Wall -Wextra -Werror` on that helper, PID 94080, exit 0; its complete combined log is empty. The actual binary `/tmp/agentloop-child-observer-20260906-94075-n85bj9/observer` hashes to `10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365`, matching both process records.
- selfcheck1 invoked that exact binary with only `--self-check`, helper PID 95226, started `2026-09-06T23:42:44.614655000+08:00`, ended `2026-09-06T23:42:46.245994000+08:00`, exit 0, signal nil. Process-record elapsed time is 1.631339 seconds; the helper's monotonic start-to-exit record spans 25,637,625 ns. Both are within the five-second bound, and all timestamped records are monotonic.
- All 305 existing build-input hashes and the exact regular-file inventory remain unchanged.

### Capability and cleanup evidence

Both samples concern only the self-check's own child PID 95229 and FD1. Each task result is 232/232 bytes, each thread list is 8 bytes with no truncation, and each matching public thread-info result is 112/112 bytes. Both sample-end records state `identity_valid=1` and `required_apis_valid=1`; every reported errno is zero. One matching thread handle is observed in both samples. This satisfies the required local task/thread capability check, not admission of any RunTests child.

The first pipe result is 184/184 bytes and reports 9; after the source-defined isolated read of the nine-byte sentinel, the second 184/184-byte result reports 0. PID, FD, pipe handle and peer handle are identical across both valid samples. Both explicit assertions match their expected values and have `apis_valid=1`. This validates the planned write-end peer-buffer measurement on this host for this owned fixture; it is not evidence that a later workload pipe is empty or stalled.

The optional name-port acquisition succeeds once; both `MACH_TASK_BASIC_INFO` results have KR 0, count 12/12 and report suspend count 0 for this self-check child. Name-port release has KR 0. The exact self-check child is reaped with raw status 0; the final self-check record states status 0 and `child_reaped=1`, followed by exit status 0. Stderr is empty and there are no API-error or cleanup-error events. The reviewed cleanup code checks its own descriptor closures before that successful terminal state.

### Retained evidence hashes

- `goal-foundation-runtime-child-observer-compile2-process.txt`: `58a54bbcee1bc4f58a73fd1414b95bc3a67bf57a79e06da02c2cc286b98e7894`.
- `goal-foundation-runtime-child-observer-selfcheck1-process.txt`: `0d6de5edef1214b59b17e2a7e96a4e6ff1b2fac9da58bc5454576e3fe6e357a8`.
- `goal-foundation-runtime-child-observer-selfcheck1.ndjson`: `f376635cee2c099e33d6f414827d478d4824ab2e95366dd0859502a91e52d9e5`.
- Empty compile2 log and selfcheck1 stderr each hash to `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The warning-clean compilation and isolated capability/reap prerequisites are therefore satisfied for this exact helper revision. The single planned workload remains gated separately on its runner review and exact capture/admission rules. Self-check mode does not exercise RunTests-parent readiness, fixture-cwd discovery, missing-target handling or the post-capture cleanup/OSLog joins; those are not inferred from this PASS. No workload was rerun or approved as GREEN here, no runtime root cause or repair is established, and the retained full-run RED, A1 completion and A2-entry boundaries remain unchanged.
