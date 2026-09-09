# P1-A2 R24 Single-Process Clean-Execution Plan Review

Verdict: APPROVED — 0 P0 / 0 P1

> Date: 2026-08-10
>
> Review object: R24 final six control surfaces, single-process Bash driver,
> 178-entry manifest, final freeze, and immutable R15–R23 evidence

## 1. Scope and independence

This reviewer did not write or revise the R24 six control surfaces,
`r24-begin.sh`, `r24-entry.sha256`, or `plan-freeze-r24.md`. Review24 was
absent when review began. The only repository write made by this reviewer is
this file.

The review did not invoke the caller or driver and did not run BEGIN, tests,
builds, the migration matrix, source gates, bundle assembly/signing, UI
preview, Review02, acceptance, or any later slice. It did not modify product,
test, App, package, schema/migration, permanent-script, control-surface,
driver, manifest, freeze, or predecessor-evidence bytes. Checks were limited
to read-only hashes, manifest reconciliation, Bash syntax and static
control-flow review, branch/HEAD and file-type inspection, and current
read-only process/root observations.

An earlier candidate freeze displayed the PIPESTATUS copy with an erroneous
double dollar sign. This reviewer withheld approval. The planner applied the
bounded freeze-only correction before this review was finalized; the current
freeze now reproduces the driver's exact valid two-element copy in both
branches. No approval is granted to the superseded candidate bytes.

## 2. Frozen identities and routing

The reviewed snapshot is branch `codex/personal-ai-ranch-p0`, HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

| Artifact | SHA-256 | Result |
|---|---|---|
| R24 freeze | `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746` | exact; regular non-symlink |
| R24 driver | `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f` | exact; regular non-symlink; 4,273 lines; system Bash 3.2 syntax PASS |
| R24 manifest | `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c` | exact; regular non-symlink; strict 178/178 PASS |
| canonical Stage | `a7dbf5196004a3cdb225b772309c4de00a98061211b5dc8e9c321ce9541c33b7` | exact |
| canonical total Plan | `c8955ab2643e5a380d7bf89736bc44f60a15a4723f157c58225720a7a4424071` | exact |
| A2 leaf Plan | `685de99eb63002768115c43bc1dead33e75311a653a7b257827706bd0ae8e2da` | exact |
| A2 blocked/control history | `b8c35cb4c301c329bb75c334309120295da40d6a66328201819d996ebeb7a008` | exact |
| P1 Stage control index | `53ca22cd0a6aef06e696a1b07b6479ba14d171c27edc033e09b234f685be4c3d` | exact |
| P1 Plan control index | `d826e915268d9a74eb594277d0193f03d4a8ed2f5ee0b31dde1106f8a5b31d47` | exact |

All six current override bodies normalize to SHA-256
`e6600ce6901506e34c02db43a2c84aaeb69cab33dda7e04f1da56e747a0b286c`.
They route R24 as the only current A2 planning gate, preserve R15–R23 as
immutable history, and explicitly supersede earlier R24 handoff, ordinary
`mv`, `kill -0` ownership, and ignored-signal wording. No conflicting current
route was found.

## 3. Manifest and predecessor preservation

The R24 manifest independently reconciles as exact `178 = 163 + 15`: every
R23 manifest path remains present, and the only additions are the frozen R24
driver plus the fourteen specified immutable R23 plan/review/runtime/report
artifacts. The manifest is bytewise path-sorted and unique, has path-set
SHA-256
`6729bc1c34b9664ccdc78397a83e0946b45918adcc8826d56da293f809588b18`,
contains regular non-symlink files, excludes itself, the R24 freeze, this
review, all twelve R24 runtime paths, fresh roots, and hidden publish stages,
and passes strict current verification 178/178.

The immutable R23 manifest currently partitions as exactly 156 unchanged plus
seven expected mismatches: `AgentLoopTests.swift` and the six R24 control
surfaces. R23 freeze, Review23, driver, manifest, report, boundary, hash log,
and verify log retain their frozen hashes. Its boundary remains uniquely
`REJECTED_CONTAMINATED` at caller-side status capture, while its verify log
retains the terminal 652/652 line; that historical output is not reused as an
R24 result.

Core, current TestSuite, and the permanent matrix script remain at the frozen
hashes. The R23 state and bundle roots remain exact real non-symlink empty
directories; the R15 exact tombstones remain absent; the current R20 partial
bundle shape remains compatible with its frozen 38-bit baseline; R24 runtime
paths and roots remain absent; and no `AgentLoop` or `AgentLoopApp` process was
observed during the read-only review.

## 4. Driver and failure-boundary review

The driver keeps BEGIN, the unique unfiltered `swift run RunTests | tee`, both
immediate two-element `PIPESTATUS` copies, same-log 46/46 audit, every build,
release, matrix, source/privacy, bundle and preview gate, report publication,
and END in one reviewed Bash process. Both pipeline branches copy
`${PIPESTATUS[@]}` as their first command. The three status fields are then
committed under defer-only signal handlers, and only exact 0/0 plus the
required unique log structure can advance.

BEGIN uses O_EXCL under a defer-only HUP/INT/TERM window. Successful creation
commits active ownership before normal traps are restored and deferred signals
are consumed; EEXIST remains pre-BEGIN and append-free. After activation,
ordinary failures and signals permanently reject the invocation.

The matrix backup, mutated stage, and restore stage have independent ownership
flags set only after their own O_EXCL success. Cleanup never pre-deletes an
unowned path; EEXIST preserves it and rejects. Publish/cleanup clears the exact
flag, restoration is mandatory, and two containment attempts cannot convert a
failed restoration into success.

Both previews directly launch the same exact signed executable with explicit
isolated state and preview environment. `$!`, Bash job membership, direct
PPID, and committed `lstart` form the ownership chain. Fork-to-identity signals
are deferred; normal Quit and containment require stable running/stopped job
snapshots; TERM/KILL authorization re-proves the direct child and birth token;
cached `wait` is consumed only after the active job disappears. `kill -0` is
not used as kill authorization.

The B01–B06 and C01–C09 contracts match the current SwiftUI accessibility
surface and synthetic isolated fixture. C06 exports only the C05 screenshot
already captured by the controller. Screenshot and implementation-report
publication each use an invocation-owned O_EXCL same-directory stage,
immediate final-absence proof, `mv -n`, and stage/final/SHA postconditions.
Pre-END signals reject and remove only exact uncommitted owned report bytes.
The only commit-wins exception is the fresh END append window; successful END
sets `END_COMMITTED=true` and `BOUNDARY_ACTIVE=false` together before traps are
cleared, and no rejected record can follow a committed END.

## 5. Authority and red lines

The standing Goal remains active, and the latest user instruction removes the
repetitive hash-echo turn while requesting complete continued landing. It does
not remove the freeze, independent review, manifest, branch/HEAD, exclusive
BEGIN, fail-once behavior, technical gates, scope, or red lines. The root agent
must still perform the no-revocation check immediately before automatic
invocation and pass only the freshly computed Review24 SHA through the frozen
clean-environment caller.

This approval authorizes only that frozen R24 execution path. It does not
authorize commits, pushes, merges, releases, destructive or normal-data
operations, payments, public communication, external action, or real-user
action. Review02 and acceptance remain closed until a valid R24 END; A3 and all
later slices remain closed.

## 6. Findings

### P0

None.

### P1

None.

### P2

None.

## 7. Machine authority

R24_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review24
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review24_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746
driver_sha=1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f
manifest_sha=55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=178
R24_MACHINE_BLOCK_END

The next permitted action is the root agent's current-Goal/no-revocation check
followed by the frozen clean-environment single-SHA caller. This review does
not execute or complete R24.
