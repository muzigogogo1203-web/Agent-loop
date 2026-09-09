# Child pre-user-entry wait: bounded source-semantics research

Status: read-only investigation; no helper/source edits, compilers, probes, tests, signals or new full run. The public XNU `main` sources cited below are reference semantics, not proof that every implementation detail matches this host's shipping kernel.

## What the new observation establishes

The existing observer capture identifies direct children of RunTests 97570: 346→97821, 347→97824, 372→97822. I checked its first/last task rows and successful Mach-basic rows. User CPU, faults/pageins and both syscall counters remain zero; system/context-switch counters remain fixed (respectively 1267/2, 1819/3, 616/2 in the reported raw units). Public thread state remains WAITING=3; valid MACH_TASK_BASIC_INFO reports suspend_count=0; pipe counts are zero. Parent owns the complete 27-sample/PID/OSLog joins.

This supports a child-side pre-output nonprogress interval, not an accumulation of stdout waiting for a delayed Swift consumer. Sampling cannot exclude a brief between-sample event, and the counters do not supply a kernel waiting reason. It does not establish loader/security, memory pressure, missed SIGCONT, or a specific scheduler defect.

## Suspended versus waiting

XNU's `MACH_TASK_BASIC_INFO` assigns `suspend_count` from `task->user_stop_count`; the ordinary internal task suspension path places a normal hold. Independently, a new main thread has a return-to-userspace gate. After that gate, `task_wait_to_return` calls the post-signature hook, credential/exec notification and control-port policy processing before the final userspace return. Those are genuine pre-user-entry seams, but the public code does not identify which, if any, blocked these children. [Apple task.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/osfmk/kern/task.c) (898–968, 4080–4091, 5155–5170).

The public state mapper tests RUN, UNINT and SUSP before WAIT. Consequently WAITING=3 should not be renamed STOPPED=2 or an uninterruptible wait=4. `THREAD_EXTENDED_INFO` obtains its reported state from the same basic mapping. There is no wait-event/owner field in these public structures. [Apple thread.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/osfmk/kern/thread.c) (1913–1929, 2073–2076); [Apple public thread_info.h](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/osfmk/mach/thread_info.h) (86–151).

The two return gates are documented in the spawn implementation: clearing the initial gate permits kernel execution; clearing the final gate permits userspace. The final gate is cleared during spawn cleanup before returning from the syscall. The START_SUSPENDED hold is separately installed with `task_suspend_internal`. Thus an already-returned `posix_spawn` plus sampled suspend_count=0 does not support assuming an uncleared normal START_SUSPENDED hold. Nor should the initial/final return gate itself be asserted as the cause: the reference uses an uninterruptible wait, and the observed public state is WAITING=3. Later pre-user callbacks remain possible, unproven seams. [Apple kern_exec.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/kern_exec.c) (2068–2079, 4150–4162, 4737–4745).

The main thread is initially created waiting on the task return event, not with its own ordinary user hold. This is another reason that “suspend_count=0” is not synonymous with “all kernel startup work finished.” [Apple kern_fork.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/kern_fork.c) (482–490); [Apple thread.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/osfmk/kern/thread.c) (1584–1641).

## Public API ceiling and tool caveats

The inspected installed SDK `sys/proc_info.h` and `mach/thread_info.h` expose run state/counters, public thread handles, and limited identities. `THREAD_BASIC_INFO` would add a per-thread user suspend count, not a wait reason. Repeating these queries cannot recover the missing kernel `wait_event`, continuation, block hint or owner. No safe public wait-reason accessor using the already-held task-name port was found.

XNU stackshot, by contrast, records kernel wait event/continuation and can include wait-type/owner information. It deliberately omits certain unavailable/no-hint wait information, so even stackshot is not guaranteed to name an owner. [Apple kern_stackshot.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/osfmk/kern/kern_stackshot.c) (3973–3977, 5708–5729, 5756–5768).

The direct stackshot syscall checks root credentials and can additionally enforce a stackshot entitlement depending on kernel policy. The current uid501 observer's task-name access is therefore not evidence of permission for kernel stackshot collection. No sudo, privileged escalation, entitlement change or task-control request was performed in this investigation. [Apple bsd/kern/stackshot.c](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/stackshot.c) (465–507).

Two installed Apple manual pages matter:

- `.../MacOSX.sdk/usr/share/man/man1/sample.1` states that `sample` periodically suspends/resumes the target. The retained `_dyld_start + 0` child sample is real historical evidence, but it is **not** a nonperturbing read-only suspension-state experiment. Repeating it is not the next appropriate count/hold check.
- `.../MacOSX.sdk/usr/share/man/man8/spindump.8` documents user/kernel stacks and `-onlyTarget`, `-timelimit`, `-timeline`. A PID alone merely prioritizes that process; default collection is system-wide. Do not invoke default spindump and call it target-scoped.

Parent subsequently completed exactly one scoped capability check, which I verified from `goal-foundation-runtime-spindump-capability1-process.txt` and `-stderr.txt`: spindump PID1502 targeted only task-owned Ruby PID1496, with `1 100 -onlyTarget -timelimit 3 -noBinary -noFile`. At uid501 it exited **77**, with `spindump must be run as root when sampling the live system`. No RunTests/user-app target and no sudo were involved. This is now an observed missing privilege, not a speculative API limitation; no further capability probe is needed.

## Self-check timing is supporting context only

`goal-foundation-runtime-child-observer-selfcheck1-process.txt` spans 23:42:44.614655→23:42:46.245994: **1631.339 ms**. Its emitted monotonic `observer_start`→`exit` interval is 126289868272250→126289893909875: **25.637625 ms**. Thus about **1605.701 ms** lies outside the instrumented helper window. This can include process startup and launcher/wait/reporting scheduling; the retained evidence does not partition it into pre-main versus post-exit delay. The self-check's own fork/pipe/thread assertions passed. It is not proof of a 1.6 s loader/security wait or the same cause as the CLI children.

## One next gate / missing authority

**The specific missing capability is a bounded, identity-scoped kernel wait/continuation observation of one owned child while it exhibits the established zero-progress state.** More public counter polling, a new unchanged full run, or a leader-SIGCONT “rescue” would not identify this wait.

The next gate is **user approval for narrowly scoped administrator sampling**, not another capability check or full run. The required scope is one short target-only kernel stackshot via the installed Apple diagnostic tool, explicit `-onlyTarget`, no system-wide data, and exact owned PID/start/parent identity before/after. The root privilege requirement has already been observed. This report does not grant that privilege or execute sampling. Until approval, the affected diagnosis and A1 acceptance/A2 entry remain paused; do not broaden collection, disable protections or change the product to fit an unproved hypothesis.

Parent also decoded the recorded BSD flags `0x1404010` against the installed SDK as LP64, EXEC, APP and IMPORTANCEDONOR, without DARWINBG/EXTBG/SUPPRESSED flags. This is useful negative evidence against those particular flags, not a complete per-thread QoS, I/O policy or scheduler explanation; no such cause is asserted here.

A usable kernel stack/continuation could distinguish an IPC/policy callback, an internal return gate or another blocking primitive; a missing/unsymbolicated result must remain unknown. No diagnosis in this report licenses a timeout increase, wrapper rewrite, signal-target change, scheduler change, A1 acceptance or A2 entry.
