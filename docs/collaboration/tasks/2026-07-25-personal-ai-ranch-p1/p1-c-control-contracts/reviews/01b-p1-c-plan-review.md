# Review01B — AgentLoop P1-C Revision 2 Plan Review

> Date: 2026-08-25  
> Reviewer: fresh responsibility-isolated, read-only reviewer  
> Role: reviewer only; not plan author or implementer  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Review boundary: frozen P1-C Revision 2 plan only

## 1. Review conduct

- Read the complete requested authority, P1-B evidence, Revision 2 plan, Review01, and Review01A.
- Inspected only relevant Swift 6, GRDB, DurableWork, Application, migration-matrix, and test-discovery surfaces.
- Did not edit or create any file.
- Did not run tests, builds, migrations, matrix lanes, App/package operations, Git writes, external actions, Claude, or non-repository memory.
- Preserved all pre-existing tracked and untracked worktree state.
- Executed the embedded outside-worktree Ruby serializer unchanged through stdin. The current `PATH` selected fallback Git 2.53.0; no serializer or temporary repository file was created.

## 2. Frozen checkout, hashes, and manifest

### 2.1 Checkout and worktree

| Check | Start/recheck | End |
|---|---|---|
| CWD | `/Users/muzi/Agent-loop` | same |
| Branch | `codex/personal-ai-ranch-p0` | same |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` | same |
| Candidate plan SHA-256 | `2afe62111cf7cac3df3e2d60efb20db7e383966adf52338d744182e0f207b396` | same |
| Porcelain-v1 `-z` status SHA-256 | `b40970e50184c4e3ae9a632ea3d4cdd78594bb18fcc13b939fab596abd461297` | same |
| Dirty paths | 460 | 460 |
| Tracked worktree modifications | 63 | 63 |
| Untracked paths | 397 | 397 |
| Staged paths | 0 | 0 |

### 2.2 Authority and predecessor hashes

| Artifact | SHA-256 |
|---|---|
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| P1-B authoritative `verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |
| Rejected Review01 | `08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b` |
| Rejected Review01A | `cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a` |
| Revision 2 candidate | `2afe62111cf7cac3df3e2d60efb20db7e383966adf52338d744182e0f207b396` |

### 2.3 Protected current-source hashes

| Surface | SHA-256 |
|---|---|
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` |
| Matrix runner | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` |
| Matrix script | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` |
| `DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |

### 2.4 Outside serializer

The unchanged embedded serializer returned identically on both executions:

```text
dirty_total=460
allowlisted_present_count=12
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

The increase from the plan’s `457 / 9` planning snapshot is exactly three allowlisted task artifacts: the candidate plan and two rejected reviews. The protected outside set remains unchanged.

### 2.5 Static migration and test inventory

- Stage §18.4 v14 SQL body: 292 lines.
- v14 SQL SHA-256: `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531`.
- Static objects: 10 tables, 13 named indexes, 4 triggers.
- Embedded test manifest: 81 entries and 81 unique names.
- Distribution: C1 9, C2 21, C3 24, C4 27.
- The revised declaration/discovery gate compares exact full sets and rejects extras as well as omissions. This is statically decision-complete; discovery itself was not run during this prohibited-execution review.

## 3. Prior-finding resolution

### 3.1 Review01

| Review01 finding | Review01B determination |
|---|---|
| P1-01 — creation/replay/vocabulary | **NOT FULLY RESOLVED.** Receipt-first archive replay, Understanding event heads, outbox identity, vocabulary, and most result arrays are now fixed. Worker-generated command identities remain unspecified, and one sealed result branch is impossible. See P1-02 and P1-04. |
| P1-02 — Input/Coach durable lifecycle | **NOT FULLY RESOLVED.** Claim handoff, renewal shutdown, adoption, and retry ownership are feasible. Ordinary Input transitions can still strand active parsing, and reopened Coach terminal failure is contradictory. See P1-06 and P1-07. |
| P1-03 — Input audit/projection Camp | **RESOLVED.** Audit, projection, work, assignment, post-assignment, cross-Camp, and archive rules are sealed. |
| P1-04 — safe JSON/inbox | **NOT FULLY RESOLVED.** Non-redacted replay/conflict behavior is now exact, but the redacted classifier rejects the authoritative deletion tombstone. See P1-05. |
| P1-05 — Application seam | **NOT FULLY RESOLVED.** Port and controller APIs are fixed, but the promised installation-ID critical section is not implementable through the frozen protocol. See P1-08. |
| P1-06 — reproducible gates | **RESOLVED.** The serializer is self-contained, and the exact 81 declaration/discovery set is enforceable. |

### 3.2 Review01A

| Review01A finding | Review01B determination |
|---|---|
| 01A-P1-01 — persisted/replay inconsistency | **NOT FULLY RESOLVED.** Receipt ordering, event heads, result membership, and outbox identity are repaired. Worker command-envelope ownership and the `cancelParsingAndDelete(.none)` result remain incomplete. |
| 01A-P1-02 — redacted inbox CHECK contradiction | **NOT RESOLVED.** The new no-CAS terminal branch still requires a hash/applied-time shape incompatible with authoritative v16 redaction. |
| 01A-P1-03 — C2 factory / exact test set | **RESOLVED.** Package-visible pure typed factories can be created in C2, and the gate compares exact declaration and discovery sets. |
| 01A-P1-04 — unreachable Understanding revision | **NOT FULLY RESOLVED.** Revision/reopen and later supersession are now reachable, but terminal failure after reopening a confirmed Goal has no coherent frozen transition. |

## 4. Findings

### P0

None.

### P1

#### P1-01 — `CoachTurnWorker.swift` exceeds the canonical P1-C production allowlist

Canonical P1 plan §5.1 permits `InputParsingWorker.swift` and the existing `DurableWorkSupervisor.swift`; it does not authorize a new `CoachTurnWorker.swift`. Revision 2 adds that production file while freezing the authorized supervisor read-only.

The two migration carriers have an explicit upstream verification justification. No equivalent authority revision exists for this additional production owner.

Required correction: either use an already authorized carrier and revise its exact ownership safely, or obtain a reviewed authority/allowlist revision that explicitly adds `CoachTurnWorker.swift`.

#### P1-02 — Worker-generated command envelopes and idempotency identities are not sealed

Every parse/Coach mutation requires a complete `CommandEnvelopeV1`, but both worker specifications own only a database/store, worker ID, clock, provider/parser closure, and sleep. The plan does not define for:

- parse result and parse failure;
- Coach question and Understanding proposal;
- Coach retry and terminal failure;

the exact command idempotency-key derivation, actor/device fields, correlation and causation sources, or replay identity per work attempt.

This cannot be left to implementation judgment: retry/failure attempts append durable receipts/events, and a crash must reproduce the same key for the same logical terminal operation without aliasing a later attempt.

Required correction: freeze a typed worker command-envelope factory for every worker-generated command, including exact key grammar and inputs, actor/device rules, correlation/causation, timestamp ownership, and crash/retry tests.

#### P1-03 — `recordQuestion` cannot obtain its required sealed `decisionKey`

`RecordCoachQuestionCommandV1` requires `decisionKey`, but the exact `CoachTurnWorkInputV1` does not contain one and `CoachTurnResultV1.question` returns only `prompt`, `recommendation`, and `reason`. The plan forbids the provider from returning additional authority/status metadata and defines no deterministic internal derivation.

The worker therefore cannot construct the exact command payload it is required to submit.

Required correction: place a validated `decisionKey` in the sealed work input, add it to the closed provider result with exact validation, or define another deterministic typed source and corresponding replay tests.

#### P1-04 — `cancelParsingAndDelete(.none)` has no constructible result/audit shape

The command payload admits `activeParsingBranch = none|expected(...)`. Its sole §5.5 result row nevertheless requires:

```text
refs = I,W
hashes include WI
versions include WV
counts include AT
```

When the sealed branch is `.none`, no durable-work identity, input hash, version, or attempt exists from which to populate `W/WI/WV/AT`. Unlike `completeDeletion`, this command has no separate no-active-work result row.

Required correction: either make `.expected` the only legal branch for `cancelParsingAndDelete`, or add an exact `.none` result/audit membership and tests. Also replace the undefined `withdrawUnconfirmed` event-head shorthand with the two exact revision enum cases.

#### P1-05 — The redacted inbox classifier rejects the authoritative deletion tombstone

Revision 2 requires a redacted inbox row to have `payloadJson='{}'` with its recomputed hash and `appliedAt=NULL`.

The governing v16 exact redaction trigger instead requires:

```text
NEW.payloadJson = '{}'
NEW.payloadHash = OLD.payloadHash
NEW.appliedAt IS OLD.appliedAt
```

Thus a legitimately redacted previously applied message preserves its pre-redaction evidence hash and may preserve non-null `appliedAt`. It satisfies the v14 redaction CHECK and the later authoritative deletion contract, but Revision 2 classifies it as `DomainInboxIntegrityError` rather than the promised redacted terminal.

Required correction: define the valid tombstone using preserved pre-redaction `payloadHash` and preserved `appliedAt`, validate the remaining exact retained fields, and cover received/applied/rejected pre-redaction origins.

#### P1-06 — Ordinary Input transitions can strand active parsing work

Capture always leaves the Input `captured` with queued `.inputParsing` work. Revision 2 simultaneously allows `captured` to enter assignment, ambiguity, coaching, archive, or Goal conversion without sealing an active-work branch for those commands.

Those commands neither cancel the work nor explicitly require that no active parse exists. The generic claim path does not inspect Input status. A later parser completion then loses the Input CAS, and the plan says a stale Input CAS changes nothing—leaving the work running/recoverable only to be adopted and fail again.

Required correction: for every transition reachable from `captured`, freeze either:

- an exact no-active-work precondition with a typed zero-write rejection; or
- an atomic active-work cancellation branch with corresponding result/audit membership.

Add queued/running/retryScheduled races for archive, assignment/ambiguity, coaching, and Goal conversion.

#### P1-07 — Terminal Coach failure after confirmed-session reopen is contradictory

`requestUnderstandingRevision(.reopenConfirmed)` leaves the Goal `ready`, preserves the confirmed Understanding head, moves the session to interviewing, and enqueues new Coach work.

The only terminal Coach failure contract says it fails the “still-clarifying Goal” and always emits Session then `goal.failed.v1`. The reopened path has a ready Goal, so the plan does not decide whether terminal failure:

- transitions `ready -> failed` while retaining or clearing the confirmed head; or
- fails only the revision session and leaves the already-valid Goal ready.

Both are materially different product/event/result contracts, and no named test covers this reachable branch.

Required correction: freeze the exact ready-Goal terminal behavior, projection/head mutations, event count/result shape, replay branch, and a deterministic/exhausted-failure test after `reopenConfirmed`.

#### P1-08 — The promised installation-ID critical section is impossible through the frozen protocol

`LocalCaptureIdentity.installationID()` is specified as performing read, generation, write, and reread under one lock. The proposed protocol exposes only separate `string(forKey:)` and `setString` calls, while the adapter locks each individual call. `LocalCaptureIdentity` is specified to hold only that store and the UUID factory.

No caller can hold the adapter’s private lock across the complete read-create-write-reread sequence. Concurrent callers can both observe absence and generate different UUIDs; at best one fails after the race, contradicting the “persists once” contract.

Required correction: expose one atomic get-or-create operation on the injected store, or give `LocalCaptureIdentity` one explicitly shared synchronization owner that encloses the entire sequence. Add concurrent first-use and copied-`Sendable`-value tests.

### P2

None.

## 5. Scope and feasibility determination

The following portions are otherwise feasible and correctly bounded:

- exact v14 append migration and GRDB transaction ownership;
- receipt-first replay after Camp archive;
- separate Understanding event-version ownership;
- event ID as the sole outbox identity;
- non-redacted inbox conflict CAS and commit-then-throw behavior;
- C2 package-visible pure typed replay factories;
- exact 81-entry declaration/discovery gate;
- Swift 6 claim handoff and renewal shutdown structure;
- Goal limited to `ready/abandoned/failed`, with activation, OutcomeContract, pause/resume, achieve, and Outcome propagation remaining in P1-D.

The eight P1 findings require new decisions about authority, persisted command identities, result shapes, lifecycle transitions, future-valid redaction, and concurrency ownership. Implementation cannot proceed without inventing those decisions.

## 6. Gate decision

- P0: 0
- P1: 8
- P2: 0
- Revision 2 approval gate: closed.
- P1-C implementation, Review02, acceptance, and P1-D planning remain closed.
- No `approved_plan_sha256` line is emitted.

## 7. Final verdict

verdict=CHANGES REQUIRED — 0 P0 / 8 P1 / 0 P2
