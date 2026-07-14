# P0 Durable Halt Round 2 — Level 3 Plan

Status: **approved by the user on 2026-07-10; implementation complete and verified (330/330)**

Branch: `codex/p0-durable-halt-round2`

Baseline note: this branch intentionally carries the uncommitted, already-verified Round 1
hardening diff. Do not revert, commit, stage, or modify unrelated work, and do not touch
`/private/tmp/agentloop-m8`.

## Goal

Make the existing global emergency stop a durable, fail-safe kernel control:

1. A successful stop survives app exit, crash, and restart.
2. Startup may recover interrupted database rows while halted, but must not start planning,
   providers, cards, MCP servers, or shell work.
3. Only an explicit, durably persisted resume may re-enable dispatch.
4. Stop/resume state changes and their audit events are atomic, idempotent, observable, and
   accurately represented in the UI.
5. Every direct mission-start path is guarded at the Orchestrator and AppStore action layers,
   not only by disabled buttons.

## Non-goals

- No general planning-attempt ledger or exactly-once planning recovery. That is iteration #2.
- No redesign of run/card/token finalization transactions or artifact journaling.
- No budget reservation, process-group sandbox, M9, M10, scheduling, or Provider Profile work.
- No per-camp halt. The existing kill switch is global across all camps, and this round preserves
  that contract while changing user-facing copy from ambiguous “营地” wording to “全部行动”.
- No change to DM/guide chat semantics or manual knowledge distillation. This gate controls the
  mission kernel: planning, card dispatch, card providers, MCP, and shell processes.
- No physical event deletion/update and no replay of historical halt events into the new state.

## Decisions

### D1. Durable state is a global singleton projection

Files:

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- new `Sources/AgentLoopCore/Database/KernelControlStore.swift`

Add a descriptive migration after v6 named exactly `v6-durable-halt`. It must not consume the
`v7` and `v8` identifiers already reserved by the M9 and M10 plans.

Add table `kernel_control`:

| Column | Type | Contract |
|---|---|---|
| `id` | TEXT primary key | exactly `global` |
| `dispatchMode` | TEXT not null | `running` or `halted` only |
| `updatedAt` | DATETIME not null | time of the last successful edge |

The migration inserts exactly one `global / running` row. It must **not** derive initial state from
historical `camp_halted` / `camp_resumed` events: older versions implicitly resumed on restart and
did not guarantee a matching resume event, so replay would incorrectly lock some upgraded users.

Add:

- `DispatchMode: String, Codable, Sendable` with `.running` and `.halted`.
- `KernelControlRecord` following existing GRDB record conventions.
- `AppDatabase.dispatchMode() throws -> DispatchMode`.
- `AppDatabase.transitionDispatchMode(from:to:) throws -> Bool`.
- `StaleKernelControlStateError(expected:actual:)` for a non-idempotent CAS mismatch.

`transitionDispatchMode` runs in one `pool.write` transaction:

- already at the desired mode: return `false`; do not update the timestamp or append an event;
- expected edge: update the singleton row and append existing global `camp_halted` or
  `camp_resumed` event with all association IDs nil, then return `true`;
- missing row, invalid mode, stale expected mode, event failure, or SQLite failure: throw and
  roll back both projection and event.

### D2. Use an explicit in-memory transition phase

File: `Sources/AgentLoopCore/Kernel/Orchestrator.swift`

Replace the plain `halted` Bool with an internal phase:

- `running`
- `halting`
- `halted`
- `resuming`
- `shuttingDown`

Only `running` permits new planning or dispatch. Transitional phases remain closed so actor
reentrancy across `await` cannot let resume/start/reconcile pass through a half-finished stop.
The persisted projection stores only stable `running` / `halted` modes.

Every transition that crosses an `await` also owns a UUID token. Phase values can repeat
(`resuming -> halted -> resuming`), so the token prevents an older continuation from mistaking a
new transition for its own phase (the actor ABA case). Concurrent resume reports an explicit
transition-in-progress error instead of returning a false success.

Orchestrator initialization reads `dispatchMode` synchronously. A read failure initializes the
phase as `halted`, retains an explanatory startup error, and never defaults to running.
The production App opts into a one-shot bootstrap gate at initialization: even a durable
`running` projection stays closed until startup recovery owns and completes its pass. A stop,
resume, or shutdown supersedes that pending bootstrap so delayed recovery cannot reopen work.

### D3. Startup restores the durable gate before dispatch

File: `Sources/AgentLoopCore/Kernel/Orchestrator.swift`

`recoverAndReconcile()` must:

1. reread the singleton state and emit the matching `haltStateChanged` event;
2. on read failure, log and emit a kernel error and stay fail-closed;
3. adopt persisted `running` orphan cards back to `ready` using the existing recovery path;
4. if durable mode is halted, stop there without starting the tick loop or dispatching;
5. if durable mode is running, continue through normal reconcile.

`reconcile` checks the phase before starting the tick loop. Because its database work suspends,
it must check again after the database plan is returned and immediately before creating runner
tasks. A stop that arrives during the DB read must therefore produce zero new runners.

Ordinary `shutdown()` never changes the durable mode and enters `shuttingDown` before awaiting
tasks.

### D4. Stop is fail-safe even when persistence fails

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopApp/AppStore.swift`

Change `emergencyStop()` to `async throws` with this exact order:

1. enter `halting` immediately, blocking all new kernel work;
2. attempt atomic `running -> halted` persistence before canceling work;
3. regardless of persistence success, expose the process as halted and cancel/await planning and
   running tasks, cancel the tick, stop MCP gracefully, then terminate residual shell processes;
4. finish in in-memory `halted` state;
5. if persistence failed, log and emit a kernel error, then throw after cleanup. The UI must say
   that current work stopped but durable stop was not saved and the user should not exit until the
   problem is resolved. It must never claim a durable success.

Track an in-memory `haltPersistencePending` flag for that failure case. A repeated stop while
`halted + pending` retries only the atomic `running -> halted` persistence edge (cleanup has already
finished); success clears the flag and produces the single real halt event. The global banner
offers “重试保存停营”. Repeated stop calls in ordinary `halting`/durably-`halted` states remain
no-ops and do not duplicate events. An explicit resume is also allowed: because the durable row is
already `running`, the database transition is an idempotent success and no false resume event is
appended.

Cancellation requests fan out to planning, running cards, and the tick before awaiting either
task group. Running-card cleanup is awaited first, so a planner that ignores cancellation cannot
delay cancellation of work capable of external side effects.

### D5. Resume is strictly fail-closed

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopApp/AppStore.swift`

Change `resume()` to `async throws`:

1. enter `resuming` while still closed to dispatch;
2. while the durable projection is still halted, retry terminalization of interrupted planning
   missions and atomically adopt any running-card/open-run crash residue;
3. if either cleanup fails, return to `halted`, log/emit/throw, write no resume event, and start no
   work;
4. atomically persist `halted -> running` plus `camp_resumed`;
5. if persistence fails, return to `halted`, log/emit/throw, and start no work;
6. only after cleanup and the successful commit enter `running`, emit
   `haltStateChanged(false)`, and reconcile once.

This is the review-hardened form of the original persist-first sequence. Opening the projection
before orphan recovery created a real window where unrelated starts could pass while recovery was
still fallible; doing local recovery under the closed gate preserves the approved fail-closed
product contract.

Repeated resume in `running` is a no-op. A stop requested after resume commits is allowed to win
as the next serialized edge.

### D6. Guard every mission-start bypass

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopApp/AppStore.swift`

Add a public, localized, sendable `KernelHaltedError`.

- `startMission` checks the phase before creating a mission or planner task.
- `confirmSquadProposal` checks before its proposal CAS, while `startMission` remains the second
  guard against a stop interleaving after confirmation.
- `reconcile` and its post-DB dispatch point use the same gate.
- AppStore `startMission` and `confirmProposal` reject immediately with actionable user copy.

Preparing data while halted remains allowed: users may edit drafts, answer a waiting question,
add budget, abandon/harvest an action, or move a blocked card to ready. Those operations may call
`reconcile`, but the durable gate prevents actual dispatch. Existing closeout behavior is not
expanded in this round; the stop contract is mission dispatch, not all app networking.

### D7. Planning interrupted by stop uses an honest terminal outcome

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- existing database transaction helpers as needed within the planned files

The current schema does not persist planner model/attempt state, so exact planning continuation is
impossible without iteration #2. To avoid permanent zombie `.planning` missions:

- after canceling an in-memory planning task, transition that mission to `.failed` and append
  `mission_failed { reason: "emergency_halt_during_planning" }` plus the existing status-change
  audit event in one database transaction;
- during halted startup recovery, apply the same terminalization to any persisted `.planning`
  mission that has no live planning task;
- retain its goal and mission history so the user can inspect what was interrupted;
- do not invent a planner model or automatically create a replacement mission.

This is the recommended bounded behavior. Exactly-once resumable planning remains the next P0
iteration rather than being partially improvised here.

### D8. Global, truthful UI state

Files:

- `Sources/AgentLoopApp/AgentLoopApp.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/TaskRunView.swift`
- `Sources/AgentLoopApp/Views/CampHomeView.swift`

Requirements:

- AppStore synchronously initializes `campHalted` from the durable projection before the first
  normal reload; read failure displays halted, never running.
- Track `.idle / .stopping / .resuming` UI operation state so buttons cannot be double-fired.
- AppStore catches stop/resume errors and shows asymmetric truthful messages.
- Move the halted banner to RootView so it is visible from every destination. On cold restoration,
  say that the previous session ended halted and nothing was auto-resumed.
- Resume requires confirmation because it may restart provider calls and spending.
- Disable and explain new-action buttons, the new-action submit button, and proposal confirmation
  while halted; keep the Orchestrator/AppStore action guards authoritative.
- Make Cmd+. a global app command in `AgentLoopApp.swift`; remove the view-local shortcut conflict.
- Stop requires no confirmation. During transition, render “正在收哨…” / “正在恢复…” and prevent
  conflicting actions.
- Announce cold-restored halt and subsequent halt/resume state changes through the macOS
  accessibility announcement API. Keep generic kernel diagnostics from overwriting the more
  actionable typed stop/resume error shown by the action layer.

## Tests

Files:

- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`

Required deterministic coverage:

1. Migrate a v6 database to `v6-durable-halt`: exactly one global running row; replay remains one.
2. Halt/resume CAS is idempotent; exactly one event per real edge and global event IDs are nil.
3. Inject halt-event insertion failure: transaction throws and projection stays running.
4. Inject resume-event insertion failure: transaction throws and projection stays halted.
5. Missing singleton row and invalid mode fail explicitly; neither defaults to running.
6. Recreate an Orchestrator on the same halted database: recovery/tick produces zero provider
   calls, runs, MCP transports, or shell launches until explicit resume.
7. Seed a crash residue (`running` card/open run) with durable halted mode: startup adopts it to
   ready/interrupted but does not redispatch; resume dispatches exactly once.
8. Halt during a gated database/reconcile window: the stale candidate is not dispatched after the
   awaited DB read returns.
9. Halt during a running card: cleanup completes without a new runner; card is ready and no open
   run remains under existing interruption semantics.
10. Halt during planning: mission becomes failed with the explicit interruption reason; no planner
    continues after stop.
11. Halt persistence failure still cancels current-process work, leaves in-memory state closed,
    surfaces an error, and writes no false success event.
12. Resume persistence failure leaves the phase halted and produces zero dispatch.
13. `startMission` and proposal confirmation while halted create no mission, mutate no proposal,
    and call no provider.
14. Existing cooldown and same-process halt/resume tests remain green without sleep-based retries
    standing in for completion synchronization.
15. A hanging planner cannot delay cancellation of an already-running card.
16. Planning-finalization and orphan-adoption failures roll back atomically and block resume until
    an explicit successful retry.
17. Pending reconcile work rechecks the gate before a second database pass.
18. UUID transition ownership prevents stale startup recovery from stealing a newer resume phase,
    and concurrent resume reports an in-progress error.
19. The one-shot startup bootstrap blocks direct starts before recovery and cannot be revived after
    stop-persistence failure or shutdown.
20. Both planning terminal audit events are asserted on success and absent after rollback.

UI has no dedicated app-test target. Verify UI code through app builds and a documented manual
smoke checklist. Do not launch a second AgentLoop while the existing `/private/tmp/agentloop-m8`
instance is active; if it remains active, report the live UI step as pending instead of claiming it
passed.

## Verification result

- `swift run RunTests`: 330/330 passed; full output saved to `verify.log`.
- `swift build --product AgentLoopApp`: passed.
- `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`: passed.
- `git diff --check`: passed.
- Live UI and VoiceOver smoke: pending because PID 89430 is the active
  `/private/tmp/agentloop-m8` app; a second AgentLoop instance was not launched.

## Verification

1. Run focused halt/database tests during implementation.
2. Run `swift run RunTests 2>&1 | tee docs/collaboration/tasks/2026-07-10-p0-durable-halt-round2/verify.log`.
3. Run `swift build --product AgentLoopApp`.
4. Run `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`.
5. Run `git diff --check`.
6. Write `impl-report.md` with changed files, test results, deviations, and the live-UI status.
7. Independent review must explicitly inspect migration replay, actor reentrancy after DB awaits,
   persistence-failure asymmetry, old-data migration default, and all start-path guards.

## Completion definition

- A successful stop remains authoritative across process recreation.
- Startup while halted performs safe orphan cleanup but starts no provider, card, MCP, or shell.
- Resume cannot dispatch unless its projection+event transaction commits.
- Direct start/proposal paths cannot bypass halt.
- Planning stopped mid-flight has an explicit, inspectable terminal outcome rather than a zombie.
- Stop/resume events are atomic and non-duplicated.
- The global UI truthfully communicates restored, stopping, halted, unsaved-stop, and resuming
  states.
- Authoritative tests and both builds pass; remaining live-app validation is reported honestly.
- No Round 1 change or unrelated worktree is altered or reverted.

## Resolved user decision

When emergency stop interrupts an in-flight planning request, this bounded round recommends marking
that planning mission **failed with reason `emergency_halt_during_planning`**. It preserves the goal
and audit trail but requires the user to launch a new mission after resume. Exact continuation would
require the separate planning-attempt recovery iteration because planner model and attempt state are
not currently persisted.

The user confirmed this fail-safe terminal behavior and the plan as a whole on 2026-07-10.
