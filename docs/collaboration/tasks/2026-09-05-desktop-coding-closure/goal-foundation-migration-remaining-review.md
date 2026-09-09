# Independent review — remaining A1 migration tests

## Verdict

**Spec: PASS for the remaining migration-test delta only. Quality: PASS for the same delta. Zero P0 / P1 / P2 findings.**

The three additional required migration tests exercise real SQLite behavior and preserve the previously approved fresh/upgrade test byte-for-byte. Their retained focused run records four tests passing with exit 0, and the reviewer independently verified the complete log, process evidence and all 305 source hashes. This verdict closes review of this test-only delta; it does not accept all of A1 or authorize a later stage.

## Scope and frozen identity

The review used `AGENTS.md`, the approved `goal-foundation-plan.md`, `.superpowers/sdd/goal-foundation-plan/task-1-brief.md`, and `goal-foundation-migration-checkpoint1-review.md`. It compared the actual dirty preimage with the current source, not HEAD. The authoritative checkout remains `/Users/muzi/Agent-loop`, branch `codex/desktop-coding-closure-20260905`, with substantial pre-existing dirty changes preserved.

| Input | SHA-256 |
| --- | --- |
| `goal-foundation-plan.md` | `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` |
| `.superpowers/sdd/goal-foundation-plan/task-1-brief.md` | `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82` |
| `goal-foundation-migration-remaining-before.swift` | `c5b23d7b4ba46162913c294e6b5b361ebd1826490df764edb633b8d3f0ffd218` |
| `goal-foundation-migration-remaining-tests.patch` | `d0c1f7ae8f432968baa7bd657c3acd84b6092ae18e10e4037d380eb31454673a` |
| `Sources/AgentLoopTestSuite/DesktopGoalMigrationTests.swift` | `ef98f27598096a16726555d455eb55c70543d4c194a65c277ae8f9dcdfab38b7` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `e6e1503ef9b140540fc0b8785a561ab3ce6ea1420cf634559fb00ee2168c59b0` |
| `Sources/AgentLoopTestSuite/OutcomeContractTests.swift` | `bbf348ad76f4b571e7f00b3c797b7ea1f403ab122aa3b59e70e8faef10600aa2` |

Only the 530 added lines in `DesktopGoalMigrationTests.swift` are the implementation delta reviewed here. A read-only reconstruction that removes the new helper section and the three added tests exactly reproduced the original 284-line preimage. The existing schema helper, fresh/upgrade test, literal DDL assertions and PRAGMA checks are unchanged. `AppDatabase.swift` and `OutcomeContractTests.swift` still match the approved checkpoint-1 hashes; no new migration production SQL or historical V17 test change accompanies this delta.

## Review results

1. **Legacy preservation and repeated migration are independently observable.** `DesktopGoalMigrationTests.swift:272` inserts a real camp, input envelope and linked goal into a temporary V17 database. At `:480`, the test captures every pre-existing user table's rows, compares them after migration, requires both new carrier tables to remain empty, and checks the exact ordered migration-receipt append. It then migrates again and compares the complete logical schema, all user-table rows, ordered receipts and schema counts against the first migrated state. `foreign_key_check` and `integrity_check` remain explicit. This proves unchanged seeded legacy data and repeated migration behavior without a backfill or fabricated carrier.

2. **The SQL constraint probes isolate their intended failure.** At `:544`, the five invalid inserts cover live context with NULL payload, redacted context with retained payload, prepared operation with NULL request, redacted operation with retained request, and redacted operation with retained result. Their IDs are distinct, their referenced context rows exist where needed, and all other checked fields are valid. The helper at `:199` accepts only `DatabaseError.extendedResultCode == SQLITE_CONSTRAINT_CHECK`; unexpected errors escape and a successful insert records a test failure. It compares both carrier tables before and after each rejection, preventing a passing constraint check from concealing a partial carrier mutation.

3. **SQL shape and receipt semantics are correctly separated.** The valid redacted operation retains only a constructed `DesktopGoalCaptureReceiptV1` while request/result remain NULL. The test reads the persisted receipt and decodes it through the canonical application codec. It then stores the intentionally shape-invalid `{"schemaVersion":1}` and requires application decode to reject it. The approved SQL does not promise to validate receipt JSON semantics, and the test explicitly preserves that boundary at `:682`. This is evidence for the tested malformed shape only; it does not claim every unsafe receipt or the future store read/redaction path has been covered here. Inspection of `DesktopGoalWorkflow.swift:388` confirmed that the decoder actually checks the exact outer keys and validates the nested capture receipt.

4. **Rollback is exercised after an earlier migration statement can execute.** At `:717`, a real V17 database with legacy rows is snapshotted before the deliberate `desktop_goal_operation` probe table is created. The real migration creates context first and conflicts on operation second. The test requires `DatabaseError`, `SQLITE_ERROR`, and the exact `table desktop_goal_operation already exists` reason. It then requires no context table, no pending index, no new migration receipt, and the original probe row still present. Only that deliberately created probe table is dropped; the final full logical schema/data/receipt snapshot must equal the original V17 state, including unchanged literal 79 / 208 / 84 counts. No production failure hook, broad cleanup or swallowed error is involved.

5. **The evidence matches this exact source.** The complete `goal-foundation-migration-complete-green1.log` records the original test plus all three new tests by their required names. The accompanying process record identifies the command `swift run --jobs 2 RunTests --filter DesktopGoalMigrationTests`, PID 77308, start `2026-09-06T22:18:51+08:00`, end `2026-09-06T22:19:10+08:00`, exit 0 and signal nil. Build time is 15.66 seconds; all four tests in one suite passed in 0.510 seconds. A read-only audit verified that all 305 before entries equal all 305 after-OK entries and the 305-entry source manifest, and `shasum -a 256 -c --quiet` independently matched that manifest against current files. The retained driver/rpath warnings do not report a test or compilation failure.

## Evidence hashes

| Evidence | SHA-256 |
| --- | --- |
| `goal-foundation-migration-complete-green1.log` | `4405267b03bfd61d5c6ec52be98dd1a788e9cb8f1db0617edea4cb740498478d` |
| `goal-foundation-migration-complete-green1-process.txt` | `4f8d7147680a55cc4b72cf388b83eed5d6e0f69950bf5141d9336f180bd2f7bc` |
| `goal-foundation-migration-complete-green1-source.sha256` | `bfcf020d3a32151c4923fb65b2ed25d4077f4bf2fe2e0a9a08658ae17689c54e` |

## Limits and handoff

- The added tests have a source-bound focused GREEN run. This review does not invent a separate RED run for each newly added test or extend checkpoint-1 RED evidence to them.
- The logical snapshot compares every non-internal table's projected rows and explicit schema objects, ordered migration receipts, and object counts. It does not claim physical SQLite file-byte equivalence or arbitrary-data corpus coverage.
- Foundation snapshot/list, retention hooks, unsafe safe-receipt handling through the store, and the other currently intentional Foundation RED tests remain outside this review. Their incomplete state is not masked by this migration-suite result.
- There is no full unfiltered `swift run RunTests`, strict App build, runtime/App acceptance, A1 final acceptance, A2/A3 entry, commit, push or release claim here.
- The reviewer ran no compiler or tests and touched no App, Provider or real database. The only write was this designated review artifact. Review and verification skills were used to separate source inspection, retained execution evidence and later acceptance; frozen-input discipline was used to check identities before and after the artifact write.
