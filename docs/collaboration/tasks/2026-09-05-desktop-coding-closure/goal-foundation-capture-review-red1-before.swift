import Foundation
import GRDB
import Testing
import AgentLoopCore

private let desktopGoalInputID = "10000000-0000-4000-8000-000000000001"
private let desktopGoalGoalID = "10000000-0000-4000-8000-000000000002"
private let desktopGoalSessionID = "10000000-0000-4000-8000-000000000003"
private let desktopGoalOperationID = "10000000-0000-4000-8000-000000000004"
private let desktopGoalDeviceID = "10000000-0000-4000-8000-000000000005"
private let desktopGoalProfileID = "10000000-0000-4000-8000-000000000006"

private func desktopGoalContext(
    runtime: DesktopCoachRuntimeV1 = .unconfigured,
    maximumDispatches: Int = 8
) throws -> DesktopGoalContextV1 {
    let policy = try DesktopCoachPolicyV1(maximumDispatches: maximumDispatches)
    return try DesktopGoalContextV1(
        inputId: desktopGoalInputID,
        goalId: desktopGoalGoalID,
        sessionId: desktopGoalSessionID,
        coachRuntime: runtime,
        coachPolicy: policy,
        budgetTokens: 100_000
    )
}

private let desktopTextQuestionID = "10000000-0000-4000-8000-000000000007"
private let desktopTextNextQuestionID = "10000000-0000-4000-8000-000000000008"
private let desktopTextBodies = ["first\nsecond", "first\r\nsecond", "first\tsecond", "first\r\n  second\n\tthird"]
private let desktopTextNarrativeFields = [
    "problem", "scenario", "targetAudience", "goals", "nonGoals", "deliverables",
    "constraints", "acceptanceCriteria", "verificationPlan", "assumptions", "acceptedRisks",
]

private func desktopTextGoal(_ text: String, title: String = "Single-line goal", actor: String = "user:local-owner") throws -> GoalControllerRecord {
    try GoalControllerRecord(
        id: desktopGoalGoalID, campId: "desktop-camp-a", sourceInputId: desktopGoalInputID,
        title: title, rawIntent: text, status: .clarifying,
        currentUnderstandingId: nil, currentUnderstandingVersion: nil,
        currentOutcomeContractId: nil, currentOutcomeContractVersion: nil,
        aggregateVersion: 1, createdByActorId: actor,
        createdAt: Date(timeIntervalSince1970: 130), updatedAt: Date(timeIntervalSince1970: 130)
    )
}

private func desktopTextConversion(_ text: String, title: String = "Single-line goal") throws -> ConvertInputToGoalCommandV1 {
    try ConvertInputToGoalCommandV1(
        envelope: desktopGoalEnvelope(key: "desktop-text-convert"),
        input: InputHeadV1(inputId: desktopGoalInputID, auditCampId: "desktop-camp-a", expectedInputVersion: 2),
        activeParsingBranch: .none, goalId: desktopGoalGoalID, title: title, rawIntent: text
    )
}

private func desktopTextContent(
    _ text: String,
    field: String? = nil,
    resources: [String] = ["local:artifact"],
    capabilities: [String] = ["coding"],
    budget: [String: String] = ["tokens": "10000"]
) throws -> UnderstandingContentV1 {
    func value(_ name: String) -> String { field == nil || field == name ? text : "plain" }
    return try UnderstandingContentV1(
        problem: value("problem"), scenario: value("scenario"), targetAudience: value("targetAudience"),
        goals: [value("goals")], nonGoals: [value("nonGoals")], deliverables: [value("deliverables")],
        constraints: [value("constraints")], acceptanceCriteria: [value("acceptanceCriteria")],
        verificationPlan: [value("verificationPlan")], resourceRefs: resources,
        requiredCapabilities: capabilities, budgetPolicy: budget,
        assumptions: [value("assumptions")], acceptedRisks: [value("acceptedRisks")]
    )
}

private func desktopTextContentValues(_ content: UnderstandingContentV1) -> [String] {
    [content.problem, content.scenario, content.targetAudience]
        + content.goals + content.nonGoals + content.deliverables + content.constraints
        + content.acceptanceCriteria + content.verificationPlan + content.assumptions + content.acceptedRisks
}

private func desktopTextQuestion(_ text: String, field: String) throws -> CoachQuestionRecord {
    try CoachQuestionRecord(
        id: desktopTextQuestionID, sessionId: desktopGoalSessionID,
        decisionKey: CoachTurnWorkInputV1.decisionKey(nextQuestionId: desktopTextQuestionID),
        prompt: field == "prompt" ? text : "plain",
        recommendation: field == "recommendation" ? text : "plain",
        reason: field == "reason" ? text : "plain", answer: nil, state: .open,
        createdAt: Date(timeIntervalSince1970: 160), answeredAt: nil
    )
}

private func desktopTextQuestionCommand(_ text: String, field: String, decisionKey: String = "single-line-decision") throws -> RecordCoachQuestionCommandV1 {
    try RecordCoachQuestionCommandV1(
        envelope: CommandEnvelopeV1(
            idempotencyKey: "text-question", actorType: .coach, actorId: "system:coach:v1",
            deviceId: nil, correlationId: "text-trace", causationId: nil, occurredAt: Date(timeIntervalSince1970: 150)
        ),
        goal: GoalHeadV1(goalId: desktopGoalGoalID, campId: "desktop-camp-a", expectedGoalVersion: 1),
        coach: CoachHeadV1(sessionId: desktopGoalSessionID, expectedSessionVersion: 1),
        claim: WorkClaimV1(claim: DurableWorkClaim(
            workId: desktopGoalOperationID, attempt: 1, workerId: "text-worker", version: 2,
            leaseExpiresAt: Date(timeIntervalSince1970: 210)
        )),
        decisionKey: decisionKey, prompt: field == "prompt" ? text : "plain",
        recommendation: field == "recommendation" ? text : "plain",
        reason: field == "reason" ? text : "plain"
    )
}

// Produces wire fixtures independently of the content types' Codable implementations.
// Semantic-negative tests separately assert canonicality and a specific semantic error.
private func desktopTextCanonicalFixture(_ object: [String: Any]) throws -> Data {
    let raw = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    let canonical = try CanonicalJSONV1.canonicalize(rawUTF8: raw)
    try CanonicalJSONV1.validateCanonical(rawUTF8: canonical)
    return canonical
}

private func desktopTextContentWire(_ text: String) -> [String: Any] {
    ["problem": text, "scenario": "plain", "targetAudience": "plain", "goals": ["plain"],
     "nonGoals": ["plain"], "deliverables": ["plain"], "constraints": ["plain"],
     "acceptanceCriteria": ["plain"], "verificationPlan": ["plain"],
     "resourceRefs": ["local:artifact"], "requiredCapabilities": ["coding"],
     "budgetPolicy": ["tokens": "10000"], "assumptions": ["plain"], "acceptedRisks": ["plain"]]
}

private func desktopTextDatabase() throws -> (AppDatabase, String) {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("desktop-text-\(UUID().uuidString).sqlite").path
    let database = try AppDatabase(path: path)
    try database.pool.write { db in
        try db.execute(sql: "INSERT INTO camp(id,name,archived,createdAt) VALUES ('desktop-camp-a','Text camp',0,1)")
        try CampLifecycleStore.insertInitialActive(campId: "desktop-camp-a", at: Date(timeIntervalSince1970: 1), database: db)
    }
    return (database, path)
}

private func desktopTextWorkerEnvelope(_ database: AppDatabase, claim: DurableWorkClaim) throws -> CommandEnvelopeV1 {
    try database.pool.read { db in
        let fetchedWork = try DurableWorkRecord.fetchOne(db, key: claim.workId)
        let fetchedAttempt = try DurableWorkAttemptRecord.fetchOne(db, key: ["workId": claim.workId, "attempt": claim.attempt])
        let work = try #require(fetchedWork)
        let attempt = try #require(fetchedAttempt)
        return try ControlWorkerCommandEnvelopeFactoryV1.make(work: work, attempt: attempt, claim: claim)
    }
}

private func desktopTextRows(_ database: AppDatabase) throws -> [String: [[DatabaseValue]]] {
    try database.pool.read { db in
        var result: [String: [[DatabaseValue]]] = [:]
        for table in ["input_envelope", "goal_controller", "coach_session", "coach_question",
                      "understanding_card_version", "durable_work", "durable_work_attempt",
                      "domain_command_receipt", "domain_event", "event_outbox"] {
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY rowid")
            result[table] = rows.map { Array($0.databaseValues) }
        }
        return result
    }
}

extension DesktopGoalFoundationTests {
    @Test func desktopTextConversionAndGoalPreserveInteriorFormatting() throws {
        for body in desktopTextBodies {
            #expect(throws: Never.self) {
                let command = try desktopTextConversion(body)
                #expect(Array(command.rawIntent.utf8) == Array(body.utf8))
                #expect(command.title == "Single-line goal")
            }
            #expect(throws: Never.self) {
                let goal = try desktopTextGoal(body)
                #expect(Array(goal.rawIntent.utf8) == Array(body.utf8))
                let bytes = try CanonicalContractCodingV1.encode(goal)
                let decoded = try CanonicalContractCodingV1.decode(GoalControllerRecord.self, from: bytes)
                #expect(Array(decoded.rawIntent.utf8) == Array(body.utf8))
            }
        }
    }

    @Test func desktopTextCoachRecordCommandAndAnswerPreserveFormatting() throws {
        for body in desktopTextBodies {
            for field in ["prompt", "recommendation", "reason"] {
                #expect(throws: Never.self) {
                    let question = try desktopTextQuestion(body, field: field)
                    let actual = field == "prompt" ? question.prompt : field == "recommendation" ? question.recommendation : question.reason
                    #expect(Array(actual.utf8) == Array(body.utf8))
                }
                #expect(throws: Never.self) {
                    let command = try desktopTextQuestionCommand(body, field: field)
                    let actual = field == "prompt" ? command.prompt : field == "recommendation" ? command.recommendation : command.reason
                    #expect(Array(actual.utf8) == Array(body.utf8))
                }
            }
            #expect(throws: Never.self) {
                let answer = try CoachAnswerV1(text: body)
                #expect(Array(answer.text.utf8) == Array(body.utf8))
                let bytes = try CanonicalContractCodingV1.encode(answer)
                let decoded = try CanonicalContractCodingV1.decode(CoachAnswerV1.self, from: bytes)
                #expect(Array(decoded.text.utf8) == Array(body.utf8))
            }
        }
    }

    @Test func desktopTextUnderstandingFieldsPreserveFormattingIndependently() throws {
        for body in desktopTextBodies {
            for (index, field) in desktopTextNarrativeFields.enumerated() {
                #expect(throws: Never.self) {
                    let content = try desktopTextContent(body, field: field)
                    let actual = desktopTextContentValues(content)
                    #expect(actual.count == 11)
                    #expect(Array(actual[index].utf8) == Array(body.utf8))
                    let bytes = try CanonicalContractCodingV1.encode(content)
                    let decoded = try CanonicalContractCodingV1.decode(UnderstandingContentV1.self, from: bytes)
                    #expect(decoded == content)
                    #expect(Array(desktopTextContentValues(decoded)[index].utf8) == Array(body.utf8))
                    #expect(decoded.resourceRefs == ["local:artifact"])
                    #expect(decoded.requiredCapabilities == ["coding"])
                    #expect(decoded.budgetPolicy == ["tokens": "10000"])
                }
            }
        }
    }

    @Test func desktopTextContentDecodingRejectsCanonicalInvalidControlsAndEdges() throws {
        let invalid = ["", " plain", "plain ", "\nplain", "plain\t",
                       "first\u{0000}second", "first\u{000B}second", "first\u{000C}second",
                       "first\u{001B}second", "first\u{007F}second", "first\u{0085}second"]
        for text in invalid {
            let answerBytes = try desktopTextCanonicalFixture(["text": text])
            try CanonicalJSONV1.validateCanonical(rawUTF8: answerBytes)
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try CanonicalContractCodingV1.decode(CoachAnswerV1.self, from: answerBytes)
            }
            for field in desktopTextNarrativeFields {
                var wire = desktopTextContentWire("plain")
                if ["problem", "scenario", "targetAudience"].contains(field) {
                    wire[field] = text
                } else {
                    wire[field] = [text]
                }
                let bytes = try desktopTextCanonicalFixture(wire)
                try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
                #expect(throws: P1ContractValidationError.invalidValue) {
                    _ = try CanonicalContractCodingV1.decode(UnderstandingContentV1.self, from: bytes)
                }
            }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextConversion(text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextGoal(text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try CoachAnswerV1(text: text) }
            for field in ["prompt", "recommendation", "reason"] {
                #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextQuestion(text, field: field) }
                #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextQuestionCommand(text, field: field) }
            }
        }
    }

    @Test func desktopTextContentDecodersRejectUnknownAndMissingRawKeys() throws {
        let answerShapes: [[String: Any]] = [["text": "plain", "extra": "hidden"], [:]]
        for wire in answerShapes {
            let bytes = try desktopTextCanonicalFixture(wire)
            // Direct decode isolates raw-key checking from canonical re-encoding.
            #expect(throws: P1ContractValidationError.invalidKeys) {
                _ = try JSONDecoder().decode(CoachAnswerV1.self, from: bytes)
            }
        }
        var extra = desktopTextContentWire("plain")
        extra["extra"] = "hidden"
        var missing = desktopTextContentWire("plain")
        missing.removeValue(forKey: "acceptedRisks")
        for wire in [extra, missing] {
            let bytes = try desktopTextCanonicalFixture(wire)
            #expect(throws: P1ContractValidationError.invalidKeys) {
                _ = try JSONDecoder().decode(UnderstandingContentV1.self, from: bytes)
            }
        }
        let answer = try CoachAnswerV1(text: "plain")
        let answerJSON = try CanonicalContractCodingV1.string(answer)
        #expect(answerJSON == "{\"text\":\"plain\"}")
        let content = try desktopTextContent("plain")
        let contentBytes = try CanonicalContractCodingV1.encode(content)
        let expectedBytes = try desktopTextCanonicalFixture(desktopTextContentWire("plain"))
        #expect(contentBytes == expectedBytes)
    }

    @Test func desktopTextStrictIdentityReferenceAndOperationalFieldsRemainStrict() throws {
        let (database, _) = try desktopTextDatabase()
        for text in desktopTextBodies {
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextGoal("plain", title: text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextConversion("plain", title: text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextGoal("plain", actor: text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopGoalEnvelope(key: text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopGoalEnvelope(actorId: text) }
            #expect(throws: P1ContractValidationError.invalidCampIdentifier) {
                _ = try GoalHeadV1(goalId: desktopGoalGoalID, campId: text, expectedGoalVersion: 1)
            }
            #expect(throws: P1ContractValidationError.invalidIdentifier) {
                _ = try CommandEnvelopeV1(idempotencyKey: "plain", actorType: .user, actorId: "user:local-owner", deviceId: text,
                                         correlationId: "plain", causationId: nil, occurredAt: Date(timeIntervalSince1970: 100))
            }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try WorkClaimV1(claim: DurableWorkClaim(workId: desktopGoalOperationID, attempt: 1, workerId: text,
                                                          version: 2, leaseExpiresAt: Date(timeIntervalSince1970: 200)))
            }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextQuestionCommand("plain", field: "prompt", decisionKey: text) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextContent("plain", resources: [text]) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextContent("plain", capabilities: [text]) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextContent("plain", budget: [text: "plain"]) }
            #expect(throws: P1ContractValidationError.invalidValue) { _ = try desktopTextContent("plain", budget: ["plain": text]) }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try CaptureInputCommandV1(
                    envelope: desktopGoalEnvelope(), inputId: desktopGoalInputID, auditCampId: "desktop-camp-a", initialCampId: "desktop-camp-a",
                    sourceType: .file, sourceDeviceId: desktopGoalDeviceID, connectorId: nil, authorId: nil,
                    capturedAt: Date(timeIntervalSince1970: 100), inlineText: nil, payloadRef: text,
                    contentHash: String(repeating: "a", count: 64), candidateCampIds: [], explicitIntent: .createGoal, privacyLevel: .localOnly, parentInputId: nil
                )
            }
            #expect(throws: P1ContractValidationError.invalidValue) { try CanonicalContractCodingV1.validateCode(text) }
            #expect(throws: InvalidDurableWorkFailureError.invalidCode) {
                _ = try ControlWorkerProviderFailureV1(code: text, safeMessage: "safe message", disposition: .deterministic)
            }
            #expect(throws: InvalidDurableWorkFailureError.messageContainsControlScalar) {
                _ = try ControlWorkerProviderFailureV1(code: "safe_code", safeMessage: text, disposition: .deterministic)
            }
            #expect(throws: InvalidDurableWorkCancellationReasonError.containsControlScalar) {
                _ = try DurableWorkStore(database: database).cancel(
                    workId: desktopGoalOperationID, expectedVersion: 1, reason: text,
                    now: Date(timeIntervalSince1970: 100), businessMutation: { _, _ in }
                )
            }
        }
    }

    @Test func desktopTextGoalDecodingRetainsLegitimateActivatedContractState() throws {
        let fixture = try p1dContractFixture("desktop-text-goal-decode")
        let draft = try p1dCreateDraft(fixture)
        let contract = try p1dActivateContract(fixture, draft: draft)
        let activation = try fixture.store.activateGoal(ActivateGoalCommandV1(
            envelope: p1dUserEnvelope("desktop-text-activate-goal"),
            goal: GoalHeadV1(goalId: fixture.goal.id, campId: fixture.goal.campId, expectedGoalVersion: 1),
            contract: contract.ref, missionId: fixture.mission.id, expectedLinkVersion: nil
        ))
        let bytes = try CanonicalContractCodingV1.encode(activation.goal)
        let decoded = try CanonicalContractCodingV1.decode(GoalControllerRecord.self, from: bytes)
        #expect(decoded.status == .active)
        #expect(decoded.currentOutcomeContractId == contract.ref.id)
        #expect(decoded.currentOutcomeContractVersion == contract.ref.version)
        #expect(decoded == activation.goal)
        #expect(throws: P1ContractValidationError.invalidMembership) {
            _ = try GoalControllerRecord(
                id: decoded.id, campId: decoded.campId, sourceInputId: decoded.sourceInputId,
                title: decoded.title, rawIntent: decoded.rawIntent, status: decoded.status,
                currentUnderstandingId: decoded.currentUnderstandingId,
                currentUnderstandingVersion: decoded.currentUnderstandingVersion,
                currentOutcomeContractId: decoded.currentOutcomeContractId,
                currentOutcomeContractVersion: decoded.currentOutcomeContractVersion,
                aggregateVersion: decoded.aggregateVersion, createdByActorId: decoded.createdByActorId,
                createdAt: decoded.createdAt, updatedAt: decoded.updatedAt
            )
        }
    }

    @Test func desktopTextRealFlowPersistsAndReplaysWithoutFormattingDrift() throws {
        let (database, path) = try desktopTextDatabase()
        let inputStore = InputGoalStore(database: database)
        let coachStore = CoachUnderstandingStore(database: database)
        let workStore = DurableWorkStore(database: database)
        let body = "first\r\n  second\n\tthird"
        let context = try desktopGoalContext()
        let captureEnvelope = try desktopGoalEnvelope()
        let intent = try desktopGoalIntent(text: body, context: context, envelope: captureEnvelope)
        let capture = try intent.captureCommand()
        let captureReceipt = try inputStore.captureAndEnqueueParsing(capture)
        let capturedInputValue = try inputStore.input(id: desktopGoalInputID)
        let capturedInput = try #require(capturedInputValue)
        let parsingWorkValue = try workStore.activeWork(kind: .inputParsing, aggregateType: "input", aggregateId: desktopGoalInputID)
        let parsingWork = try #require(parsingWorkValue)
        let parseClaim = try workStore.claim(workId: parsingWork.id, workerId: "desktop-parser", now: Date(timeIntervalSince1970: 110), leaseDuration: 60)
        let parseEnvelope = try desktopTextWorkerEnvelope(database, claim: parseClaim)
        let parse = try CommitInputParseResultCommandV1(
            envelope: parseEnvelope,
            input: InputHeadV1(inputId: capturedInput.id, auditCampId: "desktop-camp-a", expectedInputVersion: capturedInput.aggregateVersion),
            claim: WorkClaimV1(claim: parseClaim),
            result: InputParseResultV1(route: .coaching, candidateCampIds: [], assignedCampId: "desktop-camp-a")
        )
        let parseReceipt = try inputStore.commitParseResult(parse, terminalNow: Date(timeIntervalSince1970: 120))
        let parsedInputValue = try inputStore.input(id: desktopGoalInputID)
        let parsedInput = try #require(parsedInputValue)
        let convert = try ConvertInputToGoalCommandV1(
            envelope: desktopTextUserEnvelope("desktop-text-convert-flow", at: 130),
            input: InputHeadV1(inputId: parsedInput.id, auditCampId: "desktop-camp-a", expectedInputVersion: parsedInput.aggregateVersion),
            activeParsingBranch: .none, goalId: desktopGoalGoalID, title: "Single-line goal", rawIntent: body
        )
        let convertReceipt = try inputStore.convertToGoal(convert)
        let goalValue = try coachStore.goal(id: desktopGoalGoalID)
        let goal = try #require(goalValue)
        let goalHead = try GoalHeadV1(goalId: goal.id, campId: goal.campId, expectedGoalVersion: goal.aggregateVersion)
        let open = try OpenCoachSessionCommandV1(
            envelope: desktopTextUserEnvelope("desktop-text-open", at: 140), goal: goalHead,
            sourceInputId: desktopGoalInputID, sessionId: desktopGoalSessionID, nextQuestionId: desktopTextQuestionID
        )
        let openReceipt = try coachStore.openCoachSession(open)
        let sessionValue = try coachStore.session(id: desktopGoalSessionID)
        let session = try #require(sessionValue)
        let coachWorkValue = try workStore.activeWork(kind: .coach, aggregateType: "goal", aggregateId: desktopGoalGoalID)
        let coachWork = try #require(coachWorkValue)
        let questionClaim = try workStore.claim(workId: coachWork.id, workerId: "desktop-coach", now: Date(timeIntervalSince1970: 150), leaseDuration: 60)
        let questionEnvelope = try desktopTextWorkerEnvelope(database, claim: questionClaim)
        let question = try RecordCoachQuestionCommandV1(
            envelope: questionEnvelope, goal: goalHead,
            coach: CoachHeadV1(sessionId: session.id, expectedSessionVersion: session.aggregateVersion),
            claim: WorkClaimV1(claim: questionClaim), decisionKey: CoachTurnWorkInputV1.decisionKey(nextQuestionId: desktopTextQuestionID),
            prompt: "first\nsecond", recommendation: "first\r\nsecond", reason: "first\tsecond"
        )
        let questionReceipt = try coachStore.recordQuestion(question, terminalNow: Date(timeIntervalSince1970: 160))
        let waitingValue = try coachStore.session(id: desktopGoalSessionID)
        let waiting = try #require(waitingValue)
        let answer = try AnswerCoachQuestionCommandV1(
            envelope: desktopTextUserEnvelope("desktop-text-answer", at: 170), goal: goalHead,
            coach: CoachHeadV1(sessionId: waiting.id, expectedSessionVersion: waiting.aggregateVersion),
            currentQuestionId: desktopTextQuestionID, answer: CoachAnswerV1(text: body),
            nextQuestionId: desktopTextNextQuestionID, expectedUnderstandingEventVersion: 0
        )
        let answerReceipt = try coachStore.answerQuestion(answer)
        let interviewingValue = try coachStore.session(id: desktopGoalSessionID)
        let interviewing = try #require(interviewingValue)
        let proposalWorkValue = try workStore.activeWork(kind: .coach, aggregateType: "goal", aggregateId: desktopGoalGoalID)
        let proposalWork = try #require(proposalWorkValue)
        let proposalClaim = try workStore.claim(workId: proposalWork.id, workerId: "desktop-coach", now: Date(timeIntervalSince1970: 180), leaseDuration: 60)
        let proposalEnvelope = try desktopTextWorkerEnvelope(database, claim: proposalClaim)
        let proposal = try ProposeUnderstandingCommandV1(
            envelope: proposalEnvelope, goal: goalHead,
            coach: CoachHeadV1(sessionId: interviewing.id, expectedSessionVersion: interviewing.aggregateVersion),
            claim: WorkClaimV1(claim: proposalClaim), expectedUnderstandingEventVersion: 0, content: desktopTextContent(body)
        )
        let proposalReceipt = try coachStore.proposeUnderstanding(proposal, terminalNow: Date(timeIntervalSince1970: 190))
        let beforeRestart = try desktopTextRows(database)
        try database.pool.close()

        let reopened = try AppDatabase(path: path)
        let reopenedInputStore = InputGoalStore(database: reopened)
        let reopenedCoachStore = CoachUnderstandingStore(database: reopened)
        let reopenedRows = try desktopTextRows(reopened)
        #expect(reopenedRows == beforeRestart)
        let storedInputValue = try reopenedInputStore.input(id: desktopGoalInputID)
        let storedGoalValue = try reopenedCoachStore.goal(id: desktopGoalGoalID)
        let storedQuestionValue = try reopenedCoachStore.question(id: desktopTextQuestionID)
        let storedUnderstandingValue = try reopenedCoachStore.understanding(id: desktopGoalGoalID, version: 1)
        let storedInput = try #require(storedInputValue)
        let storedGoal = try #require(storedGoalValue)
        let storedQuestion = try #require(storedQuestionValue)
        let storedUnderstanding = try #require(storedUnderstandingValue)
        let storedInline = try #require(storedInput.inlineText)
        let storedAnswer = try #require(storedQuestion.answer)
        #expect(Array(storedInline.utf8) == Array(body.utf8))
        #expect(storedInput.status == .goalCreated)
        #expect(Array(storedGoal.rawIntent.utf8) == Array(body.utf8))
        #expect(Array(storedQuestion.prompt.utf8) == Array("first\nsecond".utf8))
        #expect(Array(storedQuestion.recommendation.utf8) == Array("first\r\nsecond".utf8))
        #expect(Array(storedQuestion.reason.utf8) == Array("first\tsecond".utf8))
        #expect(Array(storedAnswer.text.utf8) == Array(body.utf8))
        for value in desktopTextContentValues(storedUnderstanding.content) {
            #expect(Array(value.utf8) == Array(body.utf8))
        }
        let replayed = [
            try reopenedInputStore.captureAndEnqueueParsing(capture),
            try reopenedInputStore.commitParseResult(parse, terminalNow: Date(timeIntervalSince1970: 120)),
            try reopenedInputStore.convertToGoal(convert),
            try reopenedCoachStore.openCoachSession(open),
            try reopenedCoachStore.recordQuestion(question, terminalNow: Date(timeIntervalSince1970: 160)),
            try reopenedCoachStore.answerQuestion(answer),
            try reopenedCoachStore.proposeUnderstanding(proposal, terminalNow: Date(timeIntervalSince1970: 190)),
        ]
        #expect(replayed == [captureReceipt, parseReceipt, convertReceipt, openReceipt, questionReceipt, answerReceipt, proposalReceipt])
        let afterReplay = try desktopTextRows(reopened)
        #expect(afterReplay == beforeRestart)

        for invalidText in ["first\u{0000}second", "first\u{000B}second", "first\u{000C}second",
                            "first\u{001B}second", "first\u{007F}second", "first\u{0085}second"] {
            let beforeInvalid = try desktopTextRows(reopened)
            #expect(throws: P1ContractValidationError.invalidValue) {
                let invalidIntent = try desktopGoalIntent(text: invalidText, context: context, envelope: captureEnvelope)
                _ = try reopenedInputStore.captureAndEnqueueParsing(invalidIntent.captureCommand())
            }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try reopenedInputStore.convertToGoal(ConvertInputToGoalCommandV1(
                    envelope: convert.envelope, input: convert.input, activeParsingBranch: .none,
                    goalId: convert.goalId, title: convert.title, rawIntent: invalidText
                ))
            }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try reopenedCoachStore.recordQuestion(RecordCoachQuestionCommandV1(
                    envelope: question.envelope, goal: question.goal, coach: question.coach, claim: question.claim,
                    decisionKey: question.decisionKey, prompt: invalidText, recommendation: question.recommendation, reason: question.reason
                ), terminalNow: Date(timeIntervalSince1970: 160))
            }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try reopenedCoachStore.answerQuestion(AnswerCoachQuestionCommandV1(
                    envelope: answer.envelope, goal: answer.goal, coach: answer.coach,
                    currentQuestionId: answer.currentQuestionId, answer: CoachAnswerV1(text: invalidText),
                    nextQuestionId: answer.nextQuestionId, expectedUnderstandingEventVersion: 0
                ))
            }
            #expect(throws: P1ContractValidationError.invalidValue) {
                _ = try reopenedCoachStore.proposeUnderstanding(ProposeUnderstandingCommandV1(
                    envelope: proposal.envelope, goal: proposal.goal, coach: proposal.coach, claim: proposal.claim,
                    expectedUnderstandingEventVersion: 0, content: desktopTextContent(invalidText)
                ), terminalNow: Date(timeIntervalSince1970: 190))
            }
            let afterInvalid = try desktopTextRows(reopened)
            #expect(afterInvalid == beforeInvalid)
        }

        let changedText = "first\n  second\n\tthird"
        let changedIntent = try desktopGoalIntent(text: changedText, context: context, envelope: captureEnvelope)
        let changedCapture = try changedIntent.captureCommand()
        #expect(changedCapture.contentHash != capture.contentHash)
        #expect(throws: DomainCommandReplayConflictError.self) { _ = try reopenedInputStore.captureAndEnqueueParsing(changedCapture) }
        let changedConvert = try ConvertInputToGoalCommandV1(
            envelope: convert.envelope, input: convert.input, activeParsingBranch: .none,
            goalId: convert.goalId, title: convert.title, rawIntent: changedText
        )
        #expect(throws: DomainCommandReplayConflictError.self) { _ = try reopenedInputStore.convertToGoal(changedConvert) }
        let changedQuestion = try RecordCoachQuestionCommandV1(
            envelope: question.envelope, goal: question.goal, coach: question.coach, claim: question.claim,
            decisionKey: question.decisionKey, prompt: "first\r\nsecond", recommendation: question.recommendation, reason: question.reason
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try reopenedCoachStore.recordQuestion(changedQuestion, terminalNow: Date(timeIntervalSince1970: 160))
        }
        let changedAnswer = try AnswerCoachQuestionCommandV1(
            envelope: answer.envelope, goal: answer.goal, coach: answer.coach,
            currentQuestionId: answer.currentQuestionId, answer: CoachAnswerV1(text: changedText),
            nextQuestionId: answer.nextQuestionId, expectedUnderstandingEventVersion: 0
        )
        #expect(throws: DomainCommandReplayConflictError.self) { _ = try reopenedCoachStore.answerQuestion(changedAnswer) }
        let changedProposal = try ProposeUnderstandingCommandV1(
            envelope: proposal.envelope, goal: proposal.goal, coach: proposal.coach, claim: proposal.claim,
            expectedUnderstandingEventVersion: 0, content: desktopTextContent(changedText)
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try reopenedCoachStore.proposeUnderstanding(changedProposal, terminalNow: Date(timeIntervalSince1970: 190))
        }
        let afterConflicts = try desktopTextRows(reopened)
        #expect(afterConflicts == beforeRestart)
    }
}

private func desktopTextUserEnvelope(_ key: String, at: TimeInterval) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key, actorType: .user, actorId: "user:local-owner", deviceId: desktopGoalDeviceID,
        correlationId: "desktop-text-flow", causationId: nil, occurredAt: Date(timeIntervalSince1970: at)
    )
}

private func desktopGoalEnvelope(
    key: String = "desktop-goal:10000000-0000-4000-8000-000000000004:capture:v1",
    actorId: String = "user:local-owner"
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .user,
        actorId: actorId,
        deviceId: desktopGoalDeviceID,
        correlationId: "desktop-goal-test",
        causationId: nil,
        occurredAt: Date(timeIntervalSince1970: 100)
    )
}

private func desktopGoalIntent(
    text: String = "hello",
    context: DesktopGoalContextV1,
    envelope: CommandEnvelopeV1
) throws -> DesktopGoalCaptureIntentV1 {
    try DesktopGoalCaptureIntentV1(
        operationId: desktopGoalOperationID,
        campId: "desktop-camp-a",
        expectedCampLifecycleVersion: 1,
        context: context,
        originalText: text,
        envelope: envelope
    )
}

@Suite(.serialized)
struct DesktopGoalFoundationTests {
    // Catches synthesized enum encoding, omitted policy, or rejection of valid V1.
    @Test func desktopDomainOutputPolicyHasExactCanonicalWireShape() throws {
        #expect(throws: Never.self) {
            let policy = DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4_096)
            let encoded = try CanonicalContractCodingV1.string(policy)
            #expect(encoded == "{\"apiRequestedTokens\":4096,\"kind\":\"providerAware\"}")
            let decoded = try CanonicalContractCodingV1.decode(
                DesktopCoachOutputPolicyV1.self,
                from: Data("{\"apiRequestedTokens\":4096,\"kind\":\"providerAware\"}".utf8)
            )
            #expect(decoded == .providerAware(apiRequestedTokens: 4_096))
        }
    }

    // Catches lost runtime selection, policy limits, explicit nil fields and hash drift.
    @Test func desktopDomainContextBindsPolicyAndUnresolvedRuntime() throws {
        #expect(throws: Never.self) {
            for runtime in [DesktopCoachRuntimeV1.unconfigured,
                            .selected(profileId: desktopGoalProfileID, model: "unresolved-model")] {
                let context = try desktopGoalContext(runtime: runtime)
                let bytes = try CanonicalContractCodingV1.encode(context)
                let object = try JSONSerialization.jsonObject(with: bytes)
                let dictionary = try #require(object as? [String: Any])
                let coach = try #require(dictionary["coachPolicy"] as? [String: Any])
                let policy = try #require(coach["outputPolicy"] as? [String: Any])
                #expect(Set(policy.keys) == Set(["apiRequestedTokens", "kind"]))
                #expect(policy["kind"] as? String == "providerAware")
                #expect(policy["apiRequestedTokens"] as? Int == 4_096)
                #expect(coach["maximumDispatches"] as? Int == 8)
                #expect(coach["reportedTokenStopThreshold"] as? Int == 32_768)
                #expect(coach["maximumRequestUTF8Bytes"] as? Int == 49_152)
                #expect(coach["timeoutSeconds"] as? Int == 120)
                #expect(dictionary["remoteConsentReceiptId"] is NSNull)
                #expect(dictionary["workspacePath"] is NSNull)
                #expect(dictionary["workspaceBookmark"] is NSNull)
                let decoded = try CanonicalContractCodingV1.decode(DesktopGoalContextV1.self, from: bytes)
                #expect(decoded == context)
                #expect(decoded.coachRuntime == runtime)
                let changed = try desktopGoalContext(runtime: runtime, maximumDispatches: 7)
                let originalHash = try CanonicalContractCodingV1.hash(context)
                let changedHash = try CanonicalContractCodingV1.hash(changed)
                #expect(originalHash != changedHash)
                let envelope = try desktopGoalEnvelope()
                let originalIntent = try desktopGoalIntent(context: context, envelope: envelope)
                let changedIntent = try desktopGoalIntent(context: changed, envelope: envelope)
                let originalIntentHash = try CanonicalContractCodingV1.hash(originalIntent)
                let changedIntentHash = try CanonicalContractCodingV1.hash(changedIntent)
                #expect(originalIntentHash != changedIntentHash)
            }
        }
    }

    // Catches trimming/replacing interior text, generated identities and incorrect capture ownership.
    @Test func desktopDomainCaptureIntentSealsNormalizedCallerOwnedCommand() throws {
        #expect(throws: Never.self) {
            let context = try desktopGoalContext()
            let envelope = try desktopGoalEnvelope()
            let intent = try desktopGoalIntent(text: " \nhello\t ", context: context, envelope: envelope)
            #expect(intent.originalText == "hello")
            let command = try intent.captureCommand()
            #expect(command.inputId == desktopGoalInputID)
            #expect(command.auditCampId == "desktop-camp-a")
            #expect(command.initialCampId == "desktop-camp-a")
            #expect(command.sourceType == .text)
            #expect(command.sourceDeviceId == desktopGoalDeviceID)
            #expect(command.connectorId == nil)
            #expect(command.authorId == nil)
            #expect(command.payloadRef == nil)
            #expect(command.parentInputId == nil)
            #expect(command.candidateCampIds.isEmpty)
            #expect(command.explicitIntent == .createGoal)
            #expect(command.privacyLevel == .localOnly)
            #expect(command.inlineText == "hello")
            #expect(command.capturedAt == Date(timeIntervalSince1970: 100))
            #expect(command.contentHash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
            #expect(command.envelope == envelope)
            let bytes = try CanonicalContractCodingV1.encode(intent)
            let decoded = try CanonicalContractCodingV1.decode(DesktopGoalCaptureIntentV1.self, from: bytes)
            let replayCommand = try decoded.captureCommand()
            let commandBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: command.envelope, payload: command)
            let replayBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: replayCommand.envelope, payload: replayCommand)
            #expect(decoded == intent)
            #expect(commandBytes == replayBytes)
            let spaced = try desktopGoalIntent(text: "  hello  world  ", context: context, envelope: envelope)
            #expect(spaced.originalText == "hello  world")
        }
    }

    // Catches permissive decoding that discards extra keys or accepts a legacy cap.
    @Test func desktopDomainOutputPolicyRejectsUnsupportedWirePayloads() throws {
        let unsupported = [
            "{}",
            "{\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4096}",
            "{\"apiRequestedTokens\":4096,\"extra\":true,\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4096,\"kind\":\"fixed\"}",
            "{\"apiRequestedTokens\":\"4096\",\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":true,\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4095,\"kind\":\"providerAware\"}",
            "{\"kind\":\"providerAware\",\"maximumOutputTokens\":4096}",
        ]
        for json in unsupported {
            #expect(throws: (any Error).self) {
                _ = try CanonicalContractCodingV1.decode(DesktopCoachOutputPolicyV1.self, from: Data(json.utf8))
            }
        }
    }

    // Catches wrong gesture key, non-owner submission and an empty normalized gesture.
    @Test func desktopDomainCaptureIntentRejectsWrongIdentityAndEmptyText() throws {
        let context = try desktopGoalContext()
        let envelope = try desktopGoalEnvelope()
        let wrongKey = try desktopGoalEnvelope(key: "different-key")
        let wrongOwner = try desktopGoalEnvelope(actorId: "user:someone-else")
        for candidate in [wrongKey, wrongOwner] {
            #expect(throws: DesktopGoalFoundationErrorV1.invalidIntent) {
                _ = try desktopGoalIntent(context: context, envelope: candidate)
            }
        }
        #expect(throws: DesktopGoalFoundationErrorV1.invalidIntent) {
            _ = try desktopGoalIntent(text: " \n\t ", context: context, envelope: envelope)
        }
    }

    // Catches the identifier validator incorrectly rejecting ordinary text formatting.
    @Test func desktopTextCapturePreservesInteriorFormatting() throws {
        let cases: [(text: String, sha256: String)] = [
            ("first\nsecond", "4252f8d56b4bb236d0b1bc95a1202e392ca84ce0644bf628398fbb9517287da8"),
            ("first\r\nsecond", "d930e679a8ca94308fb7400eea7b82500cc7ea08eff0c1484e065e4a5f6145d0"),
            ("first\tsecond", "8718839ad8d16514fe1c77498f204280c1c5c4d6d669ea746816c35b6301f5e4"),
        ]
        let context = try desktopGoalContext()
        let envelope = try desktopGoalEnvelope()
        for item in cases {
            let intent = try desktopGoalIntent(text: item.text, context: context, envelope: envelope)
            #expect(Array(intent.originalText.utf8) == Array(item.text.utf8))
            #expect(throws: Never.self) {
                let command = try intent.captureCommand()
                let inlineText = try #require(command.inlineText)
                #expect(Array(inlineText.utf8) == Array(item.text.utf8))
                #expect(command.contentHash == item.sha256)
                #expect(command.inputId == desktopGoalInputID)
                #expect(command.sourceType == .text)
                #expect(command.sourceDeviceId == desktopGoalDeviceID)
                #expect(command.auditCampId == "desktop-camp-a")
                #expect(command.initialCampId == "desktop-camp-a")
                #expect(command.explicitIntent == .createGoal)
                #expect(command.envelope == envelope)
            }
        }
    }
}

private func desktopCaptureIntent(
    inputId: String = desktopGoalInputID, goalId: String = desktopGoalGoalID,
    sessionId: String = desktopGoalSessionID, operationId: String = desktopGoalOperationID,
    campId: String = "desktop-camp-a", deviceId: String = desktopGoalDeviceID,
    at: TimeInterval = 100, text: String = "hello", runtime: DesktopCoachRuntimeV1 = .unconfigured,
    maximumDispatches: Int = 8
) throws -> DesktopGoalCaptureIntentV1 {
    let context = try DesktopGoalContextV1(
        inputId: inputId, goalId: goalId, sessionId: sessionId, coachRuntime: runtime,
        coachPolicy: DesktopCoachPolicyV1(maximumDispatches: maximumDispatches), budgetTokens: 100_000
    )
    let envelope = try CommandEnvelopeV1(
        idempotencyKey: "desktop-goal:\(operationId):capture:v1", actorType: .user,
        actorId: "user:local-owner", deviceId: deviceId, correlationId: "desktop-capture-test",
        causationId: nil, occurredAt: Date(timeIntervalSince1970: at)
    )
    return try DesktopGoalCaptureIntentV1(
        operationId: operationId, campId: campId, expectedCampLifecycleVersion: 1,
        context: context, originalText: text, envelope: envelope
    )
}

private func desktopCaptureSecondIntent(sessionId: String = "20000000-0000-4000-8000-000000000003") throws -> DesktopGoalCaptureIntentV1 {
    try desktopCaptureIntent(
        inputId: "20000000-0000-4000-8000-000000000001", goalId: "20000000-0000-4000-8000-000000000002",
        sessionId: sessionId, operationId: "20000000-0000-4000-8000-000000000004", text: "existing second input"
    )
}

private struct DesktopCaptureSQLSnapshot: Equatable {
    let rows: [String: [[DatabaseValue]]]
    let counts: [String: Int]
    let rowHashes: [String: String]
}

private func desktopCaptureSQLSnapshot(_ database: AppDatabase) throws -> DesktopCaptureSQLSnapshot {
    try database.pool.read { db in
        var rows: [String: [[DatabaseValue]]] = [:]
        var counts: [String: Int] = [:]
        var hashes: [String: String] = [:]
        for table in ["desktop_goal_context", "desktop_goal_operation", "input_envelope", "durable_work",
                      "durable_work_attempt", "domain_event", "event_outbox", "domain_command_receipt",
                      "goal_controller", "coach_session", "mission", "outcome"] {
            let fetched = try Row.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY rowid")
            rows[table] = fetched.map { Array($0.databaseValues) }
            counts[table] = fetched.count
            let printable = fetched.map { row in row.map { "\($0.0)=\($0.1)" } }
            hashes[table] = try CanonicalContractCodingV1.hash(printable)
        }
        return DesktopCaptureSQLSnapshot(rows: rows, counts: counts, rowHashes: hashes)
    }
}

private func desktopCaptureOperationRow(_ database: AppDatabase, operationId: String = desktopGoalOperationID) throws -> Row {
    try database.pool.read { db in
        let row = try Row.fetchOne(db, sql: "SELECT * FROM desktop_goal_operation WHERE id=?", arguments: [operationId])
        return try #require(row)
    }
}

private func desktopCaptureStageWire(_ intent: DesktopGoalCaptureIntentV1, receipt: InputCaptureReceiptV1? = nil) throws -> [String: Any] {
    let command = try intent.captureCommand()
    let commandBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: intent.envelope, payload: command)
    let envelopeBytes = try CanonicalContractCodingV1.encode(intent.envelope)
    let envelopeObject = try JSONSerialization.jsonObject(with: envelopeBytes)
    var result: [String: Any] = [
        "ordinal": 0, "commandType": "inputCapture", "commandBytes": commandBytes.base64EncodedString(),
        "commandHash": CanonicalJSONV1.sha256Hex(commandBytes), "envelope": envelopeObject,
        "predecessorReceiptHash": NSNull(), "receipt": NSNull(),
    ]
    if let receipt {
        let bytes = try CanonicalContractCodingV1.encode(receipt)
        let inputId = try #require(receipt.refs.first(where: { $0.kind == .input })?.id)
        let workId = try #require(receipt.refs.first(where: { $0.kind == .durableWork })?.id)
        let inputVersion = try #require(receipt.versions.first(where: { $0.kind == .inputProjection })?.value)
        let workVersion = try #require(receipt.versions.first(where: { $0.kind == .durableWork })?.value)
        result["receipt"] = ["receiptBytes": bytes.base64EncodedString(), "receiptHash": CanonicalJSONV1.sha256Hex(bytes),
                             "inputId": inputId, "inputVersion": inputVersion, "workId": workId, "workVersion": workVersion]
    }
    return result
}

// Truthful setup for independently exercising seal/append: existing InputGoalStore
// commits the domain effects; these local carrier rows describe that actual command.
// They do not claim that the new store has executed any behavior successfully.
private func desktopCaptureInsertPreparedFixture(
    _ database: AppDatabase, intent: DesktopGoalCaptureIntentV1,
    sealed: Bool, receipt: InputCaptureReceiptV1? = nil
) throws {
    let contextJSON = try CanonicalContractCodingV1.string(intent.context)
    let requestJSON = try CanonicalContractCodingV1.string(intent)
    let stages: [[String: Any]] = sealed ? [try desktopCaptureStageWire(intent, receipt: receipt)] : []
    let resultBytes = try CanonicalJSONV1.canonicalize(rawUTF8: JSONSerialization.data(withJSONObject: stages, options: [.sortedKeys, .withoutEscapingSlashes]))
    var safeJSON: String?
    if let receipt {
        let receiptObject = try JSONSerialization.jsonObject(with: CanonicalContractCodingV1.encode(receipt))
        let safeBytes = try desktopTextCanonicalFixture([
            "inputId": intent.context.inputId, "goalId": intent.context.goalId, "sessionId": intent.context.sessionId,
            "operationId": intent.operationId, "captureReceipt": receiptObject,
        ])
        safeJSON = String(decoding: safeBytes, as: UTF8.self)
    }
    try database.pool.write { db in
        try db.execute(sql: """
            INSERT INTO desktop_goal_context(inputId,goalId,campId,version,contextJson,contextHash,retentionState,createdAt,updatedAt)
            VALUES (?,?,?,1,?,?,'live',?,?)
            """, arguments: [intent.context.inputId, intent.context.goalId, intent.campId, contextJSON,
                               CanonicalJSONV1.sha256Hex(Data(contextJSON.utf8)), intent.envelope.occurredAt, intent.envelope.occurredAt])
        try db.execute(sql: """
            INSERT INTO desktop_goal_operation(id,inputId,kind,ownerKind,version,requestJson,requestHash,phase,resultJson,safeReceiptJson,safeErrorCode,createdAt,updatedAt)
            VALUES (?,?,'submit','userMutation',?,?,?,'prepared',?,?,NULL,?,?)
            """, arguments: [intent.operationId, intent.context.inputId, receipt != nil ? 3 : sealed ? 2 : 1, requestJSON,
                               CanonicalJSONV1.sha256Hex(Data(requestJSON.utf8)), String(decoding: resultBytes, as: UTF8.self), safeJSON,
                               intent.envelope.occurredAt, intent.envelope.occurredAt])
    }
}

private func desktopCaptureParseActual(_ database: AppDatabase, intent: DesktopGoalCaptureIntentV1) throws {
    let inputStore = InputGoalStore(database: database)
    let fetchedInput = try inputStore.input(id: intent.context.inputId)
    let input = try #require(fetchedInput)
    let workStore = DurableWorkStore(database: database)
    let fetchedWork = try workStore.activeWork(kind: .inputParsing, aggregateType: "input", aggregateId: input.id)
    let work = try #require(fetchedWork)
    let claim = try workStore.claim(workId: work.id, workerId: "desktop-capture-parser", now: Date(timeIntervalSince1970: 110), leaseDuration: 60)
    let envelope = try desktopTextWorkerEnvelope(database, claim: claim)
    let command = try CommitInputParseResultCommandV1(
        envelope: envelope, input: InputHeadV1(inputId: input.id, auditCampId: intent.campId, expectedInputVersion: input.aggregateVersion),
        claim: WorkClaimV1(claim: claim), result: InputParseResultV1(route: .coaching, candidateCampIds: [], assignedCampId: intent.campId)
    )
    _ = try inputStore.commitParseResult(command, terminalNow: Date(timeIntervalSince1970: 120))
}

extension DesktopGoalFoundationTests {
    @Test func atomicCaptureCreatesActualInputWorkAndPreparedSubmission() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        #expect(throws: Never.self) {
            let result = try DesktopGoalWorkflowStore(database: database).prepareSubmission(intent)
            #expect(result.inputId == desktopGoalInputID)
            #expect(result.goalId == desktopGoalGoalID)
            #expect(result.sessionId == desktopGoalSessionID)
            #expect(result.operationId == desktopGoalOperationID)
            let snapshot = try desktopCaptureSQLSnapshot(database)
            for table in ["desktop_goal_context", "desktop_goal_operation", "input_envelope", "durable_work",
                          "domain_command_receipt", "domain_event", "event_outbox"] {
                #expect(snapshot.counts[table] == 1)
            }
            for table in ["goal_controller", "coach_session", "mission", "outcome", "durable_work_attempt"] {
                #expect(snapshot.counts[table] == 0)
            }
            let inputValue = try InputGoalStore(database: database).input(id: desktopGoalInputID)
            let input = try #require(inputValue)
            #expect(input.status == .captured)
            #expect(input.inlineText == "hello")
            #expect(input.explicitIntent == .createGoal)
            let workValue = try DurableWorkStore(database: database).activeWork(kind: .inputParsing, aggregateType: "input", aggregateId: desktopGoalInputID)
            let work = try #require(workValue)
            #expect(work.state == .queued)
            #expect(work.attempt == 0)
            #expect(work.campId == "desktop-camp-a")
            let row = try desktopCaptureOperationRow(database)
            let phase: String = row["phase"]
            let owner: String = row["ownerKind"]
            let kind: String = row["kind"]
            let version: Int = row["version"]
            #expect(phase == "prepared")
            #expect(owner == "userMutation")
            #expect(kind == "submit")
            #expect(version == 3)
            let stageJSON: String = row["resultJson"]
            let stages = try CanonicalContractCodingV1.decode([DesktopGoalSealedStageV1].self, from: Data(stageJSON.utf8))
            #expect(stages.count == 1)
            let stage = try #require(stages.first)
            let receipt = try #require(stage.receipt)
            #expect(stage.ordinal == 0)
            #expect(stage.commandType == .inputCapture)
            #expect(stage.predecessorReceiptHash == nil)
            #expect(stage.envelope == intent.envelope)
            #expect(receipt.inputId == input.id)
            #expect(receipt.inputVersion == 1)
            #expect(receipt.workId == work.id)
            #expect(receipt.workVersion == 1)
            let command = try intent.captureCommand()
            let wholeBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: intent.envelope, payload: command)
            #expect(stage.commandBytes == wholeBytes)
            #expect(stage.commandHash == CanonicalJSONV1.sha256Hex(wholeBytes))
            let domainValue = try database.pool.read { db in
                try DomainCommandReceiptRecordV1.fetchOne(db, key: intent.envelope.idempotencyKey)
            }
            let domain = try #require(domainValue)
            #expect(domain.commandPayloadHash == stage.commandHash)
            #expect(receipt.receiptBytes == Data(domain.resultJson.utf8))
            #expect(receipt.receiptHash == domain.resultHash)
            let decodedDomain = try CanonicalContractCodingV1.decode(InputCaptureReceiptV1.self, from: receipt.receiptBytes)
            #expect(result.captureReceipt == decodedDomain)
            let safeJSON: String = row["safeReceiptJson"]
            let safe = try CanonicalContractCodingV1.decode(DesktopGoalCaptureReceiptV1.self, from: Data(safeJSON.utf8))
            #expect(safe == result)
        }
    }

    @Test func captureReceiptFailureRollsBackEveryCarrierAndDomainWrite() throws {
        let (database, _) = try desktopTextDatabase()
        let existing = try desktopCaptureSecondIntent()
        let existingReceipt = try InputGoalStore(database: database).captureAndEnqueueParsing(existing.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: existing, sealed: true, receipt: existingReceipt)
        let before = try desktopCaptureSQLSnapshot(database)
        try database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER desktop_test_abort_capture_receipt
                BEFORE UPDATE OF safeReceiptJson ON desktop_goal_operation
                WHEN NEW.id='10000000-0000-4000-8000-000000000004' AND NEW.safeReceiptJson IS NOT NULL
                BEGIN
                  SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM input_envelope WHERE id=NEW.inputId)
                    OR NOT EXISTS(SELECT 1 FROM durable_work WHERE aggregateId=NEW.inputId AND kind='inputParsing')
                    OR NOT EXISTS(SELECT 1 FROM domain_command_receipt WHERE idempotencyKey='desktop-goal:10000000-0000-4000-8000-000000000004:capture:v1')
                    THEN RAISE(ABORT,'receipt_before_domain') END;
                  SELECT RAISE(ABORT,'desktop_capture_receipt_abort');
                END;
                """)
        }
        let intent = try desktopCaptureIntent()
        let result = Result { try DesktopGoalWorkflowStore(database: database).prepareSubmission(intent) }
        switch result {
        case .success:
            Issue.record("Expected injected journal receipt failure after actual domain writes")
        case let .failure(error):
            let databaseError = try #require(error as? DatabaseError)
            #expect(databaseError.message == "desktop_capture_receipt_abort")
        }
        let after = try desktopCaptureSQLSnapshot(database)
        #expect(after.counts == before.counts)
        #expect(after.rows == before.rows)
        #expect(after.rowHashes == before.rowHashes)
    }

    @Test func exactReplayBeforeAndAfterRestartOrInputProgressReturnsSameReceipt() throws {
        let (database, path) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        #expect(throws: Never.self) {
            let store = DesktopGoalWorkflowStore(database: database)
            let first = try store.prepareSubmission(intent)
            let before = try desktopCaptureSQLSnapshot(database)
            let second = try store.prepareSubmission(intent)
            #expect(second == first)
            let afterSecond = try desktopCaptureSQLSnapshot(database)
            #expect(afterSecond == before)
            try database.pool.close()
            let reopened = try AppDatabase(path: path)
            let reopenedStore = DesktopGoalWorkflowStore(database: reopened)
            let afterRestart = try reopenedStore.prepareSubmission(intent)
            #expect(afterRestart == first)
            let beforeProgress = try desktopCaptureSQLSnapshot(reopened)
            #expect(beforeProgress == before)
            try desktopCaptureParseActual(reopened, intent: intent)
            let progressed = try desktopCaptureSQLSnapshot(reopened)
            #expect(progressed.counts["durable_work_attempt"] == 1)
            let afterProgress = try reopenedStore.prepareSubmission(intent)
            #expect(afterProgress == first)
            let final = try desktopCaptureSQLSnapshot(reopened)
            #expect(final == progressed)
            #expect(final.counts["desktop_goal_context"] == 1)
            #expect(final.counts["desktop_goal_operation"] == 1)
            #expect(final.counts["input_envelope"] == 1)
            #expect(final.counts["durable_work"] == 1)
        }
    }

    @Test func providerAwareOutputPolicyIsCanonicalAndReplayBound() throws {
        for runtime in [DesktopCoachRuntimeV1.unconfigured, .selected(profileId: desktopGoalProfileID, model: "unresolved-model")] {
            let (database, path) = try desktopTextDatabase()
            let intent = try desktopCaptureIntent(runtime: runtime)
            #expect(throws: Never.self) {
                let first = try DesktopGoalWorkflowStore(database: database).prepareSubmission(intent)
                let before = try desktopCaptureSQLSnapshot(database)
                let request = try desktopCaptureOperationRow(database)
                let requestJSON: String = request["requestJson"]
                let requestHash: String = request["requestHash"]
                let expectedRequest = try CanonicalContractCodingV1.string(intent)
                #expect(requestJSON == expectedRequest)
                #expect(requestHash == CanonicalJSONV1.sha256Hex(Data(requestJSON.utf8)))
                let contextValue = try database.pool.read { db in
                    try Row.fetchOne(db, sql: "SELECT * FROM desktop_goal_context WHERE inputId=?", arguments: [desktopGoalInputID])
                }
                let contextRow = try #require(contextValue)
                let contextJSON: String = contextRow["contextJson"]
                let contextHash: String = contextRow["contextHash"]
                #expect(contextHash == CanonicalJSONV1.sha256Hex(Data(contextJSON.utf8)))
                let object = try JSONSerialization.jsonObject(with: Data(contextJSON.utf8))
                let contextObject = try #require(object as? [String: Any])
                let coach = try #require(contextObject["coachPolicy"] as? [String: Any])
                let policy = try #require(coach["outputPolicy"] as? [String: Any])
                #expect(Set(policy.keys) == Set(["apiRequestedTokens", "kind"]))
                #expect(policy["apiRequestedTokens"] as? Int == 4_096)
                #expect(policy["kind"] as? String == "providerAware")
                #expect(contextObject["remoteConsentReceiptId"] is NSNull)
                #expect(before.counts["durable_work_attempt"] == 0)
                #expect(before.counts["coach_session"] == 0)
                try database.pool.close()
                let reopened = try AppDatabase(path: path)
                let store = DesktopGoalWorkflowStore(database: reopened)
                let replay = try store.prepareSubmission(intent)
                #expect(replay == first)
                let unchanged = try desktopCaptureSQLSnapshot(reopened)
                #expect(unchanged == before)
                let changed = try desktopCaptureIntent(runtime: runtime, maximumDispatches: 7)
                let changedContext = try CanonicalContractCodingV1.string(changed.context)
                let changedRequest = try CanonicalContractCodingV1.string(changed)
                #expect(CanonicalJSONV1.sha256Hex(Data(changedContext.utf8)) != contextHash)
                #expect(CanonicalJSONV1.sha256Hex(Data(changedRequest.utf8)) != requestHash)
                #expect(throws: DesktopGoalFoundationErrorV1.operationConflict) { _ = try store.prepareSubmission(changed) }
                let afterConflict = try desktopCaptureSQLSnapshot(reopened)
                #expect(afterConflict == before)
                // Arrange a later legitimate context revision without altering the sealed original gesture.
                try reopened.pool.write { db in
                    try db.execute(sql: "UPDATE desktop_goal_context SET contextJson=?,contextHash=?,version=2 WHERE inputId=? AND version=1",
                                   arguments: [changedContext, CanonicalJSONV1.sha256Hex(Data(changedContext.utf8)), desktopGoalInputID])
                }
                let afterContextRevision = try desktopCaptureSQLSnapshot(reopened)
                let originalReplay = try store.prepareSubmission(intent)
                #expect(originalReplay == first)
                let afterOriginalReplay = try desktopCaptureSQLSnapshot(reopened)
                #expect(afterOriginalReplay == afterContextRevision)
                #expect(throws: DesktopGoalFoundationErrorV1.operationConflict) { _ = try store.prepareSubmission(changed) }
            }
        }
    }

    @Test func changedIntentEnvelopeContextOrStageUnderSameIdentityRejectsWithoutWrites() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        #expect(throws: Never.self) {
            let store = DesktopGoalWorkflowStore(database: database)
            _ = try store.prepareSubmission(intent)
            let before = try desktopCaptureSQLSnapshot(database)
            let changed = [
                try desktopCaptureIntent(text: "hello changed"),
                try desktopCaptureIntent(runtime: .selected(profileId: desktopGoalProfileID, model: "another-model")),
                try desktopCaptureIntent(campId: "desktop-camp-b"),
                try desktopCaptureIntent(deviceId: "30000000-0000-4000-8000-000000000005"),
                try desktopCaptureIntent(at: 101),
                try desktopCaptureIntent(goalId: "30000000-0000-4000-8000-000000000002"),
            ]
            for candidate in changed {
                #expect(throws: DesktopGoalFoundationErrorV1.operationConflict) { _ = try store.prepareSubmission(candidate) }
                let after = try desktopCaptureSQLSnapshot(database)
                #expect(after == before)
            }
        }
    }

    @Test func duplicateLiveSessionReservationRejectsWithoutAnyNewDomainWrite() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        let actualReceipt = try InputGoalStore(database: database).captureAndEnqueueParsing(intent.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: intent, sealed: true, receipt: actualReceipt)
        let before = try desktopCaptureSQLSnapshot(database)
        let conflicting = try desktopCaptureSecondIntent(sessionId: desktopGoalSessionID)
        #expect(throws: DesktopGoalFoundationErrorV1.contextConflict) {
            _ = try DesktopGoalWorkflowStore(database: database).prepareSubmission(conflicting)
        }
        let after = try desktopCaptureSQLSnapshot(database)
        #expect(after == before)
    }

    @Test func sealCaptureStageUsesCASAndPreservesExactCommandIdentity() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        _ = try InputGoalStore(database: database).captureAndEnqueueParsing(intent.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: intent, sealed: false)
        let store = DesktopGoalWorkflowStore(database: database)
        let beforeStale = try desktopCaptureSQLSnapshot(database)
        #expect(throws: DesktopGoalFoundationErrorV1.staleOperationVersion) {
            _ = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 2, intent: intent)
        }
        let afterStale = try desktopCaptureSQLSnapshot(database)
        #expect(afterStale == beforeStale)
        #expect(throws: Never.self) {
            let stage = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 1, intent: intent)
            let command = try intent.captureCommand()
            let bytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: intent.envelope, payload: command)
            #expect(stage.ordinal == 0)
            #expect(stage.commandType == .inputCapture)
            #expect(stage.commandBytes == bytes)
            #expect(stage.commandHash == CanonicalJSONV1.sha256Hex(bytes))
            #expect(stage.envelope == intent.envelope)
            #expect(stage.predecessorReceiptHash == nil)
            #expect(stage.receipt == nil)
            let row = try desktopCaptureOperationRow(database)
            let version: Int = row["version"]
            let phase: String = row["phase"]
            #expect(version == 2)
            #expect(phase == "prepared")
            let sealedSnapshot = try desktopCaptureSQLSnapshot(database)
            let staleExactReplay = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 1, intent: intent)
            #expect(staleExactReplay == stage)
            let currentExactReplay = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 2, intent: intent)
            #expect(currentExactReplay == stage)
            let afterExactReplay = try desktopCaptureSQLSnapshot(database)
            #expect(afterExactReplay == sealedSnapshot)
            let changed = try desktopCaptureIntent(text: "different sealed text")
            #expect(throws: DesktopGoalFoundationErrorV1.stageConflict) {
                _ = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 2, intent: changed)
            }
            #expect(throws: DesktopGoalFoundationErrorV1.staleOperationVersion) {
                _ = try store.sealCaptureStage(operationId: intent.operationId, expectedVersion: 99, intent: intent)
            }
            let afterRejected = try desktopCaptureSQLSnapshot(database)
            #expect(afterRejected == sealedSnapshot)
        }
    }

    @Test func sealedStageAndReceiptCASIsReplayableButNotReplaceable() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        let receipt = try InputGoalStore(database: database).captureAndEnqueueParsing(intent.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: intent, sealed: true)
        let other = try desktopCaptureSecondIntent()
        let otherReceipt = try InputGoalStore(database: database).captureAndEnqueueParsing(other.captureCommand())
        let before = try desktopCaptureSQLSnapshot(database)
        #expect(throws: DesktopGoalFoundationErrorV1.staleOperationVersion) {
            _ = try database.pool.write { db in
                try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 1, receipt: receipt, in: db)
            }
        }
        let afterStale = try desktopCaptureSQLSnapshot(database)
        #expect(afterStale == before)
        #expect(throws: DesktopGoalFoundationErrorV1.receiptConflict) {
            _ = try database.pool.write { db in
                try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 2, receipt: otherReceipt, in: db)
            }
        }
        let afterWrongFirstReceipt = try desktopCaptureSQLSnapshot(database)
        #expect(afterWrongFirstReceipt == before)
        #expect(throws: Never.self) {
            let appended = try database.pool.write { db in
                try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 2, receipt: receipt, in: db)
            }
            let receiptBytes = try CanonicalContractCodingV1.encode(receipt)
            #expect(appended.receiptBytes == receiptBytes)
            #expect(appended.receiptHash == CanonicalJSONV1.sha256Hex(receiptBytes))
            #expect(appended.inputId == desktopGoalInputID)
            #expect(appended.inputVersion == 1)
            #expect(appended.workVersion == 1)
            #expect(appended.workId == receipt.refs.first(where: { $0.kind == .durableWork })?.id)
            let row = try desktopCaptureOperationRow(database)
            let version: Int = row["version"]
            let phase: String = row["phase"]
            #expect(version == 3)
            #expect(phase == "prepared")
            let stageJSON: String = row["resultJson"]
            let stageObjectsValue = try JSONSerialization.jsonObject(with: Data(stageJSON.utf8))
            let stageObjects = try #require(stageObjectsValue as? [[String: Any]])
            #expect(stageObjects.count == 1)
            var actualPrefix = try #require(stageObjects.first)
            actualPrefix["receipt"] = NSNull()
            let actualPrefixBytes = try desktopTextCanonicalFixture(actualPrefix)
            let expectedPrefixBytes = try desktopTextCanonicalFixture(desktopCaptureStageWire(intent))
            #expect(actualPrefixBytes == expectedPrefixBytes)
            let safeJSON: String = row["safeReceiptJson"]
            let safe = try CanonicalContractCodingV1.decode(DesktopGoalCaptureReceiptV1.self, from: Data(safeJSON.utf8))
            #expect(safe.captureReceipt == receipt)
            #expect(safe.inputId == intent.context.inputId)
            #expect(safe.goalId == intent.context.goalId)
            #expect(safe.sessionId == intent.context.sessionId)
            #expect(safe.operationId == intent.operationId)
            let committedStageSnapshot = try desktopCaptureSQLSnapshot(database)
            let duplicate = try database.pool.write { db in
                try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 2, receipt: receipt, in: db)
            }
            #expect(duplicate == appended)
            #expect(throws: DesktopGoalFoundationErrorV1.receiptConflict) {
                _ = try database.pool.write { db in
                    try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 3, receipt: otherReceipt, in: db)
                }
            }
            let afterReceipts = try desktopCaptureSQLSnapshot(database)
            #expect(afterReceipts == committedStageSnapshot)
            let exactStage = try DesktopGoalWorkflowStore(database: database).sealCaptureStage(operationId: intent.operationId, expectedVersion: 1, intent: intent)
            #expect(exactStage.receipt == appended)
            let afterReseal = try desktopCaptureSQLSnapshot(database)
            #expect(afterReseal == committedStageSnapshot)
        }
    }

    @Test func outputPolicyRejectsUnsupportedOrLegacyJSONWithoutWrites() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        let receipt = try InputGoalStore(database: database).captureAndEnqueueParsing(intent.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: intent, sealed: true, receipt: receipt)
        let intentBytes = try CanonicalContractCodingV1.encode(intent)
        let intentObjectValue = try JSONSerialization.jsonObject(with: intentBytes)
        let intentObject = try #require(intentObjectValue as? [String: Any])
        let originalContext = try #require(intentObject["context"] as? [String: Any])
        let originalCoach = try #require(originalContext["coachPolicy"] as? [String: Any])
        let malformedPolicies: [[String: Any]] = [
            [:], ["kind": "providerAware"], ["apiRequestedTokens": 4096, "kind": "providerAware", "extra": true],
            ["apiRequestedTokens": 4096, "kind": "fixed"], ["apiRequestedTokens": "4096", "kind": "providerAware"],
            ["apiRequestedTokens": 4095, "kind": "providerAware"], ["maximumOutputTokens": 4096, "kind": "providerAware"],
        ]
        let before = try desktopCaptureSQLSnapshot(database)
        for policy in malformedPolicies {
            var context = originalContext
            var coach = originalCoach
            coach["outputPolicy"] = policy
            context["coachPolicy"] = coach
            var object = intentObject
            object["context"] = context
            let bytes = try desktopTextCanonicalFixture(object)
            #expect(throws: (any Error).self) {
                let invalid = try CanonicalContractCodingV1.decode(DesktopGoalCaptureIntentV1.self, from: bytes)
                _ = try DesktopGoalWorkflowStore(database: database).prepareSubmission(invalid)
            }
            let after = try desktopCaptureSQLSnapshot(database)
            #expect(after == before)
        }
        var corruptedContext = originalContext
        var corruptedCoach = originalCoach
        corruptedCoach["outputPolicy"] = ["apiRequestedTokens": 4095, "kind": "providerAware"]
        corruptedContext["coachPolicy"] = corruptedCoach
        let corruptedBytes = try desktopTextCanonicalFixture(corruptedContext)
        try database.pool.write { db in
            try db.execute(sql: "UPDATE desktop_goal_context SET contextJson=?,contextHash=? WHERE inputId=?",
                           arguments: [String(decoding: corruptedBytes, as: UTF8.self), CanonicalJSONV1.sha256Hex(corruptedBytes), desktopGoalInputID])
        }
        let corrupted = try desktopCaptureSQLSnapshot(database)
        #expect(throws: DesktopGoalFoundationErrorV1.corruptCanonicalPayload) {
            _ = try DesktopGoalWorkflowStore(database: database).prepareSubmission(intent)
        }
        let afterRejectedReplay = try desktopCaptureSQLSnapshot(database)
        #expect(afterRejectedReplay == corrupted)
    }
}

extension DesktopGoalFoundationTests {
    @Test func captureReviewPrepareRejectsUnicodeEquivalentRequestByteDrift() throws {
        let (database, _) = try desktopTextDatabase()
        let original = try desktopCaptureIntent(runtime: .selected(profileId: desktopGoalProfileID, model: "caf\u{00E9}"))
        let changed = try desktopCaptureIntent(runtime: .selected(profileId: desktopGoalProfileID, model: "cafe\u{0301}"))
        let originalBytes = try CanonicalContractCodingV1.encode(original)
        let changedBytes = try CanonicalContractCodingV1.encode(changed)
        #expect(String(decoding: originalBytes, as: UTF8.self) == String(decoding: changedBytes, as: UTF8.self))
        #expect(originalBytes != changedBytes)
        #expect(CanonicalJSONV1.sha256Hex(originalBytes) != CanonicalJSONV1.sha256Hex(changedBytes))
        let store = DesktopGoalWorkflowStore(database: database)
        let receipt = try store.prepareSubmission(original)
        let before = try desktopCaptureSQLSnapshot(database)
        #expect(throws: DesktopGoalFoundationErrorV1.operationConflict) {
            _ = try store.prepareSubmission(changed)
        }
        let after = try desktopCaptureSQLSnapshot(database)
        #expect(after == before)
        let replay = try store.prepareSubmission(original)
        #expect(replay == receipt)
        let afterExactReplay = try desktopCaptureSQLSnapshot(database)
        #expect(afterExactReplay == before)
    }

    @Test func captureReviewSealRejectsUnicodeEquivalentRequestByteDrift() throws {
        let (database, _) = try desktopTextDatabase()
        let original = try desktopCaptureIntent(runtime: .selected(profileId: desktopGoalProfileID, model: "caf\u{00E9}"))
        let changed = try desktopCaptureIntent(runtime: .selected(profileId: desktopGoalProfileID, model: "cafe\u{0301}"))
        let originalBytes = try CanonicalContractCodingV1.encode(original)
        let changedBytes = try CanonicalContractCodingV1.encode(changed)
        #expect(String(decoding: originalBytes, as: UTF8.self) == String(decoding: changedBytes, as: UTF8.self))
        #expect(originalBytes != changedBytes)
        #expect(CanonicalJSONV1.sha256Hex(originalBytes) != CanonicalJSONV1.sha256Hex(changedBytes))
        _ = try InputGoalStore(database: database).captureAndEnqueueParsing(original.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: original, sealed: true)
        let store = DesktopGoalWorkflowStore(database: database)
        let before = try desktopCaptureSQLSnapshot(database)
        #expect(throws: DesktopGoalFoundationErrorV1.stageConflict) {
            _ = try store.sealCaptureStage(operationId: original.operationId, expectedVersion: 2, intent: changed)
        }
        let after = try desktopCaptureSQLSnapshot(database)
        #expect(after == before)
        let staleReplay = try store.sealCaptureStage(operationId: original.operationId, expectedVersion: 1, intent: original)
        let currentReplay = try store.sealCaptureStage(operationId: original.operationId, expectedVersion: 2, intent: original)
        #expect(staleReplay == currentReplay)
        #expect(staleReplay.ordinal == 0)
        #expect(staleReplay.receipt == nil)
        let afterExactReplays = try desktopCaptureSQLSnapshot(database)
        #expect(afterExactReplays == before)
    }

    @Test func captureReviewFirstReceiptAppendRejectsMissingActualOutbox() throws {
        let (database, _) = try desktopTextDatabase()
        let intent = try desktopCaptureIntent()
        let inputStore = InputGoalStore(database: database)
        let receipt = try inputStore.captureAndEnqueueParsing(intent.captureCommand())
        try desktopCaptureInsertPreparedFixture(database, intent: intent, sealed: true)
        // Resolve only this actual capture's event/outbox; no fabricated graph or broad deletion.
        try database.pool.write { db in
            let receiptRowValue = try DomainCommandReceiptRecordV1.fetchOne(db, key: intent.envelope.idempotencyKey)
            let receiptRow = try #require(receiptRowValue)
            let eventIDs = try String.fetchAll(db, sql: "SELECT id FROM domain_event WHERE commandIdempotencyKey=? ORDER BY eventOrdinal",
                                              arguments: [receiptRow.idempotencyKey])
            #expect(receiptRow.eventCount == 1)
            #expect(eventIDs.count == 1)
            let eventID = try #require(eventIDs.first)
            let outboxValue = try EventOutboxRecordV1.fetchOne(db, key: eventID)
            let outbox = try #require(outboxValue)
            #expect(outbox.eventId == eventID)
            try db.execute(sql: "DELETE FROM event_outbox WHERE eventId=?", arguments: [eventID])
            #expect(db.changesCount == 1)
        }
        let corrupted = try desktopCaptureSQLSnapshot(database)
        #expect(corrupted.counts["event_outbox"] == 0)
        #expect(corrupted.counts["domain_event"] == 1)
        #expect(corrupted.counts["domain_command_receipt"] == 1)
        // Existing domain replay proves the exact missing edge is a real integrity failure.
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try inputStore.captureAndEnqueueParsing(intent.captureCommand())
        }
        let afterDomainReplay = try desktopCaptureSQLSnapshot(database)
        #expect(afterDomainReplay == corrupted)
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try database.pool.write { db in
                try DesktopGoalWorkflowStore.appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 2, receipt: receipt, in: db)
            }
        }
        let afterAppend = try desktopCaptureSQLSnapshot(database)
        #expect(afterAppend == corrupted)
    }
}
