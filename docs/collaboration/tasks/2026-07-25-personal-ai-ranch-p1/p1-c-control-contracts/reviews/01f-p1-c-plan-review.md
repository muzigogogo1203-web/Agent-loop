# P1-C Control Contracts Plan Review — Review01F

> Date: 2026-08-25  
> Reviewer: current Codex implementation owner, separate read-only review pass  
> Process note: user explicitly directed Codex to proceed alone without Claude;
> this is a disclosed self-review and is not represented as independent  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: Revision 6 build-gate closure only, plus regression check of
> the previously approved Revision 5 boundary

## Conduct and authority

I reviewed the frozen Revision 6 plan without changing product or test code,
running the App, launching a preview, or performing any external action. I
checked it against `AGENTS.md`, the collaboration protocol, the accepted master
spec, canonical P1 plan/stage spec, preserved Reviews01–01E, P1-B acceptance,
the current App compiler diagnostics, and the exact current source shapes.

The user has overridden the Claude/reviewer choice and requested that Codex
continue alone. This artifact therefore supplies a responsibility-separated
review pass but not reviewer independence. It does not weaken any product,
test, migration, source, build, or evidence gate.

## Frozen inputs and checkout

| Check | Result |
|---|---|
| CWD | `/Users/muzi/Agent-loop` |
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| Revision 6 plan SHA-256 | `6f86f03af3225bbd99a80e8d546c23278cadf3f486f910ce284a2bdddf06bcf1` |
| Preserved Review01E SHA-256 | `97c3171dcc7f86bb7c08ca48c06468380e0602be0503b9583faee1b8b24df2ad` |
| Failed App build SHA-256 | `bf6ff041aeb8686734000d40527ea2d564983ddadb5859e534876668cb4ea05e` |
| Preview fixture pre-image | `35050a360d84cdac4c14c748a691bfbf277c62fb7b4fb96861dfcd910417a962` |
| Planned preview fixture post-image | `c8afc50f5af67d4544ba399523aed34bb7c974e4e67dca259f813a3345ec5238` |

The embedded NUL-safe outside serializer passed unchanged:

```text
dirty_total=486
allowlisted_present_count=38
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

Ruby serializer syntax, Bash source-gate syntax, 50-fence balance, and
`git diff --check` all passed. Existing protected authority/review/package
hashes in the source gate remain unchanged; Revision 6 additionally freezes
Review01E, the failed build evidence, and the exact fixture post-image.

## Root-cause review

The failed `swift build --product AgentLoopApp` is deterministic and points to
one stale committed preview expression:

- `CodingRanchContracts.swift` now owns `suggestedMission` rather than a stored
  `missionDraft`, and `MissionDraftViewState` now requires
  `startCapability`;
- `CodingRanchStoreAdapter.swift` is the working reference: it constructs
  `SuggestedMissionReviewViewState`, derives `canStart` from the opaque
  capability, and never fabricates that capability;
- `CodingRanchPreviewFixtures.swift` is still byte-identical to HEAD and calls
  the old memberwise shape; and
- the P1-B plan includes the accepted new contracts but omitted this fixture
  from its exact write list.

The plan's single hypothesis is therefore evidence-backed: updating only that
preview constructor closes the type-shape mismatch. Setting `canStart` false
with a visible preview-only block reason and nil capability preserves the
accepted authority invariant. The later SwiftUI `Group` errors may be compiler
cascades; the plan does not assume that silently—if the single exact change
does not produce a green App build, it stops rather than authorizing a second
fix.

## Scope and gate review

Revision 6 changes no runtime view, domain model, schema, migration, command,
event, provider, concurrency, identity, or P1-D boundary. The one source delta
is fully determined by its pre/post hashes and exact field values. It cannot
start a mission because the preview carries no opaque start capability. The
failed build is preserved separately before the green build log is generated.

After the exact change, the plan still requires the complete ordered matrix,
source/hash/scope gate, App build, and authoritative unfiltered test run. The
outside manifest remains the same because the fixture and this review are
explicitly allowlisted; all non-P1-C dirty bytes remain frozen by the same
manifest.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Decision

Revision 6 is decision-complete for the one observed build-gate root cause and
retains every prior P1-C product and evidence boundary. It may proceed only
with the exact fixture replacement and ordered final gates. This approval does
not authorize another code change if the build remains red, P1-D work, commit,
push, merge, release, App/preview execution, destructive data mutation, or any
external action.

approved_plan_sha256=6f86f03af3225bbd99a80e8d546c23278cadf3f486f910ce284a2bdddf06bcf1

verdict=APPROVED — 0 P0 / 0 P1
