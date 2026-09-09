# P1-D Bounded Full-Suite Compatibility Revision 01

> Status: **PLANNING ONLY — self-review required before test edits**
>
> Date: 2026-08-26
>
> Branch / entry HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Authority: accepted master spec; canonical P1 stage §12–§13, §18.5,
> §19 and P1 completion gates; canonical P1 plan §6/§10/§11; approved P1-D
> plan SHA-256
> `3b34e4f699a568d2be5cf345dfa260615d29c5708fd21b29772c723858598acf`;
> approved P1-D Review01; and P1-D plan §9's mandatory bounded revision rule
> after a full-suite failure

## 1. Purpose, precedence, and observed red boundary

This revision closes only incompatibilities exposed by the first authoritative
unfiltered P1-D run. The complete failure is preserved in `verify-red.log`:
900 tests in 15 suites, 39 issues, command status 1 and tee status 0. The
failures reduce to these bounded classes:

1. historical tests still encode the pre-P1-D accepted-Mission rollup,
   v14-as-final, v15-absent, and external-write-without-Grant assumptions;
2. two historical source sentinels do not yet partition the exact reviewed
   P1-D successor allowlist;
3. strict P1-D Date equality is intermittently violated after GRDB's
   millisecond text round-trip even though the semantic timestamp is unchanged;
4. three unrelated failures pass in isolated reruns and therefore remain
   unmodified pending the final unfiltered concurrency run.

The Date repair is inside the original P1-D product allowlist and fixes the
persisted representation boundary. This revision authorizes the exact test
compatibility edits that the original allowlist omitted. All original plan
clauses not contradicted here remain binding. Original `plan.md`, Review01,
accepted P1-C evidence, and historical entry manifests remain immutable.

Because the user explicitly directed Codex to proceed without Claude or
delegated agents, the required plan rereview is a disclosed role-separated
self-review. It must not be described as independent. No test edit below may
start until `reviews/01a-p1-d-plan-revision-review.md` records `APPROVED` with
zero P0/P1.

## 2. Exact scope overlay

### 2.1 Five additional test files

Revision 01 adds exactly these paths to the P1-D allowlist:

- `Sources/AgentLoopTestSuite/MissionRollupTests.swift`
- `Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift`
- `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`

Their entry SHA-256 values are respectively:

```text
afff390e14aa14f1a9d009c2d20d28fa4afac0ffff29718983db2bf2d4682241
1d37bf962015a372f068b98561707697c1abb4165e493f799c3b23b2958eef35
c7047d48e8e5d08fcbdf193b94234ac8de2d81a5ac3f88f62529330b217ad9b4
0d4e55b9e0e678406edc020d566b9b1066fea24cdc86ce9a8d9892e364a1c081
f125868304f7f6929e3ec2f20ec15a90761ec131797db135d1f018eee2618ed4
```

No other product, App, test, Package, runner, script, canonical-authority,
accepted-evidence, or historical-manifest path is added.

### 2.2 Additional task artifacts

Exactly these task-local artifacts are additionally allowed:

- this `plan-revision-01.md`
- `reviews/01a-p1-d-plan-revision-review.md`
- `revision01-regression.log`

Existing planned evidence paths remain authoritative. No prior evidence file
may be rewritten except the already planned current green destinations in the
original verification order.

## 3. Decision-complete repairs

### 3.1 Persisted millisecond restoration

`P1DTimestampV1.canonical` remains floor-to-integer-millisecond and all strict
contract equality/CAS checks remain strict. Add one database-boundary restore
operation with these exact semantics:

1. require a finite Date and finite `seconds * 1000`;
2. round the decoded value to its nearest integer millisecond;
3. accept only when the distance is at most `0.01` millisecond, which covers
   floating-point ulps from Foundation text decoding but not submillisecond
   business timestamps;
4. return the exact `Date(milliseconds / 1000)`; otherwise throw
   `P1ContractValidationError.invalidTime`.

Apply it only when reading persisted P1-D Date fields used by exact projection,
CAS, or receipt equality: approval-request `answeredAt`; Grant `validFrom`,
`validUntil`, `revokedAt`, `createdAt`, `updatedAt`; Grant-use `reservedAt`,
`dispatchIntentAt`, `adapterAcceptedAt`, `finishedAt`; and external receipt
`createdAt`. Writers, schema, DDL, command hashes, event times, expiry policy,
and equality operators do not change. Strengthen the existing
`contractContentAndRequirementHashesUseCanonicalJSONV1` test to prove a
within-tolerance persisted decode restores exactly and a value outside the
tolerance fails closed. The existing Grant workflow test remains the real DB
round-trip regression.

### 3.2 Accepted Mission rework

Rename `rollupTerminalStatesSticky` to
`rollupAcceptedReworkResumesExecutingAndFailedRemainsSticky`. Replace only the
obsolete expectation for `.accepted + [.todo]`: the exact expected result is
`.executing`, as required by stage §19 and original P1-D plan §5.4. Preserve
the failed-terminal sticky assertion and add/retain the assertion that an
accepted Mission with only terminal Cards remains accepted. No product code
changes are authorized here.

### 3.3 Historical v14 migration boundary

`p1cRequireV14` must continue to require `v14-p1-control-contracts` to be the
immediate successor of `v13-p1-observability`. Remove only the stale claim that
v14 must also be the final migration. Every P1-C test continues to migrate
explicitly `upTo: "v14-p1-control-contracts"`, verify its exact objects,
counts, DDL, constraints, replay, rollback, and append-only behavior. Rename
the error text from “immediate final successor” to “immediate successor”. It
must not inspect or accept v15 objects inside the v14 checkpoint.

### 3.4 Ready Goal remains contract-free before activation

Rename `goalReadyDoesNotRequireV15Schema` to
`goalReadyRemainsContractFreeBeforeExplicitActivation`. The current
`AppDatabase` must now contain the exact v15 `outcome_contract_version` table,
so assert that exact table name rather than absence. Preserve the substantive
P1-C invariant unchanged: confirmation ends at `.ready`, keeps the confirmed
Understanding ref, and leaves both current OutcomeContract fields nil until an
explicit P1-D activation command.

### 3.5 Legacy two-Card golden path under explicit Grant

The golden test is an orchestrator/dependency/handoff/artifact test, not an
ApprovalGrant test. Before starting the Mission, write the exact `facts.md`
fixture into its fresh temporary workspace. Remove provider A's ungranted
`write_file` turn; provider A's first and only turn is its existing
`complete_card`, registering that real readable file as the artifact. Preserve
all Mission planning/executing/delivering transitions, A→B dependency/handoff,
artifact registration/existence, model-call, closeout, and accepted assertions.
No fake Grant, approval bypass, injected external workflow, weaker artifact
assertion, or production change is permitted.

### 3.6 Successor-aware historical source sentinels

Add `a3P1DExactAllowlist()` containing the original P1-D plan's exact 41
product/test/carrier paths plus the five Revision 01 test paths: exactly 46
unique paths. Do not change either historical manifest byte or its frozen hash.

For `broadcastFailureDoesNotRewriteStartedFire` against the A4 206-row entry
manifest:

- raw P1-D intersection is exactly 23 paths;
- after subtracting the already-accounted P1-B and P1-C intersections, the
  P1-D-only successor exclusion is exactly 19 paths;
- exactly 14 P1-D-only paths are new after that entry manifest and every one
  must be a regular non-symlink file;
- the still-frozen unaffected entry set is exactly 138 paths and every hash
  remains byte-exact.

For `a3Revision02EntryBoundaryRemainsByteExact` against the A3 206-row entry
manifest:

- raw P1-D intersection is exactly 24 paths;
- after the existing A4-historical, P1-B, and P1-C partitions, the P1-D-only
  successor exclusion is exactly 19 paths;
- exactly the same 14 P1-D-only new paths must be regular non-symlink files;
- the live historical complement and recursive enumeration are each exactly
  134 identical sorted paths, and every hash remains byte-exact.

The P1-B/P1-C allowlists, intersection assertions, frozen `Package.resolved`
and RunTests hashes, manifest hashes, runtime behavior assertions, and all
non-P1-D historical file hashes remain unchanged. The repair must partition
reviewed successor scope, never update expected hashes to current bytes.

## 4. Regression gate and evidence

After this revision is approved and only the edits above are made, write full
stdout/stderr with pipefail and true statuses to `revision01-regression.log`.
It must include:

1. ten sequential fresh selections of
   `approvedGrantExecutesOnceAndTerminalReplayUsesSanitizedAck`, all passing;
2. one exact filter covering the strengthened canonical-time test, renamed
   Mission rollup test, complete serialized P1-C migration suite, renamed
   ready-Goal test, two-Card golden path, A4 broadcast sentinel, and A3 entry
   sentinel;
3. isolated reruns of
   `deniedActionRoutesToErrorAndCardContinues`,
   `cliProcessBackendCancellationReturnsCardToReady`, and
   `ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider`;
4. `git diff --check` and absence of all temporary `p1d-*-diagnostic` prints.

The exact P1-D 80-test manifest still contains exactly 80 tests; this revision
renames/strengthens legacy tests and adds no `@Test`. After the regression log
is green, rerun the original plan's exact 80-test filter, dual SQLite matrix,
source/scope gate updated for this reviewed overlay, App build, isolated UI
failure preview, and finally a fresh unfiltered `swift run RunTests`. The final
suite must remain exactly 900 tests in 15 suites and pass. Any unrelated test
that fails again is diagnosed at its root; isolated green is not acceptance.

## 5. Completion gate and red lines

Revision 01 is complete only when its disclosed self-review is `APPROVED — 0
P0 / 0 P1`, every exact compatibility edit is present, `revision01-regression.log`
is green, original P1-D evidence is freshly green in the required order, the
outside manifest remains exact, Review02 is zero P0/P1, and P1-D acceptance is
written.

Forbidden: changing v14/v15 DDL; changing a historical manifest or its hash;
accepting arbitrary timestamp rounding; tolerance-based business equality;
creating a fake Grant; bypassing ApprovalGate; deleting or broadly weakening a
historical assertion; changing Package/RunTests; editing P1-C accepted
evidence; adding a fallback; hiding a full-suite failure; or starting P1-E
before P1-D acceptance.

Open questions: none.
