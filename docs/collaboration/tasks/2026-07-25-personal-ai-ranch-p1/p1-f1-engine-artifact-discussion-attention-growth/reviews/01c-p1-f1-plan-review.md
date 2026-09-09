# P1-F1 F1C Revision 4 Independent Plan Review 01c

> Reviewer: responsibility-isolated Codex reviewer  
> Date: 2026-08-27  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`  
> Boundary: Revision 4 F1C plan/scaffold/scope review only; no product, test,
> migration, build, matrix, package, or application command was run

## Verdict

**APPROVED — 0 P0 / 0 P1**

Revision 4 is decision-complete for the two verified F1C entry conflicts. It
creates a bounded declaration-only exception that makes identities 043–061
discoverable as runtime capability reds, and it removes the last predecessor
fixture dependency on nonempty raw path authority without opening F1D or F2.
F1A and the accepted F1B implementation are not reopened.

## Reviewed immutable inputs

| Input | Independently verified SHA-256 |
|---|---|
| Revision 4 `plan.md` | `d4b003daa4528df82ca88920f1debea1fd1d01edd1301206bbc17d195ff1a91a` |
| 98-line `scope-allowlist.txt` | `9c9c0198e7570c56367c83e90e606a888bc08f7e833ed9cd82517bacb4e39020` |
| 47-line `entry-source-manifest.sha256` | `024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a` |
| 100-line focused test manifest | `03f69e8455d7d7b9c7a75f2489dd7499cf1611b5299542c84042d70b33615968` |
| canonical P1 Stage | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| accepted master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| final F1B Review02 | `8a06de21ba238b02afc2030e82414e992b03e005899c875af3554773a7044673` |
| `GuideChatTests.swift` pre-image | `6b6150e00bf826fa98ae9eafbb5735735af81ed39fa64d05cd8628022329e7c7` |

The allowlist is LF-terminated, byte-sorted, and unique. The entry manifest is
path-sorted and contains the exact live GuideChat pre-image. Review01c is the
only new review path. The five Store/stager/verifier/report owners and all
three F1C test files are absent, matching the stated compile-entry fact.

## Independent boundary proof

The plan's NUL-safe, lstat-mode/type-aware serializer independently reproduced
the pre-review-materialization boundary:

```text
dirty_total=648
allowlisted_present_count=59
outside_count=589
outside_manifest_v1=792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88
```

Writing this sole allowlisted review is expected to change only the first two
live counts to 649 and 60. The outside count and hash remain the immutable
F1C boundary.

## Decision-completeness findings

### Compile scaffold and exact red

The exception is zero-behavior and temporally closed. It begins only after
this approval, permits declarations in the five absent owners plus the
already-present v17 record owner, and requires every DB/filesystem-capable
operation to throw its exact `ArtifactCapabilityUnavailableErrorV1` before ID
allocation, path opening, locking, task creation, or any memory/persistent
mutation. Empty/nil/placeholder success is forbidden, and prepared artifacts,
verified ownership evidence, and trusted capabilities have no caller-usable
constructor.

The order is executable: scaffold first; declare the exact manifest identities
043–061 once; run the anchored exact-19 filter with pipefail; require nonzero
command status, zero tee status, exact discovery-set equality, and only typed
unavailability/direct capability failures. Compile, fixture, setup, crash,
predecessor, or discovery-count failure invalidates the red. Functional work
can begin only after that immutable red, and the scaffold type/error must have
zero references at the F1C completion gate.

### API and v17 schema consistency

The three added records contain exactly the columns of the accepted v17
`artifact_blob`, `artifact_blob_reference`, and `artifact_storage_origin`
tables. Their closed state/storage/evidence/disposition raw values match the
DDL byte-for-byte; Revision 4 authorizes no schema or migration change.
Prepared-artifact construction stays with the stager/blob owner, artifact plus
origin/reference insertion stays transaction-local to the Origin Store, and
legacy upgrade accepts only verifier-created managed or verified-outside
evidence with exact version CAS.

The Blob Store/Stager, Origin Store, verifier, and managed-report signatures
are closed in §§15.5–15.7. Their checkpoints are observation/fault-injection
seams, not fallback control flow. The exact GC root union, no-follow ownership
matrix, tombstone restage, redaction lock, deterministic report cursor, and
recovery ordering remain the already-approved F1C semantics.

### Predecessor adaptation and ownership boundary

`GuideChatTests.swift` is added only for
`campStatusToolReportsMissionsAndDeliverables`: it must use a real unique
temporary regular file and a validated typed workspace-external reference,
while preserving the mission/Card/deliverable and byte-identical replay
assertions. The already-allowlisted Harvest nonempty fixture follows the same
typed external completion path. Neither fixture may insert artifact/origin/ref
rows directly or retain `/tmp` text as ownership proof.

Both public and transaction-local nonempty raw `durablePath` overloads are
removed. No String/URL/reflection/tuple compatibility path can represent a
nonempty artifact. A no-artifact compatibility surface cannot carry one, and
BoardTools must fail a nonempty legacy completion before copy/delete/Card or
artifact mutation until F1D injects the terminal sink. Thus identity 059 can
prove raw authority is actually absent without implementing F1D behavior.

The report ownership correction covers all three live writers:
`Orchestrator`, `AppStore`, and `MissionWorkflowController.live`. All delegate
to `ManagedExpeditionReportStore`; only that owner may traverse/write the
report root and recover the sorted-key cursor. This closes the previously
unlisted third writer while remaining report creation/recovery, not deletion.

### Stage boundary

Revision 4 does not add adapter descriptors, engine terminal-sink wiring,
Discussion/Attention/Growth, Camp lifecycle/deletion permits, unlink authority,
`camp_deletion_proposal_blob` product writes, UI, or external actions. F1D and
F2 remain closed. The final F1C gate still requires 001–061 green, predecessor
assertions, source gates, Core/App builds, and an independent bounded
implementation review with 0 P0/P1.

## Finding count and review boundary

- P0: 0
- P1: 0
- P2: 0

No Swift build/test, migration or SQLite matrix, package/App preview,
credential/provider, normal-state, Git-write, or external action was run.
This approval opens only the declaration scaffold and exact-19 TDD sequence
defined by Revision 4; it is not implementation acceptance.

---

## Revision 4a Successor Review

> Successor reviewer: responsibility-isolated Codex reviewer  
> Date: 2026-08-27  
> Reviewed delta: plan §§16.1–16.3 only  
> Revision 4a `plan.md` SHA-256:
> `8dc757ea8286a8f8e4224064d742c10879046c972094f2a04e63eaac7c39cefc`

### Successor verdict

**APPROVED — 0 P0 / 0 P1**

Revision 4a closes the three compile/ownership-integration gaps without
changing scope, tests, Stage behavior, or any product byte. The original
Review01c content is preserved as the exact prefix of this file, SHA-256
`f79d8806dc0e85d27dccf764c5e92d0375ab0f8e4e96d33ce3ee1616550ccb1c`.

### Snapshot and evidence closure

`ArtifactStorageOriginSnapshotV1` now correctly conforms only to `Sendable`;
tests compare its typed fields and do not require the non-Equatable predecessor
`ArtifactRecord` to synthesize a new public conformance.

The root descriptor/snapshot fields, validated factories, canonical root-set
hash material, ordering, generation, ID, hash, and absolute-file-URL rules are
exact. “No memberwise authority” requires the implementation to suppress any
synthesized caller-usable initializer; `registered` and `frozen` are the only
package construction surfaces. Standardized path bytes are snapshot identity,
not path-prefix ownership evidence, and every root still requires no-follow
descriptor traversal before the verifier may issue proof.

The four proof values are sealed from product callers, have exact safe fields,
and are consumed only after row/Camp/version/hash/date/generation validation.
The two previously missing enums now close every associated-value shape:
managed, known-managed already absent, verified workspace external, unresolved,
and the narrower managed/verified-outside legacy-upgrade authority. Explicit
external creation remains a different typed intent and cannot fabricate
verifier evidence. The unresolved reason mapping remains exactly the accepted
Stage set; unavailable/drifted roots cannot produce outside-all-roots proof.

### Engine transaction closure

The optional Blob/Origin Store dependencies preserve every accepted
zero-artifact F1B initializer and behavior. Nil is not a fallback: a nonempty
proposal requires both dependencies and otherwise fails visibly before any
artifact or terminal projection write; zero-artifact commits do not touch
them.

For first nonempty commit, prepared-blob validation and artifact/origin/active-
reference insertion use the exact existing outer `database.pool.write` handle
before the handoff, Run/Card/Mission/proposal/execution, legacy event, receipt,
domain-event, scope, and outbox mutations. The prepared set is matched on the
full persisted identity/version tuple and exact contiguous ordinal. Any error
rolls back the entire graph, and partial existing rows are rejected rather
than upserted or healed.

Committed replay performs no staging or filesystem mutation and validates the
complete proposal-artifact to artifact/origin/reference join plus ordered
receipt artifact IDs and strict command graph. Missing, extra, partial, or
drifted state is a graph-integrity error with zero healing writes. This closes
the Store-side authority needed by F1C without moving orchestration into an
adapter.

### F1D boundary and unchanged machine scope

F1C tests may use the package seam to stage and commit a real pending proposal.
Production receipt of adapter terminal proposals, preparation/recovery, and
final commit remains the F1D `EngineTerminalSink` /
`prepareAndCommitProposal` owner. No ModelLoop/CLI/Board wiring, descriptor,
session surface, adapter SQLite access, Camp deletion authority, or F2 behavior
is opened by this successor.

The unchanged machine inputs remain:

```text
allowlist_lines=98
allowlist_sha256=9c9c0198e7570c56367c83e90e606a888bc08f7e833ed9cd82517bacb4e39020
entry_manifest_lines=47
entry_manifest_sha256=024dfaab32ff6688258439b0f57e0d37148005f4ac3f8a40854eb24bfd7fd58a
dirty_total=649
allowlisted_present_count=60
outside_count=589
outside_manifest_v1=792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88
```

### Successor finding count and boundary

- P0: 0
- P1: 0
- P2: 0

This successor review ran no Swift build/test, migration or SQLite matrix,
package/App preview, credential/provider, normal-state, Git-write, or external
action. It approves only the Revision 4a plan delta; F1C implementation still
requires the reviewed scaffold, immutable exact-19 red, functional gates, and
independent implementation review.
