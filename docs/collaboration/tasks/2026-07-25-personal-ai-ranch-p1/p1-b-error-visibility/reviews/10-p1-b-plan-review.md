# P1-B Responsibility-Isolated Plan Review10

> Date: 2026-08-15
>
> Reviewer: independent read-only review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**

## Frozen inputs reviewed

The planning inputs and immutable manifests were regular files and had these
SHA-256 values at review start:

```text
8412c36b8713f13fef98313009bc27715df5415635f17249fa25d1c6a9a9497b  plan.md
e6b19ac49c78557aeb0bcef819fce65394f130464bb990057526839b993201a1  try-question-mark-inventory.md
1a3f0616610ef09c42fb3713e4a4780a61be1ff83d46ee28978c7be8cd1d93fd  blocked.md
3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e  A3 revision02-entry-source-manifest.sha256
6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71  A4 a4-entry-source-manifest.sha256
```

This review changed no product, test, plan, inventory, blocked boundary,
manifest, migration, scanner, or declaration byte. This file is the sole
review output.

## Independent manifest, source-gate, and evidence assessment

Both immutable manifests contain 206 sorted, unique paths. The current
`a3P1BExactAllowlist()` has exactly 64 unique paths. Direct pathname
intersections are 48 with A3 and 45 with A4.

For A3, the seven historical A4 exclusions overlap the 48 raw P1-B rows in
six paths. The current gate therefore correctly proves 42 successor exclusions
and 157 live rows. For A4, the current gate correctly proves 45 P1-B members,
161 unaffected rows, and 10 absent-at-entry P1-B new paths.

The immutable evidence also disproves the carried B-03 premise that A4 has an
accepted `ScheduleMath.swift` predecessor delta: `ScheduleMath.swift` occurs
once in A3 (at line 85) and zero times in the A4 manifest. Thus the A4
45/161/10 partition is already internally consistent, and the current
`broadcastFailureDoesNotRewriteStartedFire` A4 gate does not compare a
ScheduleMath row.

I independently reran:

```text
swift run RunTests --filter 'a3Revision02EntryBoundaryRemainsByteExact|broadcastFailureDoesNotRewriteStartedFire'
```

It exited zero: both tests passed (2 tests, 0.707 seconds). The preserved B-02
evidence remains bounded to its three historical assertions: its recorded
SHA-256 is
`59a672ef37cbb73b9be01785309bcfcbfde111db01f3416b0f7ecd65628a53b1`
and its terminal record is `3 tests in 1 suite passed`. No timeout relaxation,
product, migration, scanner, immutable-manifest, or declaration change is
supported by this review.

## Findings

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | No product, migration, scanner, immutable-manifest-byte, or declaration-count mutation was found. |
| P1 | 1 | **Revision09 retains a false active B-03 narrative.** `plan.md` lines 74–80 and `blocked.md` lines 20–39 say the A4 unchanged-row check compares an accepted `ScheduleMath.swift` delta. The frozen A4 manifest has no such path, the current 45/161/10 gate passes, and the targeted test passes. Retaining this false causal account makes the frozen execution boundary misleading and invites another avoidable gate stall. Make one bounded documentation-only correction: state that ScheduleMath is an A3 historical exclusion, not an A4 manifest row; preserve the already-verified A3 48/42/157 and A4 45/161/10 arithmetic, the B-02 boundary, and all code/manifests. |
| P2 | 0 | None. |

## Gate decision

**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2.**

Do not enter implementation under Revision09. A bounded Revision10 may correct
only the false ScheduleMath/A4 causal narrative in the frozen planning inputs,
then requires a fresh independent zero-P0/P1 review. It must not alter the
already-passing gate arithmetic, B-02 scope, product code, manifests,
migrations, scanner, declarations, or the independent cancellation-ignoring
provider one-second shutdown bound.
