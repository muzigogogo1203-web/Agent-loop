# P1-E Plan Revision 04 — Repair the isolated schedule corruption fixture

> Date: 2026-08-26  
> Scope: one latent Schedule replay-integrity fixture exposed after the
> Revision-03 event timestamp root fix  
> Authority: base P1-E plan §§3, 8–12; Revisions 01–03; canonical P1 plan §7;
> canonical Stage §§14–15, 18.6, 19, 26–27  
> Frozen history: every earlier plan/review/red artifact remains byte-immutable

## 1. Trigger and root cause

After applying only the independently approved `EventRecord.createdAt` epoch
encoding fix, the seven-test Schedule replay gate produced six passes. The
seventh test advanced past `ScheduleFireReplayIntegrityError` and exposed a
previously masked fixture error:

```text
temporary_log=/tmp/p1e-event-date-green.KqISfC
tests=7
issues=1
failing_test=replaySamePayloadReturnsSameFireButConflictFails
error=SQLite error 1: no such trigger: event_no_update
sha256=40b661921870ba66a6c0e9a1d45ef4f695123de805ff0440aef068692c048867
```

The test deliberately creates impossible persisted winners so the replay
reader can prove fail-closed integrity. Its corruption helper still names the
pre-v16 append-only trigger, while v16 replaced that trigger with
`event_reject_update_except_camp_redaction`. A later corruption case also
raw-inserts an opposite event without its mandatory typed scope. These are
test-fixture compatibility defects, not production defects.

## 2. Exact effective scope

No source/test path is added. `ScheduleTests.swift` was already admitted by
Revision 03. The executable allowlist adds only this revision and its review:

```text
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-04.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01d-p1-e-compatibility-plan-review.md
```

The effective allowlist is exactly 104 unique LF-terminated paths:

```text
allowlist_sha256=fa6fb13794903e66ce316f69a5f39922e9edca0fea69f72099a258c12cd3b43c
dirty_total=594
allowlisted_present_count=95
outside_count=499
outside_manifest_v1=206148164535b7e48b1fc64ec564c4bf5ff9b86981ec12509c9d43b7fd9243a9
```

Only the first two counters may increase as the two named artifacts become
present. The outside count/hash remains frozen.

`ScheduleTests.swift` is still at its Revision-03 frozen pre-image before this
fixture write:

```text
e4fcaa1adf9ce7a5d75858549c9eb3f51032816b74008370249b07f92cc8e5e8
```

## 3. Decision-complete fixture correction

Only `ScheduleTests.swift` changes, and only inside the explicit corruption
fixtures owned by `replaySamePayloadReturnsSameFireButConflictFails`:

1. Replace exactly three `DROP TRIGGER event_no_update` statements with
   `DROP TRIGGER event_reject_update_except_camp_redaction`.
2. Each drop occurs only in its fresh temporary test database immediately
   before deliberate event corruption. The scope trigger, insertion trigger,
   foreign keys, production migration, and production database remain intact.
3. In `ScheduleStartedWinnerCorruption.oppositeEvent`, replace the raw SQL event
   insert with `AppDatabase.appendLegacyEventAndScope`, preserving the exact
   canonical `ScheduleMissedPayloadV1`, nil mission/card/run, Schedule-missed
   kind, and `fire.createdAt`. The helper must create the matching typed Camp
   scope before the event.
4. Keep every replay-integrity assertion, provider-call assertion, mutation
   snapshot, and `changesCount` guard. No production reader/writer or trigger
   is weakened.

The corruption fixture is intentionally isolated from the redaction fixtures
covered by Revision 02 §4.2.6; no ordinary redaction test may drop a v16
trigger.

## 4. Successor sentinel update

`DurablePlanningTests.swift` changes only its P1-E exact allowlist SHA/count to
the 104-line values above. A4/A3 raw intersections remain 33/35, successor sets
remain exact, and unaffected/live counts remain 131/127. No historical
manifest is rewritten.

## 5. Ordered gate

1. Freeze this revision and independent Review01d before the fixture write.
2. Apply the exact three trigger-name substitutions, typed opposite-event
   insertion, and 104-line successor sentinel.
3. Run `replaySamePayloadReturnsSameFireButConflictFails` alone; it must pass
   every corruption case.
4. Resume Revision 03's Schedule, Board, kernel, 112-successor, load-sensitive,
   90-test, source/scope, build, matrix, and authoritative full-suite gates.
5. Any later failure with a different root requires another bounded reviewed
   revision; it may not be hidden by removing a corruption case or assertion.

## 6. Completion gate and red lines

Revision 04 is complete only when Review01d is `APPROVED — 0 P0 / 0 P1`, the
standalone replay-integrity test passes, and every Revision-03 completion gate
passes. No path outside the 104-line allowlist, production trigger, v17/P1-F
behavior, or prohibited external action may change.
