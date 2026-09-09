# A1 amendment — preserve narrative text without weakening identities

Status: proposed bounded implementation amendment; independent plan review required before production edits. This is a root-cause repair within the accepted goal/coach flow, not a new product direction. Parent owns integration and all compiler/test execution; one source writer at a time.

## Evidence and contract

`desktop-text-capture-red1.log` is a real one-test / three-issue / exit-1 run: LF, CRLF and TAB each fail the real CaptureInputCommand with `P1ContractValidationError.invalidValue`. The five earlier desktop-domain tests passed separately. Neither result is full A1 acceptance.

The main agent read `desktop-text-validation-root-cause-scope.md` and the cited master §§8–9, P1-C plan §5.1 and P1 stage canonical-string/cancellation contracts. Narrative text was incorrectly sharing a strict identity validator. Canonical JSON and existing SQLite TEXT storage support escaped interior formatting without schema changes. Stripping/replacing formatting would conceal the defect.

Keep nonempty/already-trimmed domain values. Introduce a separate validator that permits only U+0009 TAB, U+000A LF and U+000D CR as exceptions to the existing control-character predicate. It never normalizes or rewrites any scalar. All other currently rejected controls remain rejected, including VT, FF and NEL. LF/CRLF and TAB/space remain different original bytes and hashes. The desktop's one-time outer trim stays unchanged.

## Exact scope and preimages

Actual dirty preimages are `desktop-text-validation-before/` and `desktop-text-validation-before.sha256`, including these five production files, the existing new test file and A2 plan. Do not use HEAD as their preimage or overwrite that snapshot.

Exactly five additional production files under `Sources/AgentLoopCore/Domain/`:

1. `CanonicalContractCoding.swift`: add `validateNarrativeText` only. Existing validators, canonical facade and whole-command byte/hash functions remain unchanged.
2. `InputEnvelope.swift`: only inlineText in shared body validation and ConvertInputToGoalCommand.rawIntent use the new helper. Preserve XOR and payloadRef validation.
3. `GoalController.swift`: only constructor rawIntent validation. Preserve synthesized record decoding, currentOutcomeContract creation guard and the P1-D extension.
4. `CoachContracts.swift`: question record/command prompt, recommendation and explanatory reason, plus CoachAnswerV1.text use the helper. Add a narrowly scoped exact-key validating decoder for CoachAnswerV1, forwarding to its content initializer. Preserve its one-key encoded shape.
5. `UnderstandingCard.swift`: problem/scenario/targetAudience and entries of goals/nonGoals/deliverables/constraints/acceptanceCriteria/verificationPlan/assumptions/acceptedRisks use the helper. Split the combined array loop so resourceRefs and requiredCapabilities remain strict. Both budgetPolicy keys and values remain strict. Add an exact-key validating decoder only for UnderstandingContentV1, forwarding all 14 fields to its initializer; preserve current encoded shape.

All regressions go in the already new `Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift`; local private fixture helpers may reuse real existing command patterns. Do not edit old contract-test fixtures or expose their private helpers. Preserve the first five desktop tests and already observed capture regression.

Identifiers, title/display labels, camp/actor/device/worker/decision keys, payload/resource references, capability names, budget keys/values, operational cancellation reasons and error/code fields keep their strict rules. No SQL, new file, Provider, worker, AppStore, UI, InputGoalStore or CoachUnderstandingStore change is authorized by this amendment. Existing separately approved A1 store work remains separate.

### Explicit decoder and downstream-plan exception

The two content-only validating decoders are an explicit behavior amendment, not incidental cleanup. They prevent canonical decoding from bypassing content validation. Require raw exact keys through the existing helper, not enum-key enumeration that discards unknown keys. Preserve synthesized encoding and valid historical canonical goldens.

Never forward GoalControllerRecord decoding to its creation initializer: legitimate later records carry a non-nil outcome contract. A broader decoder audit is not in scope and must not be claimed.

After implementing and verifying these two decoders, update only source fact 2 in `goal-driver-plan.md` to describe the current content decoder and link this amendment. A2's separate strict adapter DTO, exact key/type/size limits, explicit constructor call and prohibition on a global historical decoder redesign remain unchanged. No other A2 scope or budget relaxation is authorized.

### Frozen gates

The original main/A1 plans and SDD brief remain byte-frozen. This companion adds exactly five existing production paths to A1's original eight-source scope: combined footprint 13 source files (four new, nine modified), not a directory-level permission. Test additions stay in one of the original four new paths.

These five existing paths are already exact P1-C historical allowlist members. Do not widen the A3 sentinel, rewrite its frozen manifest/hashes, change SQL authority, or exempt another path. The planned exact four-new-file A1 successor is still separately required when all four A1 files exist.

Review packaging must compare the five files to their actual text-amendment preimages, retain the original A1 preimage diff separately, and check all remaining runtime-baseline source hashes. Any update to the packaging guard must enumerate only the reviewed five paths and retain their reviewed hashes; never disable the guard.

## Tests first and bounded implementation sequence

1. Add direct real-constructor RED tests for conversion/Goal, Coach question/answer and Understanding. Exercise LF, CRLF, TAB and a mixed indented body independently so a capture setup failure cannot mask every consumer. Use a fixed single-line title.
2. Add positive exact-byte round trips and semantic-negative canonical-decode tests for only the two admitted content types. Establish JSON canonicality independently before asserting semantic rejection; malformed formatting alone is not evidence of validation. Include exact-key tests and representative disallowed controls.
3. Add strict-field counterexamples for every category listed above and domain edge/empty rejection. Positive text cases must assert original UTF-8, not just no-throw.
4. Add an isolated on-disk GRDB chain using real capture, exact work claim/parse commit, convert, open coach, question, answer and Understanding persistence. Reopen it, verify persisted original/prose bytes and exact replay receipt after progress. Changed interior formatting under the same identity must conflict without row/event/receipt/work mutations. No Provider, real database or fake successful domain rows.
5. Parent captures meaningful RED with frozen source hashes, complete unique log and actual exit. Then the sole writer implements exactly the five production seams and A2 source-fact update. No broad helper replacement.
6. Parent runs all text regressions, existing InputEnvelope/GoalCoach canonical/history regressions and relevant P1-D contract-linked-goal reading tests, preserving full outputs. Compare unchanged single-line golden fixture bytes/hashes, not regenerated expectations. Inspect actual preimage diff and obtain independent spec/quality review.
7. Resume remaining A1 store/read/retention checkpoints only after this amendment's focused gate clears. Run authoritative unfiltered `swift run RunTests` and strict App build on the integrated A1 revision after its exact source-inventory successor is present. Do not run a knowingly incomplete source inventory just to manufacture a failure. Packaging/live App/user acceptance remain later distinct gates.

## Done and followthrough

This amendment is complete only when real consumer and persistence/replay tests pass, strict fields/controls/edges still reject, valid wire bytes remain unchanged, and a nonimplementer approves the exact diff with no unresolved material findings. It does not complete A1, A2 or the product.

A3 title derivation must deliberately derive a single-line label without altering rawIntent; do not feed a multiline prefix to the still-strict title field. Record this followthrough, not an unapproved UI change now. New source discovery outside the enumerated scope requires another bounded review, not automatic expansion.
