# A1 administrator capture review-fix1 — independent delta review

Date: 2026-09-07  
Scope: only closure of the three P1 findings in `goal-foundation-runtime-admin-implementation-review.md` plus defects introduced by this two-file delta  
Spec verdict: **PASS**  
Quality verdict: **PASS**  
Entry verdict: **APPROVED FOR THE SINGLE AUTHORIZED DIAGNOSTIC ATTEMPT ONLY**

This is not approval of actual capture scope/content, a root-cause conclusion, a runtime repair, a GREEN test result, or an A1/A2 gate. Those remain downstream evidence-review questions after the one attempt.

## Frozen delta and evidence

- Actual two-file delta `goal-foundation-runtime-admin-review-fix1.diff`, 267 lines, SHA-256 `e86feb56be808f6734819fe40da2fee707351e4628c886ac359c48bb2d8f6cb8`, read completely.
- Exact preimages match the blocked whole review: Ruby `a21bcb5eadbf463e1afc456183290f19d72a6d95a11e134866836bf16737c781`; AppleScript `a1575713abe83e83ce9baa7ddf26f81ed888b56e8a39742935ba7dbc3dc2a1a1`.
- Current corrected files match the handoff: Ruby `a572d0242d77305827b4e0d7e9e2631202567be7918260a204c92df105fc272f`; AppleScript `bde94fd018f73106b7b58481a70733d8989d5fdf88e24725fd4dfe8671973e6b`.
- Accepted out-of-delta files remain unchanged: C `8d1a9a1a7a3f6be783844cef2590da9d73777a08bf7cfea77d0e3dee5f04fabd`; refusal checks `3c42024f1c10b0e03adfd3e79c5b33654bc6fe6f7b01f8cc17ecb7481db37db7`; old observer source `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`; old runner `74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417`.
- Root evidence `goal-foundation-runtime-admin-review-fix1-process.txt` records Ruby syntax PID 26390 exit 0 and AppleScript compile-only PID 26403 exit 0. Wrong-prefix, wrong-helper and wrong-observer processes 26406/26411/26416 each exited 1 with the exact first abort; the log and process record show no approved-prefix artifact and no authentication. The fixed approved location artifact is still absent at review time.

These checks establish syntax and early refusal only. They do not establish successful authentication, helper execution, real spindump output, or cleanup behavior under a live workload.

## P1 closure

### 1. Privileged executable is now fixed — CLOSED

The runner accepts only the exact helper path `/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture`, binary SHA-256 `ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5`, exact old-observer path/SHA, and the corrected AppleScript SHA. It verifies canonical path, ordinary-user ownership, regular/non-symlink and single-link file identity, executable status where required, and no group/world write on each file and containing directory. Checks occur before artifacts/authentication, immediately before spawning AppleScript, after authenticated readiness before workload, and after the run.

AppleScript no longer accepts an executable argument. It hard-codes the same helper path and SHA. Its final privileged shell computes SHA-256 for that fixed path and `exec`s that same fixed path only on exact equality; mismatch exits 65 and leaves an explicit helper-result failure. The seven caller fields remain quoted identity/path data, not executable selection. This closes the arbitrary-root-executable defect without a root-owned installer/copy. The already accepted narrow same-UID hash-open/exec-open race remains documented and requires post-run pin verification; it is not misrepresented as atomic.

### 2. `osascript` raced exit is always given a bounded final reap — CLOSED

`finish_apple` now uses `apple_cleanup_attempted` only to suppress repeated signal sequences. Identity or TERM/KILL exceptions are retained, then an `ensure` block always attempts `wait2(..., WNOHANG)` until one shared three-second monotonic deadline. EINTR is recorded and retried only inside that deadline; other reap errors remain explicit. A raced natural exit can therefore be reaped and its real status recorded. If reap cannot be confirmed, `cleanup_incomplete` and the pinned identity remain, diagnostic errors remain nonempty, and no success is fabricated. Re-entry can make one final WNOHANG observation but cannot extend the original deadline or signal again.

No new signal target was introduced: TERM/KILL remain limited to the exact owned `osascript` generation. The accepted C-side 15+2+3 cleanup and no-signal rule for target/RunTests/groups are untouched.

### 3. Single authorized attempt is enforced — CLOSED

The runner accepts only `goal-foundation-runtime-admin-observed1`; another valid-looking name aborts before artifacts or authentication. After all argument, path, permission, SHA, 305-input and old-source checks, but still before authentication, it exclusively creates the fixed `goal-foundation-runtime-admin-observed1-location.json`. The initial reserved record is retained even if private-run-directory setup or any later authentication/capture/workload step fails, so cancellation, denial, missed fixture, empty capture and RED all consume the attempt. Reuse of the same fixed entry fails both the presence check and `O_EXCL`; caller-selected prefixes no longer bypass it.

## Delta quality and remaining boundary

No P0/P1/P2 defect was introduced by this delta. The hash-gate failure is fail-closed; it cannot silently substitute a helper. The early wrong-argument checks precede the consumption artifact, while the exact approved invocation consumes it before showing authentication. Cleanup errors survive separately from test and sampling status. The delta does not alter C, the 20 refusal checks, product Sources, sampling argv, target ownership, deadlines, Provider/data access, or signal authority.

The single diagnostic may now enter only through the exact reviewed command and artifacts. The controller must still freeze the current helper/script/observer/RunTests/spindump hashes and retain command/stdout/stderr/exit evidence. Afterward, independent evidence review must reject unexpected sampled processes, malformed/incomplete/nonzero output, target-generation mismatch, incomplete cleanup, source drift, or a second-attempt artifact. A successful transport remains only `capture_admission=PENDING` until that review.

- P0: none.
- P1: none; all three prior P1 findings are closed.
- P2: none.

No authentication, workload, compiler, test, sampling, signal, source modification, or process mutation was performed by this reviewer. This review artifact is the only write.
