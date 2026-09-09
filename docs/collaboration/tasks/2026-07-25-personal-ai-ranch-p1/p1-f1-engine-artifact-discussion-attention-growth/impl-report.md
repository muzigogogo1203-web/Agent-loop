# P1-F1 Implementation Report

Status: **F1A CLOSED; F1B CLOSED; F1C PLAN-ONLY CORRECTION PENDING**

Date: 2026-08-27

## Authority

- Effective Revision 3a plan SHA-256:
  `ae3162dbe24d2069009e7ffbc33e75b82c31c859a2a658db6bbbf543d7edf609`.
- Effective 96-line allowlist SHA-256:
  `8d4e07d1ccda444a5b5c53ba7951e5514a07d01e9262990bbf2934cad9f50e73`.
- Effective 46-line entry manifest SHA-256:
  `6048f075e2d09b21f5b6d4e56f929d81fe1ec72441e336cfaa98e356de8b9924`.
- Review01b successor verdict: `APPROVED - 0 P0 / 0 P1`; full review SHA-256:
  `b2ae3efb5cbf69aa811313dc80f8c096fde0ae9400502f88d360189c0d972f29`.

## F1A closed evidence

- Migration tests 001–016 pass together.
- v17 schema literal is the accepted 29,934-byte / 770-LF / 757-nonblank
  payload with SHA-256
  `a6ef8747ee3e8ffeb0856827f6cf8f858c681a70748cd373783ae1d23d2b4e99`.
- Real-linked and literal SQLite 3.51/3.52 matrix passes all 14 fixtures,
  rollback, replay, FK, integrity, and exact 79/208/84 checkpoint gates.
- `migration-matrix.log` SHA-256:
  `390c23cce78c0b44498db41c1d802af5b36728b207e561657309452749763a05`.

## F1B implementation

The implementation adds the closed engine command/event vocabulary and safe
result/audit catalog, full receipt/event/scope/outbox graph validation,
canonical request/session/event/terminal types, exact session resume and
close/invalidate CAS, kernel-owned execution/proposal/terminal projections,
active exact-version write fences, deterministic two-command synthetic
terminals, and lifecycle-first crash recovery.

Product file SHA-256 values:

- `Sources/AgentLoopCore/Database/EventKind.swift`:
  `caf837ec8e1521405974d76d57410d9ef78672f2d9d8a88127101053e135ceb5`
- `Sources/AgentLoopCore/Domain/CommandEnvelope.swift`:
  `b6b5bea999333674f6ea2d238f63933f93233208f177ed6f5f5c3954f97a8351`
- `Sources/AgentLoopCore/Domain/DomainEvent.swift`:
  `04477e6c717a8456246d26ee6e8b6b4b7799e8c4f01f43b04a2231b16a642dd4`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`:
  `22ac30cc432bc6c512974098a105e3fb6c64b18a618a124b77745df210e5b427`
- `Sources/AgentLoopCore/Domain/ExecutionEngine.swift`:
  `bf394cad23ab06199a8ee63e728a953b06e0d9a08a5eab547f31922423f9f57d`
- `Sources/AgentLoopCore/Domain/EngineExecutionReceipt.swift`:
  `ab77296c711fa8b7321660a86eb6ecefd7c947dfe8494396bdf547a04fc27673`
- `Sources/AgentLoopCore/Database/EngineSessionStore.swift`:
  `6aacd5d69262abc7a6a3cedb21137ce00c02281cfd8d8de448f854b78f272c69`
- `Sources/AgentLoopCore/Database/EngineExecutionStore.swift`:
  `ab494d0f9a6887dfbd8a795fdf3856c8c1f0bb77e09000e84e468682e6bf6765`

## F1B tests and verification

- Strengthened red-before-product evidence:
  `red-f1b-revision3.log`, SHA-256
  `7d1d22b4f63b86c29e08cf359f99b650cdc09b6c44294d623967f42ecee91143`.
- Identities 017–042 remain exactly 26 and each declaration occurs once.
- The exact 26-name run passes: 26 tests / 3 suites, command and tee status 0.
- Formal focused evidence: `focused-verify.log`, SHA-256
  `bd1032b14e82d8bb66099e98e051911a862165c81d83e427c23874d94b94c84e`.
- `swift build --target AgentLoopCore` passes; latest complete evidence log:
  `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/p1f1-rev3-core-build4.84fxsoSG0L.log`,
  SHA-256
  `df3f26671a48edbf267ed91fd6394bdcfb45890c0fe2a3635e6feac2ae196c55`.
- `git diff --check` passes for all Revision 3a product and test files.

## Root-cause corrections during green convergence

- Deferred the terminal receipt FK only for the bounded terminal transaction,
  so the strict command receipt can be inserted before transaction commit
  without weakening FK enforcement.
- Replaced the unregistered `engine_usage` legacy kind with the established
  `progress_note` compatibility carrier while retaining typed usage payload.
- Split exact terminal-key receipt/proposal parity from execution-level second
  terminal conflicts, preserving graph corruption as fail-closed.
- Corrected test-only corruption fixtures to bypass append-only triggers only
  inside isolated databases, and corrected begin lifecycle coverage to adopt
  the current active version as required by the Stage authority.

No fallback was added, no assertion or schema invariant was weakened, and no
F1C/F1D/F1E/F1F or F2 product implementation was pulled into F1B.

## Review02 P1 correction

The initial Review02 SHA-256
`d067c234b7afac62f9cfa774b176dc3cb3aeb4969ca98064446c7c26a8688823`
reported one P1: active recovery could heal a persisted kernel synthetic
proposal-command-only (`R`-only) graph into a different protocol-error
terminal.

- Existing identity 042 now creates that exact append-only counterexample and
  asserts `DomainCommandGraphIntegrityError` plus a byte-stable projection
  snapshot. It also injects a synthetic `C` projection failure and proves that
  the outer transaction rolls back all `R` proposal/receipt/event/scope/outbox
  writes.
- Pure red evidence is preserved in `verify-red.log`, SHA-256
  `07ff08ebb308c5461b39ea7e98a75a52b6f768416b1fcc6016a9d6d3749813b6`:
  one test failed only because the R-only graph was healed; command status 1,
  tee status 0.
- Active exact-lifecycle recovery now performs a read-only preflight for the
  five exact kernel synthetic terminal keys before request/proposal/session
  decode or any catch-to-protocol-error path. Any proposal or R/C receipt
  history on a still-running execution fails closed. Deletion lifecycle
  precedence and ordinary adapter proposals remain unchanged.
- Corrected `CrashRecoveryTests.swift` SHA-256:
  `0934090114f10a13a52ad89514ec4577e8dbbfec89cde1eaae9ca8892beea708`.
- The shared exact projection/surface snapshot now includes
  `camp_event_scope`, so both R-only zero-write and injected-C rollback prove
  that independent scope rows cannot survive. Corrected
  `EngineExecutionStoreTests.swift` SHA-256:
  `d23e3411d27b78776b7123229a0b66d774f3a97704ac55dad6668b2c15b378ea`.
- Corrected exact 26-name evidence passes 26 tests / 3 suites with command and
  tee status 0; its SHA-256 is the current `focused-verify.log` value above.
- Corrected Core build passes; log SHA-256:
  `508468812fc0374717c4594452793c1e0df40153725a4399ad5cd0af4050417d`.

The final Review02 successor verdict is **APPROVED — 0 P0 / 0 P1**. The
complete append-only Review02 SHA-256 is
`8a06de21ba238b02afc2030e82414e992b03e005899c875af3554773a7044673`;
its preceding review bytes remain an exact prefix with SHA-256
`6232d392230595faff53548290700e537a1523e9964277136a0eeef4ed12cc8c`.
F1B is closed; no further F1B audit is open.

## F1C reviewed compile scaffold

Revision 4a plan SHA-256
`8dc757ea8286a8f8e4224064d742c10879046c972094f2a04e63eaac7c39cefc`
and the append-only Review01c SHA-256
`d79fe5d8a832c08369a44ffe1698a9c4c189d5e1bfd3a24c56507523bd9b64a4`
are approved with 0 P0/P1. Before any 043–061 test byte, the reviewed
declaration-only scaffold was frozen at:

- `Records.swift`: `0d2364e4c8e0b1f7130c7cc8a5573176581685f5bb0f462b3af8eb761184b879`;
- `ArtifactBlobStore.swift`: `07cc11dba8401a4c72e92154466ff97e96502cb0eabcd63fc6cc4c166c6fb280`;
- `ArtifactStager.swift`: `32e0777d00a397639663407b11cc8cbc0f8c4bfe4e881cd4e2d789f2ed5be8ed`;
- `ArtifactOwnershipVerifier.swift`: `9288121bdf306b51a2e008631a83d1c3d95d2f69225c5456bb91a73c9af6424b`;
- `ArtifactStorageOriginStore.swift`: `9343ad9fdbee58f216d73a766cfbd2523f94fd142ee5337ec7831f19147debd4`;
- `ManagedExpeditionReportStore.swift`: `73f19f94182660085a114dd5d9b7e69312b62bc4c611f918d91c968f2bdbec06`.

Every scaffold operation immediately throws its exact typed unavailable error;
static inspection found no DB/FS/hash/clock/UUID/task/success path. The first
scaffold-only `swift build --target AgentLoopCore` passed with command/tee
status 0; `/tmp/p1f1-f1c-scaffold-build.log` SHA-256 is
`a966e105884b315518d02f6b070edffc3aa070132eac7e3aced0515eafa51755`.
This is compile evidence only, not F1C capability evidence.

## F1C tests-first evidence

After the scaffold build, identities 043–061 were declared exactly once and
the complete `AgentLoopTestSuite` target compiled before the runtime red. The
first valid exact-19 run discovered and failed all 19 identities: 18 failures
reported their matching `ArtifactCapabilityUnavailableErrorV1`, while 059
failed its nonempty legacy Board completion zero-mutation assertion. Command
status was 1, tee and evidence-validator statuses were 0. The immutable red is
`red-f1c-artifact.log`, SHA-256
`cb4a5b5be4c28af76e085212502844e2a93f69adc71cf5e5d38a0985bc522979`.

An earlier candidate used whole-name regex anchors that the custom Testing
entry point applies to the fully qualified test identity; it selected zero
tests and was rejected before any task evidence file existed. It did not alter
product or test bytes. A compile-only candidate also exposed and corrected
test-fixture access/macro issues before the valid red; neither candidate is
acceptance evidence.

## F1C implementation checkpoint — identities 043–061

F1C was implemented against Revision 4a plan SHA-256
`8dc757ea8286a8f8e4224064d742c10879046c972094f2a04e63eaac7c39cefc`
and Review01c SHA-256
`d79fe5d8a832c08369a44ffe1698a9c4c189d5e1bfd3a24c56507523bd9b64a4`.
No Claude process or review was used. No real CLI login, credential, network
provider, notification, normal user state, commit, push, merge, release, or
public action was performed.

The reviewed compile scaffold preceded all F1C test bytes. The immutable pure
red `red-f1c-artifact.log` has SHA-256
`cb4a5b5be4c28af76e085212502844e2a93f69adc71cf5e5d38a0985bc522979`:
all 19 identities 043–061 were discovered and failed through the planned
missing capabilities, with command status `1` and tee status `0`.

Functional owners and current SHA-256 values are:

- `Records.swift`: `0d2364e4c8e0b1f7130c7cc8a5573176581685f5bb0f462b3af8eb761184b879`;
- `ArtifactBlobStore.swift`: `5177843f4045f53784bb20f4946afb8ffd342371bdd717d3c1a12b97b82ace09`;
- `ArtifactStager.swift`: `a36b95243a5484de5d86754a1ed192eca7414431a8521d4701c97b221964c2a4`;
- `ArtifactStorageOriginStore.swift`: `39e2cc70680a86419ad6c5b34002e31ba3df526df47e1600715f562fff83f19d`;
- `ArtifactOwnershipVerifier.swift`: `713c327866a0036dec0754108a02c89fd914cfead0b3f8c4e35df75f91c18fc9`;
- `EngineExecutionStore.swift`: `b771100b9a49a505e19301436912bbef89c6cc0ace95a70f2ce2703f1bcd7ea7`;
- `BoardCardTransactions.swift`: `c7762797c28a069313418065d61f8222b7d0323c69023f667e82e416b6fa4757`;
- `BoardTools.swift`: `343daf95dba66cd216b17d8026d6e4ec6d84260dcefbdc689934f9b469f104ff`;
- `ManagedExpeditionReportStore.swift`: `4197501b74b8f4f1834195c1e0acb89668b1887023175d5f0f6eb818a5bb6186`;
- `Orchestrator.swift`: `ef22c392abf31c9664b49dfa139219c71ee473c8fbf2be803b59504b2f923fa0`;
- `MissionWorkflowController.swift`: `eb72a6e37ae02f03ecb73d06b4241896bdc64697ea0c940510107d2a376831c8`;
- `AppStore.swift`: `ebfc75b322a626da8a31245becd39cb2dcf73dc9deb927cb6c08cc221eff3c17`.

The implementation provides immutable blob preparation and recovery, exact
three-root garbage collection, typed managed/external origins, sealed legacy
ownership upgrades, no-follow ownership verification, same-transaction Engine
artifact graph commit/replay, removal of raw durable-path completion authority,
typed GuideChat/Harvest external fixtures, and one crash-recoverable managed
expedition-report writer shared by Core, Application, and App hosts.

Root-cause corrections after the valid red remained bounded. Blob root
bootstrap, quarantine recheck, and identity-bound unlink were corrected before
043–053 closed. Origin proof consumption now rechecks the same-handle graph and
rejects same- or cross-Camp competing origins. Verifier directory enumeration
uses an independent open-file description and rejects same-Camp identity
ambiguity. Report recovery received a second tests-first correction after a
read-only review found four P1 issues: `reportURL` recovery authority, an
`ensureReport`-masked test, unbound root/lock identity, and mismatched-final
overwrite. The valid correction red is
`/tmp/p1f1-report061-p1-red-r2.UsA7KHkx`, SHA-256
`8d7950e68adb1351463f64de26539510aeb973f72c59c66306683c9f8f97d311`;
the corrected exact 060–061 green is
`/tmp/p1f1-report060061-p1-green.3mdL81vj`, SHA-256
`3cd884f91f136608899f29207e5653f5a18b0cf5f79f8bdd1072e85e356dcdb8`,
2/2 with command and tee status `0`. A Foundation directory-URL trailing-slash
fixture was corrected to compare standardized paths; product behavior was not
changed to satisfy that lexical mismatch.

Current authoritative F1C focused evidence is `focused-verify.log`, SHA-256
`04d1a6441860351837474ad5557da8648e31ccb6ad68c608ebc4b3e74e6a78d4`:
exactly 61 expected identities, 61 started identities, and 61 passed identities
with both set comparisons and command/tee statuses `0`. The post-correction App
product build passed; `/tmp/p1f1-report-app-build-p1.AqyEMqcl` has SHA-256
`7ef6312005d318636f4b2665253c16ac0ee6e193bcb4a2a5adeadbd7ab7db6e2`.
The NUL-safe boundary remains exactly 589 outside nodes with manifest
`792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88`.

F1C is code- and evidence-complete. Its independent bounded implementation
review is the only remaining F1C gate before F1D tests-first work begins.

## F1C final bounded implementation-review correction

The first formal F1C implementation review preserved all prior TDD evidence
but reported three bounded P1 findings: compile-only scaffold symbols remained,
orphan-staging cleanup still used a path-based recursive deletion owner, and a
pre-existing report root could be accepted through an unregistered
intermediate alias. The review's 25,545-byte `NEEDS CHANGES` prefix is
preserved exactly with SHA-256
`1bd7b6d7a70f5dfbfda9430362e741bd22ab20826d894c6ffdb0e803bc397a72`.

The compile-only symbols and their two test catches are now absent from all
Core and test sources. Staging cleanup now performs descriptor-relative
`openat`/`fstatat`/`fdopendir`/`unlinkat` traversal, rebinds directory identity
before traversal, fails on namespace drift, and fsyncs the affected parent
after every successful removal. The valid cleanup correction red is
`/tmp/p1f1-f1c-cleanup-red.Fo4hym`, SHA-256
`a95c2d17b6ac87477b35fb1257f9307bde8bcc4862bad7151adf8c4cb0f36760`:
043–052 were all discovered and only 046 failed its two new capability
assertions, with command/tee status `1/0`. The matching green is
`/tmp/p1f1-f1c-cleanup-green.xhjZnH`, SHA-256
`50ca0949c5c9b20c5366be5e0e60e85dabefbaf5062d6b927e09a37c551b8a2f`,
10/10 with command/tee status `0/0`.

The managed report root now walks components by descriptor, accepts only the
root-owned macOS `/var` and `/tmp` aliases whose targets are exactly
`private/<name>`, and binds ordinary directories and aliases across
`fstatat`/`openat`/`fstat` identity checks. The ENOENT branch syncs its parent
before opening the created child, so its error ownership has no leaked next
descriptor. The valid report-root red is
`/tmp/p1f1-report-root-final-red-r2.YA7R7T`, SHA-256
`23a1672f8cf72988fb9d475267f5039ba734383df9df953433fa5cd94ce9bf58`,
with 061 discovered and command/tee status `1/0`; corrected 060–061 evidence is
`/tmp/p1f1-report-root-final-green.wnKtT8`, SHA-256
`3955bc4f14a30d2ab2c47b79949bdf892f77d4fee18bbb326e97b0bf99468d5f`,
2/2 with command/tee status `0/0`.

Final corrected source/test SHA-256 values are:

- `ArtifactBlobStore.swift`: `b241637af1310346e2c403893f16af57bd684c3882f4b70d5b75d9d5d0abbb87`;
- `ArtifactBlobStoreTests.swift`: `a5d859074c1d34202bba3dab41b2328c7abc6d85fa24daaa6ee8e6c778616d40`;
- `ManagedExpeditionReportStore.swift`: `b1e69051f928ed248663ebe2f084d1ba2a7a8148d190dc6db5be16e3d4948d67`;
- `HarvestTests.swift`: `b111dfee8105359b37e1f3e350de223b874569aad5edc3e862f00404f9449427`.

The refreshed authoritative focused evidence is `focused-verify.log`, SHA-256
`c65503ff01454e9d9a2c90f555fa25110784a41bd9b1ab9d22f9a9df3b87373f`:
61 expected, 61 started, and 61 passed identities, equal sets, and command/tee
status `0/0`. The final App product build log is
`/tmp/p1f1-f1c-final-app-build.JYEs3U`, SHA-256
`1675bd6b099ad8a1a6b99d562d622fd633500066318a4abcced7695c37054f68`,
with command/tee status `0/0`. The combined static log is
`/tmp/p1f1-f1c-final-static.JuWuNb`, SHA-256
`7c66c37661bf80295b4d731d73dbdfd30a78004036586ca24f66f882358db079`;
parse and diff checks pass, and the boundary remains exactly 589 outside nodes
with manifest
`792b4de01590c9a291f0bb49092057e3fb87678d485ae29d7ba21254846f7a88`.

The independent bounded successor review is now `APPROVED — 0 P0 / 0 P1`.
The complete append-only Review02 SHA-256 is
`821b177cf50f8f0c249824eecd8fdd1c1c7db54cbe6a48bdaa664abc923c95b5`.
F1C is formally closed; F1D is the next and only open P1-F1 band.

## 2026-08-30 engineering acceptance-candidate closeout

This section records the later R9-F successor integration and delivery evidence.
It supersedes the preceding live-status sentence only; it does not rewrite the
earlier band chronology or claim formal P1-F1 acceptance.

The integrated product now contains the Engine cancellation/recovery,
descriptor authority, managed CLI policy, artifact/report, Discussion,
Attention, Growth, Application projection, and desktop coach-to-result paths
needed by the frozen user delivery boundary. Root-cause corrections were driven
by focused red/green evidence and retained fail-closed contracts. In particular,
the final CLI socket-authority regression red is
`/private/tmp/r9f-root.2U4S9d/cli-canonical-red-v152.log`, SHA-256
`20ca8f108ff47965ddbae532b174875292fe267957835808b9caf7332fa2f5f9`;
the matching green is
`/private/tmp/r9f-root.2U4S9d/cli-canonical-green-v155.log`, SHA-256
`fba465842c846cd4cf1d7b9ddc19342c674e6d3fe555501cc4ee2a5eca3fc6cf`.

Final engineering evidence:

- `verify.log` contains the complete serial full run: 1,082 tests / 31 suites
  passed in 226.512 seconds; SHA-256
  `436781a58b8916af33673ef8b807f941084f1ae65b01c362c9d13343fe76eebb`.
- `migration-matrix.log` passes SQLite 3.51/3.52 real/literal,
  replay/rollback/FK/integrity and the v17 79/208/84 checkpoint; SHA-256
  `0d2d70c0e3744d4f615acc71d170eefd775529012098c4f4c473908e0323dd24`.
- `build.log` captures release builds of `AgentLoopApp` and
  `AgentLoopBoardBridge`, codesign validation, and ZIP/DMG packaging; SHA-256
  `a07c190d6add8423ce7e392bc33383930304616eaf5c8e084542a9b25179801c`.
- `preview.log` captures the clean-machine resource simulation and isolated
  launch; SHA-256
  `774f8b5fb05c1418293a396a0667c98cfddb046400ed35d4e5fb0cff87f001aa`.
- Exact dist launch/PID evidence is
  `/private/tmp/r9f-root.2U4S9d/dist-launch-final-v160.log`, SHA-256
  `999056795e92c0e774381b714025b80319d41d14173fabade770cea270ab1cd2`.
- Final `git diff --check` and deep/strict App/helper codesign verification pass.

The packaged candidate is `Coding 牧场.app` version 1.1.0 build 128. ZIP SHA-256
is `121a636a2024086d79b0f80bf44ab978ebabbce5c3fd325a194d15546a3bcead`;
DMG SHA-256 is
`dc9b5a9cbe375c7fbe6e6dd92ea14e4832936ebc32961ec3828719547501558c`.
The package is ad-hoc signed and not notarized.

No real credential, network Provider/CLI, notification, normal user state,
commit, push, merge, release, payment, public communication, or real-user action
was used. All launch verification used isolated state and terminated only its
exact child PID.

This checkout is ready for user functional acceptance, documented in
`acceptance.md`, with one explicit formal evidence limitation: the plan-required
default-parallel unfiltered `swift run RunTests` could not be rebuilt after
repeated compiler signal-9 termination, while stale uninterruptible SwiftPM
processes retained the default build lock. The passing full run used
`--no-parallel`; it is strong engineering evidence but is not substituted for
the frozen plan's exact final command. The current Review02 also closes only
through F1C, and the complete current source/compatibility gates remain absent.
Therefore this report does not claim formal P1-F1 acceptance.
