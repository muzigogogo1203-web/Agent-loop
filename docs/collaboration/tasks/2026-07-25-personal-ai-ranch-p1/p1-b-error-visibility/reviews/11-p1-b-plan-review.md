# P1-B Responsibility-Isolated Plan Review11

> Date: 2026-08-15
>
> Reviewer: independent read-only review
>
> Verdict: **CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2**

## Frozen inputs reviewed

At review start, the planning inputs and immutable manifests were regular files
with these SHA-256 values:

```text
4dafb4073e62c73efdc3e0e8b517f91a4e45175450f230d7f3bb05797c8c7cf1  plan.md
6e7eb0f28ae1c844cfb1240be2ef520be3381bb8bb5db1dab9ecdb191659e147  try-question-mark-inventory.md
174404ebf343f8fe94c5be8481de65d3f58e454120766131490af232829b5a4c  blocked.md
3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e  A3 revision02-entry-source-manifest.sha256
6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71  A4 a4-entry-source-manifest.sha256
```

This file is the sole review output. No product, test, plan, inventory,
blocked-boundary, manifest, migration, scanner, or declaration byte was
changed by this review.

## Independent arithmetic and targeted-gate check

I parsed the 64 unique pathname literals in `a3P1BExactAllowlist()` and the
two immutable 206-row manifests directly. The immutable membership correction
is correct:

| Check | Independent result |
|---|---:|
| Exact P1-B allowlist | 64 |
| A3 raw P1-B intersection | 48 |
| A3 successor exclusions | 42 |
| A3 live rows | 157 |
| A4 P1-B members | 45 |
| A4 unaffected rows | 161 |
| A4 absent-at-entry P1-B new paths | 10 |

`Sources/AgentLoopCore/Kernel/ScheduleMath.swift` occurs in A3 and does not
occur in A4. It is one of the A3 historical exclusions, but not one of the six
A3 raw-P1-B/historical overlaps; no A4 unchanged-row check compares it.

I also reran the bounded source gates:

```text
swift run RunTests --filter 'a3Revision02EntryBoundaryRemainsByteExact|broadcastFailureDoesNotRewriteStartedFire'
```

The command exited zero. Both named tests passed (`2 tests in 0 suites`,
`0.828 seconds`). The gates therefore independently prove the corrected
64 / A3 48-42-157 / A4 45-161-10 arithmetic against the current immutable
manifests.

## Findings

| Severity | Count | Finding |
|---|---:|---|
| P0 | 0 | The manifest hashes remain exact, the corrected pathname arithmetic is true, and the two targeted gates are green. No product, migration, scanner, manifest-byte, or declaration mutation is supported or needed. |
| P1 | 1 | **The active execution condition still names Review10, which rejected this candidate class.** `plan.md` line 84 and `blocked.md` line 45 say implementation may resume only after immutable/fresh `Review10` returns zero P0/P1, while each file's status line correctly requires `Review11`. Review10's actual verdict is `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`; retaining it as a possible release gate makes the frozen authority contradictory. Replace only those active B-03 gate references with `Review11`; retain historical Review10 references and all scope/arithmetic evidence. |
| P1 | 1 | **Revision10 expands the frozen evidence surface without a stated bounded need.** Review10 froze `try-question-mark-inventory.md` at `e6b19ac49c78557aeb0bcef819fce65394f130464bb990057526839b993201a1`; the current Revision10 input is `6e7eb0f28ae1c844cfb1240be2ef520be3381bb8bb5db1dab9ecdb191659e147`. The prior required correction was limited to the false ScheduleMath/A4 causal narrative in the planning inputs, and neither current B-03 text explains why the large inventory is an authorized transitive edit. Either restore that immutable inventory byte, or document a mechanical, scoped reason and independently verify its exact permitted delta before the next review. |
| P2 | 0 | None. |

## Gate decision

**CHANGES REQUIRED — 0 P0 / 2 P1 / 0 P2.**

Do not enter implementation. A bounded Revision11 may (1) align the two active
B-03 release-gate labels with Review11 and (2) eliminate or explicitly bound
the unexplained inventory drift. It must preserve the verified 64 / A3
48-42-157 / A4 45-161-10 arithmetic, B-02 boundary, targeted gates, product
code, manifests, migrations, scanner, declarations, and the independent
one-second cancellation-ignoring-provider shutdown root-cause gate.
