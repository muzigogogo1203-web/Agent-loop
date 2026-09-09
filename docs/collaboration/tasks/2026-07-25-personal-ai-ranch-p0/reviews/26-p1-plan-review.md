# P1-A2 R26 ERR-Subshell Clean-Execution Plan Review

Verdict: APPROVED — 0 P0 / 0 P1

> Date: 2026-08-10
>
> Review object: R26 final six control surfaces, fresh driver, 206-entry
> manifest, final freeze, and immutable R25 evidence

## 1. Scope and independence

This reviewer did not write or revise the R26 six control surfaces,
`r26-begin.sh`, `r26-entry.sha256`, or `plan-freeze-r26.md`. The Review26 path
was absent when this final review began. The only repository write made by this
reviewer is this file.

The review did not invoke the caller or driver and did not run BEGIN, tests,
builds, the migration matrix, source/privacy gates, bundle assembly/signing, UI
preview, Review02, acceptance, or later-slice work. It did not modify product,
test, App, Package, schema/migration, permanent-script, control-surface, driver,
manifest, freeze, predecessor-evidence, or runtime bytes. It did not enter,
enumerate, hash, open, or clean either R25 root or any descendant.

## 2. Frozen identities and synchronized control surfaces

The reviewed snapshot is branch `codex/personal-ai-ranch-p0`, HEAD
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`.

| Artifact | SHA-256 | Result |
|---|---|---|
| R26 freeze | `0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb` | exact; regular non-symlink |
| R26 driver | `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d` | exact; regular non-symlink; 5,128 lines; 260,840 bytes; Bash syntax PASS |
| R26 manifest | `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d` | exact; regular non-symlink; strict 206/206 PASS |
| canonical Stage | `32831bbdbc11192b76ac8c801631bd2484a3f005aa69376f0818feef0c34f5d9` | exact |
| canonical total Plan | `c23df83d00e78062272bb44440436d0db063be8bfaa1109104a6a60fc152f816` | exact |
| A2 leaf Plan | `c2194d029fde7848b5f901af5e2577ae8049a3ce2d0b7c051a0d6cd62af593f0` | exact |
| A2 blocked/control history | `f94a3d80e359e323dd348aaa1637542b9f2a77b46bb19fd3a7dc1bbb171e6f71` | exact |
| P1 Stage control index | `d6dfd53218efafd595d675ea8a5977b4c304e30f90c2b2915899df8c61044140` | exact |
| P1 Plan control index | `da69563d80be37da5aff7415eeef90863420608c529bcb389ad40c4b0c29dc60` | exact |

All six R26 bodies are byte-identical under the frozen extraction boundary:
112 newline-terminated lines, 9,068 bytes, SHA-256
`18f3fc1244b90c87c12626e19b2f10fe5a57e5381c83f5f9d0ee4badd4757c1e`.
Their headers and current-state statements consistently identify the R26
candidate, driver, 206-entry manifest, and freeze as present and frozen, with
Review26 as the only pending gate and caller/BEGIN closed until approval.

## 3. Manifest and immutable R25 evidence

The manifest has exactly 206 lowercase SHA-256 plus two-space plus absolute-path
records. Paths are sorted and unique, every member is a regular non-symlink,
strict current verification is 206/206, and the path-set SHA-256 is
`a9e143f5090f1e49cebc274fccde81e52571317d59696122d970b3e4dcf98949`.
Its set is exactly the full R25 192-path set plus fourteen non-overlapping
additions: the R26 driver; immutable R25 manifest, freeze, and Review25; and the
ten actual R25 runtime artifacts. The R25 historical partition is exactly 186
unchanged plus six expected control-surface mismatches.

The R25 freeze, Review25, driver, manifest, and all ten actual runtime files
retain their frozen identities and sizes. The evidence still proves the unique
full 652/652 run, same-log 46/46, pre-preview 192/192, and the three exact
preview-bootstrap rejection blocks. Both preview logs remain empty; the R25
report and screenshot remain absent; no END exists. Nothing in R25 substitutes
for the required R26 full rerun, Review02, or acceptance.

The manifest excludes itself, the R26 freeze, this review, all twelve R26
runtime/report paths, both future fresh roots, and invocation-owned hidden
stages. Before this review write, this review and all twelve runtime/report
paths were absent. The only permitted manifest mutation window remains 205
unchanged plus one owned matrix-script mismatch followed by exact restoration.

## 4. Driver and causal-fix review

The R26 driver changes only the demonstrated Bash `set -E` child-inheritance
root cause. `r26_err_trap` captures the original status and command, then exits
any `BASH_SUBSHELL != 0` child with its original status after removing the child
ERR trap. Only the root shell can invoke root-owned fail-fast or containment.
There is no child `EXIT` trap, global ERR disablement, `|| true`, packet bypass,
fallback classification, or swallowed indeterminate status.

The static gate verifies guard order, no `EXIT` trap, exactly fifteen `/bin/ps`,
two `/usr/bin/pgrep`, and three `/usr/sbin/lsof` nested captures, and two
pre-BEGIN microprobe invocations. Independent isolated system-Bash execution of
the frozen probes passed all eight cases, including the cross-subshell fd-3
cleanup sentinel and exactly one root fail-fast for raw uncaught
`x="$(false)"`.

R25 root handling is limited to Python `os.lstat` on the two frozen exact root
path entries. Only `FileNotFoundError` maps to absence; symlink, wrong type,
malformed/partial capture, and every other OS error fail closed. The driver does
not descend into or use R25 root contents. Complete A/B comparisons permit only
equality or 1-to-0 erosion, reject 0-to-1, and commit FIRST/LATEST/accepted-B
only after all comparisons pass.

The remaining execution chain is unchanged: exclusive BEGIN, one unfiltered
`swift run RunTests | tee` with immediate two-element `PIPESTATUS`, same-log
46/46, debug build and fresh signed bundle, guard/strip, target-exact release
builds, four-object gates, mandatory matrix restoration, source/privacy gates,
same-bundle B01–B06/C01–C09 preview, staged screenshot/report, and tiny
commit-wins END in one reviewed Bash process. There is no retry, handoff,
continuation, root/binary substitution, or predecessor-result reuse.

## 5. Gate result

No P0 or P1 finding remains. This approval opens only the exact frozen automatic
caller after the root agent rechecks identities and confirms no newer user turn
revoked the standing Goal. It does not attest an R26 run, END, Review02,
acceptance, A3, commit, push, merge, release, data operation, payment, public
communication, external operation, or real-user action.

R26_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review26
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review26_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb
driver_sha=937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d
manifest_sha=f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=206
R26_MACHINE_BLOCK_END
