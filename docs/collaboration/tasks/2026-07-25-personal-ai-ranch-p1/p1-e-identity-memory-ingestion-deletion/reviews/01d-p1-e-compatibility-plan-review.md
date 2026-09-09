# P1-E Compatibility Plan Review — Review01d

> Date: 2026-08-26  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This review was performed by a separate Codex
> subagent in a read-only pass. The reviewer did not author Revision 04 and did
> not modify product or test source.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

```text
base_plan_sha256=e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727
revision_01_sha256=a490e3408ae4deb227980a2af8a382fe47e2d2ff8651546baf7fc72e90a56198
revision_02_sha256=597646e6ee2152ddfff523fbe67d0651e3a0050dc3fae8e65496bd0dd6d4bca9
revision_03_sha256=3ffec577b9045c8796bf44f21a504851630bf2c73ccf9eed2e59d6f513b05492
revision_04_sha256=e1f12961edcadf02dd2c404037235c19a5ad43673e5c87d8c231a02a6204c41a
effective_allowlist_sha256=fa6fb13794903e66ce316f69a5f39922e9edca0fea69f72099a258c12cd3b43c
schedule_tests_preimage_sha256=e4fcaa1adf9ce7a5d75858549c9eb3f51032816b74008370249b07f92cc8e5e8
trigger_red_sha256=40b661921870ba66a6c0e9a1d45ef4f695123de805ff0440aef068692c048867
```

## Review scope and method

I reviewed the immutable base plan, Revisions 02–04, Review01c, the executable
allowlist, `/tmp/p1e-event-date-green.KqISfC`, the Schedule corruption helpers,
the v16 migration trigger DDL, the scope-first legacy-event append helper, and
the A3/A4 successor sentinels. I did not run a build or test command. Checks
were limited to hashes, the NUL-safe outside-boundary serializer, exact source
occurrences, and surrounding semantics.

## Findings

### Frozen inputs and boundary

- The trigger log is complete and matches Revision 04: seven Schedule replay
  tests ran, six passed, and the only issue is `no such trigger:
  event_no_update` in `replaySamePayloadReturnsSameFireButConflictFails`.
- `scope-allowlist.txt` has exactly 104 nonempty, unique, LF-terminated paths
  and the SHA above. Removing only the Revision-04 plan and Review01d paths
  reconstructs the Revision-03 allowlist SHA
  `1e94456880e52d584fde94503e4159902f8889d5b16e6933fb6e6545e4ff69c9`.
- Replaying the base plan's NUL-safe serializer gives the unchanged boundary:

```text
outside_count=499
outside_manifest_v1=206148164535b7e48b1fc64ec564c4bf5ff9b86981ec12509c9d43b7fd9243a9
```

  The current first-two counters have advanced only as the newly allowlisted
  Revision-04 artifact became present; they do not change the frozen outside
  boundary. `ScheduleTests.swift` still matches its Revision-03 pre-image.

### Trigger substitutions are exact and isolated

- v16 removes `event_no_update` and installs
  `event_reject_update_except_camp_redaction`. `ScheduleTests.swift` contains
  exactly three `DROP TRIGGER event_no_update` statements and no occurrence of
  the replacement yet.
- All three statements belong to the single
  `replaySamePayloadReturnsSameFireButConflictFails` corruption matrix: the
  shared winner-corruption helper is called only by that test, and the other
  two drops prepare its provenance and failure-pair corruptions.
- Every owning fixture is backed by a fresh UUID-named temporary database. The
  drop occurs immediately before deliberate event mutation; the typed-scope
  triggers, foreign keys, migrations, and production database are untouched.
  Existing replay-integrity errors, provider-call counts, mutation snapshots,
  and `changesCount` guards remain required.
- These are integrity-reader corruption fixtures, not ordinary deletion or
  redaction fixtures. Revision 02's prohibition on dropping v16 triggers from
  ordinary redaction tests therefore remains intact; Revision 04 does not
  authorize any other trigger drop.

### Scope-first opposite event preserves the test contract

- The current `oppositeEvent` case already constructs the canonical
  `ScheduleMissedPayloadV1` with the winner fire's schedule/template/slot,
  provenance, trace, failure details, and exact `fire.createdAt`; only its raw
  unscoped SQL insert is invalid under v16.
- `AppDatabase.appendLegacyEventAndScope` validates the exact canonical bytes
  and finite date, resolves `scheduleMissed` through the persisted template and
  schedule, inserts `camp_event_scope` first, then inserts the event. With nil
  mission/card/run it therefore creates the required Camp scope without
  changing the deliberately contradictory event semantics. Its final event
  insert also preserves the existing `changesCount == 1` guard.

### Successor sentinel arithmetic

- Independent manifest intersection with the 104-line allowlist gives A4 raw
  P1-E intersection `33` and A3 raw P1-E intersection `35`.
- The new Revision-04 paths are documentation artifacts and do not occur in
  either historical source manifest. The exact seven successor exclusions,
  A4 unaffected count `131`, and A3 live/enumerated count `127` remain
  unchanged. Updating only the allowlist SHA/count and the two raw intersection
  counts is therefore sufficient.

No P0, P1, or necessary P2 finding remains. Revision 04 is bounded to one
already-admitted test path plus its exact successor sentinel and does not
weaken a production trigger, replay validator, redaction contract, assertion,
or scope rule.

## Verdict

**APPROVED — 0 P0 / 0 P1.**
