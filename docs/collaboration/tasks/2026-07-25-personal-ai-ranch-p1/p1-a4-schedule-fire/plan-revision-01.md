# P1-A4 Bounded Leaf Revision 01 — Deterministic Schedule Fire

> Status: **REVISION 01 — implementation blocked pending responsibility-isolated Review01A**
>
> Date: 2026-08-10
>
> Branch / entry HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Authority: Candidate 01, immutable Review01 `CHANGES REQUIRED — 0 P0 / 5 P1 / 1 P2`, accepted P1 Stage §6.6/§18.2, and canonical P1 Plan §3.5/§10/§11

## 1. Purpose, precedence, and gate

This revision closes Review01 P1-01...P1-05 and clarifies P2-01. It also
closes the same-boundary replay/hash/template/duplicate ambiguities found by a
separate read-only feasibility audit. It does not expand the 13-file
product/test/script allowlist, change exact Stage §18.2 DDL, introduce an
eleventh canonical test, or open P1-B.

This file is the current decision-complete overlay for Candidate 01. Every
Candidate 01 clause not contradicted here remains binding. The clauses below
replace Candidate 01's conflicting runtime payload, template replay, finite
millisecond-overflow, post-commit effect, catchup durability, source-boundary,
and verification language.

No product, test, App, Package, runner, or script implementation may start
until a fresh responsibility-isolated reviewer writes
`reviews/01a-p1-a4-plan-review.md` with `APPROVED` and zero P0/P1. Internal
hashes are evidence only; no user hash echo is required. Unknowns, unexpected
files, failures, or non-empty Open Questions fail closed.

## 2. Exact command, preflight, and transaction ownership

### 2.1 Frozen command types

`ScheduleMath.swift` owns a package-visible, `Sendable`/`Equatable`
`ScheduleSlotContextV1` with exactly:

```text
contractVersion = 1
calendarId = "gregorian"
timeZoneId
frequency
hour
minute
weekday
scheduledAt                 // normalized finite Date
scheduledAtInstantBits      // 16 lowercase hexadecimal digits
slotKey                     // exact Candidate 01 v1 string
```

The original command carries `scheduleId`, the complete context, one
nonblank trace ID, and exactly one `ScheduleFirePreparation`:

```text
selected(runtimeProfileId, plannerModel)
forcedFailure(schedule_missed_while_offline)
unavailable(schedule_runtime_unavailable)
```

`unavailable` is constructible only when App runtime selection reports the
exact existing `RecordNotFoundError(table: "runtime_profile(default)",
id: "default")`, or when a selected profile/model is blank. Any other error
from the runtime-selection closure is unknown and is rethrown before the
ledger call; it is never converted to a missed fire. `forcedFailure` is used
only by startup offline evaluation. No raw `Error`, provider detail, database
message, credential, or arbitrary string enters a command.

An explicit replay command additionally carries `originalFireId`, a fresh
global `schedule-replay:<lowercase UUID>` key, a caller-computed canonical
payload hash, and the exact canonical payload fields frozen in §4. Trace and
replay key are not payload identity.

### 2.2 Two-phase Core owner

Both original and explicit replay use this exact ordering:

```text
Coordinator capture/validate command
  -> Orchestrator commitScheduledMission
  -> DurableWorkSupervisor start/replayScheduledMission
  -> AppDatabase initial read snapshot
       1. require durable dispatch running
       2. look up and validate an already committed winner
       3. only for absence, capture current schedule/template/profile truth
  -> only selected+absent resolves provider outside the write transaction
  -> AppDatabase writer
       1. require durable dispatch running again
       2. look up and validate a concurrent winner before absent fences
       3. only for continued absence, validate slot/cursor/business/profile
       4. commit one started or failed graph
```

The one `ScheduleDurablePlanningLedgerOwner` is declared as a `fileprivate`
nested enum inside the existing `PlanningDurableWorkLedgerOwner` in
`DurableWorkStore.swift`. Swift nested-private access lets it reuse the exact
existing private dispatch/canonical-event/graph helpers without widening them
to package/public, duplicating a generic ledger, or nesting the public
`enqueueMissionPlanning` API inside `pool.write`. Source gates require this
nesting and reject a sibling owner plus access-control widening.

Only an existing `PlanningProviderResolutionError` becomes the terminal
`schedule_provider_unavailable` outcome. Any other resolver error is logged by
safe type/operation/trace only, then rethrown; the writer is not entered.

A winner visible in the initial read performs zero provider resolution. With
no schema reservation and no process-global owner, two genuinely concurrent
absent callers may each preflight once; the SQLite writer/unique indexes still
guarantee exactly one insert and one replayed result. The plan does not claim
cross-process or process-local provider single-flight.

### 2.3 Profile snapshot and writer fence

For a selected request, the initial snapshot captures one exact
`RuntimeProfileRecord`. Missing profile, CLI kind, or blank selected profile or
model becomes `schedule_runtime_unavailable` data without provider resolution.
The writer compares exactly these persisted fields with the captured row:

```text
id
kind
baseURL
credentialAccount
```

It also requires `kind.isCLI == false`. A change to any listed field, deletion,
or CLI drift becomes `schedule_runtime_unavailable`. `name`, `isDefault`, and
`createdAt` are deliberately not provider identity and do not conflict. Model
catalog/credential validation belongs to the typed provider preflight; the
writer does not invent an unavailable cache snapshot.

If a concurrent winner exists, winner validation occurs before this profile
fence and returns the first graph even if the profile subsequently changed.
Durable halt remains before all winner returns, so replay never crosses halt.

## 3. Total calendar, slot, and Date contract

### 3.1 Supported calendar and time zone

A4 supports exactly Foundation `.gregorian`; the canonical token is the
literal `gregorian`. Code compares `calendar.identifier == .gregorian` and
must not derive the token with `String(describing:)`, locale-sensitive
lowercasing, or a fallback. Every other identifier throws
`UnsupportedScheduleCalendarError` before UUID generation, runtime selection,
database reads, or writes.

The exact non-empty `TimeZone.identifier` is captured. It must reconstruct via
`TimeZone(identifier:)` and the reconstructed identifier must be byte-equal;
otherwise `InvalidScheduleTimeZoneError` is thrown at the same pre-DB gate.
Slot reconstruction uses a new `Calendar(identifier: .gregorian)` with locale
`en_US_POSIX` and the reconstructed zone. Other caller Calendar properties do
not participate.

`MissionScheduler.register` captures one complete `ScheduleSlotContextV1`
from the Schedule snapshot, the registration-time Calendar/TimeZone, and the
exact `nextFireDate`. The `NSBackgroundActivityScheduler` closure captures and
passes that value to `fire`; `fire` must not read `.current` or rebuild a slot
context. A time-zone or configuration change after registration therefore
either commits the exact planned context or hits the writer's typed stale-
configuration zero-write fence; the subsequent refresh schedules a new
context. `runNow` and startup due evaluation each capture their complete
context synchronously before their first `await`. Explicit replay uses the
original fire's stored instant/key and needs no new Calendar capture.

### 3.2 Finite instant and components

`scheduledAt.timeIntervalSince1970` must be finite. `-0.0` is normalized to
`+0.0` before both Date reconstruction and bit extraction. The normalized
seconds must also satisfy the exact human-schedule range
`-62_135_596_800 <= seconds && seconds < 253_402_300_800` (UTC years
0001...9999). A finite value outside that range throws
`ScheduleSlotComponentsUnavailableError` before Calendar, UUID, runtime, or
database work. The normalized in-range seconds must reconstruct a Date whose
`timeIntervalSince1970.bitPattern` equals the normalized bits. The
Gregorian/POSIX calendar must return every
required era/year/month/day/hour/minute/second/nanosecond component, and the
zone must return its offset. The real builder passes those `DateComponents`
through one package semantic value initializer,
`ScheduleSlotComponentsV1(validating:)`, whose stored fields are exactly the
eight required integers and which throws
`ScheduleSlotComponentsUnavailableError` for any nil component. The
production slot builder uses this initializer; the canonical test directly
passes an incomplete `DateComponents` to the same non-DEBUG production
validator. This is a package semantic type, not a substitute-result test seam.
There is no zero/default component substitution, and failure occurs before
UUID/runtime/DB work.

A4 removes Candidate 01's obsolete checked-UTC-milliseconds planning identity
and its `schedule_fire_time_out_of_range` failed-row case. Planning identity is
the SHA-256 of the exact slot key; no `Int64` millisecond conversion is needed.
The exact fixture outcomes are:

| Input seconds | Exact result |
|---|---|
| `-0.0` | accepted after normalization to `+0.0`; stored/key bits `0000000000000000` |
| `1_700_000_000.0000002` (`41d954fc40000001`) | accepted |
| `1_700_000_000.0000005` (`41d954fc40000002`) | accepted as a distinct instant/key in the same millisecond |
| `10_000_000_000_000_000` | `ScheduleSlotComponentsUnavailableError`, zero UUID/runtime/DB work |
| `Double.greatestFiniteMagnitude` and its negative | same component-unavailable error, zero UUID/runtime/DB work |
| NaN and either infinity | `InvalidSchedulePlanningFireTimeError`, zero UUID/runtime/DB work |
| incomplete `DateComponents` passed to the real validator | `ScheduleSlotComponentsUnavailableError` |

The two epoch range boundaries are also tested for inclusive-lower and
exclusive-upper behavior. This table, not host ICU's behavior for extreme
finite Dates, is authoritative.

### 3.3 Exact numeric database storage

Exact Stage §18.2 DDL remains byte-identical; no additional `typeof` CHECK is
added. Every ledger raw-SQL bind for the following columns passes
`date.timeIntervalSince1970` as `Double`, never `Date`:

```text
schedule_fire.scheduledAt
schedule_fire.createdAt
schedule_fire.redactedAt when non-null in future code
schedule_evaluation_cursor.lastEvaluatedScheduledAt
schedule_evaluation_cursor.updatedAt
schedule.lastFiredAt on a successful original
event.createdAt for the A4 `schedule_fired` / `schedule_missed` row
```

The new fetch-only fire and cursor records use GRDB 7.11.1's exact custom
numeric-only `DatabaseDateDecodingStrategy` for every new Date column:

```swift
.custom { databaseValue in
    switch databaseValue.storage {
    case .double(let seconds)
        where seconds.isFinite
            && seconds >= -62_135_596_800
            && seconds < 253_402_300_800:
        let date = Date(timeIntervalSince1970: seconds)
        guard date.timeIntervalSince1970.bitPattern == seconds.bitPattern
        else { return nil }
        return date
    case .int64(let integerSeconds):
        let seconds = Double(integerSeconds)
        guard Int64(exactly: seconds) == integerSeconds,
              seconds >= -62_135_596_800,
              seconds < 253_402_300_800
        else { return nil }
        let date = Date(timeIntervalSince1970: seconds)
        guard date.timeIntervalSince1970.bitPattern == seconds.bitPattern
        else { return nil }
        return date
    default:
        return nil
    }
}
```

Thus text, blob, null-for-nonnull, and non-finite corruption fail record
decoding. The records do not conform to `PersistableRecord`; the fileprivate
ledger remains the only writer. If an internal Codable insert helper is used,
its encoding strategy is exactly `.timeIntervalSince1970` for the same
columns.

`lastFiredAt` is updated by an exact raw numeric bind to the normalized command
instant, not commit time. The two A4 schedule events are inserted by the
fileprivate ledger with a numeric `event.createdAt` bind; the existing generic
event API and historical rows are unchanged. The transaction uses one commit
`Date()` for its created/updated Mission/Squad/work/fire/event/cursor
timestamps. Tests require
SQLite storage class `real` or `integer`, exact scheduled/cursor/last-fired
Double bit patterns after fetch and close/reopen, and same-millisecond
different-bit cursor ordering. Legacy Schedule Date decoding stays compatible
with predecessor TEXT rows.

## 4. Explicit replay identity and current-template truth

### 4.1 Canonical payload

Before an explicit user replay, the MainActor Coordinator reads the failed
original and current Schedule once, captures the current
`effectiveTemplateId = schedule.templateId`, captures runtime selection, and
constructs `ScheduleReplayPayloadV1` with exactly these keys:

```text
contractVersion = 1
originalFireId
scheduleId
originalTemplateId
effectiveTemplateId
slotKey
scheduledAtInstantBits
runtimeState = "selected" | "unavailable"
runtimeProfileId
plannerModel
preflightFailureCode
```

The DTO custom encoder always emits all nullable keys. Exact nullability is:

| runtimeState | runtimeProfileId | plannerModel | preflightFailureCode |
|---|---|---|---|
| `selected` | non-null/nonblank | non-null/nonblank | null |
| `unavailable` | null | null | `schedule_runtime_unavailable` |

Profile absence/CLI/drift after a selected capture leaves the payload row
`selected`; only the fire result becomes `schedule_runtime_unavailable`.
Typed provider failure also leaves the payload `selected`; provider outcome is
not replay identity and the fire result becomes
`schedule_provider_unavailable`. Same failed replay key therefore never
retries a recovered provider; a fresh explicit user action must use a fresh
key.

`CanonicalJSONV1` produces the bytes and lowercase SHA-256. The Coordinator
places the hash on the command. The Store independently reloads original and
current Schedule, reconstructs the complete DTO from those rows plus the typed
runtime request, re-encodes it, and requires byte/hash equality before a new
write. A changed effective template between capture and writer throws
`StaleScheduleReplayPreparationError` with zero writes; the caller may capture
a fresh user command.

### 4.2 Effective template and provenance

Replay revalidates and executes the writer-current effective template. A
schedule rebind is a legitimate repair: the new replay fire, Mission identity,
and schedule event all use `effectiveTemplateId`; `replayOfFireId` and the
payload's `originalTemplateId` preserve historical provenance. The original
fire and its template ID never change. This replaces Candidate 01's statement
that every replay row retains the original `templateId`.

Only a failed original (`replayOfFireId == NULL`) is eligible. A started
original or a replay-of-replay throws `InvalidScheduleReplaySourceError` with
zero writes. A missing original throws
`RecordNotFoundError(table: "schedule_fire", id: originalFireId)`.

### 4.3 Replay-key winner

The global replay key lookup occurs after the durable gate and before current
schedule/template/profile/provider checks. Same key, same caller hash, same
original, and an intact stored graph returns the first result with zero writes
or provider resolution and preserves first trace/timestamps. Any difference
throws `DurableWorkReplayConflictError` with zero writes.

## 5. Original winner, cursor, and exact failure mapping

### 5.1 Original duplicate and stale snapshot

The original winner lookup is after the durable gate but before current
business/profile/provider revalidation. It validates only:

- command self-consistency: schedule ID, exact slot key, normalized scheduled
  instant bits, and frozen context reproduce one another;
- persisted row identity: `scheduleId`, `slotKey`, and scheduled bits equal the
  command; and
- the persisted terminal graph is intact: a started fire has its one Mission,
  one matching planning work and one canonical fired event; a failed fire has
  no Mission/work and one canonical missed event.

Incoming trace, runtime request, provider state, and current schedule/template/
camp/cow edits are not original replay identity. Stored `templateId` is not
compared with current `schedule.templateId`. An intact winner returns the first
result. Graph corruption or command/row identity mismatch throws
`ScheduleFireReplayIntegrityError` with zero writes.

Only the absent path compares the frozen frequency/hour/minute/weekday to the
writer-current Schedule and recomputes the key. A mismatch throws
`StaleScheduleConfigurationError` with zero writes. Two concurrent identical
legal commands must return exactly one `.inserted` and one `.replayed`; the
leaf's prior optional “or conflict” does not apply to that case.

Cursor comparison is exact `(scheduledAt Double, raw UTF-8 slotKey)`. An older
tuple throws `StaleScheduleEvaluationError`; equal without an already validated
original winner throws `ScheduleEvaluationIntegrityError`; both make zero
writes. Checked cursor version increment overflow throws
`ScheduleEvaluationVersionOverflowError` and rolls back.

### 5.2 Fixed failures and messages

Only the following terminal failure rows exist in A4. Each always persists the
exact code and exact Chinese message shown; no underlying description is
appended.

| Typed condition | `errorCode` | exact `errorMessage` |
|---|---|---|
| current Schedule disabled | `schedule_disabled` | `定时行动已停用。` |
| `ScheduleValidationError` | `schedule_configuration_invalid` | `定时行动配置无效。` |
| current Camp archived | `schedule_camp_archived` | `定时行动所属营地已归档。` |
| `MissionTemplateValidationError` or companion JSON `DecodingError` | `schedule_template_invalid` | `定时行动模板配置无效。` |
| referenced Companion absent | `schedule_companion_missing` | `定时行动模板引用的伙伴不存在。` |
| Companion `campId` nil or different | `schedule_companion_wrong_camp` | `定时行动模板中的伙伴不属于该营地。` |
| typed unavailable preparation, selected profile absent/CLI, blank selection, or listed profile drift | `schedule_runtime_unavailable` | `定时行动的运行配置不可用。` |
| `PlanningProviderResolutionError` | `schedule_provider_unavailable` | `定时行动的规划服务暂不可用。` |
| startup offline forced failure after all structural/business checks | `schedule_missed_while_offline` | `定时行动在应用离线期间错过了触发时间。` |

The exact precedence for a continued-absence writer is:

1. durable-running gate;
2. winner validation;
3. command/slot/cursor consistency;
4. required Schedule, effective Template, and Camp scope;
5. disabled Schedule;
6. Schedule validation;
7. archived Camp;
8. Template validation/JSON;
9. companions by a global two-pass check: first report the first missing ID in
   template order; only if none are missing, report the first nil/wrong-Camp
   companion in template order;
10. offline forced failure;
11. runtime unavailable/profile fence;
12. typed provider unavailable;
13. started graph.

Missing Schedule, effective Template, or Camp throws the corresponding exact
`RecordNotFoundError` and writes nothing because a valid §18.2 FK scope cannot
be constructed. An existing row whose FK/identity disagrees throws
`ScheduleFireScopeIntegrityError`. Database/GRDB/FK/constraint errors,
canonical encoding errors, numeric corruption, unknown runtime-selection
errors, unknown resolver errors, and every unenumerated error throw and roll
back. These conditions never become a generic failed fire.

### 5.3 Exact canonical schedule events

`schedule_fired` uses `ScheduleFiredPayloadV1`; `schedule_missed` uses
`ScheduleMissedPayloadV1`. Both custom encoders always emit nullable
`replayOfFireId` as JSON null and use `CanonicalJSONV1` sorted canonical bytes.
They have exactly:

```text
contractVersion: Int = 1
fireId: String
scheduleId: String
templateId: String                 // original effective ID or replay effective ID
slotKey: String
scheduledAt: Double                // normalized Unix seconds JSON number
scheduledAtInstantBits: String     // exact 16 lowercase hex
replayOfFireId: String | null
traceId: String
```

The missed DTO adds exactly non-null `errorCode` and `errorMessage`; the fired
DTO contains neither key. `schedule_fired` has the committed Mission ID;
`schedule_missed` has `missionId == NULL`. Event `createdAt` equals the fire's
commit timestamp. Decoder/snapshot tests require the numeric seconds to be
finite and bit-equal to both the hex field and fire row.

### 5.4 Exact A4 fail-fast error surface

The following new errors are package-visible `Error & Sendable & Equatable`
values with only the listed fields; they contain no raw underlying message:

| Error | Exact stored fields |
|---|---|
| `InvalidSchedulePlanningFireTimeError` | none |
| `UnsupportedScheduleCalendarError` | none |
| `InvalidScheduleTimeZoneError` | `timeZoneId` |
| `ScheduleSlotComponentsUnavailableError` | none |
| `StaleScheduleConfigurationError` | `scheduleId` |
| `StaleScheduleReplayPreparationError` | `originalFireId`, `expectedTemplateId`, `actualTemplateId` |
| `InvalidScheduleReplaySourceError` | `originalFireId` |
| `ScheduleFireReplayIntegrityError` | `fireId` |
| `ScheduleFireScopeIntegrityError` | `scheduleId` |
| `StaleScheduleEvaluationError` | `scheduleId`, `slotKey` |
| `ScheduleEvaluationIntegrityError` | `scheduleId`, `slotKey` |
| `ScheduleEvaluationVersionOverflowError` | `scheduleId`, `version` |

Replay hash/key conflicts continue using the accepted fieldless
`DurableWorkReplayConflictError`; durable halt continues using
`PlanningDurableDispatchNotRunningError(actualMode:)`. Tests match concrete
types and fields, never localized text, for zero-write errors.

## 6. Disposition-bound post-commit effects

The complete matrix is:

| Fire state / disposition | conditional wake | `planningStarted` Kernel event | guide broadcast | `onScheduleFired` |
|---|---:|---:|---:|---:|
| started + inserted | yes, if work is queued/retry-scheduled and both dispatch gates run | once only inside that eligible wake branch | once best-effort | once |
| started + replayed | yes, under the same current-state gates | never | never | never |
| failed + inserted | never | never | one missed broadcast best-effort | never |
| failed + replayed | never | never | never | never |

`commitScheduledMission` is database-only and emits no Kernel event. The sole
Kernel event owner is `Orchestrator.wakeScheduledPlanning`: after re-reading
the exact work and both dispatch gates, queued/retry-scheduled executes
`ensureTickStarted()`, then emits `.planningStarted` only when disposition is
`.inserted`, then calls `planningSupervisor.kick()`. Replayed work never emits
the Kernel event. Running/terminal work, or a process/durable gate that no
longer permits dispatch, performs none of these three operations. Thus a crash
between commit and wake can lose the in-memory inserted-only event, while the
durable Mission/work remains authoritative and recoverable; A4 does not fake a
later replay event.

The wake path may recover a crash-after-commit and is idempotent at durable
claim boundaries. Broadcast and notification are inserted-only, best-effort,
at-most-once attempts; they remain eligible after a started commit even if the
independent wake is skipped or throws. A4 does not claim exactly-once delivery
without an outbox. Each eligible effect has its own `do/catch`; one failure
never skips a later eligible effect. Catches log only stable operation, fire
ID, trace ID, and safe error type, and cannot call any
fire/missed/cursor/schedule mutation.

Core/TestSuite dynamic coverage proves inserted/replayed fire, ledger, provider,
conditional-wake, Kernel-event, tick, kick, and a real post-commit
`appendGuideBroadcast` database failure leaves the committed graph unchanged.
Because TestSuite cannot import `AgentLoopApp`, guide/callback disposition and
callback counts are not claimed as dynamic evidence. The actual
`MissionScheduler` source-range sentinel proves broadcast and
`onScheduleFired` exist only in inserted branches, are absent in replayed
branches, remain ordered after the independent wake attempt, and no catch can
rewrite fire truth. The two previews prove launch isolation only and do not
pretend to exercise callback behavior. No App dependency/test seam and no
eleventh `@Test` is added.

## 7. Startup catchup limit

A4 makes slot consumption and replayable failed-fire history durable, not the
prompt disposition. Startup computes only the latest unconsumed slot from the
cursor and commits one inserted `schedule_missed_while_offline` original. Only
that current-process inserted result creates a `ScheduleCatchup` containing
its `fireId`. Decline removes it for the current process; confirm uses that ID
to capture a new explicit replay command.

After a crash/restart, the advanced cursor prevents spin and duplicate fire,
but an unconfirmed or declined prompt is not reconstructed automatically.
Users can later replay retained failed history once a future UI surface exists.
No table/column, false durable-prompt claim, or P1-B/F2 work is added.

## 8. Fail-closed A3-to-A4 source partition

### 8.1 Immutable historical evidence

The A3 `revision02-entry-source-manifest.sha256` remains byte-identical at 206
entries and identity
`3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e`.
It is never regenerated or overwritten.

Before the first red test edit, create task artifact
`a4-entry-source-manifest.sha256` from current accepted A3 bytes. It contains
exactly 206 sorted unique rows in exact form
`<64 lowercase hex><two ASCII spaces><repository-relative path><LF>` for every
regular file under `Sources/` and `scripts/`, plus `Package.swift` and
`Package.resolved`, except the exact 13 A4 allowlist paths. Enumeration and
transport use `find -P ... -print0` plus NUL-delimited explicit Package paths.
Each NUL-delimited repository-relative path is validated before conversion to
the line manifest: it must contain neither LF nor CR, must not be absolute or
start with `./`, and must match exactly one enumerated regular non-symlink
file. Any LF/CR pathname fails closed because the final format deliberately
does not encode it. Only after that rejection may validated paths be converted
to LF records and sorted with `LC_ALL=C`. Verification repeats the same NUL
pipeline; newline-delimited `find` output, word splitting, globs, and command
substitution are forbidden for pathname discovery. A separate NUL symlink
enumeration must be empty. It includes existing hidden regular files, rejects
symlinks, and has expected file identity
`6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71`.
Creation or verification disagreement blocks red edits.

### 8.2 Executable sentinel transformation

The existing A3 test remains named
`a3Revision02EntryBoundaryRemainsByteExact`; it still validates the immutable
A3 manifest's original identity/count/order/uniqueness. For live byte checks,
it filters exactly these seven A4 paths that the old outside-nine manifest had
included:

```text
Sources/AgentLoopCore/Database/ScheduleStore.swift
Sources/AgentLoopCore/Kernel/ScheduleMath.swift
Sources/AgentLoopApp/MissionScheduler.swift
Sources/AgentLoopTestSuite/ScheduleTests.swift
Sources/AgentLoopTestSuite/DatabaseTests.swift
Sources/P1MigrationMatrixRunner/main.swift
scripts/verify-p1-migrations-sqlite-matrix.sh
```

The filtered historical set is exactly 199 paths and is checked against a
fresh equally filtered enumeration. Its exact frozen dictionary removes only
the five A4 entries it formerly pinned (`AppDatabase.swift`, `DurableWork.swift`,
`DurableWorkSupervisor.swift`, `DurableWorkStore.swift`, and the matrix script)
and continues pinning the other seven exact entry bytes. No path, hash, regular
file, or symlink assertion is broadly disabled.

One of the ten A4 canonical tests reads the new A4 manifest, requires its exact
identity/count/sort/uniqueness, enumerates the same boundary, and verifies all
206 regular non-symlink bytes. It also proves that the complement is exactly
the 13 reviewed A4 paths. `source-gates.log` repeats the partition after all
verification. Any other Source/Package/RunTests/script delta blocks A4.

### 8.3 Stage SQL anchors

The matrix script updates its stale whole-Stage anchor to the current canonical
Stage file and simultaneously enforces all three independent values:

```text
p1-stage-spec.md whole file:
  bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6
§18.1: 187 lines / fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2
§18.2: 47 lines / c693edcdfe15d586b018bc51dceeebf8091544edede5dc9eb775a105153717ea
```

It extracts §18.1 and §18.2 separately, applies §18.2 only after a real
v12-durable predecessor in the literal lane, and preserves every inherited
§18.1 diagnostic/append-only assertion plus both real and literal SQLite
3.51/3.52 lanes. No Stage or canonical Plan edit is authorized by A4.

## 9. Failure-first, verification, and preview gates

Task artifacts additionally authorize
`a4-entry-source-manifest.sha256` and `preview.log`. The exact order is:

1. after Review01A approval, create and verify the A4 entry manifest before
   any red source edit;
2. add/migrate exactly the ten canonical tests plus the existing A3 sentinel;
3. save the first authoritative failing run to `red-tests.log`; failures may
   name only missing reviewed A4 behavior;
4. implement only the 13-file reviewed scope;
5. run each canonical test independently, affected legacy tests, runner build,
   `bash -n`, dual SQLite matrix, debug/release Core/TestSuite/App builds,
   source gates, `git diff --check`, and one fresh direct `swift run RunTests`
   producing exactly 667/667 tests in 7 suites;
6. only after every prior gate is green, run the repository's unmodified exact
   `scripts/run-app.sh --preview` twice.

Each preview run uses a different fresh absolute `mktemp -d` state root passed
as `AGENTLOOP_STATE_DIR`, requires a cold start, and records only safe evidence:

- the script succeeds and LaunchServices starts exactly one process;
- the executable path is byte-equal to
  `<pwd -P>/.build/AgentLoop.app/Contents/MacOS/AgentLoop` from this checkout;
- the isolated root receives the preview database/state;
- a programmatic open-file check returns zero matches for the normal AgentLoop
  Application Support root without printing unrelated open-file paths;
- the process remains alive through the bounded observation window, then is
  gracefully terminated and confirmed gone before the next run; and
- source gates prove preview mode uses process-local defaults, disables
  recovery/scheduling/credential access, and passes the explicit state root.

The preview log must not dump the process environment, secrets, normal data,
or unrelated file names. An installed-App/display-name fallback, normal-root
match, launch failure, crash, hang, or second process blocks acceptance. This
is execution evidence only; it does not authorize editing `run-app.sh`, normal
user-data access, release, or real-user action.

The final implementation review and independent acceptance read all evidence,
including both previews. Only an `APPROVED` zero-P0/P1 review plus `ACCEPTED`
closes R-04 and opens P1-B.

## 10. Completion invariants and red lines

- Exact Stage §18.2 schema remains unchanged: 29 tables / 60 indexes / 4
  triggers at the A4 checkpoint.
- Ten and only ten new canonical `@Test` functions produce exactly 667 tests / 7
  suites; added source assertions are folded into those tests or migrated
  existing sentinels.
- Original/replay concurrency has one graph and deterministic dispositions;
  duplicate preflight may occur only for two truly absent concurrent callers.
- No replay changes cursor/`lastFiredAt`; no failed original auto-retries; no
  post-commit effect rewrites fire truth.
- No raw error description, credential, profile secret, provider response, or
  normal user data is logged or persisted.
- No `try?`, fallback/default success, second ledger, nested writer, new
  public API, target/dependency edge, F2 trigger, P1-B schema, commit, push,
  merge, release, external communication, or real-user operation is allowed.

## 11. Open Questions

无。
