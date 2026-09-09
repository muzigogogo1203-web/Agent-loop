# Independent A4 packaging successor implementation review

2026-09-06. Responsibilities-separated Codex reviewer.

## Verdict

Approved for the exact one-file historical gate amendment. No findings or plan deviations. This is static implementation approval only; the parent owns focused execution and all remaining full-suite and acceptance evidence.

Read `package-historical-gate-plan.md` and `package-historical-gate-impl-report.md`, and independently examined the entire diff against `package-historical-gate-before/DurablePlanningTests.swift`.

## Verified scope and logic

The diff adds only the dated singleton declaration and changes the A4 verification block. The singleton is constrained by both cardinality 1 and equality to the literal `scripts/run-app.sh` set. Its selected entry set is separately checked against that literal and has count 1.

The original `unaffectedEntries` filter and literal count 105 remain unchanged. Complementary membership filters partition those same entries into the reviewed launcher and 104 byte-exact entries, with an explicit sum of 105. Every one of the 104 entries retains the existing regular/nonsymlink check and comparison against its original manifest hash. The launcher receives its own regular/nonsymlink check and exact reviewed Fix 1 SHA checkpoint. There is no unchecked successor and no directory or generic script exemption.

All prior A4 partition declarations, arithmetic, manifest SHA/count/order/uniqueness assertions, and surrounding behavioral assertions are unchanged. The complete source diff shows no A3 change. No historical manifest or allowlist is amended, and `package-app.sh` receives no new exemption.

## Measured identities

- Reviewed `DurablePlanningTests.swift`: `56b504731d1bff1432e36c82289c1013df033d1dd383c7fc7b5318ca3e6ff06b`.
- Supplied preimage: `b8b3640e1b7d0093e55efd4dc31a72ee0f500302743afd024ad014ce5e293a9f`.
- Historical A4 manifest: `6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71`, matching the retained historical expectation.
- Current launcher: `34ff641b68379e1978367cd2c5c9890638c5913627942858767efe56b475428c`, matching the separately pinned successor expectation.

No source edits, builds, tests, script execution, App/process operations or data changes were performed. This reviewer wrote only this review. Parent focused A4 verification is pending from this review's perspective; this amendment does not resolve or accept any unrelated full-suite failure.
