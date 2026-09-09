# Blocking-path source investigation — 2026-09-09

Root and two responsibilities-separated source readers inspected actual callers against the admitted boundary1 trace. No additional workload or system capture was executed for this investigation.

## Established boundaries

- `CliProcessBackend.start` queues run after the mechanics registry's short lock is released; the first run statement logs entry. No intervening project lock explains the observed4.7–9.2s queue delay.
- `CliHelpProbeV1.snapshot` is async but has no suspension and runs synchronous version/help polling, sleep and waitpid inline. Cache Task.detached does not offload that body. This is a concrete production forward-progress defect. However, boundary1's075 phase5 (lazy-cell task group) occupies the relevant interval and the live probe portion comes later: do not attribute those three delayed CLI entries to this particular help probe. The separately scoped help-probe repair is justified by its own actual-callsite regression.
- OAuth controlled-test state waits on NSCondition directly from its async matrix after enqueueing the very Tasks whose registration it needs. Five calls across three scenarios, default5s. Its test overlaps the delayed CLI entries. The bounded OAuth plan repairs this test dependency through a deterministic actual-facade regression; overlap does not establish unique causation.
- CardRunner's armed-claim test blocks through a synchronous lifecycle observer invoked while the task-registry lock is held. Moving its wait to another thread but synchronously joining would still pin the caller; making the observer async would alter the lock/linearization oracle. No CardRunner change is admitted by the current two plans.
- Cancellation-ignoring planning test providers use NSCondition, but Planner already dispatches their synchronous streamTurn to DispatchQueue.global. They may add shared resource pressure; that is not proof of direct cooperative-worker occupancy. No broad provider rewrite is admitted.
- The repaired CLI reaper and existing Board managed workers/async stop already offload blocking waits. They are not a newly identified direct pre-run-entry blocker.

## Selected actions and stop boundary

Execute only runtime-help-probe-forward-progress-plan.md and runtime-oauth-wait-forward-progress-plan.md after their independent entry/source gates. Their three source paths are disjoint across two writers; root owns builds/tests. Both need actual RED/GREEN before one reviewed integrated default full gate. Preserve original production timing, test5s/3sbudgets, matrix oracles and historical source inventory. No priority change, suite serialization, selfexec descendant expansion, additional capture or blanket resource attribution.
