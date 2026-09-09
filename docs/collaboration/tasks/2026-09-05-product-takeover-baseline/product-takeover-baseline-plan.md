# Product Takeover Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish an accurate ownership agreement and evidence-linked current desktop baseline without altering product behavior.

**Architecture:** Preserve the existing dirty source tree and existing long-term product contracts. Add one current takeover record, update active documentation entry points, run fresh validation on unchanged source, and distinguish audit completion from product/stage acceptance.

**Tech Stack:** Swift 6, SwiftPM, SwiftUI, GRDB 7, macOS 14+, repository RunTests executable.

**Spec:** `docs/collaboration/tasks/2026-09-05-product-takeover-baseline/spec.md`; long-term invariants remain in `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`.

## Global Constraints

- No Swift, database, test, dependency, or packaging-script changes in this plan.
- Preserve all existing dirty changes; no commit, push, merge, release, public communication, payment, real-user actions, or destructive data operations.
- Work in the existing authoritative checkout on a new `codex/` branch; do not duplicate the huge dirty tree into a worktree based only on the stale HEAD.
- Use `swift run RunTests` as the unfiltered default full-suite gate; retain complete stdout/stderr and actual exit status. Focused reruns never supersede a red full run.
- Use a unique `AGENTLOOP_STATE_DIR` and `AGENTLOOP_UI_PREVIEW=1` for launch validation; no production database or credentials.
- Preserve frozen historical evidence and mark newer corrections explicitly. Do not declare P1-F1/P1/P2 acceptance.
- The default test suite runs local process/socket fixtures and existing local OS integration checks; do not add real cloud/CLI-provider calls to this audit.

## Preflight (before any Task 1 edits)

- [x] Record branch/HEAD/worktrees, full dirty status, disk and process snapshot in `baseline.txt`.
- [x] Save six documentation pre-change copies and `source-before.sha256` (303 current files).
- [x] Switch existing dirty checkout to `codex/product-takeover-baseline-20260905` without discarding changes.
- [x] Independent plan review approved; correct P2 section citation/outcome-type wording and explicitly supersede old master governance. No product-code implementation authorized by this plan.

### Task 1: Correct active ownership and status entry points

**Files:** Modify `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/collaboration/claude-codex-protocol.md`, `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`, and `docs/collaboration/tasks/2026-09-01-active-ingestion-deletion-timestamp-roundtrip/impl-report.md` only.

**Interfaces:** Consumes this spec and the six failure records in the Sept 1 `verify.log`; produces consistent links to this task and explicit current governance. Historical protocols remain readable as historical records.

- [x] Read the listed documents and the Sept 1 `verify.log`/`serial-reruns.log` before editing. Capture pre-change copies for a task-only diff (controller owns this capture).
- [x] Make AGENTS designate Codex product/engineering owner with autonomous ordinary decisions and independent review. Preserve technical facts, error observability, dirty-tree protection, authority boundaries, evidence requirements, and stage gates. Link this takeover spec as the current decision record.
- [x] Make CLAUDE a compatible optional participant guide. Add a dated active override at the top of the historical Claude/Codex protocol; retained historical CLI commands/model choices are not current mandatory instructions.
- [x] Replace README's stale P0/current-main claims with dated current facts: ongoing P1 implementation and desktop closure, historical base HEAD plus dirty workspace, P1-F1 not formally accepted. Label existing feed-led UI as current behavior and the unified coach journey as target. Link the current report without claiming future validation outcomes.
- [x] Add a dated current-state notice at the top of the master spec and explicitly mark old status notes historical; retain requirements and historical hashes/body. Explicitly supersede historical governance in §27.1/§27.2, ordinary-decision escalation in §27.3, and the §31 Agent role row with the Sept 5 ownership confirmation. Preserve independent review and stage/authority gates.
- [x] Append a Sept 5 correction to the Sept 1 report: six failing tests/six issues, only five separately rerun; list missing `p1f1_075CLIHelpCapabilityMismatchIsUnsupported` and `processGroupSurvived`. Do not assert failures are unrelated or solely environmental; preserve original text as historical superseded reporting and original logs unchanged.
- [x] Self-review against the spec, verify changed paths and `git diff --check`, report changed files and unresolved concerns. Controller provides independent task review of the before/after diff. No test-source changes and no fabricated TDD cycle for documentation.

### Task 2: Refresh unchanged-source engineering evidence

**Files:** Create generated evidence under this task directory: `source-before.sha256`, `source-after.sha256`, `baseline.txt`, `verify.log`, optional `focused-reruns.log`, `build.log`, `launch.log`, and an artifact manifest. Do not overwrite historical evidence.

**Interfaces:** Consumes the current dirty source tree; produces test, build and launch results tied to its source manifest, not merely HEAD.

- [x] Record `git rev-parse HEAD`, branch/worktree identity, dirty status, disk availability and existing processes. Hash all current tracked/untracked source, tests, package, scripts and local skills. Snapshot existing documentation paths and branch with `git switch -c codex/product-takeover-baseline-20260905`, retaining all dirty changes.
- [x] Run `swift run RunTests` once, redirecting complete stdout/stderr into a unique temporary log then preserving it as `verify.log`; record command and exit status. No simultaneous Swift build/test runner.
- [x] Read the run summary and every issue. If any failure appears, run the exact affected test filter once with `--no-parallel` in a separate log; investigate call sites/read-only evidence with an independent agent. Record that isolated green is not proof of a fixed race. If the full run is green, run the six historical failure cases together once as a focused regression check; do not infer historical root cause from green alone.
- [x] Run `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors`, saving stdout/stderr and exit status. If build fails, retain evidence and skip launch rather than claim a new app was built.
- [ ] Ensure no user App process is running, create a unique temporary preview-state directory with `mktemp -d`, and run `AGENTLOOP_STATE_DIR=<exact-path> scripts/run-app.sh --preview`. Save complete output. The script's replacement of its generated `.build/AgentLoop.app` is normal local build output, not authorization to alter any installed app.
- [ ] Verify `codesign --verify --deep --strict .build/AgentLoop.app`, read Info.plist, hash the executable and resource bundle contents, record the actual process command and inspect preview-state output after at least 8 seconds. Stop only the exact preview PID after verifying its executable path; leave the isolated state for evidence. Do not perform the skill's broad `pkill`, rename build resources or act on the real database.
- [x] Rehash the same source scope and compare manifests; collect `git diff --check`. Launch survival and packaged resource presence are limited evidence, not a clean-machine resource simulation or a user-flow acceptance.

Task 2 result: audit checks performed; default full suite remains red (6 issues), all six isolated runs green, strict build red. The two unchecked launch steps above are **SKIPPED by the build-failure branch**, not unfinished background work or a claimed success. Evidence: `verify.log`, `focused-reruns.log`, `build.log`, `launch-status.md`, `final-checks.log`.

### Task 3: Evidence-backed handoff and independent final review

**Files:** Create this task's `impl-report.md`, `reviews/01-baseline-review.md`, and update its execution checklist/ledger.

**Interfaces:** Consumes all task evidence and independent findings; produces an accurate baseline conclusion and next bounded product increment.

- [x] Report exact changed paths, source-manifest identity, test counts/exit statuses, build and launch facts, history correction, active branch, and limitations. Separate documentation review, default tests, focused tests, build, preview startup, real-provider validation and user acceptance.
- [x] List any unresolved failure by test name and observed error, with the next smallest diagnostic or repair step. Never extend this plan into speculative production fixes.
- [x] State the next increment: close any reproduced baseline failure first; then plan one default goal-to-contract user journey using existing workflow controllers, before expanding remaining UI. Retain the full historical P1-F1/source/compatibility review gap explicitly.
- [x] Independent final reviewer examines the task-only diff, evidence and scope. Address documentation/report inaccuracies within this plan; do not claim to review all historical dirty implementation. Save reviewer verdict and check no unreviewed material correction remains.
- [x] Deliver a short user-facing account of what was established and what remains. Do not request another general permission to continue the agreed product direction.

Final audit review: `reviews/01-baseline-review.md`, APPROVED — 0 P0 / 0 P1 / 0 P2. Audit complete; runtime/strict-build baseline NOT accepted. No new feature work, commit or stage progression occurred.
