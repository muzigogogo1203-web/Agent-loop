# P1 Stage Spec / Plan Independent Review — Round 3

> Reviewer role: responsibility-separated fallback reviewer
>
> Date: 2026-07-25
>
> This is the protocol's third and final P1 plan-review round.

## Frozen review target

The reviewed inputs were frozen and independently hash-checked before and after
the review:

| File | SHA-256 |
|---|---|
| `p1-stage-spec.md` | `62511ed7915bc5253e8bb3f11589856b6ec01f98e2e4b619ce47f1975192fdea` |
| `p1-plan.md` | `b9c744dcfd2f5318923fc4dacef7332fd9a3c9c7bbc5aa241afda83d4eed6ac9` |

Also reviewed:

- accepted master spec, especially `§7.1`, `§25`, `§27` and `§29`;
- P0 `spec.md`, `plan.md` and the P0 completion/phase gates;
- `reviews/01-p1-plan-review.md`;
- `reviews/02-p1-plan-review.md`;
- current runtime-profile/model-catalog, Keychain, BoardTools, Camp, artifact,
  Run/Card and test-runner source facts needed to validate the plans.

## Conclusion

**CHANGES REQUIRED**

P1-A1a is **not authorized for implementation**. No P1 product-code
implementation may begin.

The third revision closes many difficult contracts, including exact
Runtime-Profile resolution, bounded shutdown, checked planning usage,
CanonicalJSONV1, `DurableWorkFailure`, most A1a Store signatures, the Grant
dispatch-intent boundary, full terminal proposals and Input tombstone
status/retention equivalence. It still has four P0 and seven P1 findings below.

This is Round 3. `p1-plan.md:1639-1640` requires escalation to the ranch owner
when P0/P1 findings remain after three review rounds. Therefore the documents
must not be silently revised into a fourth automatic review cycle. The P0/P1
phase gate remains closed, the implementation Goal must not enter P1-A1a, and
the unresolved product/safety decisions must be escalated to the user.

## Round 2 finding disposition

| Round 2 finding | Round 3 result |
|---|---|
| R2-P0-1 exact-profile resolver | **Closed.** The per-kind catalog, credential, endpoint and typed-error table is exact in `p1-stage-spec.md:485-514`; plan wiring/tests are at `p1-plan.md:416-429,528-540`. Existing API manual-model and OAuth account-ID behavior is covered. |
| R2-P0-2 bounded shutdown | **Closed.** Lifecycle, generation invalidation, bounded wait and no-post-shutdown-commit gate are fixed in `p1-stage-spec.md:231-245` and `p1-plan.md:455-497,552-555`. |
| R2-P0-3 Grant receipt boundary | **Partially closed.** `dispatchIntent` is now correctly separate from real `adapterAccepted`, but crash-unknown no-effect authority still conflicts; see R3-P0-2. |
| R2-P0-4 kernel terminal/recovery | **Partially closed.** Full payload, request hash, staging, ask-user ownership and a recovery table now exist. Dispatch causality and deterministic proposal/artifact recovery remain blocked by R3-P0-3 and R3-P0-4; exact identity gaps remain in R3-P1-3…5. |
| R2-P0-5 Camp lifecycle | **Not closed.** The revision substitutes reversible archive for the master-required deletion-chain decision without user authorization, and the archive boundary itself is incomplete; see R3-P0-1. |
| R2-P1-1 Store API types/ownership | **Closed for the listed methods.** Ownership, isolation, return values, mutation closure and transaction helpers are fixed at `p1-plan.md:150-273`. A separate persisted-output gap remains in R3-P1-1. |
| R2-P1-2 `cancelActive` | **Closed.** Same-transaction lookup/CAS and `.noActiveWork` are fixed at `p1-stage-spec.md:222-225` and `p1-plan.md:308-315`. |
| R2-P1-3 caller input hash | **Closed.** Canonical recomputation, lowercase SHA-256, mismatch rejection and DDL checks are fixed at `p1-stage-spec.md:165-172,1343-1347` and `p1-plan.md:282-288,335-338`. |
| R2-P1-4 retry tests/task artifacts | **Closed.** Backoff/exhaustion/overflow tests are at `p1-plan.md:345-360`; task path and role-owned artifacts are exact at `p1-plan.md:113-123`. |
| R2-P1-5 checked two-turn usage | **Closed.** Checked accumulation is fixed in `p1-stage-spec.md:522-525` and `p1-plan.md:448-453,543`. |
| R2-P1-6 Outcome transitions/policy | **Partially closed.** Policy override bits are gone and hard guards are explicit. The allegedly unique Outcome table still has out-of-table transitions and command-name drift; see R3-P1-6. |
| R2-P1-7 Input schema | **Partially closed.** `parseAttempt` is removed and status/retention tombstones are equivalent. Payload cardinality and tombstone retained fields still conflict; see R3-P1-7. |

## Supplemental A1a disposition

The post-Round-2 A1a questions were rechecked against the frozen hashes:

- **Canonical JSON conflict — closed.** `p1-stage-spec.md:68-152` defines one
  strict `AgentLoopCanonicalJSON.v1`; typed and raw inputs converge on one local
  parser/serializer. A1a owns the implementation and golden tests in
  `p1-plan.md:103-135,317-344`.
- **`DurableWorkFailure` type — closed.** Disposition, fields, validation and
  custom Codable behavior are complete in `p1-stage-spec.md:259-481` and
  `p1-plan.md:136-184,274-281,339-344`.
- **A1a task path and artifact ownership — closed.** The single path and
  planner/implementer/reviewer/acceptance write ownership are explicit at
  `p1-plan.md:113-123`.
- **Normative SQL syntax — structurally valid.** All seven SQL blocks were
  executed against an in-memory SQLite database with the predecessor tables
  stubbed; `PRAGMA foreign_key_check` returned no rows and
  `PRAGMA integrity_check` returned `ok`. This does not cure the semantic
  findings below.

## P0 findings

### R3-P0-1 — Camp deletion was deferred in conflict with the accepted master, and archive is not a complete substitute

**Evidence**

- The accepted master requires the P1 data contract to define the deletion
  chain after a Camp is deleted
  (`personal-ai-ranch-master-spec.md:271-273`).
- Master §29 lists “营地删除后的精确生命周期” as a P1 open decision
  (`personal-ai-ranch-master-spec.md:1356-1366`) and says P1 decisions must be
  resolved before entering P1. Deferral is allowed only when the user explicitly
  approves it and it does not affect the stage gate/safety boundary
  (`personal-ai-ranch-master-spec.md:1344-1346`).
- The frozen stage spec instead removes `deleteCamp` and irreversible
  tombstones and unilaterally leaves them to a future privacy/retention spec
  (`p1-stage-spec.md:1068-1070`). The plan repeats that P1 has no
  delete/tombstone (`p1-plan.md:1274-1286`).
- Even as an archive-only contract, quiescence only counts schedules, selected
  Mission states, durable work, selected Inputs/Goals and Coach sessions
  (`p1-stage-spec.md:1071-1075`). It omits unresolved
  `approval_grant_use` and pending `engine_terminal_proposal` facts.
- The stage says every new dispatch/write/auth store must reject archived Camps
  (`p1-stage-spec.md:1076-1081`), but the P1-E plan only names residency,
  bridge, memory, Goal/Input/Mission and schedule entry points
  (`p1-plan.md:1282-1286`). P1-E's allowed files
  (`p1-plan.md:1207-1242`) exclude the earlier
  `InputGoalStore`, `CoachUnderstandingStore`, `ApprovalGrantStore`,
  `ToolExecutor` and later engine store that own other affected writes.

**Impact**

The plan falsely claims that all master §29 P1 decisions are resolved. A planner
cannot silently replace a user-accepted deletion requirement with a future
phase. Separately, a Camp can be archived while an external effect is
crash-unknown, or earlier/later stores can continue Camp-scoped writes because
the exact slice cannot edit them. This is both a master phase-gate violation and
an external-effect isolation risk.

**Required decision**

Escalate to the user. The user must either:

1. require P1 to define the deletion/tombstone chain (implementation/UI may
   still be staged separately), including residency, bridges, Inputs, Memory,
   work, external operations, engine proposals and retained audit facts; or
2. explicitly approve deferral and authorize a corresponding accepted-master
   revision that explains why it does not weaken the P1 completion/safety gate.

Independently, enumerate every Camp-scoped mutable/in-flight projection in the
archive quiescence/guard matrix and place each owning store/controller/test in
the slice where it can actually be changed.

### R3-P0-2 — A crash-unknown Grant has two conflicting no-effect authorities

**Evidence**

- For a non-replayable operation, the spec says the user resolves
  `crashUnknown` as `succeeded` or `noEffect`
  (`p1-stage-spec.md:1007-1014`).
- The next rule says only the adapter may prove `noEffect` and permit release
  and `usedCount` refund (`p1-stage-spec.md:1015-1017`).
- The DDL permits both a `userResolved` phase and `noEffect` result
  (`p1-stage-spec.md:2125-2138`).
- The plan only says that an “明确 noEffect receipt” may refund the use; it does
  not select user or adapter authority (`p1-plan.md:1151-1156`).

**Impact**

The implementer must choose whether a user's crash resolution can refund a
single-use Grant or whether only an adapter reconciliation can. The wrong choice
either allows a possibly executed non-replayable effect to be authorized again
or leaves a user-resolved no-effect operation permanently consumed. This is the
same external-effect safety boundary the revision was meant to make exact.

**Required revision**

Choose one authority. If user adjudication is allowed, define its required
actor, evidence/attestation, receipt phase/result and exact
`crashUnknown -> released|succeeded` transaction. If only an adapter may prove
no effect, remove `noEffect` from the user-resolution path and define what a user
can do when the adapter can never reconcile. Add both replay and conflicting
resolution tests.

### R3-P0-3 — Engine recovery uses `dispatchState` as a fact without defining the durable call boundary

**Evidence**

- `engine_execution.dispatchState` has
  `prepared|started|sessionBound|terminalProposed|terminal`
  (`p1-stage-spec.md:2316-2319`).
- Recovery treats `prepared` as proof that the adapter was never called and
  safely starts it, while a non-replayable `started` execution becomes
  `external_effect_unknown` (`p1-stage-spec.md:1229-1241`).
- The ownership sequence only says begin creates the execution and then the
  adapter receives the request (`p1-stage-spec.md:1204-1208`).
- The plan exposes `beginEngineExecution`, `acceptEngineEvent` and terminal
  commands, but no command that atomically changes
  `prepared -> started` immediately before the non-transactional
  `adapter.execute` call (`p1-plan.md:1402-1427`).

**Impact**

If `started` is inferred from the first adapter event, a process can crash after
calling/spawning an adapter but before that event is persisted. Recovery then
misreads `prepared` as “never called” and replays a non-replayable execution.
If an implementer writes `started` at some other point, the crash window is
still their unreviewed decision.

**Required revision**

Add an exact CAS command such as `markEngineDispatchStarted`, committed before
the adapter call. Define the resulting ambiguous window: a non-replayable crash
after that commit must block/crash-unknown even when the call may not have
started; replay-safe/idempotency-keyed engines reuse the same execution key.
Test crashes immediately before the CAS, after the CAS, after the real call but
before the first event, and after session binding.

### R3-P0-4 — A pending terminal proposal can become permanently unfinishable or lose its prepared blob

**Evidence**

- The kernel records a unique pending terminal proposal before artifact
  preparation and workspace path/size/hash verification
  (`p1-stage-spec.md:1170-1195`).
- Recovery of a pending proposal only repeats prepare and commit
  (`p1-stage-spec.md:1200-1202,1229-1234`).
- `engine_terminal_proposal.executionId` is unique and the row has an `invalid`
  state, but no invalidation/terminalization command is defined
  (`p1-stage-spec.md:2342-2365`).
- The plan/tests cover crashes around prepare, but not deterministic path escape,
  missing source, size/hash mismatch or corrupt immutable blob
  (`p1-plan.md:1419-1438,1525-1540`).
- GC may delete any blob older than 24 hours that is not yet referenced by an
  artifact row (`p1-stage-spec.md:1200-1202`). A pending proposal intentionally
  has no artifact row until terminal commit, so its successfully prepared blob
  is not protected by that live-set rule.

**Impact**

A malformed completed proposal can remain pending forever: prepare will
deterministically fail on every restart, a second failed/blocked proposal cannot
be inserted for the same execution, and the plan does not say how `invalid`
closes Run/Card/Mission. Separately, a long-offline restart can garbage-collect
the only verified prepared blob required by a pending proposal; recovery then
depends on the mutable workspace source still existing. Both violate the P1
all-in-flight deterministic-terminal gate (`p1-stage-spec.md:2585-2603`).

**Required revision**

Define a single deterministic path for prepare/validation failure—for example,
atomically mark the proposal invalid and use a kernel-owned
`engine_protocol_error` terminal transaction without requiring a second
proposal. Define replay of that failure. Treat hashes referenced by every
pending proposal as live GC roots until the proposal is committed/invalidated,
or persist an equivalent staging reference. Add deterministic-failure,
24-hour-pending, missing-workspace-source and corrupted-blob recovery tests.

## P1 findings

### R3-P1-1 — A1a does not define canonical handling for `complete.outputJson`

Global rules require work/persisted canonical JSON to use
`CanonicalJSONV1` (`p1-stage-spec.md:75-79,1304-1310`), and the v12 table stores
`outputJson` (`p1-stage-spec.md:1343-1349`). Yet
`DurableWorkStore.complete` accepts an arbitrary `String?`
(`p1-plan.md:228-231`), while A1a's validation rules and tests only cover
enqueue input and failure usage (`p1-plan.md:274-315,317-360`).

Specify whether non-nil output may be any JSON value or must be an object,
whether the Store canonicalizes or requires byte equality, the typed error, and
whether rejection occurs before the business mutation with zero writes. Add
alternate-representation, invalid JSON and mutation-rollback tests.

### R3-P1-2 — Nullable receipt hashes defeat the declared SQL uniqueness rule

`external_operation_receipt.receiptHash` is nullable, while uniqueness is
`(grantUseId, phase, receiptHash)`
(`p1-stage-spec.md:2125-2138`). SQLite permits multiple rows whose unique-key
component is `NULL`, so duplicate `dispatchIntent`, `adapterAccepted` or
user-resolution receipts are possible at the schema boundary.

Add a non-null receipt idempotency key/ordinal, phase-specific partial unique
indexes, or an equally exact rule that permits repeated reconciliation attempts
while making one-shot phases exactly once. Add same-command replay and
concurrent duplicate tests.

### R3-P1-3 — `waitingForUser` is simultaneously a blocked subtype and a terminal kind

The engine terminal set is declared to be exactly
`completed|blocked|failed|canceled` (`p1-stage-spec.md:1157-1168`), and
waiting-for-user is called a blocked subtype
(`p1-stage-spec.md:1177-1179`). The DDL nevertheless adds
`waitingForUser` as a fifth `terminalKind`
(`p1-stage-spec.md:2342-2353`), and the plan tells `ask_user` to form that kind
(`p1-plan.md:1428-1432`).

Choose either `blocked` plus a typed subtype in payload, or a five-kind proposal
taxonomy with an explicit mapping to the four engine terminal outcomes. Align
event enums, request answering, hashes, DDL and conformance tests.

### R3-P1-4 — Terminal replay identity does not say whether the artifact manifest is included

The completed proposal contains both handoff payload and artifact facts
(`p1-stage-spec.md:1170-1176`), but replay compares a singular terminal
idempotency/hash (`p1-stage-spec.md:1182-1186`;
`p1-plan.md:1433-1435`). DDL stores separate `payloadHash` and
`artifactManifestHash` (`p1-stage-spec.md:2348-2354`).

Define one canonical whole-proposal hash, or require exact comparison of terminal
kind, payload hash and manifest hash. A replay with the same handoff but a
different source path/byte count/artifact hash must be a deterministic conflict.
Add a manifest-only drift test.

### R3-P1-5 — `requestHash` does not validate `contextHash` against `contextJson`

The request accepts both `contextJson` and `contextHash`
(`p1-stage-spec.md:1137-1149`). The Store hashes the enclosing request, which
only proves that the two caller-provided values replay together; it never says
to canonicalize `contextJson`, recompute its SHA-256 and compare it with
`contextHash` (`p1-stage-spec.md:1151-1155`;
`p1-plan.md:1413-1417`; DDL at `p1-stage-spec.md:2311-2313`).

Make context validation a precondition of begin, use `CanonicalJSONV1`, and add
noncanonical-context and mismatched-context-hash zero-write tests.

### R3-P1-6 — The “unique authoritative” Outcome state table still has transitions outside the table

The spec says its table is the only authoritative Outcome state machine
(`p1-stage-spec.md:847-858`), but `invalidateVerification` transitions are
defined only in prose immediately after it
(`p1-stage-spec.md:860-864`) and again in §19
(`p1-stage-spec.md:2480-2486`). The plan then requires rejection of every
from/to pair absent from the table (`p1-plan.md:1171-1172`), while naming the
table's `returnOutcome` command `returnForRework`
(`p1-plan.md:1082-1089`).

Put every invalidation transition directly in the authoritative table and use
one command name throughout stage spec, plan, store and tests.

### R3-P1-7 — Input payload cardinality and tombstone retention still disagree

The prose permits `inlineText` or `payloadRef` with “at least one”
(`p1-stage-spec.md:679-687`), while normative DDL requires exactly one for every
non-tombstone row (`p1-stage-spec.md:1620-1626`). The deletion rule says only
ID/hash/time/deletion fact/non-sensitive provenance remain
(`p1-stage-spec.md:718-726`), but DDL still requires or permits a tombstone to
retain candidate Camp IDs, Camp ID, intent, privacy, parent, error and source
metadata (`p1-stage-spec.md:1584-1628`) without classifying or clearing them.

Choose XOR versus dual carriers. Then enumerate the exact post-deletion value of
every column, including which provenance is retained, nulled or redacted, and
add direct store/DDL tests for forbidden retained fields.

## Closed areas and regression check

No new P0/P1 was found in:

- attempt lifecycle plus append-only attempt-event ledger;
- `commitPlanningSuccess` transaction composition;
- due claim, latest-claim CAS, projection-atomic cancellation and adoption;
- durable `inputParsing` recovery;
- P1-C/P1-D Goal/Outcome dependency ordering;
- verification requirement/head/reducer mechanics and policy hard guards;
- schedule missed-slot cursor and explicit replay;
- exact profile/model call-site migration;
- bounded supervisor shutdown generation gate;
- checked two-turn planning usage;
- v12–v17 SQL syntax and per-slice predecessor matrices;
- CLI exact-session preflight/continuation rules;
- CanonicalJSONV1 and `DurableWorkFailure` themselves.

## Final phase gate

- P0 findings: **4**
- P1 findings: **7**
- Decision: **CHANGES REQUIRED**
- P1-A1a implementable now: **No**
- P1 implementation authorized: **No**
- P0 acceptance may claim P1 review passed: **No**
- `Open Questions` may remain “无”: **No**
- Review-round limit: **Reached (3/3)**
- Required next action: **Stop and escalate the unresolved decisions to the
  user. Do not start P1-A1a and do not silently launch a fourth review cycle.**
