import Foundation
import GRDB

package enum CampLifecycleStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case archived
    case deletionRequested
    case deleting
    case deletedTombstone
}

package struct CampLifecycleSnapshotV1: Codable, Sendable, Equatable {
    package let campId: String
    package let state: CampLifecycleStateV1
    package let version: Int
    package let createdAt: Date
    package let updatedAt: Date
    package let deletionRequestedAt: Date?
    package let deletedAt: Date?
}

package enum CampLifecycleWriteAuthorizationError:
    Error, Sendable, Equatable
{
    case missing
    case lifecycleVersionMismatch(expected: Int, actual: Int)
    case inactive(CampLifecycleStateV1)
    case legacyArchived
}

package struct CampLifecycleStore: Sendable {
    private let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package func lifecycle(
        campId: String
    ) throws -> CampLifecycleSnapshotV1? {
        try CanonicalContractCodingV1.validateCampID(campId)
        return try database.pool.read { db in
            try lifecycle(campId: campId, database: db)
        }
    }

    package func lifecycle(
        campId: String,
        database transaction: Database
    ) throws -> CampLifecycleSnapshotV1? {
        guard let row = try Row.fetchOne(
            transaction,
            sql: """
                SELECT campId,state,version,createdAt,updatedAt,
                       deletionRequestedAt,deletedAt
                FROM camp_lifecycle WHERE campId=?
                """,
            arguments: [campId]
        ) else {
            return nil
        }
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        return CampLifecycleSnapshotV1(
            campId: row["campId"],
            state: state,
            version: row["version"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"],
            deletionRequestedAt: row["deletionRequestedAt"],
            deletedAt: row["deletedAt"]
        )
    }

    package func requireActiveCampWrite(
        campId: String,
        expectedLifecycleVersion: Int,
        database transaction: Database
    ) throws -> CampLifecycleSnapshotV1 {
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validatePositive(
            expectedLifecycleVersion
        )
        guard let snapshot = try lifecycle(
            campId: campId,
            database: transaction
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        guard snapshot.version == expectedLifecycleVersion else {
            throw CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(
                    expected: expectedLifecycleVersion,
                    actual: snapshot.version
                )
        }
        guard snapshot.state == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(snapshot.state)
        }
        guard try Int.fetchOne(
            transaction,
            sql: "SELECT archived FROM camp WHERE id=?",
            arguments: [campId]
        ) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        return snapshot
    }

    package static func insertInitialActive(
        campId: String,
        at: Date,
        database: Database
    ) throws {
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateFinite(at)
        try database.execute(
            sql: """
                INSERT INTO camp_lifecycle(
                  campId,state,version,createdAt,updatedAt,
                  deletionRequestedAt,deletedAt
                ) VALUES (?,'active',1,?,?,NULL,NULL)
                """,
            arguments: [campId, at, at]
        )
    }
}
