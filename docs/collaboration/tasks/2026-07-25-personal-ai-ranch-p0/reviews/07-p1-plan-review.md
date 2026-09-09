# P1 Stage Spec / Plan Independent Review — Review07

> Date: 2026-07-26
>
> Reviewer role: responsibility-separated independent reviewer
>
> Independence: the reviewer did not participate in the bounded revisions that
> produced these frozen inputs, did not edit either frozen input, and did not
> repair findings during review. Product code remained frozen. The only
> repository file written by this review is this report.

## Frozen inputs

- `p1-stage-spec.md`
  - SHA-256:
    `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- `p1-plan.md`
  - SHA-256:
    `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`

Both hashes were independently recomputed before and after this review and
matched exactly.

The repository `AGENTS.md`, accepted master spec, P0 `blocked.md`, P0 Stage,
Plan, and current-state evidence, Reviews 01–06, the complete frozen P1 Stage
and Plan, and the current source owners named by the Plan were read as review
inputs. No Stage, Plan, master-spec, P0-status/evidence, prior review, product
source, package file, script, or test fixture was modified.

## Verdict

**CHANGES REQUIRED — 0 P0 findings and 2 P1 findings.**

The required zero-P0/zero-P1 gate is not met. Review07 gates only entry into
the P0 final acceptance audit. It does not authorize A1a, any P1 product-code
implementation, commit, push, merge, release, or the next stage. The frozen
candidate must be revised, refrozen, and independently reviewed before that
audit entry can open.

## Validation performed

### Worktree and product-code scope

- Branch observed: `codex/personal-ai-ranch-p0`.
- The worktree already contained P0/P1 documentation changes outside this
  review.
- `git diff --name-only -- Sources Package.swift scripts` returned no paths.
- `git ls-files --others --exclude-standard -- Sources Package.swift scripts`
  returned no paths.
- `git diff --check` passed.
- Review07 introduced no product-code delta.

### SQL fence extraction and dual-SQLite execution

All eight `sql` fences were independently extracted in document order: seven
DDL/migration fences and the final GC live-set query.

A baseline produced by the current real `AppDatabase.migrator` through v11
contained 24 tables, 44 indexes, and 2 triggers. The seven literal DDL fences
were then applied in transactions with foreign keys enabled under both
available SQLite implementations:

| Check | `/usr/bin/sqlite3` 3.51.0 | Homebrew SQLite 3.52.0 |
|---|---:|---:|
| all seven DDL fences execute | pass | pass |
| GC query executes | pass | pass |
| trigger checkpoints | `2/4/4/4/8/16/67/84` | `2/4/4/4/8/16/67/84` |
| final tables / indexes / triggers | `79/208/84` | `79/208/84` |
| `PRAGMA foreign_key_check` | 0 rows | 0 rows |
| `PRAGMA integrity_check` | `ok` | `ok` |
| stale final FK target | 0 | 0 |
| temporary/staging schema object | 0 | 0 |

The literal fences therefore pass structural execution and the fixed graph
counts in both lanes. They do not pass the separately normative statement
ordinal contract; see R7-P1-1.

Populated migration and rollback fixtures additionally established:

- archived `running`, `queued`, and `retryScheduled` durable work closes as
  specified while active-Camp work remains active;
- failed populated v15-to-v16 migration restores the v15 data and guard graph
  byte-for-byte;
- final durable child foreign keys target only `durable_work`,
  `durable_work_attempt`, and `camp_provider_dispatch`;
- `domain_event` and `camp_event_scope` remain exact 1:1 before and after a
  rejected raw event delete;
- raw external-CLI deletion with matching receipt, event, scope, outbox, and
  safe JSON still fails closed because the connection-local UDF is absent, and
  all four rows remain unchanged;
- `action_candidate` and `knowledge_source_link` ordinary deletes remain
  permanently rejected.

### Append-only and redaction guard graph

The final executable graph contains both UPDATE and DELETE protection for all
nine normative append-only carriers:

| Carrier | UPDATE protection | DELETE protection |
|---|---:|---:|
| `durable_work_attempt_event` | yes | yes |
| `domain_command_receipt` | yes | yes |
| `domain_event` | yes | yes |
| `verification_record` | yes | yes |
| `verification_invalidation` | yes | yes |
| `acceptance_record` | yes | yes |
| `external_operation_receipt` | yes | yes |
| `memory_dependency` | yes | yes |
| `discussion_turn` | yes | yes |

At each introducing checkpoint, a legal INSERT succeeded, while no-op UPDATE,
ordinary UPDATE, and DELETE aborted without changing the database. The five
v16 replacement paths for durable attempt events, Verification, Acceptance,
external-operation receipts, and legacy events also passed the intended
matrix: wrong/no-op redaction failed, the exact first redaction succeeded,
second or extra-diff mutation failed, and DELETE failed.

This closes the original Review06 append-only graph defect at plan/fence level.

### UDF arity, safe JSON, and GRDB/Swift API probes

Static parsing of the two normative trigger calls found exactly:

- `deleteIngestion`: 53 arguments;
- `deleteResult`: 63 arguments.

The receipt safe-JSON allowlist contains 23 unique keys and the event allowlist
contains 21 unique keys. Both UDF-gated DELETE trigger bodies contain every
respective key and the exact `json_each(...) = 23` / `= 21` cardinality checks.

With the repository-resolved GRDB 7.11.1 and Swift 6 strict concurrency, a
standalone temporary target compiled and ran probes for:

- `Configuration.prepareDatabase`;
- variadic `DatabaseFunction(argumentCount: nil, pure: false)`;
- `Database.sqliteConnection`, `Database.isInsideTransaction`, and
  `sqlite3_get_autocommit` via `GRDBSQLite`;
- `Database.changesCount`;
- `Database.afterNextTransaction` commit and rollback callbacks;
- `DatabasePool.writeWithoutTransaction` with autocommit enabled.

The probe result was:

```text
PASS prepares=1 commits=1 rollbacks=1
```

The declared APIs and the 53/63 UDF surface are therefore otherwise
implementable. A separate real lifecycle probe exposed the connection-close
gap in R7-P1-2.

### Product semantics, owners, and Open Questions

The accepted product distinctions remain represented at plan level:

- exact-profile resolution, durable work/attempt ownership, bounded
  cancellation, terminal proposal recovery, Outcome/Verification/Acceptance,
  Grant external-effect recovery, schedule replay, and memory provenance keep
  their previously assigned owners and fail-closed gates;
- ordinary active-Ingestion deletion is separate from Camp deletion:
  `resultOnly` and `sourceAndResult` have exact row/count semantics,
  `everythingIncludingProjection` is unsupported before any write, and
  candidates/links remain non-deletable;
- the command factory, sealed handle, same-key replay, resolution-only path,
  initial outbox, four UI phases, and safe-preview/privacy boundaries are
  consistently assigned;
- Camp retirement/deletion authority is not broadened into ordinary Store,
  Engine, Grant, provider, filesystem, or generic callback APIs.

Current Store, controller, adapter, application, UI, migration, provider,
Engine, scheduler, and lifecycle source owners were compared with the Plan's
allowed-file and ownership tables. No additional product-semantics or
file-scope blocker was found beyond the two P1 findings below.

Both frozen documents' `Open Questions` sections contain exactly:

```text
无。
```

R7-P1-1 and R7-P1-2 show that two implementation contracts are nevertheless
still unresolved.

## Prior-review finding disposition

The disposition below distinguishes closure of the original finding from a
newly discovered contradiction in a later revision.

| Source | Finding IDs | Review07 disposition |
|---|---|---|
| Review01 P0 | `P0-1`, `P0-2`, `P0-3`, `P0-4`, `P0-5`, `P0-6`, `P0-7`, `P0-8`, `P0-9`, `P0-10`, `P0-11`, `P0-12` | **Closed at plan level.** Durable attempts, exact profiles, atomic planning, command/CAS ownership, parsing recovery, C/D ordering, verification reduction/invalidation, Grant effects, Engine/Run ownership, schedule replay, and concrete schema/file scope are now assigned with tests. |
| Review01 P1 | `P1-1`, `P1-2` | **Closed at plan level.** Multi-aggregate event idempotency and introducing-slice migration verification are explicit. |
| Review02 P0 | `R2-P0-1`, `R2-P0-2`, `R2-P0-3`, `R2-P0-4`, `R2-P0-5` | **Closed at plan level.** Exact catalog/credential policy, bounded shutdown, Grant acceptance boundary, terminal truth, and Camp deletion semantics have normative owners and gates. |
| Review02 P1 | `R2-P1-1`, `R2-P1-2`, `R2-P1-3`, `R2-P1-4`, `R2-P1-5`, `R2-P1-6`, `R2-P1-7` | **Closed at plan level.** Store API, cancel races, derived input hash, retry acceptance artifacts, checked usage, Outcome policy, and input schema are concrete. |
| Review03 P0 | `R3-P0-1`, `R3-P0-2`, `R3-P0-3`, `R3-P0-4` | **Closed at plan level.** Retirement, crash-unknown Grant truth, durable dispatch boundary, and pending terminal proposal/blob recovery have exact state and recovery contracts. |
| Review03 P1 | `R3-P1-1`, `R3-P1-2`, `R3-P1-3`, `R3-P1-4`, `R3-P1-5`, `R3-P1-6`, `R3-P1-7` | **Closed at plan level.** Canonical output, non-null hashes, waiting state, artifact replay identity, context hash, authoritative Outcome transitions, and input tombstones agree. |
| Review04 P0 | `R4-P0-1`, `R4-P0-2`, `R4-P0-3`, `R4-P0-4` | **Closed at plan level.** Retirement authority/recovery, privacy erasure, legacy scope, and owner/provider enforcement are assigned and fail closed. |
| Review04 P1 | `R4-P1-1`, `R4-P1-2`, `R4-P1-3`, `R4-P1-4` | **Closed at plan level.** Candidate status, Outcome-version command, exact GC root, and no-guess artifact classification are resolved. |
| Review05 P0 | `R5-P0-1`, `R5-P0-2`, `R5-P0-3`, `R5-P0-4` | **Closed at plan/fence level.** Proposal closeout, artifact resolution, exact tombstone/field shape, and one-shot retained-evidence locks are represented and passed targeted raw-SQL checks. |
| Review05 P1 | `R5-P1-1` | **Original defect closed.** The unresolved-table SQLite 3.52 failure no longer occurs and both SQLite lanes execute. The later literal-fence/ordinal contradiction in R7-P1-1 is distinct. |
| Review06 P0 | `R6-P0-1` | **Closed at plan/fence level.** All nine append-only carriers have the required introduction/replacement guards and exact `67/84` final counts. |
| Review06 P1 | `R6-P1-1` | **Closed at plan level.** The ordinary Feed/Rumination delete replacement now has exact scope, evidence, UDF, Store, race, replay, and UI contracts. |

## Bounded R7 pre-review finding disposition

| Finding | Review07 disposition |
|---|---|
| `R7-pre-P0-1` | **Closed at plan level.** Permit generation, ordered mutation, row counts, canonical snapshots, and same-transaction evidence cover all four counterexamples. |
| `R7-pre-P1-1` | **Closed at plan level.** Five blocker counts are bound through command, receipt, event, permit, live revalidation, and race tests. |
| `R7-pre-P1-2` | **Closed at plan level.** Prepare-once opaque pending state and same-key execute/resolve/replay prevent refresh from minting another command. |
| `R7-pre2-P1-1` | **Closed at plan level.** Caller facts are absent from the request; the Store owns read-snapshot derivation and writer revalidation. |
| `R7-pre2-P1-2` | **Partially reopened.** Exact pointer+nonce lookup, writer/autocommit checks, generation invalidation, and 53/63 UDF plumbing are specified, but connection-close weak cleanup has no implementable public GRDB path; see R7-P1-2. |
| `R7-pre2-P1-3` | **Closed at plan level.** Full envelope/event/outbox identity, safe JSON, privacy, and four UI phases agree. |
| `R7-pre3-P1-1` | **Closed at plan level.** Commit resolution has one SELECT-only validator path and explicit committed/notCommitted/pending dispositions. |
| `R7-pre4-P1-1` | **Closed at plan level.** The same shared validator is rerun after same-key absence and before permit/evidence installation. |
| `R7-pre5-P1-1` | **Closed at plan level.** Both validator modes reconstruct the 7-field envelope, 19-field payload, and canonical command whole hash instead of trusting persisted hash copies. |

## P0 findings

无。

## P1 findings

### R7-P1-1 — The v16 literal SQL fence contradicts its normative trigger ordinal gate

Stage lines 5585–5600 make actual Swift migration order normative and require
every `CREATE TRIGGER` to occur after the same fence's final
`table/index/drop/rename statement` and explicit backfill/assertion barrier.
Plan lines 1510–1513 repeat:

```text
tables/indexes → copy/backfill/assertion → drop/rename → triggers
```

The literal v16 SQL fence does not have that order:

- last structural table/index statement: Stage line 4336;
- phase barrier: Stage line 4340;
- first `CREATE TRIGGER`: Stage line 4345;
- later `DROP TRIGGER event_no_update`: Stage line 5389;
- later `DROP TRIGGER verification_record_reject_update`: Stage line 5449;
- later `DROP TRIGGER acceptance_record_reject_update`: Stage line 5490;
- later `DROP TRIGGER external_operation_receipt_reject_update`: Stage line
  5524.

Fifty-six `CREATE TRIGGER` statements precede the final `DROP TRIGGER`. The
fence executes under SQLite 3.51 and 3.52, but a literal ordinal assertion
using the frozen term `drop` must fail. Restricting `drop` to `DROP TABLE`
would pass, but neither Stage nor Plan provides that carve-out. Conversely,
hoisting the four replacement drops changes the displayed normative fence
order.

An implementer/test author must therefore invent whether the rule means all
DROP statements or only structural table-graph drops. That violates the
repository's no-unplanned-decisions rule and makes the required compatibility
test non-deterministic.

Required revision: choose and encode one exact contract in both frozen inputs:

1. move all four `DROP TRIGGER` statements before the phase barrier/first
   `CREATE TRIGGER`; or
2. explicitly narrow the ordinal rule to table/index graph statements
   (`CREATE TABLE`, `CREATE INDEX`, `DROP TABLE`, and table rename) and state
   that `DROP TRIGGER`/`CREATE TRIGGER` replacement pairs belong to the final
   trigger-install phase.

Then update the literal ordinal test description, refreeze both inputs, and
rerun Review07.

### R7-P1-2 — GRDB cannot deliver the specified connection-close cell cleanup through the authorized API

Stage lines 1397–1405 and Plan lines 1627–1635 require:

1. `Configuration.prepareDatabase` creates one cell per actual connection;
2. a GRDB `DatabaseFunction` closure strongly captures that same cell;
3. the AppDatabase registry retains only a weak exact-key entry;
4. closing the connection invalidates the cell and clears the weak entry.

Plan lines 1909–1915 make weak cleanup and pointer reuse explicit acceptance
tests.

With the repository-resolved GRDB 7.11.1, those requirements cannot all hold
through the authorized public surface:

- GRDB `Database` strongly stores each registered `DatabaseFunction` in its
  `functions` dictionary
  (`.build/checkouts/GRDB.swift/GRDB/Core/Database.swift:448-449`,
  `777-779`);
- `Database.close()` closes SQLite and sets `sqliteConnection = nil`, but does
  not remove stored functions (`Database.swift:656-697`);
- therefore the `DatabaseFunction` continues strongly retaining its closure
  and the required strongly captured cell after connection close;
- GRDB's `Configuration.onConnectionWillClose` /
  `SQLiteConnectionWillClose` seam is internal, not public
  (`GRDB/Core/Configuration.swift:457-473`). A Swift 6 type-check against the
  resolved dependency returns:

```text
'onConnectionWillClose' is inaccessible due to 'internal' protection level
```

A standalone runtime lifecycle probe using the specified
`prepareDatabase` + `DatabaseFunction` pattern produced:

```text
afterOpen=true
afterClose=true
afterPoolScope=true
afterPoolScopePlus1s=false
```

The weak cell is still alive immediately after `pool.close()` and after the
pool leaves its lexical scope; it is released only when GRDB later deallocates
the owning connection objects. That is not the frozen contract's
connection-close cleanup.

The Plan does not authorize an AppDatabase-owned close seam, registry-wide
lifecycle invalidation, raw `sqlite3_create_function_v2` destructor ownership,
or a GRDB patch. The current `AppDatabase.pool` is public, so merely adding an
unmentioned wrapper would also leave direct `pool.close()` as a bypass. An
implementer must invent a lifecycle architecture or weaken the acceptance
test.

Required revision: select one exact supported design and assign its owner,
allowed files, bypass prevention, and tests. For example:

1. add one controlled `AppDatabase.close` lifecycle seam that invalidates and
   removes every exact registry entry before closing, and prevent direct
   `pool.close()` bypass; or
2. explicitly change the contract to owner/deinit-time cleanup and rewrite the
   weak-cleanup/pointer-reuse test and safety argument; or
3. explicitly authorize a raw SQLite `xDestroy`-owned registration path and
   define how it replaces or complements the currently normative GRDB
   `DatabaseFunction` registration.

This choice cannot be left to the implementer.

## Limitations and remaining gates

- This is a frozen Stage/Plan review, not product implementation or P0 final
  acceptance.
- External CLI negative UDF behavior was executed. The legal registered-UDF
  deletion paths cannot be run through the real product because the planned
  Store/registry/UDF do not yet exist; they remain implementation-stage tests.
- The standalone Swift/GRDB probes validate API availability and expose the
  lifecycle contradiction, but do not substitute for the required same-real-
  migrator 3.51/3.52 implementation lanes.
- Product code remains zero-diff. P0 final acceptance-audit entry, A1a, and
  every later P1 slice remain closed until both P1 findings are revised,
  refrozen, and independently cleared.

## Ending integrity

- Stage SHA-256:
  `683a876410689592e5ca7972e1e8206e6763f9baf2da4695ce47bc6b2ab8e40e`
- Plan SHA-256:
  `c7f6e26a10e622e47296a3eb2c2163ec989e26ed519b5d9db8d0ed1b51d25df3`
- Product-code diff: zero.
- Review07 repository write: only
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/07-p1-plan-review.md`.
