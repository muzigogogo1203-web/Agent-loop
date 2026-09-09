# P1-A2 R23 Erosion-Snapshot Plan Review

Verdict: APPROVED — 0 P0 / 0 P1

> Date: 2026-08-10
>
> Review object: R23 final six surfaces, BEGIN-only driver, 163-entry static
> manifest, R23 freeze, and immutable R19–R22 containment evidence

## 1. Scope and independence

This reviewer did not write or revise the R23 six surfaces, `r23-begin.sh`,
`r23-entry.sha256`, or `plan-freeze-r23.md`. Review23 was absent when this
review began. The only repository write made by this reviewer is this file.

The review did not run the external caller, `r23-begin.sh`, BEGIN, tests,
builds, migration matrix, source gates, bundle assembly/signing, preview,
Review02, acceptance, or any later slice. It did not modify product, test,
App, RunTests, matrix-script, six-surface, driver, manifest, freeze, or
historical-evidence bytes. Checks were limited to read-only hashing, manifest
reconciliation, Bash syntax/static control-flow review, branch/HEAD and file
type inspection, current volatile-root observation, and isolated planning-safe
mask/signal micro-probes.

## 2. Frozen identities and routing

The reviewed snapshot is branch `codex/personal-ai-ranch-p0`, HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

| Artifact | SHA-256 | Result |
|---|---|---|
| R23 freeze | `9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a` | exact; regular non-symlink |
| R23 driver | `0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c` | exact; regular non-symlink; system Bash 3.2 syntax PASS |
| R23 manifest | `1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006` | exact; regular non-symlink |
| canonical Stage | `b54d8b5fb92108b45a783480706dde434328a1fd7bca88da1f391aed32bd97fb` | exact |
| canonical total Plan | `6ad24bf4c8c836e9ed70831c1206b90d7cdeeea9038d311578b030d839f073a2` | exact |
| A2 leaf Plan | `7d88c0886814c3d03063373fe4ec91463ac107798eaa5a9d06178b4acb5f785e` | exact |
| A2 blocked/control history | `18effbd7a9c6559fa2d1be8e90e42dac17c97070f8d995a0aa63469872200b1f` | exact |
| P1 Stage control index | `4d8295780cd17299650c151c495c46f83d88713c88acdef1868d7913728ac745` | exact |
| P1 Plan control index | `1a4156ab2518fa2bc16b89c926a96fdd8ed6554ca3eb261fa2e7ae1bccd97996` | exact |

All six status headers normalize to the single frozen R23 current-status
string. Canonical Stage section 30, total Plan section 20, and A2 leaf section
15 each contain exactly `无。`. The current indexes route R23 as the only A2
planning gate and preserve R22 solely as the immutable changes-required
predecessor; no conflicting current execution route was found.

## 3. Predecessor and manifest preservation

Review22 remains a unique `CHANGES REQUIRED — 0 P0 / 1 P1` review with no
approval machine block. Its SHA-256 is
`bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5`.
The immutable R22 freeze, driver, and manifest retain their frozen hashes.
R22 was not invoked: its twelve runtime paths and two fresh-root globs are
absent, no boundary or root exists, and its authority remains unconsumed.

The R23 manifest independently reconciles as exact `163 = 159 + 4`: the full
R22 path set plus only the R23 driver, R22 manifest, R22 freeze, and Review22.
It is bytewise path-sorted and unique, has path-set SHA-256
`2e1cd3b7e7292510077225db8661140b6ab942e72eb43d5b8bc16deb2a6d9e0f`,
contains only canonical in-repository regular non-symlink files, excludes its
own file, R23 freeze, Review23, runtime paths, and temporary roots, and passes
strict verification 163/163. The old R22 manifest now yields exactly 153 PASS
plus the six current control-surface mismatches. Core and TestSuite remain at
the R20-final entry hashes
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`
and `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`.
The frozen edit therefore has a mechanically enforceable 162 unchanged plus
one authorized TestSuite mismatch future state.

## 4. Erosion and driver contract

The fixed universe contains 38 bits in the frozen parent, App, and 36-node
order. The Review22 baseline
`11101011100000000000000000000000000010` has exactly 38 bits and set positions
0, 1, 2, 4, 6, 7, 8, and 36. Current read-only observation still matches that
mask: exact parent and App real non-symlink directories, one exact direct
child, six expected directories, zero files, zero links or special nodes, and
strict codesign nonzero. R19 exact roots and R20 state remain absent.

Each observation performs two complete captures. The first pair proves
baseline-to-A and A-to-B; later pairs prove committed LATEST-to-A and A-to-B.
Every comparison rejects 0-to-1 at the exact bit and label. FIRST is committed
only from the first accepted A; LATEST and the accepted phase state commit from
accepted B. CAPTURE and counts are correctly described as diagnostic working
registers that may contain incomplete, A, or B staging before comparison; the
accepted lifecycle never relies on those pre-commit values. The deferred-signal
assignment section covers FIRST/LATEST, accepted phase state, and final
CAPTURE/count normalization, restores ordinary handlers, and then rejects on a
recorded signal. Planning-safe probes confirmed baseline-to-current and
baseline-to-zero acceptance, zero-to-baseline rejection with exit 70, and full
assignment completion before deferred TERM rejection.

The App validator fully drains one NUL stream, rejects definitions, extra or
duplicate paths, wrong types, symlinks, partial EOF, hash failures, and either
pipeline status, and directly emits the 36-bit mask and counts. No second
filesystem pass constructs that mask. Terminal checks repeat parent/App
presence, type, canonical realpath, and exact-child shape. The documents and
driver explicitly avoid claiming a filesystem transaction, lock, atomic
snapshot, inode/hardlink, xattr, resource-fork, or complete TOCTOU guarantee.

A current signed-App claim requires all 38 bits, exact 36/6/30 counts, all
frozen file hashes, the aggregate manifest, strict codesign success, and a
terminal complete capture. Because the frozen baseline already contains file
zeros, that branch is unreachable on the current route. Partial states emit
only explicitly historical executable, Info.plist, and signed-bundle hashes.

The independently enumerated ERR-facing outer status-capture inventory is
exactly `8P / 4S / 13C = 25`. Every pipeline parent copies the full
`PIPESTATUS` immediately; expected nonzero simple-status and command-
substitution states use Bash 3.2-safe conditional capture. The inline App
validator pipeline remains enclosed by its outer command substitution and is
not double-counted.

## 5. Authority, implementation, and red lines

Root-thread evidence confirms the standing Goal remains active and explicitly
removes repetitive hash-echo turns, and the latest user instruction is
`不要哈希了，完整落地`. This removes only the extra user echo; it does not
remove Review23, frozen hashes, branch/HEAD, the single-SHA caller, exclusive
BEGIN, fail-once behavior, implementation scope, completion gates, or red
lines. The caller must still perform the no-revocation check immediately before
automatic invocation. The machine block below proves only local consistency,
not reviewer cryptographic identity, external signature, or human anti-rewrite
protection.

The sole future source delta is three direct matching DEBUG guard pairs, six
directive lines total, around the frozen helper block, `startControlledLoop`,
and five exact tests in `AgentLoopTests.swift`; no logic or other source byte is
authorized. The frozen order remains one unfiltered `swift run RunTests`,
same-log 46/46 audit, debug App and fresh signed bundle, guard-shape and
strip-to-R20 proof, target-exact release Core then TestSuite builds, four exact
release-zero/debug-positive object-symbol gates, migration matrix/restoration,
remaining source/privacy/hash gates, same-bundle preview, and END. Any failure
permanently rejects the invocation. Review02 and acceptance remain closed until
R23 END; A3 and all Git, release, normal-data, external, and real-user actions
remain unauthorized.

## 6. Findings

### P0

None.

### P1

None.

### P2

None.

## 7. Machine authority

R23_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review23
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review23_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a
driver_sha=0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c
manifest_sha=1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=163
R23_MACHINE_BLOCK_END

`APPROVED — 0 P0 / 0 P1`. The next permitted action is the root agent's
current-Goal/no-revocation check followed by the frozen clean-environment
single-SHA caller. This review itself does not execute or complete R23.
