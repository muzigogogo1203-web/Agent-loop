# Review01C — AgentLoop P1-C Revision 3 Plan Review

> Date: 2026-08-25  
> Reviewer: Review01C, fresh responsibility-isolated read-only reviewer  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: frozen P1-C Revision 3 plan only

## 1. Review conduct

- Read every required authority, P1-B closeout artifact, rejected P1-C review, and the complete Revision 3 plan.
- Inspected only relevant current Swift 6, GRDB migration, DurableWork, Application-target, matrix-carrier, and test-runner source.
- Performed static/read-only inspection only.
- Did not edit or create files.
- Did not run tests, builds, migrations, matrix lanes, test discovery, applications, Claude, external actions, or memory.
- Performed no Git writes and preserved all pre-existing tracked and untracked worktree state.
- Executed the plan’s embedded outside-worktree serializer unchanged through stdin using the read-only fallback Git binary.

## 2. Frozen checkout, hashes, and manifest

### 2.1 Checkout and worktree

| Check | Start | End |
|---|---|---|
| CWD | `/Users/muzi/Agent-loop` | same |
| Branch | `codex/personal-ai-ranch-p0` | same |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` | same |
| Revision 3 plan SHA-256 | `3e5ac323210cab52820170069a758a5c6a5d613f84a09a59d23d305e38813824` | same |
| Expanded porcelain-v1 `-z` SHA-256 | `8c0705489ba9a15d2fc529e1d3f753d30b3f003d4623f5f70fb47bfb75bc24d6` | same |
| Dirty paths | 461 | 461 |
| Tracked worktree modifications | 63 | 63 |
| Untracked paths | 398 | 398 |
| Staged paths | 0 | 0 |

### 2.2 Authority and predecessor hashes

| Artifact | SHA-256 |
|---|---|
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| P1-B authoritative `verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |
| Rejected Review01 | `08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b` |
| Rejected Review01A | `cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a` |
| Rejected Review01B | `52391a6cf2612211f1a3612e5fb5379101cb2c90f644430c7fe04e5398a4e4de` |
| Revision 3 candidate | `3e5ac323210cab52820170069a758a5c6a5d613f84a09a59d23d305e38813824` |

The canonical P1 plan/stage headers retain historical R27/R28/A2 wording, but the higher-authority accepted master spec explicitly records P1-B Accepted and opens only P1-C decision-complete planning. That explicit route override and the accepted P1-B chain provide valid planning authority; no P0 authority conflict was found.

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

### 2.4 Accepted P1-B evidence

The accepted historical evidence remains:

```text
714 tests in 7 suites passed after 43.614 seconds
EXIT: 0
RESULT: PASSED
```

That evidence was inspected but not rerun. Acceptance23 and Review24 retain their accepted zero-P0/P1 conclusions and exact frozen hashes.

### 2.5 Exact v14 literal facts

Static extraction of stage spec §18.4 produced:

- 292 SQL lines.
- SHA-256 `a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531`.
- 10 tables.
- 13 named indexes.
- 4 append-only triggers.
- 27 explicit `CREATE` statements.

Tables:

```text
domain_command_receipt
domain_event
event_outbox
inbox_message
input_envelope
goal_controller
goal_mission_link
coach_session
coach_question
understanding_card_version
```

Named indexes:

```text
domain_event_correlation
domain_event_camp
domain_event_aggregate
event_outbox_pending
inbox_message_camp_state
input_envelope_status
input_envelope_camp
goal_controller_camp_status
goal_mission_link_goal
coach_session_goal
coach_question_one_open
coach_question_decision
understanding_goal
```

Triggers:

```text
domain_command_receipt_reject_update
domain_command_receipt_reject_delete
domain_event_reject_update
domain_event_reject_delete
```

The existing matrix carrier statically freezes the v13 checkpoint at `31 tables / 65 indexes / 4 triggers`. The v14 literal adds 10 tables, 13 named indexes, 16 SQLite automatic indexes, and 4 triggers, making the plan’s final `41 / 94 / 8` checkpoint arithmetically consistent. No migration was executed.

### 2.6 Embedded test inventory

Static extraction confirmed:

```text
entries=88
unique_specs=88
unique_names=88
duplicate_names=0
```

Distribution:

| Suite file | Tests |
|---|---:|
| `ControlContractMigrationTests.swift` | 9 |
| `DomainEventContractTests.swift` | 23 |
| `InputEnvelopeContractTests.swift` | 27 |
| `GoalCoachContractTests.swift` | 29 |
| Total | 88 |

The declaration/discovery gate compares exact sets and rejects extras and omissions. Test discovery itself was not run.

### 2.7 Outside serializer

The unchanged embedded serializer returned:

```text
dirty_total=461
allowlisted_present_count=13
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

The increase from the planning-entry `457 / 9` snapshot is exactly four allowlisted task artifacts: the candidate plan and rejected Reviews 01, 01A, and 01B. The 448-path protected outside set is unchanged.

## 3. Prior-finding resolution

### 3.1 Review01

| Finding | Review01C determination |
|---|---|
| P1-01 — creation/replay/vocabulary | **NOT FULLY RESOLVED.** Vocabulary, ID ownership, event ordering, result membership, and receipt-first graph replay are substantially frozen. `PreparedDomainCommandV1` now has mutually exclusive construction contracts, and confirmed-head authority remains inconsistent. See P1-01 and P1-08. |
| P1-02 — durable lifecycle | **NOT FULLY RESOLVED.** Latest-claim actor ownership is specified, but frozen adoption and timestamp behavior cannot provide the claimed recovery/backoff semantics. See P1-02 and P1-03. |
| P1-03 — Input Camp scope | **RESOLVED.** Audit Camp, projection Camp, parsing work, archive, assignment, and cross-Camp rules are exact. |
| P1-04 — safe JSON/inbox | **NOT FULLY RESOLVED.** Closed JSON vocabulary, hash verification, redaction, and conflict CAS are fixed. Typed handler rejection still lacks transaction isolation from partial handler writes. See P1-07. |
| P1-05 — Application seam | **NOT FULLY RESOLVED.** Controller ports and request mapping are exact, but installation identity is atomic only per adapter instance. See P1-09. |
| P1-06 — reproducible gates | **RESOLVED mechanically.** The binary serializer and exact 88-test manifest are executable and closed-set. The semantic tests required by the new findings are absent. |

### 3.2 Review01A

| Finding | Review01C determination |
|---|---|
| 01A-P1-01 — persisted/replay inconsistency | **NOT FULLY RESOLVED.** Receipt ordering, event heads, result membership, and outbox identity are fixed; prepared-command ownership is contradictory. See P1-01. |
| 01A-P1-02 — redacted inbox contradiction | **RESOLVED.** The authoritative preserved hash/applied-time tombstone is now classified before ordinary conflict processing. |
| 01A-P1-03 — C2 factory/exact test set | **RESOLVED.** Real package-visible typed factories are authorized in C2, and the exact declaration/discovery set rejects extras and omissions. |
| 01A-P1-04 — unreachable Understanding revision | **RESOLVED as to reachability.** All three revision branches and replacement confirmation are reachable. The separate confirmed-head carrier defect remains in P1-08. |

### 3.3 Review01B

| Finding | Review01C determination |
|---|---|
| 01B-P1-01 — production allowlist | **RESOLVED.** The sole Coach processor is confined to the authorized Supervisor carrier with a strip-to-preimage gate. |
| 01B-P1-02 — worker envelopes | **NOT FULLY RESOLVED.** Attempt keys and envelope fields are frozen, but same-owner recovery, live-lease adoption, and terminal time/backoff are incompatible with the frozen generic Store. See P1-02 and P1-03. |
| 01B-P1-03 — decision key | **RESOLVED.** The key is derived from `nextQuestionId`, sealed in work input, and excluded from provider authority. |
| 01B-P1-04 — impossible Input result | **RESOLVED.** Cancel-and-delete is `.expected`-only; complete deletion is `.none`-only; result membership is constructible. |
| 01B-P1-05 — redacted inbox | **RESOLVED.** Preserved old hash and nil/non-nil applied time match the future-authoritative tombstone. |
| 01B-P1-06 — stranded parsing work | **RESOLVED for ordinary transitions.** Every ordinary branch requires transactional absence of queued/running/retryScheduled parsing work. |
| 01B-P1-07 — reopened Coach failure | **NOT FULLY RESOLVED.** Session-only failure with a ready Goal is selected, but the plan’s “exact confirmed head hash” has no matching Goal/work/result carrier. See P1-08. |
| 01B-P1-08 — installation-ID atomicity | **NOT FULLY RESOLVED.** Copies sharing one store are safe; independently constructed live adapters guarding the same UserDefaults key are not. See P1-09. |

## 4. Findings

### P0

None.

### P1

#### P1-01 — `PreparedDomainCommandV1` has two mutually exclusive construction contracts

Plan §5.2 requires its validating factory to take the typed Camp-safe result and says the prepared command stores canonical result bytes/hash. Plan §6 instead says `PreparedDomainCommandV1` contains no result or allocated values and that `NewDomainCommandV1` receives the result only after projection/work mutation.

Those contracts cannot both be implemented. New results can contain a newly allocated work ID and post-mutation projection/work versions, so they cannot be supplied to the receipt-first prepared value without either allocating/mutating before receipt lookup or violating §6.

Required correction: freeze one exact prepared/new/replay type split. The prepared value must contain only pre-receipt immutable command authority; the result must be constructed after new-branch mutation and then validated/stored, or the execution algorithm must be revised consistently.

#### P1-02 — Frozen interrupted-work adoption is neither lease-fenced nor complete

The plan freezes `DurableWorkStore.swift` read-only while claiming renewal failure or parent cancellation leaves running work recoverable after lease expiry.

Current `adoptInterrupted` selects:

```sql
state = 'running' AND leaseOwner <> currentWorkerId
```

It does not test `leaseExpiresAt`. `claimNext` never claims a running row.

Consequences:

- A processor retaining the same worker ID cannot recover its own canceled/renewal-failed running work after lease expiry.
- A different processor can adopt another live worker’s unexpired claim.
- The named restart tests cover reopening/adoption, but not same-owner expiry or attempted adoption of a live foreign lease.

Required correction: either unfreeze and specify a lease-expired adoption rule that safely handles same-owner recovery, or freeze exclusive processor lifecycle/worker-ID rotation rules that make the current generic adopter safe. Add both same-owner-expired recovery and foreign-live-lease rejection tests.

#### P1-03 — Attempt-start time is incorrectly reused as terminal ledger time and retry origin

The worker envelope fixes `occurredAt = attempt.startedAt`, and §5.4 requires every generic DurableWork logical `now` to equal that value.

Current generic Store uses its `now` argument for:

- terminal `updatedAt` and `finishedAt`;
- attempt `endedAt`;
- terminal attempt-event time; and
- `retryScheduled.notBefore = now + [5,30,120]`.

Lease renewal can already have written a later `updatedAt`. A long-running attempt therefore terminalizes with time moving backward, and an attempt lasting longer than five seconds schedules its first retry in the past.

Required correction: separate stable command-envelope occurrence identity from terminal mutation time. Freeze the terminal clock’s ownership and replay behavior, then add long-attempt and post-renewal tests proving monotonic timestamps and backoff measured from failure/terminalization rather than claim start.

#### P1-04 — The command-by-command actor authorization matrix is absent

§5.4 says every command factory validates the actor allowed by §§7–8, but those sections do not provide an exact actor/type/ID/device rule for every command.

Missing or ambiguous cases include ordinary Input assignment/archive/coaching/conversion/deletion commands, parsing requeue/cancel, and `openCoachSession`. The plan defines exact worker and local-capture actors and several Coach/user operations, but that does not decide the remaining security boundary.

The 88-test manifest names only focused Coach question/answer and Coach-confirmation actor tests; it does not enforce all command permissions promised by the completion gate.

Required correction: add an exact command-by-command allowed actor-type, actor-ID, and device-nullability table, with rejection-before-SQL behavior and a closed positive/negative test matrix.

#### P1-05 — The plan does not enforce or select among multiple Coach sessions for one Goal

The v14 schema has only a non-unique `coach_session_goal` index. The unique Coach constraint is one open question per session, not one current session per Goal.

`openCoachSession` does not specify a transactional “no existing current session” check or an alternative multi-session rule. It also emits no Goal event or pointer mutation that could provide a Goal-level CAS owner. Meanwhile:

- `resumeSession(goalId:)` returns one session without a selection rule;
- abandon/fail uses a branch that represents at most one expected session; and
- restart promises exactly one restorable question/session path.

Two distinct open commands can therefore create an underdetermined state unless the implementer invents a hidden invariant.

Required correction: freeze either one-session-per-Goal or one-active-session-per-Goal, including the exact status set, transaction check, reopen policy, resume selection, and concurrent-open/replay/abandon tests.

#### P1-06 — Worker dependency interfaces and durable provider inputs are not decision-complete

The plan says the parsing worker owns an injected parser closure and the Coach processor owns an awaited Coach closure, but it never freezes:

- either closure’s exact Swift type;
- the parser’s durable input DTO;
- the Coach request/snapshot fields and historical-question ordering;
- initializer signatures and visibility;
- typed failure/cancellation surfaces; or
- which persisted snapshot is captured before the provider `await`.

These constructors must be package-visible to the separate test-suite target. Letting closures capture arbitrary external state would also contradict restart recovery from persisted rows rather than chat memory.

Required correction: specify exact `Sendable` request/result/failure types and package initializers for both processors, with snapshot construction and ordering derived solely from persisted state before the first provider/parser await.

#### P1-07 — Typed inbox rejection can commit partial handler writes

`applyInbox` inserts the new row as received, runs a synchronous mutation-capable handler, and converts a typed handler rejection into a durable rejected row within the same outer `pool.write`.

The plan does not require a savepoint or restrict the handler to validation-only behavior. If the handler performs one database mutation and then throws a typed rejection, catching that error inside the outer transaction permits the partial handler mutation to commit alongside the rejected inbox row. Unknown errors roll back, so the two error classes currently have materially different and unspecified mutation semantics.

Required correction: freeze a savepoint/rollback boundary or a prepare-then-apply handler contract. Add a test whose handler writes and then rejects, proving handler writes roll back while the intended rejection evidence persists.

#### P1-08 — The “confirmed Understanding ID/version/hash in the Goal head” has no exact carrier

The plan repeatedly requires preserving or copying the confirmed Understanding `ID/version/hash` in the Goal head.

The frozen v14 `goal_controller` has only:

```text
currentUnderstandingId
currentUnderstandingVersion
```

It has no hash column. `GoalHeadV1` likewise contains no Understanding hash. `CoachTurnWorkInputV1` carries an Understanding event version but not the confirmed content version/hash, and the ready-revision terminal-failure result omits Understanding ref/hash/version members.

The implementer must therefore choose between treating “Goal head hash” as inaccurate prose, adding unauthorized schema/payload fields, or inventing an unstated event-graph lookup rule.

Required correction: reconcile the contract with v14 explicitly. If the hash remains solely on the referenced Understanding row, freeze the exact joined/event-head validation algorithm and the sealed value against which it is checked; otherwise revise the authorized payload/result/schema and corresponding tests.

#### P1-09 — Installation-ID atomicity is per adapter instance, not per persisted key

`LockedUserDefaultsCaptureIdentityStore` owns one instance-local `NSLock`. Copies of one `LocalCaptureIdentity` share that store and are safe, matching the named test.

However, each default controller initialization evaluates `.live()` and constructs a separate adapter around `UserDefaults.standard`. Two independently created live controllers therefore use different locks for the same key and can both observe absence, generate different UUIDs, and overwrite each other.

Required correction: use a process-shared synchronization owner/store for the fixed production key, or another storage-level atomic primitive. Add a concurrent first-use test using two independently constructed live-equivalent adapters, not merely copies sharing one reference.

### P2

None.

## 5. Scope and feasibility determination

The following portions are correctly bounded and statically feasible:

- P1-B provides accepted entry evidence.
- The exact v14 append migration and GRDB-owned transaction are feasible.
- The 22-path product/test/matrix allowlist is bounded; the Supervisor marker block respects the upstream production allowlist.
- Receipt-first replay, caller-owned creation IDs, event/outbox identity, safe JSON vocabulary, Input active-work absence gates, and the selected ready-revision failure direction are substantially specified.
- The exact 88-test declaration/discovery mechanism is mechanically closed.
- Dirty-worktree preservation and protected-hash gates are reproducible.
- The P1-D fence excludes activation, pause/resume, achieve, OutcomeContract implementation, and v15 dependency.

The plan is not implementation-ready because the nine P1 findings require decisions affecting package APIs, command authority, durable recovery, time semantics, session ownership, transaction atomicity, persisted-head validation, and installation identity. The existing 88-test inventory also lacks the red-first cases needed to close those defects.

## 6. Gate decision

- P0: 0
- P1: 9
- P2: 0
- Revision 3 approval gate: closed.
- P1-C product/test/schema/migration implementation remains closed.
- Review02, P1-C acceptance, and P1-D planning remain closed.
- Frozen plan hash and protected outside manifest remained unchanged throughout this review.

## 7. Final verdict

verdict=CHANGES REQUIRED — 0 P0 / 9 P1 / 0 P2
