# Parent independent review of FD fixture plan

Approved revised plan SHA-256 `c01dd8c21cbbf85340f0a2559b68315641bbd5027c379ee89da09c6df081114e` for its single test-source task. Parent did not author the diagnosis/plan or implement the task. No claim of runtime acceptance.

The retained macOS crash establishes the exact cause: PID 95860, EXC_GUARD on fd 304, faulting dup2 in the old sentinel helper. Re-running the unsafe mutation is unnecessary. Process isolation keeps the three original FD-sensitive assertions from contending with other suites; F_DUPFD_CLOEXEC independently prevents clobbering any occupied slot, even if runtime activity inside the isolated child reuses a number. Occupied-target and real child-failure regressions preserve meaningful behavioral coverage.

Parent requested and checked two refinements now present: CLOEXEC_DEFAULT with checked spawn attributes/actions prevents inherited unrelated pipe ends from delaying other tests' EOF; a single exclusively created log open description is shared by child stdout/stderr and closed by parent exactly once. Full child log and exact phase evidence are emitted before successful fixture deletion, so the full parent log remains verifiable. Unexpected wait errors retain primary error and cannot abandon ownership silently or signal after ECHILD/reap.

Local SDK defines F_DUPFD_CLOEXEC; current production spawn paths already use POSIX_SPAWN_CLOEXEC_DEFAULT. The existing test-file environment/self-exec seam permits this change without editing the byte-frozen RunTests entry point or adding sources. Original drain/stop/reap/EBADF/managedPolicy assertions and their deadlines remain; only a new bounded child-containment watchdog is added. Full suite concurrency is unchanged.

Implementation must remain exactly one file, retain safe error/secondary-cleanup reporting, and receive separate code review. Parent owns focused and full runs and parent/child event capture. The two packaging scripts are still held by their sole writer; fixture implementation starts only after that writer releases them, per the task sequencing rule.
