# P1-A3 Responsibility-Isolated Plan Review 01

> Date: 2026-08-10
>
> Reviewer: responsibility-isolated A3 plan reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## 1. Independence, scope, and method

This reviewer did not write the A3 leaf plan and did not participate in A3
implementation. The review was read-only except for this file. It did not run
tests, builds, scripts, migrations, or UI and did not modify the Stage, total
Plan, P1 control route, A2 acceptance, product, test, App, Package, or script
bytes.

The review read `AGENTS.md`, the collaboration protocol, the accepted master
spec, P1 Stage §§6.3 and 6.5, canonical Plan §3.4, the current P1 A3 route
override, A2 acceptance, and the complete A3 leaf plan. It then inspected the
real nine-file allowlist, including the existing `PlanningEntryCoordinator`
two-step candidate path, `Orchestrator` and Supervisor actor gates, the
`AppDatabase` planning entry boundary, the fileprivate
`PlanningDurableWorkLedgerOwner`, the legacy conversion/link bypasses, the App
adapter, and current candidate/planning tests.

Branch and entry HEAD are the planned
`codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.
A2 is independently `ACCEPTED`, so A3 planning is open. A3 implementation and
A4 remain closed by the findings below. No hash approval or user hash
roundtrip is required; the leaf needs a bounded decision-complete revision and
a new responsibility-isolated plan review.

## 2. Architecture findings that are already sound

- The nine-file allowlist now includes the real owner of the current two-step
  route, `Orchestrator.swift`, and matches canonical Plan §3.4.
- The proposed call chain correctly keeps the Adapter on `@MainActor`, crosses
  to the `Orchestrator` actor with `await`, uses an actor-isolated Supervisor
  method, and places the GRDB transaction in the existing fileprivate planning
  ledger owner. No target edge or public protocol is needed.
- The plan correctly forbids nesting public `enqueueMissionPlanning` inside an
  existing write transaction, preserves manual/proposal/schedule entry paths,
  removes all callable `MissionDraftFactory` conversion/link bypasses, and
  keeps A1a/A1b/A2 and A4 out of scope.
- Candidate, Mission, Squad, planning work, candidate link, and the three start
  events are correctly required to commit or roll back as one transaction.
- Capturing the core draft, runtime selection, deterministic candidate key,
  and trace before the Adapter's first `await` is compatible with the current
  `@MainActor` call site.

These points do not cure the two blocking semantic gaps below.

## 3. Findings

### P0

0.

### P1-01 — Terminal replay and first-trace semantics are internally incomplete

Leaf §4 lines 148–160 correctly says a persisted winner must replay before
provider resolution, preserve the first trace, and perform zero writes. But
§6 lines 195–210 says every item agrees with the incoming command and describes
the work only as following “queued/active graph conventions” while also naming
the “original trace.” This leaves two incompatible implementation choices:

1. compare `work.traceId` with the newly captured incoming trace, which would
   reject a valid later-process replay; or
2. ignore the incoming trace and preserve the first trace, as §4 requires.

It also leaves `succeeded`, `failed`, and `canceled` planning work undefined.
Those are valid same-key replay states when the immutable start graph remains
intact. The accepted Stage §6.3 replay contract is not limited to active work,
and the current planning validator deliberately calls
`requirePlanningGraph(... requirePlanningMission: false,
requireUnarchivedCamp: false)` in
`Sources/AgentLoopCore/Database/DurableWorkStore.swift:1724`, without rejecting
a terminal work or Mission merely because execution progressed after start.

The four planned tests at leaf lines 238–249 cover an ordinary replay, provider
skip, rollback, residency, and a concurrent insert, but do not require a replay
after the work reaches any terminal state, a fresh incoming trace, a same-key
payload conflict, or the absence of tick/event/kick on terminal replay. An
implementation could therefore pass the written tests while breaking durable
cross-process idempotency or dispatching a completed work.

Required bounded revision:

- define valid replay over all six durable states
  `queued|running|retryScheduled|succeeded|failed|canceled` when the complete
  immutable start graph is intact;
- state that the incoming trace is validated as a new-command input only on
  insert and is never compared with or written over the persisted first trace
  on replay; `.replayed` returns the original Mission/work and preserves its
  trace and timestamps;
- make clear that exactly-one checks apply to the three start-event kinds and
  do not reject valid later terminal/retry events;
- require zero provider resolution, DB mutation, new start event, tick event,
  or kick for a terminal replay; only an active replay may enter the separately
  revalidated conditional-kick path;
- extend the exact four-test gate with table-driven terminal replay, fresh-trace
  preservation, and same-key changed-command conflict cases, including row,
  event, resolver, and dispatch-call counts.

### P1-02 — The durable-mode/profile fences are absent from the exact transaction plan

Leaf §4 lines 148–156 specifies work lookup, provider preflight, and concurrent
winner recheck. Leaf §5 then labels its eight candidate/source/residency checks
the **exact** validation order before IDs and writes. Neither section requires
the read snapshot or write transaction to read
`kernel_control.global.dispatchMode == running`, and the write list omits the
absent-winner re-read of the exact Runtime Profile ID/kind.

Process-local Orchestrator/Supervisor gates at leaf lines 132–138 cannot replace
those SQLite fences: either actor can suspend before the write, and another
control path can durably halt dispatch. Accepted Stage §6.3 requires every
planning enqueue transaction to require durable `running`, and requires the
absent-key transaction to re-read the exact profile ID/kind before any IDs or
inserts. The current implementation shows the necessary ordering:

- `DurableWorkStore.swift:1677-1703` checks durable mode before replay/read
  snapshot and returns a DB `RuntimeProfileRecord` snapshot only for absence;
- `DurableWorkStore.swift:1812-1841` rechecks durable mode, then a concurrent
  winner, then the exact current profile ID/kind/non-CLI state before writes.

Leaf §4 line 153 additionally refers to a “returned profile snapshot,” but the
real `PlanningProviderResolver.resolvePlanningProvider` contract in
`Sources/AgentLoopCore/Work/PlanningProviderResolver.swift:3-7` returns only an
`LLMProvider`, not a profile snapshot. The implementer is therefore forced to
invent whether the snapshot comes from the read transaction, the provider, or
a new API that the plan forbids.

Required bounded revision:

- freeze that the initial DB read first requires durable mode `running`, then
  validates a same-key replay; only absence returns the exact
  `RuntimeProfileRecord` snapshot for `planningInput.runtimeProfileId`;
- freeze that provider resolution consumes the captured profile/model outside
  the write transaction but does not return or own the DB profile snapshot;
- freeze write ordering as durable-mode recheck → concurrent-winner replay
  validation →, only if still absent, exact profile ID/kind/non-CLI recheck
  against the read snapshot → the eight candidate/source/residency checks → ID
  generation and atomic writes;
- preserve replay independence from current profile, catalog, credentials, and
  endpoint after a winner is found, while still refusing replay across the
  durable halt gate required by Stage §6.3;
- add deterministic tests for halt between preflight and write, profile
  missing/kind drift between snapshot and write, provider-preflight failure
  with zero business writes, and a concurrent winner that replays before the
  absent-path profile fence. Each must assert resolver count, row/event counts,
  first trace, and no kick on rejection.

### P2

0.

## 4. Verdict and next gate

**CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2.**

The atomic ownership direction and nine-file scope are viable, but the plan is
not yet decision-complete for durable replay or the mandatory SQLite dispatch
and Runtime Profile fences. Product/test implementation, red-phase execution,
and A4 remain blocked. Revise only the A3 leaf/control wording needed to close
P1-01 and P1-02, then run a fresh responsibility-isolated Plan Review. Do not
use this verdict to modify product/test/App/Package/script bytes or to cross
into A4.
