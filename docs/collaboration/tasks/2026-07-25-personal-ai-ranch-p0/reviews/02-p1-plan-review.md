# P1 Stage Spec / Plan Independent Review — Round 2

> Reviewer role: responsibility-separated fallback reviewer
>
> Date: 2026-07-25
>
> Reviewed:
>
> - root `AGENTS.md`
> - accepted master spec, especially §§24–29
> - P0 `current-state-evidence.md`
> - revised `p1-stage-spec.md`
> - revised `p1-plan.md`
> - `reviews/01-p1-plan-review.md`
> - the current runtime-profile/model-catalog, planning usage, BoardTools,
>   Camp, approval, execution and test call sites implicated by the revision

## Conclusion

**CHANGES REQUIRED**

P1-A1a is **not approved for implementation**.

The revision materially improves the proposal. In particular, it now has a
mutable attempt lifecycle plus an immutable attempt-event ledger, direct due
claim with full claim CAS, projection-atomic terminal commands, durable
`inputParsing`, a corrected C/D dependency, normalized verification data and a
reducer, a downstream transition matrix, permanently missed schedule fires with
explicit replay, normative v12–v17 DDL, per-slice migration matrices, and
explicit A1a/A1b boundaries.

It does not yet close every implementation decision. Five P0 findings remain at
provider selection, shutdown, external-effect, engine-terminal and Camp
lifecycle boundaries. The A1a store surface also still leaves several choices
to the implementer. Under the repository phase gate, neither A1a nor a later
slice may start until these findings are resolved and independently reviewed.

## Round 1 disposition

| Round 1 finding | Round 2 disposition |
|---|---|
| P0-1 attempt lifecycle/event ledger | **Closed.** `durable_work_attempt` is now a one-close mutable projection and `durable_work_attempt_event` is append-only with a partial unique terminal index. |
| P0-2 exact Runtime Profile and call sites | **Partially closed.** Exact ID capture, no-default-fallback, typed resolver, test injection and the enumerated call-site migration are present. Model-catalog and credential semantics remain open in R2-P0-1. |
| P0-3 atomic planning success | **Closed.** `commitPlanningSuccess` is the sole transaction and includes claim CAS, usage, fallback policy, Cards, Mission rollup, events, attempt and work. |
| P0-4 complete work commands/CAS | **Substantially closed.** Due retry is claimed directly; renew returns the latest claim; cancel owns the projection closure; adoption is explicit. A1a's `cancelActive` wrapper still needs the exact contract in R2-P1-2. |
| P0-5 input parsing recovery | **Closed at the lifecycle level.** Parsing is durable `inputParsing` work and no longer duplicates a `parsing` projection. |
| P0-6 Goal/Outcome C/D dependency | **Closed.** C stops at `ready`; contract-dependent activation and later transitions move to D. |
| P0-7 verification reducer/policy | **Substantially closed.** Requirement rows, current heads, invalidations and the reducer are defined. The remaining state/policy contradictions are R2-P1-6. |
| P0-8 downstream invalidation | **Closed at the transaction-matrix level.** §19 enumerates the required projections and atomicity. |
| P0-9 ApprovalGrant/external receipt | **Not closed.** Explicit scope and receipt tables are present, but the dispatch boundary is causally incorrect; see R2-P0-3. |
| P0-10 kernel/adapter Run ownership | **Not closed.** Kernel-owned Run is selected and affected files are listed, but the terminal payload and recovery contract cannot preserve current behavior; see R2-P0-4. |
| P0-11 schedule missed/replay | **Closed.** Failed slots are permanently evaluated/missed and replay is a separate explicit command. |
| P0-12 schemas/file scopes | **Partially closed.** Normative v12–v17 DDL and much more exact per-slice scope are present. Camp deletion and A1a task-document scope remain open below. |
| P1-1 multi-aggregate event idempotency | **Closed.** A command receipt plus stable event ordinals/derived keys is defined. |
| P1-2 per-slice migration matrices | **Closed.** Every introducing slice runs the full predecessor matrix, and F repeats the aggregate matrix. |

## P0 findings

### R2-P0-1 — The exact-profile resolver still has no exact catalog and credential policy

**Evidence**

- `p1-stage-spec.md:163-178` requires the model to be in the profile's
  “trusted catalog” and fixes a resolver signature and error-code list.
- `p1-plan.md:223-253` repeats that contract, but does not define the catalog
  source or credential requirements for each `RuntimeProfileKind`.
- Root `AGENTS.md:34` says OAuth/CLI profiles use read-only built-in catalogs
  while API-key profiles may add provider-specific manual models.
- Current `ModelCatalogService.resolvedCatalog` accepts scoped choices and
  manual models for profiles without an official trusted catalog, whereas
  `trustedCatalog` returns `nil` for non-official API endpoints
  (`Sources/AgentLoopCore/Provider/ModelCatalogService.swift:55-76`).
- Current ChatGPT OAuth construction reads both the profile credential and the
  separate ChatGPT account ID
  (`Sources/AgentLoopApp/AppStore.swift:585-602,615-622`), but the revised
  contract does not map those two requirements and their read failures to exact
  typed outcomes.

**Impact**

An A1b implementer must choose whether a valid custom API endpoint/manual model
is accepted, rejected because `trustedCatalog == nil`, or accepted from
`modelChoices`. They must also decide whether a missing ChatGPT account ID is
`credential_account_missing`, `credential_not_found`, or still constructible.
Those choices can either break an already supported API-profile path or weaken
the preflight invariant.

**Required revision**

Add one normative resolver table for every profile kind. It must identify:

- the exact model-catalog source and whether cached, scoped and manual entries
  are valid for official and custom API endpoints;
- all required credential accounts, including the OAuth account ID;
- exact endpoint normalization and provider construction;
- the error code for each missing/failed read;
- enqueue-preflight versus claimed-work revalidation behavior.

Add tests for OAuth, official API, custom API + manual model, missing catalog,
missing primary credential, missing OAuth account ID, Keychain read failure and
invalid endpoint. Keep the already-correct no-default-fallback and exhaustive
call-site migration.

### R2-P0-2 — Supervisor shutdown can hang forever and can permit a post-shutdown commit

**Evidence**

- `p1-stage-spec.md:149-152` and `p1-plan.md:268` require shutdown to cancel and
  await owned provider Tasks without changing the ledger.
- `p1-plan.md:280-283` says cancellation itself does not terminalize or release
  work, while a provider return uses the latest live claim.
- `p1-plan.md:272-276` defines a terminal `shutDown` lifecycle, but no lifecycle
  or generation check is part of the terminal-commit gate.
- The required test is only
  `shutdownLeavesRunningForNextProcessAdoption`
  (`p1-plan.md:329`).

**Impact**

Swift Task cancellation is cooperative. A provider that ignores cancellation
can make `shutdown()` wait without a bound. If that provider later returns, its
claim is still current because shutdown intentionally did not alter the ledger;
the plan does not prevent it from committing success after the supervisor has
entered `shutDown`.

**Required revision**

Define a bounded shutdown contract and an actor-serialized lifecycle/generation
gate immediately before every provider terminal commit. Once shutdown begins,
no owned Task may commit, renew or schedule more work; its durable row remains
running for next-process adoption. Specify what happens to an uncooperative
Task after the bound without silently declaring it stopped.

Add at least:

- `shutdownWithCancellationIgnoringProviderReturnsBoundedly`;
- `providerReturningAfterShutdownCannotCommit`;
- a race test between shutdown and terminal proposal;
- proof that the next process adopts and completes the row exactly once.

### R2-P0-3 — `adapterAccepted` is persisted before the adapter can have accepted anything

**Evidence**

- `p1-stage-spec.md:638-645` requires
  `reserved -> started`, `usedCount += 1` and an `adapterAccepted` receipt
  **before** the actual adapter call.
- `p1-plan.md:906-918` repeats the same order.
- The tests simultaneously require “crash before adapter start releases without
  use” and post-start reconciliation (`p1-plan.md:941-944`).

**Impact**

The receipt makes a false factual claim. A crash after the local `started`
commit but before the call is indistinguishable from a crash after the external
effect began. In particular, a non-replayable operation cannot safely be
released in that window, while treating the pre-call row as truly
`adapterAccepted` can consume a grant for an action never dispatched.

**Required revision**

Separate local dispatch intent from adapter acceptance:

1. `reserved` may be released only while it is proven that dispatch did not
   begin.
2. Persist a correctly named `dispatching`/dispatch-intent boundary before the
   non-transactional call.
3. Append `adapterAccepted` only after the adapter actually returns acceptance
   or an operation ID.
4. Treat every non-replayable crash in the ambiguous dispatch window as
   `crashUnknown`; never auto-release it.
5. Reconcile/replay replay-safe and idempotency-keyed operations with the same
   key.

Update DDL/state checks and add crash tests immediately before and after both
the dispatch-intent and actual adapter-acceptance boundaries.

### R2-P0-4 — Kernel-owned terminal receipts cannot preserve handoff, artifact, block or `ask_user` truth

**Evidence**

- `p1-stage-spec.md:788-807` chooses kernel-owned Run/Card termination, but the
  exact `BoardTerminalReceipt` contains only IDs, terminal, `payloadHash`,
  sequence and idempotency key.
- `p1-plan.md:1148-1163` gives `commitEngineTerminal` only that receipt plus
  usage; it defines no canonical terminal payload or durable payload reference.
- Current `BoardTools.complete` parses a full `HandoffPayload`, verifies and
  copies artifact files, then persists handoff + durable artifact paths
  (`Sources/AgentLoopCore/Tools/BoardTools.swift:24-78`).
- Current `block` persists reason/detail, and current `ask_user` atomically
  creates a user request and blocks the Card
  (`BoardTools.swift:81-89,114-173`). The revision only says progress/ask keep
  writing commands while lacking terminal authority.
- Interrupted execution recovery may restore the Card to “ready or blocked”
  (`p1-stage-spec.md:805-807`) without a decision rule.

**Impact**

A hash is not enough to reconstruct the handoff, artifact manifest, durable
paths, blocked reason/detail or user request. Removing BoardTools' DB authority
therefore loses existing product truth unless the implementer invents another
store. File copy and SQLite commit also cannot be one transaction. `ask_user`
has no exact owner for its required block transition. Recovery must guess
between resume, retry, blocked, failed and canceled. In addition,
`beginEngineExecution` has no canonical request hash to reject reuse of the
same idempotency key with a different contract, grants, budgets or workspace.

**Required revision**

Define:

- a canonical terminal proposal containing the full completed/blocked payload,
  or a durable payload reference whose hash is verified by the kernel;
- an artifact staging, commit, cleanup and replay protocol across filesystem and
  SQLite boundaries;
- the exact kernel command for `ask_user` that atomically writes the user
  request and Run/Card terminal projection;
- `beginEngineExecution` request hashing/conflict semantics;
- a deterministic interrupted-execution matrix for never-started, resumable
  session, replay-safe, non-replayable/crash-unknown, cancellation and
  unrecoverable parser/EOF cases.

Test full handoff/artifact replay, block reason/detail, `ask_user`, crash between
file staging and DB commit, request-key payload conflict, and every recovery
branch.

### R2-P0-5 — `deleteCamp` still does not define what is deleted

**Evidence**

- `p1-stage-spec.md:701-706` says Camp deletion revokes active residency and
  invalidates or erases Camp-private memory.
- `p1-plan.md:1022-1030` exposes only a “deleteCamp contract command”.
- The existing Camp row already has an `archived` projection
  (`Sources/AgentLoopCore/Database/Records.swift:119-131`).
- New residency, bridge and memory foreign keys use `ON DELETE RESTRICT`
  (`p1-stage-spec.md:1703-1759`), and §19 requires preserved evidence and
  downstream invalidation.

**Impact**

Physical deletion conflicts with the normative foreign keys and retained
history. Archival/tombstoning is implementable, but the documents do not choose
it or define whether it is reversible. They also do not define the same
transaction's treatment of bridges, queued/running work, Inputs, Goals,
Missions, notes, private-memory bodies and global records that merely reference
the Camp.

**Required revision**

Choose one explicit lifecycle—preferably a named irreversible tombstone command
separate from the existing reversible archive command—or remove `deleteCamp`
from P1. Define the Camp-row projection, reversibility, exact propagation to
residencies/bridges/work/Goals/Missions/Input/Memory, retained audit fields,
body erasure, command receipt/event and rollback behavior. Add FK-backed replay
and partial-failure tests.

## P1 findings

### R2-P1-1 — A1a's Store API is not a complete Swift/GRDB contract

`p1-plan.md:128-142` lists method names but, except for `renewLease`, omits
return types. It also does not type `businessMutation` /
`terminalBusinessMutation` as a throwing `(Database) throws -> Void` closure or
say whether `DurableWorkStore` owns an `AppDatabase`, a `DatabasePool`, or is a
stateless transaction helper. Specify the initializer/ownership/isolation,
async/throws and return type for every method. The later supervisor and tests
must not choose this surface ad hoc.

### R2-P1-2 — `cancelActive` lacks its race and no-active semantics

`p1-plan.md:137-138` names `cancelActive` but does not say whether no active row
is a successful idempotent no-op or an error. It must select the active work,
lock/read its current version and perform the version-CAS cancellation plus
business mutation in the same write transaction. Add concurrent
terminal-vs-cancel and no-active replay tests.

### R2-P1-3 — A1a accepts an unverified caller-supplied `inputHash`

The enqueue API accepts `inputJson` and `inputHash`
(`p1-plan.md:128-132`), while the v12 DDL only checks that the hash has 64
characters (`p1-stage-spec.md:907-909`). Require the store to canonicalize or
validate canonical JSON, recompute SHA-256, require lowercase hex and reject a
mismatch before replay comparison. Test uppercase, non-hex, non-canonical and
same-hash/different-payload attempts.

### R2-P1-4 — A1a omits the retry policy's own acceptance tests and task artifacts

The A1a test list (`p1-plan.md:156-170`) tests due claim but not the specified
5s/30s/120s bounded backoff, deterministic immediate failure, exhaustion at
`maxAttempts`, or overflow-safe date arithmetic. Add these tests to A1a rather
than waiting for planning integration.

The exact A1a allowed-file list (`p1-plan.md:103-112`) also omits the slice
`reviews/` output and `acceptance.md`, although the same section requires
independent Review/acceptance. List the exact task artifact paths and their
owner; the implementer must not need to violate scope to finish the gate.

### R2-P1-5 — Two-turn planning usage can overflow before the checked DB commit

The stage allows an initial provider turn and one correction turn
(`p1-stage-spec.md:179-185`) and checks overflow at commit. Current
`Usage.add` performs unchecked `Int +=`
(`Sources/AgentLoopCore/Provider/LLMProvider.swift:7-12`). The plan does not
require `Planner.proposeDurable` to use checked accumulation while constructing
its result/failure. Specify checked per-turn accumulation and test that overflow
on the correction turn yields deterministic `UsageOverflowError` without a
process trap or saturated success.

### R2-P1-6 — Outcome transitions and acceptance-policy safety rules disagree internally

The state diagram permits `delivered -> returned` but not
`accepted -> returned` (`p1-stage-spec.md:502-511`), while §19 explicitly
requires `delivered|accepted -> returned` (`p1-stage-spec.md:1987-1993`).
Likewise, re-verification after failure/block is defined by the reducer/matrix
but absent from the diagram. Publish one authoritative transition matrix and
make the diagram match it.

The policy text says first onboarding, first outcome type, subjective creation,
publication, payment, deletion and external send always require the user, but
the DDL permits their `allow*` fields to be `1`, and the stated hard store guard
only names high/irreversible risk and an unverified reducer
(`p1-stage-spec.md:595-603,1316-1351`). Either remove impossible allow-fields or
mandate and test a store-level rejection for every always-user action,
regardless of stored policy bits.

### R2-P1-7 — InputEnvelope prose and normative schema still disagree

The field contract still lists `parseAttempt` (`p1-stage-spec.md:339-356`) even
though parsing attempts moved to `durable_work` and the normative Input DDL no
longer contains that field. Remove it or define a non-authoritative derivation.
Also make `status = deletedTombstone` and
`retentionState = deletedTombstone` mutually consistent in DDL/store invariants;
the current independent checks can represent a deleted status with active
retention, or a retention tombstone with a live status. Add direct malformed-row
tests, not only happy-path store tests.

## Coverage and phase gate

| Area requested for Round 2 | Result |
|---|---|
| attempt lifecycle / event ledger | Closed |
| exact-profile resolver and all call sites | Callsites closed; resolver policy blocked by R2-P0-1 |
| `commitPlanningSuccess` atomicity | Closed |
| complete work commands / CAS | Core closed; `cancelActive` exactness remains R2-P1-2 |
| input parsing recovery | Closed; schema cleanup remains R2-P1-7 |
| C/D dependency | Closed |
| verification reducer / policy / invalidation | Reducer and matrix closed; internal transition/policy conflicts remain R2-P1-6 |
| Grant external receipt | Blocked by R2-P0-3 |
| kernel-owned Run/current backends | Ownership chosen; terminal/recovery contract blocked by R2-P0-4 |
| schedule missed/replay | Closed |
| v12–v17 DDL / exact allowed files | Broadly closed; Camp lifecycle and A1a artifacts remain open |
| per-slice migration matrix | Closed |
| A1a/A1b, planner errors, legacy repair, CLI preflight | Broadly closed; R2-P0-1 and R2-P1-1…5 remain |
| supervisor lifecycle / shutdown | Blocked by R2-P0-2 |

## Approval gate

- P0 findings: **5**
- P1 findings: **7**
- Decision: **CHANGES REQUIRED**
- P1-A1a implementable now: **No**
- Open Questions may not be “无” until all findings above are resolved in the
  stage spec and plan and Round 3 returns no P0/P1 findings.
