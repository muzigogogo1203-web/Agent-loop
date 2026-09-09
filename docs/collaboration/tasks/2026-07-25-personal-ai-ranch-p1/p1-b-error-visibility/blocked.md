# P1-B Planning Boundary

> Status: **CANDIDATE 03 REVISION 17 FROZEN — implementation paused until immutable Review21 records APPROVED with zero P0/P1**
>
> Date: 2026-08-15

## Current blocker

### B-03 — Revision16 synchronous-provider construction isolation awaiting independent review

### B-04 — Revision17 Application/Core OAuth dependency boundary awaiting independent review

Acceptance20 found a non-waivable P1: the Application target directly imports
`Security` and `CryptoKit` for OAuth random-secret and PKCE hashing. Revision17
keeps the exact 66-path boundary, moves only those primitives to the existing
Core `OpenAIOAuthSession.swift` owner, and removes both Application imports.
Implementation may resume only after immutable Review21 records zero P0/P1.

Immutable Review06 approved Candidate 03 Revision05, and the three bounded
B-02 tests then passed together. Their complete evidence is
`b02-targeted-verify.log` (SHA-256
`59a672ef37cbb73b9be01785309bcfcbfde111db01f3416b0f7ecd65628a53b1`).

The required unfiltered `swift run RunTests` then completed all 714 tests in
seven suites but failed with five issues; full stdout/stderr is preserved in
`verify.log` (SHA-256
`7c1169e3ac402a93db2a5d74b3ec6b7031fc5b81646f534d2e3c53f29211d7e`).
The failures are outside the three authorized B-02 assertion changes:

1. `DurablePlanningTests.a3Revision02EntryBoundaryRemainsByteExact` and
   `DurablePlanningTests.broadcastFailureDoesNotRewriteStartedFire` each
   report the immutable A3 hash mismatch for both
   `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift` and
   `Sources/AgentLoopTestSuite/DurableWorkTests.swift`. This directly
   contradicts Revision05 and Review06's assertion that both paths are absent
   from the A3/A4 immutable manifests. They are present in the actual A3
   206-row manifest with the frozen hashes recorded in Revision05.
2. The earlier ScheduleMath attribution was incorrect: that path is an A3
   historical-exclusion member, not an A4 manifest member; its separate hash
   state is not an A4 unchanged-row failure.
3. `DurablePlanningTests.shutdownWithCancellationIgnoringProviderReturnsBoundedly`
   measured 3.523666834 seconds against its strict one-second bound. This is
   independent of the B-02 test authority correction.

Revision06 records the actual A3/A4 membership and authorizes only the
existing `DurablePlanningTests.swift` manifest-gate arithmetic plus the two
B-02 test paths already authorized by Revision05. With Planner now authorized,
A3 is 49 raw / 43 successor / 156 live; A4 is 46 P1-B members / 160
unaffected rows / ten P1-B new paths.
It does not authorize product,
migration, scanner, declaration-count, or immutable-manifest-byte edits. The
shutdown timing failure remains a separately classified root-cause item: the
fixture's synchronous `streamTurn` blocks the cooperative executor under the
authoritative parallel suite. A fixture-only async-stream rewrite changes the
cancellation-ignoring contract and is rejected. Revision14, explicitly
authorized by the user, adds only `DurableWorkSupervisor.swift` and
`Planner.swift`: durable planning awaits synchronous stream construction from
an off-executor continuation without making the construction wait
cancellation-reactive, while the Supervisor retains cancellation/deadline
ownership. This preserves the strict one-second bound and expected
uncooperative ID. Implementation may resume only after immutable Review18
records zero P0/P1.

### B-02 — Three historical source assertions contradict the approved typed/controller boundary

The first unfiltered authoritative suite after the approved Revision 04 slice
completed the newly authorized WAL-read barriers, but exposed three additional
historical assertions outside that slice. `swift run RunTests` completed all
714 tests and failed only the following three assertions (full stdout/stderr is
preserved in `verify.log`):

1. `HaltAndCooldownTests.startupBootstrapGateBlocksDispatchUntilRecoveryCompletes`
   still accepts only `KernelHaltedError`, while the approved compatibility
   boundary returns the existing typed
   `UserVisibleOperationError(failure:)` with the captured operation trace;
2. `HaltAndCooldownTests.directMissionAndProposalStartsAreRejectedWhileHalted`
   has the same obsolete `KernelHaltedError`-only expectation for its public
   direct-mission path. Its package-level captured-proposal assertion remains
   an intentional `KernelHaltedError` expectation and is not part of B-02;
   and
3. `DurableWorkTests.activeRuminationFencesDiscardDeleteAndArchiveRaces`
   still requires `CodingRanchStoreAdapter.deleteIngestion` to contain
   `db.pool.write`, even though the approved boundary makes
   `InputWorkflowController` / `InputWorkflowPorts.live` the sole App-facing
   owner and keeps the transaction in Core.

The evidence is reproducible and narrowly attributable: the three WAL barrier
tests that previously timed out all passed in the same 714-test run. The run
then ended with exactly the three assertions above; it did not disclose a
product/runtime regression. `HaltAndCooldownTests.swift` and
`DurableWorkTests.swift` are absent from Revision 04's exact 62-path allowlist
and from its explicit 16-test delta. Updating them now would therefore violate
the frozen execution boundary, even though the changes are mechanically
derivable from the already approved contracts.

Revision 05 resolves this planning omission by adding these two existing test
paths only; preserving their behavioral matrices; replacing only the two
public direct-mission halt expectations with the plan's existing typed
compatibility-error contract; preserving the captured-proposal
`KernelHaltedError` assertion; and replacing the obsolete App direct-database
token assertion with the same controller/port/Core-transaction ownership proof
used by Revision 04. It changes only the resulting pathname/manifest
arithmetic. No product or architecture decision is open, and implementation
must not change either test file until immutable Review06 records zero P0/P1.

### B-01 — Frozen Coding Ranch source assertions contradict the reviewed controller boundary

Implementation reached one reproducible planning conflict on 2026-08-14.
`Sources/AgentLoopTestSuite/CodingRanchTests.swift` remains byte-identical to
its entry-manifest row
`38d20527135ace5035fc387daeead71f66a5798e4d4c090d9bb16cc03491b192`
and was intentionally absent from the exact 61-path Revision 03
implementation allowlist.
Four authoritative tests in that frozen file still require the pre-P1-B App
implementation to call `codingRanchPersistedSnapshot`,
`db.prepareRuminationStart`, `orchestrator.startRumination`, and
`orchestrator.cancelRumination` directly. Candidate 03 Revision 03 §§6.3 and
6.6 instead require `CodingRanchStoreAdapter` to map only loaded
`InputWorkflowController` snapshots and forbid a second App-side fallible
DB/provider decision. Both contracts cannot be implemented honestly: adding
dead branches or source-token shims would only bypass the source gate, while
restoring the direct calls would violate the reviewed single-owner boundary.

Evidence is frozen in `coding-ranch-targeted-tests.log`: the exact four-test
command exits 1 with five issues, all rooted in those legacy source markers.
The adjacent manifest command in `manifest-targeted-tests.log` exits 0 with
both A3 pathname/hash validation and the A4 broadcast test green. The broadcast
test also exposed and closed a separate implementation regression: provider
resolution failure now durably blocks the unchanged ready Card (or
session-suppresses it if that write fails), preventing the former
`runnerFinished -> reconcile` hot loop.

Required bounded planning correction: preserve the reviewed
`InputWorkflowController` ownership, add `CodingRanchTests.swift` to the exact
implementation/test delta, replace only the four obsolete direct-owner source
assertions with controller-port/snapshot assertions, update the A3 frozen
successor partition and inventory arithmetic, then freeze and obtain a fresh
independent zero-P0/P1 review. No product choice is open. Implementation must
not manufacture compatibility code or continue to the authoritative full-suite
gate until that corrected review reopens execution.

No further P1-B product, test, Package, matrix-script, build, migration,
preview, or runtime implementation may continue until this bounded correction
is reviewed. Review01 concluded
`CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2`. Candidate 03 Revision 01 closed that
review and its own pre-review consistency findings, but immutable Review02 then
concluded `CHANGES REQUIRED — 0 P0 / 7 P1 / 1 P2`. Revision 02 is restricted
to those eight planning findings, their mechanically necessary transitive
consistency closure, and `plan.md`, `try-question-mark-inventory.md`, and this
file. Frozen Revision 02 then received Review03
`CHANGES REQUIRED — 0 P0 / 6 P1 / 2 P2`. Revision 03 is restricted to those
eight Review03 findings, their mechanically necessary transitive consistency
closure, and the same three planning files. A fresh responsibility-isolated
review returned `APPROVED` with zero P0/P1 and opened Revision 03
implementation. B-01 is the sole implementation-discovered contradiction and
reopens only the Revision 04 planning bytes described above.

The three planning documents freeze before Review05. Once immutable Review05
records `APPROVED` with zero P0/P1 against those exact hashes, this phase gate
closes without any further edit to `plan.md`, the inventory, or `blocked.md`.
Any planning-byte drift instead reopens review.

This is a phase gate, not a request for user authority. The standing long-run
Goal already permits autonomous work inside an accepted/reviewed slice and no
per-step hash echo is required.

## Resolved planning gaps

### G-01 — Canonical 33 paths could not run its own migration gate

Canonical Plan §4.3/§10 requires a through-v13 matrix with v12-schedule as the
eighth predecessor, but §4.1 omitted the runner and script. Read-only inspection
also found A4's Database test hard-coded v12 as final and A3/A4 live source
manifests that must recognize a legal successor slice.

Resolution: Candidate 02 adds only runner, script, DatabaseTests, and
DurablePlanningTests. It preserves the A4 29/60/4 checkpoint, creates a
separate v13 31/65/4 owner, and keeps all unaffected historical entries/hashes.

### G-02 — Typed MCP API had direct callers outside canonical scope

`McpToolBridge` contains a business `try?` on failure-event persistence and
persists raw readable external detail. `McpManagerSpikeTest` directly calls the
manager API whose failure result must become typed. `CompanionEditorView`
silently turns a Companion DB read failure into a stale/default form while it
consumes MCP tool-list state.

Resolution: all three paths are exact bounded additions. CampHome and other
views retain their façade signatures and remain closed.

### G-03 — “degradation event” owner was ambiguous before v14

P1-B introduces `context_degradation`, while v14 domain events do not yet
exist and canonical §4.1 did not include EventKind.

Resolution: durable truth is `context_degradation`; required also commits the
existing `card_blocked` event. After an optional degradation commits,
Orchestrator emits `KernelEvent.contextDegraded` for live UI delivery; cold UI
queries the durable row. P1-B does not invent a legacy EventKind or v14 event.

### G-04 — Initial OAuth fix alone would leave refresh partial writes

AppStore has ignored multi-key writes, but OpenAIOAuthSession also updates
access/refresh/ID/account credentials sequentially. Claiming Keychain
write-failure safety while leaving refresh partial would be false.

Resolution: Candidate 02 adds OpenAIOAuthSession and its existing tests, freezes
pre-image/fixed-order/reverse-rollback behavior, and forbids credential/account
values in diagnostics. Candidate03 Revision03 closes the crash/await extension
of the same root cause: every mutation writes a durable committing envelope
before its first field and deletes it last, while refresh HTTP carries an
opaque revision+preimage proof so a stale response cannot overwrite a newer
authorization.

### G-05 — Trace representation and optional continuation

Existing durable paths may already own non-UUID trace IDs; truncating a trace
would break correlation. Separately, an optional context read cannot continue
when failure/degradation persistence itself failed.

Resolution: generated traces use UUIDs, accepted safe opaque durable traces are
adopted exactly, and the full ID is rendered/persisted/logged. Optional
continuation occurs only after the atomic failure+degradation transaction;
otherwise dispatch is suppressed.

### G-06 — MemoryDistill watermark race

The prior nil result merged no input, model skip, failures, and a lost commit
race. Treating the race as no-input would still hide concurrency behavior.

Resolution: no-input, skip, and created are explicit outcomes; provider/DB and
lost-watermark races are distinct typed internal failures. The public Memory
entries own one fresh fixed Memory trace and one existing catch each, capture
once, and return a flat `noEligibleInput/skipped/created/failed` terminal; App
does not catch or mint a second trace. The two public raw-array persistence
methods retain their exact `@discardableResult throws -> Bool` signatures:
complete commit alone returns true, while false is unreachable and every
invalid capture/race/write fault throws. They validate one exact ordered
capture before any transaction: empty arrays, blank IDs, and duplicate IDs are
distinct typed contract failures, never `0 == 0` success, hidden deduplication,
or a fabricated lost race. Blank validation precedes duplicate validation;
`[" ", " "]` is blank and `["id", "id"]` is duplicate.
`markDistilled([])` alone preserves its historical no-op. A created terminal is
irrevocably committed; its later note/knowledge reload has a separate trace and
retry reloads only, never provider/CAS/persistence. Application owns one
`MemoryKnowledgeProjectionCoordinator`, not an App-private duplicate or global
array. Its caches, attempts, pending committed records, and stable visibility
card are keyed by companion/guide owner; selecting B and failing never renders
A. Initial/CRUD/committed/retry loads all call the sole
`InputWorkflowController.loadMemoryNotes/loadCampNotes` DB owner and
conditionally apply its closed terminal. Stale request/card IDs are pre-trace
or zero-mutation, repeated failed reloads preserve every exact committed
record, and nonvisible-owner completion cannot overwrite the visible owner.
AppStore only delegates; RootView receives only the card and reload action,
never a DB or distillation capability.
The closed normalizer distinguishes threshold/capture, missing owner, duplicate
owner thread, owner/message read, thread-create write, invalid persisted role/
Distiller payload decode, provider, persistence write, CAS race, and
cancellation. Its exhaustive table freezes exact safe body, code, severity,
category/domain, retryable value, and sole optional GRDB/HTTP diagnostic for
every stage/source combination; known types at an impossible stage are
unexpected rather than guessed. DM/guide pre-owner traces use fixed `application/memory_dm` and
`application/memory_guide` for the whole invocation and never derive scope from
raw content.

### G-07 — Internal review found composition, commit, and persistence gaps

The first candidate left the Runtime actor on synchronous AppStore/Orchestrator
paths, could not represent committed mutations whose refresh/event failed,
could reuse one trace for multiple context failures, and did not prevent a
ready Card from immediately retrying after degradation persistence failed.

Resolution: Candidate 02 freezes a synchronous throwing
`RuntimeCredentialResolver`; stateless controllers with façade-owned
generation/projection; `OperationCommitOutcome`; one trace per dependency;
`FailureReporter.prepare/complete`; a session-local suppressed-card set with an
explicit retry action; and immutable redacted tombstones. Existing
`CodingRanchLoadState.failed(String)` remains a legacy projection, so closed
views do not change type.

### G-08 — MCP/OAuth rollback and event ownership were incomplete

Separate OAuth owners could interleave stale pre-image rollback; MCP deletion
could remove only some secrets; and ordinary MCP tool errors were incorrectly
about to mark the server down.

Resolution: one shared credential coordinator serializes callback and refresh
bundles with frozen initial/refresh absence semantics. MCP deletion snapshots
all secrets, mutates in fixed order, and reverse-restores on secret/DB failure.
Only typed `connectionDown` atomically writes `failure_record` plus the existing
down event; tool-level errors write a failure only. Revision03 clarifies that
the coordinator actor serializes short commands but not the browser/HTTP await:
the durable envelope covers process-crash visibility, and the opaque refresh
revision/preimage proof covers stale same-process HTTP continuation.

### G-09 — Verification contracts needed executable, count-stable evidence

The first candidate used ambiguous “parameterized” wording, lacked the real
v13 conflict injection/literal starting point, and relied too heavily on visual
preview evidence.

Resolution: Candidate 03 Revision 03 retains 47 ordinary `@Test` declarations
and 714 total,
maps all 133 literal inventory rows to internal case owners, starts the literal lane
from reopened v11, freezes the real v13 sentinel-index rollback, and requires
owned executable/PID/lstart, `lsof`, DEBUG zero-call audit, Accessibility full
trace, and isolated-DB exact correlation.

### G-10 — Review01 exposed non-executable failure/target contracts

Candidate 02 still left atomic fallback ownership, selected context handoff,
one-snapshot Application reads, equivalent defaults, metadata provenance, and
cross-target API/debug seams to the implementer.

Resolution in Candidate 03: exact AppDatabase atomic/read/resolve methods,
typed context identities, strict scope/trace factories, six one-snapshot Core
bundles, sync Runtime bootstrap, shared credential coordinator, closed
FailureOperation/FailureCode registries, package controller APIs, DEBUG-only
hooks, and executable source/test descriptors. Persisted rows validate shape
but cannot mint a live trace scope.

### G-11 — Root-cause audit expanded the exact closed set

The prior 42/50/56-path candidates could not repair defaults/catalog corruption,
newcomer scalar collapse, Distiller fallback visibility, scheduler/notifier
post-commit failures, guide-chat localized errors, or provider resolver catches
after those errors had already been swallowed by transitive owners. The 56-path
draft still duplicated Schedule/Chat/Mission-draft persistence algorithms and
could not prove one-snapshot/one-transaction ownership.

Resolution in Candidate 03 Revision 03: exact scope is now 61 paths. The prior
three true Core owners remain, `ScheduleManagerView.swift` is the one
additional UI owner required by the complete equivalent audit, and
`ProductBootstrapService.swift` is the root transaction owner required to make
the full Coding Ranch bootstrap atomic. The Schedule view can no
longer reparse a validated template with `try?`, raw-format local validation
failure, or guess commit completion with a 200 ms sleep. Literal `try?` is
133; the expanded production catch snapshot is 134 and raw formatter snapshot
is 85 named plus two reflected-type uses. Historical A4/A3 manifests use the
recomputed raw intersections 42/46, yielding 164/159 unaffected entries, without changing
their accepted evidence.
Revision04 adds the existing CodingRanchTests path, and Revision05 adds only
the existing HaltAndCooldownTests and DurableWorkTests paths. The former
Revision05 claim that those test paths were absent from A3/A4 is superseded by
Revision06's recorded 48/42/157 A3 and 45-plus-four/157 A4 pathname-exact
partitions; the exact scope remains 64.

### G-12 — MCP committed cleanup could repeat a durable deletion

The first Candidate 03 cleanup draft discarded the Manager lease after a
post-delete finish failure and represented cleanup as an optional field on a
deletion receipt. That allowed illegal committed/pending combinations and gave
neither rollback cleanup nor the App façade a safe single-flight retry.

Resolution in Candidate 03: mutually exclusive rollback-pending,
deleted-pending, and cleaned-receipt types derive identity only from the opaque
lease. A dedicated cleanup-only controller/port never reacquires maintenance or
touches DB/Keychain, Controller and McpStore both enforce per-server
single-flight/conditional apply, and a closed cleanup-integrity error preserves
one trace. The execution-only seam has its own inventory descriptor without
changing any entry count.

### G-13 — Candidate03 lacked executable descriptor/debug/artifact closure

The first Candidate03 bytes counted every literal/catch/equivalent row but did
not bind all 133 literal descriptors, 134 catch descriptors, and fourteen
planned-new catches to exact production callables and App delegate anchors.
It also described DEBUG seams and SwiftPM artifacts generically, leaving release
TestSuite compilation and object selection ambiguous. One atomic-fault owner
sentence assigned the MCP event fault to the wrong test.

Resolution in Candidate03 Revision 03: the inventory is a relational registry
covering 413 descriptors, of which 411 are production and two MCP fake-helper
rows remain honest nonproduction parse tests. The 411 production descriptors
project to exactly 152 primary seams; their four closed multi-case descriptors
produce 416 variants whose expected-counter union covers all 153
`ProductionFailureSeam` cases. App delegation is the independently derived
127-tuple `DE-001...DE-127` ledger. Six previously missing decision boundaries are frozen:
post-database bootstrap, schedule-outcome load, default-Camp ensure, and
rumination-phase projection, plus the dedicated rate-limit event persistence
boundary `orchestratorRateLimitEvent`, plus the execution-only
`schedulePostCommitRepair` boundary. The plan declares the only 13 DEBUG aggregate
overloads and all 13 owning subcases, with direct caller guards and exact
writer/WAL semantics. Its fail-closed `output-file-map.json` algorithm requires
bidirectional source-key equality; two explicit App product-link gates exclude
stale executables; and 13 full demangled label signatures distinguish the two
Mission-draft overloads. Atomic statement faults now have their exact
MCP/required/optional owners. Those descriptor repairs add no path or test by
themselves; Revision03's separate Product-bootstrap root fix and A14 test,
plus Revision04/05's three existing historical-test owners, are the explicit
64-path/47-test-declaration deltas recorded in G-15, B-01, and B-02.
Revision 02 also classifies `captureAsyncStream` as the eleventh planned catch;
`orchestratorRetryCard` is now the sole nested-only seam case because the
arithmetic and strict review-provenance descriptors make
`orchestratorAddBudget` and `inputSaveReview` real primaries.

Review02's negative-gate finding is closed by a separate pathname-exact syntax
universe rather than by treating the 130 semantic N rows as a source scan. The
35 existing production files freeze 954 candidate occurrences: 431 join an
existing descriptor/cross-gate contract and 523 are occurrence-exact
closed-nonfallback decisions. A second exact registry freezes all 2,962 entry
syntax exclusions: 759 core exclusions—including the 159 maximal-munch `?.`
anchors omitted by the earlier lone-question census—plus 2,203 excluded standalone-call
roots. The complete standalone-call-root census is 2,283 because its remaining
80 roots are reviewed candidate occurrences in the 954-row ledger.
Terminal source is rescanned with the same reviewed candidate/standalone
algorithm: a harmless entry may only remain byte-normalized identical or be
deleted automatically; each of the 431 business entries has one explicit
`KEEP` or `DELETE` relation whose immutable ClassificationSet still closes
through the frozen callable/seam/delegate/owner; and each of the seventeen
pathname/declaration/trigger-exact planned occurrences has one `PLANNED`
relation. The exact `P1-B-RESOLVE` line total is therefore 448. The 2,962 entry
exclusions may remain suffix-identical or disappear; a changed/new root is
accepted only by the frozen closed structural grammar. The relation is evidence
of the planned rewrite, never authority to change a failure disposition or
invent another harmless case.

Revision 03 also freezes the complete normative scanner and compiler-typed
role registry inline, rather than referring to temporary producer artifacts.
The scanner replays 954 candidates, 2,962 exclusions, and 2,283 standalone
roots; the typed registry closes all 2,476 privileged roots across the frozen
debug/release evidence with zero unresolved roles. Terminal validation extracts
those same reviewed bytes from the inventory and fails closed on an absent,
ambiguous, changed-signature, or newly self-approved root. Revision 03 adds the
missing executable terminal-corpus producer and independent provenance
validator; their complete authority is recorded in G-15 below.

### G-14 — OAuth logical receipts did not own physical listener generations

The prior reservation/receipt recovery design could not distinguish a late
failure from physical listener G1 after the same authorization had installed
G2. It also relied on cancelling an App callback Task to prevent an already
legal callback actor claim, which Swift cancellation and actor scheduling do
not guarantee. Finally, giving the App-owned listener a controller callback
without an explicit construction boundary would require an unplanned IUO,
mutable late bind, `lazy` cycle, or illegal pre-initialization `self` capture.

Resolution in Candidate03 Revision 02: the controller mints the initial opaque
listener lease directly, while every listener-recovery retry has one strict
order: record its old owner/attempt/lease, stop that old lease, await all
callback/failure acknowledgements, recheck the same actor owner, and only then
mint/install/start G2. App owns one MainActor physical slot with a closed
starting/live/failure/callback/dual-claim state machine; there is no unused
stopping phase and `startListener` never replaces a nonempty slot. Every
physical callback carries its event lease into a sealed command. A queued
eligible callback remains drain-bearing after stream dequeue while the serial
consumer performs a non-suspending controller claim and then one App promotion,
abandon, sealed reject, or local reject. App leaves its old lifecycle state and
Task byte-identical until claim succeeds, except that an already controller-
sealed listener pending may apply through the exact preparation-origin or
active/recovery row and retarget the same candidate without acknowledging it.
A winning G1 claim atomically changes
the controller owner, so the waiting recovery recheck is stale and G2 is never
minted; a rejected G1 reaches a stable owner before its physical
acknowledgement, so only then may the retry proceed. A current G2 callback or
failure may claim its phase before start returns; the mandatory post-start
phase+lease+attempt recheck then compare-stops G2 and publishes no false
success. If the start caller rechecks first, the later claim takes over the
resulting controller-current post-preparation/browser-opening/ready owner and
makes its late App terminal stale. No branch relies on Task cancellation, actor FIFO, or a controller-
invisible local deletion of a current G2 callback.

Promotion changes the physical slot to `.callbackProcessing` only after
controller claim, installs the sole capability Task, and is the physical
callback acknowledgement. An accepted claim that cannot promote is first
abandoned into opaque listener recovery; a sealed/local reject finishes without
changing an unrelated App carrier. Plain processing is therefore physically
acknowledged, and cleanup stop never awaits its own callback terminal. A failure
claim remains an independent tombstone: stop/replacement cannot remove it until
the exact sink event is consumed, its guarded App transition is attempted, and
the same MainActor segment acknowledges that apply. If callback processing and
failure coexist, committed cleanup waits only for that failure acknowledgement;
it returns before the callback method emits its sealed terminal. Recovery-first,
callback-terminal-first, and stop-before-sink orders preserve one callback and
one fresh listener trace, resume at most one waiter, and create no post-commit
restart capability. One live failure claims one handler attempt;
a failure after callback claim retains both exact attempts without ever
restoring a dead listener to live. Every controller/App terminal validates reservation,
authorization, lease, and claim attempt. Preparation/active/recovery listener
transitions have exact cross-phase CAS rows. Once callback processing is
synchronously installed, listener results are display-only and cannot cancel
or replace its Task; the earlier non-I/O claim has already adopted the
controller-current recovery stage, and the capability Task's sealed terminal
alone synchronizes App. The sealed terminal remains a
logical lifecycle terminal, not a physical callback-drain acknowledgement.
Preparation and browser opening
are separate: controller preparation commits listener plus one canonical
selected-phase (`.prepared` or quarantine-preserving `.recoveryPrepared`)
Keychain envelope and returns
an opaque prepared owner; App installs active state plus a fresh browser-open
Task in one MainActor segment before the sole open controller call. Callback or
listener takeover invalidates only that exact open attempt, so no callback is
legitimately dropped while App is preparing and no late browser terminal can
overwrite recovery or the controller-private cleanup phase. Test13 freezes G1/G2, dual-claim, open/callback, and
actor-terminal/MainActor-apply orderings without any FIFO assumption.
Construction is cycle-free and lossless: an App-private MainActor platform
owner creates both typed event streams before the platform factory/controller;
the factory captures only that owner. The controller's first preparation
creates a sink already weak-bound to itself and calls the pure factory exactly
once before listener start. App initializes all properties and installs the two
stream-value-plus-weak-self consumers before `AppStore.init()` returns. No optional/IUO
controller cell, bind method, recursive lazy initializer, unbound event window,
second slot registry, or event-dropping buffer exists. The callback consumer
strongly retains AppStore for at most one bounded claim/promotion/abandon
iteration and must close an accepted claim despite cancellation before
releasing that local; it never retains AppStore across the next stream wait.
Its per-flow candidate map persists the exact pre-promotion lease/attempt guard
across the actor claim. Before promotion, a controller-sealed pending may change
the old App carrier only through the two exact listener rows and must atomically
retarget that map entry; post-claim listener results are otherwise display-only.
Termination/cancellation after `.claimed` must promote or
abandon and physically acknowledge before releasing the candidate. If a
listener-pending actor terminal was already sealed before claim but its App
apply wins before promotion, that one MainActor segment installs the pending
through either the preparation-origin or active/recovery transition and
retargets the same candidate to the fresh lifecycle attempt/origin; the
callback remains drain-bearing and promotion still succeeds. If promotion wins
first, the same late pending is display-only. While that exact candidate
exists, the authorization-retry control and action are synchronously disabled:
a stale tap changes no attempt/state/Task, queues nothing, mints no trace, and
calls no controller or platform seam. Retry-first is allowed only when its
attempt/Task installation completes before candidate capture; candidate-first
holds its guard until promotion/abandon/reject physically acknowledges and
removes it. Rows two and three never re-enable retry merely by retargeting.
Whole-App teardown is separately closed by one MainActor owner `shutdown()`:
AppStore remains its pure-Swift `@MainActor @Observable` class. After both
stream-value-plus-weak-self consumers are installed, it asks the owner through
a typed-binding call to install the sole will-terminate block observer; its
main-queue block uses one typed `MainActor.assumeIsolated` body, weakly captures
only owner plus the two Sendable consumer Tasks, and the owner stores/removes
its one observer token in shutdown before cancelling consumers. Each consumer
retains only its pre-extracted `AsyncStream` value and weak AppStore, never the
owner. The callback loop's one permitted strong AppStore local is bounded to a
single dequeued claim handshake, must promote/abandon/reject despite
cancellation, and is released before the next stream wait; the observer thus
cannot close a persistent indirect owner/Task cycle. No
NSObject/selector/relay, AppStore/controller strong capture, or observer/owner
cycle exists. Because
macOS 14 cannot use isolated deinit, ordinary deinit
copies only the Sendable owner/Task values into one typed MainActor cleanup Task
with the same order and no AppStore capture. The
idempotent shutdown finishes both streams, removes physical slots before
cancellation, resumes each stored start continuation with
`.ownerShuttingDown`, and
resumes each claim drain with the closed `.ownerShuttingDown` stop outcome. Controller
callers instead receive the closed `.ownerShuttingDown` start/stop outcomes and
exhaustively turn ordinary branches into their existing zero-I/O `.superseded`
terminal. A failed atomic preparation write leaves its envelope preimage
byte-identical and has no rollback owner; stop during shutdown returns only the
exact superseded teardown terminal. Normal ready/start and stop/drain return
`.started` and `.stopped`. The teardown
terminal cannot be invoked by a live-flow stop/replacement or masquerade as a
successful recovery acknowledgement.
TestSuite executes only the Core/Application controller, sink, and injected
platform-double transcripts. App-private NWListener slots, weak-capture/
teardown shape, and MainActor transition placement are pathname source+compile
evidence; the plan does not claim that AgentLoopTestSuite imports App, allocates
NWListener, or proves App object deallocation at runtime. The existing
`AppStore.startOpenAIAuthCallbackListener()` catch is retained in place as the
self-free static raw-NWListener-to-typed-bind adapter, so no new App catch or
Result candidate is introduced.

### G-15 — Review03 exposed terminal-evidence and cross-owner repair gaps

Frozen Revision 02 had no executable producer for its mandatory terminal AST
corpus and did not independently bind accepted corpus jobs to a recomputed
SwiftPM driver provenance. Its local-listener-only OAuth command could not
represent the retained custom-scheme callback, while per-flow authorization
owners aliased one shared verifier. Schedule DB commits had no opaque
post-commit effect-repair owner; Coding Ranch bootstrap could durably commit a
Camp before a later bootstrap throw was reported as not committed; and the
MemoryDistill skip path lacked the same conditional watermark CAS as created
paths. Its path prose also mixed the implementation allowlist with the
production scanner universe.

The first recovered Revision03 terminal-source candidate then exposed a second
root defect: it could hash one pathname instance and parse or bind a reopened
instance, discarded the validator's 86 parsed AST bytes, accepted duplicate or
nonfinite JSON at some boundaries, trusted lexical cache containment and mtime
ordering, and tested shadow helpers instead of every real success publisher.
That is a terminal-authority TOCTOU and validation-contract failure, not a
documentation-only variance.

Resolution in Candidate03 Revision 03 is one bounded root-cause closure:

- the inline terminal-corpus producer consumes the just-completed debug and
  release SwiftPM build descriptions, recomputes six configuration-target
  records and all 264 primary dry-run jobs, executes exactly 86 jobs for the 43
  production paths, and emits a closed artifact/command/progress ledger. The
  independent validator repeats the SwiftPM selection and exact argv transform,
  checks every exit/stderr/AST/hash/cache/source/module/SDK/target/conditional
  field, and hands only that validated corpus to the frozen final scanner;
- producer, independent validator, and final scanner now use one
  descriptor-anchored `O_NOFOLLOW` snapshot protocol, so hash, strict parse,
  schema, and binding consume the same retained bytes. Validator and scanner
  each carry all 86 AST bytes through an immutable `ValidatedTerminalState`.
  Strict JSON rejects duplicate keys and nonfinite constants, canonical
  authorities/ledger rows are byte-exact, and integer schema fields exclude
  Bool. Every subprocess has pre/post direct-directory, resolved-containment,
  and held-FD cache/tmp checks. Producer and validator each have one complete
  atomic PASS publisher with file and parent-directory fsync; causal publication
  and byte binding replace mtime authority. Real full-success and race/fault
  probes exercise those production call graphs;
- OAuth authorization is globally single-active across `.chatGPT` and
  `.generic`, preserving the intentional shared credential bundle and its one
  Keychain transaction-envelope coordinate.
  Local-listener callbacks retain the lease-bound controller-first claim, while
  a distinct lease-free opaque custom-scheme command enters the same common
  claim/handle/abandon state machine. Before its claim CAS, the custom ingress
  purely validates route plus the exact controller-held state, so an old URL
  cannot mutate a newer owner. The physical ingress performs that same pure
  configured-route/state proof after its exact owner+lease proof and before its
  claim CAS. An invalid state on the exact current listener returns the
  distinct current-authorization-rejected terminal and restores only a plain
  live slot, leaving the current controller/App carrier byte-identical; a stale
  owner/lease is superseded and non-restoring. Thus an A URL delivered on B's
  listener neither claims B nor consumes B's callback opportunity, including
  failure/drain interleavings. Both pre-CAS URL matchers use the sole
  nonthrowing `SecretValue.validated` factory; blank/invalid protocol state
  returns its closed rejection without `catch`, `try?`, `try!`, trap, or a
  throwing bridge. They and the post-payload state validation use the sole
  fixed-work `constantTimeEquals` helper. Explicit `SecretValue.==` delegates
  only to that helper; synthesized/fieldwise/raw equality, hash, prefix, and
  early-return byte comparison are forbidden, and factory rejection plus
  functional mismatch positions are tested. The factory trims only to decide
  blank rejection, then stores the original untrimmed bytes; a whitespace-
  wrapped expected state is a mandatory mismatch rather than normalization.
  Every initial callback atomically replaces the
  complete shared credential bundle: absent refresh is deleted, generic clears
  ChatGPT-only ID/account, and ChatGPT writes its required derived account.
  Authorization preparation pre-reads the one item and performs at most one
  canonical owner-bearing selected-phase envelope write, so a failed Security
  call is genuinely not committed and needs no repair owner. Absent or
  canonical prepared preimages select ordinary `.prepared`; only an exact
  five-coordinate-owner match may advance recovery/committing quarantine to
  `.recoveryPrepared`. A different owner or an unprovable legacy/malformed/
  noncanonical/unknown item remains byte-identical and unavailable; quarantine
  cannot be reassigned or downgraded.
  Initial callback atomically changes that exact item to `.initialCommitting`
  before any credential field and deletes it last; refresh and permanent-
  unauthorized delete require an absent envelope, install their own committing
  sentinel first, and delete it last. Any process crash or failed compensation
  therefore leaves a durable quarantine phase that every Runtime/Planning/
  presence/Session credential reader rejects before returning a field. A fresh
  globally sole authorization for the **same exact envelope owner** atomically
  replaces a stale sentinel only with owner-equal `.recoveryPrepared`; all
  readers remain quarantined through that browser interval, and only the same-
  owner complete replacement callback's final envelope delete makes credentials
  visible. A different accounts bundle cannot recover/delete another owner's
  crash sentinel. No raw-token fallback or
  session-local rollback capability exists. Reverse compensation restores or
  deletes the envelope only after all changed credential fields restore; any
  field rollback failure keeps the committing phase. Refresh HTTP reads carry
  an opaque coordinator revision plus complete credential preimage; every
  intervening OAuth mutation attempt invalidates it, and refresh commit or 401
  delete revalidates revision, absent envelope, and byte-equal preimage before
  its first write. Stale responses are retryable typed terminals and never
  delete or overwrite the newer bundle. Cross-flow preparation/callback, crash barriers, reverse
  compensation, stale retry, custom ingress, and refresh/delete tests prove one
  global owner and no state overwrite, mixed credential, or deletion race;
  every synchronized access instance shares one process-global lock and one
  private revision registry keyed by stable backend namespace + account. The
  public protocol extension supplies the stable `.legacyShared` default, so
  old external conformers remain source-compatible and conservatively share a
  revision domain; it never generates an identity. Each `KeychainStore`
  projects its exact service namespace; each memory/recording backend instance
  retains one unique explicit isolated namespace. Each mutation
  advances all five coordinates in its own backend. Within one backend only
  bundles whose complete five-coordinate sets are disjoint retain independent
  proofs; different **explicitly namespaced** backends never invalidate one
  another, while legacy-default stores may conservatively invalidate. Public compatibility
  tuples over one backend always overlap at `.live.verifier` and deliberately
  invalidate one another even when their four credential fields are disjoint.
  The public Session
  initializer keeps its existing signature and caller boundary exactly
  source-compatible, but replaces the old fieldwise mutation implementation.
  It uses
  `OAuthCredentialAccounts.live.verifier` as the one backend-global durable
  envelope for every custom four-coordinate tuple and delegates to the same
  coordinator rather than retaining direct fieldwise store writes. This
  deliberately quarantines overlapping—and conservatively disjoint—public
  compatibility tuples after a crash; a per-tuple derived sentinel is
  forbidden because it could miss another tuple's partially written shared
  account. Empty, duplicate, or global-envelope-colliding supplied coordinates
  fail safely before store or HTTP work. Authorization-preparation and refresh
  proofs are bound to their originating coordinator and exact accounts;
  initial/refresh commit and delete accept no caller accounts, and an empty
  revision registry is atomically seeded with a complete
  five-coordinate snapshot before the first proof. The nonthrowing preparation
  commit reports invalid coordinates through its closed `.unavailable` outcome
  rather than an impossible throw. Initial commit additionally requires the
  payload flow to equal the preparation flow, while refresh commit requires
  `.chatGPT`; both mismatches return the proof-owned `.preimageChanged` before
  lock/revision/store/Reporter/callback or permanent-failure work. This keeps
  source compatibility while closing multi-Session
  mutation/HTTP-await races; App production still uses only the injected
  package coordinator initializer;
- every committed Schedule mutation creates its exact committed identity and,
  when authorization or registration visibility fails, one opaque current-stage
  repair receipt. Initial committed/visibility-failure and repair repaired/
  still-pending outcomes each carry only one distinct opaque application
  receipt; their four fileprivate-initialized wrappers contain no raw identity,
  evidence, failure, repair, or clearance payload. The controller owns one
  effect state-by-ID whose `.performing` and `.repair` phases back every effect
  key reverse mapping, plus one application carrier-by-ID whose closed ordered
  `SchedulePostCommitCanonicalProgram` is the sole owner of projection,
  authorization/registration evidence, repair-clearance, and repair-install
  operations from unpublished creation through published consumption. A
  published application state stores only receipt + carrier ID, with the exact
  `applicationId -> state.carrierId -> published carrier(receipt)` bijection;
  every owned key always maps directly to that carrier ID. No state duplicates
  or reconstructs the program;
- every DB commit and accepted repair flight creates its unpublished carrier
  before the first platform await. A current terminal seals that same carrier;
  a carrier already transferred to a successor yields a receipt-free stale
  terminal. A new intersecting DB commit removes complete predecessor effect
  owners and carrier-key mappings, leaves one exact mutation-superseded receipt
  tombstone for each published predecessor, transfers each complete normalized
  canonical program and undelivered clearance once, deterministically composes
  disjoint predecessor groups, reverse-maps the union of inherited and new keys,
  appends the new DB identity last, and only then begins effects. Thus a
  subset-key successor preserves a predecessor template delete's nonoverlapping
  child deletions. After an unpublished carrier is transferred, the old effect
  owner, every effect reverse key, and its matching repair flight are removed;
  its late continuation fails the existing guard and returns receipt-free stale
  with zero reconstruction/capture. There is no `applicationTransferred` phase;
  only global visibility may retain `globallyVisibleAwaitingTerminal`. A DB
  failure changes none of these authorities;
- initial authorization success and catch continuations plus repair retries
  guard every owned key before Reporter, registration, evidence, repair, or
  state mutation; a stale thrown error is discarded without capture. A stale
  initial effect returns committed-superseded and cannot touch its successor.
  Registration uses one injected now/time-zone evaluation and exactly one
  `try await` of the async `ScheduleRegistrationPort.replaceAll`. Production's
  `MissionScheduler` adapter and synchronous build/swap helper have no
  suspension/Task/continuation/callback/actor-hop edge and complete in one
  MainActor segment, so invocation order is swap order; only no-shared-scheduler
  test doubles suspend to make controller-state barriers executable. An initial
  registration success publishes its carrier and in the same no-await segment
  removes the exact `.performing` owner and every effect reverse key, while the
  carrier remains until consume or successor claim;
- retry invokes only the remaining effect and never repeats DB mutation or
  starts while the prior terminal token is unconsumed. Successful explicit
  registration refresh returns every removed registration-stage opaque repair
  not already owned by a carrier. Global visibility normalizes eligible
  unpublished or published carrier programs in place—retaining project,
  authorization, and clearance operations while suppressing obsolete
  registration evidence/repair installation—and retains all carrier-key reverse
  mappings so a later commit can still upgrade the token to mutation-superseded.
  Authorization-stage owners remain current. A package pure same-repair-owner
  proof clears an older App carrier without exposing ID or stage;
- every receipt-bearing App terminal holds a bounded strong owner, consumes its
  receipt synchronously before any local-flight check, and exhausts only the
  decision's closed three-arm fold: apply the controller-owned canonical
  program, mutation-superseded, or already-consumed. The apply arm folds all
  operations into a temporary projection and commits once even when local
  generation is stale; the other arms mutate nothing. Decision/program storage
  and initializers remain fileprivate, verified by positive package fixtures and
  pathname/source structural gates rather than intentionally noncompiling
  TestSuite code. Flight entry/tail still uses key/generation/attempt/purpose/
  old-receipt equality, performs no application-time generation arithmetic,
  never compares Task values or reads private IDs/stage, and template-child
  clearance cannot cancel a newer mutation or the current repair Task before
  its sole tail;
- `ProductBootstrapService.ensureBootstrap()` delegates to
  `AppDatabase.ensureCodingRanchBootstrap()`, whose Camp ensure, guide upgrade,
  base-cow insertion, and provisioning event insertion share one `pool.write`
  and one Database handle. The post-database boundary preserves the exact
  `CodingRanchBootstrapResult`; App owns one typed Ranch state/method and one
  retained Ranch boundary/service, plus one typed Runtime state/method and
  retained Runtime bootstrap/request. The Runtime projection, Ranch state, and
  joint gate have no default initializers: one ordered pre-self local pipeline
  runs Runtime capture then Ranch post-database boundary and derives all three
  exact values. Any throw is genuinely not committed, keeps Runtime/
  listener/recovery/scheduler/provider/Kernel dispatch at zero, and exposes one
  traced RootView retry. Both loaded values enter one Application-owned joint
  startup gate; either alone remains halted, the missing peer's recovery starts
  exactly once, and every repeat is zero work. AppStore initialization only
  constructs that gate and has no claim/start edge; RootView's existing
  `onAppear` invokes one synchronous repeat-safe activation entry after the
  fully initialized store is installed, and all initial/retry decisions share
  one exhaustive `.startNow`-only downstream applier. There is no Ranch-only,
  Runtime-only, constructor-start, or second Boolean start path. Trigger-
  driven A14 proves rollback at every write boundary, removes each trigger with
  throwing cleanup, proves it absent, then verifies one idempotent retry;
- DM/guide skip and created paths share one conditional captured-ID watermark
  consumer whose exact changes count must match. All four Service race rows
  return one failed trace without a false skip/created success or partial note/
  event write; raw persistence rows throw exact lost-race. A fileprivate
  validated-capture token is the only input to the shared conditional helper;
  every raw-array commit owner rejects empty arrays, blank IDs, or duplicate
  IDs before DB work, every production captured-ID list is additionally proven
  nonempty/unique, and the source-compatible Bool persistence result is true on
  commit and never false. Created-terminal reload failure is retained by the
  Application owner-keyed projection coordinator with the exact
  committed-record set; its only retry calls the existing Input controller load
  owner, and provider/CAS/persistence counts stay unchanged; and
- terminology is exact: the 64-path implementation allowlist contains 43
  production scanner paths, 35 entry-existing plus eight planned-new. The
  expanded entry/scanner/typed/test/descriptor/seam/delegate values are
  954/2,962/2,476/714/413/153/127 respectively. Terminal AST authority is not
  an external unexplained corpus: inventory §9.1g-p/§9.1g-v frame the complete
  independent producer/validator bytes, and one NUL-framed scanner-order path
  formula binds exact entry-35 and terminal-43 digests. Final accepts only the
  producer's one-shot atomically published and parent-fsynced PASS V2 handoff
  plus the independently published validator handoff, byte-bound through
  retained `ValidatedTerminalState`; “last” is causal publication order, never
  mtime. The driver runs only the producer. Exactly one final scanner inside
  the fresh authoritative RunTests invocation extracts and runs the validator,
  consumes its newly published handoff, and performs typed extraction; no
  pre-validation or standalone final replay may consume that real corpus.
  Preflight/self-probes use distinct fresh roots, and a failed root is never
  reused. There is no legacy fallback.

Revision05 remains planning-only. This bounded correction changes no further
implementation bytes until immutable Review06 returns `APPROVED` with zero
P0/P1.

## Stop conditions after review

Reopen this file and stop if implementation discovers:

- any required source path outside the exact allowlist;
- a schema/DDL requirement beyond Stage §18.3;
- a need for EventKind/v14 domain events or P1-C+ types;
- an inability to preserve existing App-facing signatures without broad view
  churn;
- a red result not caused by the intended failure-first missing implementation;
- normal-data, Keychain, provider, MCP-process, or user-process contact during
  preview;
- any unknown failure, unresolved P0/P1, or source partition drift.

## Open questions

No user/product decision is currently open. Candidate 03 Revision 05 is the
bounded B-02 test-authority correction selected above; implementation remains
paused until a fresh responsibility-isolated plan review returns zero P0/P1.
Any newly discovered transitive path or unresolved callable reopens this
section and Revision 05 rather than being invented during implementation.
