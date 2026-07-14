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
            guard var item = try IngestionItemRecord.fetchOne(database, key: id) else {
                throw FeedServiceError.ingestionNotFound(id)
            }
            guard item.status != .materialized else { throw FeedServiceError.invalidState(item.status) }
            item.status = .discarded
            item.updatedAt = Date()
            try item.update(database)
        }
    }

    private static func nilIfBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
