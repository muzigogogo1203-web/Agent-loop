# CLI cleanup error provenance — deterministic RED

2026-09-06. Bounded test-only stage before any production repair. Existing069 failure remains unlocalized; one diagnostic run passed without changing cancellation behavior. Independent source analysis found a deterministic coverage gap in the existing stubborn CLI scenario.

## Required invariant

When a direct adapter cancellation fails with `CliProcessBackendError.processGroupStillAlive`, the independently running, non-canceled execution consumer must observe that same failure category, not a CancellationError introduced solely by the adapter canceling its own outer task. Actual externally canceled consumers are different: this amendment does not change their behavior or assertions. No success receipt or terminal submission may be fabricated on cleanup failure.

## Exact test-only change

Starting from test source SHA256 `f77401a884501bb928233296336ba1f756caf00ca1c45069d26c507b5547bf8a`, in `p1f1d069ExerciseCliHandoffAndImmediateWinners` replace only `_ = await stubbornDirectConsumer.value` with `#expect(await stubbornDirectConsumer.value == "process_group_still_alive")`, formatted across lines if needed. Keep the earlier `_ = await stubbornSignalConsumer.value` unchanged because that consumer was explicitly canceled. No other source change.

The existing `P1F1D069StubbornCliCell` leaves its producer stream open and throws `processGroupStillAlive` from cancel. Existing barriers ensure the second launch exists; the direct consumer is never canceled by the test. Existing code already awaits the direct cancel, stream termination, and consumer, checks exact cancellation count2, and requires both terminal sinks empty. The added assertion therefore exercises real CliEngineAdapter error propagation without a new fake, fixture, timing control or test-only production seam. The wrong production branch is the unconditional internal outer cancellation erasing the caught cleanup failure.

Root owns this sole source edit, freezes the preimage and scoped diff, obtains independent assertion/scope review, then runs one normal incremental build plus focused069 with complete outputs/PID/hashes. A failure at the new assertion showing actual `cancellation` is the expected behavioral RED. If an earlier failure prevents reaching it, report that honestly and scope the next diagnostic; do not hide the earlier error. Any pass is not permission to invent a cause. No production edits before RED interpretation and reviewed repair semantics.

Production repair design is separately read-only in progress: retaining outer cancellation/joins is mandatory because actual CLI cancellation can fail before the producer stream settles. Do not copy the ModelLoop skip-cancel condition. Exact-generation state and consistent atomic outcome publication must preserve the original error without rewriting an already settled terminal winner or unrelated genuine failure.

No timeouts, suite serialization, @Test inventory, source-boundary manifest, Package.swift, real data, App, secrets, paid Provider, commit or release changes. All broader runtime/product gates remain unchanged.

## Observed RED and label-only supplement,approximately05:02

The single admitted run reached the new assertion and failed exactly there, with no other issue: PID58119,04:59:27–04:59:56,build19.86s,0695.529s/exit1. All12 hashes match. However, the async expression's diagnostic prints only the assertion text, not its evaluated label; do not call `cancellation` an observed value yet. Preserve `runtime-cli-provenance-red.log` and its original source manifest.

Root admits one narrowly reviewed observation supplement: bind the SAME single `await stubbornDirectConsumer.value` to local `stubbornDirectResult`, print `P1F1D069_RESULT=stubborn-direct value=\(stubbornDirectResult)`, and assert that local equals the SAME expected literal. This existing classifier returns only closed fixed labels, never raw error/user/provider content. No second await, changed consumer, catch or behavior. Repeat the focused command once after this new observation, retaining actual value. This is not an unchanged retry for green; it closes a specific missing evidence field before production repair.

## New localized earlier failure

That admitted observation ran PID58651,05:02:59–05:03:27,build23.34s. It failed earlier in the existing SharedAdapterCleanup scenario,0.511s/one issue/exit1. The exact sequence is model-begin, model-end, cli-begin, then propagated CancellationError and no cli-end. Both immediately preceding cancellation caller expectations produced no issue and therefore received their expected typed `P1F1D069AdapterCleanupFailure`. The only awaited operation between cli-begin and cli-end is `cliConsumer.value`; that consumer catches the expected cleanup type and propagates other errors. This localizes the execution-stream error substitution in this new run without relying on the later stubborn label.

The stubborn label was NOT reached and is not an observed value. Original PID50925 still lacks markers and cannot be retroactively assigned a join. Root proposes these combined REDs (earlier deterministic stubborn assertion failure plus new exact CLI consumer CancellationError after typed cleanup results) as stronger direct production-failure evidence for the same repair; independent reviewer must explicitly assess that entry amendment. Do not rerun unchanged just to obtain the later label. Post-fix verification must reach both joins and observe the retained stubborn expected category, with every matrix assertion intact.
