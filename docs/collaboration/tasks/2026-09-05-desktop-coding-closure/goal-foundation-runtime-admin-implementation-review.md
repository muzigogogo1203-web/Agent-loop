# A1 administrator capture implementation — independent review

Date: 2026-09-07  
Reviewer role: responsibility-separated whole-diff reviewer; not implementer  
Spec verdict: **CHANGES REQUIRED**  
Quality verdict: **CHANGES REQUIRED**  
Authorization verdict: **BLOCKED — do not authenticate or execute the workload**

## Frozen review inputs

- Actual four-new-file diff: `goal-foundation-runtime-admin-implementation1.diff`, SHA-256 `d90d362ca62571804dcdee6233164652ddb513e741eef592272b07ba5113f122`. I read the complete 859-line artifact; all four paths have `/dev/null` preimages. I did not substitute a commit diff.
- Current implementation hashes match the diff/report: C `8d1a9a1a7a3f6be783844cef2590da9d73777a08bf7cfea77d0e3dee5f04fabd`; Ruby runner `a21bcb5eadbf463e1afc456183290f19d72a6d95a11e134866836bf16737c781`; AppleScript `a1575713abe83e83ce9baa7ddf26f81ed888b56e8a39742935ba7dbc3dc2a1a1`; refusal checks `3c42024f1c10b0e03adfd3e79c5b33654bc6fe6f7b01f8cc17ecb7481db37db7`.
- Latest plan: `goal-foundation-runtime-admin-capture-plan.md`, SHA-256 `0f76aee99ad99de6b6c5522376aa4e1c6926b0ea945d5d8758dd45fb18442e2f`.
- Correct task SDD brief: `.superpowers/sdd/goal-foundation-runtime-admin-capture-plan/task-1-brief.md`, 20 lines, SHA-256 `2c3a4f4f076deaf2d1c11ca3c3382c62eba191af44f9fa0007e5c6dabbdee98e`; implementer report SHA-256 `b198dbff2e7291120ece1154f8e69f2de16ee61d2a90b294f35d32d6ff03eb9f`.
- Included old observer source remains `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`; old runner remains `74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417`.
- Independent read-only recomputation found exactly 305 `Sources`/`scripts`/Package inputs with manifest SHA-256 `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`.

### Provenance correction

The first revision of this review incorrectly named and hashed `.superpowers/sdd/goal-foundation-plan/task-1-brief.md` (`f476f42d…`), which is the broader goal-foundation brief rather than this diagnostic task's brief. That provenance entry is withdrawn. I have now read the complete correct 20-line brief identified above. The code findings were derived from the actual administrator-capture diff and current administrator-capture plan, so their technical conclusions do not change:

- P1 privileged executable selection directly contradicts correct brief line 6 (“fixed authentication and two helper calls, no arbitrary code input”), line 16's fixed-spindump requirement, and the current plan's fixed capture boundary.
- P1 incomplete `osascript` reap directly contradicts correct brief line 18 (“Always wait/reap exact owned commands”) and the current plan's finite authentication cleanup rule.
- P1 repeatable caller-chosen prefix is governed chiefly by the current plan's explicit one-authentication-session, one-workload, at-most-one-capture/no-retry constraint. Correct brief line 7 also describes one workload collector; nothing in the correct brief authorizes reusable run names or a second attempt.

No other portion of the review is expanded or preapproved by this correction.

## Blocking findings

### P1 — The privileged executable is caller-selected rather than fixed

`goal-foundation-runtime-admin-capture.applescript:4-5` accepts the first argv item as `helperPath`; lines 14 and 19 interpolate that caller-selected executable into both helper commands, and line 20 executes the latter with administrator privileges. `goal-foundation-runtime-admin-capture-run.rb:11-12` accepts any canonical executable path. Lines 31-32 merely hash whichever executable was supplied; they never compare it with the approved helper path or binary SHA.

Consequently, invoking the runner with another canonical executable causes the same authenticated script to run that different executable as root. Quoting prevents shell injection but does not make the executable authorized. This directly violates the plan's fixed-helper/no-arbitrary-code privilege boundary.

Required closure for this one diagnostic: remove caller choice from the privileged command. Hard-code the already reviewed canonical helper binary path and approved binary SHA in AppleScript; in the final privileged shell, compare that fixed path's SHA immediately before executing that same fixed path and refuse on mismatch. The ordinary Ruby controller must reject any mismatch in that same helper path/SHA, the AppleScript SHA, and the approved old-observer binary SHA before requesting authentication, and recheck its frozen pins after readiness. Require the helper and parent directory to remain regular/non-symlink, single-link where applicable, and not group/world writable. A root-owned copy or persistent installer is not required; retain the narrow same-UID hash-open/exec-open race explicitly and verify hashes again after the run.

### P1 — `finish_apple` can abandon confirmed reap after an exit/signal race

`goal-foundation-runtime-admin-capture-run.rb:59-60` permanently sets `apple_cleanup_attempted` before cleanup succeeds. After the first WNOHANG pass, lines 71-75 perform identity then TERM; lines 85-88 do the same before KILL. If `osascript` exits between WNOHANG/identity and `Process.kill`, identity or kill raises (commonly ESRCH). The outer ensure records the exception, but the already-set flag makes every later `finish_apple` call return without another WNOHANG. A now-exited direct child can therefore remain unconfirmed/unreaped, contrary to the bounded exact-child cleanup contract.

Required closure: every identity/signal error path must make a fresh bounded `wait2(..., WNOHANG)` attempt. If the exact direct child has exited, reap and record its real status. If it remains live but its generation cannot be proven, do not signal it; retain `cleanup_incomplete` plus the exact last-known identity and exit the bounded cleanup as failure. Do not let the “attempted” guard suppress the final reap path, and do not replace the original authentication/capture/test result with cleanup success.

### P1 — The one authorized run can be bypassed by choosing a new prefix

The file comment promises one invocation, but `goal-foundation-runtime-admin-capture-run.rb:11-16` accepts any regex-valid `name` and checks uniqueness only for that caller-provided prefix. Line 35 then writes a non-exclusive `${name}-location.json`. Choosing another valid name permits another authentication session, full workload, and capture, violating the explicit one-session/one-workload/one-capture/no-retry constraint.

Required closure: accept exactly one predeclared evidence prefix (for example `goal-foundation-runtime-admin-observed1`) and reject every other value. Before authentication, create the corresponding fixed location/consumption artifact with exclusive-create semantics. Keep it after cancellation, privilege denial, missed fixture, empty capture, or RED so those outcomes consume the single authorized attempt. This is a single-diagnostic gate, not a general authorization ledger.

## Accepted implementation properties

Apart from the three blockers, the actual C implementation is well bounded against the reviewed plan:

- `ticket_parse` accepts exactly six bounded decimal fields with no whitespace tolerance. Capture preserves the fixed nonzero ordinary-user owner while effective UID is root.
- Launcher → RunTests → CLI347 ancestry, generation, UID/RUID, PGID, canonical cwd and `/bin/sh` image are revalidated. Two quiet observations and the 400–1500 ms selector age are enforced; capture performs two complete guards and a final age at most 2000 ms.
- `goal-foundation-runtime-admin-capture.c:319-323` contains the exact single `execve` argv `/usr/sbin/spindump PID 1 100 -onlyTarget -timeline -timelimit 10 -noFile -noBinary` and a fixed minimal environment. It neither reads target argv/environment/memory nor supplies additive process options.
- Both spindump byte streams are separately base64-framed and reconstructable in stream order. The C result records actual wait/exit/signal, I/O completeness, deadline, cleanup, and post-target identity; Ruby refuses missing/nonzero/incomplete transport and leaves report-scope admission pending.
- C tool cleanup uses the monotonic 15-second outer horizon, fresh WNOHANG, exact positive direct-child generation before TERM, two-second grace, generation recheck before KILL, and at most three further seconds of WNOHANG. It never targets the sampled child, RunTests, launcher, or a process group, and reports `cleanup_incomplete` rather than claiming reap.
- AppleScript performs `/usr/bin/true` authentication before selector readiness, runs selection without privilege, quotes each field, uses `altering line endings false`, and preserves a separate helper-result status even though the transport shell itself returns success.
- Ruby starts no product command before validating the ready marker and selector generation/ancestry; waits for the unchanged test normally; retains test, observer, AppleScript, reconstructed sample, identity, OSLog, status and drift records separately; and does not treat diagnostic success as a GREEN test result.

## Evidence assessment and limitations

Root's frozen `goal-foundation-runtime-admin-compile2-process.txt` records C `-Wall -Wextra -Werror` exit 0, Ruby and checks syntax exits 0, and AppleScript compile-only exit 0 against the reviewed hashes. The compiled helper exists at `/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture`, SHA-256 `ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5`; its containing directory is mode 0700, and the file is a single-link regular executable without group/world write.

`goal-foundation-runtime-admin-checks2.log` contains 20 named passing refusal cases; its process record identifies PID 20933, exit 0, no signal, and the same compiled helper SHA. This supports parser/refusal behavior only. It does not prove successful privileged execution, authentication cancellation cleanup, TERM/KILL races, output scope, actual timeline content, or full-workload integration. No authentication or successful privileged capture has occurred, so none is accepted here.

## Scope and verdict

- P0: none.
- P1: three, all actionable above.
- P2: none.

The four-file implementation is not approved for authentication or execution at this revision. Resolve the three P1 findings in the minimum affected files, preserve the actual before/after diff and hashes, rerun only the nonprivileged compile/refusal/syntax checks needed for those bytes, and return the bounded correction for independent delta review. Successful delta review would approve only one diagnostic attempt; actual output scope, same-run lifecycle joins and cleanup remain a later evidence-review gate, not preapproved facts.

No compiler, test, authentication, sampling, Provider, signal, source edit, or process mutation was performed by this reviewer. This review artifact is the only write.
