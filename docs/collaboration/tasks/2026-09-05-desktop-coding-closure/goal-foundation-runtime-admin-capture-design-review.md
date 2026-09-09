# A1 runtime administrator capture — independent design review

Date: 2026-09-07  
Reviewer role: independent, read-only diagnostic-design reviewer; not the author or implementer  
Verdict: **PASS WITH HARD EXECUTION CONDITIONS**  

This verdict approves only the bounded design of one diagnostic capture. It does not approve an implementation in advance, authorize a second workload or retry, identify a root cause, repair the runtime, or clear A1/A2 gates.

## Frozen material reviewed

- `goal-foundation-runtime-child-checkpoint.md`, SHA-256 `2df6379658aa82971e031906dd33effd857800946cd319035a4c2facf0f10560`.
- The complete installed `/usr/share/man/man8/spindump.8` (224 lines), SHA-256 `d5648a5c0ba494526a4e68720cff3227dee6ba1f7aee764162b078eff804e16a`.
- The installed `/usr/sbin/spindump`, SHA-256 `ae75637b77d3262dde83b201893338d8b4fb01b7be11895533267f60d07c7625`; static inspection of its embedded option/error text only. The tool was not invoked by this review.
- The previous nonprivileged capability evidence: process record SHA-256 `552aa181c4c285c29ca6bdbc5aa97c36d1419b078b366362e37b2a0644016958` and stderr SHA-256 `b3fdf2063ef1d838114601b70c192941b91a038695f2d1c55c3818cab8636a9c`. It establishes exit 77 and `spindump must be run as root when sampling the live system`; it is not a successful stack capture.
- Apple’s `do shell script` command reference, specifically the `administrator privileges` contract ([Apple Commands Reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html#//apple_ref/doc/uid/TP40000983-CH216-SW40)).

No sampling, test workload, compiler, privilege escalation, process signal, product source edit, Provider call, or real-data access was performed. This review file is the only write.

## Installed `spindump` scope and option findings

The installed manual first describes the default manual behavior as sampling user and kernel call stacks for **every process** (`spindump.8:21`). Supplying a PID alone merely sorts that process topmost (`:51-54`); it does not scope acquisition. The critical distinction is explicit: `-onlyTarget` means “Only sample the target process” (`:106-107`). The installed binary’s embedded help repeats that wording and separately rejects multiple targets without `-onlyTarget` because otherwise all processes are sampled. On the locally documented/current-binary command contract, `-onlyTarget` narrows acquisition; it is not merely a final-output filter.

That contract is sufficient for this bounded design, but it is not a source-level proof of proprietary implementation internals. `spindump` still executes as root, and target-independent system/report metadata may appear. Evidence admission must therefore inspect the report structure and reject any unexpected process stack section rather than treating the flag as a substitute for output review.

The minimal useful fixed invocation is:

```text
/usr/sbin/spindump <fresh-pid> 1 100 -onlyTarget -timeline -timelimit 3 -noBinary -noFile
```

Its semantics and boundaries are:

- positional `1 100`: sample for one second, nominally every 100 milliseconds (`:56-60`). Do not broaden duration or decrease the interval for this one authorized capture.
- `-timeline`: show leaf stacks chronologically, including ranges of consecutive samples (`:33-45`, `:94-95`). Leaf frames identify running/runnable or suspended state, and `*` identifies a kernel frame (`:47-49`). This is the smallest mode able to preserve transitions relevant to the observed child nonprogress.
- `-timelimit 3`: a wall/report-completion cap—exit after three seconds even if the report has not been saved (`:120-123`). It is not the sampling duration and is not evidence of completeness. Expiry, truncation, empty output, or a nonzero exit is an explicit diagnostic gap, not a reason to retry.
- `-noFile`: send the report to stdout instead of the default `/tmp` report (`:73-78`, `:128-129`).
- `-noBinary`: retain text only, without the opaque embedded binary payload (`:131-132`).

The command must omit `-proc`, `-wait`, `-sampleWithoutTarget`, `-stdout`, `-o`, `-open`, `-reveal`, `-siginfo`, `-delayonsignal`, `-notarget`, `-noText`, `-onlyRunnable`, `-onlyBlocked`, and all microstackshot/system-wide modes. In particular, `-proc` adds another sampled process (`:109-115`), `-wait` creates a late-name/PID ambiguity (`:97-98`), and `-sampleWithoutTarget` continues after the owned target exits (`:117-118`). The installed binary also reports that runnable/blocked filtering cannot be combined with timeline output; filtering either state would hide the transition this measurement needs.

## What the one-second report can and cannot establish

If symbolication succeeds, the timeline can show sampled user/kernel call paths and state at roughly ten nominal sampling points. A symbolic kernel leaf or wait-related user frame can identify a plausible wait path or continuation. It can distinguish sampled running/runnable/suspended states more directly than the previous public task counters.

It cannot prove what happened between samples, guarantee that a brief wait is caught, establish causality from one stack, or guarantee a named kernel wait event. Kernel symbols may be incomplete. The report must not reinterpret `suspend_count == 0` as excluding every internal wait or START_SUSPENDED-related condition. A valid but inconclusive capture ends this authorized measurement; it does not justify an unmodified full rerun.

## Privilege and authentication boundary

The proposed two-stage AppleScript design is acceptable only with these constraints:

1. One AppleScript first performs a fixed `/usr/bin/true` using `do shell script ... with administrator privileges`, so the user enters credentials only in the macOS authentication UI **before** the short-lived workload starts. Cancellation or authentication failure aborts before workload launch; there is no fallback or retry.
2. Apple documents that a correctly authenticated script is not asked again for five minutes, while the elevated privileges and grace period do not extend to other scripts or the rest of the system. This is a useful timing mechanism, not persistent or system-wide authorization. It is nevertheless a five-minute privileged capability inside that script: the reviewed implementation must contain an exact closed list of privileged statements, accept no arbitrary command text, and exit immediately after the capture/retention step.
3. Target launch, wait, child discovery, and routine observer work remain under the ordinary user. Do not run `swift`, `RunTests`, the fixture, or a general launcher as root. Do not install a root helper/daemon, change `sudoers`, use `sudo`, persist credentials, or request the password through argv, stdin, environment, files, logs, chat, or a custom dialog.
4. Immediately before `spindump`, run only the already reviewed fixed identity check for the chosen PID and then the fixed `spindump` command. If the final identity check is placed in the privileged shell to minimize the race, it must be a fixed, read-only, exact-PID invocation and must gate `spindump` on success. No discovery, name search, wildcard, Provider access, or filesystem crawl may occur with privilege.
5. Because `do shell script` uses `sh`, every executable path and option must be fixed, the PID must be validated as decimal and range-checked, and every output path must be unique, absolute, predeclared, and shell-quoted. Preserve stdout, stderr, exit status/signal, and AppleScript error separately; never turn a failed `spindump` into a successful wrapper result. If AppleScript transports stdout directly, use `altering line endings false`; otherwise raw report bytes would be normalized and the claimed raw hash would be false.

Apple’s reference also forbids asking another application to execute an administrator `do shell script`; keep the privileged statement outside `tell` or inside `tell me`. No claim should be made that the five-minute grace can be actively revoked; the safety boundary is the short-lived, frozen script and the fact that its privilege does not extend elsewhere.

## Fresh target and PID-reuse conditions

`spindump` takes only a numeric PID and has no generation-token argument. There is an irreducible check-to-use race, so a historical PID or a process found by partial name is unacceptable. Select exactly one fixture in advance; do not opportunistically fall back to a different child if it is absent or too short-lived.

Before launch, freeze the 305-input manifest and the expected fixture identity. After ordinary-user launch and discovery, require all already reviewed ownership fields: fresh BSD start time after this invocation began; exact UID/RUID; immediate PPID equal to this run’s `RunTests` PID; expected self-led PGID; exact canonical fixture cwd beneath this run’s unique temporary root; and the predeclared executable/image lifecycle for that exact fixture. Reject zero, multiple, stale, exited, or mismatched candidates.

Immediately before the privileged sample, repeat the exact PID/start/PPID/UID/PGID/canonical-cwd/image check and require byte-for-byte agreement with the admitted generation. Invoke `spindump` immediately after that check, with neither `-wait` nor `-sampleWithoutTarget`. After capture, require the same generation or its exact recorded exit/reap transition; do not silently accept a new process that reused the number.

Normal test cleanup must always continue regardless of authentication, identity-check, or capture failure. The diagnostic must not signal, suspend, resume, kill, attach a debugger to, read file descriptors from, or change the deadlines/concurrency of the target. Final lifecycle evidence must join the exact fixture’s spawn, SIGCONT performed by unchanged product code, waitpid/reap, stdout/stderr EOF, and finalization events, and must show no continued PID for the completed execution.

## Privacy and evidence admission

Even target-only text can disclose the synthetic fixture path/cwd, executable and library names, symbol names/addresses, thread state, OS/build/hardware metadata, and process identity. Store stdout/stderr/metadata in unique task-local files with mode `0600`; do not display or transmit them beyond this task review path. `-noFile` prevents the normal automatic report destination, and `-noBinary` removes the embedded binary payload, but neither option makes the text nonsensitive.

Accept the capture only if all of the following are recorded and independently reviewable:

- the exact fixed command and hashes of its reviewed script/helper; ordinary-user runner PID plus exact fresh target generation; authentication requested/completed/cancelled/failed metadata with no credential material;
- nanosecond-offset start/end times, command PID, exit status and signal, independently retained raw stdout/stderr and hashes, and explicit outcome of the identity checks before and after sampling;
- exit zero/no signal, nonempty textual timeline for the exact admitted PID/generation, a plausible one-second sample range/count, and no `timelimit`/truncation/reporting error;
- zero unexpected process stack sections or extra sampled PIDs. Target-independent report metadata may be retained and classified, but any other process’s stack/argv/path is a privacy and admission failure; preserve the evidence securely and do not rerun automatically;
- unchanged synthetic fixture only, no camp database, secrets, user application, Provider, paid service, or real-user data; normal exact-child cleanup and OSLog joins; 305 source/build inputs unchanged before/after; and no unexpected report file in the default or requested output locations.

The existing RED workload result and prior observer evidence remain authoritative regardless of this measurement. A successful capture accepts only measurement integrity. An inconclusive or failed capture must be reported as such; it must not be converted into a repair claim, GREEN gate, or permission for another sample.

## Findings

- **P0: none.**
- **P1: none, provided every hard condition above is present in the separately reviewed implementation.** The most important gates are pre-authentication before the short-lived child exists, ordinary-user workload execution, target-generation validation immediately adjacent to sampling, fixed `-onlyTarget` with no additive-process options, raw result preservation, and rejection of unexpected process stacks.
- **P2: none.** The unavoidable residuals—numeric-PID TOCTOU, sparse sampling, incomplete symbols, and target-independent report metadata—are explicitly bounded and must remain limitations in the final evidence review.
