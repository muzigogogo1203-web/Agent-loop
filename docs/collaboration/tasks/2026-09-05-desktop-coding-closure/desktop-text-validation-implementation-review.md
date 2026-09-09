# Independent narrative-text implementation review

2026-09-06. Responsibilities-separated reviewer; author of the earlier root-cause report, not the production/test implementer. This review read the frozen tests, complete RED/GREEN/compatibility logs, run process/hash evidence, actual-preimage production/test diff and final A2 fact-only diff. Reviewer ran only read-only source/evidence/hash checks and wrote this report; no compiler, test, App, Provider or database execution.

## Decision and exact boundary

**Spec review PASS. Code/test quality review PASS. No actionable findings or unresolved material concerns in this amendment.** The focused narrative-text repair gate is approved for final package SHA-256 `5564cd4b8125d3fec05371a35e6b22a8d0ebf6bb95fbc0a621ef4bffcf702810` (`desktop-text-validation-final.diff`) against the actual dirty preimages in `desktop-text-validation-before/`.

The change is exactly the five reviewed domain production paths, additions to the already-new DesktopGoalFoundationTests, and only source fact 2 in goal-driver-plan.md. This clears this amendment’s focused repair/review gate so the parent can resume the separately approved A1 work. It does **not** complete A1/A2, admit the exact source-inventory successor, establish an authoritative unfiltered runtime result on integrated A1, pass a strict App build on that integration, or prove packaged/live desktop/user acceptance. Those gates remain future work.

## Spec and production review

- `CanonicalContractCoding.swift:98–112` adds a distinct validator, retaining nonempty/already-trimmed requirements and the existing Foundation control predicate, with exceptions only for TAB U+0009, LF U+000A and CR U+000D. It stores/rewrites nothing. The old identity/optional validators, canonical façade and whole-command hash functions are unchanged. Other previously rejected controls remain rejected.
- `InputEnvelope.swift:837,997–1008` changes conversion rawIntent and shared inlineText validation only. Payload reference strictness, body XOR, command encoding/envelope semantics and record validation paths remain intact. `GoalController.swift:59` changes only constructor rawIntent validation. Title, actor checks, creation-only currentOutcomeContract guards, synthesized decoder and P1-D extension are unchanged.
- `CoachContracts.swift:161–163,439,513–515` changes only the admitted question prompt/recommendation/explanatory reason and answer text. The answer decoder checks raw exact keys through the existing dynamic-key helper before decoding String and calling its throwing content constructor. Its encoded shape remains one `text` key; operational reasons/errors and decision keys are not relaxed.
- `UnderstandingCard.swift:36–48,68–99` changes the three scalar and eight array narrative fields. The split loop leaves resourceRefs/requiredCapabilities strict, and both budget keys and values unchanged. Its decoder lists all 14 original fields, obtains raw exact keys through the existing helper, decodes their original types without defaults/coercion and forwards every field to the constructor. Synthesized encoding remains intact. No general record-decoder redesign occurred.
- These changes match the accepted master natural-language/source contract and the P1 canonical scalar-preservation rules cited in the approved amendment/root-cause report. There is no newline stripping, normalization, schema migration, hidden fallback, error suppression, Provider behavior or permission change.
- Final `goal-driver-plan.md` differs only in source fact 2, after the recorded Foundation GREEN: it describes the two validating content decoders and still requires A2’s separate strict DTO, keys/types/bounds, explicit constructor and no global decoder redesign. Original main/A1/SDD-brief bytes remain frozen.

## Test quality and real RED

The reviewed 735-line frozen test source is `desktop-text-consumers-red1-before.swift`, SHA-256 `821812397b50661b42e7a20c33f31d53f3716ab23c0569086d590b419f67f1ac`. The live test remained byte-identical through GREEN/compatibility/review. Relative to the text-amendment preimage, the test diff adds one import and 524 lines; no old test/helper lines are removed. The first five desktop-domain cases and previously observed capture case remain intact.

The direct tests isolate every admitted consumer instead of allowing a failing capture setup to mask all downstream coverage. They exercise LF/CRLF/TAB and a mixed indented body, compare UTF-8 arrays, preserve fixed single-line titles, and round-trip the two content types. Eleven Understanding narrative fields are exercised separately. Independently constructed JSON is canonicalized/validated before semantic-invalid decoding is asserted. Direct JSONDecoder tests isolate the new raw-key behavior from the façade’s existing canonical round-trip check. Representative NUL/VT/FF/ESC/DEL/NEL and empty/edge cases reject. Strict identities, labels, worker/decision keys, references, capabilities, budget entries, failure code/message and cancellation reason counterexamples are checked.

The legitimate activated-goal guard uses actual P1-D fixture commands to create/activate a contract and goal, successfully decodes the resulting non-nil contract membership, and separately proves the creation constructor still rejects that state. It would catch accidental decoder-to-creation-init forwarding.

`desktop-text-consumers-red1.log` and process evidence establish PID 70399, `swift run --jobs 2 RunTests --filter desktopText`, build 20.98 seconds, 9 tests/1 suite, 0.356 seconds, exit 1, no signal. The 220 issues are independently accounted for:

| RED category | Issues | Interpretation |
| --- | ---: | --- |
| Conversion/Goal | 8 | Four formatting bodies × two real constructors reject as invalidValue. |
| Coach | 28 | Four bodies × record/command three fields plus answer reject. |
| Understanding | 44 | Four bodies × eleven narrative fields reject. |
| Semantic canonical decoding | 132 | Eleven invalid strings × answer plus eleven Understanding fields incorrectly decode without errors. |
| Direct raw-key decoding | 4 | Two extra-key payloads incorrectly accepted; two missing-key payloads throw generic keyNotFound rather than the required invalidKeys. |
| Capture | 3 | Existing LF/CRLF/TAB regressions reject. |
| Full command chain | 1 | Capture entry fails; this alone does not prove later chain execution. |

Strict-field and activated-goal guard tests already PASS in RED. The source manifest/process file records 304 before/304 after-OK entries with zero mismatches: the failure did not depend on production changes during the run.

## GREEN and compatibility evidence

All commands were run by the parent. This reviewer read their full saved logs and checked process exits, hashes and source identity.

| Evidence | Result |
| --- | --- |
| `desktop-text-consumers-green1.log`, PID 70834, filter DesktopGoalFoundationTests | Build 89.30 seconds; 14 tests/1 suite PASS in 0.488 seconds; exit 0/no signal. Same frozen tests as RED. |
| `desktop-text-regression-p1c.log`, PID 71073, filter P1C | 103 tests/5 suites PASS in 4.592 seconds; exit 0/no signal. Actual suite set includes InputEnvelope, GoalCoach, DomainEvent, control migration and P1-E integration. |
| `desktop-text-regression-p1d.log`, PID 71164, filter P1DOutcomeContractTests | 18 tests/1 suite PASS in 1.830 seconds; exit 0/no signal. Includes migration history, active-contract binding and goal lifecycle. |

The GREEN real-flow case passed in 0.205 seconds. Inspection confirms it actually performs capture → claim/parse commit → conversion → session open → claim/question → answer → claim/Understanding proposal; closes and reopens the on-disk database; checks persisted original/prose UTF-8; replays all seven original receipts after progress; and compares all rows of ten relevant input/goal/coach/Understanding/work/attempt/receipt/event/outbox tables before/after. Interior-formatting changes under the same replay identities conflict, with no row drift. Invalid-control construction is also checked before mutation. This is real local domain persistence/replay evidence, not a fake successful Provider response or desktop-driver test.

The unchanged P1-C tests include the canonical golden-byte and whole-envelope hash tests, receipt/nullability and graph/replay contracts; P1-D checks include canonical contract hashes and contract-linked goals. The Foundation test also independently compares the single-line answer wire literal and all-field Understanding wire shape. No golden expectations were regenerated.

The GREEN build log retains existing warnings in EngineExecutionStoreTests/ExecutionEngineConformanceTests plus driver/linker warnings. No warning cleanup was folded into this amendment, and this review does not claim a warning-free build. Process evidence reports 304 before/304 after-OK inputs, zero mismatches, separately for GREEN, P1-C and P1-D.

## Frozen hashes and independent checks

Five live production hashes below were identical at initial released-source inspection and final review; the final diff and A2 document hashes were identical at initial final-package inspection and final review. The test retained its RED hash. Independently hashing the RED manifest with only the five explicitly admitted production paths excluded produced **299/299 unchanged inputs**, zero failures, both before and after compatibility inspection. This includes unchanged historical tests, SQL source and source sentinel; no directory-wide exclusion was used.

| Reviewed input | SHA-256 |
| --- | --- |
| CanonicalContractCoding.swift | `2714927196e80dfea4dfab516b14dceee9eaa4ababa3067f20c661b74364a89b` |
| InputEnvelope.swift | `f4a7c35f13bf61543c3ad3289189363f1a53045ae60a6a31f1a7d5b8d2c76c9c` |
| GoalController.swift | `3e4db6027c62577511816d6caac331ec705754a02ffbcd78689bea1b4cdc79b3` |
| CoachContracts.swift | `c7358b4204770ee3c1e4e9db94e548bace5163f475ec63de3bd9369d38935b5f` |
| UnderstandingCard.swift | `07df38917fea8cac73a2a066b36a3fb4ffe5ac9f0b691caef307908a4c5b85d0` |
| DesktopGoalFoundationTests.swift | `821812397b50661b42e7a20c33f31d53f3716ab23c0569086d590b419f67f1ac` |
| goal-driver-plan.md | `032ef4ff906b6acc74025ae3e2cdb9edf51c79eb44c145c0888ae13a4ae830f8` |
| Final actual-preimage package | `5564cd4b8125d3fec05371a35e6b22a8d0ebf6bb95fbc0a621ef4bffcf702810` |
| Foundation GREEN log | `02241f879703031289f4efc9bdbc27f06d11637f49929c3b93f55196fb87b713` |
| P1-C compatibility log | `aa2b183674882255bb1e5733b8f804978067a41a6cea319e0b493c982352c516` |
| P1-D compatibility log | `0063ed933422f76b18e05c1cd63353b8f60bf65ef2ff6af063c61080cb4ee964` |

The approved amendment remains `ed8fde6530bf94a1b43d931166f0ca1baf597dd2b624ad981244fe370a99327a`; main/A1/brief remain their previously approved `a6166c3f…` / `c2f0a874…` / `f476f42d…` hashes, and DurablePlanningTests remains `56b50473…`. The prior plan review records their full hashes. These production files are already individually historical P1-C allowlisted; no sentinel membership, frozen manifest/hash, SQL authority or new-path exception changed. The separately required A1 four-file successor and integrated runtime/App gates remain unclaimed.

Domain filenames mean `Sources/AgentLoopCore/Domain/`; test filenames mean `Sources/AgentLoopTestSuite/`; evidence/documents reside in this task directory. Approval is tied to these bytes. A later source change requires its own scoped evidence/review rather than inheriting this result automatically.
