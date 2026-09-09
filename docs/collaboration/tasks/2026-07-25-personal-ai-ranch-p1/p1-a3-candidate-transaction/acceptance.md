# P1-A3 Independent Acceptance — Candidate Atomic Conversion

> Final status: **ACCEPTED**
>
> Date: 2026-08-10
>
> Acceptance owner: fresh, responsibility-isolated independent acceptance owner
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Responsibility isolation and boundary

This owner did not plan or implement A3, author its tests or evidence, or
participate in Reviews 01–04. The acceptance pass was read-only except for this
file. It did not rerun tests, builds, release gates, migrations, scripts, the
App, or UI, and it did not modify product, test, plan, manifest, review,
evidence, or report bytes.

The decision independently read the accepted master specification, P1 Stage
§6.5 and P1-A completion gate, canonical Plan §3.4, the complete A3 leaf and
Revisions 02–04, every immutable plan/implementation review, current A3
product/test bytes, the authoritative task `verify.log`, its Revision04 mirror
and predecessor, build/release evidence, the 206-entry manifest, and
`impl-report.md`.

## 2. Current-byte and evidence identity

The current nine-file A3 boundary still matches the final reviewed state:

| File | Current SHA-256 / disposition |
|---|---|
| `MissionDraftFactory.swift` | `f33e53d3d795cd913f722d1c5e3f71f5800b97083a9101db27514bcc566d0e26` |
| `DurableWork.swift` | `49b61c58c07886904fdb16a1a4076081789749645459696f412e85ac672785ee` |
| `DurableWorkSupervisor.swift` | `cf6ece2fdd22842d093ea51b461e10bc4d1099360400d9ff254b0e457ff19d39` |
| `DurableWorkStore.swift` | `4f2ab03002fbb113784e9586fc20a17bdd580b18aa954432562fbf0d5c728fa9` |
| `AppDatabase.swift` | unchanged A3 boundary at `147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de` |
| `Orchestrator.swift` | `f28331248a8ba50b641018456e3bbbc0e81e75111756a8ad2d11af9571f4088b` |
| `CodingRanchStoreAdapter.swift` | `42ccc982acee797a3f53e754763b606a51e46944cc38cdfc97278f631c4589d0` |
| `CodingRanchTests.swift` | `38d20527135ace5035fc387daeead71f66a5798e4d4c090d9bb16cc03491b192` |
| `DurablePlanningTests.swift` | `0dbc6385b73b13cf70f2e3f3a739d1a387b43fc27b3660da5181ab884ffed403` |

The required task `verify.log` and `revision04-verify.log` remain byte-identical
at `5e0f9108664e4ef9165cb72d259fbbdfce8cdad4fc6afc083e0cd58a80b6d217`.
The displaced 655-test predecessor remains preserved separately at
`8eba08f8dd64f7999e24c2c0f90baac960db4c1ac077e42fe13c9abb4bc88eeb`.
The source manifest remains exactly 206 entries at
`3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`;
an independent read-only current-hash check passed all entries. The 12 frozen
source identities match, `Sources/` contains no symlink, and `git diff --check`
passes.

## 3. Independent completion-gate decision

| Required A3 row | Decision | Evidence basis |
|---|---|---|
| Single legal candidate-start owner | PASS | Adapter captures before its first `await` and delegates through Coordinator → Orchestrator → Supervisor → AppDatabase → the fileprivate ledger owner. |
| Legacy two-step bypass removal | PASS | `MissionDraftFactory` is draft-only; callable `existingMissionId`, `linkConverted`, and conversion bypasses are absent. Manual, proposal, and schedule ownership is preserved. |
| One atomic conversion transaction | PASS | Candidate/source/Camp/cow validation precedes IDs and writes; Squad, Mission, queued attempt-zero work, converted candidate link, and the three exact start events commit or roll back together. Injected work-insert failure preserves the complete graph. |
| Replay and conflict contract | PASS | All six durable states replay the original Mission/work, preserve first trace/timestamps/state/attempt/version, skip provider resolution, and produce zero start mutation; every canonical same-key payload drift is an explicit conflict. |
| Durable and Runtime Profile fences | PASS | Durable running is checked before replay/read and again in the writer; a concurrent winner is replayed before the absent-profile fence; missing/kind/CLI drift and halt interleavings fail with zero candidate business mutation. |
| Camp and cow residency | PASS | Wrong and nil `companion.campId` paths fail before IDs/writes with one required absent-path preflight and zero runtime observation. |
| Post-commit runtime ownership | PASS | Dynamic Orchestrator evidence proves queued/retry wake behavior, no running/terminal wake, no replay start event, and the concurrent command boundary `ensureTick=2`, `planningStarted=1`, `kick=2`. The observer is DEBUG-only, adjacent to the real operations, and non-substitutive. |
| Concurrency and zero-mutation proof | PASS | Dedicated two-absent database callers yield exactly one insert and one replay with one complete graph; halt-winner and profile-drift races preserve the winner. `Database.totalChangesCount` distinguishes reads from mutations. |
| Harness completion and fail-closed sentinel | PASS | Exactly two named Foundation workers rendezvous/abort explicitly; the sole private completion coordinator observes both `isFinished` values before validating indexed outcomes and resuming once. The sentinel freezes this order and excludes cooperative waits. |
| Failure-first provenance | PASS | Rejected harness attempts remain classified and preserved; Revision04 selected red fails only on the missing reviewed completion-owner capability, followed by five exact selected greens. No rejected/partial run is promoted to green. |
| Authoritative test gate | PASS | Current task `verify.log` contains one terminal unfiltered result: **657 tests in 7 suites passed**. The two source gates and all four canonical A3 tests each start once and pass once; no failure, crash, timeout, or nonterminal result is present. |
| Build and release gate | PASS | AgentLoopApp, DEBUG Core/TestSuite, and release Core/TestSuite builds pass. Release Core has 0 A3 seam symbols and DEBUG Core has 37. Only the documented pre-existing driver diagnostic and two `BoardServerTests` warnings remain. |
| Scope and documentation gate | PASS | The executable 206 + 12 boundary, current hashes, no-symlink check, and report show no unexplained A3 delta outside the reviewed files. `impl-report.md` preserves corrections and deviations; none remains blocking. |
| Independent implementation review | PASS | Review04 is immutable at **APPROVED — 0 P0 / 0 P1 / 0 P2** and independently closes both Review03 findings while preserving all inherited A3 gates. |

No silent fallback, default success, swallowed error, unresolved Open Question,
red final test, unknown build result, scope drift, or open P0/P1 remains.

## 4. Historical evidence disposition

Acceptance does not rewrite earlier evidence. Review02 remains
`CHANGES REQUIRED — 0 P0 / 3 P1`; Review02A remains
`CHANGES REQUIRED — 0 P0 / 2 P1`; the first Revision02 red is permanently
`HARNESS_REJECTED`; the Revision02 full-run hang remains non-green; and Review03
remains `CHANGES REQUIRED — 0 P0 / 2 P1`. Their findings were closed only by
the separately reviewed Revision02B/02C, Revision03/Review03A, and
Revision04/Review04A changes culminating in Review04. None of the rejected,
partial, or stale predecessor artifacts is used as the final completion proof.

## 5. Acceptance and next gate

**ACCEPTED.** P1-A3 Candidate Atomic Conversion is complete. **R-03 is
CLOSED**: candidate conversion can no longer commit an unlinked Mission through
the former two-step route, and the atomic/replay/runtime boundaries have the
required dynamic and fail-closed regression evidence.

This acceptance opens **only P1-A4 — Schedule Fire Evaluation/Commit** under a
new bounded leaf plan, responsibility-isolated review, exact entry conditions,
completion gate, and red lines. It does not pre-accept A4 or open P1-B–P6, and
it grants no commit, push, merge, release, destructive or normal-data
operation, payment, public communication, external action, or real-user
operation.
