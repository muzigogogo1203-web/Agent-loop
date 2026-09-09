# Cancellation gate boundary observation implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Root alone owns executable checks, compilation, the single focused test and evidence collection. No commits or deletion of evidence.

**Goal:** Distinguish gate actor admission, continuation readiness, state completion and actor/caller readmission within the observed post-open delay, without changing cancellation behavior.

**Architecture:** Attach an optional immutable canonical execution owner only to the cancellation gate created by `installCancellation`. Add synchronous markers outside existing locks through the unchanged default-off logger. Measure brackets, not exact lock acquisition or publication; retain all error, state-precedence and await semantics.

**Tech Stack:** Swift6 strict concurrency, existing NSLock/actor/continuation implementation and OSLog; Ruby2.6 for retained-evidence assertions.

**Spec:** `goal-foundation-runtime-admin-observed2-halt-analysis.md` (SHA `cd95c610c169a674a7ebd0913b6581821ed81cdcc6a15b29ace0923c889ddd90`), its selected next experiment and stop criterion; user's renewed “继续吧”; repository AGENTS.md owner authorization and mandatory review/gates. This is observability, not a claimed runtime repair.

## Global constraints

- Use the authoritative existing dirty checkout `/Users/muzi/Agent-loop`, branch `codex/desktop-coding-closure-20260905`, HEAD `02334ec8d21533be81d93d39191bc7d9b9c24f7f`. Preserve unrelated changes and all historical evidence; no new worktree, commit, push, merge or release.
- Entry305 build-input manifest is `a462d6b57546a019564499a9ce8a485de7053f4ae3a0fd3d54d870678474e97f`. Only `Sources/AgentLoopCore/Kernel/Orchestrator.swift` and `Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift` may change in build inputs. Entry hashes are `950f118f546f54c95bf8d0ca85c6ad478217ac56428850f91bff65c02c029131` and `eb5b586478bcac3a84fde07f400621de14e77a797e4e644f743aaa8d5dc6e4f8` respectively.
- No additional Task, await, lock, retry, timeout, catch, reordered persistence/cancellation, changed branch precedence, test assertion, concurrency rule or business state. No change to logger format/API/default-off flag. Diagnostic-only optional-owner branches and source formatting needed to insert markers are permitted.
- No logger calls inside an NSLock closure. All marks describe entry, operation returned, resume attempt or successful completion. They do not claim exact lock acquisition/publication or nonperturbing observation.
- Only opaque canonical execution UUID, fixed stage, monotonic time and closed integer codes are emitted. No content, paths, environment values, tokens, credentials or arbitrary errors.
- No full test run, administrator action, OS stack sampling, usercamp/Provider/installed-App operation. Previous sampling and deletion permissions are consumed. One ordinary focused `emergencyStopCancelsRunningBeforeWaitingForPlanner` invocation after reviewed code/build, then stop and account for evidence even if it passes or fails to reproduce. A build that fails before producing RunTests does not justify running an older binary.
- Existing one-second observer semantics remain unchanged. Coverage GREEN or a focused test pass is not strict deadline, original-root-cause, full-runtime, A1/A2 or product acceptance.

## Task 1: Test-first gate observability and independent source gate

**Files:** create TD `runtime-halt-gate-evidence-check.rb`; modify only the two allowed Swift sources. TD is this task directory. Root preserves exact source preimages under `runtime-halt-gate-before/` before dispatch. The worker writes its task report, not living product checkpoints.

**Interfaces:** consume the existing `RuntimeLifecycleDiagnostics.event(_:owner:value:)` unchanged. Add optional `diagnosticExecutionId: String? = nil` to `EngineExecutionStartGateV1.init`; default callers remain silent. Only the existing `installCancellation` construction supplies `executionId`. A private optional-UUID helper emits fixed events; there is no test-only production hook.

- [ ] Write the retained-event regression first. It catches the observable defect of missing internal gate milestones and unsafe/ambiguous identity joins, not source-text spelling. It reads real emitted events; no synthetic success or source grep substitutes for a live GREEN. Use this exact Ruby2.6-compatible core, with a shebang and comments as useful:

```ruby
require 'json'
abort 'usage: check TEST_LOG ADMITTED_EVENTS PARENT_PID' unless ARGV.length == 3
test_log, event_log, parent_pid_text = ARGV
abort 'invalid parent PID' unless parent_pid_text.match?(/\A[1-9][0-9]*\z/)
parent_pid = Integer(parent_pid_text, 10)
uuid = '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
identity = /^haltFixtureIdentity test=emergencyStopCancelsRunningBeforeWaitingForPlanner orchestrator=(#{uuid}) execution=(#{uuid}) provider=(#{uuid}) gate=(#{uuid})$/
matches = File.readlines(test_log).map { |line| identity.match(line.chomp) }.compact
abort 'expected exactly one fixture identity' unless matches.length == 1
execution = matches.fetch(0)[2]
events = File.readlines(event_log).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
abort 'wrong parent event scope' unless !events.empty? && events.all? { |e| e.fetch('processID') == parent_pid && e.fetch('subsystem') == 'com.muzi.agentloop' && e.fetch('category') == 'runtime-lifecycle' }
pattern = /\Astage=(\w+) owner=(#{uuid}) mono=([0-9]+) value=(-?[0-9]+)\z/
stages = {}
events.each do |event|
  match = pattern.match(event.fetch('eventMessage'))
  abort 'malformed admitted event' unless match
  next unless match[2] == execution
  next unless match[1].start_with?('haltGate')
  abort "duplicate gate stage #{match[1]}" if stages.key?(match[1])
  stages[match[1]] = { mono: Integer(match[3], 10), value: Integer(match[4], 10) }
end
required = %w[haltGateActorWaitEntered haltGateStateWaitEntered haltGateWaitContinuationEntered haltGateWaitLockReturned haltGateStateWaitSucceeded haltGateActorWaitSucceeded haltGateActorOpenEntered haltGateStateOpenEntered haltGateOpenLockReturned haltGateOpenResumeAttempt haltGateOpenResumeReturned haltGateActorOpenSucceeded]
missing = required.reject { |name| stages.key?(name) }
abort "missing gate observations: #{missing.join(',')}" unless missing.empty?
wait_value = stages.fetch('haltGateWaitLockReturned').fetch(:value)
open_value = stages.fetch('haltGateOpenLockReturned').fetch(:value)
abort 'successful observation requires registered(0) or opened(1)' unless [0, 1].include?(wait_value)
abort 'invalid open waiter presence' unless [0, 1].include?(open_value)
%w[haltGateOpenResumeAttempt haltGateOpenResumeReturned].each do |name|
  abort 'open waiter-presence drift' unless stages.fetch(name).fetch(:value) == open_value
end
immediate = %w[haltGateWaitResumeAttempt haltGateWaitResumeReturned]
if wait_value == 1
  abort 'opened wait must have no detached opener waiter' unless open_value == 0
  immediate.each { |name| abort "missing successful immediate resume #{name}" unless stages.key?(name) && stages.fetch(name).fetch(:value) == 1 }
else
  abort 'registered waiter not detached by opener' unless open_value == 1
  abort 'registered branch emitted immediate resume' if immediate.any? { |name| stages.key?(name) }
end
abort 'canceled gate is not the selected successful observation path' if stages.keys.any? { |name| name.start_with?('haltGateCancel') }
chains = [
  %w[haltGateActorWaitEntered haltGateStateWaitEntered haltGateWaitContinuationEntered haltGateWaitLockReturned],
  %w[haltGateStateWaitSucceeded haltGateActorWaitSucceeded],
  %w[haltGateActorOpenEntered haltGateStateOpenEntered haltGateOpenLockReturned haltGateOpenResumeAttempt haltGateOpenResumeReturned haltGateActorOpenSucceeded]
]
chains << immediate if wait_value == 1
chains.each do |chain|
  chain.each_cons(2) { |left, right| abort "invalid local event order #{left}/#{right}" unless stages.fetch(left).fetch(:mono) <= stages.fetch(right).fetch(:mono) }
end
allowed = required + (wait_value == 1 ? immediate : [])
abort 'unrecognized gate observation' unless (stages.keys - allowed).empty?
puts JSON.pretty_generate({ execution: execution, parent_pid: parent_pid, branch: wait_value == 0 ? 'registered' : 'already_open', stages: stages, coverage: 'PASS', runtime_gate: 'NOT_EVALUATED' })
```

- [ ] Pause after writing the checker, before any Swift edit. Root runs syntax plus this checker on the preserved real observed2 test/admitted-event logs and PID34975. Expect exit1 specifically listing missing gate observations after a valid identity/scope parse. This is the diagnostic-output RED replay, not a new test run and not evidence of a newly reproduced business failure. Freeze checker after this meaningful RED; parser defects may be corrected before the RED is accepted.
- [ ] Add one private shared helper in Orchestrator near `haltExecutionDiagnosticEvent`; actor and state call it with their immutable optional owner:

```swift
private func haltGateDiagnosticEvent(
    _ stage: RuntimeLifecycleStage, owner: UUID?, value: Int = 0
) {
    guard let owner else { return }
    RuntimeLifecycleDiagnostics.event(stage, owner: owner, value: value)
}
```

- [ ] State gains `private let diagnosticOwner: UUID?` and `init(diagnosticOwner: UUID? = nil) { self.diagnosticOwner = diagnosticOwner }`. Actor replaces its inline state initialization with two immutable nonisolated lets, `state` and `diagnosticOwner`; preserve all method isolation:

```swift
package init(diagnosticExecutionId: String? = nil) {
    let owner: UUID?
    if RuntimeLifecycleDiagnostics.isEnabled,
       let executionId = diagnosticExecutionId,
       let candidate = UUID(uuidString: executionId),
       candidate.uuidString == executionId {
        owner = candidate
    } else {
        owner = nil
    }
    diagnosticOwner = owner
    state = EngineExecutionStartGateStateV1(diagnosticOwner: owner)
}
```

- [ ] In `installCancellation` only, replace `let gate = EngineExecutionStartGateV1()` with `let gate = EngineExecutionStartGateV1(diagnosticExecutionId: executionId)`. Leave other construction sites unchanged. Do not generate a new UUID or change execution identity.
- [ ] Add actor wait entry before its existing await and success after it; actor open entry before `try state.open()` and success after. Add state wait entry before `Task.checkCancellation()`, continuation entry before its unchanged `lock.withLock`, and state wait success after the existing cancellation-handler await. Preserve thrown errors; absent success on a throwing path is not lost-log proof.
- [ ] Immediately after the wait lock operation, classify its existing `Result<Void, Error>?` for diagnostics only: nil→0 (waiter registered), `.success`→1 (already opened), `.failure`→2 (canceled/conflict combined). Emit `haltGateWaitLockReturned` with that code. Keep the existing `if let outcome { continuation.resume(with: outcome) }`, adding `haltGateWaitResumeAttempt` and `haltGateWaitResumeReturned` around the resume, carrying the same code. The classification never changes a returned result or error.
- [ ] State open and cancel each get an entry marker before their existing lock; immediately after the unchanged lock operation emit `*LockReturned` with `current == nil ? 0 : 1`; bracket the unchanged optional continuation resume with `*ResumeAttempt` and `*ResumeReturned`, same waiter-presence code. Do not replace optional resume or add guard/return/catch. An absent waiter means no actual resume, and cannot distinguish canceled no-op from the normal no-waiter case. On duplicate-open throw, post-lock/success markers legitimately do not execute.
- [ ] Add only these18 enum cases to the existing logger stage enum; no logger implementation/API changes:

```swift
case haltGateActorWaitEntered, haltGateActorWaitSucceeded
case haltGateActorOpenEntered, haltGateActorOpenSucceeded
case haltGateStateWaitEntered, haltGateWaitContinuationEntered
case haltGateWaitLockReturned, haltGateWaitResumeAttempt, haltGateWaitResumeReturned
case haltGateStateWaitSucceeded
case haltGateStateOpenEntered, haltGateOpenLockReturned
case haltGateOpenResumeAttempt, haltGateOpenResumeReturned
case haltGateCancelEntered, haltGateCancelLockReturned
case haltGateCancelResumeAttempt, haltGateCancelResumeReturned
```

- [ ] Self-review exact preimage-relative diff and release write ownership. Report marker placement, unchanged lock closures and business operations, all default-nil call sites, current hashes, TDD replay status and that no compile/test was executed by the worker. Root packages full diff and obtains independent spec+quality review before Task2. Review may accept source instrumentation while reserving real-output GREEN to Task2; it cannot approve the original runtime failure.

## Task 2: Root-owned single focused observation and bounded conclusion

**Files:** TD `runtime-halt-gate-build1-*`, `runtime-halt-gate-focused1-*`, `runtime-halt-gate-result.md`, independent review artifacts and living checkpoints. No additional product source changes unless a specific reviewed compile correction is needed before the sole test can execute.

- [ ] Root verifies exact entry/preimage/review hashes, changed-file set and current resources. Preserve unique raw stdout/stderr/process records with `mktemp`/Ruby tmpdir. Do not execute the prior admin capture helper/runner. Record diagnostic metadata only; never dump environment values.
- [ ] Build RunTests once with `swift build --jobs 2 --product RunTests`. Preserve entire stdout/stderr and real exit; monitor only this owned build. Compiler interruption or resource exhaustion remains an environment/compile blocker, never a test regression. A compile error needs a bounded correction/review; do not silently fall back to a previous executable.
- [ ] Only after a successful reviewed build, invoke exactly once `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run --skip-build RunTests --filter emergencyStopCancelsRunningBeforeWaitingForPlanner`. The original default full run remains RED and no whole-suite pass is sought. Record exact child PID/start identity, command, wall start/end, binary/source hashes and exit/signal. Existing `--filter` path is established by `runtime-halt-precancel-plan.md`; do not probe unknown flags.
- [ ] Immediately collect ordinary OSLog via `/usr/bin/log show --style ndjson --last 10m --predicate 'processIdentifier == ACTUAL_PID AND subsystem == "com.muzi.agentloop" AND category == "runtime-lifecycle"'`, using only the freshly observed target PID. Retain raw output and admit only the exact invocation wall interval, RunTests image/PID/category. Validate metadata count, parse errors, rejected records and horizon; do not convert a missing capture into a successful empty result. No unrelated process query or stack capture.
- [ ] Run the frozen checker on the new complete test log and admitted events, with the actual PID. It must expose exactly one fixture identity and either the legitimate registered or already-open successful gate path. Duplicate/canceled/throwing/missing/ambiguous paths remain an explicit coverage failure with raw evidence retained, not permission to repeat. Derive same-run intervals from the emitted mono fields; do not assume cross-task output ordering or claim exact publication time.
- [ ] Independent review evaluates whole bounded diff plus actual build/test/checker output, generation/scope joins and limitations. Root fully reads it, writes result/impl-report/progress/blocked and keeps the SDD ledger. One focused pass can establish instrumentation integration only; non-reproduction leaves original cause unknown. Stop this diagnostic unit after the single run and its evidence account. No automatic new probe, full rerun, administrator operation, timeout relaxation, business repair, A2 or App delivery.

## Plan self-review

The two source files and one diagnostic regression cover this observability-only unit. Task1 feeds Task2 exact stage/owner/value contracts and a frozen real-output checker. Exact-time under-lock instrumentation is deliberately excluded; post-lock and resume-attempt brackets answer the selected readiness-to-completion question with explicit limits. Historical RED replay checks the missing emitted side effect, not a private source layout. Default-nil silence and error precedence require independent source inspection; the one successful focused path cannot cover every error branch. This plan does not substitute that coverage for runtime acceptance.
