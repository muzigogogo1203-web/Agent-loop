# R28 Plan Freeze — Shell timeout measurement boundary

> Status: `FROZEN — REVIEW28 PENDING`
>
> Date: 2026-08-10
>
> Branch / HEAD: `codex/personal-ai-ranch-p0` / `02334ec8d21533be81d93d39191bc7d9b9c24f7f`

This freeze is the exact R28 planning object. It supersedes R27 only as the
current execution candidate; every R15–R27 historical result and artifact
remains immutable evidence. R27 is permanently `REJECTED_CONTAMINATED` and
cannot be retried, rewritten, or used as green evidence.

## 1. Frozen control surfaces

The six current control surfaces contain one byte-identical R28 EOF body:
116 newline-terminated lines, 8,817 bytes, SHA-256
`f7245b4202c9dd3c62e7febde3c99ee6ab2b37b7215fdc3ee0f9fdb7b3252183`.

| Surface | Lines | Bytes | SHA-256 |
|---|---:|---:|---|
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | 10,458 | 608,371 | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | 6,217 | 402,717 | `dfec20e698d73ef533c8539292e61508873239933a203f8a9050829669d94948` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | 2,409 | 163,832 | `9fdda7f4b8c6d8ce6cf7fcf3e9db2c7bac345f905ea8ea0fe29adf3294087671` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/blocked.md` | 2,076 | 136,687 | `6f37b6e2586927ee3146dbfb0141b4156c3797ac817eba9b47fd3873f40c2a0f` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md` | 983 | 79,230 | `d988f24af8cfd64a0e725751d389dbd3127c2c3b99d3bc925207705488848e09` |
| `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md` | 929 | 83,440 | `a6ae00c3be8eba8316e918264b6057400b9348ceaecf755fa0122855adfbedc9` |

The frozen driver is `evidence/r28-begin.sh`: 5,970 lines, 309,526 bytes,
mode 0755, SHA-256
`2f84ff2167faed7a1d677003f36d57548896d4a323ffe9980926fa8f8b0745c7`.
It passes `/bin/bash -n`. The frozen entry manifest is
`evidence/r28-entry.sha256`: 235 lines, 42,488 bytes, SHA-256
`9d5fbeb6556a293dddb67fed80ea7983a920f4952c3f5f7ed11a5fb56e945dfc`.

## 2. R27 immutable rejection

R27 anchors are fixed as follows:

- freeze `6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41`;
- Review27 `74d20ed9909ba576beaba86659672c423686a7f798adf5bfbc6929607f606e5f`;
- driver `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d`;
- manifest `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e`.

The only R27 authoritative invocation consumed BEGIN, ran one unfiltered
`swift run RunTests`, and ended 651/652 with Swift/tee status `1/0`. Its only
issue was the elapsed assertion in `shellTimeoutTerminatesProcess()`:
5.13908825 seconds was not below 5 seconds. Targeted audit, build, release,
object, matrix, source/privacy, bundle, preview, screenshot, report, and END
did not occur. Its ten repository runtime files and their exact SHA/byte
identities are frozen by the six current surfaces and the driver. R27 report
and screenshot remain absent.

R27 exact roots are only:

- `/private/tmp/agentloop-r27-state.rc7ama`;
- `/private/tmp/agentloop-r27-bundle.6Q3UjM`.

Their planning baseline is `11`. R28 may observe only these two fixed root
entries with `lstat`, using an erosion-only state machine. It must never enter,
enumerate, open, hash, clean, rename, or reuse either root or any descendant.

## 3. Root cause and exact implementation

The failure is a contaminated measurement boundary, not a ShellTool timeout
state-machine failure. The test starts its clock before
`await LoginShellEnvironment.shared.environment()`, while ShellTool establishes
the command deadline only after environment resolution and `process.run()`.
The login-shell capture has its own 5-second safety guard; the command timeout
and termination grace are each 300ms. A cold capture plus the command lifecycle
can therefore legitimately exceed the test's 5-second wall-clock ceiling.

The sole implementation file is
`Sources/AgentLoopTestSuite/ShellToolTests.swift`.

- entry SHA-256: `c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`;
- expected final SHA-256: `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`.

Inside `shellTimeoutTerminatesProcess()`, immediately before the existing
`let clock = ContinuousClock()`, add exactly one newline-terminated line:

```swift
    _ = await LoginShellEnvironment.shared.environment()
```

Deleting exactly that line from final bytes must reconstruct the entry SHA.
The `< .seconds(5)` assertion, 300ms timeout, 300ms grace, `sleep 30`, captured
output checks, timeout error check, and registry cleanup check remain unchanged.

The following product witnesses must remain byte-identical:

- `Sources/AgentLoopCore/Tools/ShellTool.swift`:
  `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf`;
- `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift`:
  `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`.

R28 forbids threshold expansion, test serialization/reordering/filtering,
retry, environment injection, single-flight changes, public/package API
changes, and every other product/test/App/Package/schema/migration/permanent
script change. Login-shell single-flight remains a separate P2 candidate.

## 4. Manifest and phase partitions

The 235 paths are exactly the complete R27 220-path set plus fifteen disjoint
additions: the R28 driver; immutable R27 manifest, freeze, Review27; the ten
actual R27 runtime files; and the ShellToolTests entry baseline. All 235 targets
are regular non-symlink files, absolute paths are bytewise sorted and unique,
and the pre-patch manifest verifies 235/235.

The required partitions are:

- current R27 manifest: 214 unchanged + six expected control-surface mismatches;
- R28 before implementation: 235/235;
- R28 after the reviewed one-line change: 234 unchanged + one exact
  ShellToolTests mismatch;
- matrix mutation window: 233 unchanged + the exact ShellToolTests mismatch +
  one owned matrix-script mismatch;
- matrix restoration, pre-preview, and END: 234 unchanged + the one authorized
  ShellToolTests mismatch.

The R28 manifest excludes itself, this freeze, Review28, all twelve future R28
runtime/report/screenshot paths, both fresh roots, and invocation-owned hidden
stages. Any additional mismatch, missing member, type drift, or pathname drift
fails closed.

## 5. Review, implementation, and execution order

Review28 must be independent. The reviewer did not author these six surfaces,
the driver, manifest, freeze, or source delta. Its only repository write may be
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/28-p1-plan-review.md`.
It must emit exactly one `Verdict: APPROVED — 0 P0 / 0 P1` and one 12-field
`R28_MACHINE_BLOCK`, binding the current freeze, driver, manifest, branch,
HEAD, and `manifest_count=235`, with:

- `authority_mode=standing_goal_automatic_after_review28`;
- `standing_goal_authority_verified=true`;
- `reviewer_independence_attested=true`;
- `reviewer_write_scope=review28_only`;
- `user_hash_echo_required=false`.

Only after exact Review28 approval may the root agent use `apply_patch` to add
the one frozen test line in the pre-BEGIN window. The frozen driver never
writes source. Before creating a boundary it must independently prove the
final source SHA, strip-to-entry identity, immutable product hashes, steady
234+1 manifest, review identity, branch/HEAD, process absence, fresh R28
runtime absence, predecessor evidence, and lifecycle constraints. Failure in
that pre-BEGIN window writes no R28 runtime evidence and does not consume the
execution boundary.

After BEGIN, one Bash 3.2 process must execute the complete chain without
handoff or retry:

1. fresh boundary/runtime files and fresh R28 state/bundle roots;
2. unique unfiltered `swift run RunTests`, with immediate two-element
   `PIPESTATUS`, terminal 652/652, same-log A2 46/46, and separate
   `shellTimeoutTerminatesProcess` discovery/pass/failure `1/1/0`;
3. debug app build, bundle assembly/signing, and launch-ready proof;
4. guard/strip, exact release Core and TestSuite targets, and four-object
   release/debug symbol gates;
5. SQLite 3.51/3.52 matrix with the exact two-mismatch window and mandatory
   restoration;
6. remaining source/privacy/final-hash gates;
7. same-bundle bootstrap B01–B06 and cold C01–C09 using the isolated state root;
8. staged screenshot and implementation report publication;
9. final 234+1 proof and tiny commit-wins `END`.

Any failure after BEGIN permanently marks that invocation
`REJECTED_CONTAMINATED`; no same-boundary retry, patch-on-failure, alternate
root/object/binary, log replacement, evidence rewrite, or predecessor result
substitution is allowed.

## 6. Entry, completion, and red lines

Entry requires Review28 approval, the unchanged standing Goal, the exact
pre-patch source, and all planning identities above. The one-line patch is the
only implementation authorization. Completion requires the exact R28 END and
every technical gate in section 5.

Only then may an independent Review02 run; only Review02 with zero P0/P1 may
open A2 acceptance. A3 and every later slice remain closed until A2 acceptance.
Commit, push, merge, release, destructive or normal-data operations, payment,
public communication, external-system action, and real-user action are not
authorized.
