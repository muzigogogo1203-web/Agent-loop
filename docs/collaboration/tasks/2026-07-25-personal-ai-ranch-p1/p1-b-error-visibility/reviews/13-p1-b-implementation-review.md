# P1-B Responsibility-Isolated Implementation Review13

> Date: 2026-08-15
>
> Reviewer: independent read-only implementation review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**

## Boundary and frozen inputs

This review changed no product source, planning input, manifest, scanner,
descriptor, declaration, or evidence-log byte.  It writes only this review
artifact and preserves the pre-existing dirty working tree.

The current Revision11 planning inputs are the same values recorded by
immutable Review12:

```text
858313a8317debff9f26cce8d230edeb1657c9fbb3c7b0faf2cc35317bf7d739  plan.md
c3156fb6e93d4dfb4aedcb194a0a49636d8ceb896e3561cba3bc7cef532b2c86  try-question-mark-inventory.md
66daabaf334f41cc65650cc152e3110b6474313f948ec27233f53d62a0eff881  blocked.md
```

Review12 is present and says `APPROVED — 0 P0 / 0 P1 / 0 P2`.  The current
three status labels consistently name Revision11 / Review12. `git diff
--check` exits zero.

## Independent scope and ownership check

`a3P1BExactAllowlist()` contains exactly 64 unique literals, including the
two approved B-02 test paths. The live source gate independently passed the
following focused command in this review:

```text
swift run RunTests --filter 'a3Revision02EntryBoundaryRemainsByteExact|broadcastFailureDoesNotRewriteStartedFire|shutdownWithCancellationIgnoringProviderReturnsBoundedly|startupBootstrapGateBlocksDispatchUntilRecoveryCompletes|directMissionAndProposalStartsAreRejectedWhileHalted|activeRuminationFencesDiscardDeleteAndArchiveRaces'
```

It exited zero with six passing tests in one suite (0.705 seconds). In
particular, it exercised the one-second cancellation bound without relaxing
it.

The B-03 arithmetic is implemented as required: A3 has 48 raw members, six
historical A4-slice exclusions, 42 successors, and 157 live rows; A4 has 45
P1-B members, 161 unaffected rows, and ten new paths. The two B-02 paths occur
in both immutable manifests. `ScheduleMath.swift` occurs in the A3 manifest
and not in the A4 manifest. Its presence in the source-gate's
`a4HistoricalManifestExclusions` set is an A3-live-row exclusion for the
historical A4 implementation slice; it is not an assertion that the path is an
A4 manifest member.

The B-02 source assertions preserve the approved ownership boundary:

- the public direct start catches `UserVisibleOperationError` and verifies the
  supplied trace, `.missionStart`, and fixed mission-index scope;
- the package confirmed-proposal path remains a `KernelHaltedError` assertion;
- the Adapter delegates deletion to `inputWorkflowController.delete`, the live
  input port delegates to `database.deleteIngestionAtomically`, and the Core
  method retains the transactional active-work/status/scope checks. The
  Adapter no longer owns `db.pool.write`.

No scope, test-declaration, scanner, descriptor, or production-owner drift was
found in this bounded B-02/B-03 delta.

## Finding

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | None. |
| P1 | 1 | The claimed unfiltered authoritative result is not retained in the required reproducible evidence form. `impl-report.md` names only a placeholder command and a `/tmp/p1b-r11-authoritative-verify.XXXXXX.log` path. That file's content does show `714 tests in 7 suites passed after 45.047 seconds`, but it has no command, cwd, `P1B_TERMINAL_AST_CORPUS` value/provenance, exit-status, or terminal sentinel. Its literal `XXXXXX` filename also does not establish the claimed unique fresh evidence path. The mandated task `verify.log` instead records the earlier red 714/7 run. Plan §14 expressly requires complete stdout/stderr with command, cwd, environment boundary, exit status, and terminal sentinel; a post-hoc report plus an unframed `/tmp` transcript does not satisfy that gate. |
| P2 | 0 | None. |

## Decision

**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2.**

The implementation itself and all independently rerun focused gates are
consistent with the bounded 64-path correction, but P1-B acceptance may **not**
proceed yet. Re-run the one required unfiltered authoritative command with a
fresh, absolute, outside-repository, producer-PASS terminal corpus and retain
its complete framed output in the task's authoritative evidence location. Do
not weaken the cancellation bound, change the manifests, expand the allowlist,
or treat the existing stale `verify.log` as current evidence. After that
evidence is present, request a fresh responsibility-isolated implementation
review; do not overwrite this immutable Review13.
