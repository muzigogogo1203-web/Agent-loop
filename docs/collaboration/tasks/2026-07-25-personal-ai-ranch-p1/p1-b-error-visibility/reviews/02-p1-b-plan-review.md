# P1-B Responsibility-Isolated Plan Review02

> Date: 2026-08-11
>
> Reviewer: responsibility-isolated P1-B Candidate 03 Revision 01 plan reviewer
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 7 P1 / 1 P2**

## 1. Review boundary and independence

This review started from the frozen Candidate 03 Revision 01 bytes and did not
trust Candidate 03's consistency audit or Review01's conclusions. It was
read-only except for creation of this exact Review02 file. It did not run tests,
builds, migration runners, matrix scripts, the App, a preview, or any command
that could touch normal data, Keychain, providers, MCP processes, or user
processes. It did not modify product, test, Package, script, evidence,
historical acceptance, `plan.md`, `try-question-mark-inventory.md`, or
`blocked.md`.

The review reread and compared:

- the accepted master spec, canonical P1 Stage/Plan, and accepted P1-A4
  boundary;
- immutable `reviews/01-p1-b-plan-review.md` and every one of its 6 P1 / 2 P2
  corrections;
- all three Candidate 03 Revision 01 planning artifacts;
- current pathname-exact production/test signatures and call graph where the
  candidate depended on an existing callable or compatibility boundary.

The frozen candidate hashes before this review file was created were:

```text
plan.md                         4edeb7160be8050b90ed9372fae29d17b6deccc2b51099e21db1706e1ea19ed6
try-question-mark-inventory.md  9a430f3a29fa2f7b80f7c16e8f2c1287760481fa0a37037b200f37e3000c6a82
blocked.md                      49983a3bd977144e449a819c0808e1d47b662961bf5f3f2f7959d664b85b130a
```

## 2. Independently verified closure and arithmetic

The following contracts are sufficiently closed and should not be reopened
merely because the overall verdict is changes-required:

- The implementation allowlist is exactly 59 paths: 23 Core, 5 Application,
  13 App, 15 tests, and 3 Package/matrix paths. The ten named new source/test
  paths are absent at entry. No current signature check established a required
  sixtieth path.
- Stage §18.3's v13 SQL fence is byte-identical to the candidate's 49-line
  fence and has SHA-256
  `a0fe7c90723220a8e5a1402cc9f9b1997e04cf2d8a45de6474e8e5f9b599f087`.
  The v13 31-table / 65-index / 4-trigger checkpoint, eight predecessors,
  rollback/replay lanes, and no-v14 boundary remain coherent.
- The entry literal inventory is 131: 129 production occurrences plus exactly
  the two honest MCP fake-helper rows. The entry production catch snapshot is
  133. The raw-formatter snapshot is 84 named lexemes plus two reflected-type
  occurrences. The existing equivalent ledger parses as 104 with the stated
  69 typed / 12 capture / 23 approved-residual split. The planned-new ledger
  parses as ten with the stated 3 / 6 / 1 split, and the two N sets are
  disjoint, producing 114 unique N tags.
- The descriptor arithmetic before primary projection is internally
  reproducible: 379 total descriptors, two nonproduction helpers, 377
  production descriptors, and three two-variant descriptors produce 380
  production variants. The independently derived DelegateEdge tuple set is
  117 with the closed `DE-001...DE-117` range.
- The candidate adds exactly 46 ordinary non-parameterized `@Test`
  declarations: 18 + 13 + 3 + 7 + 5. The current anchored source baseline is
  667 tests and seven suites, so the intended terminal arithmetic is 713 / 7.
- Review01 P1-01's isolated `persistPrepared` fallback is now explicit for the
  MCP, required-context, and optional-context post-upsert statement faults.
  Review01 P1-02's exact search-key handoff and fail-before-read CLI unsupported
  capability rule are present. Review01 P1-03's Core snapshot bundles,
  Database-parameter helpers, injected defaults, and synchronous bootstrap
  types are declared. Review01 P1-05's closed operation/scope/code registries
  and metadata validators are materially specified. Review01 P2-01's ordering
  is now commit < awaited event sink < ready < dispatch. Review01 P2-02 now uses
  Unicode scalar/code-point count, matching SQLite `length(TEXT)` for the safe
  valid strings this formatter permits.
- The DEBUG/release source, target, product-link, output-file-map, object,
  symbol, and process-ownership gates are substantially more exact than
  Candidate 02. Finding P1-07 is a semantic contradiction in the preview
  composition, not a rejection of those artifact-resolution algorithms.

These checks do not cure the seven blocking findings below.

## 3. Findings

### P0

0.

### P1-01 — The frozen 149-primary projection is mechanically false

**Evidence**

Plan §6.1 lines 1816–1831 and inventory §10.1 lines 981–993 require the 377
production descriptors' primary-seam set to equal all 151 enum cases minus only
`orchestratorAddBudget` and `orchestratorRetryCard`, for exactly 149 cases.

A fresh relational expansion of the literal, E, existing-N, planned-N, and
execution-only registries produces only 148 unique primary seams. In addition
to the two named Orchestrator cases, `inputSaveReview` is never a primary. Its
only registry appearances are the composed root/additional App edge for
`E[.ruminationMaterializeView]` (inventory lines 1109 and 1127), whose frozen
primary is `inputMaterialize`. The expected-counter union can still contain all
151 cases through nested occurrences; that does not change the primary
projection.

**Impact**

The exact primary-set gate must fail on conforming source. An implementer must
either falsify the hard-coded expected set, reassign descriptor semantics, or
add/split a descriptor and change the 379/377/380 counts. All are unplanned.

**Required correction**

Choose and freeze one internally consistent registry. If the current
descriptor semantics remain, change the projection to 148 and identify all
three nested-only case values. If `inputSaveReview` must be primary, freeze the
exact descriptor/variant change and recompute every affected descriptor,
variant, owner, and edge count. Add a planning-time mechanical projection
transcript before the next freeze.

### P1-02 — `captureAsyncStream` requires a new catch that the closed ten-row manifest forbids

**Evidence**

Plan §6.1 declares `captureAsyncStream` and lines 1733–1746 state that each of
the four capture adapters owns one exact marked catch. The planned-new-catch
manifest at inventory lines 951–967 contains `captureSynchronous`,
`captureAsyncLoad`, and `captureAsyncOperation`, but no
`captureAsyncStream`/`asynchronousWorkflowStream` row. The manifest is declared
closed at ten rows and the lexical catch gate rejects every unlisted new catch.

`E[.chatServiceStreamRethrow]` does not supply that missing row. It is an entry
catch descriptor for the existing `ChatService.send` stream-finishing catch;
moving its lexical marker to the new Application file violates the
pathname/tag entry mapping, while retaining it still leaves the new async
adapter catch unclassified.

**Impact**

The exact stream API cannot be implemented as specified without an eleventh
new catch, an illegal path-move of an E marker, or an unplanned catch-free task/
result algorithm with different cancellation and task-ownership semantics.

**Required correction**

Add and classify the exact stream-adapter catch, then recompute the
114-N/379-descriptor/377-production/variant/owner totals; or freeze a complete
catch-free implementation whose task and cancellation semantics preserve
§6.1. Do not leave that choice to implementation.

### P1-03 — OAuth authorization/callback cleanup has no generation-safe pending identity

**Evidence**

The exact API exposes
`retryOAuthCallbackCleanup(flow:trace:)` (plan lines 3871–3874), and the
coordinator exposes unconditional `discardAuthorizationState(flow:stateStore:)`
(lines 4305–4308). The retry contract says only that it may discard state, stop
the listener, and reload (lines 3935–3943). It carries no expected state,
generation, listener identity, opaque authorization lease, or compare-and-set
receipt.

Therefore callback A can commit credentials and fail cleanup; a new
authorization B for the same flow can then replace the state/listener; retry A
will unconditionally discard B's state and stop the shared listener. The plan
neither forbids beginning B while A cleanup is pending nor makes A's cleanup
conditional on the preparation it owns. The same lifecycle is incomplete on
the preparation side: the frozen order starts a listener before compensated
state/verifier preparation (lines 3901–3910), but a preparation failure that
returns not-committed has no rule to stop that newly started listener.

The browser-open recovery has the same identity gap: the plan promises to
reopen only the same URL, but a later preparation can supersede the state behind
that URL and no callable/receipt validates the generation.

**Impact**

A cleanup-only retry can destroy a newer authorization, and a not-committed
preparation can leave an unowned local listener active. This violates the
candidate's own no-repeat/no-cross-operation rule and makes correctness depend
on timing outside the exact API.

**Required correction**

Freeze one opaque authorization-preparation/pending-cleanup receipt that binds
flow, expected state/generation, and listener ownership. Cleanup/reopen must
consume or compare-and-set only that receipt; alternatively freeze an explicit
single-active-flow rule that blocks replacement until cleanup. A listener
started by a preparation that does not commit must be stopped before the
not-committed terminal. Add overlap, stale-cleanup, stale-reopen, and
preparation-failure listener cases without exposing secret state in evidence.

### P1-04 — The API-key attachment branch misclassifies a partial mutation as a visibility failure

**Evidence**

Plan §5.2 lines 548–553 defines
`.committedWithVisibilityFailure` only after the known mutation has committed;
the UI may refresh/reconcile and must never repeat that mutation. Lines
3878–3892 instead define `.apiKey` as two required mutations—Keychain credential
write followed by conditional default-profile credential attachment—and say an
attachment failure after the Keychain write is committed-with-visibility. They
then permit retrying the same command to reapply the credential and still-
missing attachment.

That is not a reload/notification failure. The command's required DB attachment
has not committed, the fixed UI text would say the operation completed, and the
only stated retry repeats the original credential mutation despite the outcome
contract forbidding it. `OperationCommitOutcome<Void>` carries neither a
partial-commit receipt nor an attachment-only recovery capability.

**Impact**

The controller cannot truthfully represent the terminal. A conforming UI must
either claim a partially completed credential configuration is complete or
violate the no-repeat invariant to finish it.

**Required correction**

Make credential+required attachment one compensated operation, or introduce a
closed partial-commit terminal/opaque receipt and an attachment-only retry that
never rewrites the credential. Define the authoritative profile/cache state and
visible message for that terminal. Do not use the generic visibility-failure
case for an unfinished required mutation.

### P1-05 — Several promised post-commit recovery actions have no legal exact callable

**Evidence**

The split-commit table promises:

- proposal enqueue followed by attach/event failure offers link reconciliation
  only;
- an already changed rate-limit cooldown retries event append only;
- accepted closeout with failed report/distillation retries report/distill only;
- an already generated report retries presentation only;
- failed OAuth browser opening reopens the same prepared URL only.

The exact Mission/Orchestrator controller appendix (plan lines 3012–3134 and
the traced Orchestrator overloads) exposes no proposal-link reconciliation-only
call, no rate-limit-event append-only call, and no accepted-Mission
distillation-only call. Reinvoking confirm, cooldown/provider execution, or
closeout crosses the commit point again. Lines 5295–5302 explicitly require
real-distillation retry without repeating acceptance/fallback note, but name no
callable or receipt that can do it. The same absence exists for reopening a
prepared OAuth URL.

The document boundary is also type-inconsistent. `openReport` and
`revealReport` return
`OperationCommitOutcome<DocumentPresentationReceipt>` (lines 3058–3065), while
lines 3180–3184 require a rejected/throwing presentation after report creation
to be committed-with-visibility and retry presentation without regeneration.
On that failure no `DocumentPresentationReceipt` exists, so the generic
committed terminal has no truthful `Value`. Constructing a receipt anyway would
project failed presentation as delivered; rerunning the method regenerates the
report contrary to the retry rule.

**Impact**

The user-visible recovery actions required by §5.2 cannot be wired without
inventing private APIs, repeating committed mutations, or forging success
receipts. The internal `committedVisibilityFailureCannotRepeatMutation` table
cannot exercise real recovery for these branches.

**Required correction**

Freeze exact idempotent recovery callables and the minimum opaque receipts for
proposal linking/event, cooldown event append, accepted-Mission distillation,
existing-report presentation, and prepared-URL reopen. Correct the report
outcome value so a failed presentation carries the known generated URL/plan,
not a nonexistent success receipt. Map each recovery to its App action,
operation/trace rule, seam/descriptor, and no-repeat test case.

### P1-06 — The equivalent-fallback gate still cannot prove absence of unclassified fallbacks

**Evidence**

Review01 P1-04 required a complete negative gate, not only a tagged list. The
104-row §9.1 table (inventory lines 731–852) has no entry pathname, containing
declaration, lexical anchor, or marker-adjacency rule for most rows. Lines
854–866 say the source scanner covers `??`, optional/Result projections,
ternary/default branches, guard-return/continue, `compactMap`, ignored
Bool/count, nonthrowing swallow, force operations, and raw formatting, but do
not define the lexical/AST association algorithm or a closed harmless-syntax
allowlist.

Those broad syntaxes occur substantially more often than the 104 semantic
business decisions. Comparing 104 marker/tag values proves only that the listed
decisions were marked. It cannot distinguish an unmarked business fallback
from an ordinary optional/default/guard use, and the final source-gate prose at
plan lines 6054–6059 adds no executable rule. In contrast, the catch gate does
freeze a lexical scanner and first-body-line marker contract.

**Impact**

An implementation can preserve all 104 markers and still introduce or retain
an unclassified `??`, early return, ignored Boolean/count, or compact-map
fallback. A stricter implementation cannot scan every such Swift syntax
without false positives. The implementer must invent the semantic classifier,
which is the exact gap Review01 asked the revision to close.

**Required correction**

Freeze pathname + containing declaration + exact lexical anchor/adjacency for
every equivalent decision, and independently freeze the complete allowed
non-business syntax set or a deterministic Swift-syntax algorithm that proves
all remaining candidates harmless. The negative gate must fail on one injected
unmarked equivalent even when all 104 expected tags remain present.

### P1-07 — The mandatory bootstrap and zero-Keychain preview evidence cannot both be true

**Evidence**

`SynchronousRuntimeBootstrap.run` is the only frozen synchronous AppStore
bootstrap. Plan lines 4132–4137 require every run to begin with one synchronized
credential-presence critical section reading all four accounts, before seeding
and the runtime bundle read. The failure preview only injects
`RuntimeWorkflowReads(load:)`: its synchronous-bootstrap read succeeds and its
first controller refresh throws (lines 5436–5443). No exact bootstrap
credential-presence override exists.

At the same time, credential audit hooks fire immediately before any store read
(lines 5535–5540), the failure preview is said to use only the injected Runtime
DB read and no credential hook (lines 5554–5556), and both previews must report
`keychainRead == 0` and `keychainWrite == 0` (lines 5615–5626).

**Impact**

Running the mandatory bootstrap increments credential reads; bypassing it,
installing hooks only afterward, or substituting an unaudited fake makes the
zero-contact evidence false. The exact API offers no legal implementation that
satisfies both contracts.

**Required correction**

Freeze an explicit preview-safe credential-presence input/port consumed by the
same bootstrap algorithm, and state exactly how the audit proves zero real
Keychain contact. The hook must dominate every real credential-store access
from process start. Add a deliberate canary read proving the audit would become
nonzero/fail, while both real preview paths stay zero. Do not silently skip the
bootstrap or attach the audit after it.

### P2-01 — MCP pending cleanup exposes the trace capability that prose says does not cross into App

**Evidence**

`McpPendingRollbackCleanup.traceScope`,
`McpPendingDeletedServerCleanup.traceScope`, and
`McpPendingServerCleanup.traceScope` are all `package` (plan lines 4446–4480).
Lines 4696–4701 nevertheless state that only `serverId` and the Equatable value
cross into App, while the lease/scope capability remains Application-internal;
lines 4707–4711 require only the controller to mint the cleanup trace.

Because AgentLoopApp is another target in the same package, `package`
`traceScope` is readable there. The lease fields and initializers are correctly
internal, but the retained trace capability is not.

**Impact**

The source can still be made correct by convention/source scanning, but the
claimed API sealing is false and an App caller can mint an unrelated valid
cleanup trace from the pending value.

**Required correction**

Make pending `traceScope` internal to AgentLoopApplication and let only the
controller's same-target implementation consume it. Keep only the derived
display `serverId` and opaque Equatable pending value visible to AgentLoopApp.
Update the compile/source fixtures to prove the property is inaccessible across
the target boundary.

## 4. Review01 closure disposition

Review01's original findings are not being repeated wholesale:

- P1-01 atomic fallback: closed by the exact isolated original-prepared write
  and statement-fault owners.
- P1-02 context handoff/CLI: closed by one search read, exact ready payload, and
  fail-before-read explicit CLI blocking.
- P1-03 bundle/bootstrap boundary: the Core/Application APIs now exist, but the
  new preview contradiction in P1-07 prevents approval.
- P1-04 equivalent fallback: the positive 104-row ledger exists, but its
  negative completeness proof remains open as P1-06.
- P1-05 metadata/codes: materially closed by the exhaustive registries and
  validators inspected.
- P1-06 exact APIs: materially improved, but P1-02 through P1-05 and P1-07 are
  exact callable/terminal gaps that still force unplanned choices.
- P2-01 event ordering: closed.
- P2-02 SQLite length unit: closed.

## 5. Verdict and next legal action

**CHANGES REQUIRED — 0 P0 / 7 P1 / 1 P2.**

Candidate 03 Revision 01 is not implementation-ready. Its migration, scope,
entry counts, most registry arithmetic, snapshot boundaries, failure metadata,
atomic fallback, context capability handoff, and artifact gates are strong, but
the primary projection, stream-catch manifest, OAuth lifecycle, partial
credential terminal, post-commit recovery APIs, equivalent-negative gate, and
preview bootstrap are not decision-complete.

The next legal action is planning-only: revise only `plan.md`,
`try-question-mark-inventory.md`, and `blocked.md` within these findings;
mechanically recompute every affected count/edge/variant; freeze new candidate
bytes; then obtain a fresh responsibility-isolated Review03. Until that review
returns **APPROVED — 0 P0 / 0 P1**, product, test, Package, matrix, build,
preview, migration, and runtime implementation remain prohibited.
