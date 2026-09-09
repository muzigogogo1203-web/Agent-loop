# One administrator attempt — stopped before workload

2026-09-07. **Diagnostic failed; no runtime repair or product acceptance.** The single authorized authentication session is consumed and retained. No automatic retry is allowed.

## Actual outcome

Root read the complete independent entry review `goal-foundation-runtime-admin-review-fix1-review.md` (SHA `53ba3e4e0c220e5bf637914ee7bcb12e32015905975ee67a08e8c0e03f0b3695`) before the exact approved invocation. Outer record `goal-foundation-runtime-admin-launch1-process.jsonl` preserves the command, executable/script/review hashes, stdout/stderr paths and real status. Collector PID27408 ran from 00:51:05.796 to 00:53:13.619 +08 and exited93 without a signal. The outer evidence-retention wrapper exited0; this is not collector success.

The initial local authentication returned successfully: only afterward could the fixed AppleScript start the ordinary selector and create its `auth-ready` marker. The collector then rejected the selector's shell bridge before logging `authenticated_ready` or launching any product command. This is not an authentication denial, password error or product-test failure.

| Owned process | PID / start seconds.microseconds | Observed parent / image |
| --- | --- | --- |
| Collector | 27408 / 1788713465.796782 | 27403 / `/usr/bin/ruby` |
| AppleScript | 27418 / 1788713465.951093 | 27408 / `/usr/bin/osascript` |
| Shell bridge | 27524 / 1788713473.426740 | 27418 / `/bin/bash` |
| Selector | 27525 / 1788713473.431243 | 27524 / fixed approved `admin-capture` |

All four identities report UID501; the bridge and selector are in the expected owned ancestry. Ruby's bridge guard allowed only the literal `/bin/sh`, whereas this actual `do shell script` bridge is reported as `/bin/bash`. It therefore raised exactly `RuntimeError: selector shell ancestry mismatch`. The earlier ordinary probe used `exec` and observed a direct helper → osascript relationship; it did not validate the non-exec shell-bridge path. The unsupported shell-image premise is a defect in this diagnostic launcher, not evidence naming the original CLI347 kernel wait. Local `/bin/sh` and `/bin/bash` are distinct regular files, not symlinks or identical-inode aliases; do not claim canonical-path equivalence from their names.

## Failure cleanup and evidence boundary

- Test, native-observer, OSLog, sample stdout/stderr and AppleScript transport files are all zero bytes; no `workload_start`, RunTests spawn, capture-start or spindump result exists. Neither the product workload nor privileged target capture was invoked.
- Selector emitted `{"event":"refused","reason":"missing_target","mono":130517152789083}` after its finite 120-second wait. The missing target is expected because Ruby refused before starting RunTests; it is not another product failure.
- AppleScript reports the ordinary selector's nonzero command exit2 and itself exits1, with no signal. Ruby records its direct-child wait status. No TERM/KILL was used. The final collector record contains exactly the original ancestry error and no source drift.
- The selector identity was read but had not yet been assigned to the collector's admitted-selector field when the guard threw. Consequently this run did not emit a separate `selector_no_longer_present` record. Root's separately retained post-observation `goal-foundation-runtime-admin-observed1-post-identity.json` finds collector, osascript, bridge and selector all absent with BSD errno3/ESRCH at 00:53:45 +08. Absence is not represented as root reaping nondirect children.
- The live `process.log` delayed writing the caught error until the bounded cleanup finished. Earlier user-facing progress inferred continued authentication from the missing admitted-ready event; root corrected this immediately after reading the complete result. No password dialog was inspected or captured.

The immutable location record points to the private retained run directory; its existence consumes this attempt on failure just as on success. Source-before and source-after manifests both contain305 inputs and SHA `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`. Outer helper/observer/script/runner/RunTests/spindump/review pins are unchanged. No product Source, real camp data, installed App, paid Provider, security setting, commit or release was changed by this attempt.

## Next authority and completion gate

This one-attempt plan terminates as failed-before-workload, not a successful capture. Root fully read independent evidence review `goal-foundation-runtime-admin-observed1-evidence-review.md`, SHA `28c03a8d0f88af65efbef94535abed26a4cee729218f5795c925d0da0ea8496c`: evidence integrity PASS, no evidence-integrity P0/P1/P2, diagnostic outcome failed before workload/no sample. This accepts the failure account, not a successful diagnostic or runtime repair. Do not alter or remove the consumed location record, reuse historical PIDs, use cached authentication to retry, or declare A1/A2 open.

A further attempt needs renewed explicit authority. Before it, the smallest corrective preparation is an ordinary-user shell-bridge contract check matching the real non-exec selector command, followed by a narrowly reviewed identity guard and immediate failure logging; preserve exact generation, UID, parent and helper-image checks. This document does not implement or approve those changes and does not authorize another authentication session, full run or sample. The original runtime failure remains unresolved.
