# A1 administrator observed1 — independent failure-evidence review

Date: 2026-09-07  
Evidence-integrity verdict: **PASS**  
Diagnostic-attempt outcome: **FAIL-CLOSED BEFORE WORKLOAD; NO SAMPLE EXISTS**  
Authority outcome: **THE SINGLE SESSION IS CONSUMED; NO RETRY/AUTHENTICATION/WORKLOAD/SAMPLE IS AUTHORIZED**

This accepts the accuracy and completeness of the retained failure account. It does not accept a kernel-wait capture, identify the original CLI347/runtime root cause, repair product code, or clear A1/A2/product gates.

## Reviewed identity and evidence set

- Entry review `goal-foundation-runtime-admin-review-fix1-review.md`, SHA-256 `53ba3e4e0c220e5bf637914ee7bcb12e32015905975ee67a08e8c0e03f0b3695`, had been read by root before execution.
- Immutable one-use location record SHA-256 `f9b8be652a03100cb62e887765eaf4b985be9851c3f5be6fec77d6c89b0b374f` points to `/private/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-admin-goal-foundation-runtime-admin-observed1-20260907-27408-o8aq5`, a mode-0700 UID-501 directory. Its retained files are mode 0600.
- Outer process/stdout/stderr hashes are respectively `8efed483d0005da0f41145ad43bee066f2a617d3d8abe0ebda0d41155891e6e2`, `e11e0dc98ffeee6d43a990f3f21f508d349dc58f765e1e946147d7021cd38766`, and the empty-file hash `e3b0c442…`. Post-identity evidence SHA-256 is `e80538a5790328d0c0469897d68ccc6b3131a87e96dfd3593a23bee8b0bdb018`.
- I read the complete retained `process.log`, `identity.log`, `selector.ndjson`, `auth-ready`, `apple-stderr.log`, `pins.json`, outer launch records, zero-length channel files, both 305-line source manifests, post-identity record, and `goal-foundation-runtime-admin-observed1-result.md` (SHA-256 `9182207371ba4301bada11516d8202fe29eaf54ee05f29b216905d14eef2a21a`).

## Supported sequence

1. The outer wrapper recorded the exact approved command and hashes at `2026-09-07T00:51:05.796490000+08:00`, spawned collector PID 27408 at `00:51:05.798892`, and later obtained its direct-child status: exit 93, no signal, at `00:53:13.619287`. Outer before/after pin maps are identical and `drift` is empty.
2. Collector PID 27408 recorded the administrator preflight request at `00:51:05.950264`. The fixed selector PID 27525 was then created and wrote the exclusive `auth-ready` record. Under the reviewed AppleScript ordering, this is evidence that `/usr/bin/true` with administrator privileges returned successfully before selector execution. It does **not** establish whether macOS displayed a fresh password prompt or reused its same-script grace; no password UI or credential material was captured.
3. Exact ordinary-user identities form the observed chain: collector 27408 → osascript 27418 → shell bridge 27524 → selector 27525. Every row is UID 501 with pinned start time. The selector path is the fixed approved `admin-capture` helper. The bridge's actual resolved process path is `/bin/bash`, PPID 27418; it is not the collector's admitted `/bin/sh` literal.
4. At `goal-foundation-runtime-admin-capture-run.rb:249`, the runner permits the indirect bridge only when its path is exactly `/bin/sh`. It therefore raised the exact retained `RuntimeError: selector shell ancestry mismatch` before assigning `selector_identity`, logging `authenticated_ready`, or executing `workload_start`.
5. With no RunTests child ever created, selector 27525 remained inside its planned finite search and eventually emitted exactly `refused/missing_target` after about 120.003 seconds from its first retained identity observation. That is the expected consequence of the launcher refusal, not a product-test failure. The ordinary selector command returned 2; AppleScript recorded a nonzero-command execution error and osascript exited 1 without a signal.
6. The collector's `status` record for direct child osascript is a real `wait2` result and therefore confirms that the collector reaped osascript. The outer status similarly confirms that the wrapper reaped the collector. The selector emitted its own terminal refusal, and the later post-identity check reports ESRCH for collector, osascript, bridge and selector. For the nondirect bridge/selector, ESRCH establishes only that those PID generations were no longer present at `00:53:45`; it does not prove which process reaped them.

The retained process log contains no TERM/KILL or cleanup-incomplete event. Given the reviewed only-signal path and natural osascript status, the evidence records no diagnostic signal use. This is not broadened into a claim about unobserved external actors.

## Zero-workload and zero-sampling boundary

The following retained files are exactly zero bytes: `test.log`, `observer.log`, `observer-stderr.log`, `events.log`, `events-stderr.log`, `apple.log`, `sample-stdout.log`, and `sample-stderr.log`. There is no `workload_start`, `workload_spawned`, `capture_started`, `spindump_started`, `spindump_result`, helper-result frame, or OSLog collection record.

Therefore:

- no `swift run RunTests` workload or native observer was started;
- the privileged capture helper path was never entered and `/usr/sbin/spindump` was not invoked;
- no target process was sampled and there is no report whose process scope, timeline, kernel wait, or cleanup can be admitted;
- the attempt supplies no new evidence about the original CLI346/347/372 failure mechanism.

Because no product workload began, the empty test file is “not run,” not a passing or failing product test. Because no sampling began, the empty sample files are absence of a capture, not evidence that the target had no stack or output.

## Frozen inputs, privacy, and one-use state

The before/after source manifests are byte-identical, contain 305 entries, and each hashes to `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`. Inner and outer records preserve the reviewed runner, AppleScript, helper, observer, C source, old observer/runner, RunTests and spindump identities; the outer pin comparison reports no drift.

No evidence shows a test launch, Provider call, camp/database read, App operation, installation, security-setting change, commit, release, target signal or spindump report. The administrator action was limited to the successful fixed preflight; the subsequent selector was ordinary-user. The password itself and authentication UI were not observed or stored.

The fixed `goal-foundation-runtime-admin-observed1-location.json` exists and was not removed. Under the reviewed O_EXCL gate, it irreversibly consumes this authorized attempt for the unchanged artifacts. A different prefix is rejected by the reviewed runner. No cached-authentication reuse or automatic retry is permitted.

## Result-document review

`goal-foundation-runtime-admin-observed1-result.md` is evidence-conservative and does not overclaim. Its authentication wording is properly about successful return, not password failure; its `/bin/bash` bridge identity and exact runner refusal match the retained rows; it distinguishes direct-child wait status from later nondirect-process absence; it states zero workload/zero sample; and it leaves the original runtime cause unresolved. A separate read-only local stat check also confirms `/bin/sh` and `/bin/bash` are distinct regular files with different inode, size and SHA-256, so the result correctly avoids claiming symlink/canonical equivalence.

Its proposed smallest future preparation is explicitly non-authorizing. This evidence review neither approves that correction nor permits another attempt. Renewed authentication, workload or sampling would require new explicit user authority plus separately reviewed bounded changes.

## Final findings

- P0: none in evidence integrity.
- P1: none in evidence integrity. The attempt itself failed because the diagnostic launcher encoded an unsupported literal shell-bridge premise; that fact is retained rather than repaired or retried.
- P2: none.

The accepted terminal state is: administrator preflight success; owned selector created; fail-closed shell-bridge mismatch; selector finite `missing_target`; collector exit 93; no workload; no sample; inputs unchanged; single attempt consumed; original runtime root cause still unknown.

No probe, compiler, test, authentication, sampling, signal, source edit, Provider/data action, or process mutation was performed by this reviewer. This review artifact is the only write.
