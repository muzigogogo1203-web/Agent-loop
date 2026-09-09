# Independent A1 checkpoint 1 migration review

## Verdicts

**Spec verdict: PASS for checkpoint 1 only.** Zero P0, P1, or P2 findings. The frozen dirty-preimage delta implements the admitted additive migration microstep and the single historical V17 setup correction without changing the approved SQL or historical assertions.

**Quality verdict: PASS for checkpoint 1 only.** The initial migration test exercises real fresh and V17-upgrade paths, compares persisted migration receipts and real SQLite schema, and uses literal expectations independent of the production SQL string. The retained focused RED/GREEN and historical V17 GREEN evidence is internally consistent and source-bound. This permits the next separately authorized A1 microstep; it is not A1 completion or acceptance of later work.

## Frozen inputs and boundary

- Reviewed the actual dirty-baseline package `goal-foundation-migration-checkpoint1.diff`, SHA-256 `b66e1accb13f99570776318216027424988549def4a838ff773985ff8f86312d`; no commit diff was substituted. The checkout remains on `codex/desktop-coding-closure-20260905` at HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`.
- The approved brief is SHA-256 `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82`. Its checkpoint boundary allows the new migration test, an appended migration after V17, and only the setup/read receiver correction in the named historical test (`.superpowers/sdd/goal-foundation-plan/task-1-brief.md:7-16`).
- Current checkpoint files match the package hashes: `AppDatabase.swift` `e6e1503e...`, `OutcomeContractTests.swift` `bbf348ad...`, and `DesktopGoalMigrationTests.swift` `c5b23d7b...`. The package also proves `InputGoalStore.swift` and `DurablePlanningTests.swift` remain byte-identical to their authoritative entry preimages.
- The current worktree contains later checkpoint-2 files and report text. They are outside this frozen package and were not treated as checkpoint-1 implementation or evidence.

## Concrete review results

1. **No finding — real migration paths and expectations are correctly bound.** `DesktopGoalMigrationTests.swift:154-189` creates two isolated real `DatabaseQueue` instances, migrates one fresh and the other explicitly through literal `v17-p1-engine-coordination` before advancing to head, then requires registered, fresh-persisted, and upgraded-persisted heads to be `desktop-goal-workflow-v1`. It also compares the complete migration receipt arrays and carrier schema snapshots, so the test cannot pass from a fabricated marker or a single-path fixture.

2. **No finding — schema assertions are literal and sufficiently exact for this microstep.** `DesktopGoalMigrationTests.swift:68-150` reads actual `sqlite_master`, column, foreign-key, and index metadata. `DesktopGoalMigrationTests.swift:191-280` independently asserts the complete normalized DDL for both tables and the partial unique index, ordered column shapes, zero context foreign keys, the sole operation-to-context foreign key with `NO ACTION`, the single indexed column, uniqueness/partial flags, `foreign_key_check`, and `integrity_check`. These expectations match the approved SQL at `goal-flow-plan.md:86-119`; they do not import or derive expected SQL from production.

3. **No finding — production SQL is the exact admitted additive delta.** `AppDatabase.swift:4676-4694` retains the existing V17 registration and body; `AppDatabase.swift:4695-4732` immediately appends named migration `desktop-goal-workflow-v1`. Its only statements are the approved `desktop_goal_context`, `desktop_goal_operation`, and `desktop_goal_one_pending` definitions. There is no backfill, goal foreign key, trigger, old-migration edit, fallback, or error-swallowing path.

4. **No finding — the historical V17 contract remains historical.** `OutcomeContractTests.swift:406-444` now creates a temporary queue, migrates it explicitly up to V17, and changes only the three read receivers from the latest-schema `AppDatabase.pool` to that queue. The literal V17 head assertion, fourteen-object check, and frozen `79 / 208 / 84` assertions remain unchanged; the shared `p1dDatabase` helper is untouched.

5. **No finding — the compile-only correction preserved the behavioral test.** The preserved `goal-foundation-migration-compile1-before.swift` differs from `DesktopGoalMigrationTests.swift:269-280` only by extracting the two throwing `PRAGMA foreign_key_check` and `PRAGMA integrity_check` queries into local bindings before applying the same predicates. It adds no catch/default, changes no literal or migration path, and therefore the earlier macro/compiler failure is correctly excluded from behavioral RED evidence.

6. **No finding — focused evidence is auditable for this checkpoint.** `goal-foundation-migration-red2.log:12-21` shows a successful build followed by the intended missing-head failure (`v17-p1-engine-coordination` versus `desktop-goal-workflow-v1`), exit 1. `goal-foundation-migration-green1.log:13-21` shows the same named test passing after the migration, and `goal-foundation-historical-v17-green1.log:3-11` shows the unchanged historical checkpoint assertions passing. Their process records identify PIDs 65109, 65794, and 66071, record exit statuses `1 / 0 / 0`, and contain 302 before plus 302 matching after hashes with zero mismatches for each run. The retained driver and duplicate-rpath warnings predate this delta (`runtime-cli-provenance-focused-069.log:7-11`) and no new source warning or error appears in the two GREEN logs.

## Scope limitations

- This review approves only the 284-line initial migration test, exact additive SQL, and single historical V17 setup correction in the frozen checkpoint-1 package.
- It does **not** review or approve in advance the other three required migration tests, strict domain coding, carrier capture/replay, stage/receipt CAS, retention/redaction hooks, foundation reads, exact four-file source-boundary successor, checkpoint 2 scaffolding or implementation, A2/A3, Provider/App/UI behavior, packaging, or product acceptance.
- The two focused GREEN tests are valid checkpoint evidence, not the authoritative unfiltered `swift run RunTests`, strict App build, independent final A1 implementation review, or later integration gates required by the brief (`task-1-brief.md:218-223`).
- The reviewer ran no compiler or test and mutated no source, real data, App/process, or Provider state. Evidence acceptance above is based on the retained complete logs/process records and recomputed hashes.
