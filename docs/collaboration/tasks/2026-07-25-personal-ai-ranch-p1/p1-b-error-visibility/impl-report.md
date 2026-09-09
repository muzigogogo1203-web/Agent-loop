# B-03 Bounded Implementation Report

Date: 2026-08-15

## Authorized changes applied

- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
  - Replaced only the two public `Orchestrator.startMission` halted-path
    expectations with `UserVisibleOperationError` assertions for the supplied
    trace ID, `.missionStart`, and the public representation of fixed
    `.missionIndex` scope (`.mission` / `"mission_index"`).
  - Preserved the package `startConfirmedProposal` `KernelHaltedError`
    expectation.
- `Sources/AgentLoopTestSuite/DurableWorkTests.swift`
  - Replaced only the stale adapter-local transaction source gate with the
    reviewed ownership chain: Adapter -> `inputWorkflowController.delete` ->
    `InputWorkflowPorts.live` ->
    `AppDatabase.deleteIngestionAtomically`, with the Core transaction's
    active-work/status/scope proof.
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
  - Applied only the Revision11-reviewed manifest-gate correction: the
    64-path allowlist includes the two already-authorized B-02 test paths;
    A3 checks 48 raw / 42 successor / 157 live entries; A4 checks 45 P1-B /
    161 unaffected / 10 new paths. `ScheduleMath.swift` remains an A3-only
    historical exclusion.

## Verification

- Targeted authoritative command passed:

  ```text
  swift run RunTests --filter 'startupBootstrapGateBlocksDispatchUntilRecoveryCompletes|directMissionAndProposalStartsAreRejectedWhileHalted|activeRuminationFencesDiscardDeleteAndArchiveRaces'
  ```

  Evidence: `b02-targeted-verify.log`, SHA-256
  `59a672ef37cbb73b9be01785309bcfcbfde111db01f3416b0f7ecd65628a53b1`.

- The Revision11/Review12 focused manifest command passed:

  ```text
  swift run RunTests --filter 'a3Revision02EntryBoundaryRemainsByteExact|broadcastFailureDoesNotRewriteStartedFire'
  ```

  Review12 independently recorded two passing tests in 0.686 seconds, with
  frozen planning inputs unchanged.

- The required unfiltered authoritative command now passes:

  ```text
  P1B_TERMINAL_AST_CORPUS=<fresh disposable directory> swift run RunTests
  ```

  It completed 714 tests in seven suites successfully in 45.047 seconds.
  Complete stdout/stderr was captured at the unique local evidence path
  `/tmp/p1b-r11-authoritative-verify.XXXXXX.log` during this execution.

## Remaining review boundary

The former B-03 source-gate and cancellation-bound failures are green in the
authoritative suite; no timeout was relaxed. P1-B still requires the separate,
responsibility-isolated implementation review and acceptance record specified
by plan §15. No production, scanner, manifest-byte, or declaration-count
change was made for B-03.

## Revision16 root-cause closure

`Planner` now constructs the durable provider stream from a Dispatch global
queue and returns through an intentionally non-cancellation-reactive
continuation. This keeps a synchronous, cancellation-ignoring provider from
occupying a cooperative executor thread while preserving the Supervisor's
existing cancellation and deadline ownership.

The bounded verification command passed all four relevant gates, including
the strict shutdown bound. The authoritative command also passed all 714 tests
in seven suites in 44.899 seconds; framed evidence is `verify.log` with
SHA-256 `b31d645d92209ad0a79d6adc8da9134090502ab04ba87afc0f1faf65de29632b`.

## Revision17 application dependency closure

Acceptance20 correctly identified a remaining ownership violation: the
Application target directly imported `Security` and `CryptoKit` to create the
OAuth verifier and PKCE challenge. Revision17 moves those platform primitives
to the already-approved Core owner, `OpenAIOAuthSession.swift`, as
`OAuthPKCEPrimitives`. `RuntimeProfileWorkflowController.swift` now imports
only `Foundation` and `AgentLoopCore`, delegates random-secret creation and
challenge derivation to Core, and preserves its existing boundary error mapping.

No test declarations, scanner/descriptor/seam, manifest inventory, or
allowlist path changed; the 66-path and A3/A4 historical counts therefore
remain frozen. Targeted OAuth regression tests passed (3 tests, 0.010 seconds),
and the fresh framed authoritative run passed all 714 tests in seven suites in
44.899 seconds. Complete stdout/stderr, command, cwd, disposable corpus path,
exit status, and sentinel are captured in `verify.log`, SHA-256
`b31d645d92209ad0a79d6adc8da9134090502ab04ba87afc0f1faf65de29632b`.

## Post-Acceptance23 evidence synchronization

The preceding Revision17 paragraph's `b31d645d...` / 44.899-second reference
is a stale pre-Acceptance23 evidence pointer. The final accepted authority is
Review22 plus Acceptance23 and the framed `verify.log` at SHA-256
`6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87`:
714/714 tests in seven suites passed after 43.614 seconds, with `EXIT: 0` and
`RESULT: PASSED`.

This appended correction supersedes only the current evidence pointer. It does
not rewrite any immutable historical result and changes no product, test,
schema, migration, Package, or runtime behavior.
