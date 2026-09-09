# Board FD oracle isolation implementation report

2026-09-06. Source implementation is ready for parent-owned compilation, focused verification, and independent review. Exclusive source writer ownership is released. Runtime behavior and acceptance remain unverified by this implementer.

## Frozen scope and hashes

The complete 103-line plan and `runtime-board-fd-plan-review.md` were read before editing. Plan SHA-256 remains `2abce42ffc1560a103778e117e08089d62da0ac74d662ce7119882ab056f4ac2`. Both sources matched the parent-created `runtime-board-fd-before/` preimages at writer entry.

| File | Preimage SHA-256 | Postimage SHA-256 | Scoped diff |
| --- | --- | --- | --- |
| `Sources/AgentLoopTestSuite/BoardServerTests.swift` | `d31bc45ade3d2b3d3c02b7b420a2dffe77700746781470cdb06b1675c5455ebb` | `3fba9b83e8005573cef51f24e114dc0694b40457d38384fb6204e99e5c8de9c8` | +164 / -9 |
| `Sources/AgentLoopTestSuite/CliBackendTests.swift` | `0a0821f7f9d283290c6db9b7f7a1723385228a63c7ef34fa0b89a69de5875f7d` | `8dd4c162a666e59ab21180c443d05a0802fdfdca504f59b5fab0b896becf1d80` | +115 / -49 |

Only these two source files and this report were edited. No new Sources path, Package.swift, production code, logger, manifest, or unrelated test was changed. Prior CLI cleanup and readiness diagnostics are preserved; the CLI diff begins in the existing 075 child-owner section. The implementer performed no Swift build/test, OS signal, App/Provider operation, new agent, or commit.

## Diagnosis preserved

The retained full-run failure at `runtime-recheck-full.log:2007` is an FD delta of 35 from a process-wide `/dev/fd` oracle. The original test's multi-second measurement ran alongside other suites, while `@Suite(.serialized)` only serialized BoardServerTests itself. This establishes an overly broad measurement boundary. It does not establish that Board leaked those descriptors, or authorize a production close-path fix. The approved executing-plans workflow therefore stayed within test isolation.

## Exact implementation

### Existing 075 owner reused in place

`OwnedSelfExecTestRequest` and module-internal `runOwnedSelfExecTest` now expose the existing self-exec process owner in CliBackendTests.swift. The request contains only label, fixed selected filter, fixed mode/evidence keys, mode, expected completion bytes, and containment. Nonempty/NUL-free request validation rejects malformed selections before spawning; executable resolution still comes only from the current RunTests image.

The previous `p1f1d075RunFDChild` is a thin adapter preserving:

- Label/directory prefix `p1f1d-075-fd-child`.
- Exact selected test `p1f1_075CLIHelpCapabilityMismatchIsUnsupported`.
- `AGENTLOOP_075_FD_CHILD_MODE` and `AGENTLOOP_075_FD_CHILD_EVIDENCE`.
- 15-second containment and exact `live-drain\nsurviving-run\nsurviving-abort\n` completion bytes.
- The existing child body's `deliberateChildFailure`, occupied-target regression, live-drain/sentinel assertions, and intentionally failing-child parent checks. Only the negative parent's caught process-status type was adapted to the shared owner.

The same one native utility Thread plus checked continuation runs the same blocking mechanics. Current-image resolution, `/usr/bin/env`, inherited `environ` including diagnostic opt-in, exclusive 0600 log creation, owned-log normalization, `/dev/null` stdin, shared stdout/stderr log description, auxiliary close, CLOEXEC_DEFAULT, single-use setup resource release, exact-child poll, existing containment sleep, ownership reconfirmation, kill/reap, and evidence emission are retained. No second spawn framework or test-wide execution lock was added.

Only the output emission lock is shared, and it covers complete evidence writes after child execution. The emitted block retains full stdout/stderr and completion bytes, and now includes source-owned label, mode, actual PID, raw status, and log/evidence paths. Both file reads remain independent. Success requires zero raw status plus exact expected evidence before deleting its fixture. All non-successes retain their files. The shared child-status error carries actual PID/status and both paths; other resource-owner failures retain the same identity/path context plus primary and cleanup errors in `OwnedSelfExecTestFailure`. A cleanup/read/output failure wraps status instead of being accepted by a negative regression as an expected child failure.

### Two Board bodies isolated without weakening their checks

The two existing test entry methods are async wrappers. Their original synchronous 20- and 100-iteration bodies remain private static methods in the same suite. A source-owned mode selects one exact test filter and uses `AGENTLOOP_BOARD_FD_CHILD_MODE` / `AGENTLOOP_BOARD_FD_CHILD_EVIDENCE`.

| Mode | Selected original test | Exact completion | Outer containment |
| --- | --- | --- | --- |
| `blocked-handler` | `boardServerStopWaitsForBlockedHandlerThenCloses` | `blocked-handler:20\n` | 60 s |
| `accept-loop` | `boardServerStopWakesBlockedAcceptLoopAndReleasesListener` | `accept-loop:100\n` | 60 s |
| `blocked-handler-leak-proof` | Same blocked-handler test/body | `blocked-handler:20\n` | 60 s |

The child checks its mode before it can launch another child. Mismatched/invalid modes throw. It validates an absolute, NUL-free, standardized evidence path with the exact evidence basename, expected source-owned fixture label plus UUID, and the inherited temporary directory. A launched child that cannot bind throws before the body and does not write completion; only the ordinary parent branch retains the existing socket-availability skip. Completion is written with `.withoutOverwriting` only after the body and its defers return.

Both original loop contents and their cleanup defers are unchanged. The blocked-handler body still injects its intentionally suspended handler queue; its accept worker remains the current production default path. The accept-loop body retains both default workers. The 0.1 s blocked-stop wait, 2 s resumed-stop wait, 5 s weak-reference deadline, bounded connection retry, stop-error/EOF/weak-reference/socket assertions, and queue-resume-once behavior remain intact. Outer containment is separate from these original per-iteration bounds.

`fileDescriptorCount()` now throws on `/dev/fd` enumeration failure instead of inventing zero. Both FD assertions use throwing baseline/final counts and retain the exact `finalCount - baseline < 10` threshold. A fixed measurement line prints mode, actual PID, baseline, final, delta, and completed iteration count after the loops. No ordinary measurement probe descriptor remains open across the interval.

### Real held-FD failure regression

`boardFDIsolatedLeakStillFailsParent` runs the same blocked-handler child with `blocked-handler-leak-proof`. Directly after its baseline, that mode opens 32 distinct owned `/dev/null` descriptions using `O_CLOEXEC`, holds them through the final count, and checked-closes every successfully opened descriptor in defer. Partial open failures also run that defer. No descriptor is overwritten or guessed, and the normal mode opens none.

The negative parent accepts only a direct, reaped nonzero child-status error and then independently reads both retained files. It requires exactly one recorded issue, from the original `finalCount - baseline < 10` expectation; one measurement line for that same child PID/mode; measured delta at least 10; and exact completed `blocked-handler:20\n` evidence. Additional assertion/close failures, mode/setup errors, containment, missing evidence, read errors, or shared owner cleanup failures do not become expected success. Only after all negative evidence checks pass does the regression remove its own exact fixture directory.

## Static checks and verification handoff

`git diff --check` exited 0. Both complete scoped diffs were inspected against the frozen preimages, including unchanged loop bodies and existing child ownership mechanics. No runtime or compile success is asserted.

Parent now runs the approved focused commands with full unique stdout/stderr logs and actual exit codes:

```text
swift run RunTests --filter p1f1d075FD
swift run RunTests --filter p1f1_075CLIHelpCapabilityMismatchIsUnsupported
swift run RunTests --filter boardFDIsolatedLeakStillFailsParent
swift run RunTests --filter boardServerStopWaitsForBlockedHandlerThenCloses
swift run RunTests --filter boardServerStopWakesBlockedAcceptLoopAndReleasesListener
swift run RunTests --filter a3Revision02EntryBoundaryRemainsByteExact
```

The expected failing nested 075/leak child is separate from the outer test result. Review complete outer summaries, child status, full assertion output, and exact phase evidence. Positive children must each finish all original iterations with status zero and their original threshold passing. Obtain a non-implementing review before acceptance and retain the required later full concurrent gate.

No material implementation ambiguity or scope deviation was found. The inherited runner's exact-child termination/reap boundary remains as previously implemented; it was not replaced with an unjoined cleanup shortcut. If an isolated positive child remains red, stop at its narrower evidence and distinguish FD growth from deadline/shutdown/worker failure. This task does not clear the other full-run issues or establish a globally green runtime gate.
