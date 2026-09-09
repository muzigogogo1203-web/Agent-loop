# A1 administrator attempt2 — independent plan review

Date: 2026-09-07  
Plan reviewed: `goal-foundation-runtime-admin-attempt2-plan.md`, SHA-256 `f70eaa311afa3da889c76a1ac4d5a23c4c0a5e45ae917730c9c170be64548165`  
Spec verdict: **PASS**  
Quality verdict: **PASS**  
Stage verdict: **APPROVED FOR THE BOUNDED LAUNCHER CORRECTION AND ORDINARY-USER REGRESSION; AUTHENTICATION REMAINS BLOCKED UNTIL IMPLEMENTATION REVIEW**

This review relies on the user's renewed explicit authority for one more same-scope diagnostic. It does not approve changed code in advance, authorize a third attempt, or accept any future capture/result.

## Root-cause fit and minimality

Observed1 established a specific diagnostic-launcher failure: the non-`exec` selector command created an owned `/bin/bash` bridge, while Ruby admitted only literal `/bin/sh`. The plan changes the source of that mismatch rather than adding `/bin/bash`, aliases, wildcard images, or relaxed ancestry. Prefixing only the ordinary selector command with shell `exec` replaces the transient shell image with the already pinned helper in the same PID, so the helper should be the direct child of the exact osascript generation. Ruby then requires that direct relationship through full `same_identity` plus the already pinned `/usr/bin/osascript` image.

That is the smallest relevant correction. C selection/capture code, compiled helper, target eligibility, seven identity/path arguments, numeric ticket, privileged hash gate, spindump argv, stream framing, cleanup deadlines, target no-signal rule, Provider/data boundary and product Sources remain unchanged. The plan correctly refuses to reinterpret this as a product-runtime fix.

## Ordinary regression design

The planned regression is sufficiently representative and nonprivileged, subject to its stated fail-closed construction:

- It derives a test-only in-memory AppleScript variant from the actual frozen script and must find/replace exactly once each of the two current administrator statements: the fixed `/usr/bin/true` preflight and final privileged capture return. Before executing the variant, it requires zero remaining `with administrator privileges` text. Failure of either exact replacement or the zero-privilege scan stops the check.
- It retains the real selector-command construction, fixed helper, seven arguments, osascript launch and `auth-ready` behavior. Replacing final capture with `return ticket` means a successful selector could not fall through to privileged capture even if the check's assumptions changed.
- The supplied launcher is a fresh ordinary-user owned process with exact PID/start identity, blocked only on a controller-owned pipe and with no children. It does not execute RunTests. The helper may therefore create its marker and expose its parent relationship but cannot discover an eligible RunTests/CLI347 target or invoke sampling.
- Pre-fix RED has a precise oracle: marker/helper identity exists, but its parent is the observed bridge rather than the exact osascript generation. Post-fix GREEN requires the fixed helper generation to be a direct child of the pinned osascript generation; merely accepting `/bin/bash` cannot pass.
- Ensure closes the dummy launcher's controller pipe, reaps that direct child, and boundedly joins/observes selector and osascript outcomes without signals. Selector refusal after launcher disappearance is expected cleanup evidence, not a product failure. The check uses neither observed1 nor observed2 consumption paths.

The implementation and later evidence reviews must confirm that the variant is passed directly to ordinary `/usr/bin/osascript` without writing over or executing the original privileged script; replacement counts and final privilege-scan results are logged before osascript spawn; all PIDs/generations and direct versus nondirect reap claims are retained; and every cleanup wait is bounded. These are acceptance checks for the specified regression, not new scope.

## Renewed single-attempt boundary

The prior `goal-foundation-runtime-admin-observed1-location.json` remains present and immutable. At review time the new observed2 location is absent. Advancing the runner to the exact fixed name `goal-foundation-runtime-admin-observed2` and using a new fixed O_EXCL location before authentication correctly represents the newly granted one-session budget. Cancellation, rejection, missed target, empty sample or RED must leave that record consumed; no alternate prefix or fallback target may create another attempt.

Immediate synced error logging is an observability correction only: a main error must be written with wall time/class/message before cleanup starts, while the final accumulated error and real statuses remain. It prevents cleanup latency from being mistaken for ongoing authentication without changing cleanup or success criteria.

Before authentication, root must retain the planned pre-fix RED and post-fix GREEN of the privilege-free selector regression, Ruby syntax, AppleScript compile-only, and the early observed1/unknown-prefix/wrong-helper refusals with no observed2 artifact. Then a separate responsibility-separated implementation/delta review must verify the actual bytes, final AppleScript SHA embedded in Ruby, unchanged fixed helper/observer pins, and absence of any administrator statement in the regression variant. The unchanged C20 refusal suite and product tests need not be repeated for this launcher-only correction.

## Findings and limits

- P0: none.
- P1: none.
- P2: none.

Plan approval permits only the two-file launcher/name/logging correction, the new ordinary regression file, and the enumerated nonprivileged checks. It does not permit authentication until those bytes and evidence pass independent review. The later fixed observed2 execution is exactly one ordinary-user full workload and at most one exact target-only spindump capture under the original privacy/process/deadline bounds. Any outcome consumes it. Actual sample scope, target generation, cleanup and causal meaning require a new evidence review; an empty or failed capture cannot trigger a retry.

No probe, compile, authentication, test, workload, sampling, signal, source edit, Provider/data action, or process mutation was performed by this reviewer. This review artifact is the only write.
