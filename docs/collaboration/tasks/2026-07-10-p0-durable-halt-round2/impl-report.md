# P0 Durable Halt Round 2 — Implementation Report

Status: **implemented and verified**

Branch: `codex/p0-durable-halt-round2`

This branch intentionally carries the earlier uncommitted Round 1 hardening diff. Round 1 files
were preserved; no changes were staged, committed, pushed, or reverted.

## Result

The emergency stop is now a durable, global, fail-closed kernel control:

- A successful stop is stored in SQLite and survives exit, crash, and restart.
- Startup recovery may repair crash residue while closed, but cannot start providers, cards, MCP,
  shell work, or new planning before its one-shot bootstrap completes.
- Resume first closes interrupted planning and adopts orphan runs, then commits the durable
  `running` edge. Any cleanup or persistence failure leaves dispatch closed.
- Stop cancellation fans out to planning, running cards, and the tick before waiting; a stuck
  planner cannot delay cancellation of active work.
- UUID transition ownership prevents stale actor continuations from reopening a newer halt/resume
  state, and concurrent resume no longer reports a false success.
- Planning interrupted by emergency stop becomes a durable failed mission with reason
  `emergency_halt_during_planning` and both required audit events.
- AppStore and Orchestrator both guard direct mission start and proposal confirmation paths.
- The global UI provides Cmd+., cold-restore state, durable-save retry, resume confirmation,
  localized asymmetric errors, accurate mission-kernel scope, and VoiceOver announcements.

## Round 2 files

Data layer:

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/KernelControlStore.swift` (new)

Kernel:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`

App/UI:

- `Sources/AgentLoopApp/AgentLoopApp.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/CampHomeView.swift`

Tests and task evidence:

- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
- `docs/collaboration/tasks/2026-07-10-p0-durable-halt-round2/plan.md`
- `docs/collaboration/tasks/2026-07-10-p0-durable-halt-round2/verify.log`
- `docs/collaboration/tasks/2026-07-10-p0-durable-halt-round2/impl-report.md`

## Persistence contract

Migration `v6-durable-halt` adds a constrained singleton `kernel_control` projection with one
`global / running` row. It intentionally does not replay historical halt events. Real
`running <-> halted` edges update the projection and append the existing global audit event in one
GRDB transaction; idempotent calls update neither timestamp nor events. Missing, stale, corrupt,
or fault-injected states throw and roll back.

## Verification

- `swift run RunTests`: **330/330 passed**.
- Full authoritative output: `verify.log`.
- `swift build --product AgentLoopApp`: **passed**.
- `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`: **passed**.
- `git diff --check`: **passed**.
- Three independent read-only reviews (data/transactions, Core concurrency, App/UI) reported no
  remaining P0/P1 after the final fixes.

New deterministic coverage includes migration replay, CAS/idempotency, bidirectional event
rollback, missing/corrupt singleton fail-closed behavior, cold halted recovery, running-card and
planning interruption, cancellation ordering, persistence retry, planning-cleanup retry,
orphan-adoption rollback, pending reconcile gating, concurrent resume, actor ABA ownership,
startup bootstrap gating, failed-stop delayed recovery, and shutdown ownership.

## Review-driven safety clarification

The approved draft originally placed the durable `running` commit before orphan recovery. Review
showed that this briefly opened direct starts while recovery could still fail. The final sequence
performs planning cleanup and orphan adoption under the closed gate, then commits `running`. This
does not change the product decision; it enforces its fail-closed guarantee. The plan was updated
to match the implemented single source of truth.

## Live UI status

The App target was compiled and linked, but this task did not launch it. PID 89430 is an active
AgentLoop built from `/private/tmp/agentloop-m8`; launching this branch would violate the explicit
single-instance constraint. Therefore rendered layout, cold-halt interaction, and real VoiceOver
focus/announcement smoke remain **pending**, not claimed as passed.

## Deliberately deferred

- Persisted planning-attempt ledger and exactly-once resumable planning (next P0 iteration).
- Atomic run/card/token finalization and artifact journaling.
- Process-group sandbox hardening.
- M9/M10, scheduling, and Provider Profile work.

No commit was created.
