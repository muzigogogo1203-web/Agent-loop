# Help probe forward progress — pre-GREEN source report

## Scope and conclusion

- Changed only the two approved source paths.
- This repair is deliberately limited to the independently identified help-probe cooperative-executor violation. Boundary1 proves broad task-admission starvation, but its timeline also proves the live help-probe portion did not run during the three observed CLI readiness delays; this work therefore does not claim sole attribution for those failures.

## RED source written

- `CliEngineAdapter.swift`: added a package-only synchronous runner seam for `CliHelpProbeV1`. The default initializer still selects the original live `run` implementation, and `snapshot` remains inline for the pre-GREEN RED.
- `BlockingProcessOperationTests.swift`: added `cliHelpProbeSnapshotPreservesCooperativeProgress`, using the existing strict-pool owned self-exec boundary with a distinct environment/evidence identity.
- The child creates a real executable-mode file and derives its actual stat/hash authority, but the injected runner intercepts the first exact `--version` request before any subprocess creation.
- The injected runner blocks on a real pipe. A dedicated controller queues and retains a sibling task, records whether rescue was required, releases the pipe, and closes its owned writer. The canceled snapshot task, controller completion, sibling task, reader ownership, exact sentinel, invocation count, authority, argv, byte results, close results, and no-rescue requirement are all joined/checked before evidence publication.
- Expected old-scheduling RED: all mechanics complete, but `rescueUsed == true`, so the final no-rescue assertion fails and the child publishes no success evidence.
- The existing `blockingProcessOperationPreservesCooperativeProgress` behavior and assertions are unchanged.

## Counts and hashes

- `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`: 4,791 -> 4,828 lines; SHA-256 `8990d76e0c6ffae563b691324cc36760078c315913197ac246ce97704fa5a100`.
- `Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift`: 365 -> 693 lines; SHA-256 `9143914cf81e6db4ffa7ac94e55adcb5b6f160ef1f9ae32a8b16c5ba15308c9f`.

## Verification status

- Build: NOT RUN (root-owned).
- Focused RED: NOT RUN (root-owned).
- Runtime/process tests: NOT RUN (root-owned).
- Source review: implementer diff-only self-review completed; independent review remains required.

## Risks for review

- Confirm Swift 6 accepts the package typealias closure and canceled `Task.result` usage without isolation diagnostics.
- Confirm the strict-pool child reports the intended no-rescue failure rather than fixture validation or compilation failure before authorizing GREEN.
- The test seam exposes a small package-level result shape solely because a closure returning the private live `ProbeResult` cannot be initialized from the test target; the production default remains exact.
