# P1-A4 Leaf Plan — Schedule Fire Evaluation/Commit

> Status: **REVISION 01 — implementation blocked pending responsibility-isolated re-review**
>
> Date: 2026-08-10
>
> Branch / entry HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Authority: accepted master spec, P1 Stage §6.6 and §18.2, canonical P1 Plan §3.5/§10/§11, and accepted P1-A3 acceptance

> Current bounded override: `plan-revision-01.md`. Where Candidate 01 and
> Revision 01 conflict, Revision 01 is authoritative. Immutable Review01 is
> preserved in `reviews/01-p1-a4-plan-review.md`.

## 1. Entry, objective, and stop conditions

P1-A3 is independently `ACCEPTED`; R-03 is closed and only P1-A4 is open.
A4 exists to close R-04. The current route commits at least four independent
steps:

```text
claimScheduleFire(lastFiredAt)
  -> create Mission/Squad/planning work
  -> append schedule_fired
  -> append guide broadcast / notification
```

The first step can survive while the recoverable Mission/work does not, and a
validation failure writes only a legacy event without a durable evaluation
cursor. The result is a claimed slot with no work, repeat missed-slot scans,
and post-commit broadcast errors being reported as if the Mission never left.

Implementation may start only after a fresh responsibility-isolated reviewer
writes `reviews/01-p1-a4-plan-review.md` with `APPROVED` and zero P0/P1. Any
ambiguity, unknown failure, unlisted file requirement, or non-empty Open
Questions must be recorded in `blocked.md` and stops the slice. Internal hashes
may be recorded as evidence, but no user hash echo is required.

A4 does not authorize commit, push, merge, release, normal/destructive
user-data operations, payment, public communication, external actions, or
real-user operations.

## 2. Exact implementation allowlist

Canonical Plan §3.5 named eight files before A1b/A3 and the aggregate migration
matrix existed. Current code inspection proves five additional files are in the
same A4 root-cause boundary. The reviewed A4 allowlist is therefore exactly:

1. `Sources/AgentLoopCore/Database/ScheduleStore.swift`
2. `Sources/AgentLoopCore/Database/AppDatabase.swift`
3. `Sources/AgentLoopCore/Work/DurableWork.swift`
4. `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
5. `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
6. `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
7. `Sources/AgentLoopCore/Kernel/ScheduleMath.swift`
8. `Sources/AgentLoopApp/MissionScheduler.swift`
9. `Sources/AgentLoopTestSuite/ScheduleTests.swift`
10. `Sources/AgentLoopTestSuite/DatabaseTests.swift`
11. `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
12. `Sources/P1MigrationMatrixRunner/main.swift`
13. `scripts/verify-p1-migrations-sqlite-matrix.sh`

The additions are scope reconciliation, not product expansion:

- `Orchestrator.swift` owns the live claim/start route and post-commit wake;
- `ScheduleMath.swift` owns slot identity and DST behavior;
- `DurablePlanningTests.swift` contains five old claim-first tests and the
  source sentinel that otherwise rejects A4;
- the runner and script hard-code the previous final migration and assert that
  `schedule_fire` is absent, so leaving them unchanged would knowingly break an
  accepted verification path.

Task artifacts may additionally be created only in this task directory:
`red-tests.log`, `targeted-tests.log`, `verify.log`, `build.log`,
`migration-matrix.log`, `source-gates.log`, `impl-report.md`, `acceptance.md`,
`blocked.md`, and `reviews/`. `Package.swift`, `Package.resolved`,
`EventKind.swift`, `Sources/RunTests/main.swift`, dependency/target edges,
other App views, and every P1-B–P6 file remain closed.

## 3. Frozen data types and ownership chain

### 3.1 Records and terminal result

`ScheduleStore.swift` adds package-visible, `Sendable`/`Equatable` records for
the exact §18.2 columns:

- `ScheduleFireState`: only `.started` and `.failed`;
- `ScheduleFireRecord`: fetch-only in ordinary product code; it must not
  conform to `PersistableRecord` and gains no generic save/update/delete API;
- `ScheduleEvaluationCursorRecord`: fetch-only outside the ledger owner;
- `ScheduleFireDisposition`: `.inserted` or `.replayed`;
- `ScheduleFireCommitResult`: the fire, disposition, and optional exact
  `missionId`/`workId`. Started requires both IDs; failed requires neither.

The command boundary is package-only. It carries schedule ID, scheduled
instant, the caller-computed slot key, a frozen slot context, one trace ID, and
one typed preparation:

```text
runtime(profileId, plannerModel)
failure(code)
```

No raw `Error`, credential, provider response, or arbitrary error string may
cross or be persisted through that preparation. Replay adds the original fire
ID, a global replay key, and its canonical payload hash. Incoming trace is an
insert-only fact and is never replay identity.

### 3.2 Single transaction owner and call chain

The only normal original-fire chain is:

```text
MissionScheduler
  -> PlanningEntryCoordinator.startScheduledMission
  -> Orchestrator.commitScheduledMission
  -> DurableWorkSupervisor.startScheduledMission
  -> AppDatabase.startScheduledMission
  -> fileprivate ScheduleDurablePlanningLedgerOwner (one GRDB write tx)
```

The only explicit replay chain uses the same owners and ends in
`ScheduleDurablePlanningLedgerOwner.replayMissedScheduleFire`.

The ledger owner lives in `DurableWorkStore.swift` so it can reuse the accepted
planning payload/graph conventions without nesting public
`enqueueMissionPlanning` inside `pool.write`. It must not create a second
generic planning owner or bypass durable work.

After commit, and never before it, `MissionScheduler` independently calls:

```text
PlanningEntryCoordinator.wakeScheduledPlanning
  -> Orchestrator.wakeScheduledPlanning
  -> re-read work + durable dispatch mode
  -> DurableWorkSupervisor.kick
```

Only current queued/retry-scheduled planning work while both process and
durable dispatch permit running may be kicked. Running or terminal work is not
kicked. A failed transaction, failed fire, stale slot, or replay conflict is
never kicked. A crash between commit and kick is safe because the queued work
is recoverable.

No new public protocol/API or release-visible test seam is allowed.

## 4. Exact `slotKey` v1 contract

`ScheduleMath` replaces the legacy day/week-only key with one canonical UTF-8
string:

```text
schedule-slot:v1|f=<frequency>|c=<byteCount>:<calendarId>|z=<byteCount>:<timeZoneId>|p=<HH>:<MM>:<weekday>|r=<era>:<year>:<month>:<day>:<HH>:<MM>:<SS>:<nanoseconds>|o=<offsetSeconds>|i=<instantBits>
```

Rules are exact:

1. `frequency` is `daily` or `weekly`.
2. `calendarId` is the lowercase Foundation identifier token captured from the
   caller's `Calendar`; production is `gregorian`. `byteCount` is the UTF-8
   byte count, so embedded separators cannot create ambiguity.
3. `timeZoneId` is the exact non-empty `TimeZone.identifier`, also UTF-8
   length-prefixed.
4. `p` is configured local hour/minute, each zero-padded to two digits;
   weekday is `0` for daily and the configured `1...7` value for weekly.
5. `r` is the resolved local scheduled instant in the frozen calendar/zone.
   Hour/minute/second are two digits and nanoseconds are nine digits; other
   components are canonical base-10 integers without locale formatting.
6. `o` is `timeZone.secondsFromGMT(for: scheduledAt)` in canonical base-10.
7. `i` is exactly 16 lowercase hexadecimal digits from the normalized finite
   `scheduledAt.timeIntervalSince1970.bitPattern`; `-0.0` is normalized to
   `+0.0`. NaN and infinities are rejected before UUID, runtime selection, or
   database access.
8. The Store recomputes the key from the current schedule fields and the
   command's frozen Calendar/TimeZone values inside the transaction and
   requires byte equality. It never trusts an opaque caller key.

This includes frequency, calendar, zone, configured local slot, resolved local
slot, offset, and actual instant. The two fall-back 01:30 instants therefore
have different keys; repeated computation is stable. Spring-forward keeps the
configured `p=02:30` while `r` records Foundation `.nextTime`'s resolved 03:00
instant. `nextFireDate` continues using `.nextTime` and `.first` for its chosen
automatic occurrence; tests also construct the second repeated instant to
prove identity separation.

The frozen Calendar and TimeZone are captured before `MissionScheduler`'s
first `await`; `.current` is never re-read later in the command.

## 5. Evaluation cursor and due-scan semantics

`schedule_evaluation_cursor` is the only progress source for missed/due scan.
`lastFiredAt` is no longer a scan cursor.

- With no cursor, the baseline is `schedule.createdAt`.
- At startup, each enabled schedule evaluates at most the single latest
  scheduled slot on or before `now`; older offline slots are intentionally
  skipped rather than producing an unbounded backlog.
- A committed original started or failed fire advances the cursor to its
  `(scheduledAt, slotKey)`. First insert uses version 1; later advance uses a
  checked `version + 1` in the same transaction.
- Ordering is UTC `scheduledAt`, then raw UTF-8 `slotKey`. A strictly older
  original slot throws a typed stale-slot error with zero writes. An equal slot
  must resolve to the existing original fire; equal cursor with no matching
  fire is an integrity error, never a default success.
- Cursor never regresses. Replay never inserts, updates, or deletes a cursor.
- A disabled schedule is excluded from normal scans. If disable wins after a
  scan snapshot but before the writer re-read, that original slot commits a
  failed `schedule_disabled` fire and advances the cursor.
- A configuration/time-zone edit affects only slots after the current cursor.
  It does not resurrect or auto-retry an already evaluated slot.

Startup offline handling preserves the existing confirmation UX while making
it durable: the latest unconsumed slot is committed as a failed original fire
with `schedule_missed_while_offline`, and `ScheduleCatchup` stores that fire ID.
Decline removes the prompt. Confirm creates a new explicit replay; it never
reuses the original identity.

`runNow` is a new original evaluation at its captured actual instant. Its v1
key includes that instant, so a later explicit run-now is a distinct original
evaluation. The scheduled callback uses the exact planned instant passed to
the background scheduler.

## 6. Validation and failure classification

Every expected business/preflight failure becomes a terminal failed fire with
one safe code/message, except conditions that cannot be safely scoped by the
schema. Messages are fixed product strings no longer than 1000 characters;
raw provider/database errors are not persisted.

| Condition at writer truth | Result |
|---|---|
| schedule missing | throw `RecordNotFoundError`, zero writes; no valid FK scope exists |
| template missing or schedule/template FK mismatch | integrity/not-found throw, zero writes |
| Camp missing | integrity/not-found throw, zero writes |
| durable dispatch not running | existing halt/recovery error, zero writes |
| non-finite scheduled Date | `InvalidSchedulePlanningFireTimeError`, zero reads/writes |
| finite Date whose checked UTC milliseconds cannot form a planning identity | failed `schedule_fire_time_out_of_range` + missed event + cursor |
| schedule disabled | failed `schedule_disabled` + missed event + cursor |
| invalid hour/minute/weekday | failed `schedule_configuration_invalid` + missed event + cursor |
| archived Camp | failed `schedule_camp_archived` + missed event + cursor |
| invalid template name/goal/companions/budget/autonomy | failed `schedule_template_invalid` + missed event + cursor |
| missing companion | failed `schedule_companion_missing` + missed event + cursor |
| companion with nil/wrong Camp | failed `schedule_companion_wrong_camp` + missed event + cursor |
| App runtime selection, profile missing/CLI/kind drift | failed `schedule_runtime_unavailable` + missed event + cursor |
| planning provider resolver failure | failed `schedule_provider_unavailable` + missed event + cursor |
| startup detected offline slot | failed `schedule_missed_while_offline` + missed event + cursor |

The initial database read requires durable running and returns an existing
winner before provider resolution. Only an absent runtime-prepared command
captures the exact current non-CLI `RuntimeProfileRecord` and resolves the
captured provider/model outside the write transaction. The writer order is:

1. re-require durable running;
2. re-check original slot or replay key winner and validate it;
3. recompute/validate slot identity and cursor ordering;
4. re-read schedule/template/Camp/companions and classify business validity;
5. for runtime-prepared work, re-read the exact profile ID/kind/non-CLI state
   against the read snapshot and consume the provider-preflight result;
6. validate nonblank trace and generate IDs only if a new row will be written;
7. commit the exact started or failed graph.

Expected validation is data, not a swallowed exception. Database/FK/constraint
errors, canonical encoding errors, corruption, stale cursor-without-fire, and
unknown errors throw and roll back the whole transaction. No `try?`, empty
fallback, default success, or arbitrary `String(describing:)` is allowed on the
ownership path.

## 7. Original-fire atomic write contract

For a new valid original, one write transaction performs this exact order:

1. insert one Squad;
2. insert one Mission in planning;
3. insert canonical `mission_created` and `plan_started` events;
4. insert one queued attempt-zero durable planning work;
5. insert one `schedule_fire(state=started, missionId=...)`;
6. insert one `schedule_fired` event;
7. insert/advance the evaluation cursor;
8. update `schedule.lastFiredAt` last;
9. commit.

The planning work uses accepted canonical `PlanningWorkInput` bytes/hash,
version 1, attempt 0, maxAttempts 4, the fire trace, and:

```text
mission-start:schedule:<scheduleId>:<sha256(slotKey UTF-8)>:v1
```

For a new invalid original, the same transaction inserts exactly one failed
fire, one `schedule_missed`, and inserts/advances the cursor; it creates no
Squad/Mission/work/started event and never changes `lastFiredAt`.

The exact schedule events use sorted canonical JSON and include `fireId`,
`scheduleId`, `templateId`, `slotKey`, finite `scheduledAt`, nullable
`replayOfFireId`, `traceId`, and for missed only the stable `errorCode` plus its
safe message. `schedule_fired` is mission-scoped; `schedule_missed` has no
Mission. There is exactly one event of the corresponding kind per new fire.

A duplicate `(scheduleId, slotKey)` returns the existing original fire and its
original Mission/work IDs when started. It preserves first trace/timestamps and
does not revalidate changed configuration into an automatic retry. A corrupted
started graph or mismatched stored schedule/template/slot identity throws a
typed replay/integrity conflict; it is never repaired in place.

Two concurrent callers must return one `.inserted` and one `.replayed` result
for the same complete graph, or an explicit conflict. They may not create two
Missions, two works, two events, or two cursor increments.

## 8. Explicit replay contract

Only a failed original fire with `replayOfFireId == nil` may be replayed. A
started original or any replay row is rejected before writes.

For every first replay attempt, the Store constructs canonical
`ScheduleReplayPayloadV1` with exactly:

```text
contractVersion = 1
originalFireId
scheduleId
templateId
slotKey
scheduledAtInstantBits
runtimeState = selected | unavailable
runtimeProfileId (nullable only when unavailable)
plannerModel (nullable only when unavailable)
preflightFailureCode (only when unavailable)
```

It encodes this DTO with `CanonicalJSONV1`, computes lowercase SHA-256, and
requires byte equality with the caller-supplied `replayPayloadHash`. Trace and
replay key are deliberately excluded: a retry uses a fresh incoming trace but
must preserve the first committed replay trace.

The App creates replay keys only as
`schedule-replay:<lowercase UUID>`. The planning work key for a successful
replay is:

```text
mission-start:schedule-replay:<sha256(replayIdempotencyKey UTF-8)>:v1
```

A new replay revalidates current schedule/template/Camp/cows/runtime/provider
under the same rules and commits its own started or failed fire. The replay
fire retains the original `scheduleId`, `templateId`, `slotKey`, and
`scheduledAt`, sets `replayOfFireId` and the exact key/hash, and emits one
matching schedule event. It never changes the original row, cursor, or
`lastFiredAt`.

Same key + same payload + same original returns the first replay fire and its
Mission/work with zero writes, provider resolution, events, cursor change, or
trace overwrite. Same key + different hash/payload/original throws
`DurableWorkReplayConflictError` with zero writes. Replay winner lookup occurs
before current provider/profile availability checks but never crosses the
durable-halt gate.

## 9. MissionScheduler and post-commit side effects

`MissionScheduler.fire` stops preloading business truth as authority. It only
captures finite time, frozen calendar/zone, slot key, runtime preparation, and
trace, then delegates to the Coordinator. The transaction is the authoritative
re-read.

After a started commit, three effects are independent and ordered:

1. attempt the conditional durable planning wake;
2. attempt the guide broadcast;
3. invoke `onScheduleFired` so App reload/notification is not suppressed by a
   broadcast failure.

Each failure is logged with stable operation, fire ID, and trace ID. Each
effect has its own `do/catch`; failure in one does not skip the others and none
can call a fire-mutation/missed API. Until P1-B introduces `failure_record`,
this safe `os.Logger` evidence is the explicit temporary observability
contract. P1-B owns durable/UI failure projection.

For failed commits, the optional missed broadcast is also an independent
`do/catch`; its failure cannot create another missed event or rewrite the fire.
All current `try?` broadcast swallowing is removed.

`broadcastFailureDoesNotRewriteStartedFire` dynamically injects a real
`appendGuideBroadcast` database failure after a started transaction and proves
the fire/Mission/work/cursor/lastFiredAt snapshot is unchanged. A source-range
sentinel additionally binds the actual `MissionScheduler` order above and
proves no missed/fire rewrite exists in any post-commit catch. This is a hybrid
dynamic + source contract; it does not pretend to instantiate the App target
from the Core-only TestSuite and does not add a test target or dependency edge.

## 10. Migration and deletion semantics

Append `v12-p1-schedule-fire` immediately after
`v12-p1-durable-work`, using the Stage §18.2 SQL exactly. It adds two tables,
three named indexes, two SQLite PK autoindexes, and zero triggers. The latest
checkpoint is therefore 29 tables / 60 indexes / 4 triggers.

The migration deliberately does **not** add F2/v16 first-redaction,
post-redaction-lock, or delete triggers. In A4, “reserves redaction without
allowing ordinary mutation” means:

- exact nullable `redactedAt` and its CHECK are present;
- every A4 insert writes `redactedAt = NULL`;
- `ScheduleFireRecord` is fetch-only and no ordinary product update/delete/
  redact API exists;
- invalid state/error/redaction combinations fail the exact CHECK;
- raw-SQL redaction and immutable-after-redaction enforcement remain explicitly
  owned by F2/v16.

Because §18.2 FKs use `ON DELETE RESTRICT`, deleting a Schedule or Mission
Template with retained fire history must throw and roll back; existing rows are
not cascaded or silently discarded. The current APIs propagate the database
failure. Deletion without fire history retains existing behavior. A4 does not
add a history purge or workaround.

`DatabaseTests.durableWorkMigrationMatrixThroughV12` and its exact-DDL test
must migrate only through `v12-p1-durable-work`, preserving the accepted A1a
boundary and its assertion that A1a alone has no schedule fire. The new A4 test
owns latest-schema assertions.

The migration runner and script are upgraded, not weakened:

- latest real migration must be `v12-p1-schedule-fire`;
- fixtures remain exactly fresh, v7, v8, v9, v10, v11, and v12-durable;
- the v12-durable lane preserves a logical snapshot of all predecessor data,
  applies A4 once, captures the new full snapshot, and requires the second
  migrate to be byte-identical to that final snapshot;
- the literal lane starts at a real v12-durable baseline and applies only the
  exact Stage §18.2 SQL;
- both SQLite 3.51 and 3.52 lanes assert 29/60/4, the two new tables, exact
  columns/FKs/index predicates/CHECK truth table, migration replay/rollback,
  FK/integrity, and all inherited durable diagnostics/append-only checks;
- Package/lock files and matrix-owned script bytes are restored/unchanged
  outside their reviewed A4 edits.

## 11. Failure-first and exact canonical tests

Before product implementation, add the ten canonical tests and preserve a
failure-first run whose failures are only missing A4 capability/behavior:

1. `scheduleFireMigrationMatrixAndExactDDL`
2. `scheduleValidationFailureAdvancesEvaluationCursorButNotLastFiredAt`
3. `failedSlotDoesNotSpinOrAutoRetryAfterConfigurationFix`
4. `explicitReplayUsesNewIdempotencyKeyAndDoesNotMoveCursor`
5. `replaySamePayloadReturnsSameFireButConflictFails`
6. `scheduleStartedTransactionSurvivesRestartBeforePlannerKick`
7. `sameSlotReplayReturnsSameMission`
8. `broadcastFailureDoesNotRewriteStartedFire`
9. `scheduleFireDSTSlotKeysAreStable`
10. `scheduleFireSchemaReservesRedactionWithoutAllowingOrdinaryMutation`

The tests freeze these dynamic matrices:

- migration: all seven predecessors, exact 15 fire columns / 5 cursor columns,
  FK actions, three named indexes and predicates, all CHECK legal/illegal rows,
  no `intended`, +0 trigger, rollback, replay, FK and integrity;
- validation: invalid template, archived Camp, missing/wrong-Camp cow,
  runtime/profile/provider failure, finite millisecond overflow, disabled
  race, durable halt, and injected work/event failure; exact row/event/cursor/
  `lastFiredAt` mutation snapshots for each;
- cursor: same failed slot after configuration repair produces zero second
  evaluation, fire, Mission, work, event, provider resolution, or cursor
  increment; only explicit replay can start it;
- replay: successful/failed replay, source restrictions, fresh key, canonical
  hash verification, same-payload zero-write return, changed-payload conflict,
  fresh-trace preservation, and concurrent same-key winner;
- restart: commit started graph without kick, close/reopen database, then a
  fresh Orchestrator/Supervisor recovers exactly one queued work dispatch;
- same original: sequential and two real Foundation-thread callers return one
  complete graph with one inserted/one replayed disposition and first trace;
  no cooperative-executor blocking primitive is permitted;
- broadcast: real post-commit DB failure plus actual App source ordering;
- DST: exact v1 literals for LA spring-forward and both fall-back instants,
  repeated computation, daily/weekly, different zone and configured slot;
- redaction/deletion: reserved column/CHECK/fetch-only owner, no A4 trigger,
  and FK-restricted schedule/template deletion with history.

The due-scan portion is tested through a package-testable pure Core calculation
that accepts a cursor; `MissionScheduler` must delegate to it. No App test
target, sleep, polling, network, normal user data, or UI automation is used.

Existing test names are retained and their bodies migrate from claim-first to
A4 truth. In particular, the five A1b schedule tests in
`DurablePlanningTests.swift`, `scheduleCRUDAndClaimDedupe`, the extreme-date
test, and the schedule source sentinel may not retain `claimScheduleFire`,
`notClaimed`, “no schedule_fire”, or failure-updates-`lastFiredAt` assertions.
Accepted schedule CRUD/math/date-encoding coverage remains green.

## 12. Source gates and verification sequence

Source gates must parse owner/function ranges, not rely on repository-wide
substring counts. They prove:

- `claimScheduleFire` definition and production/test calls are zero;
- one original transaction owner and one explicit replay owner exist;
- no nested public planning enqueue exists inside a write transaction;
- MissionScheduler captures Calendar/TimeZone before await, delegates once,
  and performs only post-commit wake/broadcast/notification;
- no post-commit catch can write failed/missed fire state;
- due scan reads cursor rather than `lastFiredAt`;
- fire rows are fetch-only, all A4 insert paths set `redactedAt` nil, and no A4
  update/delete/redact surface or premature trigger exists;
- P1-B–P6 APIs/schema and Package graph remain absent/unchanged.

Verification order after implementation is:

1. each canonical test selected independently, exactly one start/pass;
2. affected legacy Schedule/Database/DurablePlanning tests selected green;
3. `swift build --product P1MigrationMatrixRunner` and `bash -n` on the script;
4. the aggregate/literal dual-SQLite 3.51/3.52 matrix;
5. debug Core, TestSuite, and AgentLoopApp builds;
6. release Core, TestSuite, and AgentLoopApp builds;
7. source gates, `git diff --check`, no source symlinks, exact allowlist diff;
8. one fresh, unfiltered `swift run RunTests` written directly to
   task `verify.log`.

With the current 657-test accepted baseline, adding ten tests without deleting
or merging old tests yields exactly 667 tests in 7 suites. Any other discovered
count, duplicate/missing canonical name, warning introduced by A4, failure,
crash, hang, filtered substitute, retry, or nonterminal log blocks completion.

`impl-report.md` records changed files, root cause, red/green evidence, exact
test/build/matrix outcomes, any deviation, and confirms no unauthorized action.

## 13. Completion gate and next stage

A4 is complete only when all of the following are true:

- the ten canonical tests and migrated legacy schedule tests pass;
- the authoritative unfiltered suite is exactly 667/667 in 7 suites;
- App/debug/release builds and the dual-SQLite matrix pass;
- migration replay, cursor, original/replay concurrency, restart-before-kick,
  DST, broadcast failure, redaction reservation, and FK deletion evidence are
  present;
- scope/source gates pass with no unexplained change or new warning;
- a fresh responsibility-isolated implementation review returns zero P0/P1;
- a fresh independent acceptance owner writes `ACCEPTED` and closes R-04.

Only that acceptance opens P1-B. It does not pre-accept P1-B or any later
slice.

## 14. Red lines

- Never claim/update `lastFiredAt` before the atomic graph commits.
- Never auto-retry a failed original slot after configuration repair.
- Never let replay move cursor or `lastFiredAt`.
- Never turn a committed started fire into failed because wake, broadcast, or
  notification failed.
- Never swallow ownership, DB, provider, or broadcast failure with `try?`,
  `??`, empty data, default success, or raw-string fallback.
- Never add `intended`, a second planning ledger, nested writer, sleep/retry
  harness, new dependency/target, or release-visible test API.
- Never implement F2 redaction/delete triggers early or weaken exact §18.2 DDL.
- Never rewrite, delete, or wash green A1a–A3 or R15–R28 history.
- Never commit, push, merge, release, reset data, access normal user data, or
  perform external/real-user actions in this slice.

## 15. Open Questions

无。
