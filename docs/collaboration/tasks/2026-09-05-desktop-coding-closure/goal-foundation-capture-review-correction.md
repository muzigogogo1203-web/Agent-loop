# Checkpoint 3 bounded review correction

Initial implementation diff: `goal-foundation-capture-fix1.diff`, SHA-256 `d4a910e7a13523ab2efe8e3952961223b4b631d9919613dacef4e7dea8a0b189`. The first GREEN log SHA-256 is `e758910099f7cc3b46086773ac9770c98f9e8eeb8991d9d82d69330640dea688`: PID73470, build147.81s,23tests/1suite/1.994s/exit0. All305 frozen inputs match. This is focused evidence, not approval.

Independent reviewer found, and parent confirmed by source inspection:

1. `prepareSubmission` and direct `sealCaptureStage` compare original canonical request JSON using Swift String equality, which accepts canonically equivalent Unicode with different UTF-8 bytes. Runtime model is part of the request but not the capture command, so the historical domain command hash cannot catch that drift. Add separate actual prepare/seal counterexamples, then compare request bytes exactly at both boundaries.
2. Direct `appendCaptureReceipt` checks real receipt identity/bytes and actual input/work, but cannot establish event/scope/outbox integrity from those fields alone. Add a first-attachment counterexample with only the owned event outbox deliberately removed in an isolated test DB; require the existing domain graph error and no journal changes.

The original plan requires transaction-taking internal append behavior, not a static append ABI. Parent authorizes changing this new method to an instance method so it can reuse its existing AppDatabase-owned DomainEventStore. Reconstruct the prepared command and existing InputGoalStore capture replay plan from the stored intent; require the actual receipt as before; invoke existing `executeCommand` against the same Database with `makeNew` always throwing `DomainCommandGraphIntegrityError`. Compare the validated result bytes with the candidate before journal mutation. Do not expose the historical private graph validator, copy graph SQL, create a second transaction, or repair missing domain records. Existing test receiver-only changes are permitted after real RED; preserve all original expectations.

No SQL, DomainEventStore, old tests, Provider or UI scope is added. Three new tests are prepared before production changes. Root owns compilers; the implementer owns only the explicitly granted files; reviewer remains responsibilities-separated. Corrected results and review closure must be recorded before checkpoint3 acceptance.
