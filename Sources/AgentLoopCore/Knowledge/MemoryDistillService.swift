import Foundation
import GRDB

fileprivate enum MemoryDistillOutcome<Record: Sendable>: Sendable {
    case noEligibleInput
    case skipped
    case created(Record)
}

extension MemoryDistillOutcome: Equatable where Record: Equatable {}

public enum MemoryDistillTerminal<Record: Sendable>: Sendable {
    case noEligibleInput
    case skipped
    case created(Record)
    case failed(UserVisibleFailure)
}

extension MemoryDistillTerminal: Equatable where Record: Equatable {}

fileprivate enum MemoryDistillExecutionStage: Sendable, Equatable {
    case input
    case ownerRead
    case threadEnsure
    case messageRead
    case provider
    case watermark
    case persistence
}

enum MemoryDistillNormalizedFailure: Error, Sendable, Equatable {
    case input(MemoryDistillError)
    case ownerRead(MemoryDistillError)
    case threadEnsure(MemoryDistillError)
    case messageRead(MemoryDistillError)
    case provider(MemoryDistillError)
    case watermark(MemoryDistillError)
    case persistence(MemoryDistillError)
    case watermarkRace
    case persistenceRace
}

/// 记忆沉淀协调：读取冻结增量，调用 Distiller，并通过同一事务提交水位、笔记与事件。
public struct MemoryDistillService: Sendable {
    public static let autoMinMessages = 4

    private let db: AppDatabase
    private let distiller: Distiller
    private let campRuntime: CampProviderRuntimeV1
    private let reporter: FailureReporter
    private let traceFactory: OperationTraceFactory

    package init(
        db: AppDatabase,
        distiller: Distiller,
        campRuntime: CampProviderRuntimeV1,
        reporter: FailureReporter,
        traceFactory: OperationTraceFactory
    ) {
        self.db = db
        self.distiller = distiller
        self.campRuntime = campRuntime
        self.reporter = reporter
        self.traceFactory = traceFactory
    }

    @discardableResult
    public func distillDM(
        companionId: String,
        minMessages: Int
    ) async -> MemoryDistillTerminal<CompanionNoteRecord> {
        let trace = traceFactory.generated(
            operation: .memoryDMDistill,
            scope: .fixed(.memoryDM)
        )
        var stage = MemoryDistillExecutionStage.input
        let outcome: MemoryDistillOutcome<CompanionNoteRecord>
        do {
            if minMessages <= 0 {
                throw MemoryDistillError.invalidMinimumMessages(minMessages)
            }

            stage = .ownerRead
            guard let companion = try db.companion(id: companionId) else {
                throw MemoryDistillError.ownerNotFound(.companion)
            }

            stage = .threadEnsure
            let thread = try verifiedDMThread(companionId: companionId)

            stage = .messageRead
            let undistilled = try db.undistilledMessages(threadId: thread.id)
            if undistilled.count < minMessages {
                outcome = .noEligibleInput
            } else {
                let messages = try Self.strictDMMessages(undistilled)
                let capturedMessageIds = undistilled.map(\.id)

                stage = .provider
                let note = try await distiller.distillMemory(
                    companionName: companion.name,
                    rolePrompt: companion.rolePrompt,
                    messages: messages
                )
                if let note {
                    let record = CompanionNoteRecord.new(
                        companionId: companionId,
                        sourceThreadId: thread.id,
                        title: note.title,
                        bodyMd: note.bodyMd
                    )
                    stage = .persistence
                    _ = try db.persistCompanionDistillation(
                        note: record,
                        capturedMessageIds: capturedMessageIds
                    )
                    outcome = .created(record)
                } else {
                    stage = .watermark
                    try db.advanceDistillationWatermark(
                        capturedMessageIds: capturedMessageIds
                    )
                    outcome = .skipped
                }
            }
        } catch {
            let failure = reporter.capture(
                Self.normalized(error, at: stage),
                trace: trace
            )
            return .failed(failure)
        }
        return Self.flatten(outcome)
    }

    @discardableResult
    public func distillGuideChat(
        campId: String
    ) async -> MemoryDistillTerminal<CampNoteRecord> {
        let trace = traceFactory.generated(
            operation: .memoryGuideDistill,
            scope: .fixed(.memoryGuide)
        )
        var stage = MemoryDistillExecutionStage.input
        let outcome: MemoryDistillOutcome<CampNoteRecord>
        do {
            stage = .ownerRead
            guard try db.camp(id: campId) != nil,
                  let guide = try db.guide(campId: campId)
            else {
                throw MemoryDistillError.ownerNotFound(.guide)
            }

            stage = .threadEnsure
            let thread = try verifiedGuideThread(
                campId: campId,
                guideId: guide.id
            )

            stage = .messageRead
            let undistilled = try db.undistilledMessages(threadId: thread.id)
            if undistilled.isEmpty {
                outcome = .noEligibleInput
            } else {
                let messages = try Self.strictGuideMessages(undistilled)
                let capturedMessageIds = undistilled.map(\.id)

                stage = .provider
                let inputJSON = try JSONValue.object([
                    "campId": .string(campId),
                    "capturedMessageIds": .array(
                        capturedMessageIds.map(JSONValue.string)
                    ),
                    "threadId": .string(thread.id),
                ]).encodedString()
                let returned = try await campRuntime.beginMemoryPromotion(
                    campId: campId,
                    aggregateId: thread.id,
                    inputJson: inputJSON,
                    system: Distiller.guideChatSystem,
                    user: Distiller.guideChatPrompt(messages: messages),
                    idempotencyKey:
                        "guide-distill:\(thread.id):\(capturedMessageIds.last!)",
                    traceId: trace.traceId
                )
                let note: Distiller.Note?
                switch try Distiller.parseNoteJSON(returned.text) {
                case .note(let title, let body):
                    note = Distiller.Note(title: title, bodyMd: body)
                case .skip:
                    note = nil
                }
                if let note {
                    let record = CampNoteRecord.new(
                        campId: campId,
                        title: note.title,
                        bodyMd: note.bodyMd
                    )
                    stage = .persistence
                    _ = try campRuntime.consumeGuideDistillation(
                        returned,
                        note: record,
                        capturedMessageIds: capturedMessageIds
                    )
                    outcome = .created(record)
                } else {
                    stage = .watermark
                    _ = try campRuntime.consumeGuideDistillation(
                        returned,
                        note: nil,
                        capturedMessageIds: capturedMessageIds
                    )
                    outcome = .skipped
                }
            }
        } catch {
            let failure = reporter.capture(
                Self.normalized(error, at: stage),
                trace: trace
            )
            return .failed(failure)
        }
        return Self.flatten(outcome)
    }

    private func verifiedDMThread(
        companionId: String
    ) throws -> ChatThreadRecord {
        let selected: ChatThreadRecord
        do {
            selected = try db.findOrCreateDMThread(companionId: companionId)
        } catch ProjectionContractError.invalidPayload {
            throw MemoryDistillError.threadInvariant(.companion)
        } catch let error as LegacyContentScopeError {
            switch error {
            case .malformedScope, .missingThreadScope:
                throw MemoryDistillError.threadInvariant(.companion)
            default:
                throw error
            }
        }
        let matches = try db.pool.read { database in
            try ChatThreadRecord
                .filter(
                    Column("companionId") == companionId
                        && Column("kind") == ChatThreadRecord.Kind.dm.rawValue
                )
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
        }
        guard matches.count == 1, matches[0].id == selected.id else {
            throw MemoryDistillError.threadInvariant(.companion)
        }
        return selected
    }

    private func verifiedGuideThread(
        campId: String,
        guideId: String
    ) throws -> ChatThreadRecord {
        let selected: ChatThreadRecord
        do {
            selected = try db.findOrCreateGuideThread(campId: campId)
        } catch ProjectionContractError.invalidPayload {
            throw MemoryDistillError.threadInvariant(.guide)
        } catch let error as LegacyContentScopeError {
            switch error {
            case .malformedScope, .missingThreadScope:
                throw MemoryDistillError.threadInvariant(.guide)
            default:
                throw error
            }
        }
        let matches = try db.pool.read { database in
            try ChatThreadRecord
                .filter(
                    Column("campId") == campId
                        && Column("kind") == ChatThreadRecord.Kind.guide.rawValue
                )
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
        }
        guard matches.count == 1,
              matches[0].id == selected.id,
              matches[0].companionId == guideId
        else {
            throw MemoryDistillError.threadInvariant(.guide)
        }
        return selected
    }

    private static func strictDMMessages(
        _ records: [ChatMessageRecord]
    ) throws -> [(role: String, text: String)] {
        try records.map { record in
            guard record.role == "user" || record.role == "companion" else {
                throw MemoryDistillError.invalidPayload
            }
            return (role: record.role, text: try exactText(record.contentJson))
        }
    }

    private static func strictGuideMessages(
        _ records: [ChatMessageRecord]
    ) throws -> [(role: String, text: String)] {
        try records.map { record in
            guard record.role == "user" || record.role == "guide" else {
                throw MemoryDistillError.invalidPayload
            }
            let value = try JSONValue.decoded(from: record.contentJson)
            if let object = value.objectValue,
               object.count == 1,
               let text = object["text"]?.stringValue
            {
                return (role: record.role, text: text)
            }
            guard record.role == "guide" else {
                throw MemoryDistillError.invalidPayload
            }
            let proposal = try JSONDecoder().decode(
                SquadProposalBlock.self,
                from: Data(record.contentJson.utf8)
            )
            guard proposal.type == SquadProposalBlock.typeName else {
                throw MemoryDistillError.invalidPayload
            }
            return (role: record.role, text: proposal.historyPlaceholder)
        }
    }

    private static func exactText(_ contentJSON: String) throws -> String {
        let value = try JSONValue.decoded(from: contentJSON)
        guard let object = value.objectValue,
              object.count == 1,
              let text = object["text"]?.stringValue
        else {
            throw MemoryDistillError.invalidPayload
        }
        return text
    }

    private static func normalized(
        _ error: any Error,
        at stage: MemoryDistillExecutionStage
    ) -> any Error {
        if error is CancellationError {
            return error
        }
        switch stage {
        case .input:
            if let memory = error as? MemoryDistillError,
               case .invalidMinimumMessages = memory
            {
                return MemoryDistillNormalizedFailure.input(memory)
            }
            if let memory = error as? MemoryDistillError,
               case .invalidCapturedMessages = memory
            {
                return MemoryDistillNormalizedFailure.input(memory)
            }
        case .ownerRead:
            if let memory = error as? MemoryDistillError,
               case .ownerNotFound = memory
            {
                return MemoryDistillNormalizedFailure.ownerRead(memory)
            }
            if let database = error as? DatabaseError {
                return MemoryDistillNormalizedFailure.ownerRead(
                    .read(grdbResultCode: database.extendedResultCode.rawValue)
                )
            }
        case .threadEnsure:
            if let memory = error as? MemoryDistillError,
               case .threadInvariant = memory
            {
                return MemoryDistillNormalizedFailure.threadEnsure(memory)
            }
            if let database = error as? DatabaseError {
                return MemoryDistillNormalizedFailure.threadEnsure(
                    .write(grdbResultCode: database.extendedResultCode.rawValue)
                )
            }
        case .messageRead:
            if let memory = error as? MemoryDistillError,
               case .invalidPayload = memory
            {
                return MemoryDistillNormalizedFailure.messageRead(memory)
            }
            if error is DecodingError {
                return MemoryDistillNormalizedFailure.messageRead(.invalidPayload)
            }
            if let database = error as? DatabaseError {
                return MemoryDistillNormalizedFailure.messageRead(
                    .read(grdbResultCode: database.extendedResultCode.rawValue)
                )
            }
        case .provider:
            if error is DistillerError {
                return MemoryDistillNormalizedFailure.provider(.invalidPayload)
            }
            if let call = error as? CampProviderCallFailureV1 {
                switch call.cause {
                case .provider(let provider):
                    let status: ValidatedHTTPStatus?
                    switch provider {
                    case .http(let rawStatus, _):
                        status = .recognizingDiagnostic(rawStatus)
                    default:
                        status = nil
                    }
                    return MemoryDistillNormalizedFailure.provider(
                        .provider(httpStatus: status)
                    )
                case .unknown:
                    return MemoryDistillNormalizedFailure.provider(
                        .provider(httpStatus: nil)
                    )
                }
            }
            if let provider = error as? ProviderError {
                let status: ValidatedHTTPStatus?
                switch provider {
                case .http(let rawStatus, _):
                    status = .recognizingDiagnostic(rawStatus)
                default:
                    status = nil
                }
                return MemoryDistillNormalizedFailure.provider(
                    .provider(httpStatus: status)
                )
            }
        case .watermark:
            if error is MemoryDistillRaceLostError {
                return MemoryDistillNormalizedFailure.watermarkRace
            }
            if let memory = error as? MemoryDistillError,
               case .invalidCapturedMessages = memory
            {
                return MemoryDistillNormalizedFailure.watermark(memory)
            }
            if let database = error as? DatabaseError {
                return MemoryDistillNormalizedFailure.watermark(
                    .write(grdbResultCode: database.extendedResultCode.rawValue)
                )
            }
        case .persistence:
            if error is MemoryDistillRaceLostError {
                return MemoryDistillNormalizedFailure.persistenceRace
            }
            if let memory = error as? MemoryDistillError,
               case .invalidCapturedMessages = memory
            {
                return MemoryDistillNormalizedFailure.persistence(memory)
            }
            if let database = error as? DatabaseError {
                return MemoryDistillNormalizedFailure.persistence(
                    .write(grdbResultCode: database.extendedResultCode.rawValue)
                )
            }
        }
        return error
    }

    private static func flatten<Record: Sendable>(
        _ outcome: MemoryDistillOutcome<Record>
    ) -> MemoryDistillTerminal<Record> {
        switch outcome {
        case .noEligibleInput:
            return .noEligibleInput
        case .skipped:
            return .skipped
        case .created(let record):
            return .created(record)
        }
    }
}
