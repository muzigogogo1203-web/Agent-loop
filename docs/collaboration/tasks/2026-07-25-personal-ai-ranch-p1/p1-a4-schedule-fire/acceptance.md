# P1-A4 Independent Acceptance — Schedule Fire Evaluation/Commit

> Final status: **ACCEPTED**
>
> Date: 2026-08-11
>
> Acceptance owner: fresh, responsibility-isolated independent acceptance owner
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Responsibility isolation and boundary

This owner did not plan, implement, test, or review A4. The acceptance pass was
read-only except for this file. It did not rerun tests, builds, the migration
matrix, source gates, the App, or either preview; and it did not modify product,
test, script, Package, plan, manifest, evidence, review, or report bytes.

The decision independently read the accepted master specification, canonical
P1 Stage/Plan and P1 control indexes, the complete A4 leaf and Revision 01,
Reviews 01/01A/02/03, all 13 current implementation/test/script paths, the
entry manifest, all final evidence logs, and `impl-report.md`. It also performed
only cheap read-only current-byte, source-partition, Git-scope, and process
checks.

## 2. Authority and reviewed-byte identity

The controlling authority remains:

| Surface | Current SHA-256 / state |
|---|---|
| accepted master spec | `79c266fccccbc6383cfc4cd528b22a39a55a6dc829c0250e3702ace2b8f55ad1` |
| canonical P1 Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| canonical P1 Plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| A4 leaf `plan.md` | `b537965f8455c120331c9bd4eb7a228e563bff741312532854196733f8d405c7` |
| A4 `plan-revision-01.md` | `fe537a6c5c09c43105559b36f009a8696f312d28142874c9b6f75849ca561dd8` |
| Review01A | `efaa13fe6994ea937d761ab37a6799d2eec8b34e057039b75773092eaca5a517`; `APPROVED — 0 P0 / 0 P1 / 0 P2` |
| final implementation Review03 | `b6969d04c87b34e0c31e9b5fc869a7b2bbce290db5f1e3a54b38eb256e7f1112`; `APPROVED — 0 P0 / 0 P1 / 0 P2` |

The exact 13-file A4 implementation boundary is the final reviewed state:

| File | Current SHA-256 |
|---|---|
| `Sources/AgentLoopCore/Database/ScheduleStore.swift` | `96a4757ba437d1fe860d912c25460a43287037e772255afec6e57d6723381edc` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `3bd30625a696c88b481297ca885454f6e448c893c39d365b15085d5f0b74b91e` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `Sources/AgentLoopCore/Kernel/Orchestrator.swift` | `b588211d628eb45d6190eb141033f47cae2829dba5cf1b0f7011097659dfc285` |
| `Sources/AgentLoopCore/Kernel/ScheduleMath.swift` | `fab4ca7e02a1cf141a0ded3f5c8554fca492c661327e2c360602fdc1105cc6fc` |
| `Sources/AgentLoopApp/MissionScheduler.swift` | `aa5cacf6193558282f2e4d4b3380dd5888597abeed98993ca51e1523a04ff157` |
| `Sources/AgentLoopTestSuite/ScheduleTests.swift` | `d8010e5ee120e009c9c4cd854a8a89844b26125d05047db645e36b6349068a7a` |
| `Sources/AgentLoopTestSuite/DatabaseTests.swift` | `89d95e43fc8fe3601c7d1a875ccf20c9029f3e3fb4c18c708d09d6d117c53e1a` |
| `Sources/AgentLoopTestSuite/DurablePlanningTests.swift` | `8e453e656196a9f42946021c38cf362449b8b56e3056316887b1efc4288b7a45` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `16198ecd60f29363fbe8ff6f38f05e942c85207a1d486ea0f42e3ae3ea278c92` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `7820a9c64c6fc10e67bb373d89f9e0fa6bb0cacbe6a4b7e7e7c8b318d081f973` |

The entry manifest remains exactly 206 sorted unique entries at
`6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71`.
An independent current read found 219 regular files in the protected
Sources/scripts/Package boundary, all 206 manifest hashes matched, the exact
complement was the 13 paths above, and the boundary contained zero symlinks.
`git diff --check` passed. The intentionally dirty P1 worktree was not cleaned,
reverted, staged, or committed.

## 3. Final evidence identity and disposition

| Evidence | Final SHA-256 | Acceptance observation |
|---|---|---|
| `red-tests.log` | `8093d025e9d2bbe704b81ff6ad3dc720041beaefcc7fe39679a12de54a793712` | Preserved failure-first A4 capability run; it is historical evidence, not substituted for final green evidence. |
| `targeted-tests.log` | `b6bd683e69da9e87f5dd05eefaf80b56d6b388dc6adf38f8004fee96b40ee101` | All 10 canonical and all 10 affected tests pass independently from final bytes. |
| `build.log` | `90e3d049de6fa4ad6f91e3103b44937f4937a2f9d9ef1164b3aaecd48201049a` | Debug/release Core, TestSuite, and App gates pass. Only the recorded environment driver notice and two pre-existing non-A4 BoardServer warnings remain. |
| `migration-matrix.log` | `e14da0ac9ae79e1a7449e4f4fd33abef4fe3002532792d10bc965cfd533b3777` | SQLite 3.51/3.52 real and literal lanes, all seven predecessors, replay, rollback, constraints, inherited diagnostics, FK and integrity gates pass; terminal result is `p1_migration_matrix.result=pass`. |
| `source-gates.log` | `07cd5eb5ac83ad00948f93b26f26bff043c48593ae38eea93792ebc3d0e0fb70` | All 17 manifest, scope, owner, fetch-only, replay-binding, symbol, preview-source, migration, build, and diff gates pass. |
| `verify.log` | `35f2e0923604259a8db5b578e37a195231aeaf2a8583724d786f0f9feb9f0a27` | One fresh unfiltered authoritative run ends with exactly **667 tests in 7 suites passed**. |
| `preview.log` | `6becf3bd82608eedef8adf7dc288be46b66ee16e34e1232a365499c9f6f986ea` | Two distinct cold isolated previews pass. |
| `impl-report.md` | `65dd122b11bd059c1557bf5264f3cc3181f10a25f526a47f924a5e8a66fbaf10` | Final report records the root causes, corrections, evidence, and authority limits. |

The accepted preview claim is deliberately bounded to the recorded runs. Each
run used a distinct absolute isolated state root, launched exactly one checkout
executable, created its isolated database and lock, observed seven isolated
open files and zero normal-root matches, remained alive through the bounded
window, terminated gracefully, and left zero process before the next run. A
fresh read-only process check at acceptance also found zero `AgentLoop`
processes. This does not claim filesystem-atomic observation or authorize
normal-data inspection; it establishes the reviewed safe preview disposition
only.

## 4. Independent completion-gate decision

| Required A4 row | Decision | Evidence basis |
|---|---:|---|
| Exact v12 schema and replayable migration | PASS | `v12-p1-schedule-fire` is the final migration with exact two tables, three named indexes, 29/60/4 checkpoint, Stage §18.2 CHECK/FK shape, seven predecessors, idempotent replay and rollback across SQLite 3.51/3.52. |
| Fetch-only ledger boundary | PASS | Fire/cursor records conform only to `FetchableRecord`; production reads use explicit SQL; all production fire/cursor writes are confined to the one nested fileprivate ledger. The compiler-surface regression proves GRDB generic mutation APIs are unavailable. |
| Original fire atomicity and cursor semantics | PASS | Started commits one Squad/Mission/planning-work/fire/event graph, cursor, and last-fired update in one transaction; failed originals commit only the canonical missed fact and cursor. Cursor ordering/version and zero-write stale/integrity paths are covered. |
| Replay identity and provenance | PASS | Same key/same complete identity returns the first graph without provider or writes; conflicts fail closed. The shared read/writer winner validator binds the retained failed source, canonical payload/hash, selected work input, and Mission identity. |
| Failure classification and fail-fast behavior | PASS | Fixed typed business/provider outcomes persist only their exact safe code/message; unknown, database, canonical, numeric, constraint, corruption, and unsupported paths throw and roll back. |
| Slot, Date, and DST contract | PASS | Gregorian/POSIX, exact zone, finite/range/bit identity, raw UTF-8 cursor ordering, spring gap and repeated fall-back instants, numeric storage and close/reopen bit round-trip are covered. |
| Restart, concurrency, and no-spin behavior | PASS | Commit-before-kick survives restart; original and replay races produce one graph with deterministic inserted/replayed dispositions; a failed slot cannot auto-retry or spin, and replay never moves cursor or `lastFiredAt`. |
| Post-commit effects | PASS | Wake, guide broadcast, and callback follow the disposition matrix. Replayed results do not duplicate inserted-only effects, and wake/broadcast/callback failures cannot rewrite fire truth. |
| Redaction reservation and deletion | PASS | `redactedAt` and exact CHECK are present, all A4 inserts use NULL, no premature F2 trigger/API exists, and retained Schedule/Template/Mission history is FK-restricted. |
| Tests, builds, matrix, source, and preview | PASS | Final evidence above is green and current-byte exact; 667/667 in 7 suites, six builds, both SQLite lanes, source/scope gates, and both isolated previews pass. |
| Independent implementation review | PASS | Review03 is `APPROVED — 0 P0 / 0 P1 / 0 P2` and explicitly closes both Review02 findings. |

No unresolved Open Question, red final test, unknown failure, scope drift,
silent fallback, default success, open P0/P1, or unmet A4 completion gate was
found.

## 5. Review history and correction disposition

Acceptance preserves the complete review history; it does not wash a rejected
predecessor green.

- Review01 remains `CHANGES REQUIRED — 0 P0 / 5 P1 / 1 P2`. Revision 01
  decision-completely closed its effect-disposition, total slot/date,
  failure-mapping, source-partition, preview, and catchup-limit findings;
  Review01A then approved the plan at 0/0/0.
- Review02 remains `CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2`. Its first P1
  proved that `TableRecord` exposed forbidden GRDB update/delete APIs; the
  correction removed that conformance, moved every read to explicit SQL, and
  added an actual compiler-surface regression. Its second P1 proved that a
  canonical but payload-different work/Mission graph or source-provenance graph
  could pass replay-winner validation; the correction binds source, payload,
  work, and Mission identity in the shared winner validator and adds both
  coherent-corruption regressions.
- The full-suite-discovered test isolation race remains honestly recorded in
  `impl-report.md`; the bounded test-only correction waits on the supervisor's
  real idle contract after recovery. It does not change product behavior or
  use sleep, polling, retry, or fallback.
- Final post-correction targeted, build, matrix, source, full-suite, and
  preview evidence was regenerated from the final bytes and independently
  re-reviewed by Review03 at 0/0/0.

## 6. Acceptance and next gate

**ACCEPTED.** P1-A4 Schedule Fire Evaluation/Commit is complete. **R-04 is
CLOSED**: schedule evaluation can no longer consume a slot independently of
its durable terminal graph, failed slots no longer spin or auto-retry, explicit
replay is provenance- and payload-bound, and post-commit effects cannot rewrite
committed fire truth.

This acceptance opens **only bounded Level-3 planning for P1-B — Error
Visibility and Application-Layer Seams** under the accepted master/Stage/Plan.
P1-B product/test/Package/App/script implementation remains closed until a new
decision-complete leaf, exact allowlist/entry conditions/completion gate/red
lines, and a fresh responsibility-isolated plan review with zero P0/P1 exist.
P1-C and every later stage remain closed. This acceptance does not pre-accept
P1-B or authorize one invocation to cross the A4-to-B implementation boundary.

No commit, push, merge, release, destructive operation, normal-data access,
payment, public communication, external action, or real-user operation is
authorized by this acceptance.
