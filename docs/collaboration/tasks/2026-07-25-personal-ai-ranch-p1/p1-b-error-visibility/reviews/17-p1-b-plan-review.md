# P1-B Responsibility-Isolated Plan Review17

> Date: 2026-08-16
>
> Reviewer: independent read-only review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**

## Frozen inputs reviewed

At review start, Revision15's three planning inputs had these SHA-256 values:

```text
f13c6291c79d17d19394ce9053bfd75a8373d57ce2808921be2c413db85fb469  plan.md
1456972b45fc0b6ae8413f00dea1f4831d3c85de0f73e4698428f3d8bdbe889f  try-question-mark-inventory.md
239ea4f6640bee60a7596a14836066e0dcc4ee3427e5d31e9070b2a0f2350062  blocked.md
```

All active status labels consistently name **Revision15 / Review17**. The
review preserves the pre-existing dirty worktree and writes only this review
artifact.

## Independent scope and preservation check

The implementation list is sequentially numbered 1 through 66 and contains
66 unique paths. Its two newly expanded paths are exactly the regular files:

```text
decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095  Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
0412b01bef7657f5305760d225bdcc6322dca1661395b8749e6c2dfeaec6ff43  Sources/AgentLoopCore/Kernel/Planner.swift
```

The proposed ownership boundary remains appropriate: synchronous
`streamTurn` construction must move off the cooperative executor without
making the construction wait cancellation-reactive; Supervisor retains the
shutdown deadline, cancellation ownership, and reported uncooperative ID.
The frozen test still requires `elapsed < .seconds(1)`, expects the same work
ID, and calls `release()` only after the report. No timeout relaxation,
fixture semantic substitution, declaration, scanner, descriptor, seam,
migration, or manifest-byte edit is authorized.

## Findings

### P0

None.

### P1-01 — A3/A4 arithmetic is not unchanged after adding Planner

The stated Revision15 delta adds `Planner.swift` as well as
`DurableWorkSupervisor.swift`. Unlike Supervisor, Planner is present in both
immutable 206-row manifests (A3 line 84 and A4 line 1), at the recorded
`0412…ff43` entry hash. Recomputing pathname intersections from the frozen
66-path allowlist gives **A3 raw 49** and **A4 P1-B members 46**, not the
unchanged 48 and 45 asserted by the active plan/inventory/blocked authority.
Removing only the two new paths returns the prior 64-path values 48 and 45,
which isolates Planner as the missing arithmetic delta.

Therefore the active claim that all A3/A4 math remains unchanged is false.
Before implementation, make one planning-only bounded revision that records
the correct Planner-aware successor/unaffected arithmetic and any necessary
manifest-gate treatment, then obtain a fresh independent review. Do not hide
this by changing a timeout or by omitting Planner from the stated scope.

### P2

None.

## Gate decision

**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2.**

Revision15 does not authorize implementation. The next step is a narrowly
bounded planning correction for the Planner manifest membership and gate
arithmetic, followed by a fresh frozen review. This review authorizes no
source/test, manifest, scanner, declaration, commit, push, release, or
external action.
