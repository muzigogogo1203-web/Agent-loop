import CryptoKit
import Foundation
import GRDB

public enum FeedServiceError: Error, Sendable, Equatable {
    case emptyContent
    case ingestionNotFound(String)
    case invalidState(IngestionStatus)
}

public enum FeedSubmission: Sendable, Equatable {
    case created(IngestionItemRecord)
    case duplicate(IngestionItemRecord)
}

public enum FeedContentHasher {
    public static func hash(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct FeedService: Sendable {
    public let db: AppDatabase

    public init(db: AppDatabase) { self.db = db }

    public func submit(
        campId: String,
        rawText: String,
        title: String? = nil,
        sourceURL: String? = nil,
        author: String? = nil,
        userIntent: String? = nil,
        sourceType: IngestionSourceType = .text,
        allowDuplicate: Bool = false
    ) throws -> FeedSubmission {
        let content = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw FeedServiceError.emptyContent }
        let hash = FeedContentHasher.hash(content)
        return try db.pool.write { database in
            _ = try Self.requireActiveLifecycle(
                database,
                campId: campId
            )
            if !allowDuplicate,
               let existing = try IngestionItemRecord
                .filter(Column("campId") == campId && Column("contentHash") == hash && Column("status") != IngestionStatus.discarded.rawValue)
                .order(Column("createdAt").desc)
                .fetchOne(database) {
                return .duplicate(existing)
            }
            let now = Date()
            let record = IngestionItemRecord(
                id: UUID().uuidString,
                campId: campId,
                sourceType: sourceType,
                title: Self.nilIfBlank(title),
                rawText: content,
                sourceURL: Self.nilIfBlank(sourceURL),
                author: Self.nilIfBlank(author),
                userIntent: Self.nilIfBlank(userIntent),
                contentHash: hash,
                status: .queued,
                attempt: 0,
                errorText: nil,
                createdAt: now,
                updatedAt: now
            )
            try record.insert(database)
            try AppDatabase.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.ingestionCreated,
                payload: ["campId": .string(campId), "ingestionId": .string(record.id)]
            )
            return .created(record)
        }
    }

    public func items(campId: String) throws -> [IngestionItemRecord] {
        try db.pool.read { database in
            try IngestionItemRecord
                .filter(Column("campId") == campId)
                .order(Column("createdAt").desc)
                .fetchAll(database)
        }
    }

    public func item(id: String) throws -> IngestionItemRecord? {
        try db.pool.read { try IngestionItemRecord.fetchOne($0, key: id) }
    }

    public func discard(id: String) throws {
        try db.pool.write { database in
            guard let item = try IngestionItemRecord.fetchOne(database, key: id) else {
                throw FeedServiceError.ingestionNotFound(id)
            }
            _ = try Self.requireActiveLifecycle(
                database,
                campId: item.campId
            )
            guard let fence = try Row.fetchOne(
                database,
                sql: "SELECT version,terminalReason,redactedAt FROM ingestion_item WHERE id=?",
                arguments: [id]
            ) else {
                throw FeedServiceError.ingestionNotFound(id)
            }
            let version: Int = fence["version"]
            let terminalReason: String? = fence["terminalReason"]
            let redactedAt: Date? = fence["redactedAt"]
            guard terminalReason == nil, redactedAt == nil else {
                throw FeedServiceError.invalidState(item.status)
            }
            guard item.status != .materialized else { throw FeedServiceError.invalidState(item.status) }
            let activeRuminationCount = try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*)
                    FROM durable_work
                    WHERE kind = 'rumination'
                      AND aggregateType = 'ingestion'
                      AND aggregateId = ?
                      AND state IN (
                        'queued','running','retryScheduled'
                      )
                    """,
                arguments: [id]
            ) ?? 0
            guard item.status != .ruminating,
                  activeRuminationCount == 0
            else {
                throw FeedServiceError.invalidState(.ruminating)
            }
            let (nextVersion, overflow) = version.addingReportingOverflow(1)
            guard !overflow else { throw InvalidDurableWorkStateError() }
            let now = Date()
            try database.execute(
                sql: """
                    UPDATE ingestion_item
                    SET status='discarded',updatedAt=?,version=?
                    WHERE id=? AND campId=? AND version=? AND status=?
                      AND terminalReason IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    now,
                    nextVersion,
                    item.id,
                    item.campId,
                    version,
                    item.status.rawValue,
                ]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
        }
    }

    @discardableResult
    private static func requireActiveLifecycle(
        _ database: Database,
        campId: String
    ) throws -> Int {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let version: Int = row["version"]
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), state == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["state"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        return version
    }

    private static func nilIfBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
