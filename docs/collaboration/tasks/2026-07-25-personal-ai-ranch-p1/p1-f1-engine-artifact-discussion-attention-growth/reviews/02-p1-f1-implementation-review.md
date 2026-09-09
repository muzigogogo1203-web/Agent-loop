# P1-F1 F1B Revision 3a Implementation Review 02

Date: 2026-08-27

## Verdict

**NEEDS CHANGES — 0 P0 / 1 P1**

This verdict is scoped only to P1-F1 **F1B Revision 3a**. It does not review or
open F1C, F1D, F1E, F1F, or P1-F2 product scope. The review was a
responsibility-isolated static implementation/evidence review; as required, it
did not run builds, tests, migrations, packages, or applications.

F1B cannot close because recovery can heal a persisted R-only synthetic
terminal graph into a different protocol-error terminal. Revision 3a explicitly
requires that an R-only or C-only graph fail with graph-integrity error and
never be healed.

## Authority and evidence reviewed

- root `AGENTS.md` and `docs/collaboration/claude-codex-protocol.md`;
- canonical P1 plan/stage F1B authority and task `plan.md` §§14.1–14.10;
- Review01b plus its approved Revision 3a successor;
- the effective allowlist, entry manifest, red evidence, focused evidence, and
  `impl-report.md`;
- every current F1B product/test file listed by the implementation report.

Independent recomputation produced:

| Check | Result |
|---|---|
| branch | `codex/personal-ai-ranch-p0` |
| effective plan SHA-256 | `ae3162dbe24d2069009e7ffbc33e75b82c31c859a2a658db6bbbf543d7edf609` |
| Review01b current SHA-256 | `b2ae3efb5cbf69aa811313dc80f8c096fde0ae9400502f88d360189c0d972f29` |
| 96-line byte-sorted LF allowlist | `8d4e07d1ccda444a5b5c53ba7951e5514a07d01e9262990bbf2934cad9f50e73` |
| 46-line path-sorted LF entry manifest | `6048f075e2d09b21f5b6d4e56f929d81fe1ec72441e336cfaa98e356de8b9924` |
| live dirty/allowlisted/outside counts before Review02 | `646 / 56 / 590` |
| outside manifest v1 | `ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee` |
| Revision 3 red evidence SHA-256 | `7d1d22b4f63b86c29e08cf359f99b650cdc09b6c44294d623967f42ecee91143` |
| red evidence process statuses | command `1`, tee `0` |
| focused evidence SHA-256 | `4657f0e218cb468726bbb89366a2651d29f870b67676cdbb4ecf30751f4c0a9b` |
| focused evidence result | exact F1B identities `017–042`: 26/26 passed in 3 suites; command `0`, tee `0` |
| exact source declarations | all 26 manifest identities occur exactly once in their declared files |
| `impl-report.md` SHA-256 | `097075ff622d05b47f33a43d50d8b8e1ae1d6a783a2c5a1b14fe98d1be3649ba` |
| `git diff --check --` | exit `0` |
| no-index whitespace check for all 12 F1B product/test files | 0 problem files, 0 check errors |

The live F1B file hashes also match `impl-report.md`: `EventKind.swift`
`caf837ec...`, `CommandEnvelope.swift` `b6b5bea9...`, `DomainEvent.swift`
`04477e6c...`, `DomainEventStore.swift` `22ac30cc...`,
`ExecutionEngine.swift` `bf394cad...`, `EngineExecutionReceipt.swift`
`ab77296c...`, `EngineSessionStore.swift` `6aacd5d6...`,
`EngineExecutionStore.swift` `2654d6ae...`, and the four test files
`317fcab6...`, `67a59a73...`, `e94237ae...`, `fcaaff1e...`.

## Conforming areas

The static review found the following Revision 3a areas conforming within the
reviewed bytes:

- the engine aggregate/command/event/result/audit vocabulary is closed, has the
  exact persisted spellings, and is not added to legacy
  `EventKind.allPersistedKinds`;
- safe receipt/event/outbox carriers exclude request/context, model/workspace,
  external-session, reason-detail, prompt/options, and path/label material;
- strict command replay validates receipt, ordered event, scope, and outbox
  linkage; Engine Store does not directly insert into the shared receipt/event/
  outbox tables;
- the first-write FK deferral is transaction-bounded, active exact-version and
  legacy-archive fences are present at production write entry points, and
  recovery reads lifecycle before erasable request/session/proposal material;
- caller session selection cannot claim an external session ID, while resolved
  canonical requests carry the Store-owned internal/external pair;
- terminal receipt taxonomy, one-event/two-event attention topology, real
  proposal linkage, terminal result hash, synthetic R+C keys, and no-sequence-
  consume behavior match the plan on the intact paths exercised by the current
  tests;
- no F1C artifact staging/GC, F1D adapter authority, F2 permit/deletion
  authority, schema migration, package dependency, or `attention_item` write was
  introduced by this F1B correction.

## Finding

### P1-1 — Recovery heals an R-only synthetic terminal graph

Revision 3a §14.9 requires exact synthetic replay to validate both R and C
graphs and states that only R, only C, missing proposal, or linkage drift is a
`DomainCommandGraphIntegrityError` that is never healed (`plan.md:1354–1360`).
The implementation enforces the R/C presence equality only when
`commitSyntheticTerminalInTransaction` is called
(`EngineExecutionStore.swift:1383–1413`). Recovery takes a different path:

1. A valid synthetic R uses `consumeSequence: false`, so its pending proposal
   sequence equals the unchanged execution `nextSequence`.
2. `recoverySnapshot` assumes every pending proposal consumed one sequence and
   requires `execution.nextSequence == proposal.sequence + 1`
   (`EngineExecutionStore.swift:2150–2158`). An R-only synthetic graph therefore
   throws `EngineTerminalConflictErrorV1` before the strict R graph is replayed.
3. Recovery catches that error and calls `commitRecoveryProtocolError`
   (`EngineExecutionStore.swift:1958–1967`). When a pending proposal exists,
   that function directly writes a new invalidating terminal command
   (`EngineExecutionStore.swift:2388–2415`). It neither checks that the original
   synthetic C is absent as an integrity failure nor replays/validates the
   original R receipt/event/outbox graph.

The result is a durable write that converts precisely the forbidden R-only
state into a different protocol-error terminal. Corrupt or partial append-only
command history is therefore papered over instead of failing closed. This is a
completion-gate P1, not a hypothetical API-style concern: it is a reachable
branch for the persisted state that §14.9 explicitly requires recovery to
detect.

The current 26/26 focused evidence does not cover this state. Identity 042
exercises recovery and intact synthetic branches, identity 026 replays an
intact pre-dispatch R+C graph, and identity 037 injects failures into a normal
terminal C after an already committed proposal R. None constructs an R-only
synthetic graph or proves that a failure during synthetic C rolls back R, so the
required §14.10 two-command rollback/replay matrix is incomplete at this edge.

Required correction, within the existing F1B allowlist and identities:

1. Before any recovery protocol-error terminalization, distinguish strict graph
   corruption/partial synthetic R+C from a valid pending adapter proposal.
2. Validate the relevant R receipt/event/outbox/proposal linkage and make any
   R-only/C-only or mismatched synthetic graph throw
   `DomainCommandGraphIntegrityError` with zero writes; do not invalidate or
   terminalize it.
3. Strengthen an existing F1B identity, without renaming or adding identities,
   to prove R-only synthetic recovery is never healed and that an injected
   synthetic-C failure rolls the whole outer R+C transaction back. Preserve
   complete surface/projection snapshots and rerun the exact 26-test evidence.

## Final count

- P0: 0
- P1: 1

The independent implementation gate is not met. F1B remains open and F1C must
not start until this finding is corrected, evidenced, and independently
re-reviewed.

## Successor Review — Review02 P1 Correction

Date: 2026-08-27

### Successor verdict

**NEEDS CHANGES — 0 P0 / 1 P1**

This successor review is bounded exclusively to the correction of Review02
P1-1. It does not reopen the conforming F1B areas above and does not review or
open F1C+ scope. The original 7,524-byte Review02 is preserved as the exact
prefix of this file; its SHA-256 is
`d067c234b7afac62f9cfa774b176dc3cb3aeb4969ca98064446c7c26a8688823`.
No build, test, migration, package, or application was run by this reviewer.

### Inputs and independent checks

| Input/check | Independently observed result |
|---|---|
| pure Review02 red evidence | `verify-red.log` SHA-256 `07ff08ebb308c5461b39ea7e98a75a52b6f768416b1fcc6016a9d6d3749813b6`; identity 042 failed; command `1`, tee `0` |
| corrected Store | `EngineExecutionStore.swift` SHA-256 `ab494d0f9a6887dfbd8a795fdf3856c8c1f0bb77e09000e84e468682e6bf6765` |
| corrected recovery test | `CrashRecoveryTests.swift` SHA-256 `0934090114f10a13a52ad89514ec4577e8dbbfec89cde1eaae9ca8892beea708` |
| focused evidence | `focused-verify.log` SHA-256 `a48d099905ffaf72fc953db5ef25974794e547dd0285e417ee1f9b16754feebc`; exact 26 started and 26 passed in 3 suites; command `0`, tee `0` |
| Core build evidence | external complete log SHA-256 `508468812fc0374717c4594452793c1e0df40153725a4399ad5cd0af4050417d`; recorded `Build of target: 'AgentLoopCore' complete!` |
| identity manifest | F1B remains exactly 017–042; all 26 declarations occur once |
| allowlist / entry manifest | 96 lines / `8d4e07d1...`; 46 lines / `6048f075...` |
| live boundary before this append | dirty `648`, allowlisted `58`, outside `590`; outside manifest `ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee` |
| whitespace checks | `git diff --check --` exit `0`; no-index checks of the corrected Store, test, and Review02 had 0 problem files / 0 errors |

### Correctly resolved implementation behavior

The product correction resolves the code-path defect identified by Review02:

- `requireNoSyntheticTerminalHistoryForRunningRecovery` is called only after
  lifecycle existence/state, exact lifecycle version, and legacy archived-bit
  checks (`EngineExecutionStore.swift:1880–1928`). It is before request,
  proposal, descriptor, or session decode and outside the catches that convert
  ordinary recovery identity failures into protocol-error terminalization
  (`EngineExecutionStore.swift:1930–1982`). The preflight is read-only.
- The preflight enumerates exactly the five Revision 3a synthetic terminal keys:
  pre-dispatch failure, usage overflow, prepared cancellation, external-effect
  unknown, and recovery protocol error (`EngineExecutionStore.swift:2138–2144`),
  then checks both exact R and C receipt-key forms
  (`EngineExecutionStore.swift:2155–2172`). Any matching proposal or receipt on
  a still-running execution now throws `DomainCommandGraphIntegrityError`
  before the old healing catches.
- DeletionRequested/deleting deferral and deleted-tombstone/archived handling
  still precede the preflight (`EngineExecutionStore.swift:1886–1910`). Normal
  adapter proposals do not use one of the five exact synthetic keys, so their
  pending-proposal-first recovery path at `EngineExecutionStore.swift:1984–2007`
  remains reachable. The existing focused recovery identity remains green.
- The new identity-042 R-only setup creates a real strict proposal R graph,
  restores the synthetic no-sequence projection, expects the exact graph error,
  and compares the pre/post projection snapshot
  (`CrashRecoveryTests.swift:1887–1940`). The C-fault setup installs a trigger
  that fires only when C changes execution out of `running`, then compares the
  pre/post snapshot after the propagated `DatabaseError`
  (`CrashRecoveryTests.swift:1943–1978`). This is the correct transaction seam.

### P1-S1 — The rollback/zero-write snapshot omits event-scope rows

Review02 required the strengthened identity to preserve a **complete** surface/
projection snapshot and specifically prove that a synthetic-C failure rolls
back R's proposal, receipt, event, **scope**, and outbox. Revision 3a §§14.9–14.10
likewise make scope part of the strict two-command graph and rollback matrix.

Both new counterexamples compare `p1f1EngineProjectionSnapshot`, but its
`P1F1EngineSurfaceCounts` contains executions, runs, legacy/domain events,
outbox, receipts, proposals, proposal artifacts, sessions, and user requests
only (`EngineExecutionStoreTests.swift:229–239`). Its count construction also
omits `camp_event_scope` (`EngineExecutionStoreTests.swift:273–335`). The C-fault
comment claims scope rollback at `CrashRecoveryTests.swift:1943–1945`, but no
assertion observes that table.

This is a material missing surface rather than redundant bookkeeping:
`camp_event_scope` has its own primary key and no foreign key back to
`domain_event` (`AppDatabase.swift:646–658`). A faulty transaction boundary
could therefore leave an orphan R scope row while all currently compared
counts/records return to the stable snapshot, and both new tests would still
pass. The supplied 26/26 evidence consequently does not prove the exact
scope-inclusive zero-write/outer-rollback condition required to close the
original P1.

Minimal required correction, without changing product code or test identity:

1. In identity 042, observe `camp_event_scope` before and after both the R-only
   recovery attempt and injected-C failure. The smallest local correction is an
   exact count/row snapshot query in those two blocks; alternatively add an
   `eventScopes` count to the shared `P1F1EngineSurfaceCounts` helper.
2. Assert exact equality after each thrown error, alongside the existing
   snapshot comparisons, and refresh the focused 26-test evidence. No new test
   name or F1C+ file is needed.

### Successor count

- P0: 0
- P1: 1

The recovery preflight correction is code-complete, but its required
scope-inclusive rollback evidence is not. F1B remains open pending this single
test-evidence correction and a bounded successor review.

## Final Successor Review — Event-Scope Evidence Closure

Date: 2026-08-27

### Final successor verdict

**APPROVED — 0 P0 / 0 P1**

This final successor is bounded only to P1-S1 above. It does not reopen any
other F1B finding or conforming area and does not review F1C+. The prior
13,630-byte Review02 content is preserved as this file's exact prefix, SHA-256
`6232d392230595faff53548290700e537a1523e9964277136a0eeef4ed12cc8c`.
The reviewer did not run a build, test, migration, package, or application.

The remaining evidence gap is closed:

- `P1F1EngineSurfaceCounts` now contains `eventScopes`
  (`EngineExecutionStoreTests.swift:229–240`).
- Both and only both constructors populate it with the exact
  `COUNT(*) FROM camp_event_scope` result
  (`EngineExecutionStoreTests.swift:274–320,673–691`).
- Identity 042's R-only zero-write comparison and injected-C outer-rollback
  comparison both use `p1f1EngineProjectionSnapshot` before and after the
  thrown error (`CrashRecoveryTests.swift:1926–1940,1964–1978`). Because that
  snapshot is `Equatable` through `P1F1EngineSurfaceCounts`, both comparisons
  now directly fail if any R event-scope row is added, removed, or left behind.
  The proposal/receipt/event/scope/outbox rollback claim is therefore observed
  by the asserted surface snapshot rather than inferred.

Independent checks:

| Check | Result |
|---|---|
| corrected `EngineExecutionStoreTests.swift` | SHA-256 `d23e3411d27b78776b7123229a0b66d774f3a97704ac55dad6668b2c15b378ea` |
| unchanged corrected `CrashRecoveryTests.swift` | SHA-256 `0934090114f10a13a52ad89514ec4577e8dbbfec89cde1eaae9ca8892beea708` |
| refreshed focused evidence | SHA-256 `bd1032b14e82d8bb66099e98e051911a862165c81d83e427c23874d94b94c84e`; exact 26 started and 26 passed in 3 suites; command `0`, tee `0` |
| F1B identity manifest | exactly 26 identities, 017–042 |
| allowlist / entry manifest | 96 / `8d4e07d1...`; 46 / `6048f075...` |
| live boundary before this append | dirty `648`, allowlisted `58`, outside `590`; outside manifest `ead67a9d6ff226d2054a5d68f3de6770150989046bd684149c181bff098169ee` |
| whitespace checks | `git diff --check --` exit `0`; relevant no-index checks 0 problem files / 0 errors |

P1-S1 is closed. Together with the preceding successor's verified recovery
preflight correction, the original Review02 P1 is fully resolved. The bounded
F1B Revision 3a implementation review now has **0 P0 / 0 P1**.

---

## F1C Successor Review — Identities 043–061

Date: 2026-08-27

### Verdict

**NEEDS CHANGES — 0 P0 / 3 P1**

This successor is bounded exclusively to the F1C 043–061 implementation. It
does not reopen F1A, the accepted F1B Revision 3a bytes, or any F1D/F1E/F1F/F2
scope. The prior 16,077-byte Review02 content is preserved as this file's exact
prefix, SHA-256
`8a06de21ba238b02afc2030e82414e992b03e005899c875af3554773a7044673`.
The reviewer ran no Swift build/test, migration or SQLite matrix, package,
application, credential/provider, normal-state, Git-write, or external action.

### Authority and evidence reviewed

| Input/check | Independently observed result |
|---|---|
| effective Revision 4a plan | SHA-256 `8dc757ea8286a8f8e4224064d742c10879046c972094f2a04e63eaac7c39cefc` |
| approved Review01c | SHA-256 `d79fe5d8a832c08369a44ffe1698a9c4c189d5e1bfd3a24c56507523bd9b64a4`; final verdict `APPROVED — 0 P0 / 0 P1` |
| immutable exact-19 capability red | SHA-256 `cb4a5b5be4c28af76e085212502844e2a93f69adc71cf5e5d38a0985bc522979`; all 19 discovered and failed; command `1`, tee `0`, validator `0` |
| current focused evidence | SHA-256 `04d1a6441860351837474ad5557da8648e31ccb6ad68c608ebc4b3e74e6a78d4`; exact 001–061 expected/started/passed `61/61/61`; command, tee, and both set checks `0` |
| implementation ledger | `impl-report.md` SHA-256 `dd8c60c839b4e9c8beaccab46dcd355031344843f7b831d9cc53004dd048472d`; `blocked.md` SHA-256 `a024e7ee6fef7bb00ba4a3b1e4c8ffc6ca597b02a71386c62eb2f67077333bf5` |
| machine scope | allowlist 98 / `9c9c0198e7570c56367c83e90e606a888bc08f7e833ed9cd82517bacb4e39020`; entry manifest 47 / `024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a` |
| live boundary before this append | dirty `661`, allowlisted `72`, outside `589`; outside manifest `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |
| protected authorities | Stage, canonical P1 plan, master spec, accepted P1-E evidence, Package resolution, RunTests, canonical coding/JSON, durable-work owners, and all non-successor protected Store/controller hashes match their frozen values |
| whitespace | `git diff --check --` over the F1C product/test/evidence surface exited `0` |

The current functional-owner hashes independently match the implementation
ledger: `Records.swift` `0d2364e4...`, `ArtifactBlobStore.swift` `5177843f...`,
`ArtifactStager.swift` `a36b9524...`, `ArtifactStorageOriginStore.swift`
`39e2cc70...`, `ArtifactOwnershipVerifier.swift` `713c3278...`,
`EngineExecutionStore.swift` `b771100b...`, `BoardCardTransactions.swift`
`c7762797...`, `BoardTools.swift` `343daf95...`,
`ManagedExpeditionReportStore.swift` `4197501b...`, `Orchestrator.swift`
`ef22c392...`, `MissionWorkflowController.swift` `eb72a6e3...`, and
`AppStore.swift` `ebfc75b3...`.

### Conforming F1C areas

The bounded static review found the following areas conforming in the current
bytes, without reopening the component-successor reviews:

- the reviewed declaration-only scaffold preceded the exact-19 runtime red,
  the red remains immutable, every F1C identity is declared exactly once, and
  the final focused evidence includes all accepted predecessor identities;
- v17 record vocabulary, prepared-artifact sealing, existing-blob-first
  validation, ordered staging/fsync/rename/DB CAS, exact three-content-hash GC
  roots, quarantine recovery, and deleted-tombstone restage remain within the
  F1C Store boundary;
- managed/external artifact creation is transaction-local to the Origin Store,
  legacy upgrade consumes sealed evidence with same-handle graph/version
  revalidation, and Engine first commit/replay validates and commits the
  artifact/origin/reference/terminal graph in the outer transaction;
- verifier proof values and root snapshots remain sealed, and its positive and
  unresolved classifications cover the reviewed missing, symlink, permission,
  root, identity/content, hardlink, pending, same-/cross-Camp, and concurrent
  drift counterexamples;
- nonempty raw Board completion authority is removed, the bounded GuideChat
  and Harvest predecessor fixtures use typed external references, and legacy
  Board completion rejects nonempty artifacts before mutation;
- Orchestrator, MissionWorkflowController, and AppStore delegate report work to
  the shared managed Store in production, startup report recovery fails
  visibly, and no F1D terminal sink/adapter, F1E/F1F coordination, Camp
  deletion permit/unlink, or F2 product insertion was introduced.

### P1-F1C-1 — The compile-only scaffold remains in final product and tests

Revision 4 §§15.1 and 15.8 make scaffold removal an explicit F1C completion
condition: `ArtifactCapabilityUnavailableErrorV1` must have zero product/test
references after the exact-19 red. The current final bytes still declare the
entire scaffold vocabulary and error in
`ArtifactBlobStore.swift:5–32`. Two current test branches also retain and
rethrow the scaffold error in `ArtifactBlobStoreTests.swift:424–425` and
`:593–594`.

Those branches no longer contribute behavior after functional implementation,
but their presence violates the temporal exception and would let a future
unavailable throw remain specially accepted by tests instead of being treated
as an ordinary regression. A 61/61 run cannot override the plan's explicit
zero-reference source gate.

Required bounded correction:

1. remove `ArtifactCapabilityV1` and
   `ArtifactCapabilityUnavailableErrorV1` from product code;
2. remove both scaffold-specific test catches while preserving the real-error
   assertions and all 19 identity names;
3. keep the original red byte-identical, refresh exact 001–061 evidence, and
   prove the two scaffold symbols have zero references under `Sources/`.

### P1-F1C-2 — Orphan staging cleanup can follow a raced directory outside the managed root

`ArtifactStager.cleanOrphanedStaging()` delegates to
`ArtifactBlobStore.cleanOrphanedStagingFiles` (`ArtifactStager.swift:55–60`,
`ArtifactBlobStore.swift:300–316`). Its recursive helper is named
`removeDirectoryContentsNoFollow`, but it performs a path-based
`FileManager.contentsOfDirectory`, then a separate `lstat`, followed by
path-based recursion, `unlink`, or `rmdir`
(`ArtifactBlobStore.swift:1294–1316`).

If a checked child directory is replaced by a symlink between `lstat` and the
recursive call, `contentsOfDirectory(atPath:)` follows the replacement. The
subsequent child paths resolve through that symlink, so regular children of an
outside directory can be unlinked. The per-instance `NSLock` does not exclude
another process or Store instance. This is a destructive escape from the
exact Stager filesystem authority and violates §§5.1, 15.3, and 15.8's
no-follow/unsafe-filesystem-owner red line.

Required bounded correction:

1. replace path recursion with descriptor-relative traversal using
   `openat`/`fstatat(AT_SYMLINK_NOFOLLOW)` identity binding and
   `unlinkat`, never following or recursing through a symlink;
2. fail visibly on drift/irregular nodes and fsync the affected managed
   directories; do not catch-and-continue;
3. add a deterministic package-only race/fault seam permitted by §15.1 and
   strengthen an existing 043–052 identity to preserve an outside sentinel
   while the old implementation fails. Do not add or rename an identity.

### P1-F1C-3 — A pre-existing report leaf bypasses intermediate-symlink rejection

The report Store correctly rejects the current identity-061 fixture when the
configured root is missing directly beneath a symlink. It does not reject the
same alias when the final report directory already exists. In
`bootstrapReportDirectory`, `lstat(reportStoreRoot.path)` operates on the full
path; POSIX follows intermediate components. For a pre-existing
`alias/reports`, the resulting directory status is then accepted,
`realpath` canonicalizes it to the outside target, and the code deliberately
opens and identity-binds that target (`ManagedExpeditionReportStore.swift:
565–607`). The later descriptor-relative writes are therefore safe relative
to the wrong root.

This makes behavior depend on whether the escaped leaf existed before startup:
the current test at `HarvestTests.swift:530–556` rejects the absent-leaf case,
while a pre-created `outside/reports` would be accepted and receive the report.
That violates the exact trusted-root/no-follow ownership contract in §§5.3,
15.2, 15.3, and 15.7.

Required bounded correction:

1. extend identity 061 tests-first by pre-creating the escaped report directory
   and proving ensure/regenerate fail with no temp/cursor/final/lock byte outside
   the intended root;
2. bind and traverse the configured root component-by-component without
   silently treating an unregistered intermediate symlink target as the root;
   use a canonical trusted test root where the platform temporary-directory
   spelling itself contains a system alias;
3. retain the existing missing-leaf, mismatch-preservation, cursor-window, and
   same-lock identity assertions, then refresh exact 060–061 and 001–061
   evidence.

### Final count

- P0: 0
- P1: 3

F1C remains open. The reviewed TDD chronology, focused green evidence, typed
artifact graph, raw-authority removal, and report delegation are intact, but
the explicit scaffold-removal gate and both no-follow filesystem-owner gaps
must close before a bounded successor can report 0 P0/P1 or F1D product work
can begin.

---

## Final F1C Successor Review — Three P1 Closures

Date: 2026-08-27

### Final successor verdict

**APPROVED — 0 P0 / 0 P1**

This final successor is bounded exclusively to P1-F1C-1, P1-F1C-2, and
P1-F1C-3 above. It does not reopen any accepted F1A/F1B byte, any other
conforming F1C area, or any F1D/F1E/F1F/F2 scope. The prior 25,545-byte
Review02 content is preserved as this file's exact prefix, SHA-256
`1bd7b6d7a70f5dfbfda9430362e741bd22ab20826d894c6ffdb0e803bc397a72`.
The reviewer ran no Swift build/test, migration or SQLite matrix, package, or
application; the run/build results below are independently inspected evidence.
The reviewer performed only read-only source/evidence inspection, hash and set
checks, the frozen binary boundary serializer, and whitespace checks before
this sole append.

### Frozen authority and final evidence

| Input/check | Independently observed result |
|---|---|
| effective Revision 4a plan / approved Review01c | `8dc757ea8286a8f8e4224064d742c10879046c972094f2a04e63eaac7c39cefc` / `d79fe5d8a832c08369a44ffe1698a9c4c189d5e1bfd3a24c56507523bd9b64a4` |
| immutable exact-19 capability red | `red-f1c-artifact.log` SHA-256 `cb4a5b5be4c28af76e085212502844e2a93f69adc71cf5e5d38a0985bc522979` |
| initial static P1 red / existing-leaf alias red | `9879491cc59ede7270ebc5b4939b56f371cab2b33c54045d02b62abbd24d2330` / `210b634e63634c9462d819e72848d1789cd6dc4c2b2553b991a2ea36b9f8834e` |
| cleanup correction red | `/tmp/p1f1-f1c-cleanup-red.Fo4hym`, SHA-256 `a95c2d17b6ac87477b35fb1257f9307bde8bcc4862bad7151adf8c4cb0f36760`; exact 043–052 started `10/10`; only 046 failed on missing parent-fsync observations and deletion of the moved-out sentinel; command `1`, tee `0` |
| cleanup correction green | `/tmp/p1f1-f1c-cleanup-green.xhjZnH`, SHA-256 `50ca0949c5c9b20c5366be5e0e60e85dabefbaf5062d6b927e09a37c551b8a2f`; exact 043–052 passed `10/10`; command `0`, tee `0` |
| report-root correction red | `/tmp/p1f1-report-root-final-red-r2.YA7R7T`, SHA-256 `23a1672f8cf72988fb9d475267f5039ba734383df9df953433fa5cd94ce9bf58`; identity 061 exposed arbitrary root-owned alias acceptance and the fstatat/openat replacement race; command `1`, tee `0` |
| report-root correction green | `/tmp/p1f1-report-root-final-green.wnKtT8`, SHA-256 `3955bc4f14a30d2ab2c47b79949bdf892f77d4fee18bbb326e97b0bf99468d5f`; exact 060–061 passed `2/2`; command `0`, tee `0` |
| authoritative focused evidence | `focused-verify.log` SHA-256 `c65503ff01454e9d9a2c90f555fa25110784a41bd9b1ab9d22f9a9df3b87373f`; expected/unique, started/unique, and passed/unique are independently parsed as `61/61`, all expected/actual sets equal, command `0`, tee `0` |
| final App build evidence | `/tmp/p1f1-f1c-final-app-build.JYEs3U`, SHA-256 `1675bd6b099ad8a1a6b99d562d622fd633500066318a4abcced7695c37054f68`; build `0`, tee `0` |
| final static evidence | `/tmp/p1f1-f1c-final-static.JuWuNb`, SHA-256 `7c66c37661bf80295b4d731d73dbdfd30a78004036586ca24f66f882358db079`; scaffold zero, cleanup/report gates pass, parse/diff `0` |
| current ledgers | `impl-report.md` `dd8c60c839b4e9c8beaccab46dcd355031344843f7b831d9cc53004dd048472d`; `blocked.md` `a024e7ee6fef7bb00ba4a3b1e4c8ffc6ca597b02a71386c62eb2f67077333bf5` |
| machine scope | allowlist 98 / `9c9c0198e7570c56367c83e90e606a888bc08f7e833ed9cd82517bacb4e39020`; entry manifest 47 / `024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a` |
| live boundary before this append | dirty `661`, allowlisted `72`, outside `589`; outside manifest `792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88` |

Final reviewed owner/test hashes are:

- `ArtifactBlobStore.swift`
  `b241637af1310346e2c403893f16af57bd684c3882f4b70d5b75d9d5d0abbb87`;
- `ArtifactBlobStoreTests.swift`
  `a5d859074c1d34202bba3dab41b2328c7abc6d85fa24daaa6ee8e6c778616d40`;
- `ManagedExpeditionReportStore.swift`
  `b1e69051f928ed248663ebe2f084d1ba2a7a8148d190dc6db5be16e3d4948d67`;
- `HarvestTests.swift`
  `b111dfee8105359b37e1f3e350de223b874569aad5edc3e862f00404f9449427`.

### P1-F1C-1 closed — scaffold authority is gone

Both scaffold symbols now have zero references under `Sources/`. The product
declarations and the two test-only special catches identified above are absent;
real failures therefore pass through the ordinary typed/error assertions. The
immutable original capability red remains unchanged, so removal closes the
temporary compile exception without rewriting its chronology or test identity.

### P1-F1C-2 closed — cleanup stays bound to the managed descriptor graph

Cleanup no longer performs path-based enumeration, recursion, unlink, or
rmdir. It opens the Store and `.staging` directories no-follow, enumerates each
directory through an independent `openat(".")` descriptor, identity-checks that
descriptor, transfers its sole ownership to `fdopendir`, and closes it through
`closedir`. Recursive child descriptors are closed exactly once on both success
and error paths.

For a directory child, the implementation binds the pre-open `fstatat`
snapshot to the opened descriptor, invokes the deterministic package-only
replacement seam, and then rebinds the parent name to the same device/inode
before any recursive deletion. The final parent-name check precedes
`unlinkat(AT_REMOVEDIR)`. A symlink, irregular node, missing/replaced name, or
identity drift fails visibly. All removals are descriptor-relative, and every
successful file unlink or directory removal is followed by `fsync` of its
parent directory; no catch-and-continue or best-effort fallback exists.

Identity 046 now observes the exact unlink/fsync ordering and deterministically
moves an opened staging child outside before replacing its managed name with a
symlink. The old bytes delete the outside sentinel; the corrected bytes reject
the rebound name before traversal and preserve it. This directly closes the
original TOCTOU counterexample rather than inferring safety from API names.

### P1-F1C-3 closed — report root has one narrow trusted alias exception

Report-root bootstrap now walks from `/` component-by-component with
`fstatat(AT_SYMLINK_NOFOLLOW)`, `openat(O_NOFOLLOW)`, `fstat`, and a three-way
device/inode bind between the pre-open snapshot, opened descriptor, and current
parent name. Missing components are durably parent-synced before opening, so a
sync failure owns no leaked `next` descriptor; all other transitions and error
paths close their current/temporary descriptors exactly once.

An intermediate user alias is always rejected. The only first-component alias
exception is an exact root-owned `var` or `tmp` symlink whose raw target is
respectively `private/var` or `private/tmp`. The symlink identity is rebound
before and after `readlinkat` and again after opening the independently
no-follow `/private/<name>` target. Arbitrary root-owned aliases such as
`/etc -> private/etc` remain outside authority. No `realpath` or other
canonicalizing/following root bootstrap remains.

Identity 061 retains both missing-leaf and pre-existing escaped-leaf sentinel
counterexamples, rejects the arbitrary root-owned alias, and deterministically
swaps an ordinary directory between snapshot and open. The corrected Store
throws before creating a report in the replacement and preserves its sentinel,
while normal `/var` temporary roots and all cursor-recovery assertions remain
green.

### Final count and gate

- P0: 0
- P1: 0

P1-F1C-1, P1-F1C-2, and P1-F1C-3 are closed. Combined with the preceding
bounded F1C review, identities 043–061 now have an implementation-review
verdict of **0 P0 / 0 P1**. This closes only the F1C implementation-review gate;
it does not itself authorize or approve any later-band product byte.
