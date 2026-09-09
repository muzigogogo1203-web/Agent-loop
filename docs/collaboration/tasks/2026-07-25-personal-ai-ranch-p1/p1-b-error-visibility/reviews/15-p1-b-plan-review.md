# P1-B Responsibility-Isolated Plan Review15

> Date: 2026-08-16
>
> Reviewer: independent read-only review
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## Frozen inputs reviewed

At review start, the three Revision13 planning inputs had these SHA-256
values:

```text
cbd3fde3cf832f1a480b797bc15c46f9c17b11d95f14af72c1ffb6919434469b  plan.md
c8ce714caabd33ad379cde1ffa68833043ff92b762e5a810b93aa6abb8ad23d7  try-question-mark-inventory.md
6abe0b954f94b4eacf1703ed7e7ccfd72c93c6c85a285299ec7e02ac0f7d100b  blocked.md
```

All three active status labels consistently name **Revision13 / Review15**.
This review writes only this immutable review artifact; it preserves the
pre-existing dirty worktree and changes no production, test, planning,
inventory, blocked-boundary, manifest, scanner, descriptor, declaration, or
evidence-log byte.

## Independent scope, manifest, and root-cause check

The Revision13 implementation list contains exactly 65 pathname literals. Its
only delta from the prior 64-path P1-B slice is the already-existing regular,
non-symlink source
`Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`; its current entry
SHA-256 is the frozen
`decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095`.
No test declaration, scanner, descriptor, seam, migration, or ownership
surface is added.

`R01CancellationIgnoringProvider.streamTurn` synchronously waits on an
`NSCondition` before returning its stream. The normal rumination path calls
that synchronous construction from an async provider-processing task. Under
the parallel authoritative suite, that can occupy a cooperative executor
thread while shutdown needs its deadline work scheduled. The described repair
therefore targets the causal boundary: the Supervisor may wrap only stream
construction so it executes off that cooperative executor, while the existing
RuminationService continues to consume the same stream. It preserves the
cancellation-ignoring fixture contract, its explicit later `release()`, the
expected uncooperative work ID, and `elapsed < .seconds(1)`. It is not a
timeout relaxation or an async-fixture semantic substitution.

Both frozen manifests contain 206 rows. Independent pathname checks confirm
that `HaltAndCooldownTests.swift` and `DurableWorkTests.swift` are members of
both; `ScheduleMath.swift` is present in A3 and absent from A4; and
`DurableWorkSupervisor.swift` is absent from both immutable manifests. Since
the Supervisor was already in A3's historical original-allowlist exclusion,
its newly authorized implementation delta does not change the frozen gate
arithmetic: A3 remains 48 raw / 42 successor / 157 live and A4 remains 45
P1-B members / 161 unaffected / 10 absent-at-entry new paths.

## Findings

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | None. The only proposed source addition is explicit, byte-fingerprinted, and confined to the causal Supervisor boundary. |
| P1 | 0 | None. The proposal preserves the synchronous cancellation-ignoring test semantics and strict shutdown bound without changing ownership or historical manifest authority. |
| P2 | 0 | None. |

## Gate decision

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

Revision13's planning gate is satisfied. The next step may implement only the
Supervisor's described synchronous-`streamTurn` construction isolation and
run the frozen validation. This review does not authorize any other path,
test declaration change, timeout relaxation, manifest/scanner change, commit,
push, release, or external action.
