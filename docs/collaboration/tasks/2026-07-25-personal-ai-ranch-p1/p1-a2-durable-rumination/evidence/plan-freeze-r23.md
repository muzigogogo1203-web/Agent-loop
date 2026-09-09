# R23 Plan Freeze — Erosion Snapshot and Release Configuration Repair

> Date: 2026-08-10
>
> Branch: `codex/personal-ai-ranch-p0`
>
> HEAD: `02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> Scope: planning/control plane only; no caller, BEGIN, test, build, migration
> matrix, source gate, bundle assembly/signing, preview, or product/test/App-script
> implementation was run.

## 1. Frozen current status

All six current control surfaces use this exact status:

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — VOLATILE ROOT STATE DRIFT；R22 PLAN CHANGES REQUIRED — NOT EXECUTED — PARTIAL HISTORICAL BUNDLE SKELETON；R23 Erosion-Snapshot Candidate Frozen；Review23 Pending；A2 Clean Re-verification Frozen`

R23 is the only current A2 planning gate. R12–R21 are immutable execution or planning
predecessors; R22 is the immutable changes-required planning predecessor. No historical
approval, partial green evidence, or stopped invocation authorizes or proves R23 completion.

## 2. Immutable R22 and Review22 facts

| Anchor | SHA-256 |
|---|---|
| `plan-freeze-r22.md` | `839a46ad50d8bb943240267679e5878613d7ee42b5664106b4dc5b0a3dc1a8bf` |
| `reviews/22-p1-plan-review.md` | `bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5` |
| `r22-begin.sh` | `55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713` |
| `r22-entry.sha256` | `57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8` |
| R22 manifest path set | `9f05ff05ab0201995cea6f903fd466f0b1fc3fd32cdf424f086da1cf47252803` |

Review22's unique verdict is `CHANGES REQUIRED — 0 P0 / 1 P1`. Its independent,
read-only observation found the exact R20 bundle parent and `AgentLoop.app` still present,
but only six historical directories and zero regular files remained. `Info.plist` and the
executable were absent, and strict codesign returned nonzero. R22 therefore could not classify
the live root as either its fully verified retained App or an absent tombstone.

R22 was never invoked: no caller, BEGIN, boundary, runtime artifact, state root, or bundle root
was created. Its standing authorization was not consumed. All twelve R22 runtime paths and both
R22 fresh-root globs remain absent and must never be backfilled, renamed, or reused.

Core and TestSuite remain byte-identical to the R20-final entry state:

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`:
  `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`;
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`:
  `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`.

## 3. Frozen six surfaces

| Surface | SHA-256 |
|---|---|
| canonical Stage `p1-stage-spec.md` | `b54d8b5fb92108b45a783480706dde434328a1fd7bca88da1f391aed32bd97fb` |
| canonical total Plan `p1-plan.md` | `6ad24bf4c8c836e9ed70831c1206b90d7cdeeea9038d311578b030d839f073a2` |
| A2 leaf `plan.md` | `7d88c0886814c3d03063373fe4ec91463ac107798eaa5a9d06178b4acb5f785e` |
| A2 `blocked.md` | `18effbd7a9c6559fa2d1be8e90e42dac17c97070f8d995a0aa63469872200b1f` |
| P1 Stage control index | `4d8295780cd17299650c151c495c46f83d88713c88acdef1868d7913728ac745` |
| P1 Plan control index | `1a4156ab2518fa2bc16b89c926a96fdd8ed6554ca3eb261fa2e7ae1bccd97996` |

The canonical Stage §30, total Plan §20, and A2 leaf §15 Open Questions each contain
exactly `无。`. Current indexes distinguish immutable repository/historical observations from
volatile roots; they do not claim the current partial R20 bundle is a signed App.

## 4. Fixed 38-bit erosion universe

The Review22 planning observation is frozen as this 38-bit baseline:

`11101011100000000000000000000000000010`

The fixed positions are:

| Bits | Identity |
|---|---|
| 0 | exact R20 bundle parent `/private/tmp/agentloop-r20-bundle.30V5RH` |
| 1 | its exact direct child `AgentLoop.app` |
| 2–37 | the 36 historical App nodes, in the exact `R23_R20_EXPECTED_NODE_TRIPLES` order |

The baseline has exactly eight set bits: 0, 1, 2, 4, 6, 7, 8, and 36. They represent the
parent, App, and the six remaining historical directories. The driver accepts only these
shape families:

- all-zero: bundle parent and App absent;
- `10` plus 36 zeroes: exact parent only;
- `11` plus a subset of the frozen 36-node mask: App subset;
- `11` plus 36 ones: complete historical set, subject to full file/hash/aggregate/codesign proof.

`01`, any wrong type, alternate root, extra child/node, symlink, special node, file-hash mismatch,
read/hash/status failure, incomplete NUL record, or 0→1 transition fails. Failure is never
reclassified as deletion.

Every erosion observation performs two complete filesystem captures, A then B. Before the first
accepted lifecycle commit it proves `Review22 baseline → A`; every later observation proves
`LATEST → A`; every observation proves `A → B`. Each comparison permits only equality or 1→0.
`FIRST` is the first A and is never overwritten; `LATEST` is each accepted B. CAPTURE and its
node/directory/file counts are diagnostic working registers: A and B each reset and mutate them
during collection, so a failure may leave incomplete, A, or B staging. They are not accepted
lifecycle state and no safety decision may treat their pre-comparison contents as committed.
All comparisons and terminal bookends finish before the process commits FIRST/LATEST and the
accepted mode-B snapshot; the same deferred-signal section finally normalizes CAPTURE/counts to B.

HUP/INT/TERM are defer-only during that short FIRST/LATEST, final CAPTURE/count normalization,
and accepted mode-B assignment group. A signal records its identity, all assignments finish,
ordinary signal handlers are restored immediately, and the deferred signal then rejects the
boundary. No signal is dropped. On a pre-commit capture/comparison failure, FIRST/LATEST and the
accepted mode-B snapshot remain at the pair-entry values while diagnostic CAPTURE/counts honestly
identify the failure-point staging.

R23不提供filesystem transaction、filesystem lock或atomic snapshot，也不证明
inode/hardlink、xattr或resource fork不变，不能消除TOCTOU；完全发生并消失在两个capture
可见窗口之外的短暂节点可能不被观察到。本文的“原子”只指所有比较通过后，当前进程一次性
提交FIRST/LATEST变量。若未来要求原子文件系统保证，必须另开stage并重新Review。

## 5. Complete capture and signed-claim boundary

One App-subtree NUL validator directly emits the 36-bit descendant mask and node/directory/file
counts from its single fully drained stream. There is no second outer filesystem read to rebuild
that mask. The validator accepts only exact frozen paths and exact types; present regular files
must match their frozen SHA-256. After the subtree is fully drained, a terminal parent/App
presence, type, realpath, and exact-child bookend must still agree with the capture.

A current signed-App claim is allowed only for `11` plus 36 ones, exactly 36 nodes, six
directories, 30 regular files, the frozen file-manifest aggregate, and successful
`codesign --verify --deep --strict`. Partial states report only explicitly historical executable,
Info.plist, and signed-bundle hashes; they never claim the current App is signed or launchable.

The final planning-safe observation was:

`capture=11101011100000000000000000000000000010,APP_SUBSET,6,6,0`

The parent and App were exact real non-symlink directories with one exact direct child. The six
descendant nodes were the expected six directories, with no file, link, special, or extra node;
strict codesign returned 1. The observation matched Review22's baseline exactly.

Read-only Bash 3.2 micro-probes passed:

- baseline → current mask: accepted;
- baseline → all-zero mask: accepted;
- all-zero → baseline: rejected with exit 70;
- deferred-signal commit: all state variables committed before the deferred TERM rejection path.

## 6. R23 driver and capture inventory

`r23-begin.sh` SHA-256 is:

`0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c`

Its boundary identity is
`R23_EROSION_SNAPSHOT_AND_RELEASE_CONFIGURATION_REPAIR`. It accepts exactly one lowercase
64-hex argument: the automatically computed current Review23 SHA-256. It independently parses
Review23, verifies the frozen anchors, branch/HEAD, manifest, predecessor preservation, runtime
absence, erosion lifecycle, process absence, RanchArt, and implementation-source baselines before
exclusive BEGIN.

The Bash 3.2 ERR-facing unique outer capture inventory is exactly:

| Class | Unique blocks | Mapping |
|---|---:|---|
| P | 8 | pre/post anchors; historical-root glob; R19 tombstone and artifact checks; R20 top-level; R20 parent-child; RanchArt |
| S | 4 | pre/post manifest statuses; process tri-state; optional strict codesign |
| C | 13 | Review parser; R23 and R22 manifest counts; empty-directory probe; R15 enumeration; fresh-root realpath; R20 parent realpath; two App realpaths; direct-mask App-subset outer capture; complete-set manifest payload and aggregate; post-manifest count |
| **total** | **25** | **8P / 4S / 13C** |

Inline `find | validator` child statuses inside the App-subset C block are enclosed by that outer
capture and are not double-counted. Every P copies full `PIPESTATUS` immediately; expected
nonzero S/C states use Bash 3.2-safe conditional capture.

## 7. Static manifest

`r23-entry.sha256` is a regular non-symlink file with:

- SHA-256: `1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006`;
- record count: `163`;
- path-set SHA-256: `2e1cd3b7e7292510077225db8661140b6ab942e72eb43d5b8bc16deb2a6d9e0f`;
- construction: the complete R22 159-path set plus exactly the R23 driver, immutable R22
  manifest, immutable R22 freeze, and immutable Review22;
- exclusions: itself, this freeze, Review23, all R23 runtime paths, and all temporary roots.

The manifest is bytewise path-sorted and unique, all 163 paths are regular non-symlink files,
and strict current verification passes 163/163. The immutable R22 manifest now yields exactly
153 PASS plus the six current control-surface mismatches. Future implementation must yield
exactly 162 unchanged entries plus `AgentLoopTests.swift` as the sole authorized mismatch; Core
must remain at its R20-final entry hash. Any second mismatch is fatal.

## 8. Standing Goal and Review23 machine authority

The standing Goal removes only the repetitive user hash-echo turn. It does not remove this
freeze, independent Review23, manifest, branch/HEAD, erosion proof, exclusive boundary,
fail-once behavior, implementation scope, completion gates, or red lines. Before any automatic
caller, the root agent must confirm that no newer user turn revoked or narrowed the standing Goal.

Review23 must be written only by a reviewer who did not write or revise the R23 six surfaces,
driver, manifest, or this freeze. Its only repository write may be
`reviews/23-p1-plan-review.md`. It must contain exactly one line:

`Verdict: APPROVED — 0 P0 / 0 P1`

and no other line beginning `Verdict:`. It must also contain one unique
`R23_MACHINE_BLOCK_BEGIN/END` block with exactly these twelve internal fields:

1. `authority_mode=standing_goal_automatic_after_review23`
2. `standing_goal_authority_verified=true`
3. `reviewer_independence_attested=true`
4. `reviewer_write_scope=review23_only`
5. `user_hash_echo_required=false`
6. `review_verdict=APPROVED_0_P0_0_P1`
7. `freeze_sha=<current SHA-256 of this freeze>`
8. `driver_sha=0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c`
9. `manifest_sha=1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006`
10. `branch=codex/personal-ai-ranch-p0`
11. `head=02334ec8d21533be81d93d39191bc7d9b9c24f7f`
12. `manifest_count=163`

This freeze cannot self-embed its own hash without a cycle; the reviewer computes it from these
final bytes. The machine block proves local filesystem/caller-to-driver consistency only. It is
not human anti-rewrite protection, reviewer cryptographic identity, or an external signature.

Only after an approved Review23 and the no-revocation check may the agent compute the current
Review23 SHA and invoke exactly:

```bash
/usr/bin/env -i \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  LC_ALL=C LANG=C TMPDIR=/private/tmp \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  /bin/bash --noprofile --norc \
  /Users/muzi/Agent-loop/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/evidence/r23-begin.sh \
  "<automatically-computed-current-Review23-SHA-256>"
```

No new user hash-confirmation turn is required by this route.

## 9. Boundary consumption and predecessor preservation

Before exclusive creation, the driver proves all R16–R18, R21, R22, and R23 runtime paths that
must remain absent; all R21/R22/R23 fresh-root globs; immutable R19 containment; and the current
R20 erosion pair. R22's twelve paths and R22 root globs are proved again immediately after
activation and after fresh-root creation. R23's fresh twelve paths and roots alone may be used.

Exclusive boundary consumption keeps the inherited fail-once contract:

1. HUP/INT/TERM are masked only for the exclusive-create operation.
2. EEXIST fails pre-BEGIN without appending to the existing path.
3. Successful create immediately marks the boundary active and restores handlers before
   initialization.
4. Partial initialization, command failure, or handled signal after ownership leaves permanent
   `REJECTED_CONTAMINATED` evidence.
5. Immediate post-ownership predecessor and erosion reproofs occur before the hash log; later and
   post-root reproofs continue the same monotonic FIRST/LATEST history.

At freeze time all twelve R22 and all twelve R23 runtime paths, both R22 and both R23 fresh-root
globs, and all R19 roots were absent. R20 state was absent; only the exact 8/38 R20 bundle subset
remained. No R23 boundary has been created and no authorization has been consumed.

## 10. Authorized future implementation and order

The sole future source delta remains six direct directive lines in the R20-final
`AgentLoopTests.swift`: three matching `#if DEBUG` / `#endif` pairs around the exact helper block,
`startControlledLoop`, and exact five-test block frozen in canonical Stage §28.10 and A2 leaf §14.
No logic, order, whitespace, fourth guard, nesting, else/elseif, Core byte, package graph, API,
schema, migration, other product/test file, App script, RunTests runner, or matrix-script expansion
is allowed.

Only after an attested R23 BEGIN may the implementer execute this unchanged fail-once order:

```text
six-line TestSuite guard edit
→ one unfiltered swift run RunTests
→ mechanical same-log 46/46 audit
→ debug App build
→ fresh bundle assembly/sign and POST_BUILD/PRE_SIGN/LAUNCH_READY
→ guard-shape and strip-to-R20 source proof
→ release --target AgentLoopCore
→ release --target AgentLoopTestSuite
→ exact four-object release-zero/debug-positive symbol gates
→ migration matrix and restoration
→ remaining source/privacy/final-hash gates
→ same-bundle bootstrap/cold-start preview
→ END
```

Any failure permanently rejects that invocation and forbids retry, patching, cleanup, root/object
swapping, or overwriting negative evidence.

## 11. Completion and red lines

The R23 implementer may write only fresh twelve `r23-*`/report evidence paths, fresh distinct
`agentloop-r23-state.*` and `agentloop-r23-bundle.*` roots, the frozen six directive lines, and the
already frozen narrow matrix Stage-hash restoration exception. It writes `impl-report-r23.md`;
it does not write Review02 or acceptance.

Only after R23 END and every technical gate may a new independent implementation reviewer write
`reviews/02-p1-a2-review.md`. Only a zero-P0/P1 Review02 opens independent acceptance. Review02
and acceptance must disclose R19 651/652, R20 release failure, historical observations versus
volatile current state with UNKNOWN disappearance cause, the final R20 erosion state, R21
pre-BEGIN zero-write/unconsumed authority, and R22 changes-required/zero-write. They may claim
zero normal-data access only inside the R23 boundary.

Commit, push, merge, release, data reset, payment, public communication, normal-data access,
external action, and real-user action remain unauthorized. A3 and all later slices remain closed.

## 12. Planning-safe verification performed

Before this freeze, only read/static planning checks were performed:

- `/bin/bash -n r23-begin.sh` on system Bash 3.2;
- exact branch/HEAD, immutable R22 anchors, and Core/TestSuite hashes;
- six normalized current-status headers and identical non-atomic-limit paragraphs;
- Stage §30, total Plan §20, and leaf §15 Open Questions;
- R23 manifest shape, regular/non-symlink path types, sorted/unique paths, set equation, exclusions,
  path-set hash, and strict 163/163;
- old R22 manifest result `153 PASS + 6 exact surface mismatches`;
- R22/R23 runtime/root absence and read-only exact R19/R20 observations;
- direct current-mask, one-way monotonic, and defer-only signal micro-probes;
- static review of Review23 parser, fixed-universe capture, terminal bookends, capture inventory,
  boundary, status handling, and fail-once order.

No driver, caller, BEGIN, test, build, matrix, source gate, bundle/sign, preview, product/test/App
script edit, Review02, acceptance, or later-slice action was run.

## 13. Review23 checklist

The independent reviewer must verify at least:

1. reviewer independence and Review23-only write scope;
2. branch/HEAD and exact six-surface, driver, manifest, and current freeze hashes;
3. exact current status, Open Questions, control-index routing, and no conflicting current route;
4. immutable Review22 P1, R22 no-caller/no-BEGIN/zero-write, and unconsumed authority;
5. fixed 38-bit order and baseline, double-complete A/B captures, BASELINE/LATEST→A→B, and
   FIRST=A/LATEST=B commit semantics;
6. direct 36-bit App validator, full drain, exact-path/type/hash rejection, and terminal
   parent/App type/realpath/exact-child bookend;
7. defer-only signal commit and the explicit non-atomic/TOCTOU limitation;
8. complete signed-claim gate versus historical-hash-only partial reporting;
9. `163 = 159 + 4`, strict 163/163, old 153+6, and future 162+1;
10. exact `8P / 4S / 13C = 25` inventory and Bash 3.2-safe status capture;
11. R22/R23 runtime/root absence at all required points and fresh R23-only names;
12. exact verdict/machine block, no-revocation check, single-SHA caller, six-line future delta,
    target-exact/four-object gates, fail-once order, Review02/acceptance, and all red lines.

Any P0/P1, hash drift, conflicting verdict, scope pollution, unknown state, or missing evidence
must produce `CHANGES REQUIRED` and keep execution closed.

## 14. Terminal state

`PLAN_FROZEN — REVIEW23_PENDING — EXECUTION_NOT_AUTHORIZED`
