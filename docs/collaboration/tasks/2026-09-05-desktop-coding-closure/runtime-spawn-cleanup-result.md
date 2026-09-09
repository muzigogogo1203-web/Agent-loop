# Registered spawn cleanup repair — staged results

## Task 1: observed behavioral RED, 2026-09-10

The exact independently reviewed PRE-RED extraction is applied. It still contains
the old production behavior; this is not a completed fix. Review, patch, report,
and applicability audit are in `.superpowers/sdd/runtime-spawn-cleanup-reconciliation-plan/`.

- Entry remains the 309-input `f355a99d3932bc7cbad4c50d93effcee1cd8748bcd542eaaee8f7bd0d3a86389`
  manifest captured in `runtime-spawn-cleanup-entry.json`; a fresh read-only audit
  at 00:37:27 +08 confirmed no intervening source drift.
- Applied patch SHA-256: `e64c7cee3ebf532df5a76f40ffc3e6355688e35206f260c7a75e309d24c36278`.
- Core target: `d076e9c0262068f29313b0fdc3a6972ea871a31fe7c2468c552c59646e67abec`.
- Frozen CLI tests: `2e9e65746861c703ed85c36dc933949c5f186aebcdb55a052bef17524a7acacd`.
- Source manifest after extraction: `d41651d8ed8820bf6dab998a4e9d84261a7550df530b72c1f36b05636fd2fb57`.
- `swift build --product RunTests`, PID 71262, 00:38:14.065996–00:39:43.416535 +08,
  exit 0, 89.251 seconds captured wall time (Swift reports 85.77 seconds).
  Complete 858-line log SHA `3ce1882b57ee8be74a51a48ee65d739e787a7a2e799ee8062cd7bec4a465c3fb`.
  Existing test-target warnings remain: unused result/weak mutability/deprecated
  C-string initializer/redundant try/require plus toolchain/linker flags. No error
  or warning originates in the new Core/CLI-test delta. This is not the strict App gate.
- `swift run --skip-build RunTests --filter p1f1_065SpawnCleanup`, PID 71577,
  00:40:16.496238–00:40:19.363966 +08, exit 1, 2.798 seconds captured wall time.
  The runner reports 14 test functions, 0 suites, 0.011 seconds and 15 issues.
  Parameter expansion gives 17 cases: exactly 15 intended behavioral failures
  and the two original authority-protection passes. Full 124-line raw log SHA
  `e2b06911636e20b7a0393c742cc9ed70f99887fc0c0f13e1cebacef0b11c5349`.
- Both commands retained the same source manifest. Test binary stayed
  `c44ef5c6231a9094b06a50421d7325719b56daa957411e0d91b38166cf2bf835`
  throughout the test; C fixture stayed
  `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2`.

Root read the entire diagnostic content, using a display-only removal of repeated
Swift private-context type prefixes where needed; raw files remain unmodified.
All 17 resource summaries have zero script violations. Fourteen join three
test-owned value tasks; three missing-task cases join both created tasks. No
common resource/identity requirement failed. These tests create no real child,
descriptor, process discovery, or Darwin signal. The synthetic registry key is
unconditionally removed by the test only after recording the production outcome.

Observed failures match the predeclared matrix:

| Cases | Actual old behavior exposed |
| --- | --- |
| Reconcile, live/unknown final group, two unrelated-probe errors, untyped/EINVAL CONT | Seven cases skip all three production joins and leave one final probe unconsumed |
| Denied KILL followed by disappearance | Exact denied-KILL cause is discarded and registry incorrectly retired |
| Failed/invalid reap, stdout/stderr not EOF, three missing tasks | Seven cases ignore unsuccessful/missing owned results and incorrectly retire registry |
| Denied KILL with live group; initial probe EPERM | Two protection cases correctly retain exact errors and registry without joining |

The full raw entry/build/test/diff records are copied with checked hashes to
`runtime-spawn-cleanup-task1-evidence/`. Task 2 requires independent acceptance of
this exact RED and preserves these test bytes. No GREEN, real-child retry,
integration/full suite, current App, or user acceptance result is claimed yet.

## Task 2: observed helper GREEN, 2026-09-10

Root applied the independently approved patch
`edc8a203dfd567a25d97f1b133e0fe703e16fd2234a28d9ac0528bd892b77a0c`.
Core is `dea1432f701044658b46a33d97c90df390141904fdf10e948b49864d170092d6`;
diagnostics is `6b52ef65584ab6719a0988c7b91e23ecf0e6fc046850afce0cff35bdd7f3bf3c`.
Both test files remain frozen. The 309-input manifest is
`338d09a5c39b4f8c0ec3a8d6de0a3fd987eb4bf802a42f6033ccce30ef49dd49`.

- Ordinary build PID 76668, 01:03:42.008482–01:05:11.332292 +08,
  exit 0, captured wall 89.236497 seconds, Swift reports 88.29 seconds.
  Complete log SHA `b702ec5783472737275f0b668c28b285c4d78586e71ce668f429903e67510b89`.
  Existing test-target/toolchain warnings remain; this is not the strict App gate.
- Identical frozen filter PID 77013, 01:07:48.498823–01:07:52.053781 +08,
  exit 0, captured wall 3.471728 seconds. All 14 functions / 17 expanded cases
  pass in 0.005 seconds. Complete log SHA
  `ea5cb7cd3d3ea9528662690c8f6b11448847545afdeab2ab071725343dbcf4ec`.
- Source manifest remains exact before/after both commands. Test binary is
  `c025c04c9ec2ecd61776dd0b247b29e3f28ab0e6779f7313c06f8a5c15202c37`;
  C fixture remains `4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2`.

Root read the complete helper log. All 17 summaries show zero script violations,
zero unconsumed calls, and every created value task joined by its owner. Production
observations now show the actual three checked joins and final probe when admitted.
Only the complete eligible CONT-EPERM proof reconciles and retires the registry;
all denied authority, unrelated errors, invalid/missing joins, and live/unknown
final-state cases retain their exact causes and registry entry as specified.

The new `runtime-spawn-cleanup-task2-evidence/` archive contains 30 checked files;
manifest SHA `c839fd6b88b793172971dc5fd83fc56c0085606fa1f34bddc72963a4325b5ed7`.
Root independently rehashed all 30. Independent review accepted the observed
GREEN and Task 3 artifact-preparation sequence in `task-2-review.md`; required
normal/exceptional proof negatives are included in that entry. No real-child,
full-suite, App, or product acceptance is claimed by this helper result.

## Task 3: certificate amendment, cancel-race repair, 2026-09-10

Observed RED→GREEN plus isolated real-child proof, completed under the user's
continuation approval. No independent reviewer was available this session;
this is flagged in the acceptance materials rather than claimed.

- PRE-RED (EEC only): raw signal predicate extracted into a private classifier
  actually called by the certificate, retaining the old decision. 23 fixed
  no-child cases produced exactly the 12 predicted issues (the exceptional
  accept plus 11 raw-success cases whose production proof is missing,
  mismatched, or invalid). Build exit 0; frozen filter exit 1.
- GREEN: classifier requires the typed production proof in both paths and adds
  exactly one exceptional classification — final-CONT raw `-1/EPERM` only with
  in-order initial-CONT/KILL success, matching targets, and a matched report
  with `reconciledFinalCONT` plus complete checked proof. Inspector `send` and
  `processGroupExists` now preserve typed `.processSignal(errno)`. A default
  no-op `spawnCleanupObserved` witness (backend→execution) fires once after
  `runRegistered`, outside locks, without decision influence. Classifier
  23/23 and the frozen 17-case helper regression pass with unchanged test
  bytes.
- Isolated real abort465: exit 0, 0.683 s. The run hit the genuine transient
  (initial CONT 0, KILL 0, final CONT -1/EPERM, group 86564); reconciliation
  followed actual joins and final absence. Certificate fully true including
  the new `spawnCleanupProofMatched`; no containment; root removed.
- integration3 (36 tests) exposed one new interaction: the typed-EPERM
  alignment threw inside `terminateProcessGroup` grace probes during the
  post-KILL zombie window in two 065 cold cancellation tests, while later
  direct probes proved complete real cleanup (PID/group ESRCH, waitid
  ECHILD, empty registry). The 075 failure in the same run was this
  session's missing codex PATH entry, not a regression.
- Path A (user-approved): grace wait loops tolerate only the exact typed
  EPERM as still-present; strict final guard, deadlines and
  persistent-authority failure semantics unchanged.
- integration4: 36 tests / 32.448 s / exit 0; both cold tests certify cleanup
  with no retained root; source manifest unchanged before/after.
- full1 (authoritative): 1160 tests / 33 suites / 56.772 s / exit 1, five
  failures — four cliProcessBackend readiness timeouts and Board FD delta 32
  match the documented 09-06 historical load-race signatures, and
  ruminationTerminalCommitFailure passes isolated and in all four prior
  fulls. No unchanged rerun was used to seek green. EEC suite passed
  wholesale inside full1.
- Strict App build exit 0 (35.27 s); `git diff --check` clean.
- Final pins: backend `53816601…`, EEC `59c375c2…`; frozen CLI tests
  `2e9e6574…` and diagnostics `6b52ef65…` unchanged. Complete evidence in
  `runtime-spawn-cleanup-task3-evidence/` (25 files + manifest).
- Remaining open items are independent of this unit: the historical
  full-suite CLI readiness race, A1/A2, packaging and product acceptance.
