# P1 Stage Spec / Plan Independent Review — Round 1

> Reviewer role: responsibility-separated fallback reviewer
>
> Date: 2026-07-25
>
> Reviewed:
>
> - root `AGENTS.md`
> - accepted master spec, especially §§24–29
> - P0 `current-state-evidence.md`
> - `p1-stage-spec.md`
> - `p1-plan.md`
> - `docs/collaboration/claude-codex-protocol.md`
> - the current migrations, planning, scheduling, rumination, candidate conversion,
>   execution backend, approval and related test call sites named by the plan

## Conclusion

**CHANGES REQUIRED**

P1-A1 is **not approved for implementation**. The proposal covers R-01…R-09 and
the master P1 topics at the intent level, keeps cloud / 牛哒 / full P2 UI out
of scope, and establishes useful A→F gates. However, the contracts below still
contain internal contradictions or require the implementer to choose
architecture, persistence and safety semantics. That conflicts with the
repository rule against unplanned decisions and with the master requirement that
all P1 open decisions be closed before entry.

Open Questions therefore cannot truthfully remain “无” until every P0 finding
below is resolved in both the stage spec and plan and this review is repeated.

## Findings

### P0-1 — `durable_work_attempt` cannot be both inserted at claim time and immutable with terminal fields

**Evidence**

- `p1-stage-spec.md:114-116` defines one append-only attempt row containing
  `startedAt`, `endedAt` and `outcome`, with UPDATE / DELETE abort triggers.
- `p1-stage-spec.md:129-138` requires the attempt insert to occur in the claim
  transaction.
- `p1-plan.md:123-148` carries both requirements into A1.

At claim time, `endedAt`, outcome and terminal error are unknowable. The row
cannot later be completed because UPDATE is forbidden. Inserting a second row is
also undefined because the attempt identity / uniqueness contract is absent.
Restart adoption additionally says it writes an interrupted attempt, but does
not define whether this closes the original attempt or creates a second
authoritative record.

**Impact**

The first P1 migration and the core crash ledger cannot be implemented without
inventing an event model. Any ad-hoc choice risks incomplete attempt history,
duplicate attempts, or bypassing the advertised append-only invariant.

**Required revision**

Choose and specify one model completely:

1. an immutable `durable_work_attempt_event` ledger with explicit
   `claimed|leaseRenewed|interrupted|succeeded|failed|canceled` event kinds and a
   separate current-attempt projection; or
2. a mutable attempt lifecycle row plus a separate append-only attempt-event
   table.

Specify PKs, `(workId, attempt)` uniqueness, the meaning of attempt numbering,
which transaction writes every start/end event, adoption behavior, and how
lease renewal, retry, shutdown, cancellation and stale completion close the
attempt. Add tests for one and only one terminal attempt outcome per claim.

### P0-2 — A1 pins a Runtime Profile ID, but the real provider resolver still re-reads the current default

**Evidence**

- `p1-stage-spec.md:142-148` and `p1-plan.md:136,149-178` require a persisted,
  non-drifting `runtimeProfileId`.
- Current `Orchestrator` stores
  `makeProvider: (model, companionId)` and calls it without a profile ID
  (`Sources/AgentLoopCore/Kernel/Orchestrator.swift:111-118,209-256`).
- Current App composition resolves the default profile at execution time
  (`Sources/AgentLoopApp/AppStore.swift:407-432,520-540`).
- Changing the required `startMission` contract also affects current call sites
  in `GoldenPathTests.swift`, `KnowledgeGoldenPathTests.swift` and
  `MultiCampTests.swift`, but A1's allowed test list at
  `p1-plan.md:96-117` omits them.

**Impact**

Following the current plan literally either preserves profile drift, breaks
compilation outside the allowed-file list, or forces the implementer to invent
a resolver API and compatibility overload. A fallback overload that silently
looks up the default would defeat the new invariant.

**Required revision**

Define an exact typed planning resolver contract, for example
`resolvePlanningProvider(profileId:model:) throws`, including:

- missing profile, unsupported CLI profile, missing credential, Keychain
  failure and unsupported model error codes;
- the point at which the profile record and model policy are validated;
- a strict rule that no fallback to the current default is permitted;
- test injection semantics that do not read real Keychain state.

Update the A1 allowed-file list for every production and test call site, or
define a decision-complete compatibility migration that still requires an
explicit profile ID. Do not leave this to an overload selected by the
implementer.

### P0-3 — Planning success is not specified as one atomic, stale-safe commit

**Evidence**

- The stage spec requires stale results to write neither accounting nor cards
  (`p1-stage-spec.md:145-148`).
- The plan requires `complete` to co-commit a business closure and work terminal
  (`p1-plan.md:147-174`), but only says to call a “transaction version” of
  `db.planMission`; it does not define usage and fallback mutation in that same
  transaction.
- Current code records planning tokens, fallback and cards through three
  separate database calls
  (`Sources/AgentLoopCore/Kernel/Orchestrator.swift:241-256`).

**Impact**

A lease can become stale after token accounting but before card creation, or a
later write can fail after an earlier write committed. This violates the
stale-result rule and leaves partially committed planning output.

**Required revision**

Specify one transaction-only `commitPlanningSuccess` operation whose
precondition is the claim's `id + version + leaseOwner`. In that transaction,
validate token arithmetic, record usage and fallback, create cards, roll up the
Mission, append all required events, close the attempt and terminalize the work.
Specify the corresponding atomic failure/cancel operations. The public methods
that currently open independent writes must not be callable from this path.
Add failure injection between every mutation and assert a full rollback.

### P0-4 — The durable-work state machine has transitions with no command, and cancellation is not atomically tied to projections

**Evidence**

- The state machine includes `retryScheduled -> queued` when due
  (`p1-stage-spec.md:120-138`).
- The fixed A1 API has no due-requeue command and does not say that
  `claimNext` performs this transition (`p1-plan.md:137-146`).
- `cancel(aggregateType:aggregateId:reason:now:)` has no business mutation
  closure, while the same documents require work terminal and target projection
  to commit together. A1 later says cancel must also fail the Mission, and A2
  says cancel must return Ingestion to queued.

**Impact**

An implementer must guess whether `claimNext` mutates two states, whether
scheduled retries can be claimed directly, and how cancellation avoids a
`canceled` work paired with a still-`planning` Mission or still-`ruminating`
Ingestion item.

**Required revision**

Define every legal store command and transaction:

- due-requeue / due-claim semantics and its CAS;
- terminal cancellation with a required business mutation closure;
- shutdown release versus user cancellation;
- adoption eligibility and whether lease expiry matters under the
  `StateDirectoryLock`;
- attempt closure for each transition.

Add projection-pair invariants and rollback tests for Mission and Ingestion.

### P0-5 — `InputEnvelope.parsing` is a critical in-flight state with no durable worker or recovery contract

**Evidence**

- `durable_work.kind` only permits planning, rumination, coach and memory
  promotion (`p1-stage-spec.md:89-112`).
- Input has `captured -> parsing -> ...` and retryable `parseFailed -> parsing`
  states (`p1-stage-spec.md:282-297`).
- The plan exposes `beginParsing` and `recordParseFailure`, but no parsing
  worker, lease, cancellation, finite retry or restart adoption
  (`p1-plan.md:502-518`).
- The master requires every critical asynchronous conversion to be durable and
  every in-flight state to reach a deterministic terminal
  (`master-spec.md:1064-1068,1122-1126`).

**Impact**

P1 could introduce the same permanent-state bug it is intended to eliminate:
an Input can remain in `parsing` after a crash. The P1 completion claim that
“all in-flight states” are covered would be false.

**Required revision**

Either add a durable `inputParsing` work kind with atomic start, adoption,
cancel, bounded retry, stale-response and terminal projection rules, or make
parsing a fully synchronous transaction and remove the durable `parsing` state.
Add crash/replay tests to P1-C and the P1 integration matrix.

### P0-6 — P1-C cannot complete its Goal state machine before P1-D creates Outcome Contracts

**Evidence**

- P1-C must implement and test
  `activate(outcomeContractRef:)`, and activation must validate an active
  OutcomeContract (`p1-plan.md:525-566`).
- The Outcome Contract store and `v15-p1-outcome-contracts` table are not
  created until P1-D (`p1-plan.md:568-622`).
- The stage spec also puts the contract reference in Goal while requiring the
  active contract to exist (`p1-stage-spec.md:301-322`).

**Impact**

P1-C's completion gate cannot be met against its allowed schema. The
implementer must invent a fake validator, create P1-D schema early, or weaken
the activation invariant. Any choice crosses a reviewed slice boundary.

**Required revision**

Move Goal activation and its active-state tests to P1-D, leaving P1-C with a
well-defined `ready` terminal for that slice; or move the minimal Outcome
Contract schema and store into P1-C. State the chosen migration dependency and
update both slice completion gates and the integration tests.

### P0-7 — The outcome / verification / acceptance contract cannot prove that all required verification passed

**Evidence**

- OutcomeContract stores verification requirements only as JSON
  (`p1-stage-spec.md:378-397`).
- `verification_record` has no requirement ID or requirement-version/hash field
  (`p1-stage-spec.md:425-457`).
- The plan offers `recordVerification` and `markDelivered`, but defines no
  deterministic reducer that maps records to every required criterion
  (`p1-plan.md:624-642`).
- `acceptance_policy_version` is only described in one sentence, without an
  exact field/state/constraint schema (`p1-stage-spec.md:459-478`).

**Impact**

One passing record could accidentally satisfy a multi-check contract, duplicate
records could be double-counted, and policy acceptance cannot be validated
without inventing policy fields. This violates the master’s fail-closed,
stable-version/hash and exact P1-decision requirements.

**Required revision**

Give each verification requirement a stable ID and canonical version/hash.
Reference it from each VerificationRecord. Define:

- the exact reducer for `verificationPending -> verified`;
- required-all / alternative-any semantics;
- duplicate and superseding records;
- blocked, failed, invalid and stale evidence behavior;
- who may invoke `markDelivered` and its preconditions.

Fully enumerate `acceptance_policy_version` fields, PK/FKs/checks, applicability,
validity, revocation and risk restrictions. Add contract tests with multiple
requirements, duplicate records, one invalidated record and policy expiry.

### P0-8 — Downstream invalidation has no complete state-transition matrix

**Evidence**

- Goal permits only
  `clarifying -> ready -> active -> paused -> active`,
  `active -> achieved|abandoned|failed`, and `ready -> abandoned`
  (`p1-stage-spec.md:312-322`).
- Outcome can move from accepted to invalidated/revoked and metric credit is
  reversed (`p1-stage-spec.md:412-423,481-489`).
- Acceptance is required to update Goal/Mission projections, but the exact
  resulting states are not specified (`p1-stage-spec.md:474-479`;
  `p1-plan.md:644-655`).

**Impact**

Revoking or invalidating the evidence for an achieved Goal has no legal Goal
transition. Clarifying and paused Goals also lack complete cancel/fail paths.
The stores would need to invent whether to reopen, fail or leave a now-false
“achieved” projection.

**Required revision**

Add a command-by-command transition table for Goal, Mission, Outcome,
Verification, Acceptance, metric credit, Memory and Growth. It must cover
return, revocation, verification invalidation, dependency deletion and a new
Outcome version. Define atomic event/projection writes and legal terminal exits
from clarifying, ready, active, paused and achieved.

### P0-9 — ApprovalGrant cannot represent its promised scope, and crash recovery around external effects is undefined

**Evidence**

- The grant schema has only one `scopeType/scopeId` plus opaque
  `allowanceJson`, but the rule requires a composite Card + tool + input-hash
  scope (`p1-stage-spec.md:491-520`).
- The plan requires wrong tool/hash to fail closed without defining where the
  approved tool/hash is stored (`p1-plan.md:666-688`).
- `claimed|consumed|released` does not distinguish a crash before an action
  starts from a crash after a non-transactional external action starts or
  succeeds.

**Impact**

Grant matching would depend on an implementer-designed opaque JSON schema, and
recovery could either replay a real side effect or permanently consume a grant
without knowing what happened. This is a security and idempotency boundary.

**Required revision**

Define a versioned canonical scope payload, or explicit `cardId`, `toolId` and
`approvedInputHash` fields with DB constraints. Define an external-operation
receipt / reconciliation state machine, including crash-unknown. State which
tools are replay-safe, which require adapter idempotency, and which must stop
for user resolution. Add crash tests before action start, after start and after
external success but before local receipt commit.

### P0-10 — The unified engine request conflicts with current Run ownership and DB mutation

**Evidence**

- The new request requires a caller-provided `runId`, and terminal is an engine
  event (`p1-stage-spec.md:619-658`; `p1-plan.md:830-840`).
- Current ModelLoop and CLI backends both generate a new Run ID and call
  `db.startRun` internally
  (`Sources/AgentLoopCore/Loop/CardRunner.swift:36-60`;
  `Sources/AgentLoopCore/Loop/CliProcessBackend.swift:281-305`).
- Current Orchestrator selects and constructs those DB-mutating backends
  directly (`Sources/AgentLoopCore/Kernel/Orchestrator.swift:1308-1336`).

**Impact**

A wrapper adapter cannot satisfy the new protocol without choosing who owns
Run creation, Card transition, board terminal, usage accounting and terminal
DB commit. Leaving both layers authoritative risks duplicate Runs and double
terminalization; leaving the current backends authoritative makes the request's
`runId` and kernel terminal contract false.

**Required revision**

Choose one execution ownership model. The recommended model is:

- kernel transaction allocates execution + Run and transitions the Card;
- adapter receives the exact IDs and has no authority to create/finish Run or
  change Card truth;
- board tools return a terminal receipt keyed to that execution;
- kernel validates exactly-once terminal sequence and atomically commits
  Run/Card/usage/events.

If the project chooses adapter-owned Runs instead, remove caller-owned `runId`
and explicitly document/test the alternative. Update the P1-F allowed files for
all board/tool/database call sites required by the chosen model.

### P0-11 — Schedule failure replay is terminally ambiguous

**Evidence**

- `schedule_fire` is unique by `(scheduleId, slotKey)`.
- Validation failure creates a terminal `failed` fire but does not advance
  `lastFiredAt` (`p1-stage-spec.md:165-186`).
- The plan says a duplicate slot returns the existing fire, but defines no
  retry, repair or re-arm transition (`p1-plan.md:282-310`).

**Impact**

After configuration is fixed, the same still-due slot can only return its old
failed row; alternatively the scheduler may retry it forever without ever
launching. The unused `intended` state further obscures the intended crash
boundary. R-04 is not decision-complete.

**Required revision**

Specify whether a failed slot is permanently missed or retryable. If retryable,
define bounded attempts, `notBefore`, lease/adoption, idempotent transition to
started and the exact `lastFiredAt` rule. If permanently missed, advance a
separate evaluated-slot cursor so the scheduler does not spin and require an
explicit user “replay missed slot” command with a new idempotency key. Remove
the unused `intended` state or define when it is durably visible.

### P0-12 — Several referenced schemas and file scopes are not concrete enough for a no-guess implementation

**Evidence**

- `goal_mission_link` is required but has no schema contract
  (`p1-stage-spec.md:320-322`).
- Most v13–v17 tables list names/fields but omit concrete SQL types,
  nullability, PK/FK/unique/check/index/delete behavior and backfill defaults;
  `acceptance_policy_version` is the clearest example.
- P1-E says to replace Schedule authorization reads but does not allow
  `MissionScheduler.swift` or `ScheduleStore.swift`
  (`p1-plan.md:698-747`).
- P1-E and P1-F permit unspecified “directly related” App/Application files
  (`p1-plan.md:714-719,792-816`) rather than exact files.

**Impact**

Migration behavior, deletion propagation, query shape and implementation scope
would be decided during coding. This contradicts the plan's own claim that A1
can run without architecture guesses and the collaboration protocol's
decision-complete requirement.

**Required revision**

For every new table, provide a schema table with exact type, nullability,
default, PK, FK target and delete/update behavior, unique/check constraints and
indexes. Define every referenced link/outbox/invalidation table. Replace all
wildcard file descriptions with exact paths per slice, including all compile
affected call sites and tests.

## P1 findings

### P1-1 — Domain-event idempotency needs a multi-aggregate command rule

`domain_event.idempotencyKey` is globally unique, while Acceptance and other
commands update several aggregates and write plural events. The documents do
not say whether child event keys are derived from the command key or whether
one event is the sole command receipt. Define canonical derivation and conflict
checking so retries cannot partially append a second aggregate's event.

### P1-2 — Migration verification should run at each introducing slice, not only at P1-F

The final migration matrix is good, but delaying the full predecessor matrix to
P1-F makes earlier bad migrations expensive to unwind. Each slice should run
fresh plus every immediately supported predecessor to that slice, including
foreign-key and integrity checks; P1-F should repeat the aggregate matrix.

## Coverage and scope audit

| Requirement | Planned coverage | Review |
|---|---|---|
| R-01 planning | P1-A1 | Covered in intent; blocked by P0-1…P0-4 |
| R-02 rumination | P1-A2 | Covered in intent; cancellation / attempt fix must carry forward |
| R-03 candidate conversion | P1-A3 | Covered in intent; atomic command direction is correct |
| R-04 schedule claim | P1-A4 | Covered in intent; blocked by P0-11 |
| R-05 App `try?` | P1-B | Inventory + workflow state is the right boundary |
| R-06 MCP / knowledge degradation | P1-B | Required vs optionalApproved is explicitly separated |
| R-07 AppStore concentration | P1-B | Scoped consumer extraction avoids a broad rewrite |
| R-08 placeholder outcome/growth | P1-D/E/F | Covered in intent; blocked by P0-7/P0-8 |
| R-09 navigation before closeout | P1-D | Durable-first navigation order is explicit |
| Master P1 §29 decisions | P1-C…F | Topics are present, but exactness gaps above mean they are not all closed |
| P2+/cloud/牛哒 scope | Non-goals and slice limits | No material P2 UI, cloud sync or 牛哒 implementation leak found |
| Swift 6 / GRDB / security | Actor/store split, replay tests, secret-free errors | Direction is sound; exact transaction and schema fixes remain required |

## Approval gate

- P0 findings: **12**
- P1 findings: **2**
- P2 findings: **0**
- Decision: **CHANGES REQUIRED**
- P1-A1 implementation authorized: **No**

After the planner revises both documents, the next reviewer must verify every
finding against the revised text and re-run the targeted source/call-site audit.
