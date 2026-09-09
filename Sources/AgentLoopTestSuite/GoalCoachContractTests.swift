import Foundation
import GRDB
import Testing
import AgentLoopCore

private let p1cGCCampID = "p1c-goal-coach-camp"
private let p1cGCOtherCampID = "p1c-goal-coach-other"
private let p1cGCInputID = "11111111-1111-1111-1111-111111111111"
private let p1cGCGoalID = "22222222-2222-2222-2222-222222222222"
private let p1cGCSessionID = "33333333-3333-3333-3333-333333333333"
private let p1cGCQuestion1ID = "44444444-4444-4444-4444-444444444444"
private let p1cGCQuestion2ID = "55555555-5555-5555-5555-555555555555"
private let p1cGCQuestion3ID = "66666666-6666-6666-6666-666666666666"
private let p1cGCDeviceID = "77777777-7777-7777-7777-777777777777"
private let p1cGCInputHash = String(repeating: "b", count: 64)

private enum P1CGoalCoachTestError: Error {
    case forcedRollback
    case missingFixture
}

private final class P1CGCLockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) { storage = value }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }

    var value: Value { withValue { $0 } }
}

private func requireP1CGoalCoachCapability() {
    _ = GoalControllerRecord.databaseTableName
    _ = CoachSessionRecord.databaseTableName
    _ = CoachQuestionRecord.databaseTableName
    _ = UnderstandingCardVersionRecord.databaseTableName
    _ = CoachTurnProcessor.self
}

private func p1cGCRequire<Value>(_ value: Value?) throws -> Value {
    guard let value else { throw P1CGoalCoachTestError.missingFixture }
    return value
}

private func p1cGCDatabase(_ label: String) throws -> AppDatabase {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1c-goal-coach-\(label)-\(UUID().uuidString).sqlite")
        .path
    let database = try AppDatabase(path: path)
    try database.pool.write { db in
        for id in [p1cGCCampID, p1cGCOtherCampID] {
            try db.execute(
                sql: "INSERT INTO camp (id,name,archived,createdAt) VALUES (?,?,0,1)",
                arguments: [id, id]
            )
            try db.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',1,1,1,NULL,NULL)
                    """,
                arguments: [id]
            )
        }
    }
    return database
}

private func p1cGCUserEnvelope(
    key: String,
    at: TimeInterval,
    actorType: DomainActorType = .user,
    actorId: String = "user:goal-owner",
    deviceId: String? = p1cGCDeviceID
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: actorType,
        actorId: actorId,
        deviceId: deviceId,
        correlationId: "goal-coach-trace",
        causationId: nil,
        occurredAt: Date(timeIntervalSince1970: at)
    )
}

private func p1cGCCapture(
    database: AppDatabase,
    inputId: String = p1cGCInputID,
    campId: String? = p1cGCCampID,
    candidates: [String] = []
) throws -> (InputGoalStore, InputEnvelopeRecord, DurableWorkRecord) {
    let command = try CaptureInputCommandV1(
        envelope: p1cGCUserEnvelope(key: "capture-\(inputId)", at: 100),
        inputId: inputId,
        auditCampId: p1cGCCampID,
        initialCampId: campId,
        sourceType: .text,
        sourceDeviceId: p1cGCDeviceID,
        connectorId: nil,
        authorId: "user:goal-owner",
        capturedAt: Date(timeIntervalSince1970: 90),
        inlineText: "Build the acceptance artifact",
        payloadRef: nil,
        contentHash: p1cGCInputHash,
        candidateCampIds: candidates,
        explicitIntent: .createGoal,
        privacyLevel: .localOnly,
        parentInputId: nil
    )
    let store = InputGoalStore(database: database)
    _ = try store.captureAndEnqueueParsing(command)
    let input = try p1cGCRequire(store.input(id: inputId))
    let work = try p1cGCRequire(DurableWorkStore(database: database).activeWork(
        kind: .inputParsing,
        aggregateType: "input",
        aggregateId: inputId
    ))
    return (store, input, work)
}

private func p1cGCWorkerEnvelope(
    database: AppDatabase,
    claim: DurableWorkClaim
) throws -> CommandEnvelopeV1 {
    try database.pool.read { db in
        let work = try p1cGCRequire(DurableWorkRecord.fetchOne(db, key: claim.workId))
        let attempt = try p1cGCRequire(DurableWorkAttemptRecord.fetchOne(
            db,
            key: ["workId": claim.workId, "attempt": claim.attempt]
        ))
        return try ControlWorkerCommandEnvelopeFactoryV1.make(
            work: work,
            attempt: attempt,
            claim: claim
        )
    }
}

@discardableResult
private func p1cGCSeedGoal(
    _ database: AppDatabase,
    goalId: String = p1cGCGoalID
) throws -> GoalControllerRecord {
    let (store, input, _) = try p1cGCCapture(database: database)
    let claim = try p1cGCRequire(DurableWorkStore(database: database).claimNext(
        kinds: [.inputParsing],
        workerId: "seed-parser",
        now: Date(timeIntervalSince1970: 110),
        leaseDuration: 60
    ))
    let parse = try CommitInputParseResultCommandV1(
        envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
        input: InputHeadV1(
            inputId: input.id,
            auditCampId: p1cGCCampID,
            expectedInputVersion: 1
        ),
        claim: WorkClaimV1(claim: claim),
        result: InputParseResultV1(
            route: .coaching,
            candidateCampIds: [],
            assignedCampId: p1cGCCampID
        )
    )
    _ = try store.commitParseResult(
        parse,
        terminalNow: Date(timeIntervalSince1970: 120)
    )
    let convert = try ConvertInputToGoalCommandV1(
        envelope: p1cGCUserEnvelope(key: "convert-\(goalId)", at: 130),
        input: InputHeadV1(
            inputId: input.id,
            auditCampId: p1cGCCampID,
            expectedInputVersion: 2
        ),
        activeParsingBranch: .none,
        goalId: goalId,
        title: "Acceptance-ready goal",
        rawIntent: "Produce a verified artifact"
    )
    _ = try store.convertToGoal(convert)
    return try p1cGCRequire(store.goal(id: goalId))
}

private func p1cGCOpen(
    _ database: AppDatabase,
    key: String = "open-coach",
    sessionId: String = p1cGCSessionID,
    nextQuestionId: String = p1cGCQuestion1ID,
    expectedGoalVersion: Int = 1,
    at: TimeInterval = 140
) throws -> (CoachUnderstandingStore, CoachSessionRecord, DurableWorkRecord, CampSafeCommandResultV1) {
    let store = CoachUnderstandingStore(database: database)
    let result = try store.openCoachSession(OpenCoachSessionCommandV1(
        envelope: p1cGCUserEnvelope(key: key, at: at),
        goal: GoalHeadV1(
            goalId: p1cGCGoalID,
            campId: p1cGCCampID,
            expectedGoalVersion: expectedGoalVersion
        ),
        sourceInputId: p1cGCInputID,
        sessionId: sessionId,
        nextQuestionId: nextQuestionId
    ))
    let session = try p1cGCRequire(store.session(id: sessionId))
    let work = try p1cGCRequire(DurableWorkStore(database: database).activeWork(
        kind: .coach,
        aggregateType: "goal",
        aggregateId: p1cGCGoalID
    ))
    return (store, session, work, result)
}

private func p1cGCClaimCoach(
    _ database: AppDatabase,
    workerId: String = "coach-worker",
    at: TimeInterval = 150
) throws -> DurableWorkClaim {
    try p1cGCRequire(DurableWorkStore(database: database).claimNext(
        kinds: [.coach],
        workerId: workerId,
        now: Date(timeIntervalSince1970: at),
        leaseDuration: 60
    ))
}

private func p1cGCContent(_ suffix: String = "v1") throws -> UnderstandingContentV1 {
    try UnderstandingContentV1(
        problem: "Problem \(suffix)",
        scenario: "Scenario \(suffix)",
        targetAudience: "Owner \(suffix)",
        goals: ["Goal \(suffix)"],
        nonGoals: ["Non-goal \(suffix)"],
        deliverables: ["Deliverable \(suffix)"],
        constraints: ["Constraint \(suffix)"],
        acceptanceCriteria: ["Criterion \(suffix)"],
        verificationPlan: ["Run tests \(suffix)"],
        resourceRefs: ["local:artifact:\(suffix)"],
        requiredCapabilities: ["swift:\(suffix)"],
        budgetPolicy: ["mode": "local-only-\(suffix)"],
        assumptions: ["Assumption \(suffix)"],
        acceptedRisks: ["Risk \(suffix)"]
    )
}

private func p1cGCHead(
    _ goal: GoalControllerRecord
) throws -> GoalHeadV1 {
    try GoalHeadV1(
        goalId: goal.id,
        campId: goal.campId,
        expectedGoalVersion: goal.aggregateVersion
    )
}

private func p1cGCCoachHead(
    _ session: CoachSessionRecord
) throws -> CoachHeadV1 {
    try CoachHeadV1(
        sessionId: session.id,
        expectedSessionVersion: session.aggregateVersion
    )
}

private func p1cGCUnderstandingHead(
    database: AppDatabase,
    value: UnderstandingCardVersionRecord
) throws -> UnderstandingHeadV1 {
    let eventVersion = try database.pool.read { db in
        try Int.fetchOne(
            db,
            sql: "SELECT MAX(aggregateVersion) FROM domain_event WHERE aggregateType='understanding' AND aggregateId=?",
            arguments: [value.id]
        ) ?? 0
    }
    return try UnderstandingHeadV1(
        understandingId: value.id,
        expectedContentVersion: value.version,
        contentHash: value.contentHash,
        expectedUnderstandingEventVersion: eventVersion
    )
}

private func p1cGCProposeDraft(
    _ database: AppDatabase,
    content: UnderstandingContentV1? = nil
) throws -> (CoachUnderstandingStore, GoalControllerRecord, CoachSessionRecord, UnderstandingCardVersionRecord) {
    let goal = try p1cGCSeedGoal(database)
    let (store, session, _, _) = try p1cGCOpen(database)
    let claim = try p1cGCClaimCoach(database)
    let command = try ProposeUnderstandingCommandV1(
        envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
        goal: p1cGCHead(goal),
        coach: p1cGCCoachHead(session),
        claim: WorkClaimV1(claim: claim),
        expectedUnderstandingEventVersion: 0,
        content: content ?? p1cGCContent()
    )
    _ = try store.proposeUnderstanding(
        command,
        terminalNow: Date(timeIntervalSince1970: 160)
    )
    return (
        store,
        try p1cGCRequire(store.goal(id: goal.id)),
        try p1cGCRequire(store.session(id: session.id)),
        try p1cGCRequire(store.understanding(id: goal.id, version: 1))
    )
}

private func p1cGCConfirmFirst(
    _ database: AppDatabase
) throws -> (CoachUnderstandingStore, GoalControllerRecord, CoachSessionRecord, UnderstandingCardVersionRecord) {
    let (store, _, proposedSession, draft) = try p1cGCProposeDraft(database)
    let goal = try p1cGCRequire(store.goal(id: p1cGCGoalID))
    _ = try store.requestConfirmation(RequestCoachConfirmationCommandV1(
        envelope: try CommandEnvelopeV1(
            idempotencyKey: "request-confirmation",
            actorType: .coach,
            actorId: p1CCoachActorId,
            deviceId: nil,
            correlationId: "goal-coach-trace",
            causationId: nil,
            occurredAt: Date(timeIntervalSince1970: 170)
        ),
        goal: p1cGCHead(goal),
        coach: p1cGCCoachHead(proposedSession),
        understanding: p1cGCUnderstandingHead(database: database, value: draft)
    ))
    let awaitingSession = try p1cGCRequire(store.session(id: p1cGCSessionID))
    let awaiting = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
    _ = try store.confirmUnderstanding(ConfirmUnderstandingCommandV1(
        envelope: p1cGCUserEnvelope(key: "confirm-first", at: 180),
        goal: p1cGCHead(goal),
        coach: p1cGCCoachHead(awaitingSession),
        understanding: p1cGCUnderstandingHead(database: database, value: awaiting)
    ))
    return (
        store,
        try p1cGCRequire(store.goal(id: p1cGCGoalID)),
        try p1cGCRequire(store.session(id: p1cGCSessionID)),
        try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
    )
}

private func p1cGCCounts(_ database: AppDatabase) throws -> [String: Int] {
    try database.pool.read { db in
        var result: [String: Int] = [:]
        for table in [
            "input_envelope", "goal_controller", "coach_session",
            "coach_question", "understanding_card_version", "durable_work",
            "domain_command_receipt", "domain_event", "event_outbox",
        ] {
            result[table] = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM \(table)"
            ) ?? 0
        }
        return result
    }
}

private func p1cGCResultRef(
    _ result: CampSafeCommandResultV1,
    _ kind: CampSafeRefKindV1
) -> String? {
    result.refs.first(where: { $0.kind == kind })?.id
}

private func p1cGCResultVersion(
    _ result: CampSafeCommandResultV1,
    _ kind: CampSafeVersionKindV1
) -> Int? {
    result.versions.first(where: { $0.kind == kind })?.value
}

@Suite(.serialized)
struct P1CGoalCoachContractTests {
    @Test func crossCampAmbiguityBlocksGoalCreationWithoutWrites() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("ambiguous")
        let (store, input, _) = try p1cGCCapture(
            database: database,
            campId: nil,
            candidates: [p1cGCCampID, p1cGCOtherCampID]
        )
        let claim = try p1cGCRequire(DurableWorkStore(database: database).claimNext(
            kinds: [.inputParsing],
            workerId: "ambiguous-parser",
            now: Date(timeIntervalSince1970: 110),
            leaseDuration: 60
        ))
        _ = try store.commitParseResult(
            CommitInputParseResultCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                input: InputHeadV1(
                    inputId: input.id,
                    auditCampId: p1cGCCampID,
                    expectedInputVersion: 1
                ),
                claim: WorkClaimV1(claim: claim),
                result: InputParseResultV1(
                    route: .campAmbiguous,
                    candidateCampIds: [p1cGCCampID, p1cGCOtherCampID],
                    assignedCampId: nil
                )
            ),
            terminalNow: Date(timeIntervalSince1970: 120)
        )
        let before = try p1cGCCounts(database)
        #expect(throws: GoalCampResolutionError.self) {
            _ = try store.convertToGoal(ConvertInputToGoalCommandV1(
                envelope: p1cGCUserEnvelope(key: "ambiguous-convert", at: 130),
                input: InputHeadV1(
                    inputId: input.id,
                    auditCampId: p1cGCCampID,
                    expectedInputVersion: 2
                ),
                activeParsingBranch: .none,
                goalId: p1cGCGoalID,
                title: "Must not infer Camp",
                rawIntent: "Stay blocked"
            ))
        }
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func convertToGoalCommitsInputGoalEventsAndOutboxesAtomically() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("convert-atomic")
        let goal = try p1cGCSeedGoal(database)
        let input = try p1cGCRequire(InputGoalStore(database: database).input(id: p1cGCInputID))
        #expect(input.status == .goalCreated)
        #expect(input.aggregateVersion == 3)
        #expect(goal.status == .clarifying)
        #expect(goal.sourceInputId == input.id)
        #expect(goal.currentUnderstandingId == nil)
        let rows = try database.pool.read { db in
            (
                try DomainEventRecordV1.fetchCount(db),
                try EventOutboxRecordV1.fetchCount(db),
                try DomainCommandReceiptRecordV1.fetchCount(db)
            )
        }
        #expect(rows.0 == 4)
        #expect(rows.1 == 4)
        #expect(rows.2 == 3)
    }

    @Test func convertToGoalReplayUsesCallerOwnedGoalIDAfterProjectionAdvances() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("convert-replay")
        let goal = try p1cGCSeedGoal(database)
        let store = InputGoalStore(database: database)
        let replayCommand = try ConvertInputToGoalCommandV1(
            envelope: p1cGCUserEnvelope(key: "convert-\(p1cGCGoalID)", at: 130),
            input: InputHeadV1(
                inputId: p1cGCInputID,
                auditCampId: p1cGCCampID,
                expectedInputVersion: 2
            ),
            activeParsingBranch: .none,
            goalId: p1cGCGoalID,
            title: "Acceptance-ready goal",
            rawIntent: "Produce a verified artifact"
        )
        _ = try CoachUnderstandingStore(database: database).abandon(
            AbandonGoalCommandV1(
                envelope: p1cGCUserEnvelope(key: "advance-goal", at: 140),
                goal: p1cGCHead(goal),
                sessionBranch: .none
            )
        )
        let before = try p1cGCCounts(database)
        let replay = try store.convertToGoal(replayCommand)
        #expect(p1cGCResultRef(replay, .goal) == p1cGCGoalID)
        #expect(p1cGCResultVersion(replay, .goalProjection) == 1)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func goalP1CTransitionsOnlyClarifyingReadyAbandonedAndFailed() {
        requireP1CGoalCoachCapability()
        #expect(GoalControllerTransitionPolicyV1.p1CWritableStatuses == [
            .clarifying, .ready, .abandoned, .failed,
        ])
        #expect(GoalControllerTransitionPolicyV1.allows(from: .clarifying, to: .ready))
        #expect(GoalControllerTransitionPolicyV1.allows(from: .ready, to: .abandoned))
        for status in [
            GoalControllerStatusV1.active,
            .paused,
            .achieved,
            .deletedTombstone,
        ] {
            #expect(!GoalControllerTransitionPolicyV1.p1CWritableStatuses.contains(status))
        }
    }

    @Test func openCoachSessionEnqueuesDurableCoachWorkAtomically() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("open-atomic")
        _ = try p1cGCSeedGoal(database)
        let (_, session, work, result) = try p1cGCOpen(database)
        let sealed = try CanonicalContractCodingV1.decode(
            CoachTurnWorkInputV1.self,
            from: Data(work.inputJson.utf8)
        )
        #expect(session.status == .interviewing)
        #expect(work.kind == .coach)
        #expect(work.state == .queued)
        #expect(work.aggregateId == p1cGCGoalID)
        #expect(sealed.sessionId == session.id)
        #expect(sealed.nextQuestionId == p1cGCQuestion1ID)
        #expect(sealed.decisionKey == "decision:v1:\(p1cGCQuestion1ID)")
        #expect(sealed.failureScope == .clarifyingGoal)
        #expect(p1cGCResultRef(result, .durableWork) == work.id)
    }

    @Test func openCoachReplayUsesCallerOwnedSessionAndQuestionIDs() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("open-replay")
        _ = try p1cGCSeedGoal(database)
        let (_, _, work, first) = try p1cGCOpen(database)
        let before = try p1cGCCounts(database)
        let (_, _, replayWork, replay) = try p1cGCOpen(database)
        #expect(replay == first)
        #expect(replayWork.id == work.id)
        #expect(p1cGCResultRef(replay, .coachSession) == p1cGCSessionID)
        #expect(p1cGCResultRef(replay, .nextCoachQuestion) == p1cGCQuestion1ID)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func oneCoachSessionPerGoalControlsConcurrentOpenResumeAndTerminalBranches() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("one-session")
        _ = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let before = try p1cGCCounts(database)
        #expect(throws: CoachSessionAlreadyExistsError.self) {
            _ = try store.openCoachSession(OpenCoachSessionCommandV1(
                envelope: p1cGCUserEnvelope(key: "second-open", at: 141),
                goal: GoalHeadV1(
                    goalId: p1cGCGoalID,
                    campId: p1cGCCampID,
                    expectedGoalVersion: 1
                ),
                sourceInputId: p1cGCInputID,
                sessionId: "88888888-8888-8888-8888-888888888888",
                nextQuestionId: "99999999-9999-9999-9999-999999999999"
            ))
        }
        #expect(try p1cGCCounts(database) == before)
        let resumed = try store.resumeSession(goalId: p1cGCGoalID)
        #expect(resumed.session == session)
        #expect(resumed.openQuestion == nil)
    }

    @Test func coachSessionAllowsExactlyOneOpenQuestion() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("one-question")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        _ = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(goal),
                coach: p1cGCCoachHead(session),
                claim: WorkClaimV1(claim: claim),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "What is the acceptance boundary?",
                recommendation: "Use deterministic evidence",
                reason: "The Goal is not yet decision-complete"
            ),
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let snapshot = try store.resumeSession(goalId: goal.id)
        #expect(snapshot.session.status == .waitingForUser)
        #expect(snapshot.openQuestion?.id == p1cGCQuestion1ID)
        let openCount = try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM coach_question WHERE sessionId=? AND state='open'",
                arguments: [session.id]
            )
        }
        #expect(openCount == 1)
    }

    @Test func coachQuestionAndAnswerEnforceCoachAndUserActors() throws {
        requireP1CGoalCoachCapability()
        let goal = try GoalHeadV1(
            goalId: p1cGCGoalID,
            campId: p1cGCCampID,
            expectedGoalVersion: 1
        )
        let coach = try CoachHeadV1(
            sessionId: p1cGCSessionID,
            expectedSessionVersion: 1
        )
        let badCoach = try p1cGCUserEnvelope(key: "bad-coach", at: 1)
        let fakeClaim = try WorkClaimV1(claim: DurableWorkClaim(
            workId: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            attempt: 1,
            workerId: "worker",
            version: 2,
            leaseExpiresAt: Date(timeIntervalSince1970: 2)
        ))
        #expect(throws: P1CommandAuthorizationError.self) {
            _ = try RecordCoachQuestionCommandV1(
                envelope: badCoach,
                goal: goal,
                coach: coach,
                claim: fakeClaim,
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "Prompt",
                recommendation: "Recommendation",
                reason: "Reason"
            )
        }
        let coachEnvelope = try CommandEnvelopeV1(
            idempotencyKey: "bad-user",
            actorType: .coach,
            actorId: p1CCoachActorId,
            deviceId: nil,
            correlationId: "trace",
            causationId: nil,
            occurredAt: Date(timeIntervalSince1970: 1)
        )
        #expect(throws: P1CommandAuthorizationError.self) {
            _ = try AnswerCoachQuestionCommandV1(
                envelope: coachEnvelope,
                goal: goal,
                coach: coach,
                currentQuestionId: p1cGCQuestion1ID,
                answer: CoachAnswerV1(text: "Answer"),
                nextQuestionId: p1cGCQuestion2ID,
                expectedUnderstandingEventVersion: 0
            )
        }
    }

    @Test func everyGoalCoachCommandEnforcesExactActorAndDeviceMatrixBeforeSQL() throws {
        requireP1CGoalCoachCapability()
        let userRows: [P1CommandTypeV1] = [
            .coachOpenSession, .coachAnswerQuestion,
            .coachConfirmUnderstanding, .coachRequestUnderstandingRevision,
            .goalAbandon,
        ]
        let coachRows: [P1CommandTypeV1] = [
            .coachRecordQuestion, .coachProposeUnderstanding,
            .coachRequestConfirmation, .coachRecordWorkFailure, .goalFail,
        ]
        let user = try p1cGCUserEnvelope(key: "matrix-user", at: 1)
        let coach = try CommandEnvelopeV1(
            idempotencyKey: "matrix-coach",
            actorType: .coach,
            actorId: p1CCoachActorId,
            deviceId: nil,
            correlationId: "trace",
            causationId: nil,
            occurredAt: Date(timeIntervalSince1970: 1)
        )
        for command in userRows {
            #expect(throws: Never.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command,
                    envelope: user
                )
            }
            #expect(throws: P1CommandAuthorizationError.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command,
                    envelope: coach
                )
            }
        }
        for command in coachRows {
            #expect(throws: Never.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command,
                    envelope: coach
                )
            }
            #expect(throws: P1CommandAuthorizationError.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command,
                    envelope: user
                )
            }
        }
    }

    @Test func coachSealedDecisionKeyNeverComesFromProvider() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("sealed-decision")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let requestBox = P1CGCLockedBox<CoachTurnProviderRequestV1?>(nil)
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 150),
            Date(timeIntervalSince1970: 160),
        ])
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "sealed-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { request in
                requestBox.withValue { $0 = request }
                return .question(
                    prompt: "Persisted question",
                    recommendation: "Persisted recommendation",
                    reason: "Persisted reason"
                )
            }
        )
        #expect(try await processor.runNext())
        let request = try p1cGCRequire(requestBox.value)
        #expect(request.nextQuestionId == p1cGCQuestion1ID)
        #expect(request.decisionKey == "decision:v1:\(p1cGCQuestion1ID)")
        let question = try p1cGCRequire(
            CoachUnderstandingStore(database: database)
                .question(id: p1cGCQuestion1ID)
        )
        #expect(question.id == request.nextQuestionId)
        #expect(question.decisionKey == request.decisionKey)
    }

    @Test func coachProviderInterfaceOrdersPersistedHistoryBeforeAwait() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("provider-history")
        let goal = try p1cGCSeedGoal(database)
        let (store, openedSession, _, _) = try p1cGCOpen(database)
        let firstClaim = try p1cGCClaimCoach(database)
        _ = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: firstClaim),
                goal: p1cGCHead(goal),
                coach: p1cGCCoachHead(openedSession),
                claim: WorkClaimV1(claim: firstClaim),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "First question",
                recommendation: "First recommendation",
                reason: "First reason"
            ),
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let waiting = try p1cGCRequire(store.session(id: p1cGCSessionID))
        _ = try store.answerQuestion(AnswerCoachQuestionCommandV1(
            envelope: p1cGCUserEnvelope(key: "answer-first", at: 170),
            goal: p1cGCHead(goal),
            coach: p1cGCCoachHead(waiting),
            currentQuestionId: p1cGCQuestion1ID,
            answer: CoachAnswerV1(text: "First answer"),
            nextQuestionId: p1cGCQuestion2ID,
            expectedUnderstandingEventVersion: 0
        ))
        let requestBox = P1CGCLockedBox<CoachTurnProviderRequestV1?>(nil)
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 180),
            Date(timeIntervalSince1970: 190),
        ])
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "history-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { request in
                requestBox.withValue { $0 = request }
                _ = try? database.pool.write { db in
                    try db.execute(
                        sql: "UPDATE goal_controller SET title='post-await mutation' WHERE id=?",
                        arguments: [p1cGCGoalID]
                    )
                }
                return .understanding(try! p1cGCContent("history"))
            }
        )
        #expect(try await processor.runNext())
        let request = try p1cGCRequire(requestBox.value)
        #expect(request.goalTitle == "Acceptance-ready goal")
        #expect(request.questionHistory.map(\.questionId) == [p1cGCQuestion1ID])
        #expect(request.questionHistory[0].answer?.text == "First answer")
        #expect(request.understandingHistory.isEmpty)
        #expect(request.nextQuestionId == p1cGCQuestion2ID)
    }

    @Test func coachProviderInvalidOutputFailsDeterministicallyExactlyOnce() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("invalid-provider")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let calls = P1CGCLockedBox(0)
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 150),
            Date(timeIntervalSince1970: 160),
            Date(timeIntervalSince1970: 170),
        ])
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "invalid-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                calls.withValue { $0 += 1 }
                return .question(prompt: "", recommendation: "valid", reason: "valid")
            }
        )
        #expect(try await processor.runNext())
        let store = CoachUnderstandingStore(database: database)
        #expect(try p1cGCRequire(store.goal(id: p1cGCGoalID)).status == .failed)
        #expect(try p1cGCRequire(store.session(id: p1cGCSessionID)).status == .failed)
        let failedWork = try await database.pool.read { db in
            try p1cGCRequire(DurableWorkRecord
                .filter(Column("kind") == DurableWorkKind.coach.rawValue)
                .fetchOne(db))
        }
        #expect(failedWork.state == .failed)
        #expect(failedWork.errorCode == "coach_provider_invalid_output")
        #expect(!(try await processor.runNext()))
        #expect(calls.value == 1)
    }

    @Test func coachAnswerEnqueuesNextDurableTurnAtomically() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("answer-atomic")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        _ = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(goal),
                coach: p1cGCCoachHead(session),
                claim: WorkClaimV1(claim: claim),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "Question",
                recommendation: "Recommendation",
                reason: "Reason"
            ),
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let waiting = try p1cGCRequire(store.session(id: session.id))
        let result = try store.answerQuestion(AnswerCoachQuestionCommandV1(
            envelope: p1cGCUserEnvelope(key: "answer-atomic", at: 170),
            goal: p1cGCHead(goal),
            coach: p1cGCCoachHead(waiting),
            currentQuestionId: p1cGCQuestion1ID,
            answer: CoachAnswerV1(text: "Answer"),
            nextQuestionId: p1cGCQuestion2ID,
            expectedUnderstandingEventVersion: 0
        ))
        let answered = try p1cGCRequire(store.question(id: p1cGCQuestion1ID))
        let nextWork = try p1cGCRequire(DurableWorkStore(database: database).activeWork(
            kind: .coach,
            aggregateType: "goal",
            aggregateId: goal.id
        ))
        let input = try CanonicalContractCodingV1.decode(
            CoachTurnWorkInputV1.self,
            from: Data(nextWork.inputJson.utf8)
        )
        #expect(answered.state == .answered)
        #expect(answered.answer?.text == "Answer")
        #expect(input.nextQuestionId == p1cGCQuestion2ID)
        #expect(p1cGCResultRef(result, .durableWork) == nextWork.id)
    }

    @Test func coachAnswerReplayDoesNotEnqueueSecondTurn() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("answer-replay")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        _ = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
                claim: WorkClaimV1(claim: claim),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "Question", recommendation: "Recommendation", reason: "Reason"
            ),
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let waiting = try p1cGCRequire(store.session(id: session.id))
        let command = try AnswerCoachQuestionCommandV1(
            envelope: p1cGCUserEnvelope(key: "answer-replay", at: 170),
            goal: p1cGCHead(goal), coach: p1cGCCoachHead(waiting),
            currentQuestionId: p1cGCQuestion1ID,
            answer: CoachAnswerV1(text: "Answer"),
            nextQuestionId: p1cGCQuestion2ID,
            expectedUnderstandingEventVersion: 0
        )
        let first = try store.answerQuestion(command)
        let before = try p1cGCCounts(database)
        let replay = try store.answerQuestion(command)
        #expect(replay == first)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func coachProposalReplayUsesGoalIDAsUnderstandingID() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("proposal-id")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        let command = try ProposeUnderstandingCommandV1(
            envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
            goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
            claim: WorkClaimV1(claim: claim),
            expectedUnderstandingEventVersion: 0,
            content: p1cGCContent()
        )
        let first = try store.proposeUnderstanding(
            command,
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let before = try p1cGCCounts(database)
        let replay = try store.proposeUnderstanding(
            command,
            terminalNow: Date(timeIntervalSince1970: 999)
        )
        #expect(replay == first)
        #expect(p1cGCResultRef(replay, .understanding) == goal.id)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func coachFailureRetriesAtomicallyAndKeepsSessionInterviewing() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("failure-retry")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 150),
            Date(timeIntervalSince1970: 160),
        ])
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "retry-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                .failed(try! ControlWorkerProviderFailureV1(
                    code: "coach_unavailable",
                    safeMessage: "retry",
                    disposition: .transient
                ))
            }
        )
        #expect(try await processor.runNext())
        let store = CoachUnderstandingStore(database: database)
        let goal = try p1cGCRequire(store.goal(id: p1cGCGoalID))
        let session = try p1cGCRequire(store.session(id: p1cGCSessionID))
        let work = try await database.pool.read { db in
            try p1cGCRequire(DurableWorkRecord
                .filter(Column("kind") == DurableWorkKind.coach.rawValue)
                .fetchOne(db))
        }
        #expect(goal.status == .clarifying)
        #expect(session.status == .interviewing)
        #expect(session.aggregateVersion == 2)
        #expect(work.state == .retryScheduled)
        #expect(work.notBefore == Date(timeIntervalSince1970: 165))
    }

    @Test func coachFailureExhaustionFailsSessionAndGoalAtomically() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("failure-exhaust")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let times = P1CGCLockedBox([
            150.0, 150.0, 155.0, 155.0,
            185.0, 185.0, 305.0, 305.0,
        ].map(Date.init(timeIntervalSince1970:)))
        let calls = P1CGCLockedBox(0)
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "exhaust-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                calls.withValue { $0 += 1 }
                return .failed(try! ControlWorkerProviderFailureV1(
                    code: "coach_unavailable",
                    safeMessage: "retry",
                    disposition: .transient
                ))
            }
        )
        for _ in 1...4 { #expect(try await processor.runNext()) }
        let store = CoachUnderstandingStore(database: database)
        #expect(try p1cGCRequire(store.goal(id: p1cGCGoalID)).status == .failed)
        #expect(try p1cGCRequire(store.session(id: p1cGCSessionID)).status == .failed)
        let work = try await database.pool.read { db in
            try p1cGCRequire(DurableWorkRecord
                .filter(Column("kind") == DurableWorkKind.coach.rawValue)
                .fetchOne(db))
        }
        #expect(work.attempt == 4)
        #expect(work.state == .failed)
        #expect(calls.value == 4)
    }

    @Test func coachReopenedTerminalFailuresAndReplayPreserveReadyGoalAndConfirmedHead() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("ready-terminal")
        let (store, readyGoal, confirmedSession, confirmed) = try p1cGCConfirmFirst(database)
        _ = try store.requestUnderstandingRevision(
            RequestUnderstandingRevisionCommandV1(
                envelope: p1cGCUserEnvelope(key: "reopen-ready", at: 190),
                goal: p1cGCHead(readyGoal),
                coach: p1cGCCoachHead(confirmedSession),
                understanding: p1cGCUnderstandingHead(database: database, value: confirmed),
                revisionBranch: .reopenConfirmed,
                nextQuestionId: p1cGCQuestion2ID
            )
        )
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 210),
        ])
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "ready-failure-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                .failed(try! ControlWorkerProviderFailureV1(
                    code: "bad_ready_revision",
                    safeMessage: nil,
                    disposition: .deterministic
                ))
            }
        )
        #expect(try await processor.runNext())
        let afterGoal = try p1cGCRequire(store.goal(id: p1cGCGoalID))
        let failedSession = try p1cGCRequire(store.session(id: p1cGCSessionID))
        #expect(afterGoal == readyGoal)
        #expect(failedSession.status == .failed)
        #expect(try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1)) == confirmed)
        _ = try store.requestUnderstandingRevision(
            RequestUnderstandingRevisionCommandV1(
                envelope: p1cGCUserEnvelope(key: "reopen-after-failure", at: 220),
                goal: p1cGCHead(afterGoal),
                coach: p1cGCCoachHead(failedSession),
                understanding: p1cGCUnderstandingHead(database: database, value: confirmed),
                revisionBranch: .reopenConfirmed,
                nextQuestionId: p1cGCQuestion3ID
            )
        )
        #expect(try p1cGCRequire(store.session(id: p1cGCSessionID)).status == .interviewing)
    }

    @Test func readyRevisionWorkSealsAndValidatesJoinedConfirmedUnderstandingHash() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("ready-hash")
        let (store, readyGoal, confirmedSession, confirmed) = try p1cGCConfirmFirst(database)
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE understanding_card_version SET problem='tampered' WHERE id=? AND version=1",
                arguments: [p1cGCGoalID]
            )
        }
        let before = try p1cGCCounts(database)
        #expect(throws: UnderstandingIntegrityError.self) {
            _ = try store.requestUnderstandingRevision(
                RequestUnderstandingRevisionCommandV1(
                    envelope: p1cGCUserEnvelope(key: "tampered-reopen", at: 190),
                    goal: p1cGCHead(readyGoal),
                    coach: p1cGCCoachHead(confirmedSession),
                    understanding: UnderstandingHeadV1(
                        understandingId: confirmed.id,
                        expectedContentVersion: confirmed.version,
                        contentHash: confirmed.contentHash,
                        expectedUnderstandingEventVersion: 3
                    ),
                    revisionBranch: .reopenConfirmed,
                    nextQuestionId: p1cGCQuestion2ID
                )
            )
        }
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func coachWorkerRestartAdoptsInterruptedTurn() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("worker-adopt")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let interrupted = try p1cGCClaimCoach(
            database,
            workerId: "old-worker",
            at: 150
        )
        let recovery = try CoachTurnProcessor(
            database: database,
            workerId: "new-worker",
            clock: { Date(timeIntervalSince1970: 220) },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in .canceled }
        )
        let adopted = try recovery.recoverInterrupted()
        #expect(adopted.map(\.id) == [interrupted.workId])
        #expect(adopted[0].state == .queued)
        let times = P1CGCLockedBox([
            Date(timeIntervalSince1970: 221),
            Date(timeIntervalSince1970: 230),
        ])
        let resumed = try CoachTurnProcessor(
            database: database,
            workerId: "new-worker",
            clock: { times.withValue { $0.removeFirst() } },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                .question(prompt: "Recovered", recommendation: "Continue", reason: "Persisted authority")
            }
        )
        #expect(try await resumed.runNext())
        #expect(try p1cGCRequire(CoachUnderstandingStore(database: database).question(id: p1cGCQuestion1ID)).prompt == "Recovered")
    }

    @Test func coachRenewalHandsLatestClaimToTerminalCommit() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("renewal")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let initial = try p1cGCClaimCoach(database, at: 150)
        let envelope = try p1cGCWorkerEnvelope(database: database, claim: initial)
        let renewed = try DurableWorkStore(database: database).renewLease(
            claim: initial,
            now: Date(timeIntervalSince1970: 160),
            leaseDuration: 60
        )
        let result = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: envelope,
                goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
                claim: WorkClaimV1(claim: renewed),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "Renewed", recommendation: "Latest claim", reason: "CAS"
            ),
            terminalNow: Date(timeIntervalSince1970: 170)
        )
        #expect(p1cGCResultVersion(result, .durableWork) == renewed.version + 1)
        #expect(try p1cGCRequire(store.question(id: p1cGCQuestion1ID)).prompt == "Renewed")
    }

    @Test func coachTerminalTimeIsMonotonicAfterRenewalAndBackoffStartsAtFailure() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("terminal-time")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, work, _) = try p1cGCOpen(database)
        let initial = try p1cGCClaimCoach(database, at: 150)
        let envelope = try p1cGCWorkerEnvelope(database: database, claim: initial)
        let renewed = try DurableWorkStore(database: database).renewLease(
            claim: initial,
            now: Date(timeIntervalSince1970: 170),
            leaseDuration: 60
        )
        let sealed = try CanonicalContractCodingV1.decode(
            CoachTurnWorkInputV1.self,
            from: Data(work.inputJson.utf8)
        )
        let failure = try ControlWorkerProviderFailureV1(
            code: "delayed_failure",
            safeMessage: "retry",
            disposition: .transient
        )
        let command = try RecordCoachWorkFailureCommandV1(
            envelope: envelope,
            goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
            claim: WorkClaimV1(claim: renewed),
            expectedUnderstandingEventVersion: sealed.expectedUnderstandingEventVersion,
            failure: failure,
            failureScope: sealed.failureScope,
            confirmedUnderstanding: sealed.confirmedUnderstanding,
            failureBranch: .retryScheduledClarifyingGoal
        )
        let before = try p1cGCCounts(database)
        #expect(throws: ControlWorkerTerminalTimeError.self) {
            _ = try store.recordCoachWorkFailure(
                command,
                terminalNow: Date(timeIntervalSince1970: 169)
            )
        }
        #expect(try p1cGCCounts(database) == before)
        let result = try store.recordCoachWorkFailure(
            command,
            terminalNow: Date(timeIntervalSince1970: 180)
        )
        let notBefore = result.times.first(where: { $0.kind == .notBefore })?.value
        #expect(notBefore == Date(timeIntervalSince1970: 185))
    }

    @Test func coachWorkerCancellationLeavesRecoverableRunningWork() async throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("worker-cancel")
        _ = try p1cGCSeedGoal(database)
        _ = try p1cGCOpen(database)
        let entered = P1CGCLockedBox(false)
        let processor = try CoachTurnProcessor(
            database: database,
            workerId: "cancel-worker",
            clock: { Date(timeIntervalSince1970: 150) },
            sleep: { _ in try await Task.sleep(for: .seconds(600)) },
            provider: { _ in
                entered.withValue { $0 = true }
                do {
                    try await Task.sleep(for: .seconds(600))
                } catch {
                    return .canceled
                }
                return .canceled
            }
        )
        let task = Task { try await processor.runNext() }
        while !entered.value { await Task.yield() }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("canceled worker unexpectedly completed")
        } catch is CancellationError {
        }
        let work = try await database.pool.read { db in
            try p1cGCRequire(DurableWorkRecord
                .filter(Column("kind") == DurableWorkKind.coach.rawValue)
                .fetchOne(db))
        }
        #expect(work.state == .running)
        #expect(work.leaseOwner == "cancel-worker")
        #expect(try CoachUnderstandingStore(database: database).question(id: p1cGCQuestion1ID) == nil)
    }

    @Test func coachTerminalMutationRollbackRestoresWorkSessionGoal() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("terminal-rollback")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, work, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        try database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1c_force_coach_rollback
                BEFORE UPDATE ON coach_session
                BEGIN
                  SELECT RAISE(ABORT, 'forced coach rollback');
                END
                """)
        }
        let before = try p1cGCCounts(database)
        #expect(throws: DatabaseError.self) {
            _ = try store.recordQuestion(
                RecordCoachQuestionCommandV1(
                    envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                    goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
                    claim: WorkClaimV1(claim: claim),
                    decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                    prompt: "Rollback", recommendation: "Rollback", reason: "Rollback"
                ),
                terminalNow: Date(timeIntervalSince1970: 160)
            )
        }
        #expect(try p1cGCCounts(database) == before)
        let restored = try database.pool.read { db in
            try p1cGCRequire(DurableWorkRecord.fetchOne(db, key: work.id))
        }
        #expect(restored.state == .running)
        #expect(try p1cGCRequire(store.session(id: session.id)) == session)
        #expect(try p1cGCRequire(store.goal(id: goal.id)) == goal)
    }

    @Test func understandingEditAlwaysCreatesNewVersion() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("understanding-edit")
        let (store, readyGoal, confirmedSession, confirmed) = try p1cGCConfirmFirst(database)
        _ = try store.requestUnderstandingRevision(
            RequestUnderstandingRevisionCommandV1(
                envelope: p1cGCUserEnvelope(key: "edit-reopen", at: 190),
                goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(confirmedSession),
                understanding: p1cGCUnderstandingHead(database: database, value: confirmed),
                revisionBranch: .reopenConfirmed,
                nextQuestionId: p1cGCQuestion2ID
            )
        )
        let reopened = try p1cGCRequire(store.session(id: p1cGCSessionID))
        let claim = try p1cGCClaimCoach(database, at: 200)
        _ = try store.proposeUnderstanding(
            ProposeUnderstandingCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(reopened),
                claim: WorkClaimV1(claim: claim),
                expectedUnderstandingEventVersion: 3,
                content: p1cGCContent("v2")
            ),
            terminalNow: Date(timeIntervalSince1970: 210)
        )
        let first = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
        let second = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 2))
        #expect(first.status == .confirmed)
        #expect(second.status == .draft)
        #expect(first.contentHash != second.contentHash)
    }

    @Test func requestConfirmationDoesNotRewriteUnderstandingBody() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("request-no-rewrite")
        let (store, goal, session, draft) = try p1cGCProposeDraft(database)
        let beforeContent = draft.content
        let beforeHash = draft.contentHash
        _ = try store.requestConfirmation(RequestCoachConfirmationCommandV1(
            envelope: CommandEnvelopeV1(
                idempotencyKey: "request-only-status",
                actorType: .coach,
                actorId: p1CCoachActorId,
                deviceId: nil,
                correlationId: "trace",
                causationId: nil,
                occurredAt: Date(timeIntervalSince1970: 170)
            ),
            goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
            understanding: p1cGCUnderstandingHead(database: database, value: draft)
        ))
        let after = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
        #expect(after.status == .awaitingConfirmation)
        #expect(after.content == beforeContent)
        #expect(after.contentHash == beforeHash)
    }

    @Test func requestUnderstandingRevisionWithdrawsOrReopensAndEnqueuesTurn() throws {
        requireP1CGoalCoachCapability()
        for mode in [
            UnderstandingRevisionBranchV1.withdrawDraft,
            .withdrawAwaitingConfirmation,
            .reopenConfirmed,
        ] {
            let database = try p1cGCDatabase("revision-\(mode.rawValue)")
            let store: CoachUnderstandingStore
            let goal: GoalControllerRecord
            let session: CoachSessionRecord
            let understanding: UnderstandingCardVersionRecord
            switch mode {
            case .withdrawDraft:
                (store, goal, session, understanding) = try p1cGCProposeDraft(database)
            case .withdrawAwaitingConfirmation:
                let values = try p1cGCProposeDraft(database)
                store = values.0
                goal = values.1
                _ = try store.requestConfirmation(RequestCoachConfirmationCommandV1(
                    envelope: CommandEnvelopeV1(
                        idempotencyKey: "awaiting-revision-setup",
                        actorType: .coach, actorId: p1CCoachActorId,
                        deviceId: nil, correlationId: "trace", causationId: nil,
                        occurredAt: Date(timeIntervalSince1970: 170)
                    ),
                    goal: p1cGCHead(goal), coach: p1cGCCoachHead(values.2),
                    understanding: p1cGCUnderstandingHead(database: database, value: values.3)
                ))
                session = try p1cGCRequire(store.session(id: p1cGCSessionID))
                understanding = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
            case .reopenConfirmed:
                (store, goal, session, understanding) = try p1cGCConfirmFirst(database)
            }
            _ = try store.requestUnderstandingRevision(
                RequestUnderstandingRevisionCommandV1(
                    envelope: p1cGCUserEnvelope(key: "revision-\(mode.rawValue)", at: 190),
                    goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
                    understanding: p1cGCUnderstandingHead(database: database, value: understanding),
                    revisionBranch: mode,
                    nextQuestionId: p1cGCQuestion2ID
                )
            )
            let revisedSession = try p1cGCRequire(store.session(id: p1cGCSessionID))
            let work = try p1cGCRequire(DurableWorkStore(database: database).activeWork(
                kind: .coach, aggregateType: "goal", aggregateId: p1cGCGoalID
            ))
            let sealed = try CanonicalContractCodingV1.decode(
                CoachTurnWorkInputV1.self,
                from: Data(work.inputJson.utf8)
            )
            #expect(revisedSession.status == .interviewing)
            #expect(sealed.nextQuestionId == p1cGCQuestion2ID)
            let after = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1))
            #expect(after.status == (mode == .reopenConfirmed ? .confirmed : .withdrawn))
        }
    }

    @Test func coachCannotConfirmUnderstanding() throws {
        requireP1CGoalCoachCapability()
        let coachEnvelope = try CommandEnvelopeV1(
            idempotencyKey: "coach-cannot-confirm",
            actorType: .coach,
            actorId: p1CCoachActorId,
            deviceId: nil,
            correlationId: "trace",
            causationId: nil,
            occurredAt: Date(timeIntervalSince1970: 1)
        )
        #expect(throws: P1CommandAuthorizationError.self) {
            _ = try ConfirmUnderstandingCommandV1(
                envelope: coachEnvelope,
                goal: GoalHeadV1(goalId: p1cGCGoalID, campId: p1cGCCampID, expectedGoalVersion: 1),
                coach: CoachHeadV1(sessionId: p1cGCSessionID, expectedSessionVersion: 1),
                understanding: UnderstandingHeadV1(
                    understandingId: p1cGCGoalID,
                    expectedContentVersion: 1,
                    contentHash: String(repeating: "a", count: 64),
                    expectedUnderstandingEventVersion: 1
                )
            )
        }
    }

    @Test func confirmUnderstandingSupersedesPriorVersionAndMakesGoalReady() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("confirm-v2")
        let (store, readyGoal, confirmedSession, confirmed) = try p1cGCConfirmFirst(database)
        _ = try store.requestUnderstandingRevision(RequestUnderstandingRevisionCommandV1(
            envelope: p1cGCUserEnvelope(key: "confirm-v2-reopen", at: 190),
            goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(confirmedSession),
            understanding: p1cGCUnderstandingHead(database: database, value: confirmed),
            revisionBranch: .reopenConfirmed,
            nextQuestionId: p1cGCQuestion2ID
        ))
        let reopened = try p1cGCRequire(store.session(id: p1cGCSessionID))
        let claim = try p1cGCClaimCoach(database, at: 200)
        _ = try store.proposeUnderstanding(
            ProposeUnderstandingCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(reopened),
                claim: WorkClaimV1(claim: claim),
                expectedUnderstandingEventVersion: 3,
                content: p1cGCContent("replacement")
            ),
            terminalNow: Date(timeIntervalSince1970: 210)
        )
        let draftSession = try p1cGCRequire(store.session(id: p1cGCSessionID))
        let draft = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 2))
        _ = try store.requestConfirmation(RequestCoachConfirmationCommandV1(
            envelope: CommandEnvelopeV1(
                idempotencyKey: "confirm-v2-request", actorType: .coach,
                actorId: p1CCoachActorId, deviceId: nil,
                correlationId: "trace", causationId: nil,
                occurredAt: Date(timeIntervalSince1970: 220)
            ),
            goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(draftSession),
            understanding: p1cGCUnderstandingHead(database: database, value: draft)
        ))
        let awaitingSession = try p1cGCRequire(store.session(id: p1cGCSessionID))
        let awaiting = try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 2))
        _ = try store.confirmUnderstanding(ConfirmUnderstandingCommandV1(
            envelope: p1cGCUserEnvelope(key: "confirm-v2-final", at: 230),
            goal: p1cGCHead(readyGoal), coach: p1cGCCoachHead(awaitingSession),
            understanding: p1cGCUnderstandingHead(database: database, value: awaiting)
        ))
        let resultGoal = try p1cGCRequire(store.goal(id: p1cGCGoalID))
        #expect(resultGoal.status == .ready)
        #expect(resultGoal.currentUnderstandingVersion == 2)
        #expect(try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 1)).status == .superseded)
        #expect(try p1cGCRequire(store.understanding(id: p1cGCGoalID, version: 2)).status == .confirmed)
    }

    @Test func coachRestartRestoresExactlyOneOpenQuestionWithoutChatMemory() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("restart-open-question")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let claim = try p1cGCClaimCoach(database)
        _ = try store.recordQuestion(
            RecordCoachQuestionCommandV1(
                envelope: p1cGCWorkerEnvelope(database: database, claim: claim),
                goal: p1cGCHead(goal), coach: p1cGCCoachHead(session),
                claim: WorkClaimV1(claim: claim),
                decisionKey: "decision:v1:\(p1cGCQuestion1ID)",
                prompt: "Persist me", recommendation: "Resume me", reason: "No chat memory"
            ),
            terminalNow: Date(timeIntervalSince1970: 160)
        )
        let restarted = CoachUnderstandingStore(database: database)
        let snapshot = try restarted.resumeSession(goalId: p1cGCGoalID)
        #expect(snapshot.openQuestion?.prompt == "Persist me")
        #expect(snapshot.session.pendingQuestionId == snapshot.openQuestion?.id)
    }

    @Test func goalAbandonAndFailCancelActiveControlWorkAtomically() throws {
        requireP1CGoalCoachCapability()
        for failed in [false, true] {
            let database = try p1cGCDatabase("terminal-cancel-\(failed)")
            let goal = try p1cGCSeedGoal(database)
            let (store, session, work, _) = try p1cGCOpen(database)
            if failed {
                _ = try store.fail(FailGoalCommandV1(
                    envelope: CommandEnvelopeV1(
                        idempotencyKey: "explicit-fail", actorType: .coach,
                        actorId: p1CCoachActorId, deviceId: nil,
                        correlationId: "trace", causationId: nil,
                        occurredAt: Date(timeIntervalSince1970: 150)
                    ),
                    goal: p1cGCHead(goal),
                    sessionBranch: .expected(
                        sessionId: session.id,
                        expectedSessionVersion: session.aggregateVersion
                    )
                ))
            } else {
                _ = try store.abandon(AbandonGoalCommandV1(
                    envelope: p1cGCUserEnvelope(key: "explicit-abandon", at: 150),
                    goal: p1cGCHead(goal),
                    sessionBranch: .expected(
                        sessionId: session.id,
                        expectedSessionVersion: session.aggregateVersion
                    )
                ))
            }
            let terminalGoal = try p1cGCRequire(store.goal(id: goal.id))
            let terminalSession = try p1cGCRequire(store.session(id: session.id))
            let canceledWork = try database.pool.read { db in
                try p1cGCRequire(DurableWorkRecord.fetchOne(db, key: work.id))
            }
            #expect(terminalGoal.status == (failed ? .failed : .abandoned))
            #expect(terminalSession.status == (failed ? .failed : .canceled))
            #expect(canceledWork.state == .canceled)
        }
    }

    @Test func goalAbandonReplayUsesSealedSessionBranchAfterProjectionChanges() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("abandon-replay")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let command = try AbandonGoalCommandV1(
            envelope: p1cGCUserEnvelope(key: "abandon-replay", at: 150),
            goal: p1cGCHead(goal),
            sessionBranch: .expected(
                sessionId: session.id,
                expectedSessionVersion: session.aggregateVersion
            )
        )
        let first = try store.abandon(command)
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE goal_controller SET title='later projection text' WHERE id=?",
                arguments: [goal.id]
            )
        }
        let before = try p1cGCCounts(database)
        #expect(try store.abandon(command) == first)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func goalFailReplayUsesSealedSessionBranchAfterProjectionChanges() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("fail-replay")
        let goal = try p1cGCSeedGoal(database)
        let (store, session, _, _) = try p1cGCOpen(database)
        let command = try FailGoalCommandV1(
            envelope: CommandEnvelopeV1(
                idempotencyKey: "fail-replay", actorType: .coach,
                actorId: p1CCoachActorId, deviceId: nil,
                correlationId: "trace", causationId: nil,
                occurredAt: Date(timeIntervalSince1970: 150)
            ),
            goal: p1cGCHead(goal),
            sessionBranch: .expected(
                sessionId: session.id,
                expectedSessionVersion: session.aggregateVersion
            )
        )
        let first = try store.fail(command)
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE coach_session SET traceId='later-trace' WHERE id=?",
                arguments: [session.id]
            )
        }
        let before = try p1cGCCounts(database)
        #expect(try store.fail(command) == first)
        #expect(try p1cGCCounts(database) == before)
    }

    @Test func goalReadyRemainsContractFreeBeforeExplicitActivation() throws {
        requireP1CGoalCoachCapability()
        let database = try p1cGCDatabase("v14-only-ready")
        let (_, goal, _, understanding) = try p1cGCConfirmFirst(database)
        let outcomeTable = try database.pool.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='outcome_contract_version'"
            )
        }
        #expect(outcomeTable == "outcome_contract_version")
        #expect(goal.status == .ready)
        #expect(goal.currentUnderstandingId == understanding.id)
        #expect(goal.currentOutcomeContractId == nil)
        #expect(goal.currentOutcomeContractVersion == nil)
    }
}
