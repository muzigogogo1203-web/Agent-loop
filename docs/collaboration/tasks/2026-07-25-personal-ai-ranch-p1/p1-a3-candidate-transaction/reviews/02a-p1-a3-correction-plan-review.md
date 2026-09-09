# P1-A3 Responsibility-Isolated Correction Plan Review02A

> Date: 2026-08-10
>
> Reviewer: responsibility-isolated correction-plan reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## 1. Independence and boundary

This reviewer did not author Revision02 or its manifest and did not participate
in the proposed correction implementation. The review was read-only except for
this exact file. It did not run tests, builds, release gates, scripts, or UI and
did not modify the plan, manifest, product, tests, logs, or prior reviews.

The review read `plan-revision-02.md`, immutable Review02, Revision01 and
Review01A, the 206-entry manifest, and the current Orchestrator, Supervisor,
database, and test architecture. This review is not implementation authority,
A3 acceptance, or authority to open A4.

## 2. Decisions that are sufficiently specified

The proposed two-file implementation surface is technically capable of
hosting the correction: the production observation point belongs in
`Orchestrator.swift`, while all barriers, snapshots, mutation counters,
manifest checks, and canonical matrices can live in
`DurablePlanningTests.swift`.

The DEBUG observer design is non-substitutive and release-sealed as written:
the nonthrowing async observer fires immediately before the existing real
`ensureTickStarted`, candidate `planningStarted` emission, and Supervisor
`kick`; it neither returns a production result nor replaces an action. Matching
DEBUG guards for type, storage, arm/clear/helper, and callers, combined with
source adjacency/occurrence gates, release-Core absence, debug-Core presence,
and release-TestSuite compilation, are sufficient to distinguish real call-site
observation from a fake counter.

Reading `Database.totalChangesCount` from the serialized writer connection is
also a viable true-write observer. With recovery/setup/profile/control writes
completed before the baseline and no active pump, zero deltas prove the
replay/rejection path issued no write statement; a work-insert-trigger rollback
can produce a positive total-change delta while persisted graph equality proves
rollback. The plan correctly takes queued/retry preservation snapshots while
paused before the real tick/kick.

Sections 5.1, 5.2, and 5.4 otherwise specify the missing halt+winner,
profile-deletion/non-CLI/CLI drift, complete graph, resolver, mutation, and
wrong/nil-Camp-cow rows precisely. The failure-first debug compile red,
authoritative final run, debug/App builds, release Core/TestSuite builds, and
source/symbol directions are executable after the two findings below are
closed.

The current manifest itself was verified as 206 sorted, unique, current-hash
matching entries: 203 regular files under `Sources/` outside the original nine
A3 files plus `Package.swift`, `Package.resolved`, and the matrix script. Its
current SHA-256 is the planned
`3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`.

## 3. Findings

### P1-01 — The one-Orchestrator two-absent-caller barrier is impossible in the current actor architecture

Revision02 §5.3 requires both absent callers to enter one recovered
Orchestrator and have their two provider preflights meet at the existing
two-party synchronous barrier. That cannot execute.

`Orchestrator.convertCandidateAndEnqueuePlanning` awaits one shared
`DurableWorkSupervisor`. That Supervisor is an actor, but its candidate method
at `DurableWorkSupervisor.swift:595-603` is a synchronous actor-isolated method.
It synchronously calls `AppDatabase.convertCandidateAndEnqueuePlanning`, whose
absent path synchronously calls the resolver. Once caller one blocks inside the
resolver barrier, the Supervisor actor cannot start caller two; caller two can
never reach its preflight, so a target-two barrier deadlocks.

This is distinct from §5.1/§5.2, where a paused Orchestrator loser is paired
with a direct-database winner; those interleavings remain feasible because the
independent winner does not need the blocked Supervisor actor.

**Required revision:** use two separately recovered Orchestrator/Supervisor
instances sharing the same AppDatabase and a shared observation/counting gate,
or freeze another architecture-compatible interleaving. Preserve two absent
preflights, one insert plus one replay, the pre-dispatch complete snapshot, and
the final command-level counts `ensureTick=2`, `planningStarted=1`, `kick=2`.
Do not make the production Supervisor method async or add a second production
owner merely to make the test barrier work. Also state how the test attributes
the eventual inserted/replayed dispositions, since the observation enum itself
does not carry disposition.

### P1-02 — The 206-entry manifest does not enforce the declared two-file correction scope

Revision02 permits changes only to Orchestrator and DurablePlanningTests and
freezes the other seven original A3 files. The 206-entry manifest deliberately
excludes all nine original A3 files. The six independent exact-byte gates add
back only `AppDatabase.swift` from that set; the other five entries duplicate
red-line files already represented by the manifest.

Therefore these six frozen original-A3 files are in neither the manifest nor an
exact-byte gate:

- `MissionDraftFactory.swift`;
- `DurableWork.swift`;
- `DurableWorkSupervisor.swift`;
- `DurableWorkStore.swift`;
- `CodingRanchStoreAdapter.swift`;
- `CodingRanchTests.swift`.

Step 8 says “two-file correction allowlist,” but supplies no immutable baseline
or machine-checkable algorithm for those six paths. In this intentionally dirty
worktree, a generic Git changed-file list cannot distinguish Revision02 drift
from accepted predecessor changes. The current manifest closes Review02 P1-03
for files outside the original nine, but it does not close Revision02's own
two-file scope/red line.

**Required revision:** either regenerate and freeze a manifest covering every
source/test/App file outside the two correction files, or add all six omitted
files with their exact Revision02-entry hashes to an executable gate. Freeze
the resulting count/path/hash and no-symlink partition before implementation;
the manifest must not remain an implementation-updatable baseline. Retain the
six named red-line/migration checks as independent sentinels if desired.

## 4. Verdict and next gate

Revision02 materially addresses all three Review02 findings, but the deadlocked
canonical race and incomplete correction-scope boundary make it not yet
executable as frozen.

Final verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**.

Implementation, new red/final evidence, A3 acceptance, and A4 remain blocked.
A bounded Revision02 update and fresh responsibility-isolated re-review with
0 P0 / 0 P1 are required before implementation.
