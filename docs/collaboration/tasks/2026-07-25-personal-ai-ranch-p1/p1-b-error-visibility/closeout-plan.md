# P1-B Acceptance23 Fact-Synchronization Closeout Plan

> **For the active Codex Goal:** REQUIRED SUB-SKILL: use
> `superpowers:executing-plans` after a responsibility-isolated read-only Codex
> follow-up plan review records `APPROVED — 0 P0 / 0 P1` against the exact
> reviewed plan SHA. No commit is permitted.

**Goal:** Close the documentation gap after P1-B Acceptance23 without changing
any frozen P1-B plan, blocker, review, acceptance, verification, product, test,
schema, package, or script bytes, and open only P1-C planning.

**Architecture:** Treat the accepted P1-B evidence chain as immutable input.
Add a newer current-route override to the mutable P1 control indexes, append a
superseding evidence note to the implementation report, update only current
route facts in the living master spec, and create a durable append-oriented
progress ledger. Preserve every older control paragraph as historical evidence.

**Tech Stack:** Markdown, SHA-256, Git read-only inspection, `rg`, `shasum`.

**Spec:**
`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
§0.3, §25 P1, §26, and §27; canonical P1 plan §1/§5.9/§14; canonical P1 stage
spec §20 P1-B/P1-C and §22.

## Global Constraints

- Authority is Acceptance23 plus Review21 and Review22; this closeout does not
  create a new product acceptance.
- P1-C product/test/schema implementation remains closed until its own
  decision-complete plan and responsibility-isolated plan review are approved.
- Existing dirty worktree changes are user/accepted input and must be preserved.
- Frozen historical labels and evidence are never rewritten, deleted, renamed,
  normalized, or described as current success when they were historical failure.
- No product, test, Package, migration, script, normal data, preview data, app,
  external operation, commit, push, merge, release, or real-user action.

---

## 1. Frozen Authority and Entry Evidence

The following seven files must remain byte-identical throughout this closeout:

| Immutable file | Required SHA-256 |
|---|---|
| `p1-b-error-visibility/plan.md` | `a30f65157d15b3c011b6922126279be74eddcbbb2cc868c16715aebd39336866` |
| `p1-b-error-visibility/try-question-mark-inventory.md` | `262085f38c3098a2154b32ee9bb7557185ae3609dbab179eb667b731a31e82c6` |
| `p1-b-error-visibility/blocked.md` | `9695ca794de2cba6db26037cea3cc9233a5b2ef6344c12af31120e1d4bc9dac7` |
| `p1-b-error-visibility/reviews/21-p1-b-plan-review.md` | `eea92e9752a5e4f8b3350673964084c78bc0b4376f6d1c34d60a22b9334d9e15` |
| `p1-b-error-visibility/reviews/22-p1-b-implementation-review.md` | `c5788dcbdd17eb3af4b117e8363751aff9260c6a705cd860fe05548f2a839b94` |
| `p1-b-error-visibility/acceptance.md` | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| `p1-b-error-visibility/verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |

The accepted terminal facts are exactly:

- Review21: `APPROVED — 0 P0 / 0 P1 / 0 P2`;
- Review22: `APPROVED — 0 P0 / 0 P1 / 0 P2`;
- Acceptance23: `ACCEPTED — 0 P0 / 0 P1 / 0 P2`;
- authoritative evidence: `714 tests in 7 suites passed after 43.614 seconds`,
  `EXIT: 0`, `RESULT: PASSED`.

The pre-closeout v2 manifest of every modified/untracked worktree file outside
the full phase allowlist in §2 contains `447` paths and is:

```text
bb48a8a46a2dbed02a1ef68b6df89ea732f92ac2649c4416bbb692c7f33830db
```

This value uses the exact NUL-safe, mode/type-aware algorithm in §5. The older
`9e5c7922...` value recorded by the first Review23 is retained as that review's
historical reproduction of the original content-only entry pipeline; it is not
the revised execution gate.

## 2. Exact Documentation Allowlist

The full phase allowlist is exactly:

1. This `closeout-plan.md` — planner-writable only before the approving review.
2. `reviews/23-p1-b-closeout-plan-review.md` — immutable first-review history.
3. `reviews/23a-p1-b-closeout-plan-review.md` — follow-up plan reviewer only.
4. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md`.
5. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md`.
6. `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`.
7. `impl-report.md` in this P1-B leaf.
8. `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/progress-ledger.md`.
9. `closeout.md` in this P1-B leaf.
10. `reviews/24-p1-b-closeout-review.md` — independent closeout reviewer only.

After Review23A approves, the executor-writable set is exactly items 4–9.
Items 1–3 become immutable; item 10 remains absent and reviewer-only until Gate
B. The approving Review23A must record the exact SHA-256 of item 1 and all later
gates must require that SHA unchanged. Any subsequent plan-byte change voids
Review23A and requires a new responsibility-isolated plan review.

No directory or wildcard is allowlisted. Review artifacts may be materialized
mechanically from a fresh read-only Codex review session, but their verdict and
finding content must be the isolated reviewer's output.

## 3. Exact Fact-Synchronization Edits

### 3.1 P1 execution control indexes

In both P1 root control indexes:

- change only the top current-status line to state that P1-B Revision17 is
  accepted and P1-C decision-complete planning is open while P1-C
  implementation remains closed;
- update only the adjacent current-header date line from `2026-08-11` to
  `2026-08-25` so the new status and date agree;
- add a dated `2026-08-25` current P1-C route override before the older
  `2026-08-11` P1-B override/current-slice text;
- bind the new override to Acceptance23, Review21, Review22, and the final
  `verify.log` SHA from §1;
- explicitly say all lower R12–R28 and 2026-08-11 route paragraphs remain
  immutable historical evidence and do not represent the current gate;
- do not delete or rewrite any older paragraph, table row, failure label, hash,
  count, or historical gate.

The new route opens only creation and independent review of
`p1-c-control-contracts/plan.md`; it does not open P1-C product code.

### 3.2 Living master spec

The master spec §0.3 requires completed-stage facts and route status to be
written back without re-confirming normative product decisions. Therefore:

- update the current document-status line from the obsolete P1-A1a entry to
  `P1-B Accepted; P1-C Planning Entry Open`;
- add a short dated route-fact note near the current implementation baseline,
  citing Acceptance23 and the final verification SHA;
- add the same current status under §25 `P1 — 可靠性与新契约地基`;
- state that P1 as a whole is not completed and P1-C implementation is still
  behind its own reviewed plan;
- leave all Round 5–8, P0, A2 R12–R28, decision-ledger, and historical hash
  blocks byte-for-byte except for the exact current-status insertions above.

No north-star, target-user, domain, permission, architecture-invariant, route
scope, completion gate, or accepted decision changes.

### 3.3 P1-B implementation report

Append, without rewriting the existing report, a section titled
`Post-Acceptance23 evidence synchronization` that says:

- the preceding Revision17 paragraph's `b31d...`/`44.899 seconds` reference was
  a stale pre-Acceptance23 evidence pointer;
- the final accepted authority is Review22/Acceptance23 and `verify.log`
  `6eb521...`, 714/714 in seven suites after 43.614 seconds, exit zero;
- this appended correction supersedes only the current evidence pointer, not
  any immutable historical result;
- the closeout changes no product/test/schema behavior.

### 3.4 Durable progress ledger

Create
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/progress-ledger.md`.
It must:

- identify `/Users/muzi/Agent-loop`, branch `codex/personal-ai-ranch-p0`, and
  baseline HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`;
- list P1-A1a, A1b, A2, A3, A4, and B as accepted with their acceptance paths
  and current acceptance SHA values;
- list P1-C as `planning`, with implementation closed pending its plan review;
- list P1-D, P1-E, P1-F1, P1-F2, and P2–P6 as pending;
- use dated append-oriented entries for future transitions and never replace
  frozen Review/Acceptance artifacts;
- record prohibited external actions: commit, push, merge, release, data reset,
  payment, public communication, and real-user operations.

### 3.5 Closeout record

Create `closeout.md` after the edits. Record:

- all seven immutable before/after hashes from §1;
- the approving Review23A-bound `closeout-plan.md` SHA before/after;
- pre/post hashes of exactly the P1 root `plan.md`, P1 root `stage-spec.md`,
  master spec, and P1-B `impl-report.md`;
- `ABSENT`/post hashes for newly created `progress-ledger.md`;
- the outside-allowlist manifest hash before and after;
- Review23 and Review23A identities, hashes, and verdicts;
- exact current route: P1-B accepted, P1-C planning open, P1-C implementation
  closed;
- no tests rerun for this docs-only closeout; the cited 714/7 run remains the
  immutable accepted P1-B evidence rather than a claim of a fresh test run.

`closeout.md` must not attempt to contain its own final hash or the future
Review24 hash. Review24 must independently hash and bind the final
`closeout.md`; after Review24 is materialized, the owner rechecks Review24,
Review23A-bound plan, all seven immutable inputs, and the outside manifest. No
self-referential file hash is required.

## 4. Responsibility-Isolated Review Gates

### Gate A — follow-up plan review before fact edits

A fresh ephemeral Codex session runs read-only and may inspect the dirty
checkout. It must review this plan against AGENTS, protocol, master spec,
Acceptance23, Review21/22, verify.log, and the P1 control indexes. Its only
repository artifact is
`reviews/23a-p1-b-closeout-plan-review.md`, with explicit P0/P1/P2 findings,
the exact reviewed `closeout-plan.md` SHA, and verdict. It must verify closure
of Review23 P1-01/P1-02/P1-03 and disposition of both P2 findings. Fact edits
remain closed until the verdict is `APPROVED — 0 P0 / 0 P1` and the recorded
plan SHA still matches.

### Gate B — independent closeout review

After all fact edits and deterministic gates pass, a different fresh ephemeral
read-only Codex session reviews only the allowed delta plus frozen evidence. Its
artifact is `reviews/24-p1-b-closeout-review.md`. P1-C planning cannot start
until that review is `APPROVED — 0 P0 / 0 P1`.

## 5. Deterministic Verification

Run all commands from `/Users/muzi/Agent-loop` with complete output captured in
`closeout.md` or quoted as exact compact results.

1. Recompute the seven immutable SHA-256 values and require exact §1 matches;
   recompute `closeout-plan.md` and require the exact SHA bound by Review23A.
2. Recompute the outside-allowlist manifest with this exact command and require
   `outside_count=447` plus
   `outside_manifest_v2=bb48a8a46a2dbed02a1ef68b6df89ea732f92ac2649c4416bbb692c7f33830db`:

```bash
ruby -rdigest -ropen3 -rset -e '
allow = Set.new(%w[
docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/progress-ledger.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/impl-report.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/closeout-plan.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/closeout.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/reviews/23-p1-b-closeout-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/reviews/23a-p1-b-closeout-plan-review.md
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-b-error-visibility/reviews/24-p1-b-closeout-review.md
])
raw, err, status = Open3.capture3("git", "ls-files", "--modified", "--others", "--exclude-standard", "-z")
abort("git ls-files failed: #{err}") unless status.success?
abort("git ls-files stderr: #{err}") unless err.empty?
parts = raw.b.split("\0", -1)
abort("missing terminal NUL") unless parts.last == ""
parts.pop
paths = parts.reject { |path| allow.include?(path) }.sort
digest = Digest::SHA256.new
paths.each do |path|
  stat = File.lstat(path)
  digest << [path.bytesize].pack("Q>") << path
  digest << [stat.mode].pack("L>")
  if stat.file?
    bytes = File.binread(path)
    digest << "F" << [bytes.bytesize].pack("Q>") << Digest::SHA256.digest(bytes)
  elsif stat.symlink?
    target = File.readlink(path).b
    digest << "L" << [target.bytesize].pack("Q>") << target
  else
    abort("unsupported outside-allowlist node: #{path}")
  end
end
puts "outside_count=#{paths.length}"
puts "outside_manifest_v2=#{digest.hexdigest}"
'
```

   Serialization is therefore: binary-path-length (`Q>`), raw path bytes,
   `lstat.mode` (`L>`), node tag, and either regular-file byte length plus raw
   SHA-256 digest or symlink-target byte length plus raw target bytes. Git or
   read errors, stderr, a missing terminal NUL, or any other node type fail the
   gate instead of being omitted.
3. Use `rg` to prove the newest top status and `2026-08-25` override exist in
   both P1 control indexes and that P1-C implementation remains closed.
4. Use `rg` to prove the master spec current status is synchronized while its
   P1 total completion gate remains unchanged.
5. Use `rg` to prove the implementation report's appended final pointer contains
   `6eb521...`, `714`, `7 suites`, `43.614`, and identifies the older pointer as
   stale rather than deleting it.
6. Run `git diff --check` on every changed tracked allowlist path.
7. Inspect `git diff --name-only` and untracked allowlist names; any new path
   outside §2 is a P0 scope failure.

No Swift test, build, migration, package, preview, or normal-data command is
authorized by this docs-only plan.

## 6. Completion Gate

This closeout is complete only when:

- Review23 remains immutable historical `CHANGES REQUIRED`, and Review23A
  approves the revised exact plan SHA with zero P0/P1;
- every §3 edit is present and no historical block was rewritten;
- all §5 deterministic gates pass;
- all seven immutable evidence hashes, the Review23A-bound plan SHA, and the
  outside-allowlist manifest match;
- Review24 approves the final documentation delta with zero P0/P1;
- `progress-ledger.md` names P1-C planning as the only current next leaf;
- P1-C implementation is still explicitly closed.

## 7. Red Lines

1. Never edit the seven immutable files in §1 or the Review23A-bound plan after
   approval.
2. Never convert an old `CHANGES REQUIRED`, `REJECTED_CONTAMINATED`, pending, or
   blocked statement into historical success.
3. Never delete stale control paragraphs; supersede them with a newer dated
   current-route override.
4. Never present the accepted 714/7 log as freshly rerun by this closeout.
5. Never open P1-C implementation, v14 migration, active Goal, OutcomeContract,
   P1-D, or any product/test change from this plan.
6. Never touch normal/preview data or launch/package the App.
7. Never commit, push, merge, release, pay, publish, message externally, or act
   on real users.
8. Any immutable hash drift, outside-allowlist drift, unknown evidence mismatch,
   or reviewer P0/P1 stops the closeout and is recorded honestly.

## 8. Open Questions

None.
