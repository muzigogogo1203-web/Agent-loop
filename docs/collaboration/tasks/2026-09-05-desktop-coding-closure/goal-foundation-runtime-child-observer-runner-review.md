# External child observer workload runner — independent implementation review

Reviewed `goal-foundation-runtime-child-observer-run.rb`, SHA-256 `db8cd219fccd55e86eb8e873a77569600b02109bb32323634635597aa3599d00`, against the accepted observer plan and the local default Ruby runtime. This reviewer did not author or execute the runner/helper/self-check/workload, compile anything, run tests, or change Source.

## Verdict

- Scope/specification: **CHANGES REQUIRED**
- Implementation quality: **CHANGES REQUIRED**
- Findings: **0 P0 / 1 P1 / 2 P2**

Do not execute the runner until these changes are applied and independently re-reviewed. `ruby -c` alone cannot detect the P1.

## Findings

### P1 — the post-test evidence path is both incompatible with local Ruby and not exception-safe

Line 69 calls `frozen.filter_map`. The machine's default `ruby` is 2.6.10 and reports no `filter_map` Array/Enumerable method. Syntax checking still succeeds, but an actual run would raise `NoMethodError` only after the runner has waited for RunTests at line 55. It would then skip OSLog capture, `meta.close`, and every `/tmp` raw-file copy at lines 77-114. This can discard the unique original stdout and process record from the one authorized workload even though the test itself completed normally.

Replace `filter_map` with a Ruby-2.6-compatible explicit loop. Also make the whole post-spawn lifecycle fail-safe, not just this known exception: once `pid` exists, always wait for that exact test PID before observer joining or post-processing; after the test wait, an `ensure` must append any post-processing failure when possible, close/flush the process record, and attempt retention of every unique raw tempfile before propagating a nonzero diagnostic status. Retention errors must be reported individually and must not mask the already captured test exit/signal or original exception. This does not authorize signaling the test or observer, and observer setup/failure must continue to leave RunTests on its normal cleanup path.

### P2 — `--last 10m` can be accepted even when it no longer covers the full invocation

Lines 79-110 correctly filter admitted events by exact PID/subsystem/category and the inclusive invocation timestamps, but `capture_ok` never proves that the `--last 10m` retrieval horizon began before `invocation_start`. If the unchanged command or observer join lasts more than ten minutes, early same-run events can be absent while logger metadata, admitted rows and `capture_ok` remain internally consistent.

Record the wall-clock instant immediately before spawning `/usr/bin/log`; calculate and retain whether its ten-minute lower bound covers `invocation_start`; require that condition in `capture_ok`. A horizon miss is an explicit incomplete-capture gap with no rerun. Using an exact supported start/end retrieval instead is also acceptable, provided the unchanged raw output and existing post-filter remain retained.

### P2 — two subprocess statuses are consumed without complete status metadata

Lines 40-45 use the identity helper's `Process::Status`, but do not retain its exit status or terminating signal; on failure, only the generic `identity handshake failed` survives. Lines 82-111 retain only the log capture exit status, not its terminating signal. Record `identity_exit`/`identity_signal` immediately after `capture3`, before JSON parsing can raise, and `capture_exit`/`capture_signal` after the log wait. This preserves independent status evidence without expanding process access or workload scope.

## Accepted control flow and boundaries

- The runner creates the frozen 305-input manifest before spawn, requires a unique evidence prefix, pins the reviewed helper and observer-source hashes, and rechecks source/helper/binary drift after the command.
- `Process.spawn` leaves the test command under normal ownership. Observer identity/launch errors are caught without cancellation, and the current normal path waits for the exact test PID before joining the observer. Test and observer exit/signal values remain separate, and diagnostic failure has its own exit code rather than converting a RED test to GREEN.
- The immediate identity handshake binds PID to BSD start generation, launcher PPID, UID and a birth interval before passing the fixed PID/generation plus pinned RunTests image and canonical fixture parent to the helper. Final target admission remains explicitly dependent on independent same-run cleanup and OSLog joins, not observer exit alone.
- Complete stdout, observer, identity and OSLog streams use unique tempfiles; the exact invocation interval and precise OSLog admission checks match the earlier accepted design apart from the retrieval-horizon finding above.
- No signal, debugger, FD read/duplication, Provider, App, real-data or user-payload operation is present. The runner does not change test concurrency, deadlines, Source, package or product behavior.

This review does not cover the separately owned C helper, approve its self-check or workload execution, accept any future capture, diagnose or repair the runtime failure, clear the retained RED gates, complete A1, or open A2.

## Closure review — revised runner

Re-reviewed the complete actual diff from retained preimage `goal-foundation-runtime-child-observer-run-before-fix1.rb`, SHA-256 `db8cd219fccd55e86eb8e873a77569600b02109bb32323634635597aa3599d00`, to current `goal-foundation-runtime-child-observer-run.rb`, SHA-256 `74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417`.

- Scope/specification: **PASS**
- Implementation quality: **PASS**
- Remaining findings in this bounded runner revision: **0 P0 / 0 P1 / 0 P2**

The P1 is closed: lines 73-78 use a Ruby-2.6-compatible explicit loop, and lines 28-30 plus 123-163 establish a fail-fast outer lifecycle guard. On every exception path after test spawn, the guard waits for the exact test PID before the exact observer PID, records available exit/signal or a distinct wait error, closes the metadata stream, and independently attempts retention of every raw tempfile. Observer or post-processing failure cannot signal, cancel, or bypass the unchanged test command's normal cleanup.

Both P2 findings are closed. Lines 87-89 retain the wall-clock capture request and explicit ten-minute-horizon predicate, and line 119 makes that predicate a prerequisite of `capture_ok`. Lines 43-44 retain identity-helper exit and signal before JSON parsing, while lines 90-92 retain log-capture exit and signal before NDJSON parsing. Diagnostic, drift, capture, observer, and test outcomes remain distinguishable; a diagnostic failure cannot turn a RED workload GREEN.

This closure is source-level approval to proceed with the separately authorized bounded runner use only. The reviewer did not execute or syntax-check the revised runner, helper, self-check, workload, compiler, tests, or OSLog capture. Root-reported `ruby -c` success is not substituted for execution evidence. The closure does not review the separately owned C helper, accept its compile/self-check, approve any produced observation as valid, authorize a rerun, diagnose or repair the runtime failure, clear retained RED gates, complete A1, or open A2.
