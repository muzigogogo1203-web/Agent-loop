# P1-E Compatibility Plan Review — Review01c

> Date: 2026-08-26  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This review was performed by a separate Codex
> subagent in a read-only pass; the reviewer did not author the plan and did not
> modify product or test source.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

```text
base_plan_sha256=e258b68a91c375309728933b8c34619c8350afbfeb500040582fb7e07c5a8727
revision_01_sha256=a490e3408ae4deb227980a2af8a382fe47e2d2ff8651546baf7fc72e90a56198
revision_02_sha256=597646e6ee2152ddfff523fbe67d0651e3a0050dc3fae8e65496bd0dd6d4bca9
revision_03_sha256=3ffec577b9045c8796bf44f21a504851630bf2c73ccf9eed2e59d6f513b05492
effective_allowlist_sha256=1e94456880e52d584fde94503e4159902f8889d5b16e6933fb6e6545e4ff69c9
compatibility_red_sha256=9cf63ce72bf30104132b736c53dd77fb0f4f1b60621dc438ed5fc7b4b8f1ea4b
remaining_red_frame_sha256=641eee9552e92d2244040da6e0c4235451e35bcbd418d4d7492259f584d5e80d
```

## Review scope and method

I reviewed the immutable base plan, Revisions 01–03, canonical P1 plan §7,
canonical Stage §§14–15/18.6/19/26–27, the executable allowlist, both red
frames, the two newly admitted test files, and the existing event/schedule/
Board/Orchestrator owners. I did not run a build or test command. Read-only
checks were limited to hashes, manifests, source inspection, and the base
plan's NUL-safe boundary serializer.

The review asked whether Revision 03 is decision-complete, whether the two new
test paths are the minimum demonstrated expansion, and whether its timestamp,
kernel-scope, fixture, TDD, and completion rules preserve the accepted
fail-closed contracts.

## Findings

### Frozen inputs and boundary

- The allowlist has exactly 102 nonempty, unique, LF-terminated entries. Removing
  exactly the four Revision-03 additions reconstructs the 98-line Revision-02
  SHA `63f35456ff4dba564c17cbe52c02ee189c4b38c4f176eacba367907ba0b41b68`.
- The two source/test pre-images match the plan exactly:

```text
BoardToolsTests.swift=a191a5c9b2706b699ee2410be1470aeaf3182d01acb7682a5ecab2f234aeac42
ScheduleTests.swift=e4fcaa1adf9ce7a5d75858549c9eb3f51032816b74008370249b07f92cc8e5e8
```

- Replaying the base plan's byte-count/mode/content NUL-safe serializer against
  the 102 paths gives the frozen effective boundary:

```text
outside_count=499
outside_manifest_v1=206148164535b7e48b1fc64ec564c4bf5ff9b86981ec12509c9d43b7fd9243a9
```

  The observed counter increase from the plan snapshot is only the now-present
  Revision-03 artifact; this review is the second named artifact. Neither is an
  outside-boundary change.

### Scope minimality and successor sentinels

- `BoardToolsTests.swift` is required because its fixture supplies `run-1`
  without a Run row. The v16 resolver correctly rejects that dangling reference;
  using the existing atomic `startRun` is the narrow fixture correction and does
  not authorize a BoardTools production change.
- `ScheduleTests.swift` is required for exactly the protected companion-delete
  fixture and the post-v16 raw event insert. Encoding a nonexistent companion ID
  in the template and using the scope-owning append helper preserve the intended
  failure/projection assertions without weakening foreign keys or scope triggers.
- No additional source/test path is needed: `Records.swift`,
  `LegacyEventScopeResolver.swift`, both existing P1-E contract tests, and
  `DurablePlanningTests.swift` were already admitted.
- Independent manifest intersection reproduces Revision 03 exactly: A4 raw
  P1-E intersection is 33 (BoardTools is already removed by P1-D), and A3 raw
  P1-E intersection is 35 (BoardTools is removed by P1-D and Schedule by the A4
  historical set). The seven P1-E successor exclusions, A4 unaffected count
  131, and A3 live/enumerated count 127 therefore remain unchanged.

### Timestamp and kernel-scope contracts

- GRDB's deferred Date encoder writes millisecond UTC text, while
  `schedule_fire.createdAt` deliberately stores exact epoch seconds. Applying
  `.timeIntervalSince1970` only to `EventRecord.createdAt` preserves the exact
  `Double` bits used by the existing replay integrity check. Leaving deferred
  decoding in place reads both historical text rows and new numeric rows. The
  plan explicitly forbids migration, tolerance, rounding, manual SQL, and replay
  relaxation, so this is the single root correction rather than a symptom patch.
- The kernel rule is dual-scope rather than a global downgrade. Empty-string
  mission IDs are an established Orchestrator global sentinel, and nil mission
  with no reference evidence is likewise global. Any card/run/payload evidence,
  a nonempty mission, dangling reference, or cross-Camp evidence stays on the
  strict resolver path or fails closed. Existing mission-scoped kernel tests plus
  the two required runtime/backfill extensions guard both sides, including
  scope-first insertion.

### TDD, compatibility gate, and red lines

- The immutable full red frame and the 109-test remaining-red recheck are
  truthful pre-change evidence for the date, Board, Schedule-fixture, and
  Orchestrator roots. Revision 03 additionally requires source-unchanged red
  evidence for the two new kernel assertions before their production fix.
- The three declarations from the first red frame that have current successor
  names map deterministically as follows and must be included in the zero-issue
  compatibility gate:

```text
inboxConflictAgainstRedactedRowIsTerminalWithoutCASOrHandler
  -> inboxOrdinaryRedactionIsRejectedWithoutCASOrHandler
inboxRedactedTombstonesPreservePriorHashAndAppliedTimeAcrossOrigins
  -> inboxOrdinaryRedactionFencePreservesEveryOrigin
outcomeContractMigrationLiteralMatchesStageSection18_5
  -> outcomeContractMigrationRemainsPresentUnderV16Head
```

- The ordered narrow tests, three standalone observations for each of the four
  load-sensitive tests, exact 90-test P1-E gate, source/scope gates, build,
  dual SQLite lanes, and authoritative unfiltered `swift run RunTests` are all
  required before implementation review or acceptance. No retry-only source
  change, assertion weakening, v17/P1-F behavior, external action, or
  outside-allowlist write is authorized.

No P0 or P1 issue remains. The plan gives an exact implementation and evidence
path without requiring an architecture, data-model, product, or dependency
decision from the implementer.

## Verdict

**APPROVED — 0 P0 / 0 P1.**

