# P1-E Plan Revision 09 — historical ownership arithmetic correction

> Date: 2026-08-27  
> Scope: mechanical correction of the single Review01h P1; no implementation
> expansion  
> Authority: accepted P1-E base plan; Revisions 01–08; Reviews 01g/01h;
> canonical P1 authority; user direction to proceed independently without
> Claude  
> Frozen history: Revisions 07–08 and Reviews 01g–01h remain byte-immutable;
> neither review authorized source/test implementation

## 1. Trigger and exact supersession

Review01h independently confirmed that Revision 08 fully closes Review01g's
accept-loop scheduling P1 and that the implementation boundary is otherwise
decision-complete. It returned one arithmetic finding:

```text
Review01h=NEEDS CHANGES — 0 P0 / 1 P1
review01h_sha256=76d3752943a5ddbec826ae1ae86f535d1fd0b858c1c58f2fdd39a39cc478cb43
revision08_sha256=413c8dbcb4f8d13c17e7f014307fc3e58900ccc70d60e964497bc55e6bb260a4
```

`HaltAndCooldownTests.swift` is already in the frozen 66-entry P1-B exact
allowlist. It increases P1-E's raw manifest intersection but is removed by the
earlier P1-B ownership subtraction. `BoardToolServer.swift` is already in the
P1-D exact allowlist and is likewise removed by P1-D ownership subtraction.
Neither path joins P1-E's historical successor-owned set.

Revision 09 supersedes only Revision 08 §§2, 5, 6, and 7 where they state the
allowlist hash/count or historical arithmetic. Every product/test decision,
pre-image, tests-first step, narrow command, build/migration/preview/full gate,
and red line in Revision 08 remains effective.

## 2. Exact effective boundary

Revision 09 adds only these two task artifacts:

```text
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/plan-revision-09.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-e-identity-memory-ingestion-deletion/reviews/01i-p1-e-compatibility-plan-review.md
```

The exact effective allowlist and outside boundary are:

```text
allowlist_lines=135
allowlist_nonempty_unique=135
allowlist_sha256=e6cf95c710cf2c7f513740cb49894f69df4ca1ecc01fc48e8294a3291dd881bb
outside_count=494
outside_manifest_v1=b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740
```

Immediately before this plan, counters were `dirty_total=618` and
`allowlisted_present_count=124`; only this plan and Review01i may advance the
allowlisted count before tests-first writes.

The implementation-sensitive pre-images remain exactly:

```text
BoardToolServer.swift=ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea
BoardServerTests.swift=ea974b23b544fd353772935440f38f07916f406befccc0bfe245d3b30c6e1dda
Orchestrator.swift=4dcfa183d6a7e85d31651d7dded45a5adb624a4cda01677c010c7727efc1e087
HaltAndCooldownTests.swift=339d8ddf8c1bc0514590a813f3ebab671885c5b5ed2b6dfe231b3e5810a13b6a
DurablePlanningTests.swift=c05d633ff65e7f7edf25c35bbbf8ab2a18bd23c35887e7eba6c070011f8c07d5
```

Runner, `DurableWorkSupervisor`, Package/lockfile, durations, socket protocol,
and every other Revision-08 protected byte remain frozen.

## 3. Correct historical arithmetic

`a3P1EHistoricalSuccessorExclusions` remains the original ten-entry
Revision-06 set, byte-for-byte:

```text
Sources/AgentLoopCore/Support/ShellProcessRegistry.swift
Sources/AgentLoopCore/Ingestion/FeedService.swift
Sources/AgentLoopCore/Ingestion/IngestionRecords.swift
Sources/AgentLoopCore/Product/CowTemplate.swift
Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift
Sources/AgentLoopTestSuite/ChatServiceTests.swift
Sources/AgentLoopTestSuite/FeedTests.swift
Sources/AgentLoopTestSuite/MultiCampTests.swift
Sources/AgentLoopTestSuite/PlanningTokensTests.swift
Sources/AgentLoopTestSuite/ShellToolTests.swift
```

The only sentinel expectation changes from the current pre-image are:

```text
allowlist_lines=135
allowlist_sha256=e6cf95c710cf2c7f513740cb49894f69df4ca1ecc01fc48e8294a3291dd881bb
A4 raw P1-E intersection=40
A4 P1-E successor-owned entries=10
A4 unaffected entries=206-46-3-19-10=128
A3 raw P1-E intersection=42
A3 P1-E successor-owned entries=10
A3 live/enumerated entries=206-7-43-3-19-10=124
```

Both frozen manifests stay at 206 unique entries and retain their hashes.
No predecessor allowlist, manifest, or ownership set is edited.

## 4. Effective implementation and execution

After independent Review01i reports `APPROVED — 0 P0 / 0 P1`, implementation
follows Revision 08 exactly:

1. save the unrelated-pipe `+2` behavior red and the missing `rateLimitNow` /
   `acceptQueue` compile red to `red-revision-08-tdd.log`;
2. implement the causal shutdown test, package-only cooldown clock, owned-FD
   observer, default-preserving Board accept queue, and two distinct dedicated
   framing queues in only the five frozen files;
3. update only the sentinel values in §3;
4. run every Revision-08 narrow, 112-test successor, 90-test P1-E,
   source/scope, app build, protected migration-hash, isolated packaged
   preview, and single exact default-parallel full gate;
5. preserve a different failure rather than rerunning by chance.

The source/scope gate must use 135 /
`e6cf95c710cf2c7f513740cb49894f69df4ca1ecc01fc48e8294a3291dd881bb`
and outside 494 /
`b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740`.

All Revision-08 completion conditions and red lines remain binding. P1-E stays
unaccepted and P1-F1 closed until the exact full gate is green, independent
implementation Review02 reports zero P0/P1, and acceptance is evidence-backed.
