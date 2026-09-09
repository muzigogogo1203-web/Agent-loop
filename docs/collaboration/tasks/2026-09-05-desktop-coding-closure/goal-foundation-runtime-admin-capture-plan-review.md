# Independent review — one administrator target-only capture plan

Reviewed 2026-09-07. Reviewer: responsibility-separated `goal_remaining_migration_review`; neither implementer nor execution owner.

## Verdict and boundary

**PASS for the amended bounded plan: 0 P0 / 0 P1 / 0 P2 open.** No architecture-level defect blocks preparation of the four named task-directory helpers. The two concrete lifecycle/owner concerns raised during review have been incorporated into the current plan and are closed at the plan level.

This is not approval of helper source, authentication, a sampling run, product behavior, or A1 acceptance. Root must retain compilation/refusal-check evidence and obtain the required implementation review before the one authentication/workload attempt. The runtime gate remains RED and A2 remains closed. This reviewer ran no compiler, test, sampler, authentication, elevated command or signal, changed no Source/plan, and dispatched no subagent.

## Inputs and identity

The complete amended plan and relevant existing checkpoint, observer implementation/interface, runner and its review were read. Review followed the requesting-code-review and verification-before-completion disciplines: actual files and primary API documentation, not a prediction of successful execution.

- Checkout `/Users/muzi/Agent-loop`, branch `codex/desktop-coding-closure-20260905`, HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f` verified.
- Reviewed plan SHA-256: `c295e817bb34f56828429da7c2bb5ef08e8435c93d22a4ebf994baff163aa3e3`.
- Initial plan inspected before the amendments: `531747b34629623f210dc6b63cc2ff227f8d67d1e4f336dd535df30ba9c0a72d`.
- Existing observer C: `027c041baca6fa1f34f9ebae77d7da8eec3e5aea583e9bb665ccfda4a9db0bcf`; old runner: `74f5a90ac5b94c5631bb9b8f1a65584b3583fe0255cf3aedf12ed7b740e69417`.
- Manifest `goal-foundation-runtime-child-observed1-source.sha256`: `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`. Current exact inventory and contents verified: 305 regular files, no missing/extra path or hash mismatch. Inventory means regular files from `Dir.glob('Sources/**/*') + Dir.glob('scripts/**/*') + Package.swift + Package.resolved`, not an unlike `rg --files Sources` enumeration.

## Findings resolved in the amended plan

1. **P2 — authentication deadline previously lacked a precise cleanup boundary.** Merely bounding the ready wait at 180 seconds would not bound an inherited unconditional `ensure` wait on osascript. The added Global constraints now require matching the launcher's own still-unreaped osascript generation before termination, exact reap/error retention, no test signals and no workload after authentication expiry. A remaining selector is either joined at its finite deadline or stopped only with retained exact ownership/generation. This closes the plan defect without introducing a general process-killing facility.
2. **P2 — privileged reuse must not reinterpret the target owner as root.** Existing observer ownership helpers use the observer's ordinary-user identity. Blind reuse in an elevated capture path would reject the intended user processes/directories or validate the wrong owner. Global constraints now explicitly bind every such comparison to the fixed nonzero ordinary UID. The same amendment distinguishes a post-capture exited/unavailable target (unknown with the actual error) from a live mismatched generation (identity failure); neither permits fabrication of a matching post-check.

## Scope and practical feasibility

The plan limits the permission increase to one fixed spindump invocation against a fresh CLI347 descendant of the actual launcher/RunTests chain. Ordinary-user selection and the product workload remain unprivileged. It prohibits arbitrary commands, target substitution, retry, user-data reads, argv/environment reads, debugger control, security-policy changes and test-process signals. These boundaries match the supplied user authorization; they do not turn it into general administrator access.

Apple documents an authentication grace period confined to the same AppleScript instance. The proposed initial privileged `/usr/bin/true`, ordinary selector and later privileged capture remain inside that instance; the selector's 120-second limit fits the documented five-minute window. This is a feasible authorization handoff, not a promise that the host will grant sampling capability. Authentication cancellation, privilege denial and expired identity must remain explicit terminal outcomes. [AppleScript command reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)

The local `/usr/share/man/man8/spindump.8` confirms that `-onlyTarget` restricts the sampled process set; supplying a PID alone does not. The fixed arguments correctly request one-second sampling at 100-ms intervals, target-only timeline output, no binary payload and a ten-second tool limit. That limit also covers report work and can expire without a saved report; it neither extends the fixture deadline nor guarantees a usable stack.

The six-integer selector ticket is an untrusted candidate identity locator, not an authentication credential or durable ownership capability. The planned privileged guard independently revalidates the fixed launcher, RunTests and target generations, UID/real UID, ancestry, groups, canonical directory and executable identities. Double checking reduces but cannot eliminate the public PID check-to-kernel-use race; the plan accurately states that limit. No broader or historical target is an acceptable fallback.

The age windows deliberately trade capture success for a bounded opportunity. Authentication handoff, tool startup or normal fixture cleanup may make that opportunity disappear. A valid pre-check followed by target exit cannot be reported as proven identity throughout capture. Preserve partial evidence and classify the missing post-check honestly; do not stretch the fixture, signal it or rerun to manufacture success.

## Concrete implementation-review checks, not additional plan blockers

- Trace fixed ordinary UID through every reused ownership helper in privileged mode; inspect the actual new-file diff instead of treating inclusion of the reviewed old C as approval of its new calling context.
- Validate the exclusive private auth-ready marker and live owned handoff before the sole workload launch. A marker or ticket alone is not proof that authentication succeeded. Preserve one selector, one workload and at most one fixed sampling invocation on all failure paths.
- Preserve byte-complete sampler stdout and stderr and the actual exit/signal separately from AppleScript transport status. AppleScript's default output conversion and nonzero-command error behavior mean that merely retaining its returned success/error string is insufficient. A fixed byte-preserving transport or safe already-open output channels can meet the plan; no general privileged file-writing interface is required. [AppleScript command reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)
- Inspect exact owned-child reaping through authentication timeout, selector failure, sampling timeout and collector/postprocessing error paths. Do not treat a ten-second report deadline as evidence that cleanup actually occurred.
- Require refusal checks to exercise their claimed parser/identity/path reasons and show no sampling side effect, rather than passing every case solely because the checks run without effective UID 0. Do not introduce a privileged-check bypass for testing.
- Retain all complete test/native-observer/scoped-OSLog/capture outputs and explicit statuses. Capture success is diagnostic evidence only; timing perturbation, a missed stack, missing fields and the product test result remain separate facts.

## Closure

The amended plan is proportionate and implementable within the four-file diagnostic scope. No additional diagnostic framework, production repair or repeated experiment is required by this review. Source approval and the one execution/evidence review remain separate gates. The only reviewer write is this artifact; the frozen plan, old observer/runner and exact 305-input inventory were rechecked after writing.
