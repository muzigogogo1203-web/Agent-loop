# P1-A2 R22 Volatile-Containment Plan Review

Verdict: CHANGES REQUIRED — 0 P0 / 1 P1

> Date: 2026-08-10
>
> Review object: R22 final six surfaces, BEGIN-only driver, 159-entry static
> manifest, R22 freeze, and immutable R19–R21 containment evidence

## 1. Scope and independence

This reviewer did not write or revise the R22 six surfaces, `r22-begin.sh`,
`r22-entry.sha256`, or `plan-freeze-r22.md`, and did not participate in the R22
planning/root-state observation. The target Review22 path was absent before this
review. The only repository write made by this reviewer is this Review22 file.

This review did not run the external caller, `r22-begin.sh`, BEGIN, any test,
build, migration matrix, source gate, bundle assembly/signing, or preview. It
did not create any R22 runtime artifact or fresh root and did not modify product,
test, App, RunTests, matrix-script, six-surface, driver, manifest, freeze,
historical evidence, Review02, acceptance, or A3 bytes. Static checks were
limited to reading current files and filesystem state, hashing, manifest
reconciliation, `/bin/bash -n`, branch/HEAD inspection, and read-only pathname,
file-type, file-hash, and codesign observations.

The review snapshot is branch `codex/personal-ai-ranch-p0`, HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`. The existing dirty/untracked tree
was treated as user work and left untouched.

## 2. Frozen identities and six-surface routing

### 2.1 Current identities

| Artifact | Current SHA-256 | Result |
|---|---|---|
| canonical Stage | `752c4658d5b2b27ae8237e92dd81cc7e1945862c24988d4236ec946a05eb1139` | exact; regular non-symlink |
| canonical total Plan | `eae8099921fd1a904973f620d0a5a57848ff1fc7cfff283f139f0386e7d5b1f9` | exact; regular non-symlink |
| A2 leaf Plan | `22d673c1fd207b36e7a2293f4bc74cd841d503c31ff9e12079df49e2244c1ed1` | exact; regular non-symlink |
| A2 blocked/control history | `5f801bd139a0518a1895f9691431a8d6a6888d7f86e48e4763f32d5e83d9e1d3` | exact; regular non-symlink |
| P1 Stage control | `7d366d021173ca6d6774da3220fead8e45d2e58780fa24bebad76ba950661d55` | exact; regular non-symlink |
| P1 Plan control | `7c3aa79bde47c1b13abf19a197ebd98ab3cf1411fbdd2f01770564181b1ed011` | exact; regular non-symlink |
| R22 BEGIN-only driver | `55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713` | exact; regular non-symlink; Bash 3.2 syntax PASS |
| R22 static manifest | `57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8` | exact; regular non-symlink |
| R22 freeze | `839a46ad50d8bb943240267679e5878613d7ee42b5664106b4dc5b0a3dc1a8bf` | exact; regular non-symlink |

All six headers normalize to the exact frozen R22 current-status string. The
canonical Stage §30, total Plan §20, and A2 leaf §14 Open Questions each contain
exactly `无。`. Stage §28.9, total Plan R22, leaf §13, blocked §30, and control
entries #34/#35 explicitly supersede the earlier R21 current route; R21 is
routed only as an immutable predecessor.

### 2.2 Standing Goal and local-consistency boundary

The reviewer-side subagent `get_goal` view is isolated and returned no local
Goal. In response to the reviewer's explicit evidence request, the root agent
immediately re-ran live `get_goal` twice and transmitted the same active Goal
whose objective includes: `不需要哈希值每步确认，除非明确需要我介入，其他的你都可以自主执行`.
The current user instruction was also reported verbatim as `不要哈希了，完整落地`,
with no later revocation or narrowing. On that current root-thread evidence,
the standing authority itself is verified; it removes only the repetitive hash
echo and does not widen any implementation, Git, normal-data, external, or
real-user permission.

The six surfaces, freeze, and driver all correctly limit the Review22
machine block to local filesystem/caller-to-driver consistency. They do not
claim human anti-rewrite protection, reviewer cryptographic identity, or an
external signature. Because this review is not approved, it intentionally does
not contain an approval machine block, and no automatic caller may run.

## 3. Manifest and immutable R21 result

The R22 manifest independently reconciles as follows:

- exact record count: `159`;
- path-set SHA-256:
  `9f05ff05ab0201995cea6f903fd466f0b1fc3fd32cdf424f086da1cf47252803`;
- path format and bytewise sorted/unique set: PASS;
- path type: 159 regular non-symlink files;
- strict current content check: 159/159 PASS;
- set equation: complete R21 155-path set plus exactly `r22-begin.sh`, immutable
  R21 manifest, immutable R21 freeze, and immutable Review21, with zero removed
  R21 paths;
- exclusions: R22 manifest itself, R22 freeze, Review22, R22 runtime artifacts,
  and temporary roots are absent from the manifest;
- current immutable R21 manifest result: exactly 149 PASS plus the six final
  control-surface mismatches, with no missing/type error.

The R21 anchors independently remain freeze
`82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4`,
Review21 `13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b`,
driver `c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`,
and manifest `d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`.
All twelve R21 runtime paths, both R21 fresh-root globs, and all R19 alternate
state/bundle identities are currently absent. Core and TestSuite remain at the
R20-final entry hashes
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`
and `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`.
These facts agree with the recorded R21 four-anchor/155 pass followed by
pre-BEGIN exit 70, zero runtime write, and unconsumed authority; they do not
turn the rejected/stopped predecessor into R22 completion evidence.

## 4. Static driver contract audit

The driver statically implements the intended fail-closed mechanisms:

1. R19 exact roots and every alternate `agentloop-r19-{state,bundle}.*` identity
   are checked by a full `/private/tmp` `find -P -print0` stream drained by Bash
   3.2 `read -r -d ''`, with `-e || -L` before/after bookends. Current exact and
   alternate R19 observations are zero.
2. R20 state-root reappearance and alternate R20 identities fail. Bundle
   classification stores a separate first-observed state, advances repeated
   pre-BEGIN and multiple post-activation observations through the one-way
   retained/absent table, performs exact-child, 36-node/30-file hashes,
   aggregate, and strict codesign verification for a retained candidate, and
   uses a later full-parent bookend that rejects an in-classification
   retained-to-absent transition.
3. The boundary path is created with noclobber exclusive-create while
   HUP/INT/TERM are masked only around that operation. EEXIST remains
   pre-BEGIN and does not append. Ownership immediately sets the in-process
   boundary active and restores handlers; partial initialization, command
   failure, or handled signal routes to permanent `REJECTED_CONTAMINATED`
   recovery facts. Immediate post-ownership R21/R19/R20 reproof occurs before
   hash-log creation.
4. Static outer capture inventory is exactly `9P / 4S / 8C = 21`: nine unique
   pipeline parents, four simple-status parents, and eight command-substitution
   parents. Every pipeline parent immediately copies full `PIPESTATUS`; expected
   nonzero simple/command states are captured in conditional contexts. System
   Bash 3.2.57 parses the driver successfully, and no later-Bash-only construct
   was found.
5. The future source exception remains exactly three direct matching
   `#if DEBUG`/`#endif` pairs, hence six directive lines, around the frozen five
   helpers, `startControlledLoop`, and five contiguous tests. Current TestSuite
   has no conditional directive and exactly matches its R20-final hash; Core has
   only its existing direct DEBUG region and also matches R20-final bytes. The
   target-exact Core/TestSuite release commands, four exact-object bidirectional
   symbol gates, strip-to-R20 proof, single unfiltered full run, same-log 46/46,
   and remaining fail-once order are unchanged.

The static implementation is fail closed. That does not make the current entry
state satisfiable; §5 records the blocking live state found by this review.

## 5. Current historical-root observations

Independent read-only observations were repeated and were stable during this
review:

| Historical path | Current observation |
|---|---|
| R19 state `/private/tmp/agentloop-r19-state.dNgUXh` | ABSENT |
| R19 bundle `/private/tmp/agentloop-r19-bundle.49xVDm` | ABSENT |
| R20 state `/private/tmp/agentloop-r20-state.3QwlQa` | ABSENT |
| R20 bundle `/private/tmp/agentloop-r20-bundle.30V5RH` | PRESENT, real non-symlink directory |

The R20 bundle parent has exactly one direct child, the expected real
non-symlink `AgentLoop.app`. That App is no longer the frozen retained bundle:

- recursive contents: 6 directories, 0 regular files, 0 symlinks, 0 other
  nodes (the parent-level App makes seven nodes when included);
- `Contents/Info.plist`: ABSENT;
- `Contents/MacOS/AgentLoop`: ABSENT;
- current file-manifest aggregate: the empty-input SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`,
  not the frozen signed aggregate
  `06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`;
- `codesign --verify --deep --strict`: nonzero.

The root agent independently repeated the same read-only observation after it
was reported and confirmed directory count 6, file/link/other counts 0,
missing executable/Info.plist, and codesign rc 1.

## 6. Findings

### P0

None.

### P1

#### P1-01 — The current R20 bundle is a present partial skeleton that the frozen state machine cannot classify, so R22 deterministically stops before BEGIN

Freeze §§4/11 and all six surfaces permit the R20 bundle only as a fully
`VERIFIED_RETAINED` bundle or as `ABSENT_TOMBSTONE`. A present parent is first
classified by `r22_classify_r20_volatile_roots` as `RETAINED_CANDIDATE`.
`r22_require_r20_containment` must then prove the exact child, executable,
Info.plist, 36-node set, 30 file hashes, aggregate, and codesign before it may
promote that candidate. Verification failure is deliberately forbidden from
being relabeled disappearance.

The actual current root is neither allowed terminal state: its parent/App
directories are present, so it is not absent, while its frozen files and
signature are gone, so it cannot be verified retained. Consequently, on the
current filesystem the reviewed driver will reach `pre_begin_r20_containment`,
classify `RETAINED_CANDIDATE`, fail the App/executable/Info.plist type gate with
exit 70, and stop before exclusive boundary creation. Authority remains
unconsumed and runtime writes remain zero, but the only current A2 route cannot
reach BEGIN. Approving and automatically invoking this known-unsatisfiable
candidate would merely create another deterministic pre-BEGIN stop.

This finding does not authorize reconstruction, deletion, cleanup, movement,
resigning, or reuse of the R20 root. Those actions remain forbidden and would
rewrite historical evidence. A bounded planner revision must first model and
honestly attest the observed partial historical bundle (and its permitted
one-way future transitions) or choose another safe non-destructive disposition,
while preserving the UNKNOWN disappearance cause, all immutable R20 repository
evidence, R21 zero-write facts, the six-line source exception, and every
execution/completion red line. The affected six surfaces, driver, manifest,
freeze, and independent review boundary must then be regenerated with fresh
next-revision identities; this Review does not choose or implement that planner
design.

### P2

None.

## 7. Final authorization boundary

**CHANGES REQUIRED — 0 P0 / 1 P1**

R22 has not received plan approval. This Review contains no approval machine
block and must not be supplied to the automatic caller. The caller,
`r22-begin.sh`/BEGIN, tests, builds, matrix, source gates, bundle/signing,
preview, six-line TestSuite edit, Review02, acceptance, A3, commit, push, merge,
release, normal-data access, external action, and real-user action all remain
closed. The present R20 partial bundle must not be rebuilt, deleted, cleaned,
completed, launched, moved, renamed, or reused.

## Open Questions

None.
