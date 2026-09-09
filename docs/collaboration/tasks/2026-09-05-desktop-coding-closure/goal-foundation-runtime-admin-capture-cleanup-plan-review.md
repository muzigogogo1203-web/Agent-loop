# A1 administrator capture — spindump cleanup plan review

Date: 2026-09-07  
Review scope: only the new `Global constraints` rule for finite cleanup of the helper-owned `spindump` child  
Plan reviewed: `goal-foundation-runtime-admin-capture-plan.md`, SHA-256 `0f76aee99ad99de6b6c5522376aa4e1c6926b0ea945d5d8758dd45fb18442e2f`  
Verdict: **PASS — no blocking finding**

## Assessment

The rule at plan line 23 is a necessary bounded resource-control obligation for the newly introduced diagnostic helper, not an expansion of sampling or test-process authority. The tool's internal `-timelimit 10` caps its own report work but cannot prove that the outer helper has reaped the child. A separate outer deadline and exact-child cleanup are therefore justified.

The planned sequence is appropriately finite and ownership-scoped:

1. The deadline is 15 seconds from the helper's single `spindump` fork, while sampling remains exactly one second at 100 ms. The ten-second `spindump` tool limit does not extend sampling duration.
2. A nonblocking `waitpid(exactPid, ..., WNOHANG)` occurs before any signal. A returned child PID is normal confirmed reap and ends cleanup without a signal.
3. TERM is permitted only when the unreaped direct child is still live and its retained BSD start generation matches. It targets one strictly positive PID—not a negative PID, zero, process group, target child, or `RunTests`.
4. The helper waits at most two additional seconds using nonblocking reap checks, then revalidates the same generation before any KILL. A missing, changed, or unconfirmable generation forbids the signal.
5. After KILL, nonblocking reap attempts stop after at most three more seconds. Thus the cleanup path has an outer bound of approximately 20 seconds from fork rather than an indefinite `waitpid`.
6. If confirmed reap is unavailable—including `ECHILD`, an unexpected wait error, failed generation validation, failed signal, or exhaustion of the final reap horizon—the result is explicit `cleanup_incomplete` failure with the residual identity. Closing only helper-owned pipe read ends and marking byte completeness false preserves failure observability without touching the sampled process.

Implementation review must verify that all three horizons use a monotonic clock; `EINTR` retries remain inside the existing horizon; every `waitpid` result and signal errno is retained; and no cleanup error overwrites the original sampling/test status. These are direct implementation checks of the accepted rule, not additional plan blockers.

## Scope boundary

This approval does not authorize signaling the sampled CLI347 child, `RunTests`, the launcher, any process group, an ambiguous/reused PID, or an independently discovered descendant. It does not authorize a second capture or retry. It also does not approve the overall helper/launcher implementation in advance; that complete diff still requires separate independent review.

P0: none.  
P1: none.  
P2: none.

No helper, source, compiler, test, capture, privilege, or process operation was invoked during this review. This review artifact is the only write.
