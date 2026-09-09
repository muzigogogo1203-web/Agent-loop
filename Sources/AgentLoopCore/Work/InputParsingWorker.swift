import Foundation
import GRDB

package typealias ControlWorkerSleepV1 =
    @Sendable (TimeInterval) async throws -> Void

package enum ControlWorkerLeasePolicyV1 {
    package static let leaseDuration: TimeInterval = 60
    package static let renewalInterval: TimeInterval = 15
}

package struct ControlWorkerProviderFailureV1: Sendable, Equatable, Codable {
    package let code: String
    package let safeMessage: String?
    package let disposition: DurableWorkFailureDisposition

    package init(
        code: String,
        safeMessage: String?,
        disposition: DurableWorkFailureDisposition
    ) throws {
        let validated = try DurableWorkFailure(
            code: code,
            message: safeMessage,
            disposition: disposition,
            usageJson: nil
        )
        self.code = validated.code
        self.safeMessage = validated.message
        self.disposition = validated.disposition
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case code
        case safeMessage
        case disposition
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard values.contains(.safeMessage) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            code: values.decode(String.self, forKey: .code),
            safeMessage: values.decodeIfPresent(String.self, forKey: .safeMessage),
            disposition: values.decode(
                DurableWorkFailureDisposition.self,
                forKey: .disposition
            )
        )
    }

    package func durableFailure() throws -> DurableWorkFailure {
        try DurableWorkFailure(
            code: code,
            message: safeMessage,
            disposition: disposition,
            usageJson: nil
        )
    }
}

package struct InputParsingProviderRequestV1: Sendable, Equatable {
    package let schemaVersion: Int
    package let workId: String
    package let attempt: Int
    package let inputId: String
    package let auditCampId: String
    package let assignedCampId: String?
    package let sourceType: InputSourceTypeV1
    package let capturedAt: Date
    package let inlineText: String?
    package let payloadRef: String?
    package let contentHash: String
    package let candidateCampIds: [String]
    package let explicitIntent: InputExplicitIntentV1
    package let privacyLevel: InputPrivacyLevelV1
    package let parentInputId: String?

    init(
        claim: DurableWorkClaim,
        auditCampId: String,
        input: InputEnvelopeRecord
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(claim.workId)
        try CanonicalContractCodingV1.validatePositive(claim.attempt)
        try CanonicalContractCodingV1.validateCampID(auditCampId)
        guard input.retentionState != .deletedTombstone,
              input.status != .deletedTombstone
        else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        schemaVersion = 1
        workId = claim.workId
        attempt = claim.attempt
        inputId = input.id
        self.auditCampId = auditCampId
        assignedCampId = input.campId
        sourceType = input.sourceType
        capturedAt = input.capturedAt
        inlineText = input.inlineText
        payloadRef = input.payloadRef
        contentHash = input.contentHash
        candidateCampIds = input.candidateCampIds
        explicitIntent = input.explicitIntent
        privacyLevel = input.privacyLevel
        parentInputId = input.parentInputId
    }
}

package enum InputParsingProviderOutcomeV1: Sendable, Equatable {
    case parsed(InputParseResultV1)
    case failed(ControlWorkerProviderFailureV1)
    case canceled
}

package typealias InputParserV1 =
    @Sendable (InputParsingProviderRequestV1) async
        -> InputParsingProviderOutcomeV1

internal enum LatestControlWorkClaimError: Error, Sendable, Equatable {
    case closed
    case staleReplacement
}

internal actor LatestControlWorkClaim {
    private var claim: DurableWorkClaim?

    init(_ claim: DurableWorkClaim) {
        self.claim = claim
    }

    func current() throws -> DurableWorkClaim {
        guard let claim else {
            throw LatestControlWorkClaimError.closed
        }
        return claim
    }

    func replace(
        expected: DurableWorkClaim,
        renewed: DurableWorkClaim
    ) throws {
        guard let claim else {
            throw LatestControlWorkClaimError.closed
        }
        guard claim == expected,
              renewed.workId == claim.workId,
              renewed.attempt == claim.attempt,
              renewed.workerId == claim.workerId,
              renewed.version > claim.version,
              renewed.leaseExpiresAt > claim.leaseExpiresAt
        else {
            throw LatestControlWorkClaimError.staleReplacement
        }
        self.claim = renewed
    }

    func closeAndTakeLatest() throws -> DurableWorkClaim {
        guard let claim else {
            throw LatestControlWorkClaimError.closed
        }
        self.claim = nil
        return claim
    }
}

package struct InputParsingWorker: Sendable {
    private let database: AppDatabase
    private let workerId: String
    private let clock: @Sendable () -> Date
    private let sleep: ControlWorkerSleepV1
    private let parser: InputParserV1

    package init(
        database: AppDatabase,
        workerId: String,
        clock: @escaping @Sendable () -> Date,
        sleep: @escaping ControlWorkerSleepV1,
        parser: @escaping InputParserV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(workerId)
        self.database = database
        self.workerId = workerId
        self.clock = clock
        self.sleep = sleep
        self.parser = parser
    }

    package func recoverInterrupted() throws -> [DurableWorkRecord] {
        let now = clock()
        try CanonicalContractCodingV1.validateFinite(now)
        return try DurableWorkStore(database: database)
            .adoptExpiredControlWork(
                kind: .inputParsing,
                currentWorkerId: workerId,
                now: now
            )
    }

    package func runNext() async throws -> Bool {
        try Task.checkCancellation()
        let claimNow = clock()
        try CanonicalContractCodingV1.validateFinite(claimNow)
        let durable = DurableWorkStore(database: database)
        guard let initialClaim = try durable.claimNext(
            kinds: [.inputParsing],
            workerId: workerId,
            now: claimNow,
            leaseDuration: ControlWorkerLeasePolicyV1.leaseDuration
        ) else {
            return false
        }

        let snapshot = try loadSnapshot(claim: initialClaim)
        let latestClaim = LatestControlWorkClaim(initialClaim)
        let outcome = try await runProviderAndRenewal(
            request: snapshot.request,
            durable: durable,
            latestClaim: latestClaim
        )
        try Task.checkCancellation()
        let terminalClaim = try await latestClaim.closeAndTakeLatest()

        switch outcome {
        case .canceled:
            throw CancellationError()
        case let .parsed(result):
            if isValidProviderResult(result, auditCampId: snapshot.input.auditCampId) {
                let terminalNow = clock()
                let command = try CommitInputParseResultCommandV1(
                    envelope: snapshot.envelope,
                    input: snapshot.input,
                    claim: WorkClaimV1(claim: terminalClaim),
                    result: result
                )
                _ = try InputGoalStore(database: database).commitParseResult(
                    command,
                    terminalNow: terminalNow
                )
            } else {
                let failure = try ControlWorkerProviderFailureV1(
                    code: "input_parser_invalid_output",
                    safeMessage: nil,
                    disposition: .deterministic
                )
                try terminalizeFailure(
                    failure,
                    snapshot: snapshot,
                    claim: terminalClaim
                )
            }
        case let .failed(failure):
            try terminalizeFailure(
                failure,
                snapshot: snapshot,
                claim: terminalClaim
            )
        }
        return true
    }

    private func runProviderAndRenewal(
        request: InputParsingProviderRequestV1,
        durable: DurableWorkStore,
        latestClaim: LatestControlWorkClaim
    ) async throws -> InputParsingProviderOutcomeV1 {
        var providerOutcome: InputParsingProviderOutcomeV1?
        try await withThrowingTaskGroup(
            of: InputParsingChildResult.self
        ) { group in
            group.addTask {
                .provider(await parser(request))
            }
            group.addTask {
                while true {
                    try await sleep(ControlWorkerLeasePolicyV1.renewalInterval)
                    try Task.checkCancellation()
                    let current = try await latestClaim.current()
                    let renewalNow = clock()
                    try CanonicalContractCodingV1.validateFinite(renewalNow)
                    let renewed = try durable.renewLease(
                        claim: current,
                        now: renewalNow,
                        leaseDuration: ControlWorkerLeasePolicyV1.leaseDuration
                    )
                    try await latestClaim.replace(
                        expected: current,
                        renewed: renewed
                    )
                }
            }
            do {
                while let child = try await group.next() {
                    switch child {
                    case let .provider(outcome):
                        providerOutcome = outcome
                        group.cancelAll()
                    }
                }
            } catch is CancellationError {
                guard providerOutcome != nil, !Task.isCancelled else {
                    throw CancellationError()
                }
            }
        }
        guard let providerOutcome else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        return providerOutcome
    }

    private func loadSnapshot(claim: DurableWorkClaim) throws -> InputWorkerSnapshot {
        try database.pool.read { db in
            guard let work = try DurableWorkRecord.fetchOne(db, key: claim.workId),
                  let attempt = try DurableWorkAttemptRecord.fetchOne(
                    db,
                    key: ["workId": claim.workId, "attempt": claim.attempt]
                  ),
                  let input = try InputEnvelopeRecord.fetchOne(
                    db,
                    key: work.aggregateId
                  )
            else {
                throw P1WorkerCommandEnvelopeError.invalidGraph
            }
            let envelope = try ControlWorkerCommandEnvelopeFactoryV1.make(
                work: work,
                attempt: attempt,
                claim: claim
            )
            guard work.kind == .inputParsing,
                  work.aggregateType == "input",
                  work.aggregateId == input.id,
                  work.campId == input.campId || input.campId == nil,
                  work.maxAttempts == 4
            else {
                throw P1WorkerCommandEnvelopeError.invalidGraph
            }
            let workInput = try CanonicalContractCodingV1.decode(
                InputParsingWorkInputV1.self,
                from: Data(work.inputJson.utf8)
            )
            guard workInput.inputId == input.id,
                  workInput.contentHash == input.contentHash,
                  CanonicalJSONV1.sha256Hex(Data(work.inputJson.utf8))
                    == work.inputHash
            else {
                throw P1WorkerCommandEnvelopeError.invalidGraph
            }
            let head = try InputHeadV1(
                inputId: input.id,
                auditCampId: work.campId,
                expectedInputVersion: input.aggregateVersion
            )
            let request = try InputParsingProviderRequestV1(
                claim: claim,
                auditCampId: work.campId,
                input: input
            )
            return InputWorkerSnapshot(
                envelope: envelope,
                input: head,
                request: request,
                maxAttempts: work.maxAttempts
            )
        }
    }

    private func isValidProviderResult(
        _ result: InputParseResultV1,
        auditCampId: String
    ) -> Bool {
        switch result.route {
        case .coaching, .archived:
            return result.assignedCampId == auditCampId
        case .campAssignmentRequired, .campAmbiguous:
            return result.assignedCampId == nil
        }
    }

    private func terminalizeFailure(
        _ failure: ControlWorkerProviderFailureV1,
        snapshot: InputWorkerSnapshot,
        claim: DurableWorkClaim
    ) throws {
        let terminalNow = clock()
        let disposition = try InputParseFailureTerminalDispositionV1.derive(
            failure: failure,
            attempt: claim.attempt,
            maxAttempts: snapshot.maxAttempts
        )
        let command = try RecordInputParseFailureCommandV1(
            envelope: snapshot.envelope,
            input: snapshot.input,
            claim: WorkClaimV1(claim: claim),
            failure: failure,
            terminalDisposition: disposition
        )
        _ = try InputGoalStore(database: database).recordParseFailure(
            command,
            terminalNow: terminalNow
        )
    }
}

private enum InputParsingChildResult: Sendable {
    case provider(InputParsingProviderOutcomeV1)
}

private struct InputWorkerSnapshot: Sendable {
    let envelope: CommandEnvelopeV1
    let input: InputHeadV1
    let request: InputParsingProviderRequestV1
    let maxAttempts: Int
}
