# P1-A1b durable planning implementation report

Date: 2026-07-27  
Branch: `codex/personal-ai-ranch-p0`  
HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
Implementer result: Review01 P1 repairs complete; ready for independent re-review

This report does not declare A1b accepted and does not open A2.

Independent implementation Review01 found two bounded P1 defects after the
first implementation pass: preview bootstrap wrote the normal shared
UserDefaults domain, and a suppressed Supervisor could report idle while
current queued/due planning still existed. Its exact verdict was
`CHANGES REQUIRED — 0 P0 / 2 P1`, SHA-256
`05ac137b93c94e04d51cbd72cf24d047b321a55beaaa24c56dcf16eca563a4a3`.
The repairs below touched only its four leaf-allowed source/test files and this
task's owner evidence. Acceptance and A2 remained closed throughout.

## Authority and scope

Implementation resumed only after Review11 gave
`APPROVED — 0 P0 / 0 P1` on these frozen inputs:

- Stage:
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
- Total Plan:
  `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0`
- A1b leaf:
  `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56`
- Review11:
  `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671`

The complete A1b manifest is the 13 production, 19 test, and 5
runner/immutable entries in leaf §3. The exact entering/final hashes and the 11
post-Review11 changed entries are recorded in
`evidence/scope-and-hashes.txt`. No file needed by the final implementation was
outside that allowlist.

`Package.swift`, `Package.resolved`, `Sources/RunTests/main.swift`, the v12
schema/literal, A1a acceptance, and all three canonical documents remain
byte-identical to their frozen fingerprints.

No commit, push, merge, release, real-data reset, payment, external
communication, or real-user operation was performed.

## Implemented outcome

### Durable planning identity and storage

- Mission creation and planning work enqueue share one transaction and stable
  replay identity.
- Same-key replay is resolved before mutable profile/catalog/credential
  preflight; conflicting payloads fail without writes.
- Generic durable-work mutation/dispatch APIs fail closed for `.planning`.
  The single fileprivate planning ledger owner handles claim, renew, retry,
  terminal projection, cancellation, halt cleanup, adoption, and legacy
  repair.
- Usage and canonical evidence preserve exact integers above 2^53, reject
  negative/invalid shapes, and turn overflow into typed durable evidence
  without trap or saturation.
- Success, deterministic/transient failure, usage overflow, cancel, and
  emergency-halt projections are transaction-atomic.

### Resolver and planner

- Planning uses the exact captured runtime profile, model, endpoint, catalog,
  and credential account. It does not consult a later current default or
  silently fall back.
- Durable planner execution has no planner-owned retry or fallback loop.
  Provider results become a single Supervisor-owned terminal proposal and
  durable retry/failure policy owns subsequent attempts.
- The R11 unexpected-fallback path is testable only through the matching
  `#if DEBUG` owned-work seam and reuses the production failure owner.
  Release object inspection proves the symbol is absent.

### Supervisor, recovery, halt, and shutdown

- Startup recovery now has the explicit process-local `.recoveryReady` phase.
  Durable-running recovery remains suppressed until Card orphan adoption,
  proposal healing, transition-token checks, and the durable mode fence
  complete.
- Full first-phase retry and Card-only retry have mutually exclusive
  eligibility. There is no reactive post-failure re-suppress hook.
- Owned providers use latest-claim lease renewal, a single pending terminal
  proposal owner, actor-continuation waiters, next-due wakeup, fatal latching,
  stale-generation loss, durable cancel, bounded shutdown, and sorted unique
  shutdown reporting.
- `waitUntilIdle` no longer treats every suppressed state as idle. After
  owned/pump/halt-cleanup are empty, only suppressed + durable halted can
  become idle directly; durable-running `recoveryReady`/`running` still
  distinguishes current due work from a future retry through the sealed ledger
  read. Store-read failures retain the existing fatal-latch path.
- `waitUntilTerminal` follows the durable terminal row even while a genuinely
  cancellation-ignoring provider Task remains owned; `waitUntilIdle` waits for
  that Task to exit.
- Running legacy planning with existing Cards throws the exact package
  `LegacyPlanningHasCardsError` with code `legacy_planning_has_cards` and zero
  writes.

### Coordinator and four product entries

- Manual, Candidate, confirmed Proposal, and Schedule starts all delegate to
  the package `PlanningEntryCoordinator` and capture immutable input before
  Task creation or the first await.
- App sources contain no direct `orchestrator.startMission`,
  `orchestrator.confirmSquadProposal`, Schedule claim, or Candidate link
  bypass.
- Non-finite Schedule fire dates fail before UUID creation, runtime selection,
  `Result`, or claim mutation.
- Extreme finite `lastFiredAt` values use numeric epoch-seconds storage and
  exact reload/dedupe. The deferred decoder still reads old TEXT plus new
  INTEGER/REAL values; all other Schedule date encoding is unchanged.

### Migration matrix and preview

- The named `v12-durable` fixture migrates through the real migrator, seeds
  valid work/attempt/event state, closes/reopens, migrates twice, and verifies
  canonical snapshot stability, FK, integrity, DDL, append-only guards, and
  full diagnostics in SQLite 3.51 and 3.52.
- The matrix script's embedded Stage hash was synchronized to the
  Review11-approved Stage, as required by leaf Step 9.
- UI preview uses a fresh absolute state root. Failure-first preview sampling
  exposed two OAuth presence reads that bypassed `AGENTLOOP_UI_PREVIEW` and
  blocked the main thread in `SecItemCopyMatching`. `AppStore.reload` now
  short-circuits those reads just like the existing API/search credential
  reads.
- Review01 then proved that the first retry still wrote normal shared defaults.
  `AppStore` now constructs its defaults dependency before any preference
  access: normal launch selects `.standard`, while preview uses a locked,
  process-local `ProcessLocalPreviewUserDefaults`. The same instance reaches
  direct AppStore access, fresh-profile bootstrap, resolver, scheduler, reload,
  catalog, persistence, and OAuth state.
- The final accepted retry showed a responsive `Coding 牧场` window, isolated
  database/WAL/lock files, zero normal App Support open files, the source-backed
  process-local defaults boundary, a true PNG screenshot, and process exit
  after Command-Q.

## Verification

### Tests

- Frozen §12 name gate:
  `115 required / 115 unique / 115 defined exactly once`.
- Final authoritative command:
  `swift run RunTests`.
- Final result:
  `611 tests in 5 suites passed after 43.026 seconds`.
- Full failure-first and all intermediate runs are preserved in `verify.log`.
  Earlier runs include:
  - the intended R-01/R11 red tests;
  - the pre-existing concurrency-sensitive
    `slowActiveStreamDoesNotIdleTimeout` failure, followed by isolated and full
    green runs;
  - one test-double race in
    `terminalWaiterReturnsAfterDurableCancelWhileIdleWaitsForProviderExit`,
    fixed by making the provider Task itself block until explicit release
    instead of merely blocking its detached stream producer.
  - Review01 failure-first regressions for process-local preview defaults and
    suppressed queued/due idle semantics, followed by a 5/5 focused pass and
    the 611/611 full pass.

### Build and release seam

- `swift build --product AgentLoopApp`: PASS after the final AppStore repair.
- `swift build -c release --product AgentLoopCore`: PASS.
- DEBUG seam counts:
  Core `1/1` guarded, tests `3/3` guarded.
- `nm` over release Core objects:
  `injectOwnedSuccessProposalForTesting` absent.

The first release-gate wrapper used zsh and hit zsh's read-only special
variable `status` after the build had passed. The total Plan's Bash block was
then rerun under `/bin/bash` without alteration and passed. Both records remain
in `build.log`.

### SQLite matrix

- Command:
  `scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`.
- SQLite 3.51 linked + literal lane: PASS.
- SQLite 3.52 linked + literal lane: PASS.
- Both lanes contain exact `v12-durable` replay/FK/integrity/DDL/append-only
  sentinels and 56/40/288 real diagnostics.

The first matrix preflight correctly rejected the old embedded Stage hash.
After the planned one-line synchronization, the full matrix passed. Both
records remain in `migration-matrix.log`.

### Preview

- Final accepted state root:
  `/private/tmp/agentloop-a1b-review01-preview.sy7T0L`.
- Final accepted process:
  PID `51258`, with both exact preview environment variables present.
- Screenshot:
  `evidence/preview-smoke.png`, true PNG, 1190 × 732,
  SHA-256
  `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8`.
- Visible state:
  `Coding 牧场`, `我的营地`, `基础牛，空闲`, `发起放牛…`, and the
  non-blocking no-model first-run explanation.
- Result:
  PASS, with full failure-first/root-fix/retry/exit evidence in `preview.log`
  and `evidence/preview-observation.md`.

The Computer Use capture returned JPEG bytes under a `.png` extension. The
accepted frame was re-encoded and independently checked as real PNG bytes.
Command-Q exited the final preview; only a shell process-presence check ran
afterward, so the UI tool could not relaunch it.

The process-local defaults regression proves the complete bounded AppStore /
bootstrap routing without inspecting, printing, exporting, or diffing normal
UserDefaults contents. No credential or account value was printed, persisted
to evidence, or asserted.

### Static, scope, and hash gates

- All total-Plan source sentinels: PASS.
- `planningTasks`, split planning API, App bypasses, public specialized
  planning mutation, generic planning fixture defaults, and reactive
  re-suppress: zero production matches.
- Fileprivate planning ledger owner: exactly one.
- `git diff --check`: PASS.
- Frozen canonical, A1a, Package, resolved, and RunTests hashes: exact match.
- Scope manifest: 11 post-Review11 changes, all in leaf §3; 26 entries unchanged.

## Evidence map

- Failure-first, targeted, full tests, named coverage, source gates:
  `verify.log`
- App/release builds and release-symbol gates:
  `build.log`
- SQLite linked/literal lanes:
  `migration-matrix.log`
- Preview launch, failure sample, repair retry, screenshot, process and exit:
  `preview.log`
- Review11 entry and red-root inventory:
  `evidence/preflight.txt`
- Exact before/after manifests and immutable hashes:
  `evidence/scope-and-hashes.txt`
- Visible preview observation and evidence boundary:
  `evidence/preview-observation.md`
- Fixed screenshot:
  `evidence/preview-smoke.png`

`evidence/final-hashes.txt` is written after this report and before independent
Review so it can include the completed implementer-owned artifact hashes
without self-reference.

## Deviations and disposition

1. The cancellation-ignoring provider test double originally blocked only its
   detached producer. Full-suite scheduling proved that the Supervisor-owned
   Task could still exit on stream cancellation. The test double was corrected
   to block the owned Task itself. Independent read-only diagnosis agreed this
   was a test synchronization defect, not a production Supervisor defect.
2. The matrix script still carried the pre-R11 Stage constant. Updating that
   constant is explicitly required by leaf Step 9 and changed no schema,
   literal, runner behavior, dependency, or target graph.
3. Final preview found and fixed the AppStore OAuth preview Keychain bypass.
   This is inside the allowed AppStore path, enforces the frozen no-real-
   credential preview boundary, and was verified by live main-thread sampling.
4. Review01 found the remaining normal-defaults bootstrap write and suppressed
   idle shortcut. Both were reproduced with deterministic regressions and
   repaired within `AppStore.swift`, `DurableWorkSupervisor.swift`,
   `DurablePlanningTests.swift`, and `CrashRecoveryTests.swift`.
5. After repaired preview PID `50856` exited, an attempted Computer Use state
   probe auto-launched non-preview PID `51012`. It was immediately terminated
   by exact PID without inspecting defaults or Keychain contents. Because
   normal initialization can access its preference domain, that run is
   explicitly rejected in the evidence. The final retry began with no
   AgentLoop process, used a new root, and made no post-quit UI call.
6. All transient failures and tool-delivery limitations are retained in the
   raw logs. None is presented as a green result.

No unexplained deviation remains. A1b is ready for a fresh, independent
implementation re-review; acceptance and A2 remain closed.
