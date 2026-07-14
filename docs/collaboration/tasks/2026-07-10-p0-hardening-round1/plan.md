# P0 Hardening Round 1 Plan

Status: approved by the user's 2026-07-10 instruction to begin fixing the audited optimization items.

## Goal

Fix the first bounded set of root-cause reliability issues identified by the repo-wide audit:

1. Malformed companion tool configuration must fail closed and remain observable.
2. The canonical app launch path must not intentionally create competing production instances, and SQLite must tolerate short-lived lock contention.
3. Memory distillation must persist the note, advance the watermark, and append its audit event atomically.
4. Existing Swift concurrency warnings in the touched Orchestrator paths must be removed without changing scheduling semantics.

## Non-goals

- No GRDB schema migration or persisted-record shape change.
- No durable halt-state design, planning-attempt recovery, run/card outcome transaction redesign, Provider Profile, MCP sandbox, process-group control, budget reservation, M9, or M10 work.
- No dependency change, UI redesign, release version change, commit, push, or modification of `/private/tmp/agentloop-m8`.

## Required changes

### 1. Tool access fail-closed

Files:

- `Sources/AgentLoopCore/Tools/ToolAccess.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopTestSuite/ToolAccessTests.swift`
- `Sources/AgentLoopTestSuite/CardRunnerTests.swift`
- `Sources/AgentLoopTestSuite/McpTests.swift`

Behavior:

- Valid legacy `[]` remains backward-compatible and grants all built-in capability tools.
- Valid v2 JSON remains literal and deterministic.
- Malformed JSON or unsupported object versions produce `parseFailed == true` with zero capability tools; board tools remain available through `allows`.
- A parse failure records a kernel diagnostic that explicitly says only board tools are retained.
- A parse failure must not start or assemble MCP servers for that card.
- Encoding the simple v2 whitelist must never silently fall back to legacy `[]`; an impossible encoder failure must fail fast.

### 2. Launch and SQLite contention

Files:

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Support/StateDirectoryLock.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `scripts/run-app.sh`
- `scripts/package-app.sh`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/SupportTests.swift`

Behavior:

- Configure GRDB with a finite five-second busy timeout while preserving WAL.
- Canonical LaunchServices startup must never force `open -n`; the script requires a cold launch
  because it cannot safely distinguish an existing production, preview, or custom-state process.
- Both development and packaged Info.plists declare multiple instances prohibited.
- Before opening SQLite, acquire and retain a non-blocking advisory lock inside the selected state
  directory. A second process using the same directory, including a dev/package cross-bundle pair or
  a raw binary launch, must fail fast with the lock path instead of running recovery or dispatch.
- `--preview` must use a non-production state directory by default when `AGENTLOOP_STATE_DIR` is not supplied.
- Existing explicit `AGENTLOOP_STATE_DIR` remains authoritative.
- Because LaunchServices ignores `open --env` when reusing a live process, every script invocation
  must reject a warm launch with an actionable error in both mode-switch directions.

### 3. Atomic memory distillation

Files:

- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
- `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`

Behavior:

- For a produced note, note persistence, watermark advancement for the captured message IDs, and audit-event insertion occur in one database transaction.
- The transaction uses a compare-and-set condition: every captured message must still be undistilled. A concurrent winner causes the losing attempt to roll back without a duplicate note.
- If note or event persistence fails, the watermark remains unchanged and the failure is logged with OSLog.
- Model `skip` keeps existing semantics: advance only the captured message IDs and create no note.
- Messages arriving during model work are not marked distilled.

### 4. Warning cleanup and observability

Files:

- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`

Behavior:

- Remove only compiler-confirmed redundant `await` expressions.
- Proposal healing errors must no longer disappear behind `try?`; log and emit a kernel error without aborting startup recovery.
- Failure to persist a kernel diagnostic must itself be logged instead of disappearing behind `try?`.

### 5. Validation stabilization

Files:

- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`

Behavior:

- When the full suite exposes a test observing the card's blocked transition before the
  orchestrator's cooldown event, synchronize on `waitUntilIdle()` before reading the event.
- When the full suite exposes idle-watchdog timing sensitivity, retain a stream whose total
  duration exceeds the timeout while making each individual event interval comfortably shorter
  than the timeout. Do not add retries or weaken the production timeout assertion.

## Tests

- Update ToolAccess regression tests for fail-closed semantics, unsupported versions, and board-tool availability.
- Add a runner-level regression proving malformed config exposes no capability tools.
- Add a database configuration test for the five-second SQLite busy timeout.
- Add a process-lock regression proving a second owner is rejected and the lock is released on deinit.
- Add DM and guide-memory regressions that inject note-insert failure and prove the watermark is unchanged.
- Add a compare-and-set persistence regression proving a stale distillation attempt cannot create a duplicate note.
- Add a gated service regression proving messages arriving during model work remain undistilled.
- Add a startup-recovery regression proving proposal-healing failures are persisted and emitted.
- If full-suite validation exposes the existing cooldown-event race, synchronize that test on
  `Orchestrator.waitUntilIdle()` before reading the event; do not weaken or retry the assertion.
- If parallel full-suite validation exposes the existing idle-watchdog timing flake, preserve the
  proof that total stream duration exceeds the timeout while increasing the per-event scheduling
  margin; do not add retries or remove the timeout assertion.
- Run `swift run RunTests`; save the complete combined stdout/stderr to this task's `verify.log`.
- Run `swift build --product AgentLoopApp`.
- Run `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`.
- Inspect the canonical launch script without launching a second app while another AgentLoop process is active.

## Completion definition

- All required behaviors above have focused regression coverage.
- The authoritative suite passes.
- Normal and warnings-as-errors app builds pass.
- Main source changes stay within this plan.
- `impl-report.md` records changed files, test results, and any deviation.

## Open questions

None.
