# P1-B Responsibility-Isolated Plan Review07

> Date: 2026-08-15
>
> Reviewer: independent read-only review
>
> Verdict: **APPROVED — 0 P0 / 0 P1 / 0 P2**

## Frozen inputs reviewed

The review began from the current planning-input bytes:

```text
50f9500268897cf73ce626300856fc3f43a197758d9dd66198e4fd3e72ea0f42  plan.md
e33256d2eca82f8040b9310df01ef0c03d6d6ab375ad051270f693d2ac8bc818  try-question-mark-inventory.md
17c93960059a12d8b3f86b6037ae5d23b1fb3da17d21f24b2776e6311d1f01fd  blocked.md
```

The immutable manifests themselves still match their asserted SHA-256 values:

```text
3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e  A3 revision02-entry-source-manifest.sha256
6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71  A4 a4-entry-source-manifest.sha256
```

No product, test, planning, manifest, migration, scanner, or declaration byte
was edited by this review. This file is the sole review output.

## Independent manifest and gate assessment

The plan's numbered implementation list contains exactly 64 paths. Direct
pathname intersections against both 206-row immutable manifests confirm 48 A3
members and 45 A4 members. Both Revision05 test paths are present in both
manifests at the frozen hashes recorded in the plan.

The A3 successor arithmetic is correct. Although the historical A4 exclusion
set has seven paths, `ScheduleMath.swift` is not in the current 64-path P1-B
allowlist. Its intersection with the 48 A3 P1-B rows is therefore six, leaving
42 P1-B successor exclusions and 157 live rows. The four accepted A4-only
implementation members outside P1-B are exactly
`DurableWork.swift`, `DurableWorkSupervisor.swift`,
`DurableWorkStore.swift`, and `ScheduleMath.swift`; excluding the 45 P1-B
members and these four leaves the stated 157 A4 unchanged rows.

The current `DurablePlanningTests.swift` has not yet implemented Revision06:
its exact allowlist assertion remains 62, A3 remains `46 / 6 / 40 / 159`, and
A4 remains `43 / 163 / 10`. That is expected before the proposed bounded
implementation, but it means approval must rely on a fully coherent Revision06
specification.

The proposed scope remains appropriately narrow in intent: only the existing
manifest-gate arithmetic in `DurablePlanningTests.swift`, plus the two
already-authorized B-02 test paths; no production, migration, scanner,
immutable-manifest-byte, or test-declaration change is authorized. The
shutdown failure remains a separate root-cause gate and its one-second bound
must not be relaxed.

## Findings

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | No newly proposed product, schema, or manifest-byte mutation was found. |
| P1 | 0 | No missing authority, incorrect manifest arithmetic, scope expansion, or timeout weakening found. |
| P2 | 0 | None. Revision06 now explicitly marks the superseded Revision05 membership/arithmetic assertion and names the four accepted A4-only paths. |

## Gate decision

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

Revision06 may enter its bounded implementation gate: only the existing
`DurablePlanningTests.swift` manifest arithmetic and the two already-authorized
B-02 test paths may change. No production, migration, scanner,
immutable-manifest-byte, test-declaration, or shutdown-timeout change is
authorized. The cancellation-ignoring-provider shutdown failure remains a
separate root-cause gate; its one-second bound must not be weakened.
