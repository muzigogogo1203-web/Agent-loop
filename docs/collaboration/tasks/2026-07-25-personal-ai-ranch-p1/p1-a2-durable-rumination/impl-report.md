# P1-A2 Durable Rumination Implementation Report

Date: 2026-07-27  
Branch: `codex/personal-ai-ranch-p0`  
HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
Implementer result: implementation and evidence complete; ready for independent
implementation review

This report does not declare A2 accepted and does not open A3. One rejected
preview attempt accidentally launched the installed normal App and opened four
files under the normal state root. That fact is preserved below and must be
adjudicated by the independent implementation reviewer; the later valid
isolated retry does not erase it.

## 1. Authority and frozen inputs

Implementation proceeded only after Review13B approved the exact R13B inputs:

| Input | SHA-256 / verdict |
|---|---|
| Canonical Stage | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| Total Plan | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| A2 leaf Plan | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |
| R13B freeze | `b9ff965be2477e68d70b2d938a3e496ff47409a20efae710a971b0a96322b8d1` |
| Review13B | `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`; `APPROVED — 0 P0 / 0 P1` |

The frozen control indexes and `blocked.md` retain historical
`Review13B Pending` wording. Their byte-identical hashes are part of the R13B
freeze, while the immutable Review13B artifact above is the later authority
that opened implementation. They were not rewritten during implementation.

No commit, push, merge, release, destructive data reset, payment, external
communication, or real-user action was performed.

## 2. Scope and changed files

The worktree already contained the long-running P0, A1a, A1b, and pre-R13 A2
changes recorded at R13A entry. The final hash manifest compares the current
tree against that exact entry baseline rather than treating the whole dirty
worktree as new R13 work.

R13 changed exactly these three allowed product/test files:

| File | Entry SHA-256 | Final SHA-256 |
|---|---|---|
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `48fa9a04ec21f07c41b958e54433681c5099e31ed851f3b4ff6deb064aef07cf` | `e7cde04d577cc53b5b4ad0f8ad18bb4ca4ce604de18c660020fbc4096cd48f45` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `13733b134cf80a63415ade04fa5ec407de3b7930b0ec7c31bb78c6e04132597a` | `5e311070fc5299fd4f576b4af6fb2286e4a515bf5b23a72d1ccc464c88c2c2bb` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `893944ff1266cd94d0cf2ddba15840719415596bc25e8b39415b205f3e54c346` | `818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7` |

The matrix control script changed only its frozen Stage-hash constant, as
required by the leaf:

- current:
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`;
- restoring the old constant reproduces the frozen script hash
  `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467`.

The other 12 entries in the 15-file R13 allowlist are byte-identical to their
entry hashes. All remaining writes are this task's authorized logs, evidence,
screenshot, and this report.

## 3. Implemented outcome

### 3.1 R13 authorization-loss seam and dynamic matrices

`DurableWorkSupervisor` now contains the frozen release-absent DEBUG seam:

- exactly two checkpoints: first and second pre-parse authorization
  revalidation;
- exactly 23 closed loss cases at each checkpoint;
- a single-armed, exact-identity, one-shot scenario;
- injection only after the real actor gates and real durable validator;
- 20 control-loss cases reuse the production control-loss owner;
- `fatal`, durable read failure, and durable invariant corruption reuse the
  unique production global-fatal owner;
- no seam path mutates durable/business state, calls provider/parser, constructs
  a terminal proposal, or bypasses the production catch/owner.

Tests #27 and #35 each run a fresh isolated 2 × 23 matrix, for 46 dynamic cells
per test. Every cell enters through real start, owned provider, actor gate,
durable validation, seam consumption, and the production catch. They assert
the exact reason and invalidation, single consumption, zero parse/failure/
accounting/proposal/event/business write, and unchanged durable rows.

The seam's types, storage, arm API, helper, and two callers are all protected by
matching `#if DEBUG` regions. The release object contains zero seam symbols;
the DEBUG object contains the expected seam.

### 3.2 Provider, usage, phase, and fences

- Test #31 locks `produceValidatedTurn` and `parseValidatedTurn` to their unique
  production Supervisor call sites. The provider is called once per attempt,
  tools are empty, and opaque validated output is parsed once without a second
  provider call.
- Test #40 exercises exact usage and invalid-usage closure end-to-end through
  the Supervisor.
- Test #41 dynamically covers discard/archive status-only, work-only, and
  neither cases and locks both mutation fences to the real Adapter transaction
  owner.
- The source/order gates use
  `PlanningTestFixtures.uniqueFunction` with masked comments/strings and unique
  brace ranges for the critical owners and call order. They do not use a
  substring-only surrogate for #27, #31, or #35.

### 3.3 Test scheduling root-cause repair

The combined #27/#35 matrices exposed a test-helper defect:
`a2Eventually` used 10,000 `Task.yield()` iterations, which could exhaust in
about 0.087 seconds under concurrent full-suite scheduling before the
Supervisor actor ran. The helper now uses a real `ContinuousClock` two-second
deadline with a one-millisecond sleep. This preserves fail-fast behavior while
testing elapsed time rather than scheduler iteration count. No production
timeout or fallback was added.

## 4. Stage §6.4 mapping

| Stage §6.4 contract | Current implementation and completion evidence |
|---|---|
| §6.4.1 atomic start, generation, start-projection barrier | #1/#6/#11/#22/#33/#34/#35 prove inserted attempt-zero `version=1`, replay normalization, reserve-before-reentrancy, delivery/release/revalidate/conditional kick, and rollback/conflict zero side effects. |
| §6.4.2 captured runtime and resolver | #9/#10/#12/#13/#14/#28/#39 prove immutable captured identity, no current-default/companion fallback, stable fail-closed resolution, and legacy snapshot handling. |
| §6.4.3 generic capability seal | #36 proves the exact generic `.rumination` rejection priority without widening the generic API. |
| §6.4.4 single Supervisor and global FIFO | #32 and #37 prove one Orchestrator-owned production Supervisor and cross-kind FIFO without planning regression. |
| §6.4.5 startup, halt, resume, shutdown | #22–#27, #32, #35, and #38 prove suppressed startup, activation ordering, control winners, sorted invalidation/cleanup, non-revival, and due/future-idle behavior. |
| §6.4.6 legacy repair | #5/#28/#34/#39 prove one repair work, exact safe terminalization, recovering UI, the full eight-cell mode × snapshot table, restart idempotency, and zero external call where required. |
| §6.4.7 provider, usage, and failure | #3/#13–#16/#29–#31/#40 prove one provider path, opaque validated turn, exact usage, stable sanitized failures, bounded retry, and invalid-output preservation. |
| §6.4.8 terminal transactions and pending proposal | #2–#4/#7/#8/#11/#17–#21 prove atomic result/failure/cancel projections, stale-claim rejection, retained proposal without provider recall, restart convergence, and one terminal commit. |
| §6.4.9 phase/UI/mutation fences | #27/#33–#35/#41 prove identity-bound process-local phase truth, exact recovering projection, both 2 × 23 loss matrices, serialized milestone delivery, App FIFO reload/reconcile, and discard/delete/archive fences. |

## 5. Verification

### 5.1 Failure-first and tests

The failure-first targeted gate preserved five genuine missing-capability reds:

1. Adapter still owned provider/current-default/unstructured-task behavior.
2. Unknown restart invented the reading phase instead of recovering.
3. Legacy `ruminating` repair was missing.
4. Start did not atomically create durable work.
5. Cancel left the durable ledger active.

These were product-behavior failures, not compile, discovery, fixture, or
unknown failures. They remain in `red-tests.log`.

Final test evidence:

| Gate | Result |
|---|---|
| Exact 41-name discovery/definition | 41 required, 41 unique, each defined once |
| Exact 41-name targeted run | 41 tests / 2 suites passed in 5.941 s |
| Authoritative `swift run RunTests` | 652 tests / 7 suites passed in 42.681 s |
| `stateDirectoryLockRejectsSecondFileDescriptionAndReleases` | passed in the authoritative run |

The final complete stdout/stderr is in `verify.log`; the failure-first and
targeted 41-name outputs are in `red-tests.log`.

### 5.2 Build and release seam

| Gate | Result |
|---|---|
| `swift build --product AgentLoopApp` | PASS, 0.18 s |
| `swift build -c release --product AgentLoopCore` | PASS, 90.05 s; only SwiftPM's known automatic-product warning |
| Release `DurableWorkSupervisor.swift.o` seam tokens | PASS, 0 matches |
| DEBUG `DurableWorkSupervisor.swift.o` seam tokens | PASS, 144 matches |
| Core matching DEBUG protection | 17 / 17 |
| `CodingRanchTests.swift` matching DEBUG protection | 13 / 13 |
| `DurableWorkTests.swift` matching DEBUG protection | 7 / 7 |

Raw build and object-symbol evidence is in `build.log`,
`evidence/r13-release-nm.txt`, `evidence/r13-debug-nm.txt`, and
`evidence/r13-seam-symbol-gate.log`.

### 5.3 SQLite 3.51 / 3.52 matrix

The authorized command
`scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`
ended with `p1_migration_matrix.result=pass`.

Both versions passed the linked real-GRDB and literal lanes for
fresh/v7/v8/v9/v10/v11/v12-durable. Each real fixture passed replay, FK,
integrity, DDL, append-only, and diagnostics gates; `v12-durable` also passed
snapshot and double replay. The intentional missing-table and rollback
sentinels failed visibly and were classified as their expected negative cases.

### 5.4 Source, privacy, immutable, and scope gates

- All inherited A1b source/release/DEBUG regression gates passed.
- A2 release seam, matching DEBUG regions, exact 41 definitions/greens,
  owner/order/anti-fake gates, matrix-script single-delta proof, artifact secret
  scan, and `git diff --check` passed.
- Artifact secret scan found zero raw provider body, credential, account,
  OAuth/token, or arbitrary error leak.
- All canonical/control hashes, 10 immutable files, the immutable
  `AppDatabase.swift` lines 21–612 migrator boundary, and the frozen Stage
  §18.1 lines 3850–4036 boundary match.
- `StateDirectoryLock.swift` and `SupportTests.swift` remain byte-identical at
  `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363`
  and
  `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386`.
- #35's enclosing source gate proves the AppStore lifetime-held lock is
  acquired before the unique production database open; the authoritative
  lock test proves a second owner fails fast and a replacement can acquire
  after release.
- Final allowlist summary: 15 total, 12 unchanged, 3 authorized deltas; one
  exact control-script exception; task-directory artifacts only.

The raw summaries are in `evidence/source-gates.log` and
`evidence/hash-manifest.log`.

## 6. Isolated preview

### 6.1 Final valid retry

The sole valid preview retry used fresh state root
`/private/tmp/agentloop-a2-preview.Kb1Er6`.

- Bootstrap PID `76355` had exact `AGENTLOOP_STATE_DIR` and
  `AGENTLOOP_UI_PREVIEW=1`; normal Application Support open-file count was 0.
- DB, WAL, SHM, and lock were all under the isolated root; bootstrap exited
  cleanly with no remaining AgentLoop process.
- A non-sensitive synthetic fixture was inserted only into the isolated DB:
  ingestion `a2-preview-ingestion-recovering`, work
  `a2-preview-work-recovering`, queued attempt 0, version 1; FK check was 0 and
  integrity was `ok`.
- Cold-start PID `77238` used the same isolated root. Normal-root open-file
  count was 0 before and after navigation; preview mode dispatched no provider.
- The full App path was targeted explicitly. AX showed one `Coding 牧场`
  window, one `隔离恢复验证`, `保存原文，已完成`, and
  `正在恢复，正在进行`; `提炼要点`, `识别需求和待办`, and `准备确认`
  current-stage nodes were all absent.
- `evidence/preview-smoke.png` is a true 1190 × 732 RGB PNG with SHA-256
  `8623453541c08c538eab784bac1872fee86e1e497c553ce9576b50ae4f84a9c3`.
- Full-path Quit exited PID `77238`; no App or child process remained.

This retry, considered by itself, satisfies the six isolated-preview
observations in leaf §11.

### 6.2 Rejected normal-data incident

The first isolated bootstrap itself was correct:
`/private/tmp/agentloop-a2-preview.HYNZ7a`, PID `73059`, exact preview
environment, isolated DB/WAL/SHM/lock, and normal-root open count 0.

During UI targeting, a Computer Use display-name lookup auto-launched the
installed `/Applications/AgentLoop.app` as PID `74836` while the isolated
development App was already running. Read-only process inspection proved that
the installed process opened four paths under
`/Users/muzi/Library/Application Support/AgentLoop`:

- `.agentloop.lock`;
- `agentloop.sqlite`;
- `agentloop.sqlite-shm`;
- `agentloop.sqlite-wal`.

Both processes were quit and no AgentLoop process remained. That entire attempt
is marked `preview.bootstrap.result=invalid`; it is not counted as green
preview evidence. No normal DB contents were inspected, printed, exported,
reset, or deliberately mutated. However, because there was no pre-incident
content hash and the normal process did open SQLite state, this report does
not claim that the incident made zero normal-data access or zero mutation.

The later fresh retry is valid and uncontaminated, but it cannot retroactively
make the historical incident satisfy the leaf's `不得读写/重置 normal DB`
red line. The independent reviewer must decide whether this is a blocking
P0/P1 or an explicitly rejected operational attempt that can be separated
from the accepted preview gate. Until that verdict, acceptance and A3 remain
closed.

The complete incident and retry records are preserved in
`evidence/preview-bootstrap.log` and `evidence/preview-cold-start.log`.

## 7. Evidence hashes

| Artifact | SHA-256 |
|---|---|
| `verify.log` | `354c0165ad261d7ec7a47b1cd2e7fe83db81fbf5ac10ce9ff0fce40ed0ccd861` |
| `red-tests.log` | `30f80fb1a90889ac1e6c207e58464509924358a4936d5058259bc23ed9b3ac46` |
| `build.log` | `b5c4aca2d6484ac8778fb65f942fc463eb3075380aa94190b113ce693937882d` |
| `migration-matrix.log` | `be62651c13e3dd3b05cedb4f074d1f6a0020ba6c8f79f648c7d5926970830940` |
| `evidence/source-gates.log` | `f52b1a98a81e39fed0d3c619ecca81dfa34f22eaf1fd507d79dbf2ed56c5e7d2` |
| `evidence/hash-manifest.log` | `12617d5dd3bb43eb9d10074a0aa5fe50328b88c22dac40232fc90f7e10a2765f` |
| `evidence/preview-bootstrap.log` | `9ec0fd18369e4d7f3e9f78afb59e55a8072dbee7e0611f5c74c68df414589bd0` |
| `evidence/preview-cold-start.log` | `04f0b602b465a7c8521a8ef9af058ce47477ba380f4ef4243ef33ce323017795` |
| `evidence/preview-smoke.png` | `8623453541c08c538eab784bac1872fee86e1e497c553ce9576b50ae4f84a9c3` |

## 8. Deviations and disposition

1. **Test polling helper.** The iteration-based `a2Eventually` timeout failed
   under the combined matrix because scheduler yields were not elapsed time.
   The root cause was repaired within the allowed test file using
   `ContinuousClock`; final targeted and full gates passed.
2. **Matrix Stage hash.** The script's embedded Stage hash was mechanically
   synchronized as explicitly authorized. Restoring that one line reproduces
   the frozen script byte hash.
3. **Preview targeting incident.** The display-name UI lookup launched the
   installed normal App and opened four normal-root files. The attempt was
   rejected, all processes were closed, and a fresh full-path retry passed,
   but the historical normal-data access cannot be denied or undone. It is the
   only unresolved disposition delegated to independent review.

No unexplained source, schema, dependency, target-graph, API, event, immutable,
or scope deviation remains. A2 implementation Review and acceptance are still
closed, and A3 has not started.
