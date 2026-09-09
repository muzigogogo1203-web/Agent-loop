# Child-observed1 — independent numeric timeline analysis

## Conclusion and scope

The three actual failing CLI fixture children each have **27 complete, identity-valid samples**, spanning approximately **2.77795 seconds** from first to last sample start. All sampled pipe counts are zero; task user CPU, Mach/Unix syscall counts, faults and pageins remain zero, while small **nonzero system CPU counters remain constant**. This supports a child-side nonprogress interval at the sampled instants, not an observed backlog of output waiting for the Swift reader. It does not identify the cause of that nonprogress.

Reader entry is not uniformly immediate: relative to each successful SIGCONT return, it occurs at +44.957 ms for 346, +807.609 ms for 347 and +153.708 ms for 372. Nevertheless, 347 has seven valid zero-pipe samples before reader entry, and 372 has one. There is no positive queued-byte observation before or after their reader entry. The reader-entry delay is a real measured interval, but this capture does not establish it as the cause of readiness failure.

The full workload remains **RED: 1130 tests / 33 suites / 56.098 seconds / five parent issues / exit 1**. Observer exit 0 is not workload success. This report performs only read-only evidence attribution; no Source, helper, compiler or test was changed or run by this reviewer, and no repair, A1 acceptance or A2 entry is approved.

## Exact run and ownership joins

The command is the single retained `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests`, PID 97570, start `2026-09-06T23:46:45.172001000+08:00`, end `2026-09-06T23:47:42.811781000+08:00`, exit 1, signal nil. Its pinned BSD start generation is `(1788709605, 172305)`, UID 501. The identity handshake first sees `/usr/bin/swift`; the reviewed observer waits for the exact resolved RunTests image before admitting children. The observer is PID 97573, helper source SHA `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`, binary SHA `10461c3041954e75b89a3e7d55d57818cc608935ca82bd313aff8e614ae49365`.

Independent parsing confirms all 2,035 admitted OSLog events equal the raw log-event sequence, plus one raw completion record `{count:2035, finished:1}`. Every admitted event has the exact PID 97570, RunTests image path, subsystem/category, and timestamp within this invocation. Their boot UUID is `FCB6B033-E174-4F15-9536-19CFD96BCC5E`; image UUID is `8E982BC0-419A-3428-816B-6DA7A53D8DBD`. All eight archived raw-capture companions match their raw files byte-for-byte. The observer has 1,127 parseable rows; observer, identity and OSLog stderr are empty. All 305 before/after/current build-input hashes and the exact regular-file inventory match.

Each child is admitted once with PPID 97570, UID 501 and PGID equal to its own PID. Its fixture directory suffix matches the same-run cleanup line, after the known `/var` to canonical `/private/var` path normalization. A unique `cliSpawned` event joins the same PID to its Core owner; a unique stdout readiness-identity line joins the execution suffix to its recorder owner. No chronological-only or PID-only substitution is used.

| Fixture | Child PID / BSD start generation | Fixture directory | Core owner | Recorder owner |
|---|---|---|---|---|
| 346 | 97821 / `(1788709633,529347)` | `c-346-D867` | `3981053E-87A0-45DD-A91A-37539F98A32D` | `2146A812-467C-4DF3-9D84-B95957A6826F` |
| 347 | 97824 / `(1788709633,533349)` | `c-347-8A0A` | `4F5F340B-798F-4DD5-B455-517B479AE4FC` | `900F5E18-1D60-42DF-92B9-F21311083E52` |
| 372 | 97822 / `(1788709633,531415)` | `c-372-436B` | `B8325372-D4E5-4644-92C8-044942A37679` | `9B366B6B-1068-4C2F-8477-E8323D74A4DD` |

All initial images are `/bin/sh`; all cwd paths end in the exact fixture's `/workspace`. Optional wrapper provenance is valid for each, with one regular staged executable and no enumeration truncation. That provenance supplements, but does not replace, process identity. Observer admission rows are 257–262; the matching cleanup rows are full-log lines 2365–2373.

## Numeric timeline

Times below are milliseconds relative to the respective Core `cliSIGCONTReturned` event; they are rounded to three decimals. The exact monotonic zero points are 346=`126557180277708`, 347=`126557184199500`, 372=`126557182369750` ns. Readiness begins before spawn because the fixture starts waiting after synchronous registration while the async launch proceeds.

| Event | 346 | 347 | 372 |
|---|---:|---:|---:|
| Ready wait begins | -86.189 | -86.719 | -86.701 |
| Spawn returns child PID | -0.091 | -0.104 | -0.117 |
| SIGCONT call begins | -0.021 | -0.019 | -0.021 |
| SIGCONT returns | 0.000 | 0.000 | 0.000 |
| Stdout drain entry | 44.957 | 807.609 | 153.708 |
| First valid sample starts | 108.133 | 104.261 | 106.118 |
| Last valid sample starts | 2886.081 | 2882.210 | 2884.072 |
| Last valid sample ends | 2886.128 | 2882.240 | 2884.099 |
| Ready wait ends, outcome 3 | 2919.100 | 2915.250 | 2917.064 |
| TERM syscall result reported | 2919.344 | 2915.517 | 2917.311 |
| Exact-child `waitpid` returns | 2919.507 | 2915.724 | 2917.464 |
| Stdout EOF task joined | 2992.953 | 2989.091 | 2990.879 |
| Stderr EOF task joined | 2992.960 | 2989.094 | 2990.884 |

The ready waits last 3005.289, 3001.969 and 3003.765 ms respectively. In the actual recorder source, outcome 3 means its deadline expired without the expected stdout line and without the stream having finished. It is not a successful ready acknowledgment. The captured Core owners have no `cliStdoutFirstBytes` or `cliStdoutFirstLineYielded`; the corresponding recorder owners have no first-stdout-received or first-stdout-recorded event. These are missing events in a complete admitted capture, not observed zero-byte reads. The independent pipe samples provide the separate numeric zero observations.

The process-signal ownership records supply complete five-field transactions for each child: path 0, target `-PGID`, signal 19 for SIGCONT or 15 for TERM, result 0 and errno 0. Each child has exactly those two recorded signal transactions and no SIGKILL transaction. Thus the signal syscall succeeded for the checked process group; this is not proof that the child completed all internal resume work.

## Sampling validity, counters and blind intervals

All 81 samples have ordered begin/task/thread-list/thread/optional-basic/pipe/end records, valid exact API sizes, no required-API errors, no thread-list truncation, and final `identity_valid=1` / `required_apis_valid=1`. The first sample for each generation also records its one name-port acquisition. Actual sample durations range from 20,750 to 114,417 ns. The same pipe and peer handles remain stable within each target.

| Measurement | 346 | 347 | 372 |
|---|---:|---:|---:|
| Valid samples | 27 | 27 | 27 |
| First-to-last start span, ms | 2777.949 | 2777.949 | 2777.955 |
| Actual inter-sample gap min–max, ms | 100.865–110.104 | 100.863–110.094 | 100.860–110.103 |
| Valid samples before / after drain entry | 0 / 27 | 7 / 20 | 1 / 26 |
| Task system counter, raw and constant | 1267 | 1819 | 616 |
| Task context switches, constant | 2 | 3 | 2 |
| Thread system counter, raw and constant | 52000 | 75000 | 25000 |

At every valid sample, task user=0, faults=0, pageins=0, syscalls_mach=0, syscalls_unix=0, threads=1 and running=0. BSD status is 2 and BSD flags are 20987920. Each public thread observation reports raw handle 0, run_state=3, user=0, cpu_usage=0 and sleep_time=0. The zero handle is retained as a raw public handle, not promoted to a unique kernel thread ID. These numeric results establish no observed counter advancement; they do not establish that no kernel activity or unsampled transition occurred.

Every pipe result is a valid 184-byte result with candidate_bytes=0. The prior independently reviewed nine-to-zero self-check supports interpreting that field as the current write-end peer-buffer count on this host. There is no positive queued-byte sample. In particular, 347's seven zero observations occur before its drain entry, so its approximately 808 ms reader-entry delay is not accompanied by an observed accumulated output buffer. After reader entry it still has approximately 2.108 seconds before the readiness failure, with another 20 valid zero samples.

There are explicit observation gaps: no child samples before the first admission, approximately 101–110 ms between sample starts, and approximately 33.212–33.278 ms from the last valid sample end to successful TERM return. There are no post-TERM task/thread/pipe samples. These intervals are not filled with inferred zeros. At the next probes, all three child BSD queries return length 0 / errno 3, after their exact-child waitpid returns; each target ends as `identity_unavailable`, and each name port is released with KR 0. The observer later gets the same unavailable query for the ended RunTests parent and terminates. Those four unavailable queries are not zero-state samples or evidence of running children.

All 81 optional `MACH_TASK_BASIC_INFO` observations return KR 0, count 12/12, valid=1 and suspend_count=0. This report does **not** equate that field with absence of every kernel hold or with completion of `POSIX_SPAWN_START_SUSPENDED` resumption. Its exact kernel semantics are outside this numeric attribution and being checked separately. Neither SIGCONT success nor this field alone proves the children fully resumed.

## Cleanup and retained test failure

For all three exact execution/recorder owners, the cancellation receipt and joined exit frame agree: PID=PGID equals the admitted child, status=143, termSent=1, killSent=0, childReaped=1, stdoutEOF=1, stderrEOF=1, cancellation state=2, and exactly one exit frame with status 143. The Core's `cliReaped value=0` means a reap status was obtained, **not exit status zero**; `cliStdoutFinished/cliStderrFinished value=0` mean their EOF checks succeeded. The actual exit status comes from the cancellation/exit-frame fields above.

All three resource-observation lines report `failures=0`. In the reviewed `cliMechanicsObserveResources` test helper this entails checked absent PID/process group, no unreaped child via non-consuming waitid, and absent socket. The evidence therefore records readiness failure followed by completed cleanup, not residual child/process-group/socket leakage. It cannot be used to call the intended TERM-resistant post-ready scenario successful.

The five parent issues, excluding the two expected nested child negative controls, are:

- 346: one `process did not become ready` issue.
- 347: the same readiness primary plus the required `killSent` expectation failure, recorded as two issues. Its intended deliberate `.afterReady` failure was never reached. Do not detach `killSent=false` from this failed precondition and label it an independent escalation regression.
- 372: one `process did not become ready` issue.
- The separate 065 cleanup-publication assertion at `ExecutionEngineConformanceTests.swift:8443`: one issue. These three child timelines do not diagnose that separate assertion.

The CLI deliberate-child-failure and Board leak-proof child blocks each contain one intentional nested issue; their dedicated parent harness tests pass. Their child red summaries are not additional full-run parent failures. Full-log line 2557 remains the authoritative five-issue RED summary.

## Interpretation boundary and evidence fingerprints

The additional measurement narrows the failure from “no ready bytes observed” to **repeated valid zero peer-buffer counts with nonadvancing child counters across most of the ready window**, while independently observing reader entry and successful group SIGCONT. This is evidence against an observed queued-output backlog awaiting the reader, and supports a child-side nonprogress interval at sampled instants. It is not a diagnosis of internal suspension, loader/security policy, scheduler/resource pressure, wrapper execution or another specific cause. No fix, deadline change, concurrency change or repeated workload is justified by this report alone. A1 remains RED.

- Full stdout: `5588efa78bfd0265430f413f9bb986603757c8b99613009ea84eea6f2691dfea`.
- Process record: `c19883951426aeef6a0bca13fab0b4a43b09f6080fbff8d03bb6c5134013dc29`.
- Observer NDJSON: `ad16351748b532bfc9f30780323b277defa36416a08cb91c769c7c2d8923c493`.
- Admitted OSLog NDJSON: `66e0dc4b62305027540c35f3831de486688ed89c2bd144a4d0e2966dccb847a6`.
- Raw OSLog NDJSON: `bd2aae064595cd5459a8a55d5f0e4d9f456f2fffaa13db6e96e6ff4ae1dd05fb`.
- Frozen 305-input manifest: `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`.
