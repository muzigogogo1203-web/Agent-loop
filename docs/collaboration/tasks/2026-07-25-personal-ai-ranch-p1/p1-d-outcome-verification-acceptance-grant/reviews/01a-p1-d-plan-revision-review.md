# P1-D Revision 01 Plan Re-review — Review01A

> Date: 2026-08-26
>
> Reviewer: current Codex implementation owner, separate read-only review pass
>
> Process disclosure: the user explicitly directed Codex to proceed without
> Claude or delegated agents. This is a role-separated self-review, **not an
> independent review**.
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

reviewed_revision_sha256=e644c521d4c8898d49b0fa163c68afff9dfb3e3026e7a816ea7c847b4bf2c945

## 1. Review boundary and authority

This pass made no product or test edit. It reviewed the complete 224-line
Revision 01 against `AGENTS.md`, the collaboration protocol, the accepted
master spec, canonical P1 stage §12–§13/§18.5/§19/completion gates, canonical
P1 plan §6/§10/§11, approved P1-D plan and Review01, the immutable P1-C and
A3/A4 boundaries, the first complete 900-test red log, and the exact live code
around all proposed edits.

The revision is placeholder-free, names five additional test paths and three
task artifacts exactly, preserves the original plan and review hashes, and has
no open question. The five additional test pre-image hashes match the live
regular files. No canonical authority, accepted evidence, Package, RunTests,
historical manifest, schema, migration literal, or unrelated test is opened.

## 2. Failure classification review

The 39 full-suite issues are not treated as 39 unrelated patches:

- one obsolete accepted-Mission expectation conflicts directly with stage §19
  and the already implemented reviewed rollup;
- nine P1-C migration failures share the one helper assertion that v14 must be
  final even though every test explicitly migrates only through v14;
- the ready-Goal test confuses the former P1-C entry schema with current live
  schema while its real null-Contract invariant still holds;
- the two-Card golden path invokes a nonReplayable external write without the
  explicit Grant now required by canonical §13;
- two historical source sentinels correctly fail because they have not yet
  partitioned reviewed P1-D successor scope;
- the Grant workflow's intermittent conflict is explained by the observed
  Foundation/GRDB millisecond-text floating-point round-trip and is closed at
  the read boundary rather than by tolerance-based CAS;
- the denied-action, CLI-cancellation, and rumination failures each pass
  isolated and remain unchanged until a fresh authoritative concurrency run.

This is a bounded root-cause partition. It neither declares isolated green to
be acceptance nor authorizes changes to unrelated timing/concurrency tests.

## 3. Contract and persistence review

The timestamp design preserves semantic strictness:

- command creation still floors to an exact integer millisecond;
- persisted decoding first validates finite values, then accepts only a
  maximum `0.01` millisecond representation delta;
- the returned value is again the exact integer-millisecond Date;
- values outside that narrow representation tolerance throw the existing
  typed invalid-time error;
- all Grant/use/receipt equality, CAS, expiry, hashing, DDL, and writers remain
  unchanged.

The enumerated read sites cover every P1-D Date participating in the observed
Grant projection/transition equality. The existing real approval workflow
test exercises a database round-trip, while the strengthened canonical-time
test makes both restoration and corruption rejection deterministic. No
fallback or swallowed error is introduced.

## 4. Legacy-test evolution review

Each test edit preserves or strengthens its actual historical contract:

1. Mission rollup now explicitly checks both sides of the P1-D rule: accepted
   plus rework resumes executing, while an all-terminal accepted Mission and a
   failed Mission remain terminal.
2. P1-C migration tests still require v14 immediately after v13 and still
   inspect an exact database migrated only to v14. Removing “must be final” is
   successor compatibility, not DDL relaxation.
3. Goal confirmation still proves `.ready`, confirmed Understanding, and nil
   OutcomeContract refs; expecting the current v15 table prevents the test
   from pretending the live schema stopped at P1-C.
4. The golden path keeps its orchestrator, dependency, handoff, artifact,
   transition, model, and closeout assertions. Preseeding a real file removes
   only an external action that belongs to the separate Grant tests; it does
   not inject a permit or bypass production security.
5. Historical manifests and hashes remain immutable. Exact successor sets and
   counts exclude only the reviewed 46-path P1-D boundary, require all 14 new
   paths to be real non-symlink files, and continue hashing every unaffected
   historical path.

The independently derived manifest arithmetic matches the revision:

```text
revised_p1d_allowlist=46
A4 raw intersection=23, P1-D-only intersection=19, new=14, unaffected=138
A3 raw intersection=24, P1-D-only intersection=19, new=14, complement=134
```

No expected current-source hash is substituted into a historical manifest.

## 5. Verification and stop conditions

The regression gate is executable and bounded: ten sequential Grant workflow
runs, one exact compatibility filter, three isolated concurrency controls,
diagnostic-print absence, and diff hygiene. It adds no `@Test`, so the original
80-test P1-D manifest and current 900-test full-suite count stay fixed. It then
returns to the original authoritative order: focused tests, dual SQLite matrix,
scope/source gate, App build, isolated UI preview, and unfiltered suite last.

Any renewed unrelated failure reopens diagnosis; it cannot be relabeled as a
flake. Historical bytes, DDL, Package, RunTests, fake Grants, approval bypasses,
timestamp business tolerance, assertion deletion, and early P1-E work are
explicit red lines.

## 6. Findings and verdict

- P0: 0
- P1: 0
- P2: 0

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

This approval opens only the exact Revision 01 product-test regression edits
and evidence. It is not P1-D implementation acceptance, does not open P1-E,
and does not authorize commit, push, merge, release, destructive data access,
payment, public communication, or real-user operations.
