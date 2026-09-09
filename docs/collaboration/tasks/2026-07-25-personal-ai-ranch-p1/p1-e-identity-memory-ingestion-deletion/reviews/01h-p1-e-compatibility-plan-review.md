# P1-E Compatibility Plan Review — Review01h

> Date: 2026-08-27  
> Reviewer: independent Codex subagent  
> Process disclosure: the user explicitly directed the implementation owner to
> proceed without Claude. This responsibility-isolated Codex reviewer did not
> author Revision 08 and changed no product, test, plan, allowlist, or prior
> evidence byte. The only repository write in this pass is this review artifact.  
> Checkout: `/Users/muzi/Agent-loop`  
> Branch / HEAD: `codex/personal-ai-ranch-p0` /
> `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 1. Frozen inputs and independent recomputation

I reviewed only the exact Revision-08 correction boundary: Revision 08, its
133-line allowlist, Review01g, the five implementation pre-images, the four
protected pre-images, the NUL-safe outside manifest, the A4/A3 raw and ownership
arithmetic, and the proposed accept/handler queue seams. I did not run a build,
the full suite, or a chance-green retry.

The frozen document inputs recompute exactly:

```text
revision_08_sha256=413c8dbcb4f8d13c17e7f014307fc3e58900ccc70d60e964497bc55e6bb260a4
allowlist_lines=133
allowlist_nonempty_unique=133
allowlist_sha256=581f9e5bafc80e9f480ca7faff519f6f11f02ff6ab79e6a278da392707670bbc
review_01g_sha256=6aa406c379e7200946e61307ec843078333df7f580c4634c1383709bd44dc247
```

The five implementation pre-images match Revision 08:

| File | SHA-256 |
|---|---|
| `BoardToolServer.swift` | `ab681c9982c537e0f6777f85e3d482c022c0d10182f9335efe0d7902364044ea` |
| `BoardServerTests.swift` | `ea974b23b544fd353772935440f38f07916f406befccc0bfe245d3b30c6e1dda` |
| `Orchestrator.swift` | `4dcfa183d6a7e85d31651d7dded45a5adb624a4cda01677c010c7727efc1e087` |
| `HaltAndCooldownTests.swift` | `339d8ddf8c1bc0514590a813f3ebab671885c5b5ed2b6dfe231b3e5810a13b6a` |
| `DurablePlanningTests.swift` | `c05d633ff65e7f7edf25c35bbbf8ab2a18bd23c35887e7eba6c070011f8c07d5` |

The four protected pre-images also match:

| File | SHA-256 |
|---|---|
| `DurableWorkSupervisor.swift` | `e4efbd3679549cb3db6d87aa7a1272c7b200ba5ac35781a2d626b7e1b75beaae` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Package.swift` | `0a4b9d3c4eba1a06bda535e69c54c3a5186dcaf148bcb489f1667b4c069cba48` |

Replaying the base plan's NUL-safe serializer immediately before this review
gave:

```text
dirty_total=617
allowlisted_present_count=123
outside_count=494
outside_manifest_v1=b43597a523f6001057b226272b7b5eb95b099691f2b142e87e310b4ce5a5d740
```

The first two counters are exactly the Revision-08 pre-plan values plus the
allowlisted plan itself. Creating this allowlisted review may advance them to
618 and 124; the outside count and hash must remain unchanged.

## 2. Review01g accept-loop finding is closed

The proposed `acceptQueue` seam is source-compatible and default-preserving:
the initializer default is the exact current global utility queue and `start()`
changes only the submission site from that literal queue to the stored queue.
Listener ownership, stop/wake behavior, and socket semantics remain unchanged.

The framing test controls both scheduler boundaries with two distinct
user-initiated serial queues and proves each queue can execute before server
construction. Keeping the queues distinct is necessary and sufficient to avoid
the accept loop blocking its own handler dispatch in `accept()`. The timeout
test retains its separately suspended handler queue and the live/default accept
queue. This fully addresses Review01g's accept-loop P1 without a timeout,
duration, retry, or production-behavior change.

The retained shutdown deadline probe, injected cooldown clock, and client-local
FD lifecycle observer are decision-complete and implementable. Their ordered
tests-first red requirements preserve the real provider, real socket/close
path, unrelated pipe, exact 400ms boundary, twenty iterations, and existing
assertions.

## 3. Finding

### P1 — the A4/A3 P1-E ownership arithmetic assigns a P1-B-owned test to P1-E

The raw intersections in Revision 08 are correct:

```text
A4_manifest_sha256=6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71
A4_raw_P1E_intersection=40
A3_manifest_sha256=3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e
A3_raw_P1E_intersection=42
BoardToolServer_present_in_both=true
HaltAndCooldownTests_present_in_both=true
```

However, `HaltAndCooldownTests.swift` is already in the exact 66-entry P1-B
allowlist. Under the frozen ownership subtraction it belongs to the P1-B
successor set, so it is removed before the P1-E successor intersection is
formed. `BoardToolServer.swift` is similarly removed by the P1-D successor set,
which agrees with Revision 08's narrative.

Independent set recomputation therefore gives:

```text
A4: 206 - 46(P1-B) - 3(P1-C) - 19(P1-D) - 10(P1-E) = 128 unaffected
A3: 206 - 7(A4 historical) - 43(P1-B) - 3(P1-C) - 19(P1-D) - 10(P1-E) = 124 live/enumerated
P1E_historical_successor_exclusions=10
```

The proposed eleven-entry set containing `HaltAndCooldownTests.swift`, A4
unaffected count 127, and A3 live/enumerated count 123 cannot all satisfy the
existing ownership equations. Implementing them as written makes both
historical sentinel tests fail for a planned cause.

The bounded correction is exact: retain the ten-entry
`a3P1EHistoricalSuccessorExclusions`, keep the correct raw intersection counts
40 and 42, and set A4 unaffected to 128 and A3 live/enumerated to 124 in the
plan, source gate, and planned test expectations. No source-scope expansion is
needed.

## 4. Verdict

**NEEDS CHANGES — 0 P0 / 1 P1.**

Review01g's accept-loop finding is closed, but no source or test implementation
is authorized until the ownership arithmetic above is corrected and reviewed.
