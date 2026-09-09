# Independent text-validation amendment plan review

2026-09-06. Reviewer is separate from the amendment author and designated source writer. Scope: the complete `desktop-text-validation-amendment-plan.md`, actual five domain-source preimages, current A1/A2 authority and relevant accepted contracts. Only this report was written; no source edits, compiler/test runs, App, Provider or database actions.

## Decision

**Spec review: PASS. Quality/implementability plan review: PASS. No blocking or actionable plan findings.** Approval applies only to amendment SHA-256 `ed8fde6530bf94a1b43d931166f0ca1baf597dd2b624ad981244fe370a99327a` and its exact tests-first sequence. It permits the parent to proceed with the bounded amendment, subject to meaningful consumer RED before production repair. It does not approve a future implementation, clear its focused gate, complete A1/A2, or clear full-runtime/App/user acceptance.

The amendment correctly fixes the demonstrated cause, rather than removing formatting at the desktop edge. The capture RED already establishes LF/CRLF/TAB failure; conversion, Coach and Understanding still require their explicit independent RED cases. Tests-only preparation concurrent with this plan review does not authorize production edits early.

## Spec and source checks

1. **Text versus identity is explicit.** Master natural-language/source preservation and Coach/Understanding contracts (`2026-07-25-personal-ai-ranch-master-spec.md:369–467`) support this bounded classification. P1 stage canonical strings preserve scalars and escape TAB/LF/CR (`p1-stage-spec.md:120–140`); they do not prohibit escaped interior line breaks. Historical P1-C §5.1 requires strict identities and already-trimmed values (`p1-c-control-contracts/plan.md:579–612`). The separate text helper preserves the latter while exempting only three named control scalars. It does not permit arbitrary whitespace controls or normalize bytes. Durable cancellation reasons remain explicitly control-free (`p1-stage-spec.md:312–316`). No migration/SQL change is justified or authorized.
2. **Five-file scope matches actual failure sites.** `CanonicalContractCoding.swift:76–96` currently rejects all controls. `InputEnvelope.swift:997–1006` couples optional inlineText and payloadRef; the proposal separates only inlineText and also changes conversion rawIntent (`:836–837`). Goal construction rawIntent is at `GoalController.swift:59`. Coach prose validation is at `CoachContracts.swift:161–163,439,503–505`. Understanding’s combined loop mixes narrative entries and refs/capabilities (`UnderstandingCard.swift:36–48`); the explicit split preserves refs/capabilities and both budget map keys/values. Title, identities, operational reasons and error fields stay unchanged.
3. **The two decoder exceptions are real, narrow behavior changes.** `CoachAnswerV1` and `UnderstandingContentV1` synthesize Decodable and have invariant-safe content constructors. `CanonicalContractCodingV1.decode` proves canonical round-trip bytes, not constructor validation. Forwarding only these two decoders through their constructors closes that bypass while preserving their one-key/14-field encoded shapes. Existing `InputContractValidationV1.requireExactKeys` uses dynamic raw keys (`InputEnvelope.swift:976–985`), suitable for rejecting unknown keys rather than losing them through a closed CodingKeys container.
4. **Goal lifecycle decoding is protected.** `GoalControllerRecord` constructor requires nil currentOutcomeContractId/currentOutcomeContractVersion (`GoalController.swift:64–69`). It must not become the decoder for valid later P1-D records. The proposal explicitly preserves its synthesized decoder, creation guard and P1-D extension, and requires relevant contract-linked read regressions. This is not a general historical decoding audit.
5. **A2 authority remains bounded.** `goal-driver-plan.md` current source fact 2 describes Understanding’s synthesized decoder. Updating only that fact after verified implementation is necessary living documentation, explicitly admitted by this companion. A2’s separate strict response DTO, raw exact-key/type/size checks and explicit constructor call remain required. The amendment does not authorize its Provider, driver, budget or lifecycle changes, or a global decoder redesign.
6. **Real persistence/replay test seams exist.** InputGoalStore exposes capture (`:27`), commitParseResult (`:114`) and convertToGoal (`:552`); CoachUnderstandingStore exposes session opening (`:76`), recordQuestion (`:148`), answerQuestion (`:245`) and proposeUnderstanding (`:323`). These support isolated GRDB command-driven fixtures without production fake rows or Provider calls. Keeping all new tests/local helpers in DesktopGoalFoundationTests is feasible; no old test helpers need public exposure. A literal single-line title avoids changing label policy.

## Frozen scope and review obligations

The original A1 list has eight source paths: four new and four modified (`goal-foundation-plan.md:15–23`). The amendment adds exactly five existing domain paths: total thirteen, four new/nine modified. Its tests stay in the already-new DesktopGoalFoundationTests path. The main/A1/SDD-brief hashes remain the exact approved output-policy revision. The correct SDD path is `.superpowers/sdd/goal-foundation-plan/task-1-brief.md`; there is no task-directory `goal-foundation-sdd-brief.md`.

All five additional paths already appear individually in `DurablePlanningTests.swift:5347–5374`’s historical P1-C allowlist. This supports leaving the sentinel, frozen manifest and hashes untouched; historical membership alone did not grant amendment authority. The exact four-new-file A1 successor is still required separately. The plan appropriately preserves the original A1 diff, adds an actual-preimage five-file diff, and requires the remaining runtime-baseline hash guard. No directory exemption or disabling the guard is approved.

Implementation review must enforce the already-written plan, especially:

- independent constructor RED cases, not downstream tests masked by capture setup failure;
- canonicality proven before semantic-invalid decode rejection, exact UTF-8 assertions and fixed existing golden/hash oracles;
- direct `JSONDecoder` unknown-key checks where testing the custom decoder specifically: the canonical facade already rejects discarded extra keys by re-encoding, so that facade-only case is not new decoder RED evidence;
- real reopen/replay and changed-content conflict/no-mutation checks; unchanged strict controls, edge validation and contract-linked Goal reads;
- no constructor forwarding/defaults/normalization outside the two admitted content types, and no edits outside the enumerated production/test/A2-fact paths.

These are implementation evidence obligations, not additional plan changes or permission to expand scope.

## Before/after hash evidence

Read-only SHA-256 checks before substantive review and after inspection were identical for the amendment, five live production files, live test file, A2 plan, original main/A1 plans and DurablePlanningTests. All seven snapshot-file hashes also matched their corresponding live preimages and the saved manifest, and were unchanged on the closing check. The brief was separately checked twice and matched its prior approved hash. Test preparation had not changed the observed live test hash at the closing check; subsequent changes require implementation review.

The table records **before = after** (full SHA-256):

| Input | SHA-256 |
| --- | --- |
| Amendment plan | `ed8fde6530bf94a1b43d931166f0ca1baf597dd2b624ad981244fe370a99327a` |
| `desktop-text-validation-before.sha256` | `f131edb410420c8e1d309fb121bfc1de007a1412da8a34fc99ad38d6ccb0d73f` |
| `CanonicalContractCoding.swift` | `b15c1f9fc8d602b834eb517cefc7e27437da3d576cc4d388d9f6472032ccdcaa` |
| `InputEnvelope.swift` | `4dff9dcfa6032f1127bcfcbbd4a1d66753783c07c0c5d5f70c95460e079dd72c` |
| `GoalController.swift` | `a64fbcb55f28c03af5632e2cd89536d73a244c7cd907e7695816515b6218f1d2` |
| `CoachContracts.swift` | `0cadfc98b6e03c3d7fc0e05123643cf3044c920b312426034aa04f9683c3f133` |
| `UnderstandingCard.swift` | `e8accd2603279320014c567de1af852fb7f2efca615bfb57cf5ba8b0de35820e` |
| `DesktopGoalFoundationTests.swift` | `bc1194050e4350f7e3c6739d9b1e98c90246be5059e076892042699b44d8c0ef` |
| `goal-driver-plan.md` | `7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d` |
| `goal-flow-plan.md` | `a6166c3fb5b9622450a20d614c01dd5ea87dfbdf79ded48656c353e925a5d5c5` |
| `goal-foundation-plan.md` | `c2f0a874bdaf4bfcd1a4d31f8a31c88199d51fd1a92f0b35274a945fe893b4fc` |
| `.superpowers/sdd/goal-foundation-plan/task-1-brief.md` | `f476f42ded75f509ed677295addf5763cc9f676e3d7ad1aafa14247547b35e82` |
| `DurablePlanningTests.swift` | `56b504731d1bff1432e36c82289c1013df033d1dd383c7fc7b5318ca3e6ff06b` |

Domain filenames above mean `Sources/AgentLoopCore/Domain/`; test filenames mean `Sources/AgentLoopTestSuite/`; plan/manifest names are in this task directory. Snapshot copies reside in `desktop-text-validation-before/` and share the listed five-domain/test/A2 hashes. No claim is made here to have rehashed every runtime source: the integration packaging guard remains the parent’s separate required evidence.
