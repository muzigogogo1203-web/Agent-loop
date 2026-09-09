# P1-A3 Responsibility-Isolated Plan Re-Review 01A

> Date: 2026-08-10
>
> Reviewer: responsibility-isolated A3 plan re-reviewer
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. Independence and review boundary

This reviewer did not write Revision 01 and did not participate in A3
implementation. The re-review was read-only except for this file. It did not
run tests, builds, scripts, migrations, or UI and did not modify the A3 leaf,
Stage, canonical Plan, P1 control route, immutable Review01, product, test,
App, Package, or script bytes.

The re-review read immutable Review01, the complete revised A3 leaf, and the
current P1 control status. It re-inspected only the existing resolver return
type, planning-ledger read/write fence order, Supervisor dispatch gates, and
Orchestrator/coordinator call boundary needed to decide whether Review01
P1-01/P1-02 are closed and whether the revision introduced a new P0/P1.

The reviewed branch/entry HEAD remains
`codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.
No hash approval or user hash roundtrip is required.

## 2. Review01 finding closure

### P1-01 — CLOSED: terminal replay and first trace

Revision 01 now freezes all previously missing decisions:

- replay accepts an intact immutable start graph in all six durable states:
  queued, running, retry-scheduled, succeeded, failed, and canceled;
- replay does not require Mission to remain planning, Camp to remain
  unarchived, or work to remain attempt-zero/version-one after legitimate
  execution progress;
- incoming trace is validated only on the absent insert path, is excluded from
  replay identity, and can neither conflict with nor overwrite the persisted
  first trace;
- `.replayed` preserves the original Mission/work, trace, timestamps, state,
  attempt, and version with zero DB mutation;
- exactly-one applies only to `missionCreated`, `planStarted`, and
  `actionCandidateConverted`; legitimate later retry, terminal, usage, Card,
  Run, and other events do not invalidate replay;
- terminal and running replay perform zero provider resolution, start-event
  emission, tick, and kick;
- queued/retry-scheduled replay may wake only after re-reading the current work
  and durable running mode. The existing actor boundaries can implement this:
  Orchestrator awaits the Supervisor command, then performs the specified
  current-state fence before its existing tick/kick operations; Supervisor
  `kick()` retains its own lifecycle, suppression, fatal, and compatibility
  gates.

The deterministic test table now covers all six states, a fresh incoming
trace, preserved first trace/timestamps/state/attempt/version, unrelated later
events, every canonical same-key command conflict except trace, resolver and
mutation counts, and exact tick/kick behavior. The two-absent-caller case also
requires one complete graph and one inserted plus one replayed disposition.
This closes Review01 P1-01 without adding a second owner or widening scope.

### P1-02 — CLOSED: durable dispatch and Runtime Profile fences

Revision 01 now specifies the required two-phase ordering exactly:

1. initial DB read requires durable dispatch running;
2. a same-key winner validates and replays immediately;
3. only absence reads the exact `RuntimeProfileRecord` snapshot and rejects a
   missing or CLI profile before provider resolution;
4. the provider-only resolver consumes the captured profile/model outside the
   transaction and does not return, construct, refresh, or own that DB
   snapshot;
5. the write transaction re-requires durable running, checks a concurrent
   winner before all absent-path fences, then—only if still absent—re-reads the
   exact profile ID/kind/non-CLI state before candidate validation, ID
   generation, and writes.

This matches the implementable architecture already demonstrated by
`PlanningDurableWorkLedgerOwner.startReadSnapshot` and
`enqueueMissionPlanning`: durable mode precedes replay, a DB profile snapshot
belongs to the absent path, and a concurrent winner is replayed before current
profile availability is considered. It also matches the real
`PlanningProviderResolver`, which returns only an `LLMProvider`.

The revised tests deterministically cover provider-preflight failure, halt
between preflight and write, profile deletion, profile kind/CLI drift, a
concurrent winner followed by profile change, and the prohibition on replay
across durable halt. Each case requires exact resolver, row/event, first-trace,
tick, and kick evidence. This closes Review01 P1-02 without a new protocol,
schema, migration, target edge, or fallback.

## 3. Scope, preservation, and route gate

The revision remains within the nine-file A3 allowlist and task-artifact
boundary. The single GRDB transaction still belongs to the existing
fileprivate planning ledger owner; the Adapter delegates through the
MainActor coordinator; callable legacy conversion/link bypasses are removed;
and public `enqueueMissionPlanning` is not nested inside the atomic write.

Manual, confirmed-proposal, and schedule routes remain unchanged. A1a, A1b,
and A2 contracts are preserved. The current P1 control status correctly keeps
A4 and later slices closed until A3 implementation review and independent A3
acceptance. Revision 01 introduces no new P0, P1, unresolved question, scope
expansion, or authority expansion.

## 4. Findings

### P0

0.

### P1

0.

### P2

0.

## 5. Verdict and next gate

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

Review01's two P1 findings are closed. Under the standing Goal, this approval
opens only the reviewed P1-A3 implementation/red-test gate defined by Revision
01. It does not accept A3, open A4, or authorize commit, push, merge, release,
normal/destructive data operations, public communication, external action, or
real-user action. Any implementation deviation, red/final failure, unknown,
or out-of-scope delta must fail closed before A3 acceptance.
