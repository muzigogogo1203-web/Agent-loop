# P1-B Responsibility-Isolated Plan Review08

> Date: 2026-08-15
>
> Reviewer: independent read-only review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## Frozen inputs reviewed

The review began from the current planning-input bytes:

```text
5137b6ece11d2b8f0dee59e07dcd47bac9ecbb09e6eff11f8417727496b01c98  plan.md
5ae03eecc3b947e3f9f87c45ed891651041a52cc0d5cfd9e0ff5410818f07059  try-question-mark-inventory.md
650f91350b5f54b23a833ea41b2cbef5489219e6f741dd1d696ee17727473e56  blocked.md
```

The immutable manifests are present, regular, and retain their asserted
SHA-256 values:

```text
3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e  A3 revision02-entry-source-manifest.sha256
6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71  A4 a4-entry-source-manifest.sha256
```

This review changed no product, test, planning, inventory, manifest,
migration, scanner, or declaration byte. This file is the sole review output.

## Independent manifest and source-gate assessment

The current source implementation of `a3P1BExactAllowlist()` contains exactly
64 paths. Direct pathname intersections with the two 206-row immutable
manifests are 48 (A3) and 45 (A4). Both B-02 test paths occur in both manifests
at their recorded entry hashes. In the actual A3 source gate, the seven A4
historical exclusions intersect the 48 A3 P1-B rows in six paths; subtraction
therefore leaves 42 successor exclusions and 157 live rows. Those claims are
correct.

The current A4 source gate, however, calculates:

```swift
let unaffectedEntries = entries.filter {
    !p1bEntryIntersection.contains($0.path)
}
#expect(unaffectedEntries.count == 161)
for entry in unaffectedEntries {
    #expect(try a3SHA256(at: url) == entry.hash)
}
```

Consequently it still requires the A4 entry hash for
`Sources/AgentLoopCore/Kernel/ScheduleMath.swift`. That path is not in the
64-path P1-B allowlist and its current SHA-256 is
`fab4ca7e02a1cf141a0ded3f5c8554fca492c661327e2c360602fdc1105cc6fc`,
not the A4 immutable entry hash
`49ca61975fad4ecedd79291445669a6bd86cc35334881bf8a4bb0ce84ddb9f46`.
Thus the stated `45 / 161 / 10` description preserves the known B-03 failure;
it does not specify the required exception/partition for the already accepted,
pre-P1-B ScheduleMath delta.

The plan and blocked boundary correctly retain the cancellation-ignoring
provider shutdown as a separate root-cause gate and retain its one-second
bound. No timeout relaxation is proposed. The described product/migration/
scanner/immutable-manifest/declaration scope is otherwise bounded to the
existing `DurablePlanningTests.swift` gate plus the two prior B-02 test paths.

## Findings

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | No proposed product, migration, scanner, immutable-manifest-byte, or declaration-count mutation was found. |
| P1 | 1 | **A4 B-03 algorithm remains red.** `plan.md` and the inventory call all 161 non-P1-B A4 rows unaffected, and the current gate verifies every one. That set includes the known changed `ScheduleMath.swift`, so the proposed arithmetic cannot make the recorded A4 failure pass. The bounded revision must state and implement the pathname-exact accepted A4 predecessor exclusion (and the resulting checked-row arithmetic), while preserving immutable manifest bytes and all unrelated rows. |
| P1 | 1 | **The frozen execution gate is internally inconsistent.** The three documents label the candidate Revision07 and require Review08, but `plan.md` §1 still says that no change is authorized before fresh `Review07`. Correct the stale gate reference and Revision06 wording where it defines the currently pending correction, so the next review/implementation authority is unambiguous. |
| P2 | 0 | None. |

## Gate decision

**CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2.**

Do not enter implementation under Revision07. A bounded Revision08 may correct
only the A4 immutable-gate partition/count and the stale revision/review
references across the three planning inputs, then must receive a fresh
independent zero-P0/P1 review. It must not change product, migration, scanner,
immutable-manifest bytes, declarations, or the cancellation-ignoring-provider
one-second shutdown bound.
