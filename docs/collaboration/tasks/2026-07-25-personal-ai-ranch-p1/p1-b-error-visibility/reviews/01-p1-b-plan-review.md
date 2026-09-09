# P1-B Responsibility-Isolated Plan Review01

> Date: 2026-08-11
>
> Reviewer: responsibility-isolated P1-B Level-3 leaf plan reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2**

## 1. Independence, authority, and review boundary

This reviewer did not author Candidate 02 and did not participate in P1-B
implementation. The review was read-only except for this exact new review file.
It did not run tests, builds, migration runners, matrix scripts, the App, a
preview, or any process that could touch normal data or Keychain. It did not
modify product, test, Package, script, plan, inventory, blocked, evidence, or
historical acceptance bytes.

The review read the complete current bytes of:

- `AGENTS.md`;
- the accepted master spec, especially §13 and the P1 direction/completion
  gate;
- canonical `p1-stage-spec.md` §7, §18.3, §20 P1-B, and §22;
- canonical `p1-plan.md` §4 and §10;
- accepted P1-A4 `acceptance.md`;
- Candidate 02 `plan.md`, `try-question-mark-inventory.md`, and `blocked.md`;
- current Package target definitions, every existing source/test path in the
  42-path allowlist, direct public/package call sites, the CLI backend, and the
  live A3/A4 source-boundary carriers.

The frozen candidate bytes reviewed were independently hashed before and after
the full read:

```text
plan.md                         9f985de7b5857bfa1cf099ae175b11e65f02a7ba85e9b81e7c3376a27e4e66ea
try-question-mark-inventory.md  6024b62afcb613b9a8ff751b82ffe6489f87abc7db5ff71af6ef954fd8a3f32b
blocked.md                      4ff6139484bcf791042fa3f2c5ba00d2bacfdb56fb2df4b1fde3df2dd7716335
```

Those hashes matched the planner's frozen submission and remained unchanged
during this review. P1-A4 is independently `ACCEPTED`, so bounded P1-B planning
is legitimately open. This review does not authorize implementation, accept
P1-B, or open P1-C.

## 2. Contracts already sufficiently specified

The following points survived read-only verification and do not need to be
reopened merely because the verdict is changes-required:

- The literal `try?` inventory count is real: 129 total, split exactly as 112
  business / 13 parse / 4 cleanup. The current per-file counts are AppDatabase
  8, Orchestrator 16, McpServerManager 3, McpToolBridge 1,
  MemoryDistillService 5, AppStore 84, McpStore 5,
  CodingRanchStoreAdapter 3, McpStationSection 1, CompanionEditorView 1, and
  McpTests 2. The 129 regression tags are unique.
- The 42-path allowlist is pathname-exact. Ten named paths are absent as new
  files and the remaining paths exist. The direct `assembledTools`,
  MemoryDistill, OAuth, and exhaustive `KernelEvent` call sites inspected do
  not currently force an additional source path merely to preserve source
  compatibility.
- Stage §18.3 is represented by the correct 49-line SQL fence with SHA-256
  `a0fe7c90723220a8e5a1402cc9f9b1997e04cf2d8a45de6474e8e5f9b599f087`.
  The final 31 tables / 65 indexes / 4 triggers arithmetic, eight predecessor
  order, reopened-v11 literal start, real-v13 named-index conflict injection,
  replay, rollback, and no-v14 boundary are coherent.
- The A4 entry manifest has exactly 26 pathname intersections with the exact
  42 paths, leaving 180 unaffected entries. The A3 manifest has 28 raw
  intersections; three are already among its seven accepted A4 exclusions, so
  25 new successor exclusions leave 174 unaffected entries. Candidate 02's
  algorithms preserve historical evidence while independently restricting the
  final delta to the 42 paths plus the task directory.
- The current static baseline is 667 `@Test` declarations in seven suites.
  Forty-six ordinary non-parameterized declarations produce the stated 713
  arithmetic; forbidding `@Test(arguments:)` is the correct count-stability
  decision.
- Keychain `errSecItemNotFound` versus read failure, invalid credential value,
  shared synchronous credential access, one OAuth callback/refresh coordinator,
  fixed mutation order, reverse rollback, and no raw token/body diagnostics
  are the right direction. The shared lock is necessary for synchronous
  resolver readers and closes the half-written-bundle race if its API is
  actually frozen as required by P1-06.
- MCP configuration validation, a throwing secret provider, typed start/list/
  call distinctions, no automatic retry after down, and a down event only for
  typed `connectionDown` are sound. A valid tool-level error must not mark the
  server down.
- The MemoryDistill outcome split among no eligible input, model skip, created,
  provider/DB failure, and lost-watermark race is semantically correct.
- The preview's owned executable/PID/start-time/lsof/Accessibility/isolated-DB
  evidence and release-zero/debug-positive intent are appropriately fail-closed.
  P1-06 concerns the missing callable seams, not those evidence goals.

These verified points do not close the six blocking findings below.

## 3. Findings

### P0

0.

### P1-01 — An auxiliary transaction rollback can discard a failure even while `failure_record` remains writable

**Authority**

- Stage §7.1 requires persistence whenever the database is writable; logger +
  UI-only is reserved for the database itself being unwritable.
- Master §13.1/§13.3 and `AGENTS.md` require observable failure rather than a
  secondary operation hiding the original failure.

**Evidence**

Candidate §5.3 freezes ordinary capture as prepare → writer → complete, but
freezes both atomic owners as prepare → multi-row transaction →
`complete(.unavailable)` on *any* transaction failure. Candidate §7.2 does this
when the MCP down-event transaction fails; §8.2 does the same when the
failure/degradation/Card transaction fails.

Those transactions contain independent failure points after the
`failure_record` upsert: event append, `context_degradation` insert, and Card
transition/event. Any one can fail and roll the transaction back while an
isolated insert into `failure_record` would still succeed. Candidate 02 makes
no bounded fallback upsert of the already scrubbed `PreparedFailure` and has no
test that distinguishes “auxiliary row failed” from “failure table itself is
unwritable.” It also says all failure write SQL is called only by Reporter or
Loader while §7.2 requires Bridge-owned atomic writing, leaving ownership
internally inconsistent.

**Impact**

A failed event, degradation row, or Card transition can erase the durable
record of the original MCP/knowledge failure and incorrectly downgrade a
writable database to logger-only evidence. That violates the exact Stage §7.1
boundary and makes UI/DB trace correlation depend on which secondary statement
failed.

**Minimum executable correction**

Freeze one bounded `persistPrepared` fallback owned by FailureReporter (or an
equivalent exact writer seam). After either atomic transaction rolls back, the
owner attempts exactly one isolated upsert of the *original*
`PreparedFailure`, with the same trace and identity. If that succeeds,
`complete(.stored)`; only if that isolated failure-record write also fails may
it use `complete(.unavailable(stableCode:))`. Do not recursively capture a
second `database_write_failed`, change the original visible failure, continue
an optional dependency, or dispatch a backend. Freeze the exact AppDatabase
transaction methods and name Reporter, Loader, and Bridge call ownership
without contradiction.

**Regression gate**

Within the existing 46 declarations, inject a failure separately after the
failure upsert at MCP event append, degradation insert, and required Card
transition. Each case must assert: the auxiliary transaction rolled back; one
failure row with the original trace/errorCode exists; no contradictory second
row exists; optional work does not continue; required work does not dispatch.
A distinct case must make the failure table itself unwritable and assert no row,
one safe terminal logger record, the same full UI trace, and zero retry/dispatch.

### P1-02 — The context handoff drops the validated search credential and can dispatch a CLI without its selected required capabilities

**Authority**

- Stage §7.2 and red line §22.6 make explicitly selected MCP/tool knowledge
  required; missing capability must block the Card rather than disappear.
- Master §13.3 forbids silent continuation without selected tools or
  permissions.

**Evidence**

Candidate §8.2 says ContextDependencyLoader resolves selected `web_search`, but
its frozen result is only:

```text
ready(campNotes, companionNotes, externalTools, degradations)
```

It does not return the resolved `searchKey`. Candidate §6.4 simultaneously says
Orchestrator calls `searchKeyProvider`, which either requires a second read or
bypasses the loader's required-dependency outcome.

The current real CLI path is outside the 42-path allowlist at
`Sources/AgentLoopCore/Loop/CliProcessBackend.swift`. Its `run` implementation
uses `context.toolAccess` only to build BoardToolServer tools and puts only those
board tool names into the CLI packet/command. It never consumes
`context.externalTools` or `context.searchKey`. Candidate §8.3 nevertheless
routes `.ready` to either CardRunner or CLI construction without a runtime-kind
capability rule. Therefore a selected MCP or `web_search` can be validated (and
an MCP server even started) and then be omitted from the actual CLI execution.

**Impact**

The required-dependency gate can report ready while the chosen backend cannot
provide the selected capability. A second search-key read also creates a
read/delete race and can turn a previously validated dependency into a generic
backend failure. This is exactly the silent required-tool downgrade prohibited
by Stage §7.2.

**Minimum executable correction**

Add the exact runtime profile/backend kind to the dependency request and add
`searchKey: String?` to the ready payload. The loader must perform at most one
selected search-credential read and the execution context must receive that
exact value. For the current bounded allowlist, the minimal CLI rule is to
atomically record/block before any backend construction when a CLI Card selects
an MCP capability or `web_search` that CliProcessBackend cannot expose. A
broader alternative is to add CliProcessBackend to a newly reviewed allowlist
and implement a real capability adapter, but Candidate 02 does not authorize
that expansion. CLI Cards with no unsupported selected capability must remain
compatible.

**Regression gate**

Add internal cases for: model backend + selected MCP receives the exact tool;
model backend + selected `web_search` performs one read and receives that key;
unselected search performs zero reads; CLI + selected MCP and CLI + selected
search each persist failure/degradation, block, start no MCP/provider/backend,
and execute zero tool calls; CLI without those selections still dispatches.
The source gate must prove no second `searchKeyProvider` call after loader
success.

### P1-03 — The Application/Core boundary has no implementable consistent-snapshot or synchronous runtime-bootstrap seam

**Authority**

- Canonical Plan §4.2 and Candidate §3 require AgentLoopApplication to depend
  only on Core and forbid importing GRDB.
- Candidate §6 requires consistent off-state snapshots, one DB snapshot for
  provider resolution, fail-closed runtime bootstrap, and no mixed old/new
  projections.
- The repository's no-unplanned-decision rule forbids the implementer from
  inventing a new persistence boundary during implementation.

**Evidence**

Current AppDatabase exposes separate public methods such as `mission`, `cards`,
`pendingUserRequests`, `events`, `missionSpendBreakdown`, `missions`, and
`artifactLedger`; each opens its own `pool.read`. Its only generic transaction
surface exposes GRDB's `DatabasePool`. Candidate's exact controller initializers
receive a concrete AppDatabase and no aggregate loader. Candidate declares
Mission detail/index and Input Camp to be coherent snapshots, but freezes no
Core record bundle or one-`pool.read` API that Application can call without
using GRDB. Sequential successful calls can therefore observe different WAL
snapshots even though the final UI assignment is atomic.

The Runtime boundary has a second concrete gap. Current AppStore performs
credential presence, `RuntimeProfileBootstrap.ensureSeeded`, initial profile/
default load, and construction of `ProfileScopedDefaults` synchronously in its
initializer. Candidate makes RuntimeProfileWorkflowController an actor, says
AppStore delegates bootstrap, but supplies no synchronous bootstrap API. Its
exact initializer also omits the existing App-scoped `ProfileScopedDefaults`
needed by reconciliation/default switching and catalog policy. Constructing a
fresh default wrapper would contact the wrong UserDefaults domain in tests and
preview.

**Impact**

The implementer must choose among three unauthorized outcomes: import/use GRDB
inside Application, publish a mixed-revision snapshot, or invent new Core
bundle/transaction APIs. Runtime initialization must likewise either await an
actor from a synchronous initializer, retain the existing silent bootstrap, or
invent another coordinator/defaults owner. Any choice changes architecture and
can violate preview isolation.

**Minimum executable correction**

Freeze package Core read-bundle types and AppDatabase methods, inside the
existing allowed `AppDatabase.swift`, for every multi-table snapshot promised
as consistent (at minimum Mission detail, Mission index, Input Camp/review, and
runtime profile/default resolution). Each method must assemble its Core-only
bundle in one `pool.read`; Application maps it to the §6.6 DTO without GRDB.

Also freeze a synchronous, throwing runtime bootstrap/composition seam used by
AppStore before actor construction. It must take the one injected
`ProfileScopedDefaults`, synchronized credential reader, and isolated database,
return the seeded/default snapshot or a visible typed failure, and inject the
same defaults instance into later reconciliation/catalog/default commands.
State exactly which work remains synchronously in AppStore composition and
which commands move to the actor.

**Regression gate**

Use a barrier/concurrent writer between component reads and prove each bundle
is entirely pre-write or post-write, never mixed. Add isolated UserDefaults
cases proving bootstrap/default/reconciliation use the injected domain, no
normal defaults, and no actor await is needed during AppStore initialization.
The import/source gate must reject GRDB types or `pool.read` use in every
Application file.

### P1-04 — The 129 count is correct, but it is not a complete inventory or executable gate for the plan's “equivalent fallback” claim

**Authority**

- Master §13.1/§13.3 forbids hidden failure, not only the `try?` spelling.
- Stage §7.1 distinguishes failure from absence/default success, and §7.3
  requires typed handling for business operations.
- Candidate R-05, inventory §1, and red line §16.7 explicitly claim closure of
  `try?` **or equivalent** and “no catch-and-ignore equivalent.”

**Evidence**

The inventory has exactly 129 literal `try?` rows and its classification is
correct. It contains no rows for `catch`, `do/catch` returning a default,
`Result` projection to absence, or a nonthrowing helper that swallows a write.
The existing in-scope production files contain 100 `catch` tokens; not all are
wrong, but none has an inventory disposition or fail-closed residual allowlist.

Concrete unaccounted examples include:

- `AppDatabase.appendKernelErrorEvent` catches an event-write failure, logs raw
  `String(describing:)`, and returns `Void`;
- `AppStore.captureLegacyRuminationSnapshot` catches a DB read failure and
  returns the same `.legacyProfileUnresolved` value used for a real domain
  state, without a P1-B trace; and
- multiple Orchestrator/AppStore catch arms still feed
  `String(describing:)`, `localizedDescription`, or `readableError` directly to
  event/UI/log surfaces. Candidate's source gate only names raw credential/
  provider/MCP response logging and does not close its broader raw error/path/
  prompt red line.

The sentence “no catch-and-ignore equivalent” is semantic prose; no exact
algorithm can decide which of the current catches is an approved cancellation,
an explicit fail-closed terminal, or a forbidden fallback.

**Impact**

Implementation can remove all 125 prohibited literal `try?` occurrences and
pass the stated fresh `rg` gate while equivalent silent/default behavior and
raw error projection remain. R-05 and the plan's own completion/redaction
claims would be unprovable.

**Minimum executable correction**

Add a frozen equivalent-fallback appendix covering every in-scope catch/default
arm that can replace a business failure with a value, no-op, raw string, or
success-like state. Give each an exact disposition, safe trace owner, and test
tag; separately enumerate approved residual catches such as stale-generation
or cancellation handling. Freeze a source-gate algorithm based on exact
markers/allowlisted arms rather than the unenforceable semantic sentence.
`appendKernelErrorEvent` must become a throwing/typed boundary or be fully
replaced by exact FailureReporter/transaction owners; raw formatting helpers
may not bypass the scrubber.

**Regression gate**

Fail on any unclassified `try?`, fallback catch, or raw error formatter in the
42 paths. Inject the named swallowed-read/write cases and assert a failed state
with the same trace, no default/empty/success projection, and no raw content.
Retain the independently verified 129 snapshot as historical planning evidence;
do not relabel it as the complete equivalent-fallback inventory.

### P1-05 — The claimed exhaustive failure contract leaves persisted/accessibility metadata and several required error codes undefined

**Authority**

- Stage §7.1 requires safe UI text and the same stable trace without secrets,
  raw credentials, or complete external responses.
- Stage §22.10 forbids recording secrets, OAuth callbacks, account identifiers,
  Keychain values, or raw sensitive content.
- Candidate §5.3 says the classifier is exhaustive and no raw value may enter
  failure/degradation/event/UI/log evidence.

**Evidence**

Candidate validates `traceId` with a bounded grammar, but `operation` is only
required to be nonempty and every `FailureScope` identifier is only required to
be nonblank. These fields bypass the body/diagnostic scrubber: `operation`,
`scopeType`, and `scopeId` are persisted, and operation is included in the
VoiceOver label. The prose says an ID is safe by convention, but there is no
closed operation registry, scope-type map, value grammar/limit, or exhaustive
call-site mapping that prevents a path/account/external name from being passed.

The exact classifier table is also not exhaustive over Candidate 02 itself.
`trace_identity_conflict` is required by §6.6 and
`mcp_secret_rollback_failed` by the MCP deletion contract, but each appears
only at its use site and neither has an exact classifier row with typed source,
severity, scope, safe body, or diagnostic keys. Proposal primary+rollback
failure defines two diagnostic keys and a body but no final stable errorCode.
The MemoryDistill typed error cases and several coordinator/integrity errors
are named only as categories, leaving the implementer to invent their exact
mapping or fall through to `unexpected_failure`.

**Impact**

Sensitive or unbounded metadata can be durable and accessibility-visible even
when message/diagnostic scrubbing is correct. Undefined codes also conflict
with same-trace identity matching and make persisted bytes, UI text, and test
expectations implementation-dependent.

**Minimum executable correction**

Freeze a closed `FailureOperation`/operation constant registry, exact
scope-type map, and validators/ceilings for every persisted or accessible
metadata field. Only opaque already-known internal IDs may be scope IDs; tool
names, Keychain account names, paths, prompts, callback values, and external
payloads must be rejected or mapped to fixed safe coordinates. Extend the
classifier table with every code used elsewhere, including exact typed source,
severity, scope, safe body, retryability, and allowed diagnostic keys. Define
the final composite proposal code and exact MemoryDistill/coordinator integrity
errors.

**Regression gate**

An exhaustive table must prove every operation/callsite and every typed error
maps once. Inject secret/account/path/external-response canaries independently
into operation, each scope coordinate, body, diagnostics, MCP coordinates, and
unknown Error; assert none enters DB, logger, event, UI, or Accessibility.
Assert the newly named conflict/rollback/composite codes round-trip and same-
trace identity mismatches never overwrite an existing row.

### P1-06 — The “exact API appendix” is not yet a compilable, compatibility-preserving, injectable interface

**Authority**

- Repository rules prohibit unplanned architecture/API decisions.
- Canonical Plan §4.7 requires executable workflow tests; Candidate §11/§14
  makes the isolated preview, strict-concurrency builds, and exact call-site
  compatibility completion gates.

**Evidence**

Several central declarations are still prose or are syntactically incomplete:

1. `WorkflowRequestGeneration` declares public `RawRepresentable` conformance
   but the snippet has no public `init(rawValue:)`; the synthesized memberwise
   initializer is not a public protocol witness. Exposing that initializer also
   changes the intended opaque-generation ownership, so the fix is a design
   choice, not punctuation.
2. §6.6 says all declarations are package API, while the literal DTOs, stored
   members, and command construction initializers use default `internal`
   access. AgentLoopApp and AgentLoopTestSuite are different targets and cannot
   construct/read those values without explicit package API.
3. ContextDependencyLoader has no exact request/initializer/result declaration;
   `ContextDegradationNotice` is referenced but never defined. The manager's
   exclusive maintenance token, `SynchronizedCredentialAccess`,
   `CredentialBundleCoordinator`, OAuth bundle commands, and the
   interaction-policy credential read API are described but not declared.
4. Existing `PlanningEntryCoordinator.startConfirmedProposal` returns `String`.
   Candidate changes `confirmSquadProposal` to a typed outcome without freezing
   a compatibility wrapper or exact unwrapping path. Similar “ignored return
   remains compatible” prose does not cover every package String call path.
5. §11.2 requires RuntimeProfileWorkflowController to receive a deterministic
   throwing read closure after one successful load, but the exact initializer
   accepts only concrete AppDatabase/resolver/coordinator/reporter values.
   AppDatabase is final. The exact DEBUG audit hook parameters for Orchestrator,
   McpServerManager, and McpToolBridge are likewise absent.

The target graph compounds the verification gap: AgentLoopTestSuite will depend
on Core + Application, not AgentLoopApp. Ninety-four inventory rows live in
App/App-view files. They can be proved only if their fallible behavior delegates
to an exact reachable Core/Application seam plus a source mapping, or via an
explicit App-level carrier. Merely comparing a hard-coded tag set to the
inventory can pass without executing the production callsite.

**Impact**

The implementer must invent access control, initializer shapes, maintenance and
credential lifecycle APIs, compatibility overloads, and DEBUG injection hooks.
Different reasonable choices change actor isolation, cancellation/lease
ownership, rollback ordering, and the release symbol surface. As written, the
strict builds or mandated preview can fail even when the prose behavior is
implemented, and 46/713 can be count-correct without being behavior-complete.

**Minimum executable correction**

Replace prose references with a complete package API appendix:

- choose an opaque generation type that compiles without a forgeable public
  RawRepresentable initializer, or explicitly freeze the required initializer;
- put package access and explicit initializers on every cross-target DTO/member;
- declare ContextDependencyRequest/Result (including runtime kind and search
  key), ContextDegradationNotice, exact AppDatabase atomic transaction calls,
  manager maintenance acquisition/release semantics, synchronized credential
  reads with interaction policy, coordinator bundle/preimage/rollback commands,
  and MemoryDistill error/outcome access/conformances;
- preserve current String-returning PlanningEntryCoordinator paths with exact
  wrappers while the new controller consumes traced typed overloads; and
- declare the production-default/test/DEBUG read and audit seams, including
  actor/sendability rules and release erasure.

Map every inventory tag to the exact reachable production seam and injected
failure, not only to a generic test name. If an App-only projection remains
unreachable from TestSuite, add a bounded App-level test/preview carrier or move
the decision logic into the already authorized Application seam; do not add a
fake table that merely restates expected values.

**Regression gate**

Require compile-time fixture call sites for every frozen initializer/overload,
all four debug/release targets, and source assertions that no closed caller
changes. The Runtime failure preview must fail one real injected read while the
same isolated failure table stays writable, and audit hooks must be
debug-positive/release-zero in the exact binaries. The 129 tag gate must invoke
each mapped production seam and fail on a tag whose only “coverage” is set
membership.

### P2-01 — Optional degradation uses a valid live-event direction, but “event commit” and dispatch ordering are contradictory

**Authority**

Stage §7.2 requires the degradation record and event before optional
continuation, with UI visibility.

**Evidence**

Candidate §8.2 chooses `context_degradation` as cold durable truth and emits an
in-process `KernelEvent.contextDegraded` after the transaction. This is a
reasonable bounded alternative to inventing a v14 domain event. Candidate red
line §16.3 nevertheless says the “degradation row and event commit” must precede
continuation. KernelEvent has no commit, durable acknowledgment, or outbox.
Test 17 is named only “occurs after commit”; it does not explicitly prove event
emission precedes loader return/backend construction.

**Impact**

Two implementations can claim compliance: emit before dispatch, or return
ready and emit later. The latter violates the required visible-before-continue
ordering. Calling an in-process yield a commit also makes evidence claims
inaccurate.

**Minimum executable correction**

State the exact chosen contract as: atomic failure + degradation row commit,
then synchronous KernelEvent emission, then missing marker/loader ready return,
then backend construction. Cold UI reloads the row; no subscriber acknowledgment
is claimed. Revise “event commit” accordingly. If the planner instead requires
a durable event, name the existing in-scope event/write and include it in the
same transaction; do not invent v14.

**Regression gate**

Extend the existing event test with an ordered call ledger proving row commit <
KernelEvent emission < loader ready < provider/backend/tool dispatch, plus
transaction failure → zero event/marker/dispatch.

### P2-02 — The 1000-character formatter budget is not defined in SQLite's length unit

**Authority**

Stage §18.3 enforces `CHECK (length(userMessage) <= 1000)`, while Stage §7.1
requires reporter persistence when the database is writable.

**Evidence**

Candidate §5.3 budgets the full framed message to “1000 Unicode characters” but
does not say whether implementation counts Swift grapheme clusters, Unicode
scalars/code points, UTF-8 bytes, or SQLite `length(TEXT)` units. Swift
`String.count` and SQLite text length differ for combining sequences and some
emoji. The listed 1000/1001 migration boundary does not name non-ASCII cases.

**Impact**

A message accepted by the in-memory formatter can fail the DDL CHECK even
though the database is otherwise writable, or be truncated inconsistently
between UI and persisted text.

**Minimum executable correction**

Freeze truncation/counting to the exact unit enforced by SQLite for UTF-8 text,
including the fixed prefix/newline/full trace suffix, and keep diagnostic JSON
on its separate 4096-byte budget.

**Regression gate**

Add internal boundary cases for ASCII, combining scalars, and multi-scalar
emoji at exact accepted/rejected limits. Each accepted formatter output must
insert unchanged and remain byte-identical to the UI message.

## 4. Required revision boundary

The six P1 findings can be closed without changing Stage §18.3, adding v14,
changing Package.resolved/RunTests, or performing a whole-AppStore rewrite. The
revised leaf may retain the 42-path boundary if it chooses fail-closed CLI
blocking rather than implementing an external-tool CLI adapter. It may retain
46 declarations/713 total by adding the required matrices as internal cases,
provided every tag reaches a real production seam.

The following accepted Candidate 02 decisions should remain unless a correction
above directly requires a bounded change: 49-line v13 DDL, 31/65/4 terminal
shape, eight predecessors, 180/174 historical gates, 129 literal snapshot,
shared credential coordinator, connectionDown-only MCP event, redacted
tombstone immutability, façade-owned generation/projection, session suppression,
and fail-closed preview ownership evidence.

No implementation may begin from this review. Revise `plan.md`,
`try-question-mark-inventory.md`, and `blocked.md` as planning artifacts only,
freeze a new candidate, and obtain a fresh responsibility-isolated plan review
with zero P0/P1.

## 5. Verdict

**CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2.**

Candidate 02 is materially stronger than the initial draft, and its literal
inventory/migration/history arithmetic is sound. It is not yet
decision-complete at the failure-persistence, backend-capability,
Application/Core transaction, equivalent-fallback, metadata/redaction, or
cross-target API/verification boundaries. P1-B implementation remains blocked.
