# P1-A1b Independent Acceptance — Durable Planning Supervisor + Integration

> Final status: **ACCEPTED**
>
> Date: 2026-07-27
>
> Acceptance owner: fresh, responsibility-isolated independent acceptance owner
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Responsibility isolation and evidence boundary

This acceptance owner did not participate in P1-A1b planning, R11 canonical
revision, implementation, test implementation, evidence generation, Review11,
the initial Review01, or its independent re-review. The only repository file
written by this owner is this `acceptance.md`; product code, tests, plans,
reviews, logs, evidence, control/index documents, `blocked.md`, Package files,
scripts, and all other paths remained read-only.

The independent commands below wrote only ignored build or temporary matrix
artifacts. Their output was not redirected or appended to implementer-owned
logs. No commit, push, merge, release, data reset, payment, public
communication, external action, or real-user operation was performed.

The accepted preview was not relaunched because the raw process, environment,
visible-state, screenshot, and exit evidence was sufficient. This owner did
not inspect, print, export, snapshot, or diff real UserDefaults or Keychain
contents.

## 2. Exact identity, frozen authority, and manifests

All hashes in this section were independently recomputed from the current
files before this acceptance file was created.

| Input | Current SHA-256 / value | Result |
|---|---|---|
| Branch | `codex/personal-ai-ranch-p0` | exact |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` | exact |
| Status porcelain-z before acceptance | `e9ada2c5292cf3be9007967e34283e013ed5fdace29c8e1d160c720001b82c1a` | exact; dirty worktree preserved |
| Status porcelain-z after acceptance path creation | `e9ada2c5292cf3be9007967e34283e013ed5fdace29c8e1d160c720001b82c1a` | unchanged because default Git status already coalesced the untracked P1 parent tree |
| Frozen Stage | `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2` | exact |
| Frozen total Plan | `143db98e995ddc1c182e13fd22ab1a52a6517b6610e7bdb070f731c790d180a0` | exact |
| Frozen A1b leaf | `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56` | exact |
| R11 freeze evidence | `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` | exact |
| Review11 | `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` | `APPROVED — 0 P0 / 0 P1` |
| A1a acceptance | `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` | `ACCEPTED` |
| Final implementation Review01 | `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` | `APPROVED — 0 P0 / 0 P1` |
| Implementer final-hashes artifact | `a8a231f4bfe177ea881ab596cb222f0a906557077c2cb7f513186f116f1298e7` | exact |

The implementer-owned `final-hashes.txt` intentionally records initial
Review01 SHA-256
`05ac137b93c94e04d51cbd72cf24d047b321a55beaaa24c56dcf16eca563a4a3`
and its historical `CHANGES REQUIRED — 0 P0 / 2 P1` verdict. It correctly
does not self-reference or pre-record the later independent re-review hash.

Immutable entry inputs remain byte-identical:

| File | SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

The current 37-entry manifest was independently recomputed in frozen leaf §3
order. Every per-file hash matches `evidence/scope-and-hashes.txt`:

| Manifest | Entries | Current aggregate | Result |
|---|---:|---|---|
| Production | 13 | `c311118ebf9f8ae5f999e4b7e46b353f2377aef7f8e66873152de36c0e708562` | exact |
| Tests | 19 | `3142499b7e1ce6bb48f8f5cdb135dce2658dcb51b30c7b67d7e5c673cf2139b2` | exact |
| Runner / immutable | 5 | `8addcb922fcb45f2d4e28af2e070df038da3d40bd5c927c70135b0b198df45b5` | exact |

The four-file Review01 repair delta was also independently reconstructed by
substituting the recorded pre-repair hashes into the current manifest. It
reproduced the initial Review01 aggregates exactly:

- production before/after:
  `f5dad4a5d4477e757ae4cd019f61151e2449be01e82cba7b3ffbbcc36338f7e8`
  → `c311118ebf9f8ae5f999e4b7e46b353f2377aef7f8e66873152de36c0e708562`;
- tests before/after:
  `68c2185d483676e571d073ec3f41dcc1a65064260618e98b1d25537c2f7c3291`
  → `3142499b7e1ce6bb48f8f5cdb135dce2658dcb51b30c7b67d7e5c673cf2139b2`;
- runner/immutable remained
  `8addcb922fcb45f2d4e28af2e070df038da3d40bd5c927c70135b0b198df45b5`.

The four current repair file hashes are:

- `AppStore.swift`:
  `2eb60d210bfc6d59c60afa4a2b272811af9b5b4ab8e674ceea397687799adf33`;
- `DurableWorkSupervisor.swift`:
  `e1991b398299898f5582e0826efa345bac501afd998e2f695af6e81ef539aa79`;
- `CrashRecoveryTests.swift`:
  `9f544fc2642aaa492c5732db04bfd2272c0a0699a1357c6de6589e409ef05650`;
- `DurablePlanningTests.swift`:
  `2929b9aecc20c21083cd5daa2f7ab61eb05c6c2ef9a815d832cf86b3c3b94fce`.

The repository was already dirty. Acceptance therefore does not make a
clean-worktree claim. The frozen manifests, current status hash, four-file
repair reconstruction, and owner-artifact hashes establish attributable
scope while preserving unrelated pre-existing changes.

The default porcelain-z hash remained unchanged after file creation because
Git was already reporting the whole untracked P1 parent directory as one
coalesced entry. With `--untracked-files=all`, the new path is an explicit
single `??` record: the fully enumerated post-create status hash is
`440a30714e3a355268dc942100aae6b8e2608bbf09130dbe24a6357cda8aed7d`;
removing only that exact record reconstructs the pre-create hash
`2a1a6745971be6d65ef1620bd533c6f4398a38ea3b0b53b147f81e667fcacc8b`.

## 3. Independent current-source contract audit

The current implementation and tests were inspected against the frozen Stage,
total Plan, and leaf rather than accepted from summaries alone.

- Durable planning identity is canonical and replay-first. Mission, Squad,
  events, and planning work share the specialized transaction; same-key replay
  validates persisted identity/graph before credential, catalog, endpoint, or
  provider construction and preserves the first trace.
- All nine generic durable-work mutation/dispatch APIs reject `.planning`
  according to the required validation priority. Read seams remain available.
  `PlanningDurableWorkLedgerOwner` exists exactly once as a `fileprivate enum`;
  specialized planning provider, recovery, single-cancel, and bulk-halt paths
  do not use generic mutation capability.
- Resolver authority uses the captured profile/model and the frozen
  profile-specific catalog/credential rules without current-default or
  provider fallback. Planner owns at most the schema-correction turn and does
  not own durable retry or fallback.
- Success, failure, retry, overflow, single cancel, and halt cleanup are
  transaction-atomic. Nil, zero, negative, overflow, and integers above 2^53
  retain their exact typed/canonical meanings without trap, saturation, or
  prefix accounting.
- Manual, Candidate, Schedule, and confirmed Proposal starts all use the same
  package `PlanningEntryCoordinator`. App source tests and executable
  sentinels prove there is no direct start/confirm/claim/link bypass.
- Schedule `lastFiredAt` writes numeric epoch seconds only for that column,
  while `.deferredToDate` continues to read legacy TEXT and new INTEGER/REAL.
  Non-finite fire dates fail before UUID, runtime selection, preparation
  `Result`, and claim; finite checked-millisecond overflow remains
  claim-then-one-missed.
- Running startup remains process-locally `.recoveryReady + suppressed` until
  Card recovery/healing, transition-token checks, and the internal durable-mode
  fence finish. Recovery retry branches, emergency control, resume, fatal
  ownership, late provider, terminal proposal retention, waiters, and bounded
  shutdown follow the frozen owner model.
- Running legacy-with-Cards throws the exact package
  `LegacyPlanningHasCardsError` with zero writes. Unexpected fallback enters
  the normal provider-completion/pending/failure owner only through the narrow
  matching-DEBUG owned-work seam; release objects contain no seam symbol.

The two initial Review01 P1 findings are closed in current code and tests:

1. Preview defaults routing occurs before AppStore's first preference access.
   Preview uses one locked `ProcessLocalPreviewUserDefaults`, and the same
   dependency reaches `ProfileScopedDefaults`, fresh-profile bootstrap,
   resolver, scheduler, reload, catalog, persistence, and OAuth state.
   Normal mode alone returns `.standard`; current AppStore source has no
   `UserDefaults.standard`, zero-argument `ProfileScopedDefaults()`, or
   zero-argument `ModelCatalogService()` bypass.
2. `isIdleNow()` no longer treats every suppressed state as idle. It first
   requires no owned work, pump, or pending halt cleanup; only exact durable
   halted may take the suppressed direct-idle path. Durable-running
   `.recoveryReady|.running` queries specialized next-due state, so due work
   blocks, future retry does not, and restored-halted cleanup can settle idle.

## 4. Independent reruns on the accepted source

| Gate / command | Independent current result |
|---|---|
| Focused five-test Review01 gate | `5/5`, 0 issue, 0.538 s |
| `swift run RunTests` | `611 tests / 5 suites`, 0 issue, 42.853 s |
| `swift build --product AgentLoopApp` | PASS, exit 0 |
| `swift build -c release --product AgentLoopCore` | PASS, exit 0; SwiftPM emitted only its known automatic-product warning |
| DEBUG declaration/call protection | Core `1/1`; required test files `3/3`; all TestSuite references `5/5` guarded |
| Release seam symbol | 86 release Core objects inspected with `nm`; symbol absent |
| Frozen §12 name gate | `115 required / 115 unique / 115 exact_once / bad=0` |
| Total-Plan source sentinels | all PASS; old split API, `planningTasks`, App bypasses, public specialized mutation, generic planning defaults, and reactive re-suppress absent; ledger owner exactly 1 |
| Preview-default bypass source gate | PASS |
| `git diff --check` before acceptance | PASS |

The exact focused filter covered:

- `uiPreviewUsesProcessLocalDefaultsBeforeBootstrapAndReload`;
- `suppressedWaitUntilIdleDistinguishesDueFutureRetryAndHaltedCleanup`;
- `waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot`;
- `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`;
- `haltedStartupRunsCleanupWithoutPumpTimerOrProvider`.

The single independently executed matrix command was:

`scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52`

It exited 0 with:

| Lane | Linked / literal | v12 durable evidence | Diagnostics | Result |
|---|---|---|---|---|
| SQLite 3.51.0 | both | snapshot, double replay, replay, FK, integrity, DDL, append-only all pass | work `56=18/38`; attempt `40=10/30`; event `288=17/271`; sentinel `7=0/7`; control `19=19/0` | `matrix.result=pass`, `literal.3.51=pass` |
| SQLite 3.52.0 | both | snapshot, double replay, replay, FK, integrity, DDL, append-only all pass | work `56=18/38`; attempt `40=10/30`; event `288=17/271`; sentinel `7=0/7`; control `19=19/0` | `matrix.result=pass`, `literal.3.52=pass` |

The matrix's append-only, CHECK-constraint, and forced missing-table errors are
expected negative probes. They are followed by the required rollback and lane
passes; the final line is `p1_migration_matrix.result=pass`. No matrix failure
was omitted or reclassified.

## 5. Raw preview acceptance

The accepted retry is the raw-evidence run rooted at
`/private/tmp/agentloop-a1b-review01-preview.sy7T0L`, PID `51258`.

- Exact environment contained `AGENTLOOP_UI_PREVIEW=1` and the isolated
  `AGENTLOOP_STATE_DIR`.
- DB, WAL, SHM, and lock were under the fresh root; normal App Support open
  count was 0.
- Visible state showed `Coding 牧场`, `我的营地`, `基础牛，空闲`,
  `发起放牛…`, and the no-model first-run explanation.
- No blocking credential, Keychain, or error prompt was visible.
- Main thread was in the normal `NSApplication` event loop with no
  `SecItemCopyMatching` frame.
- `evidence/preview-smoke.png` was independently checked and visually
  inspected: true 1190×732 RGB PNG, SHA-256
  `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8`.
- Command-Q exited PID `51258`; shell-only process inspection found no
  remaining AgentLoop process and no post-quit UI probe was run.

The earlier automatic non-preview relaunch PID `51012` is not counted as
green. It was an unintended post-quit Computer Use relaunch after repaired
preview PID `50856`; it lacked both preview environment variables, was
terminated by exact PID, and no defaults or Keychain contents were inspected.
That entire run is explicitly rejected. The accepted retry began with no
AgentLoop process, used a new root, and left no process. There is no evidence
that PID `51012` contaminated the accepted retry, but it is not interpreted as
proof of zero normal-domain access.

## 6. Frozen leaf §15 completion gates

| # | Completion gate | Current/raw evidence | Verdict |
|---:|---|---|---|
| 1 | Review11 exact approval | Frozen hashes and Review11 SHA rechecked; exact `APPROVED — 0 P0 / 0 P1` | PASS |
| 2 | Diff/scope limited to allowlist and owner artifacts | 37-entry current manifest, status hash, R11→final delta, and four-file Review01 reconstruction match; unrelated dirty work preserved | PASS |
| 3 | v12/A1a/Package/Resolved/RunTests/target graph unchanged | Exact immutable hashes; runner change limited to approved Stage-hash synchronization | PASS |
| 4 | R-01 failure-first reproduced and closed at cause | `preflight.txt` and raw `verify.log` retain atomicity, replay, usage overflow, halted generic claim, and bounded-shutdown red roots; current named/full tests pass | PASS |
| 5 | Generic planning sealed; read/specialized owners valid | Current source audit, named positives/negatives, source gate, and one fileprivate owner | PASS |
| 6 | Four real entries delegate one package coordinator | Coordinator functional tests, five App source-order/direct-call tests, and sentinels pass | PASS |
| 7 | Schedule numeric/deferred compatibility | Current code plus extreme finite, legacy TEXT, numeric reload/dedupe, and other-Date tests pass | PASS |
| 8 | Non-finite pre-guard and finite-ms missed semantics | Current coordinator order, zero-write test, overflow claim→missed test, and unchanged claim/schema tests pass | PASS |
| 9 | Atomic Mission/work and replay-first identity | Current transaction/replay source and named replay/conflict/first-trace tests pass | PASS |
| 10 | Resolver preflight with no fallback/current default | Current strict resolver and complete profile/catalog/credential/OAuth/endpoint/claim tests pass | PASS |
| 11 | Planner has no durable retry/fallback | Current planner classification/usage flow and provider-failure/no-fallback tests pass | PASS |
| 12 | All projections transaction-atomic | Success/failure/overflow/cancel/halt rollback and ownership tests pass | PASS |
| 13 | Exact usage facts, no trap/saturation/prefix | Nil/zero/negative/overflow/>2^53 typed tests and canonical source audit pass | PASS |
| 14 | Two-phase running startup and retry split | Current lifecycle/token/fence code, focused tests, and all frozen recovery tests pass | PASS |
| 15 | Halt/resume/races/late provider/bounded shutdown | Current source and full race/restart/shutdown named matrix pass; reactive re-suppress absent | PASS |
| 16 | Typed legacy Cards failure and DEBUG fallback owner | Exact error/zero-write test, focused fallback test, DEBUG `1/1` + test guards, and 86-object release symbol absence | PASS |
| 17 | Old split API and all R11 forbidden sentinels absent | Total-Plan executable fail-fast source/release gate passes | PASS |
| 18 | Named `v12-durable` on linked SQLite 3.51/3.52 | Independent single full matrix has all required linked sentinels and diagnostics | PASS |
| 19 | Full tests/build/matrix/isolated preview/diff/hash green | 611/611; App/release builds pass; matrix final pass; accepted PID 51258 evidence; hashes/diff exact | PASS |
| 20 | Complete report/logs/deviations | `impl-report.md` maps changed files and raw logs; artifact hashes exact; deviations below fully disposed | PASS |
| 21 | Independent implementation Review has 0 P0/0 P1 | Final Review01 SHA exact; initial two P1s preserved and independently verified closed | PASS |
| 22 | Independent acceptance | This fresh owner finds all prior gates green and no unresolved P0/P1/unknown | PASS — `ACCEPTED` |

## 7. Historical failures and deviation disposition

Historical failures are retained rather than silently removed:

1. The original R-01 and R11 failure-first tests failed on their intended
   roots and now pass on current source.
2. `slowActiveStreamDoesNotIdleTimeout` previously showed the recorded
   concurrency-sensitive `idle script exhausted` failure; later saved full
   runs and this independent 611/611 run pass it.
3. The cancellation-ignoring provider fixture originally blocked only a
   detached stream producer. The allowed test double was corrected to block
   the Supervisor-owned task; production assertions were not weakened.
4. `build.log` retains the zsh readonly `status` wrapper failure. The same
   fail-fast gate was rerun under Bash and passed; this acceptance reran the
   Bash source/release/symbol gates successfully.
5. The matrix log retains an old embedded Stage-hash fail-fast. The only
   runner/script change is the leaf-authorized Stage-hash synchronization;
   the independent current full matrix passes both versions and lanes.
6. Preview PID `16652` exposed the OAuth Keychain main-thread bypass; PID
   `20227` proved the Keychain repair but still predated the Review01 defaults
   repair. Both are historical/rejected evidence, not the accepted gate.
7. Initial Review01 found shared preview UserDefaults writes and a suppressed
   idle shortcut. Both were failure-first reproduced, repaired in four
   allowlisted files, covered by deterministic regressions, and independently
   re-reviewed and rerun here.
8. Repaired preview PID `50856` was rejected after the unintended non-preview
   PID `51012` relaunch. PID `51012` was terminated and is not counted green.
   The later fresh PID `51258` retry is the sole accepted preview.

No unexplained deviation, red result, unknown failure, hash drift, remaining
process, P0 finding, or P1 finding remains.

## 8. Scope, non-goals, and final verdict

This acceptance covers only P1-A1b durable planning supervisor and integration.
It does not accept or implement A2 Rumination, A3 Candidate atomic conversion,
A4 Schedule Fire schema/claim semantics, later P1 slices, provider-internal
redesign, Camp retirement/deletion, release behavior, or real-user actions. It
does not authorize commit, push, merge, release, destructive data operations,
payment, public communication, or external actions.

**ACCEPTED**

All 22 frozen leaf §15 completion gates pass on the exact current identity.
This closes R-01 and opens only the frozen A2 entry gate. It does not implement
A2 and does not broaden authority.
