# Runtime integration 2: one remaining spawn-cleanup race

2026-09-09. Bounded integration remains RED; no unchanged retry or full-suite run.

## Exact workload

After independent acceptance of isolated abort465 (`runtime-abort-contained-review.md`),
responsibilities-separated review admitted one existing integration filter, now
matching 20 tests: seven CLI backend, nine 065, plus capability, OAuth, source-boundary
and blocking-progress tests. Root used the reviewed
`.superpowers/sdd/runtime-resume-forward-progress-plan/run-evidence.rb`, with
`runtime-abort-contained-entry.json`, label `integration2`, and complete regular-file
stdout/stderr capture. No OSLog export or other process probe was added to this run.

Owned/waited PID 73757, 10:56:42.231040–10:57:15.920934 +08, exit 1,
33.635775 s wall. Final result: **20 tests / 1 suite / 32.526 s / five issues,
all in `p1f1_065AbortBeforeRegistrationOwnsAllLifetime`**. Complete log
`f3ed02b3f3aa4b0c595bdaa52ec086b54a42182aedd7d7907ce04172a80b45b3`.
Root read all 195 lines. Source309 manifest
`f355a99d3932bc7cbad4c50d93effcee1cd8748bcd542eaaee8f7bd0d3a86389`,
RunTests `58577e8568ea23218a90c50950475af86db8044ac9a361e45eb1bde70941454f`,
and C helper `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2`
remain unchanged.

CLI152/346/372/347, both old cold cases, four no-child owner cases, controlled
progress, provenance, capability/OAuth/source checks all passed in this workload.
This does not replace an authoritative unfiltered full run.

## Discriminating failure evidence

Fresh fixture `1D3F05E1-C428-4880-9EAA-5073D3D2E1DC`, exact private root
`/tmp/al65-pre-registration-abort-53e8c214`, child 73774 / parent 73757 /
group 73774 / UID 501, start tuple 1788922603:774343. Initial CONT succeeded;
readiness observed at 390/3000 polls, original 1000 μs interval, 2.808408959 s.

Normal KILL succeeded. Following CONT returned -1/EPERM (1); two immediate
group-existence probes also returned -1/EPERM. Errno is captured immediately
before logging. The test inspector turns that signal failure into generic
`EngineContextValidationErrorV1` and maps group EPERM to `true`; the live inspector
instead preserves typed `processSignal(errno)` errors.

The production spawn catch sees a signal cause plus `groupStillLiveAfterFailure`
and skips all three existing reaper/stdout/stderr joins at
`CliProcessBackend.swift:1230`. It retains the registry. Consequently both stream
and cancellation publish a structured cleanup failure, not the expected original
launch error; directory close is not attempted. This control-flow defect is
source-grounded and does not depend on guessing the kernel cause of EPERM.

The test owner's own reader, cancellation, stream and guard joins plus checked
client shutdown/close completed. Later direct probes report PID/group ESRCH and
non-consuming waitid ECHILD. **Those observations do not retroactively prove the
backend joined its three skipped internal tasks.** The cleanup certificate stays
false. Its one containment claim performs only an exact positive-PID liveness
probe, gets ESRCH, and sends no signal. The uncertified root is retained.

## Supporting source and limits

Apple's published [XNU signal implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_sig.c)
filters zombie group members before deriving the POSIX EPERM result when no
eligible member was found. That makes an exit-transition interpretation plausible,
not proven for this host. Current host kernel is xnu-12377.161.14; the matching
public tag was unavailable. No blanket EPERM-to-ESRCH interpretation is justified.

Independent reviewer confirms the next repair must use actual checked existing-owner
reap/drain results and final absence, distinguish dispatch errors from final cleanup,
preserve the original primary error and unreconciled failures, and prove the actual
cleanup branch with deterministic RED/GREEN plus genuine permission/live/reap/drain
negatives. Signal sequence, authority, deadlines and retention remain fixed;
any raw-signal certificate classification change requires explicit justification.
No production change, rerun or broader gate follows from this report alone.

Durable raw evidence is in `runtime-abort-contained-evidence/`, 25 verified files,
manifest `9fa969e7dce192cff66dcb9f7550a8c27337afeab8f0e8a0c10fa0989a5ce15d`.
