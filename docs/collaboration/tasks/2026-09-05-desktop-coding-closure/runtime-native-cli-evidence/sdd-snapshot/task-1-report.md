# Task 1 implementation report — native CLI mechanics fixture

Date: 2026-09-09. Source implementation is complete and the source lock is returned to root. This report records implementation only; root owns every build, test, workload, and process verification.

## What changed

- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`: added one stored async `@Sendable` environment provider, threaded it into each execution, and replaced only the hard-coded login-environment acquisition. Both the package/live initializer and the internal default preserve `LoginShellEnvironment.shared.environment()`.
- `Sources/AgentLoopTestSuite/CliMechanicsFixture.swift`: added the exact internal native dispatcher, checked stdin/write/readiness-file operations, fixed TERM/default-TERM modes, same-group `posix_spawn` held-stderr acknowledgement, narrowly owned failure cleanup, benign environment reporting, and current-runner identity lookup.
- `Sources/RunTests/main.swift`: dispatches the internal fixture switch before `Testing.__swiftPMEntryPoint`.
- `Sources/AgentLoopTestSuite/CliBackendTests.swift`: stages byte copies of the current runner, injects fixture-local environments, maps CLI152/213/346/347/372, preserves the opt-in real Codex path, and adds exact-once environment plus invalid-NUL-before-spawn regressions. Each harness owns an isolated `ShellProcessRegistry`, injected into the seven controlled backend constructions while the opt-in real path remains unchanged. The long-running tests assert one active registration after readiness and before cancellation or forced failure; joined cleanup and the short completion/rejection paths assert zero residue, with execution identity and count retained in cleanup failures. CLI152 retains the aggregate `200 x 10 ms` watchdog, requires `parent-exited`, expects `.pipeDrainIncomplete`, does not request cancellation on its normal path, and requires no unexpected recorded frames.
- `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`: replaces the 065 generated shell with one staged native runner per owned harness, injects fixture-local environments for controlled backends, and preserves the production verifier negative control.
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`: preserves the original 206-entry manifest and 102-entry historical baseline, derives 101 unaffected historical entries, registers exactly the runner plus new helper as dated successors, and pins both reviewed successor hashes separately.

Owned source count: exactly six paths (five existing paths changed plus one new helper). Current line counts are 2,068 / 5,128 / 9,909 / 14 / 8,610 / 578 respectively, 26,307 total; the new helper is 578 lines.

## Six 065 mappings

1. Production signature rejection: `exit-zero` (live verifier; no controlled environment override).
2. Injected signature rejection: `exit-zero`.
3. Pre-registration abort: `ready-file` with `resume-ready`; creates readiness before any stdin drain and remains alive with stdin open.
4. Cold gate: `ready-file-ignore-term` with `cold-ready`.
5. Main cancellation/drain/commit-once lifecycle: `ready-and-drain-ignore-term`.
6. Forced-error cold control: `ready-file-ignore-term` with `cold-ready`.

## Successor accounting

- Frozen manifest bytes/digest and `entries.count == 206` remain unchanged.
- Historical `liveEntries.count == 102` remains asserted.
- Exact successor set is `{Sources/RunTests/main.swift, Sources/AgentLoopTestSuite/CliMechanicsFixture.swift}`; its frozen-manifest intersection is exactly `Sources/RunTests/main.swift`.
- The original runner manifest hash remains asserted as `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`.
- Reviewed current runner hash: `67d034114d15b735133f5f3749158d885656c6c895365e78fcd35f4c2cca4b37`.
- Independently approved new-helper hash after the bounded compile and cleanup-accounting corrections: `98b11fe7eb485f6833dda059b08523a039924ea19a5e30aa9316d76b03971be2`.
- After subtracting the exact historical runner successor, 101 unchanged historical entries are compared against live enumeration; the new helper is separately pinned. The prior two blocking-progress successors remain separate.

## Tests written or strengthened

- `cliProcessBackendUsesInjectedEnvironmentExactlyOnce`
- `cliProcessBackendRejectsInjectedEnvironmentNULBeforeSpawn`
- Seven controlled CLI backend constructions now prove fixture-local registry ownership; the three ready/cancel-or-error tests require `activeCount == 1` before their trigger, and joined cleanup plus CLI213/548/549 require `activeCount == 0`.
- CLI152 now proves the acknowledged same-group holder path rather than relying on a 300 ms self-expiry.
- Existing CLI213/346/347/372 and both 065 parent tests now exercise fixed native modes without shell/login-environment fixture dependencies.

## Verification and concerns

NOT RUN by implementation agent: build, focused tests, authoritative `swift run RunTests`, strict App compilation, diff check, native fixture execution, process inspection, or signal observation. Root build 1 failed only at the helper's qualified `Darwin.sigaction` resolution and one async Boolean autoclosure; the retained build evidence is root-owned. The bounded compile correction uses the standard unqualified imported `sigaction` call (separately typechecked by root without executing a signal) and evaluates the actor result before the predicate. Independent review then identified discarded readiness/ack descriptor closes and spawn-structure destroy results; the helper now aggregates every such cleanup failure with the primary error, and a post-spawn teardown failure cleans up the owned child before any parent marker or success. Runtime verification remains NOT RUN pending root's next build.

No material design blocker was found. Residual risk is the explicitly accepted ordinary Mach-O/dynamic-loader startup and the cost of scoped 94,910,544-byte fixture copies. The 578-line helper is larger than the initial rough estimate because it contains explicit mode validation, checked low-level I/O, readiness authority checks, spawn file actions, descriptor normalization, acknowledgement, aggregate cleanup accounting, and partial-start child cleanup; no generic command runner, shell fallback, deadline change, prewarm, or global environment mutation was added.
