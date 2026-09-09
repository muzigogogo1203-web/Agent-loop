# P1-E Compatibility Plan Review — Review01i

> Date: 2026-08-27  
> Reviewer: independent Codex subagent  
> Process disclosure: the user directed the implementation owner to proceed
> without Claude. This responsibility-isolated Codex reviewer did not author
> Revision 09 and changed no product, test, plan, allowlist, or prior-evidence
> byte. The only repository write in this pass is this review artifact.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Exact reviewed delta

I reviewed only Revision 09's mechanical correction of Review01h: the new plan
and review paths, the 135-line allowlist, Review01h, the NUL-safe outside
boundary, the original ten-entry P1-E successor-owned set, and the resulting
A4/A3 arithmetic. I did not reopen Revision 08's already-closed implementation
decisions and did not run a build, focused tests, or the full suite.

The frozen inputs independently recompute as:

```text
revision_09_sha256=84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5
review_01h_sha256=76d3752943a5ddbec826ae1ae86f535d1fd0b858c1c58f2fdd39a39cc478cb43
revision_08_sha256=413c8dbcb4f8d13c17e7f014307fc3e58900ccc70d60e964497bc55e6bb260a4
allowlist_lines=135
allowlist_nonempty_unique=135
allowlist_sha256=e6cf95c710cf2c7f513740cb49894f69df4ca1ecc01fc48e8294a3291dd881bb
```

Removing exactly `plan-revision-09.md` and this Review01i path reconstructs the
133-line Revision-08 allowlist byte-for-byte:

```text
reconstructed_revision_08_lines=133
reconstructed_revision_08_sha256=581f9e5bafc80e9f480ca7faff519f6f11f02ff6ab79e6a278da392707670bbc
```

Replaying the base plan's NUL-safe outside serializer immediately before this
review gave:

```text
dirty_total=619
allowlisted_present_count=125
outside_count=494
outside_manifest_v1=b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740
```

The first two counters exactly equal Revision 09's pre-plan values plus the
allowlisted plan. Creating this allowlisted review may advance them to 620 and
126; the outside count and hash must remain unchanged.

## 2. Historical ownership arithmetic

The ten paths listed by Revision 09 exactly equal the current byte-frozen
`a3P1EHistoricalSuccessorExclusions`. The set excludes
`HaltAndCooldownTests.swift`, which is owned by P1-B, and
`BoardToolServer.swift`, which is owned by P1-D.

Both immutable manifests remain 206-entry unique sets. Independent set
subtraction gives exactly:

```text
A4_raw_P1E_intersection=40
A4_P1E_successor_owned=10
A4_unaffected=206-46-3-19-10=128

A3_raw_P1E_intersection=42
A3_P1E_successor_owned=10
A3_live_enumerated=206-7-43-3-19-10=124
```

The P1-E-owned intersection equals the original ten-entry set in both
manifests. Direct ownership checks also confirm that `HaltAndCooldownTests.swift`
is in the P1-B successor set and `BoardToolServer.swift` is in the P1-D
successor set in both calculations.

## 3. Effective implementation boundary

Revision 09 changes no product or test decision. It correctly carries forward
Revision 08's already-reviewed causal shutdown probe, package-only cooldown
clock, client-local FD lifecycle observer, default-preserving accept-queue seam,
two distinct accept/handler queues, ordered pure-red evidence, narrow gates,
source/scope gate, build, protected migration hash, packaged preview, and single
default-parallel full gate.

All five implementation pre-images and the four protected pre-images still
match the hashes frozen by Revision 08. No timeout, duration, socket protocol,
runner, parallelism, retry, scope, or external-action expansion is admitted.

## 4. Verdict

**APPROVED — 0 P0 / 0 P1.**

Revision 09 is decision-complete for its exact boundary. Source/test
implementation is authorized only within the combined Revision-08/09 plan and
its completion gates.
