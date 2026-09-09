import Foundation
import GRDB

package struct CoachUnderstandingStore: Sendable {
    private let database: AppDatabase
    private let eventStore: DomainEventStore

    package init(database: AppDatabase) {
        self.database = database
        eventStore = DomainEventStore(database: database)
    }

    package func goal(id: String) throws -> GoalControllerRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try GoalControllerRecord.fetchOne(db, key: id)
        }
    }

    package func session(id: String) throws -> CoachSessionRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try CoachSessionRecord.fetchOne(db, key: id)
        }
    }

    package func question(id: String) throws -> CoachQuestionRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try CoachQuestionRecord.fetchOne(db, key: id)
        }
    }

    package func understanding(
        id: String,
        version: Int
    ) throws -> UnderstandingCardVersionRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        return try database.pool.read { db in
            try UnderstandingCardVersionRecord.fetchOne(
                db,
                key: ["id": id, "version": version]
            )
        }
    }

    package func resumeSession(goalId: String) throws -> CoachSessionSnapshotV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        return try database.pool.read { db in
            let goal = try Self.requireGoal(id: goalId, in: db)
            let session = try Self.requireSoleSession(goalId: goalId, in: db)
            let openQuestions = try CoachQuestionRecord
                .filter(Column("sessionId") == session.id)
                .filter(Column("state") == CoachQuestionStateV1.open.rawValue)
                .fetchAll(db)
            guard openQuestions.count <= 1,
                  session.pendingQuestionId == openQuestions.first?.id
            else {
                throw CoachSessionIntegrityError()
            }
            let understanding = try Self.currentUnderstanding(
                goal: goal,
                in: db
            )
            return CoachSessionSnapshotV1(
                goal: goal,
                session: session,
                openQuestion: openQuestions.first,
                currentUnderstanding: understanding
            )
        }
    }

    package func openCoachSession(
        _ command: OpenCoachSessionCommandV1
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.openSessionReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.sessionId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: 0
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachOpenSession,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                guard .clarifying == goal.status,
                      goal.currentUnderstandingId == nil,
                      goal.currentUnderstandingVersion == nil,
                      command.sourceInputId == goal.sourceInputId
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                let sessions = try Self.sessions(goalId: goal.id, in: db)
                guard sessions.isEmpty else {
                    if sessions.count == 1 {
                        throw CoachSessionAlreadyExistsError()
                    }
                    throw CoachSessionIntegrityError()
                }
                let session = try CoachSessionRecord(
                    id: command.sessionId,
                    goalId: goal.id,
                    inputId: command.sourceInputId,
                    status: .interviewing,
                    currentUnderstandingVersion: nil,
                    pendingQuestionId: nil,
                    traceId: command.envelope.correlationId,
                    aggregateVersion: 1,
                    createdAt: command.envelope.occurredAt,
                    updatedAt: command.envelope.occurredAt
                )
                try session.insert(db)
                let work = try Self.enqueueCoachTurn(
                    goal: goal,
                    session: session,
                    nextQuestionId: command.nextQuestionId,
                    prepared: prepared,
                    expectedUnderstandingEventVersion: 0,
                    failureScope: .clarifyingGoal,
                    confirmedUnderstanding: nil,
                    in: db
                )
                return try Self.makeCoachCommand(
                    branch: .openCoachSession,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    nextQuestionId: command.nextQuestionId,
                    work: work
                )
            }
        }
    }

    package func recordQuestion(
        _ command: RecordCoachQuestionCommandV1,
        terminalNow: Date
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.recordQuestionReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachRecordQuestion,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .interviewing,
                      session.pendingQuestionId == nil
                else { throw P1ContractValidationError.invalidMembership }
                let graph = try Self.requireCoachClaimGraph(
                    claim: command.claim,
                    envelope: command.envelope,
                    goal: goal,
                    session: session,
                    in: db
                )
                try Self.validateTerminalTime(
                    terminalNow,
                    work: graph.work,
                    attempt: graph.attempt
                )
                guard command.decisionKey == graph.input.decisionKey,
                      graph.input.decisionKey == (try CoachTurnWorkInputV1
                        .decisionKey(nextQuestionId: graph.input.nextQuestionId))
                else { throw P1ContractValidationError.invalidMembership }
                let openCount = try Self.openQuestionCount(
                    sessionId: session.id,
                    in: db
                )
                guard openCount == 0 else {
                    throw CoachSessionIntegrityError()
                }
                let question = try CoachQuestionRecord(
                    id: graph.input.nextQuestionId,
                    sessionId: session.id,
                    decisionKey: graph.input.decisionKey,
                    prompt: command.prompt,
                    recommendation: command.recommendation,
                    reason: command.reason,
                    answer: nil,
                    state: .open,
                    createdAt: terminalNow,
                    answeredAt: nil
                )
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.status = .waitingForUser
                session.pendingQuestionId = question.id
                session.updatedAt = terminalNow
                let work = try DurableWorkStore.complete(
                    claim: command.claim.durableClaim,
                    outputJson: nil,
                    now: terminalNow,
                    businessMutation: { db, _ in
                        try question.insert(db)
                        try session.update(db)
                    },
                    in: db
                )
                return try Self.makeCoachCommand(
                    branch: .recordCoachQuestion,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    currentQuestionId: question.id,
                    work: work,
                    workInputHash: graph.work.inputHash,
                    attemptCount: work.attempt
                )
            }
        }
    }

    package func answerQuestion(
        _ command: AnswerCoachQuestionCommandV1
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.answerQuestionReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachAnswerQuestion,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .waitingForUser,
                      session.pendingQuestionId == command.currentQuestionId,
                      var question = try CoachQuestionRecord.fetchOne(
                        db,
                        key: command.currentQuestionId
                      ),
                      question.sessionId == session.id,
                      question.state == .open,
                      question.answer == nil,
                      question.answeredAt == nil
                else { throw P1ContractValidationError.invalidMembership }
                let authority = try Self.failureAuthority(goal: goal, in: db)
                guard command.expectedUnderstandingEventVersion
                        == authority.expectedUnderstandingEventVersion
                else { throw UnderstandingIntegrityError() }
                question.answer = command.answer
                question.state = .answered
                question.answeredAt = command.envelope.occurredAt
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.status = .interviewing
                session.pendingQuestionId = nil
                session.updatedAt = command.envelope.occurredAt
                try question.update(db)
                try session.update(db)
                let work = try Self.enqueueCoachTurn(
                    goal: goal,
                    session: session,
                    nextQuestionId: command.nextQuestionId,
                    prepared: prepared,
                    expectedUnderstandingEventVersion:
                        authority.expectedUnderstandingEventVersion,
                    failureScope: authority.scope,
                    confirmedUnderstanding: authority.confirmedUnderstanding,
                    in: db
                )
                return try Self.makeCoachCommand(
                    branch: .answerCoachQuestion,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    currentQuestionId: question.id,
                    nextQuestionId: command.nextQuestionId,
                    work: work
                )
            }
        }
    }

    package func proposeUnderstanding(
        _ command: ProposeUnderstandingCommandV1,
        terminalNow: Date
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.proposeUnderstandingReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            understandingId: command.goal.goalId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion,
            expectedUnderstandingEventVersion:
                command.expectedUnderstandingEventVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachProposeUnderstanding,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .interviewing,
                      session.pendingQuestionId == nil
                else { throw P1ContractValidationError.invalidMembership }
                let graph = try Self.requireCoachClaimGraph(
                    claim: command.claim,
                    envelope: command.envelope,
                    goal: goal,
                    session: session,
                    in: db
                )
                try Self.validateTerminalTime(
                    terminalNow,
                    work: graph.work,
                    attempt: graph.attempt
                )
                guard graph.input.expectedUnderstandingEventVersion
                        == command.expectedUnderstandingEventVersion,
                      try Self.understandingEventVersion(
                        id: goal.id,
                        in: db
                      ) == command.expectedUnderstandingEventVersion
                else { throw UnderstandingIntegrityError() }
                let contentVersion = try Self.nextUnderstandingContentVersion(
                    goalId: goal.id,
                    in: db
                )
                let understanding = try UnderstandingCardVersionRecord(
                    id: goal.id,
                    version: contentVersion,
                    goalId: goal.id,
                    content: command.content,
                    status: .draft,
                    createdByActorId: p1CCoachActorId,
                    confirmedByActorId: nil,
                    confirmedAt: nil,
                    createdAt: terminalNow
                )
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.currentUnderstandingVersion = understanding.version
                session.updatedAt = terminalNow
                let work = try DurableWorkStore.complete(
                    claim: command.claim.durableClaim,
                    outputJson: nil,
                    now: terminalNow,
                    businessMutation: { db, _ in
                        try understanding.insert(db)
                        try session.update(db)
                    },
                    in: db
                )
                return try Self.makeCoachCommand(
                    branch: .proposeUnderstanding,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    understanding: understanding,
                    work: work,
                    workInputHash: graph.work.inputHash,
                    understandingEventVersion: try CanonicalContractCodingV1
                        .checkedIncrement(command.expectedUnderstandingEventVersion),
                    attemptCount: work.attempt
                )
            }
        }
    }

    package func requestConfirmation(
        _ command: RequestCoachConfirmationCommandV1
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.requestConfirmationReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            understandingId: command.understanding.understandingId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion,
            expectedUnderstandingEventVersion:
                command.understanding.expectedUnderstandingEventVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachRequestConfirmation,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                var understanding = try Self.requireUnderstanding(
                    command.understanding,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .interviewing,
                      session.pendingQuestionId == nil,
                      session.currentUnderstandingVersion
                        == understanding.version,
                      understanding.status == .draft
                else { throw P1ContractValidationError.invalidMembership }
                understanding.status = .awaitingConfirmation
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.status = .readyForConfirmation
                session.updatedAt = command.envelope.occurredAt
                try understanding.update(db)
                try session.update(db)
                return try Self.makeCoachCommand(
                    branch: .requestConfirmation,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    understanding: understanding,
                    understandingEventVersion: try CanonicalContractCodingV1
                        .checkedIncrement(
                            command.understanding
                                .expectedUnderstandingEventVersion
                        )
                )
            }
        }
    }

    package func confirmUnderstanding(
        _ command: ConfirmUnderstandingCommandV1
    ) throws -> CampSafeCommandResultV1 {
        let replayPlan = try Self.confirmUnderstandingReplayPlan(
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            understandingId: command.understanding.understandingId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion,
            expectedUnderstandingEventVersion:
                command.understanding.expectedUnderstandingEventVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachConfirmUnderstanding,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                var understanding = try Self.requireUnderstanding(
                    command.understanding,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .readyForConfirmation,
                      session.pendingQuestionId == nil,
                      session.currentUnderstandingVersion
                        == understanding.version,
                      understanding.status == .awaitingConfirmation,
                      .clarifying == goal.status || .ready == goal.status
                else { throw P1ContractValidationError.invalidMembership }
                if let oldId = goal.currentUnderstandingId,
                   let oldVersion = goal.currentUnderstandingVersion
                {
                    guard oldId == goal.id,
                          var prior = try UnderstandingCardVersionRecord
                            .fetchOne(
                                db,
                                key: ["id": oldId, "version": oldVersion]
                            ),
                          prior.status == .confirmed,
                          prior.contentHash == (try CanonicalContractCodingV1
                            .hash(prior.content))
                    else { throw UnderstandingIntegrityError() }
                    prior.status = .superseded
                    try prior.update(db)
                }
                understanding.status = .confirmed
                understanding.confirmedByActorId = command.envelope.actorId
                understanding.confirmedAt = command.envelope.occurredAt
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.status = .confirmed
                session.updatedAt = command.envelope.occurredAt
                goal.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(goal.aggregateVersion)
                goal[keyPath: \.status] = .ready
                goal.currentUnderstandingId = understanding.id
                goal.currentUnderstandingVersion = understanding.version
                goal.updatedAt = command.envelope.occurredAt
                try understanding.update(db)
                try session.update(db)
                try goal.update(db)
                return try Self.makeCoachCommand(
                    branch: .confirmUnderstanding,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    understanding: understanding,
                    understandingEventVersion: try CanonicalContractCodingV1
                        .checkedIncrement(
                            command.understanding
                                .expectedUnderstandingEventVersion
                        ),
                    confirmedAt: command.envelope.occurredAt
                )
            }
        }
    }

    package func requestUnderstandingRevision(
        _ command: RequestUnderstandingRevisionCommandV1
    ) throws -> CampSafeCommandResultV1 {
        let resultBranch: P1ResultBranchV1 = command.revisionBranch
            == .reopenConfirmed
            ? .requestRevisionConfirmed : .requestRevisionUnconfirmed
        let replayPlan = try Self.requestRevisionReplayPlan(
            branch: resultBranch,
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            understandingId: command.understanding.understandingId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion,
            expectedUnderstandingEventVersion:
                command.understanding.expectedUnderstandingEventVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachRequestUnderstandingRevision,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                let goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                var understanding = try Self.requireUnderstanding(
                    command.understanding,
                    goalId: goal.id,
                    in: db
                )
                guard session.currentUnderstandingVersion
                        == understanding.version,
                      session.pendingQuestionId == nil
                else { throw P1ContractValidationError.invalidMembership }

                let resultingEventVersion: Int
                switch command.revisionBranch {
                case .withdrawDraft:
                    guard session.status == .interviewing,
                          understanding.status == .draft
                    else { throw P1ContractValidationError.invalidMembership }
                    understanding.status = .withdrawn
                    try understanding.update(db)
                    resultingEventVersion = try CanonicalContractCodingV1
                        .checkedIncrement(
                            command.understanding
                                .expectedUnderstandingEventVersion
                        )
                case .withdrawAwaitingConfirmation:
                    guard session.status == .readyForConfirmation,
                          understanding.status == .awaitingConfirmation
                    else { throw P1ContractValidationError.invalidMembership }
                    understanding.status = .withdrawn
                    try understanding.update(db)
                    resultingEventVersion = try CanonicalContractCodingV1
                        .checkedIncrement(
                            command.understanding
                                .expectedUnderstandingEventVersion
                        )
                case .reopenConfirmed:
                    guard .ready == goal.status,
                          goal.currentUnderstandingId == understanding.id,
                          goal.currentUnderstandingVersion
                            == understanding.version,
                          understanding.status == .confirmed,
                          session.status == .confirmed
                            || session.status == .failed
                    else { throw P1ContractValidationError.invalidMembership }
                    resultingEventVersion = command.understanding
                        .expectedUnderstandingEventVersion
                }
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.status = .interviewing
                session.pendingQuestionId = nil
                session.updatedAt = command.envelope.occurredAt
                try session.update(db)
                let authority: CoachFailureAuthority
                if .clarifying == goal.status {
                    guard goal.currentUnderstandingId == nil,
                          goal.currentUnderstandingVersion == nil
                    else { throw UnderstandingIntegrityError() }
                    authority = CoachFailureAuthority(
                        scope: .clarifyingGoal,
                        confirmedUnderstanding: nil,
                        expectedUnderstandingEventVersion:
                            resultingEventVersion
                    )
                } else {
                    authority = try Self.failureAuthority(goal: goal, in: db)
                    guard authority.expectedUnderstandingEventVersion
                            == resultingEventVersion
                    else { throw UnderstandingIntegrityError() }
                }
                let work = try Self.enqueueCoachTurn(
                    goal: goal,
                    session: session,
                    nextQuestionId: command.nextQuestionId,
                    prepared: prepared,
                    expectedUnderstandingEventVersion: resultingEventVersion,
                    failureScope: authority.scope,
                    confirmedUnderstanding: authority.confirmedUnderstanding,
                    in: db
                )
                return try Self.makeCoachCommand(
                    branch: resultBranch,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    nextQuestionId: command.nextQuestionId,
                    understanding: understanding,
                    work: work,
                    understandingEventVersion: resultingEventVersion
                )
            }
        }
    }

    package func recordCoachWorkFailure(
        _ command: RecordCoachWorkFailureCommandV1,
        terminalNow: Date
    ) throws -> CampSafeCommandResultV1 {
        let resultBranch = try Self.resultBranch(command.failureBranch)
        let replayPlan = try Self.recordWorkFailureReplayPlan(
            branch: resultBranch,
            goalId: command.goal.goalId,
            sessionId: command.coach.sessionId,
            campId: command.goal.campId,
            expectedGoalVersion: command.goal.expectedGoalVersion,
            expectedSessionVersion: command.coach.expectedSessionVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .coachRecordWorkFailure,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var goal = try Self.requireGoal(command.goal, in: db)
                var session = try Self.requireSession(
                    command.coach,
                    goalId: goal.id,
                    in: db
                )
                guard session.status == .interviewing,
                      session.pendingQuestionId == nil
                else { throw P1ContractValidationError.invalidMembership }
                let graph = try Self.requireCoachClaimGraph(
                    claim: command.claim,
                    envelope: command.envelope,
                    goal: goal,
                    session: session,
                    in: db
                )
                try Self.validateTerminalTime(
                    terminalNow,
                    work: graph.work,
                    attempt: graph.attempt
                )
                guard graph.input.failureScope == command.failureScope,
                      graph.input.confirmedUnderstanding
                        == command.confirmedUnderstanding,
                      graph.input.expectedUnderstandingEventVersion
                        == command.expectedUnderstandingEventVersion,
                      try CoachWorkFailureBranchV1.derive(
                        scope: graph.input.failureScope,
                        failure: command.failure,
                        attempt: graph.work.attempt,
                        maxAttempts: graph.work.maxAttempts
                      ) == command.failureBranch
                else { throw P1ContractValidationError.invalidMembership }
                let authority = try Self.failureAuthority(goal: goal, in: db)
                guard authority.scope == command.failureScope,
                      authority.confirmedUnderstanding
                        == command.confirmedUnderstanding,
                      authority.expectedUnderstandingEventVersion
                        == command.expectedUnderstandingEventVersion
                else { throw UnderstandingIntegrityError() }
                let resolution = try DurableWorkStore.retryOrFail(
                    claim: command.claim.durableClaim,
                    failure: command.failure.durableFailure(),
                    now: terminalNow,
                    terminalBusinessMutation: { _, _ in },
                    in: db
                )
                session.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(session.aggregateVersion)
                session.updatedAt = terminalNow
                let work: DurableWorkRecord
                let notBefore: Date?
                switch resolution {
                case let .retryScheduled(resultingWork, date):
                    guard command.failureBranch
                            == .retryScheduledClarifyingGoal
                            || command.failureBranch
                                == .retryScheduledReadyRevision
                    else { throw P1ContractValidationError.invalidMembership }
                    session.status = .interviewing
                    work = resultingWork
                    notBefore = date
                case let .failed(resultingWork):
                    guard command.failureBranch == .terminalClarifyingGoal
                            || command.failureBranch
                                == .terminalReadyGoalPreserved
                    else { throw P1ContractValidationError.invalidMembership }
                    session.status = .failed
                    work = resultingWork
                    notBefore = nil
                    if command.failureBranch == .terminalClarifyingGoal {
                        guard .clarifying == goal.status else {
                            throw P1ContractValidationError.invalidMembership
                        }
                        goal.aggregateVersion = try CanonicalContractCodingV1
                            .checkedIncrement(goal.aggregateVersion)
                        goal[keyPath: \.status] = .failed
                        goal.updatedAt = terminalNow
                        try goal.update(db)
                    }
                }
                try session.update(db)
                let understanding = try authority.confirmedUnderstanding.map {
                    try Self.requireUnderstanding($0, goalId: goal.id, in: db)
                }
                return try Self.makeCoachCommand(
                    branch: resultBranch,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session,
                    understanding: understanding,
                    work: work,
                    workInputHash: graph.work.inputHash,
                    understandingEventVersion:
                        command.failureScope == .readyRevisionSessionOnly
                            ? command.expectedUnderstandingEventVersion : nil,
                    attemptCount: work.attempt,
                    notBefore: notBefore
                )
            }
        }
    }

    package func abandon(
        _ command: AbandonGoalCommandV1
    ) throws -> CampSafeCommandResultV1 {
        try terminalGoal(
            commandType: .goalAbandon,
            goal: command.goal,
            sessionBranch: command.sessionBranch,
            envelope: command.envelope,
            payload: command,
            failed: false
        )
    }

    package func fail(
        _ command: FailGoalCommandV1
    ) throws -> CampSafeCommandResultV1 {
        try terminalGoal(
            commandType: .goalFail,
            goal: command.goal,
            sessionBranch: command.sessionBranch,
            envelope: command.envelope,
            payload: command,
            failed: true
        )
    }

    package static func openSessionReplayPlan(
        goalId: String,
        sessionId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try sessionPlan(
            branch: .openCoachSession,
            commandType: .coachOpenSession,
            goalId: goalId,
            sessionId: sessionId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            eventType: .coachSessionOpened,
            auditCode: .coachSessionOpened
        )
    }

    package static func recordQuestionReplayPlan(
        goalId: String,
        sessionId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try sessionPlan(
            branch: .recordCoachQuestion,
            commandType: .coachRecordQuestion,
            goalId: goalId,
            sessionId: sessionId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            eventType: .coachQuestionRecorded,
            auditCode: .coachQuestionRecorded
        )
    }

    package static func answerQuestionReplayPlan(
        goalId: String,
        sessionId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try sessionPlan(
            branch: .answerCoachQuestion,
            commandType: .coachAnswerQuestion,
            goalId: goalId,
            sessionId: sessionId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            eventType: .coachQuestionAnswered,
            auditCode: .coachQuestionAnswered
        )
    }

    package static func proposeUnderstandingReplayPlan(
        goalId: String,
        sessionId: String,
        understandingId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        expectedUnderstandingEventVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try twoShapePlan(
            branch: .proposeUnderstanding,
            commandType: .coachProposeUnderstanding,
            goalId: goalId,
            sessionId: sessionId,
            understandingId: understandingId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            expectedUnderstandingEventVersion: expectedUnderstandingEventVersion,
            sessionEvent: .coachUnderstandingProposed,
            understandingEvent: .understandingProposed,
            sessionAudit: .coachUnderstandingProposed,
            understandingAudit: .coachUnderstandingProposed
        )
    }

    package static func requestConfirmationReplayPlan(
        goalId: String,
        sessionId: String,
        understandingId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        expectedUnderstandingEventVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try twoShapePlan(
            branch: .requestConfirmation,
            commandType: .coachRequestConfirmation,
            goalId: goalId,
            sessionId: sessionId,
            understandingId: understandingId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            expectedUnderstandingEventVersion: expectedUnderstandingEventVersion,
            sessionEvent: .coachConfirmationRequested,
            understandingEvent: .understandingConfirmationRequested,
            sessionAudit: .coachConfirmationRequested,
            understandingAudit: .coachConfirmationRequested
        )
    }

    package static func confirmUnderstandingReplayPlan(
        goalId: String,
        sessionId: String,
        understandingId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        expectedUnderstandingEventVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try DomainCommandReplayPlanV1(
            branch: .confirmUnderstanding,
            commandType: .coachConfirmUnderstanding,
            shapes: [
                shape(campId, .coachSession, sessionId,
                      expectedSessionVersion, .coachUnderstandingConfirmed,
                      .coachUnderstandingConfirmed),
                shape(campId, .understanding, understandingId,
                      expectedUnderstandingEventVersion, .understandingConfirmed,
                      .coachUnderstandingConfirmed),
                shape(campId, .goal, goalId,
                      expectedGoalVersion, .goalReady, .goalReady),
            ]
        )
    }

    package static func requestRevisionReplayPlan(
        branch: P1ResultBranchV1,
        goalId: String,
        sessionId: String,
        understandingId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        expectedUnderstandingEventVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        guard branch == .requestRevisionUnconfirmed
                || branch == .requestRevisionConfirmed
        else {
            throw P1ContractValidationError.invalidMembership
        }
        var shapes = [
            shape(campId, .coachSession, sessionId,
                  expectedSessionVersion,
                  .coachUnderstandingRevisionRequested,
                  .coachRevisionRequested),
        ]
        if branch == .requestRevisionUnconfirmed {
            shapes.append(shape(
                campId, .understanding, understandingId,
                expectedUnderstandingEventVersion,
                .understandingWithdrawn, .understandingWithdrawn
            ))
        }
        return try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: .coachRequestUnderstandingRevision,
            shapes: shapes
        )
    }

    package static func recordWorkFailureReplayPlan(
        branch: P1ResultBranchV1,
        goalId: String,
        sessionId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        let allowed: Set<P1ResultBranchV1> = [
            .coachFailureRetryClarifying, .coachFailureRetryReady,
            .coachFailureTerminalClarifying, .coachFailureTerminalReady,
        ]
        guard allowed.contains(branch) else {
            throw P1ContractValidationError.invalidMembership
        }
        let retry = branch == .coachFailureRetryClarifying
            || branch == .coachFailureRetryReady
        var shapes = [
            shape(
                campId, .coachSession, sessionId,
                expectedSessionVersion,
                retry ? .coachWorkAttemptFailed : .coachSessionFailed,
                retry ? .coachWorkRetryScheduled : .coachWorkFailed
            ),
        ]
        if branch == .coachFailureTerminalClarifying {
            shapes.append(shape(
                campId, .goal, goalId, expectedGoalVersion,
                .goalFailed, .goalFailed
            ))
        }
        return try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: .coachRecordWorkFailure,
            shapes: shapes
        )
    }

    package static func abandonGoalReplayPlan(
        goalId: String,
        sessionId: String?,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int?
    ) throws -> DomainCommandReplayPlanV1 {
        try goalTerminalPlan(
            goalId: goalId,
            sessionId: sessionId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            failed: false
        )
    }

    package static func failGoalReplayPlan(
        goalId: String,
        sessionId: String?,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int?
    ) throws -> DomainCommandReplayPlanV1 {
        try goalTerminalPlan(
            goalId: goalId,
            sessionId: sessionId,
            campId: campId,
            expectedGoalVersion: expectedGoalVersion,
            expectedSessionVersion: expectedSessionVersion,
            failed: true
        )
    }

    private func terminalGoal<Payload: Encodable>(
        commandType: P1CommandTypeV1,
        goal goalHead: GoalHeadV1,
        sessionBranch: SessionBranchV1,
        envelope: CommandEnvelopeV1,
        payload: Payload,
        failed: Bool
    ) throws -> CampSafeCommandResultV1 {
        let sealedSessionId: String?
        let sealedSessionVersion: Int?
        switch sessionBranch {
        case .none:
            sealedSessionId = nil
            sealedSessionVersion = nil
        case let .expected(sessionId, expectedSessionVersion):
            sealedSessionId = sessionId
            sealedSessionVersion = expectedSessionVersion
        }
        let replayPlan = try Self.goalTerminalPlan(
            goalId: goalHead.goalId,
            sessionId: sealedSessionId,
            campId: goalHead.campId,
            expectedGoalVersion: goalHead.expectedGoalVersion,
            expectedSessionVersion: sealedSessionVersion,
            failed: failed
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: commandType,
            envelope: envelope,
            payload: payload,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var goal = try Self.requireGoal(goalHead, in: db)
                guard .clarifying == goal.status || .ready == goal.status else {
                    throw P1ContractValidationError.invalidMembership
                }
                let allSessions = try Self.sessions(goalId: goal.id, in: db)
                if allSessions.count > 1 {
                    throw CoachSessionIntegrityError()
                }
                var session: CoachSessionRecord?
                switch sessionBranch {
                case .none:
                    guard allSessions.isEmpty else {
                        throw CoachSessionAlreadyExistsError()
                    }
                case let .expected(sessionId, expectedVersion):
                    guard allSessions.count == 1,
                          allSessions[0].id == sessionId,
                          allSessions[0].aggregateVersion == expectedVersion
                    else { throw CoachSessionIntegrityError() }
                    session = allSessions[0]
                }
                _ = try DurableWorkStore.cancelActive(
                    kind: .coach,
                    aggregateType: "goal",
                    aggregateId: goal.id,
                    reason: failed ? "goal_failed" : "goal_abandoned",
                    now: envelope.occurredAt,
                    businessMutation: { _, _ in },
                    in: db
                )
                if let sourceInputId = goal.sourceInputId {
                    _ = try DurableWorkStore.cancelActive(
                        kind: .inputParsing,
                        aggregateType: "input",
                        aggregateId: sourceInputId,
                        reason: failed ? "goal_failed" : "goal_abandoned",
                        now: envelope.occurredAt,
                        businessMutation: { _, _ in },
                        in: db
                    )
                }
                if var currentSession = session {
                    let openQuestions = try CoachQuestionRecord
                        .filter(Column("sessionId") == currentSession.id)
                        .filter(Column("state") == CoachQuestionStateV1.open.rawValue)
                        .fetchAll(db)
                    guard openQuestions.count <= 1,
                          currentSession.pendingQuestionId
                            == openQuestions.first?.id
                    else { throw CoachSessionIntegrityError() }
                    if var openQuestion = openQuestions.first {
                        openQuestion.state = .withdrawn
                        openQuestion.answer = nil
                        openQuestion.answeredAt = nil
                        try openQuestion.update(db)
                    }
                    currentSession.aggregateVersion = try CanonicalContractCodingV1
                        .checkedIncrement(currentSession.aggregateVersion)
                    currentSession.status = failed ? .failed : .canceled
                    currentSession.pendingQuestionId = nil
                    currentSession.updatedAt = envelope.occurredAt
                    try currentSession.update(db)
                    session = currentSession
                }
                goal.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(goal.aggregateVersion)
                goal[keyPath: \.status] = failed ? .failed : .abandoned
                goal.updatedAt = envelope.occurredAt
                try goal.update(db)
                let branch: P1ResultBranchV1
                if failed {
                    branch = session == nil
                        ? .failGoalWithoutSession : .failGoalWithSession
                } else {
                    branch = session == nil
                        ? .abandonGoalWithoutSession : .abandonGoalWithSession
                }
                return try Self.makeCoachCommand(
                    branch: branch,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    goal: goal,
                    session: session
                )
            }
        }
    }

    private static func requireGoal(
        _ head: GoalHeadV1,
        in db: Database
    ) throws -> GoalControllerRecord {
        let goal = try requireGoal(id: head.goalId, in: db)
        guard goal.campId == head.campId,
              goal.aggregateVersion == head.expectedGoalVersion,
              try aggregateEventVersion(
                type: .goal,
                id: goal.id,
                in: db
              ) == goal.aggregateVersion
        else { throw GoalProjectionVersionConflictError() }
        return goal
    }

    private static func requireGoal(
        id: String,
        in db: Database
    ) throws -> GoalControllerRecord {
        guard let goal = try GoalControllerRecord.fetchOne(db, key: id) else {
            throw RecordNotFoundError(
                table: GoalControllerRecord.databaseTableName,
                id: id
            )
        }
        return goal
    }

    private static func sessions(
        goalId: String,
        in db: Database
    ) throws -> [CoachSessionRecord] {
        try CoachSessionRecord
            .filter(Column("goalId") == goalId)
            .order(Column("createdAt"), Column("id"))
            .fetchAll(db)
    }

    private static func requireSoleSession(
        goalId: String,
        in db: Database
    ) throws -> CoachSessionRecord {
        let values = try sessions(goalId: goalId, in: db)
        guard !values.isEmpty else { throw CoachSessionNotFoundError() }
        guard values.count == 1 else { throw CoachSessionIntegrityError() }
        return values[0]
    }

    private static func requireSession(
        _ head: CoachHeadV1,
        goalId: String,
        in db: Database
    ) throws -> CoachSessionRecord {
        let session = try requireSoleSession(goalId: goalId, in: db)
        guard session.id == head.sessionId,
              session.aggregateVersion == head.expectedSessionVersion,
              try aggregateEventVersion(
                type: .coachSession,
                id: session.id,
                in: db
              ) == session.aggregateVersion
        else { throw CoachProjectionVersionConflictError() }
        return session
    }

    private static func currentUnderstanding(
        goal: GoalControllerRecord,
        in db: Database
    ) throws -> UnderstandingCardVersionRecord? {
        guard let id = goal.currentUnderstandingId,
              let version = goal.currentUnderstandingVersion
        else {
            guard goal.currentUnderstandingId == nil,
                  goal.currentUnderstandingVersion == nil
            else { throw UnderstandingIntegrityError() }
            return nil
        }
        guard let value = try UnderstandingCardVersionRecord.fetchOne(
            db,
            key: ["id": id, "version": version]
        ), value.goalId == goal.id,
           value.id == goal.id,
           value.status == .confirmed,
           value.contentHash == (try CanonicalContractCodingV1.hash(value.content))
        else { throw UnderstandingIntegrityError() }
        return value
    }

    private static func requireUnderstanding(
        _ head: UnderstandingHeadV1,
        goalId: String,
        in db: Database
    ) throws -> UnderstandingCardVersionRecord {
        guard head.understandingId == goalId,
              let value = try UnderstandingCardVersionRecord.fetchOne(
                db,
                key: [
                    "id": head.understandingId,
                    "version": head.expectedContentVersion,
                ]
              ),
              value.goalId == goalId,
              value.contentHash == head.contentHash,
              value.contentHash == (try CanonicalContractCodingV1.hash(value.content)),
              try understandingEventVersion(id: goalId, in: db)
                == head.expectedUnderstandingEventVersion
        else { throw UnderstandingIntegrityError() }
        return value
    }

    private static func failureAuthority(
        goal: GoalControllerRecord,
        in db: Database
    ) throws -> CoachFailureAuthority {
        let eventVersion = try understandingEventVersion(id: goal.id, in: db)
        if .clarifying == goal.status {
            guard goal.currentUnderstandingId == nil,
                  goal.currentUnderstandingVersion == nil
            else { throw UnderstandingIntegrityError() }
            return CoachFailureAuthority(
                scope: .clarifyingGoal,
                confirmedUnderstanding: nil,
                expectedUnderstandingEventVersion: eventVersion
            )
        }
        guard .ready == goal.status,
              let current = try currentUnderstanding(goal: goal, in: db)
        else { throw P1ContractValidationError.invalidMembership }
        return CoachFailureAuthority(
            scope: .readyRevisionSessionOnly,
            confirmedUnderstanding: try UnderstandingHeadV1(
                understandingId: current.id,
                expectedContentVersion: current.version,
                contentHash: current.contentHash,
                expectedUnderstandingEventVersion: eventVersion
            ),
            expectedUnderstandingEventVersion: eventVersion
        )
    }

    private static func enqueueCoachTurn(
        goal: GoalControllerRecord,
        session: CoachSessionRecord,
        nextQuestionId: String,
        prepared: PreparedDomainCommandV1,
        expectedUnderstandingEventVersion: Int,
        failureScope: CoachFailureScopeV1,
        confirmedUnderstanding: UnderstandingHeadV1?,
        in db: Database
    ) throws -> DurableWorkRecord {
        let input = try CoachTurnWorkInputV1(
            goalId: goal.id,
            sessionId: session.id,
            nextQuestionId: nextQuestionId,
            turnCommandHash: prepared.commandPayloadHash,
            expectedUnderstandingEventVersion:
                expectedUnderstandingEventVersion,
            failureScope: failureScope,
            confirmedUnderstanding: confirmedUnderstanding
        )
        let inputJSON = try CanonicalContractCodingV1.string(input)
        let inputHash = CanonicalJSONV1.sha256Hex(Data(inputJSON.utf8))
        let enqueued = try DurableWorkStore.enqueue(
            campId: goal.campId,
            kind: .coach,
            aggregateType: "goal",
            aggregateId: goal.id,
            inputJson: inputJSON,
            claimedInputHash: inputHash,
            idempotencyKey: try ControlWorkKeyV1.coach(
                commandHash: prepared.commandPayloadHash
            ),
            maxAttempts: 4,
            traceId: prepared.envelope.correlationId,
            now: prepared.envelope.occurredAt,
            in: db
        )
        guard enqueued.disposition == .inserted else {
            throw DomainCommandReplayConflictError()
        }
        return enqueued.work
    }

    private static func requireCoachClaimGraph(
        claim: WorkClaimV1,
        envelope: CommandEnvelopeV1,
        goal: GoalControllerRecord,
        session: CoachSessionRecord,
        in db: Database
    ) throws -> CoachClaimGraph {
        guard let work = try DurableWorkRecord.fetchOne(db, key: claim.workId),
              let attempt = try DurableWorkAttemptRecord.fetchOne(
                db,
                key: ["workId": claim.workId, "attempt": claim.attempt]
              ),
              work.kind == .coach,
              work.aggregateType == "goal",
              work.aggregateId == goal.id,
              work.campId == goal.campId,
              work.state == .running,
              work.version == claim.version,
              work.attempt == claim.attempt,
              work.maxAttempts == 4,
              work.leaseOwner == claim.workerId,
              work.leaseExpiresAt == claim.leaseExpiresAt
        else { throw StaleDurableWorkClaimError() }
        let expectedEnvelope = try ControlWorkerCommandEnvelopeFactoryV1.make(
            work: work,
            attempt: attempt,
            claim: claim.durableClaim
        )
        guard expectedEnvelope == envelope else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        let input = try CanonicalContractCodingV1.decode(
            CoachTurnWorkInputV1.self,
            from: Data(work.inputJson.utf8)
        )
        guard input.goalId == goal.id,
              input.sessionId == session.id,
              CanonicalJSONV1.sha256Hex(Data(work.inputJson.utf8))
                == work.inputHash
        else { throw P1WorkerCommandEnvelopeError.invalidGraph }
        return CoachClaimGraph(work: work, attempt: attempt, input: input)
    }

    private static func validateTerminalTime(
        _ terminalNow: Date,
        work: DurableWorkRecord,
        attempt: DurableWorkAttemptRecord
    ) throws {
        do {
            try CanonicalContractCodingV1.validateFinite(terminalNow)
        } catch {
            throw ControlWorkerTerminalTimeError()
        }
        guard terminalNow >= work.updatedAt,
              terminalNow >= attempt.startedAt
        else { throw ControlWorkerTerminalTimeError() }
    }

    private static func nextUnderstandingContentVersion(
        goalId: String,
        in db: Database
    ) throws -> Int {
        let maximum = try Int.fetchOne(
            db,
            sql: "SELECT MAX(version) FROM understanding_card_version WHERE goalId=?",
            arguments: [goalId]
        ) ?? 0
        return try CanonicalContractCodingV1.checkedIncrement(maximum)
    }

    private static func understandingEventVersion(
        id: String,
        in db: Database
    ) throws -> Int {
        try aggregateEventVersion(type: .understanding, id: id, in: db)
    }

    private static func aggregateEventVersion(
        type: P1AggregateTypeV1,
        id: String,
        in db: Database
    ) throws -> Int {
        try Int.fetchOne(
            db,
            sql: "SELECT MAX(aggregateVersion) FROM domain_event WHERE aggregateType=? AND aggregateId=?",
            arguments: [type.rawValue, id]
        ) ?? 0
    }

    private static func openQuestionCount(
        sessionId: String,
        in db: Database
    ) throws -> Int {
        try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM coach_question WHERE sessionId=? AND state='open'",
            arguments: [sessionId]
        ) ?? 0
    }

    private static func resultBranch(
        _ branch: CoachWorkFailureBranchV1
    ) throws -> P1ResultBranchV1 {
        switch branch {
        case .retryScheduledClarifyingGoal: .coachFailureRetryClarifying
        case .retryScheduledReadyRevision: .coachFailureRetryReady
        case .terminalClarifyingGoal: .coachFailureTerminalClarifying
        case .terminalReadyGoalPreserved: .coachFailureTerminalReady
        }
    }

    private static func makeCoachCommand(
        branch: P1ResultBranchV1,
        prepared: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        goal: GoalControllerRecord,
        session: CoachSessionRecord?,
        currentQuestionId: String? = nil,
        nextQuestionId: String? = nil,
        understanding: UnderstandingCardVersionRecord? = nil,
        work: DurableWorkRecord? = nil,
        workInputHash: String? = nil,
        understandingEventVersion: Int? = nil,
        attemptCount: Int? = nil,
        confirmedAt: Date? = nil,
        notBefore: Date? = nil
    ) throws -> NewDomainCommandV1 {
        let contract = try P1CommandContractCatalogV1.contract(for: branch)
        func hasRef(_ value: CampSafeRefKindV1) -> Bool {
            contract.refs.contains(value)
        }
        func hasHash(_ value: CampSafeHashKindV1) -> Bool {
            contract.hashes.contains(value)
        }
        func hasVersion(_ value: CampSafeVersionKindV1) -> Bool {
            contract.versions.contains(value)
        }
        func hasCount(_ value: CampSafeCountKindV1) -> Bool {
            contract.counts.contains(value)
        }
        func hasTime(_ value: CampSafeTimeKindV1) -> Bool {
            contract.times.contains(value)
        }
        let result = try CampSafeCommandResultV1.make(
            branch: branch,
            values: CampSafeResultValuesV1(
                commandPayloadHash: prepared.commandPayloadHash,
                domainEventCount: replayPlan.shapes.count,
                outboxCount: replayPlan.shapes.count,
                occurredAt: prepared.envelope.occurredAt,
                goalId: hasRef(.goal) ? goal.id : nil,
                coachSessionId: hasRef(.coachSession) ? session?.id : nil,
                currentCoachQuestionId: hasRef(.currentCoachQuestion)
                    ? currentQuestionId : nil,
                nextCoachQuestionId: hasRef(.nextCoachQuestion)
                    ? nextQuestionId : nil,
                understandingId: hasRef(.understanding)
                    ? understanding?.id : nil,
                durableWorkId: hasRef(.durableWork) ? work?.id : nil,
                understandingContentHash: hasHash(.understandingContent)
                    ? understanding?.contentHash : nil,
                durableWorkInputHash: hasHash(.durableWorkInput)
                    ? (workInputHash ?? work?.inputHash) : nil,
                goalProjectionVersion: hasVersion(.goalProjection)
                    ? goal.aggregateVersion : nil,
                coachSessionProjectionVersion:
                    hasVersion(.coachSessionProjection)
                        ? session?.aggregateVersion : nil,
                understandingContentVersion:
                    hasVersion(.understandingContent)
                        ? understanding?.version : nil,
                durableWorkVersion: hasVersion(.durableWork)
                    ? work?.version : nil,
                goalEventVersion: hasVersion(.goalEvent)
                    ? goal.aggregateVersion : nil,
                coachSessionEventVersion: hasVersion(.coachSessionEvent)
                    ? session?.aggregateVersion : nil,
                understandingEventVersion: hasVersion(.understandingEvent)
                    ? understandingEventVersion : nil,
                coachQuestionCount: hasCount(.coachQuestion)
                    ? (session?.pendingQuestionId == nil ? 0 : 1) : nil,
                attemptCount: hasCount(.attempt)
                    ? (attemptCount ?? work?.attempt) : nil,
                confirmedAt: hasTime(.confirmedAt) ? confirmedAt : nil,
                notBefore: hasTime(.notBefore) ? notBefore : nil
            )
        )
        return try NewDomainCommandV1.make(
            result: result,
            replayPlan: replayPlan
        )
    }

    private static func sessionPlan(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        goalId: String,
        sessionId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        eventType: P1EventTypeV1,
        auditCode: P1AuditCodeV1
    ) throws -> DomainCommandReplayPlanV1 {
        _ = goalId
        _ = expectedGoalVersion
        return try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: commandType,
            shapes: [
                shape(campId, .coachSession, sessionId,
                      expectedSessionVersion, eventType, auditCode),
            ]
        )
    }

    private static func twoShapePlan(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        goalId: String,
        sessionId: String,
        understandingId: String,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int,
        expectedUnderstandingEventVersion: Int,
        sessionEvent: P1EventTypeV1,
        understandingEvent: P1EventTypeV1,
        sessionAudit: P1AuditCodeV1,
        understandingAudit: P1AuditCodeV1
    ) throws -> DomainCommandReplayPlanV1 {
        _ = goalId
        _ = expectedGoalVersion
        return try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: commandType,
            shapes: [
                shape(campId, .coachSession, sessionId,
                      expectedSessionVersion, sessionEvent, sessionAudit),
                shape(campId, .understanding, understandingId,
                      expectedUnderstandingEventVersion,
                      understandingEvent, understandingAudit),
            ]
        )
    }

    private static func goalTerminalPlan(
        goalId: String,
        sessionId: String?,
        campId: String,
        expectedGoalVersion: Int,
        expectedSessionVersion: Int?,
        failed: Bool
    ) throws -> DomainCommandReplayPlanV1 {
        guard (sessionId == nil) == (expectedSessionVersion == nil) else {
            throw P1ContractValidationError.invalidMembership
        }
        let branch: P1ResultBranchV1
        if failed {
            branch = sessionId == nil
                ? .failGoalWithoutSession : .failGoalWithSession
        } else {
            branch = sessionId == nil
                ? .abandonGoalWithoutSession : .abandonGoalWithSession
        }
        var shapes: [DomainEventReplayShapeV1] = []
        if let sessionId, let expectedSessionVersion {
            shapes.append(shape(
                campId, .coachSession, sessionId, expectedSessionVersion,
                failed ? .coachSessionFailed : .coachSessionAbandoned,
                failed ? .goalFailed : .goalAbandoned
            ))
        }
        shapes.append(shape(
            campId, .goal, goalId, expectedGoalVersion,
            failed ? .goalFailed : .goalAbandoned,
            failed ? .goalFailed : .goalAbandoned
        ))
        return try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: failed ? .goalFail : .goalAbandon,
            shapes: shapes
        )
    }

    private static func shape(
        _ campId: String,
        _ aggregateType: P1AggregateTypeV1,
        _ aggregateId: String,
        _ expectedVersion: Int,
        _ eventType: P1EventTypeV1,
        _ auditCode: P1AuditCodeV1
    ) -> DomainEventReplayShapeV1 {
        DomainEventReplayShapeV1(
            campId: campId,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            expectedAggregateVersion: expectedVersion,
            eventType: eventType,
            auditCode: auditCode
        )
    }
}

private struct CoachClaimGraph {
    let work: DurableWorkRecord
    let attempt: DurableWorkAttemptRecord
    let input: CoachTurnWorkInputV1
}

private struct CoachFailureAuthority {
    let scope: CoachFailureScopeV1
    let confirmedUnderstanding: UnderstandingHeadV1?
    let expectedUnderstandingEventVersion: Int
}
