# Prospective abort465 containment — source design

2026-09-09. Supplement to runtime-cleanup-provenance-plan.md Task2. Not an execution permit. It preserves the historical missing-identity failure as unresolved evidence.

## Fresh ownership only

The abort465 fixture is the C ready-file mode, which does not create descendants. The test inspector captures the exact spawned direct child immediately before the first SIGCONT (and before its deliberate dispatch failure): actual proc_bsdinfo before and after proc_pidpath plus checked staged-file identity/hash. Require positive PID greater than1, pbi_pid equal requested PID, pbi_ppid equal getpid(), pbi_pgid equal PID, pbi_uid equal getuid(), nonzero start tuple, and identical before/after PID/PPID/PGID/UID/start tuple. Require the canonical proc_pidpath to equal the canonical staged authority path and checked device/inode/hash to match. Store that identity once; never discover a later process by filename prefix or PID range.

Print the synthetic fixture UUID, canonical execution UUID, exact private root and captured identity synchronously before reaching SIGCONT. Subsequent actual signal and liveness result/errno observations carry that execution identity. Fixture paths are only in scoped test evidence; production descriptions remain type/phase/ID-only.

## Returned uncertain cleanup

The original backend remains responsible for normal termination, reap, drain and registry cleanup. After both cancellation and stream waiters have returned and the Board result-reader has been joined, run exact read-only PID/group absence and waitid(WEXITED|WNOHANG|WNOWAIT) observations before removing the fixture. ECHILD + ESRCH for PID/group, registry zero, removed socket/config and checked directory close are required to permit removal.

If ordinary cleanup is uncertified, retain the root and error record. A test-only independent containment helper may intervene only with the stored fresh identity after revalidating the same kernel tuple/path/file authority. ESRCH means no signal. An exact still-live direct child permits positive-PID SIGKILL; if its same identity still exists, positive-PID SIGCONT may follow. Record each syscall result/errno. Positive-PID signaling deliberately does not assume authority over a newly discovered group member. Identity drift or ambiguity fails closed without signaling.

The helper never calls waitpid or consumes a wait event. Bounded polling uses waitid with WNOWAIT and read-only group probes; any waitable child, live group, unexpected errno, missing identity or timeout is a containment failure. Any emergency signal attempt is itself a failing test condition and does not repair or erase the backend error, registry residue or original cleanup certificate. Even if containment succeeds, retain the original uncertain fixture and report.

## Explicit limit

This helper contains only a returned uncertain cleanup. It cannot join backend-owned tasks or act when launch/cancel/stream never returns. If inspection of the exact source shows the selected test can enter an unreleaseable wait, do not admit the workload: design backend join ownership or a separate parent containment boundary first. No outer-PID-only kill or historical-PID fallback is allowed.

## Review and evidence

## Total test-body ownership supplement (source design, not executed)

The responsibilities-separated source investigation found that current abort465 can throw before its defer is installed (missing-gate branches and socket construction), and later hello/tool-call/gate/reader failures can bypass asynchronous joins. The approved cooperative-boundary work must precede any fresh real-process run.

Introduce an owned orchestration helper returning a report rather than throwing from the body. It creates the stream, stream waiter, publication probe and cancellation waiter; captures the existing choreography in `Result` without changing its order: missing gate, client creation, hello, tool call, reader start, cleanup gate, missing-gate release, publication sample, cleanup-gate release. Then one unconditional epilogue releases both gates, interrupts the owned client if present, joins any started reader, joins cancellation and stream, closes the client, and returns each result. No throwing assertion or `try await` may escape that epilogue. Original body errors remain primary and every cleanup result remains separately visible. Both existing publication-order samples and all original assertions remain.

A test-only native safety guard starts with the owner. It waits on its own condition for disarm or 30 seconds, retaining only the idempotent gates, a synchronized owned-client slot (installed immediately after construction), and the fresh identity. On expiry it releases both gates, interrupts that client only, and may invoke exact-identity positive-PID containment described above. Every intervention, missing/drifted identity and syscall/probe result is recorded. Main disarms and joins this native controller only after joining reader, cancellation and stream. Any intervention fails the test and retains the fixture; it never erases an original backend failure.

Limit remains explicit: a native guard cannot force an arbitrary backend-owned task to finish if it remains stuck even after owned gates/socket release and validated child containment. It does not introduce a second reaper. Exact source review must assess actual reachable waits before entry; ordinary unbounded process join must not be confused with a newly proven unreleasable path.

Other subcases are distinct: the signature rejections are pre-spawn; cold065 and forced865 already retain fresh child identity and independent PID/group/wait certification; main ready-and-drain currently has joined backend/registry evidence but no independent wait certificate. Only historical abort465 is observed uncertified. None of these may substitute for another execution's evidence.

### Independent design review requirements

Reviewer forward_progress_review approved source preparation only. Exact implementation must also: (1) add explicit abort state that wakes async `waitUntilEnteredOrCompleted` continuations as well as releasing native gate waits; (2) keep descriptor ownership synchronized through shutdown, then disarm/join the guard before close; (3) make the socket descriptor interruptible before blocking connect/hello/send, or demonstrate a bounded constructor; (4) capture fresh child identity before the controlled wait; (5) retain body/reader/cancellation/stream/guard results and join every started task despite earlier errors. A theoretical arbitrary kernel hang does not block admission by itself, but a reachable wait with no release/containment path does.

Before real-child entry, deterministic no-child coverage must call the actual owner with injected hello failure and a real socketpair plus controlled waiter tasks, require the original sentinel and every join with no normal-path guard intervention; cover construction failure with absent client/reader; and explicitly fire guard expiry before gate entry to prove async-waiter wakeup. These are source-test requirements, not permission for additional real-process observations.

### Concrete API refinement for implementation planning

Use `.aborted` gate outcome plus `abortWake()` that sets aborted/released under the condition, broadcasts native waits, removes and resumes pending async waiters with the explicit outcome, and returns first-abort/entry/waiter-count observations. `enterAndWait()` returns whether it completed normally; ordinary sink/inspector paths throw an explicit safety-abort error on false. Existing successful release semantics remain.

Split socket creation from connection: make an owned nonblocking descriptor, register it in the synchronized guard control immediately, then connect. Nonblocking connect/send/read poll ownedFD readiness in25ms slices and check recorded abort/deadline; preserve the existing line content/EOF behavior. Hold descriptor lock through shutdown; guard never closes. Owner joins all I/O tasks, disarms and joins guard, then checked-closes once. If abort precedes socket installation, installation sees it and cannot start connect. Do not silently swallow socket setup/close errors.

Capture/publish exact fresh identity before the injected missing-image gate. A locked one-shot containment claim prevents guard and late identity publication from double signaling. Expiry before identity records abort and wakes owned waits; subsequent publication sees abort and uses the same exact-identity containment rule. No guessed PID, group discovery or second reaper.

The actual owner helper must support injected task/client seams for no-child tests without duplicating the choreography. Tests cover hello failure with real socketpair and gate-backed joins, constructor sentinel with absentclient/reader, and expiry before any gate entry. Live guard budget remains30s; the no-child expiry test may inject a short budget. A normal body failure is retained distinctly from guard intervention. All original happy-path publication samples and signal/poll/error/resource assertions remain reviewable.

Implementation stays in ExecutionEngineConformanceTests.swift, after Task1's source lock is released. Core reap interpretation and ignored-result decisions remain untouched until measured evidence justifies their own regression. No original 065 assertions, poll budget or signal order are loosened.

Before the first real-process observation, reviewer must inspect exact implementation and the one selected parent test's lifetime paths, not only this concept. Root retains complete stdout/stderr, before/after input manifest and binary identity. Existing opt-in numeric lifecycle events may be collected once for that exact owned RunTests PID/image and bounded invocation interval; no broad log export, administrator sampling or unrelated process inspection.
