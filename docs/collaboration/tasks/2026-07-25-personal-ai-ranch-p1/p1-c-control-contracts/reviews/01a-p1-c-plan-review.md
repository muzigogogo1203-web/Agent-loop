# Review01A — AgentLoop P1-C revised plan review

## Review conduct

- Role: responsibility-isolated, read-only reviewer. I was neither plan author nor implementer.
- Checkout: `/Users/muzi/Agent-loop`
- Branch: `codex/personal-ai-ranch-p0`
- HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- Reviewed the complete revised plan, rejected Review01, governing authority, accepted P1-B Acceptance23/Review24, and relevant current Swift 6, GRDB, DurableWork, Application, migration-matrix, and test-discovery surfaces.
- No repository file was edited or created. `reviews/01a-p1-c-plan-review.md` remained absent.
- Did not run tests, builds, migrations, matrix lanes, App/package operations, Git writes, or external actions.
- All pre-existing tracked and untracked worktree changes were preserved.
- Apple Git emits sandbox-related stderr on this host, which the frozen serializer correctly treats as fatal. The exact embedded Ruby body was therefore executed unchanged with the available fallback Git 2.53.0 selected through `PATH`.

## Frozen hashes and manifest

### Checkout and worktree

| Check | Start/recheck | End |
|---|---:|---:|
| Branch | `codex/personal-ai-ranch-p0` | same |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` | same |
| Porcelain-v1 `-z` status SHA-256 | `ea0bf1087194fcc0284fa0cbe9fc2da572689ce444148b62f08a524bcc6eb5c2` | same |
| Dirty paths | 459 | 459 |
| Tracked worktree modifications | 63 | 63 |
| Untracked paths | 396 | 396 |
| Staged paths | 0 | 0 |

### Candidate, predecessor, and authority hashes

| Artifact | SHA-256 |
|---|---|
| P1-C candidate plan | `1b93589bdb8694fd85af255628c117772e4948648f039aa0a572182ba58b74fe` |
| Rejected Review01 | `08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b` |
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Claude–Codex protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Personal AI Ranch master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| Accepted P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| Accepted P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| P1-B authoritative `verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |

All values matched at the final recomputation.

### Protected current-source hashes

| Carrier | SHA-256 |
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

### Exact outside-manifest result

The serializer:

1. invokes `git ls-files --modified --others --exclude-standard -z`;
2. requires terminal NUL and empty Git stderr;
3. excludes only the exact allowlist;
4. sorts raw path bytes;
5. hashes path length/path, `lstat.mode`, node type, and either file length plus raw content SHA-256 or raw symlink target.

Final result:

```text
dirty_total=459
allowlisted_present_count=11
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

The plan’s planning-entry snapshot was 457 dirty paths and 9 present allowlisted paths. The review-time increase is exactly the materialized candidate plan and rejected Review01, both explicitly allowlisted. The outside count and manifest remained exactly frozen.

Static inspection also confirmed:

- the v14 SQL body is 292 lines with SHA-256 `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531`;
- it contains 27 relevant `CREATE` statements: 10 tables, 13 indexes, and 4 triggers;
- `test_specs` contains 78 unique listed names with no duplicate listed name.

These are static source checks, not execution evidence.

## Review01 P1-01 through P1-06 resolution

| Review01 finding | Verdict | Review01A determination |
|---|---|---|
| P1-01 — creation IDs, receipt-first replay, complete graph, persisted vocabulary/work keys | **NOT FULLY RESOLVED** | Stable creation IDs, enums, event ordering, work keys, and stored-graph validation are substantially specified. However, result/audit bytes remain underdetermined, Understanding event-version input is missing, current Camp validation still precedes receipt lookup, and outbox UUID ownership contradicts the frozen schema. See 01A-P1-01. |
| P1-02 — Input/Coach structured claim, renewal, adoption, failure and cancellation ownership | **RESOLVED** | `LatestControlWorkClaim`, task-group shutdown, renewed-claim handoff, typed failure branches, adoption filters, cancellation behavior, and transaction-local DurableWork terminal operations are specified and feasible against the current generic APIs. |
| P1-03 — complete audit/projection/work Camp rule | **RESOLVED** | The immutable Input audit Camp, projection Camp, parsing work Camp, assignment restriction, ambiguity behavior, archive rejection, and cross-Camp fail-closed rules form a complete ordinary P1-C ownership rule. |
| P1-04 — closed JSON, null/date decoding, exact inbox semantics | **NOT FULLY RESOLVED** | Closed DTO vocabulary, exact-key decoding, explicit null handling, finite dates, canonical bytes/hashes, CAS, and commit-then-throw are specified. The conflict transition is nevertheless impossible for a valid redacted inbox row. See 01A-P1-02. |
| P1-05 — Application port/DTO/initializer/trace/result/read seam | **RESOLVED** | The proposed package ports and DTOs fit the current Application target, actor isolation, capture helpers, defaulted initializer evolution, result tracing, reads, and local-identity injection without requiring a package dependency change. |
| P1-06 — binary serializer and executable source/hash/78-test gates | **NOT FULLY RESOLVED** | The outside serializer is self-contained and executable, and the hash/source declarations are materially stronger. C2 cannot legally construct the promised replay plan in its allowed implementation batch, and the purported exact-78 gate permits undeclared 79th tests. See 01A-P1-03. |

## Findings

### P0

None.

### P1

#### 01A-P1-01 — Persisted command/replay contract remains underdetermined and internally inconsistent

Four blocking gaps remain in §§5–8:

1. `CampSafeCommandResultV1` and `CampSafeAuditPayloadV1` freeze only their generic containers. The plan does not freeze each command’s exact `refs`, `hashes`, `versions`, `counts`, and `times` membership or ordering. Because caller order is preserved and these bytes/hashes are persisted and replayed, the implementer would have to invent the canonical result and event payload for every command.

2. `DomainCommandReplayPlanV1` requires the exact expected Understanding aggregate-event version before receipt lookup. Input commands provide an expected projection version, while Coach commands provide only expected Goal/session versions. `proposeUnderstanding`, `requestConfirmation`, and `confirmUnderstanding` append separate Understanding events even though request/confirm do not advance the content-version number. No sealed Understanding event-version field or deterministic derivation is defined. A replay factory therefore cannot construct the exact historical graph without consulting mutable current event state.

3. Execution step 1 validates Camp rows before step 2 performs receipt lookup, while §§5.2 and 7 reject archived event/audit Camps. This contradicts the stated receipt-first rule and the later claim that replay uses only the immutable receipt/graph before projection reads. An exact replay after its Camp is subsequently archived is not given one consistent outcome.

4. The plan says `DomainEventStore` owns random “event/outbox UUIDs” and invokes both factories. Frozen v14 `event_outbox` has no independent outbox ID column; `eventId` is its identity. The plan must either state that outbox identity is exactly the event ID and remove the extra UUID factory or change the frozen schema through a new reviewed authority revision.

Required correction: freeze every command/result/audit shape and array order; add a sealed Understanding event-version contract; move current Camp/archive checks onto the receipt-absent branch or explicitly redefine replay semantics; and reconcile outbox identity with the exact DDL.

#### 01A-P1-02 — Redacted inbox conflict cannot satisfy the frozen v14 CHECK constraints

Section 6 requires every well-formed same-key/different-identity-or-payload row to be CAS-updated to:

```text
state = rejected
errorCode = inbox_payload_conflict
redactedAt = preserved
```

The frozen v14 redacted-row shape instead requires a non-null `redactedAt` row to retain the redacted tombstone vocabulary, including `errorCode = camp_deleted`, deleted source identity, and redacted payload bytes. Preserving `redactedAt` while changing only the error code to `inbox_payload_conflict` violates the table CHECK and rolls the transaction back. It therefore cannot provide the promised durable conflict commit followed by a public throw.

Required correction: explicitly classify valid redacted rows as an integrity/redaction terminal case with no impossible conflict CAS, or revise the authorized schema/transition. Add a named test for a conflicting replay against a valid redacted row.

#### 01A-P1-03 — C2’s TDD boundary is not implementable, and the “exact 78” gate is not exact

C2 requires `executeCommand` and replay tests to become green after implementing only §§5–6. Those tests require a `DomainCommandReplayPlanV1`, but §6 states that callers cannot construct its builder and only typed factories in `InputGoalStore` and `CoachUnderstandingStore` may create it. Those stores belong to the later C3/C4 batches. The ordinary test-suite target therefore has no plan-authorized factory during C2.

Separately, the source gate verifies that the 78 listed functions each exist and are discovered once. It never counts all `@Test func` declarations in the four P1-C test files or compares the full discovered P1-C set against the manifest. An additional 79th declaration and discovery would pass while the script prints `source.test_declarations=78` and `source.test_discovery=78`.

Required correction: freeze a sealed §5–6 test fixture/factory or reorder the batches; then make the gate compare exact declaration and discovery sets so missing, duplicate, and extra P1-C tests all fail.

#### 01A-P1-04 — The promised Understanding edit/supersession lifecycle is unreachable

Section 8.3 requires content edits to create `version + 1`, withdraw an earlier unconfirmed version, and supersede a prior confirmed version only when a replacement is confirmed. The test inventory likewise requires:

- `understandingEditAlwaysCreatesNewVersion`;
- `confirmUnderstandingSupersedesPriorVersionAndMakesGoalReady`.

But the authorized store surface has no edit, reject, reopen, or new-turn command after an Understanding proposal:

- `proposeUnderstanding` terminalizes the only claimed coach work;
- `requestConfirmation` advances to ready-for-confirmation;
- `confirmUnderstanding` ends in confirmed/Goal-ready;
- no transition enqueues another coach turn from draft, awaiting-confirmation, or confirmed;
- P1-C forbids a Goal `ready -> clarifying` transition.

Consequently, a second Understanding content version cannot be reached through the planned APIs. The named tests would have to hand-seed an impossible state or invent an unplanned command.

Required correction: add and fully specify an authorized revision/reopen command, transition, actor, CAS versions, work enqueue, events, replay plan, and tests—or remove the unreachable edit/supersession promises from P1-C.

### P2

None.

## Feasibility and scope determination

The proposed v14 append migration, GRDB transaction-local store structure, Swift 6 task-group claim ownership, and defaulted Application initializer changes are otherwise feasible against current source surfaces. Existing DurableWork already supports `.inputParsing` and `.coach`, and its transaction-local enqueue/claim/renew/complete/retry/cancel/adopt operations can support the specified stores without changing generic ownership.

The allowlist is exact and bounded. The plan remains outside P1-D/E/F:

- no writable `active`, `paused`, or `achieved` Goal API;
- no direct `startNow -> ready` shortcut;
- no v15 Outcome query;
- no SwiftUI/product flow;
- no release, package, deployment, or external action.

The four P1 findings are contract and test-gate blockers inside P1-C, not requests to broaden into later stages.

## Gate decision

P1-C implementation is not authorized from this candidate. The plan must be revised, assigned a new frozen hash, and independently reviewed again. No BEGIN or later implementation gate is implied.

## Final verdict

- P0: 0
- P1: 4
- P2: 0

verdict=CHANGES REQUIRED — 0 P0 / 4 P1 / 0 P2
