# CLI cleanup provenance RED — independent source review

2026-09-06. Responsibilities-separated reviewer using the requesting-code-review role. Read the complete `runtime-cli-cleanup-provenance-red-plan.md`, saved scoped diff, freshly generated actual preimage diff, existing stubborn CLI fixture/result classifiers/scenario, and the actual adapter cancellation and execution catch paths. This is approval of the single behavioral assertion only; no production repair design is approved here.

## Verdict

**Source APPROVED for the planned single incremental build and focused 069 RED observation.** No Critical, Important, or Minor findings in this bounded change. The assertion checks the intended cleanup-error provenance of an independently running consumer and preserves the separate externally canceled-consumer expectation. Root owns execution and interpretation. No runtime-pass, behavior-fix, full-gate, merge, or release approval is implied.

## Actual scope and reconstruction

- Frozen preimage independently verified: `f77401a884501bb928233296336ba1f756caf00ca1c45069d26c507b5547bf8a`.
- Reviewed current test source independently verified: `2d776ab33cd2b1fbc061a19c123a74262e04406a0b065d74ef2808272bd51449`.
- The fresh preimage-to-current diff is the one planned replacement at `ExecutionEngineConformanceTests.swift:5326`: `_ = await stubbornDirectConsumer.value` becomes a three-line `#expect` requiring `process_group_still_alive`.
- Independent in-memory reversal of exactly that unique replacement reproduces the complete preimage byte-for-byte. No new fixture, wait, Task, timeout, cancellation operation, helper order, assertion removal, production edit, or other source edit belongs to this bounded change.
- `_ = await stubbornSignalConsumer.value` remains once and unchanged. The no-index diff exit 1 is expected because this replacement exists.

## Behavioral basis

`P1F1D069StubbornCliCell` (`ExecutionEngineConformanceTests.swift:3028`) creates a producer stream without emitting or finishing it. `cancel` increments its protected count and always throws `CliProcessBackendError.processGroupStillAlive`; stream termination remains observable through its existing callback and waiters. The driver delegates to this cell without replacing the error.

The scenario (`:5270`) explicitly cancels `stubbornSignalConsumer`, waits for its cancellation owner and first producer termination, and leaves that consumer result unconstrained. It then creates a distinct `stubbornDirectConsumer`, awaits the second launch, and directly calls the real adapter's `cancel`. The test never cancels this second consumer. Its direct cancellation result is already required to be `process_group_still_alive`; the original producer-termination wait, exact cancellation count of 2, and empty terminal sinks are retained.

The label helper (`:3271`) distinguishes the concrete process-group error from `CancellationError` as `process_group_still_alive` versus `cancellation`, so the added assertion does not depend on incidental error descriptions or private state. It exposes an existing discarded observable result of real adapter execution.

In `CliEngineAdapter.resolveCancellation` (`CliEngineAdapter.swift:4133`), a cleanup-owner process cancellation error is saved as local `firstError`, and the existing outer Task is then canceled unconditionally. The resolver still waits for outcome and outer settlement, then throws `firstError` to the cancellation claimant. Meanwhile, the outer execution path (`:4484–4556`) iterates the still-open producer with cancellation checks before and after iteration; its cancellation catch rethrows `CancellationError` (`:4579`). The outer task catches and publishes that result, then finishes the execution stream with that same error (`:4074–4087`). Thus the direct cancellation caller can receive the original process-group failure while its separately running execution consumer receives the internally induced cancellation category.

The fixture fixes the failing cleanup category and prevents a successful producer terminal winner; the existing second-launch barrier ensures the tested generation has launched. Whether internal cancellation reaches the pre-iteration check or suspended iteration, the current execution path still reaches its cancellation error handling. This makes the amendment an appropriate deterministic regression case **if the enclosing 069 test reaches it**. It does not rely on reproducing the earlier unlocalized race, and an earlier failure must still be reported as preventing this RED observation.

Preserving error provenance for the non-canceled consumer is consistent with fail-fast observability: a direct cancellation failure must not become an apparently unrelated cancellation simply because the adapter internally stops its own task. This test does not prescribe the repair mechanism or permit skipping outer cancellation/joins; the open producer is precisely why cleanup settlement must remain part of a separately reviewed repair.

## Remaining gates and review actions

No compiler, test, runtime, process manipulation, OSLog extraction, database, App, source edit, commit, or subagent action was performed. This review artifact is the sole file write. The forthcoming production proposal is intentionally outside this verdict. Root must retain the focused result and distinguish the expected new assertion failure from any earlier unrelated failure; broader runtime and desktop gates remain closed.
