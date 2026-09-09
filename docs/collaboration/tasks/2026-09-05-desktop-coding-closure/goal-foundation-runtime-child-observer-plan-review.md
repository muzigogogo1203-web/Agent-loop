# Bounded external child-state observation — independent plan review

Reviewed plan SHA-256 `69f0c74944f18b36f4b5c977a7582f4b1654f116fa704f347553de78dbce8022` against the current CLI spawn, fixture wrapper and pipe-drain source plus the local macOS SDK declarations. This reviewer did not author or run the helper, compile anything, run a test/workload, change Source, or approve a repair.

## Verdict

- Specification: **CHANGES REQUIRED**
- Plan quality: **CHANGES REQUIRED**
- Findings: **0 P0 / 1 P1 / 0 P2**

Do not run the self-check or the one workload until the P1 is corrected and the actual helper receives its separately required implementation review.

## P1 — child admission depends on an ephemeral argv state that 100ms sampling cannot reliably observe

The admission rule at `goal-foundation-runtime-child-observer-plan.md:16-17` requires KERN_PROCARGS2 to expose the staged wrapper path and fixture prefix before following the child across its legitimate exec. The actual fixture writes a shebang wrapper whose only body is immediate `exec /bin/sh "$@"` (`Sources/AgentLoopTestSuite/CliBackendTests.swift:925-930`), and the backend launches that staged path with a new process group and `POSIX_SPAWN_START_SUSPENDED` (`Sources/AgentLoopCore/Loop/CliProcessBackend.swift:925-979`). After SIGCONT, the wrapper can replace itself with the second `/bin/sh` before the external observer's next 100ms enumeration. That exec preserves PID/start/PPID/PGID and working directory but removes the staged wrapper pathname from the live argv. A missed transient therefore becomes “target not found” even when the target ran normally; repeating the workload would be forbidden and would not repair the admission design.

KERN_PROCARGS2 also returns a buffer whose tail contains environment strings after argc/argv. Stopping parsing at argc can prevent disclosure, but it cannot make the literal claim “never environment bytes” true for the syscall buffer. The plan should not introduce that unnecessary privacy ambiguity when a durable, narrower identity is already available.

### Required bounded correction

Replace the transient argv/staged-image prerequisite with a durable, fail-closed join:

1. Keep the exact RunTests parent PID/start/UID/executable check, immediate-child enumeration, and child PID/start/PPID/UID/PGID==PID checks.
2. After those checks, use `PROC_PIDVNODEPATHINFO` to require the child's current directory to be the canonical, nonsymlink `workspace` under exactly one `c-346-*`, `c-347-*` or `c-372-*` directory beneath the already bounded temporary fixture parent. This is source-grounded: the harness creates `c-<identity>-<UUID-prefix>/workspace` (`CliBackendTests.swift:846-865`) and the backend applies that workspace with `posix_spawn_file_actions_addchdir_np` before spawn (`CliProcessBackend.swift:894-899`); cwd survives the wrapper's exec.
3. Require the current executable image to resolve to `/bin/sh`. If retaining wrapper-file provenance is useful, inspect the single regular nonsymlink `staged-*/executable` under that already admitted fixture directory and record its dev/inode/hash before cleanup, rather than requiring it to remain in the live argv.
4. Post-capture, require each selected child PID/generation to equal the existing same-run `executionId -> continuedPIDs` cleanup mapping and the admitted OSLog `cliSpawned` PID/Core-owner mapping. Missing, duplicate or conflicting cwd, wrapper, PID-generation or post-hoc identity edges invalidate that target's evidence. Do not fall back to KERN_PROCARGS2, chronology, PID alone or a rerun.

This correction remains read-only, observes only actual owned immediate children, avoids command bodies/environment entirely, and does not alter the 100ms cadence, test concurrency, deadlines, signals, Source, workload count or decision rule.

## Accepted portions and limits

Subject to that correction, the design is a useful smallest next measurement:

- A native external observer avoids dependence on the Swift cooperative pool and records actual sampling gaps rather than assuming cadence.
- `PROC_PIDTASKALLINFO`, bounded thread-info reads and optional read-only `MACH_TASK_BASIC_INFO` are treated as observations with exact API results, not as guaranteed access or PC-level proof; PID generation is revalidated and the optional Mach name port is released.
- `PROC_PIDFDPIPEINFO` on child FD1 consumes no test bytes. The isolated nine-byte/zero-byte self-check correctly makes host support and write-end peer-buffer semantics a fail-fast prerequisite; it does not turn helper capability into workload success.
- The decision rule is appropriately asymmetric: positive queued bytes can support a reader-service interval, while zero samples and process counters describe only sampled instants and do not identify a loader/security cause. SIGCONT success is not equated with resumed state.
- The helper and original command have separate ownership; observer failure cannot terminate or mask the test command. One self-check, at most one unchanged instrumented workload, complete evidence retention, no signals/debugger/FD reads of test pipes, and the explicit no-rerun stop rule keep the diagnostic bounded.

This review does not approve the not-yet-reviewed helper implementation, accept any eventual capture, choose a root cause or fix, clear either retained full-run RED, complete A1, or open A2.

## Closure re-review

Re-read the complete corrected plan, current SHA-256 `f1bd629503919a7c6ae1ee038fc8d87981cea54832501162b649592743fb0ecd`.

The revised lines 16-17 close the P1. Admission now uses the durable canonical `c-{346,347,372}-FOURHEX/workspace` cwd only after exact RunTests-parent and immediate-child PID/start/PPID/UID/PGID checks; it does not call KERN_PROCARGS2 or read argv/environment. It recognizes the source-defined legitimate image progression (`/bin/sh` for 346/347 and `/bin/sh` or `/bin/sleep` for 372), makes wrapper stat optional rather than an admission dependency, follows one frozen PID generation, and requires exact same-run cleanup plus OSLog `cliSpawned`/Core-owner joins after capture. A missing or conflicting edge invalidates only that target instead of inviting path inference or a rerun.

Line 32 also correctly treats a sub-100ms passing child as a per-target coverage gap, never as a negative state observation or a reason to discard separately complete failed-target evidence. A missed failing target remains unresolved. This preserves the one-workload stop rule and the asymmetric interpretation of positive queued bytes versus sampled zeroes.

The corrected line 18 also uses the public API pair consistently: bounded `PROC_PIDLISTTHREADS` handles feed `PROC_PIDTHREADINFO`, expressly excluding `PROC_PIDTHREADID64INFO`, and the self-check must prove at least one valid matching thread observation. Exact lengths, truncation and errors remain fail-closed evidence. This closes the intervening API erratum without adding private constants or broadening observation.

Final verdict for plan SHA `f1bd629503919a7c6ae1ee038fc8d87981cea54832501162b649592743fb0ecd`, superseding the initial verdict for the earlier revision:

- Specification: **PASS**
- Plan quality: **PASS**
- Open findings: **0 P0 / 0 P1 / 0 P2**

For implementation review, “regular nonsymlink fixture/workspace directories” at line 16 must be realized as actual directories (`S_ISDIR`) with symlink rejection, not as regular files. This is a source-review check, not an open plan finding. The actual helper, its self-check and any workload capture remain unapproved until their required independent reviews; no root cause, repair, A1 completion or A2 entry is pre-accepted.
