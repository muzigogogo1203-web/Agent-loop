# P1-A4 Responsibility-Isolated Plan Review01

> Date: 2026-08-10
>
> Reviewer: fresh responsibility-isolated A4 plan reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 5 P1 / 1 P2**

## 1. Independence, authority, and review boundary

This reviewer did not author the A4 leaf plan and has not participated in A4
implementation. The review was read-only except for this exact file and the
parent `reviews/` directory needed to hold it. It did not run tests, builds,
migrations, matrix scripts, the App, preview, bundle, or UI, and it did not
modify the leaf, canonical Stage/Plan, control indexes, product, test, Package,
script, evidence, or prior acceptance bytes.

The review read `AGENTS.md`, the collaboration protocol, the accepted master
spec, P1 Stage §6.6 / §18.2 / P1-A completion gate, canonical P1 Plan
§3.5 / §10 / §11, the accepted A3 acceptance, the complete candidate A4 leaf,
and the current implementation and test paths named by its 13-file allowlist.
It also inspected the current A3 executable source-boundary sentinel and the
current migration runner/script because both are direct A4 entry constraints.

P1-A3 is independently `ACCEPTED`, so A4 planning is legitimately open. This
review does not authorize implementation, does not accept A4, and does not open
P1-B. No user hash echo is required; the findings require a bounded,
decision-complete leaf revision followed by a fresh responsibility-isolated
plan re-review.

## 2. Contracts that are already sufficiently specified

The 13-file product/test/script allowlist is necessary and, after the findings
below are resolved without product expansion, sufficient for the A4 root
cause:

- `ScheduleStore.swift` can own fetch-only fire/cursor records and existing
  schedule CRUD integration;
- `AppDatabase.swift`, the three Durable Work files, and `Orchestrator.swift`
  can host the existing Coordinator → Orchestrator → Supervisor → AppDatabase
  → fileprivate ledger architecture without a new target or public API;
- `ScheduleMath.swift` is the correct owner for due/cursor and slot identity;
- `MissionScheduler.swift` is the current App owner of background callbacks,
  run-now, startup catchup, guide broadcast, and notification ordering;
- the three test files can cover exact DDL, store/transaction/concurrency,
  legacy schedule migration, and App source ordering without an App dependency
  edge; and
- the existing runner and script really do hard-code the durable-v12 terminal
  checkpoint and must be advanced by A4 rather than bypassed.

No `AppStore.swift`, View, `EventKind.swift`, `PlanningProviderResolver.swift`,
`Package.swift`, `Package.resolved`, or `RunTests` change is presently needed.
The existing `schedule_fired` / `schedule_missed` event kinds and the package
access boundary are sufficient.

The following substantive decisions are also sound:

- §18.2 is carried exactly as two tables, three named indexes, two SQLite PK
  autoindexes, no `intended` state, and no premature F2/v16 trigger. The stated
  latest checkpoint of 29 tables / 60 indexes / 4 triggers is arithmetically
  consistent with the accepted durable-v12 checkpoint.
- Fetch-only ordinary fire/cursor records plus raw mutation confined to one
  fileprivate ledger are an adequate A4 boundary. F2 still owns one-shot
  redaction, post-redaction immutability, and delete triggers.
- Original `started` and `failed` writes, cursor movement, and successful-only
  `lastFiredAt` movement belong in one transaction. A queued attempt-zero
  planning work makes commit-before-kick restart-safe.
- Durable running before replay/absence, provider resolution outside the write
  transaction, a second durable/profile fence in the writer, and unique-index
  winner validation are compatible with the current GRDB/actor architecture.
- Original `(scheduleId, slotKey)` identity, a global replay key, canonical
  replay payload hash, first-trace preservation, no automatic retry after a
  failed original, and no cursor/`lastFiredAt` movement on explicit replay are
  the correct Stage §6.6 semantics.
- The migration route retains all seven predecessors, a real v12-durable
  checkpoint, dual SQLite 3.51/3.52 literal and GRDB lanes, replay/rollback,
  inherited durable diagnostics, FK and integrity gates. The old A1a tests can
  remain pinned to `migrate(..., upTo: "v12-p1-durable-work")` while a new A4
  test owns the latest checkpoint.
- The ten canonical names match canonical Plan §3.5. Starting from the accepted
  657-test A3 baseline, ten additions with no deletion or merge produce the
  stated 667 tests in 7 suites.

These sound points do not close the five blocking gaps below.

## 3. Findings

### P0

0.

### P1-01 — Replay disposition is not bound to post-commit side effects

Leaf §7 says an existing original slot returns its first graph without another
fire/event/cursor increment. Leaf §8 is stronger for a replay-key retry: same
key + same canonical payload must return the first replay with zero writes,
events, provider resolution, cursor movement, or trace overwrite. The result
type deliberately contains `.inserted|.replayed`.

Leaf §9 nevertheless says every started result performs wake → guide broadcast
→ `onScheduleFired`, and says every failed result may broadcast missed. It does
not condition the latter two effects on disposition. Two incompatible
implementations therefore satisfy different parts of the text:

1. broadcast/notify every returned started fire, which creates a second guide
   write and user-visible notification on original/replay-key replay; or
2. treat those as first-commit effects only and use a replay solely as a
   conditional wake opportunity.

The current code does not resolve this choice for the implementer. Its
`MissionScheduler.fire` broadcasts and calls `onScheduleFired` on every
`.started` outcome, while A3 already established the relevant precedent:
replayed queued/retry work may be kicked, but start events are inserted-only.
Neither `sameSlotReplayReturnsSameMission` nor
`replaySamePayloadReturnsSameFireButConflictFails` currently freezes guide and
notification counts at the operation boundary.

**Required bounded revision:** define the complete disposition/effect matrix.
A new `.inserted` started fire may conditionally wake, broadcast once, and
notify once; a `.replayed` started fire may only perform the current-state
conditional wake and must not append a guide message, re-notify, emit a start
event, or mutate fire/cursor/schedule state. A new `.inserted` failed fire may
attempt one missed broadcast; a `.replayed` failed fire must perform no
post-return write or notification. Bind post-commit catches to this matrix and
add dynamic/source assertions inside the existing ten canonical tests so the
667 count does not change.

### P1-02 — The slot/date contract is not total at its required overflow boundary

Leaf §4 requires every accepted slot key to contain an exact Foundation
calendar token and a fully resolved local
`era/year/month/day/hour/minute/second/nanoseconds` tuple. It does not define:

- the exact, non-localized mapping from every supported
  `Calendar.Identifier` to `calendarId`, or which identifiers are rejected;
- what happens when Foundation cannot resolve one of the required local
  components for a finite but extreme `Date`; or
- the database date encoding/decoding strategies for fire `scheduledAt`,
  cursor `lastEvaluatedScheduledAt`, and the associated created/updated fields.

This becomes an internal contradiction in §6/§11. A finite date whose checked
UTC milliseconds exceed `Int64` is required to commit a failed
`schedule_fire_time_out_of_range` row and advance the cursor, but committing
that row first requires a non-null canonical slot key containing all local
components. For an instant outside Foundation Calendar's representable range,
the required key cannot be formed; the plan forbids a nil/default component
fallback but supplies no alternate identity. The caller/store cannot implement
both contracts without inventing a new key shape or silently changing the
failure classification. Storage strategy is also material because cursor
ordering, replay equality, and `scheduledAtInstantBits` must survive a DB
round-trip.

**Required bounded revision:** freeze a total `ScheduleSlotContextV1`
construction contract: an exhaustive supported-calendar token mapping,
component-nil behavior, exact `Date` database strategies, and the ordering of
slot construction versus range classification. Either prove and test that the
specified finite-overflow fixture can always form the exact v1 key and round
trip, or classify slot-key-unrepresentable dates as a typed pre-DB zero-write
error and remove the contradictory failed-fire/cursor expectation. Add exact
coverage for the chosen extreme boundary, `-0.0`, missing components, and
storage/bit round-trip without changing §18.2 DDL.

### P1-03 — Failure codes are named, but the executable typed/message mapping is not frozen

Leaf §6 says expected business failures persist one **exact** safe code/message
and all unknown/database/canonical/integrity failures throw and roll back. The
table gives codes, but it does not give the fixed message literal for any code,
and several rows still require implementer classification:

- “template missing or FK mismatch” and “Camp missing” may be typed not-found
  or integrity errors, but the exact type and boundary are not named;
- stale cursor-without-fire is called a typed integrity error without its
  type/fields;
- “App runtime selection” is grouped with expected profile absence/CLI/kind
  drift even though that closure can also throw a real database read error;
- “planning provider resolver failure” does not state that only the existing
  typed `PlanningProviderResolutionError` is terminal data while an unknown
  resolver error is rollback/fail-fast; and
- the read snapshot says it captures the exact `RuntimeProfileRecord`, while
  the writer text only binds profile ID/kind/non-CLI state, leaving base URL,
  credential-account/default/model-policy drift unspecified.

An implementer must consequently invent user-visible strings, choose which
errors are swallowed into failed rows, and choose the profile-race equality
surface. That directly affects persistent audit bytes, replay payload hashes,
and the required validation matrix.

**Required bounded revision:** add one exact typed classification table with
the error type, stable code, exact safe message, mutation shape, and
replay-payload `runtimeState/profile/model/preflightFailureCode` values for
every row. State explicitly that database/canonical/unknown resolver and
unknown runtime-selection errors roll back, while only enumerated typed
business/provider outcomes become failed fires. Freeze whether profile
revalidation compares the whole persisted record or an exact listed subset,
and add drift cases for every listed field. No raw `Error` or
`String(describing:)` may enter the command or persisted event/fire.

### P1-04 — The A4 scope/evidence gate cannot currently distinguish reviewed A4 change from weakened A3 evidence

The current accepted A3 test
`a3Revision02EntryBoundaryRemainsByteExact` is executable, not documentary.
Its immutable 206-entry manifest hashes every Source file outside the original
nine A3 files plus Package/lock/script, and its additional frozen dictionary
pins several original-A3 files. All 13 A4 files are therefore currently
protected by one of these A3 boundaries, including both files that A4 is meant
to change and files that must remain frozen.

The leaf correctly adds `DurablePlanningTests.swift` because this sentinel must
be reconciled, but it only says that the sentinel “otherwise rejects A4.” It
does not specify the fail-closed transformation. An implementer could skip all
A4 paths, replace the old manifest, remove hashes, or broadly relax the test;
all would make A4 green, but only an exact 13-changeable / everything-else-
frozen partition preserves A3 evidence. The task artifact allowlist also has no
explicit A4 entry manifest, even though `git diff` from the main HEAD cannot
isolate A4 inside the intentionally dirty P1 worktree.

The migration script has the same executable-anchor problem. Current bytes pin
`expected_stage_hash=a8ca6e...`, while the current canonical Stage hash is
`bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6`;
the script will fail before either A4 lane. The canonical §18.2 SQL extraction
is presently 47 lines with SHA-256
`c693edcdfe15d586b018bc51dceeebf8091544edede5dc9eb775a105153717ea`,
but the leaf does not freeze those derived values or say how the existing
§18.1 187-line/hash diagnostics anchor remains independently enforced.

**Required bounded revision:** define an executable A4 entry partition derived
from the accepted A3 current bytes: exactly the 13 reviewed paths may differ;
every other Source, Package, RunTests, and script path remains byte-exact and
regular/non-symlink. Keep the historical A3 manifest immutable; specify the
exact filtered-manifest/frozen-hash update in
`DurablePlanningTests.swift` rather than permitting a broad skip. Authorize an
A4 entry/source manifest artifact or freeze the complete partition in
`source-gates.log` before the first red edit. Also freeze the script's current
Stage anchor and separate §18.1/§18.2 line/hash assertions above, while
preserving every inherited durable diagnostic and both real/literal SQLite
lanes. This requires no product-file expansion.

### P1-05 — The completion gate omits the canonical P1-A App preview requirement

Canonical P1 Plan §11 requires P1-A to run
`scripts/run-app.sh --preview` twice, and the collaboration protocol requires
real App launch evidence when App behavior is modified. A4 changes the
`MissionScheduler` startup, background callback, broadcast, and notification
path, but leaf §12/§13 stops at debug/release builds and provides no
`preview.log` task artifact. A build cannot prove the App launches through the
real script or that the startup scheduler path avoids the normal state root.

This omission is especially material after the preserved A2 historical
incident in which an installed-App lookup opened the normal root. The A4 leaf
also forbids normal user-data access, so an unspecified preview cannot safely
fill the gap after implementation.

**Required bounded revision:** add `preview.log` to the task artifact set and
run the repository's exact preview script twice only after tests/build/matrix
are green, with a fresh explicit isolated state root and exact-path process
evidence. Require zero normal-root access and no display-name/installed-App
fallback, and preserve failures honestly. Preview is execution evidence, not
authorization to edit `scripts/run-app.sh`, access normal data, or perform a
real-user action.

### P2-01 — Catchup prompt consumption is process-local despite “durable” wording

Leaf §5 commits an offline miss and cursor durably, then stores its fire ID only
in the process-local `ScheduleCatchup`. It says decline removes the prompt, but
§18.2 has no consumption/dismissal fact. A crash after fire commit and before
the user chooses cannot be distinguished from a deliberate decline on the next
startup: rebuilding every unreplayed offline fire repeats declined prompts,
while relying only on the new cursor permanently loses the unconsumed prompt.

This does not corrupt the fire/cursor ledger, so it is P2 rather than an A4
transaction blocker. The revision should nevertheless state the chosen A4 UX
limit explicitly (session-only prompt with durable history available for later
replay) or identify an already-existing durable, in-scope fact that
distinguishes decline without changing exact §18.2. It must not silently invent
another table/column or pretend the current in-memory array is durable.

## 4. Test and acceptance impact of the bounded revision

The five P1 findings can be closed without adding an eleventh canonical test or
expanding the 13 product/test/script files. The revised ten tests must absorb:

- inserted-versus-replayed guide/notification/write counts;
- total slot construction and exact date storage/overflow cases;
- exact typed code/message/profile/provider drift rows;
- the fail-closed A3→A4 13-path evidence partition and dual literal anchors;
  and
- the two isolated preview executions as non-test acceptance evidence.

All existing A1a–A3 tests and evidence remain historical/current requirements;
none may be deleted, renamed, merged, or weakened merely to reach 667. A fresh
failure-first run is still required before product implementation, followed by
the individually selected canonical tests, legacy affected tests, dual-SQLite
matrix, debug/release builds, source gates, two previews, and one fresh direct
task `verify.log` with exactly 667/667 in 7 suites.

## 5. Verdict and next gate

**CHANGES REQUIRED — 0 P0 / 5 P1 / 1 P2.**

A4 implementation remains closed. Make one bounded leaf revision limited to
P1-01…P1-05 (and clarify P2-01 if cheap), preserve this Review01 immutably, and
obtain a fresh responsibility-isolated plan re-review. Only a verdict with zero
P0/P1 may open the failure-first test edit and subsequent A4 implementation.
P1-B and all later stages remain closed.
