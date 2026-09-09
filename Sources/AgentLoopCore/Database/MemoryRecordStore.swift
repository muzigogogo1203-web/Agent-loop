import Foundation
import GRDB

package struct MemoryRecordStore: Sendable {
    private let database: AppDatabase
    private let lifecycleStore: CampLifecycleStore

    package init(database: AppDatabase) {
        self.database = database
        lifecycleStore = CampLifecycleStore(database: database)
    }

    package func record(
        _ draft: MemoryRecordDraftV1,
        authorizedCowId: String?,
        expectedCampLifecycleVersion: Int?,
        at: Date
    ) throws -> MemoryRecordVersionV1 {
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.write { db in
            try requireWriteAuthorization(
                draft: draft,
                authorizedCowId: authorizedCowId,
                expectedCampLifecycleVersion:
                    expectedCampLifecycleVersion,
                database: db
            )
            guard try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM memory_record_version WHERE id=?",
                arguments: [draft.id]
            ) == 0 else {
                throw MemoryPromotionAuthorizationError.sourceMismatch
            }
            let record = try Self.record(
                draft: draft,
                version: 1,
                status: .active,
                createdAt: at,
                updatedAt: at
            )
            try Self.insert(record, database: db)
            guard try Self.memory(
                id: record.id,
                version: record.version,
                database: db
            ) == record else {
                throw MemoryPromotionAuthorizationError.sourceMismatch
            }
            return record
        }
    }

    package func promote(
        source: MemoryRecordRefV1,
        targetLayer: MemoryLayerV1,
        targetOwnerType: MemoryOwnerTypeV1,
        targetOwnerId: String,
        targetCampId: String?,
        sourceType: MemorySourceTypeV1,
        confirmedByActorId: String?,
        authorizedCowId: String?,
        expectedCampLifecycleVersion: Int?,
        at: Date
    ) throws -> MemoryRecordVersionV1 {
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.write { db in
            guard let current = try Self.memory(
                id: source.id,
                version: source.version,
                database: db
            ), current.contentHash == source.hash,
               current.status == .active,
               try Self.latestVersion(id: source.id, database: db)
                    == source.version
            else {
                throw MemoryPromotionAuthorizationError.sourceMismatch
            }
            let draft = try MemoryRecordDraftV1(
                id: current.id,
                layer: targetLayer,
                ownerType: targetOwnerType,
                ownerId: targetOwnerId,
                campId: targetCampId,
                title: current.title,
                bodyText: current.bodyText,
                contentRef: current.contentRef,
                sourceType: sourceType,
                applicabilityJson: current.applicabilityJson,
                createdByActorId: current.createdByActorId,
                confirmedByActorId: confirmedByActorId
            )
            try requireWriteAuthorization(
                draft: draft,
                authorizedCowId: authorizedCowId,
                expectedCampLifecycleVersion:
                    expectedCampLifecycleVersion,
                database: db
            )
            let nextVersion = try CanonicalContractCodingV1
                .checkedIncrement(current.version)
            let promoted = try Self.record(
                draft: draft,
                version: nextVersion,
                status: .active,
                createdAt: at,
                updatedAt: at
            )
            try Self.insert(promoted, database: db)
            _ = try Self.appendDependency(
                MemoryDependencyDraftV1(
                    id: "memory:\(promoted.id):\(promoted.version):source",
                    memory: try promoted.ref,
                    dependencyType: .memory,
                    dependencyId: current.id,
                    dependencyVersion: current.version,
                    dependencyHash: current.contentHash,
                    createdAt: at
                ),
                database: db
            )
            return promoted
        }
    }

    package func recordOutcomeSkill(
        _ draft: MemoryRecordDraftV1,
        outcome: OutcomeRefV1,
        verificationId: String,
        acceptanceId: String,
        at: Date
    ) throws -> MemoryRecordVersionV1 {
        guard draft.layer == .globalSkill,
              draft.ownerType == .cow,
              draft.campId == nil,
              draft.sourceType == .outcomeExperience
        else {
            throw MemoryRecordContractError.invalidProvenance
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(verificationId)
        try CanonicalContractCodingV1.validateCanonicalUUID(acceptanceId)
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.write { db in
            guard try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM cow_identity
                    WHERE id=? AND status='active'
                    """,
                arguments: [draft.ownerId]
            ) == 1 else {
                throw MemoryPromotionAuthorizationError.cowUnavailable
            }
            guard let outcomeRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT o.state,o.currentVersion,v.contentHash
                    FROM outcome o
                    JOIN outcome_version v
                      ON v.outcomeId=o.id AND v.version=o.currentVersion
                    WHERE o.id=?
                    """,
                arguments: [outcome.id]
            ), outcomeRow["state"] as String == "accepted",
               outcomeRow["currentVersion"] as Int == outcome.version,
               outcomeRow["contentHash"] as String == outcome.hash
            else {
                throw MemoryPromotionAuthorizationError.outcomeNotAccepted
            }
            guard let verification = try Row.fetchOne(
                db,
                sql: """
                    SELECT r.evidenceHash,r.result,h.derivedResult,
                           h.currentVerificationId
                    FROM verification_record r
                    JOIN verification_result_head h
                      ON h.outcomeId=r.outcomeId
                     AND h.outcomeVersion=r.outcomeVersion
                     AND h.requirementId=r.requirementId
                     AND h.requirementVersion=r.requirementVersion
                    WHERE r.id=? AND r.outcomeId=? AND r.outcomeVersion=?
                    """,
                arguments: [verificationId, outcome.id, outcome.version]
            ), verification["result"] as String == "passed",
               verification["derivedResult"] as String == "passed",
               verification["currentVerificationId"] as String
                    == verificationId
            else {
                throw MemoryPromotionAuthorizationError.verificationInvalid
            }
            guard let acceptance = try Row.fetchOne(
                db,
                sql: """
                    SELECT id,decision,outcomeHash,createdAt
                    FROM acceptance_record
                    WHERE outcomeId=?
                    ORDER BY createdAt DESC,rowid DESC LIMIT 1
                    """,
                arguments: [outcome.id]
            ), acceptance["id"] as String == acceptanceId,
               acceptance["decision"] as String == "accepted",
               acceptance["outcomeHash"] as String == outcome.hash
            else {
                throw MemoryPromotionAuthorizationError.acceptanceInvalid
            }
            guard try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM memory_record_version WHERE id=?",
                arguments: [draft.id]
            ) == 0 else {
                throw MemoryPromotionAuthorizationError.sourceMismatch
            }
            let record = try Self.record(
                draft: draft,
                version: 1,
                status: .active,
                createdAt: at,
                updatedAt: at
            )
            try Self.insert(record, database: db)
            let verificationHash: String = verification["evidenceHash"]
            let acceptanceHash = try CanonicalContractCodingV1.hash(
                AcceptanceDependencyHashMaterial(
                    id: acceptanceId,
                    outcomeId: outcome.id,
                    outcomeVersion: outcome.version,
                    outcomeHash: outcome.hash,
                    decision: "accepted"
                )
            )
            let dependencies: [MemoryDependencyDraftV1] = [
                try MemoryDependencyDraftV1(
                    id: "memory:\(record.id):1:outcome",
                    memory: record.ref,
                    dependencyType: .outcome,
                    dependencyId: outcome.id,
                    dependencyVersion: outcome.version,
                    dependencyHash: outcome.hash,
                    createdAt: at
                ),
                try MemoryDependencyDraftV1(
                    id: "memory:\(record.id):1:verification",
                    memory: record.ref,
                    dependencyType: .verification,
                    dependencyId: verificationId,
                    dependencyVersion: 1,
                    dependencyHash: verificationHash,
                    createdAt: at
                ),
                try MemoryDependencyDraftV1(
                    id: "memory:\(record.id):1:acceptance",
                    memory: record.ref,
                    dependencyType: .acceptance,
                    dependencyId: acceptanceId,
                    dependencyVersion: 1,
                    dependencyHash: acceptanceHash,
                    createdAt: at
                ),
            ]
            for dependency in dependencies {
                _ = try Self.appendDependency(dependency, database: db)
            }
            return record
        }
    }

    package func appendDependency(
        _ draft: MemoryDependencyDraftV1
    ) throws -> MemoryDependencyV1 {
        try database.pool.write { db in
            try Self.appendDependency(draft, database: db)
        }
    }

    package func dependencies(
        memory: MemoryRecordRefV1
    ) throws -> [MemoryDependencyV1] {
        try database.pool.read { db in
            guard let record = try Self.memory(
                id: memory.id,
                version: memory.version,
                database: db
            ), record.contentHash == memory.hash else {
                throw MemoryPromotionAuthorizationError.sourceMismatch
            }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM memory_dependency
                    WHERE memoryId=? AND memoryVersion=?
                    ORDER BY CASE dependencyType
                      WHEN 'outcome' THEN 0
                      WHEN 'verification' THEN 1
                      WHEN 'acceptance' THEN 2
                      WHEN 'input' THEN 3
                      WHEN 'memory' THEN 4 END,id
                    """,
                arguments: [memory.id, memory.version]
            )
            return try rows.map(Self.dependency(row:))
        }
    }

    package func latest(id: String) throws -> MemoryRecordVersionV1? {
        try CanonicalContractCodingV1.validateNonempty(id)
        return try database.pool.read { db in
            guard let version = try Self.latestVersion(id: id, database: db)
            else { return nil }
            return try Self.memory(id: id, version: version, database: db)
        }
    }

    package func versions(id: String) throws -> [MemoryRecordVersionV1] {
        try CanonicalContractCodingV1.validateNonempty(id)
        return try database.pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM memory_record_version
                    WHERE id=? ORDER BY version
                    """,
                arguments: [id]
            )
            return try rows.map(Self.memory(row:))
        }
    }

    package func injectableMemories(
        ownerType: MemoryOwnerTypeV1,
        ownerId: String,
        campId: String?
    ) throws -> [MemoryRecordVersionV1] {
        try CanonicalContractCodingV1.validateNonempty(ownerId)
        if let campId {
            try CanonicalContractCodingV1.validateCampID(campId)
        }
        return try database.pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT v.* FROM memory_record_version v
                    WHERE v.ownerType=? AND v.ownerId=?
                      AND v.campId IS ? AND v.status='active'
                      AND v.version=(
                        SELECT MAX(v2.version) FROM memory_record_version v2
                        WHERE v2.id=v.id
                      )
                    ORDER BY v.id
                    """,
                arguments: [ownerType.rawValue, ownerId, campId]
            )
            return try rows.map(Self.memory(row:))
        }
    }

    package func tombstone(
        memoryId: String,
        at: Date
    ) throws -> MemoryRecordVersionV1 {
        try CanonicalContractCodingV1.validateNonempty(memoryId)
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.write { db in
            try Self.tombstone(memoryId: memoryId, at: at, database: db)
        }
    }

    package func applyInvalidation(
        _ cause: MemoryInvalidationCauseV1,
        at: Date,
        database db: Database
    ) throws -> [MemoryInvalidationMutationV1] {
        try CanonicalContractCodingV1.validateFinite(at)
        let targetRows = try Self.invalidationTargets(
            cause,
            database: db
        )
        var mutations: [MemoryInvalidationMutationV1] = []
        for target in targetRows.sorted(by: {
            ($0.record.id, $0.record.version) <
                ($1.record.id, $1.record.version)
        }) {
            if target.status == .deletedTombstone {
                _ = try Self.tombstone(
                    memoryId: target.record.id,
                    at: at,
                    database: db
                )
            } else {
                try db.execute(
                    sql: """
                        UPDATE memory_record_version
                        SET status=?,updatedAt=?
                        WHERE id=? AND version=? AND status=?
                        """,
                    arguments: [
                        target.status.rawValue, at, target.record.id,
                        target.record.version, target.record.status.rawValue,
                    ]
                )
                guard db.changesCount == 1 else {
                    throw MemoryPromotionAuthorizationError.sourceMismatch
                }
            }
            mutations.append(MemoryInvalidationMutationV1(
                memoryId: target.record.id,
                memoryVersion: target.record.version,
                from: target.record.status,
                to: target.status
            ))
        }
        return mutations
    }

    package static func authorizedLocalRows(
        cowId: String,
        campId: String,
        database: Database
    ) throws -> [MemoryRecordVersionV1] {
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT v.* FROM memory_record_version v
                WHERE v.status='active'
                  AND v.version=(
                    SELECT MAX(v2.version) FROM memory_record_version v2
                    WHERE v2.id=v.id
                  )
                  AND (
                    v.campId=?
                    OR (v.campId IS NULL AND v.ownerType='user')
                    OR (v.campId IS NULL AND v.ownerType='cow'
                        AND v.ownerId=?)
                  )
                ORDER BY v.id
                """,
            arguments: [campId, cowId]
        )
        return try rows.map(memory(row:))
    }

    package static func activeCampRows(
        campId: String,
        memoryIds: [String],
        database: Database
    ) throws -> [MemoryRecordVersionV1] {
        guard !memoryIds.isEmpty else { return [] }
        let placeholders = Array(
            repeating: "?",
            count: memoryIds.count
        ).joined(separator: ",")
        var arguments: [(any DatabaseValueConvertible)?] = [campId]
        arguments.append(contentsOf: memoryIds)
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT v.* FROM memory_record_version v
                WHERE v.campId=? AND v.status='active'
                  AND v.id IN (\(placeholders))
                  AND v.version=(
                    SELECT MAX(v2.version) FROM memory_record_version v2
                    WHERE v2.id=v.id
                  )
                ORDER BY v.id
                """,
            arguments: StatementArguments(arguments)
        )
        return try rows.map(memory(row:))
    }
}

extension MemoryRecordStore {
    private func requireWriteAuthorization(
        draft: MemoryRecordDraftV1,
        authorizedCowId: String?,
        expectedCampLifecycleVersion: Int?,
        database db: Database
    ) throws {
        if let campId = draft.campId {
            guard let cowId = authorizedCowId,
                  let lifecycleVersion = expectedCampLifecycleVersion
            else {
                throw ResidencyAuthorizationError.missing
            }
            _ = try lifecycleStore.requireActiveCampWrite(
                campId: campId,
                expectedLifecycleVersion: lifecycleVersion,
                database: db
            )
            _ = try CowResidencyStore.requireActiveResidency(
                cowId: cowId,
                campId: campId,
                database: db
            )
        } else {
            guard expectedCampLifecycleVersion == nil else {
                throw MemoryRecordContractError.invalidCampScope
            }
            if let authorizedCowId {
                guard draft.ownerType == .cow,
                      draft.ownerId == authorizedCowId
                else {
                    throw ResidencyAuthorizationError.missing
                }
            }
        }
    }

    private static func record(
        draft: MemoryRecordDraftV1,
        version: Int,
        status: MemoryRecordStatusV1,
        createdAt: Date,
        updatedAt: Date
    ) throws -> MemoryRecordVersionV1 {
        try MemoryRecordVersionV1(
            id: draft.id,
            version: version,
            layer: draft.layer,
            ownerType: draft.ownerType,
            ownerId: draft.ownerId,
            campId: draft.campId,
            title: draft.title,
            bodyText: draft.bodyText,
            contentRef: draft.contentRef,
            contentHash: draft.contentHash,
            status: status,
            sourceType: draft.sourceType,
            applicabilityJson: draft.applicabilityJson,
            createdByActorId: draft.createdByActorId,
            confirmedByActorId: draft.confirmedByActorId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func insert(
        _ record: MemoryRecordVersionV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO memory_record_version(
                  id,version,layer,ownerType,ownerId,campId,title,bodyText,
                  contentRef,contentHash,status,sourceType,applicabilityJson,
                  createdByActorId,confirmedByActorId,createdAt,updatedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                record.id, record.version, record.layer.rawValue,
                record.ownerType.rawValue, record.ownerId, record.campId,
                record.title, record.bodyText, record.contentRef,
                record.contentHash, record.status.rawValue,
                record.sourceType.rawValue, record.applicabilityJson,
                record.createdByActorId, record.confirmedByActorId,
                record.createdAt, record.updatedAt,
            ]
        )
    }

    private static func appendDependency(
        _ draft: MemoryDependencyDraftV1,
        database: Database
    ) throws -> MemoryDependencyV1 {
        guard let memory = try memory(
            id: draft.memory.id,
            version: draft.memory.version,
            database: database
        ), memory.contentHash == draft.memory.hash else {
            throw MemoryPromotionAuthorizationError.sourceMismatch
        }
        try database.execute(
            sql: """
                INSERT INTO memory_dependency(
                  id,memoryId,memoryVersion,dependencyType,dependencyId,
                  dependencyVersion,dependencyHash,createdAt
                ) VALUES (?,?,?,?,?,?,?,?)
                """,
            arguments: [
                draft.id, draft.memory.id, draft.memory.version,
                draft.dependencyType.rawValue, draft.dependencyId,
                draft.dependencyVersion, draft.dependencyHash,
                draft.createdAt,
            ]
        )
        return MemoryDependencyV1(
            id: draft.id,
            memoryId: draft.memory.id,
            memoryVersion: draft.memory.version,
            dependencyType: draft.dependencyType,
            dependencyId: draft.dependencyId,
            dependencyVersion: draft.dependencyVersion,
            dependencyHash: draft.dependencyHash,
            createdAt: draft.createdAt
        )
    }

    private static func latestVersion(
        id: String,
        database: Database
    ) throws -> Int? {
        try Int.fetchOne(
            database,
            sql: "SELECT MAX(version) FROM memory_record_version WHERE id=?",
            arguments: [id]
        )
    }

    private static func memory(
        id: String,
        version: Int,
        database: Database
    ) throws -> MemoryRecordVersionV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM memory_record_version
                WHERE id=? AND version=?
                """,
            arguments: [id, version]
        ) else {
            return nil
        }
        return try memory(row: row)
    }

    private static func memory(
        row: Row
    ) throws -> MemoryRecordVersionV1 {
        guard let layer = MemoryLayerV1(rawValue: row["layer"] as String),
              let owner = MemoryOwnerTypeV1(
                rawValue: row["ownerType"] as String
              ),
              let status = MemoryRecordStatusV1(
                rawValue: row["status"] as String
              ),
              let source = MemorySourceTypeV1(
                rawValue: row["sourceType"] as String
              )
        else {
            throw MemoryPromotionAuthorizationError.sourceMismatch
        }
        return try MemoryRecordVersionV1(
            id: row["id"],
            version: row["version"],
            layer: layer,
            ownerType: owner,
            ownerId: row["ownerId"],
            campId: row["campId"],
            title: row["title"],
            bodyText: row["bodyText"],
            contentRef: row["contentRef"],
            contentHash: row["contentHash"],
            status: status,
            sourceType: source,
            applicabilityJson: row["applicabilityJson"],
            createdByActorId: row["createdByActorId"],
            confirmedByActorId: row["confirmedByActorId"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    private static func dependency(row: Row) throws -> MemoryDependencyV1 {
        guard let type = MemoryDependencyTypeV1(
            rawValue: row["dependencyType"] as String
        ) else {
            throw MemoryPromotionAuthorizationError.sourceMismatch
        }
        return MemoryDependencyV1(
            id: row["id"],
            memoryId: row["memoryId"],
            memoryVersion: row["memoryVersion"],
            dependencyType: type,
            dependencyId: row["dependencyId"],
            dependencyVersion: row["dependencyVersion"],
            dependencyHash: row["dependencyHash"],
            createdAt: row["createdAt"]
        )
    }

    private static func tombstone(
        memoryId: String,
        at: Date,
        database: Database
    ) throws -> MemoryRecordVersionV1 {
        guard let latest = try latestVersion(
            id: memoryId,
            database: database
        ) else {
            throw MemoryPromotionAuthorizationError.sourceMismatch
        }
        try database.execute(
            sql: """
                UPDATE memory_record_version
                SET title='[deleted]',bodyText=NULL,contentRef=NULL,
                    status='deletedTombstone',applicabilityJson='{}',updatedAt=?
                WHERE id=? AND status<>'deletedTombstone'
                """,
            arguments: [at, memoryId]
        )
        guard let result = try memory(
            id: memoryId,
            version: latest,
            database: database
        ), result.status == .deletedTombstone,
           result.bodyText == nil,
           result.contentRef == nil else {
            throw MemoryPromotionAuthorizationError.sourceMismatch
        }
        return result
    }

    private static func invalidationTargets(
        _ cause: MemoryInvalidationCauseV1,
        database: Database
    ) throws -> [InvalidationTarget] {
        var requested: [String: MemoryRecordStatusV1] = [:]

        func merge(
            _ ids: [String],
            status: MemoryRecordStatusV1
        ) {
            for id in ids {
                let existing = requested[id]
                if existing == .deletedTombstone { continue }
                if status == .deletedTombstone || status == .invalidated
                    || existing == nil
                {
                    requested[id] = status
                }
            }
        }

        func ids(
            type: MemoryDependencyTypeV1,
            id: String,
            version: Int?,
            hash: String? = nil
        ) throws -> [String] {
            var clauses = ["d.dependencyType=?", "d.dependencyId=?"]
            var args: [(any DatabaseValueConvertible)?] = [
                type.rawValue, id,
            ]
            if let version {
                clauses.append("d.dependencyVersion=?")
                args.append(version)
            }
            if let hash {
                clauses.append("d.dependencyHash=?")
                args.append(hash)
            }
            return try String.fetchAll(
                database,
                sql: """
                    SELECT DISTINCT v.id
                    FROM memory_dependency d
                    JOIN memory_record_version v
                      ON v.id=d.memoryId AND v.version=d.memoryVersion
                    WHERE \(clauses.joined(separator: " AND "))
                      AND v.version=(
                        SELECT MAX(v2.version) FROM memory_record_version v2
                        WHERE v2.id=v.id
                      )
                      AND v.status IN ('active','needsReview')
                    ORDER BY v.id
                    """,
                arguments: StatementArguments(args)
            )
        }

        switch cause {
        case let .outcomeReturned(outcomeId, version, acceptanceId):
            merge(try ids(type: .outcome, id: outcomeId, version: version),
                  status: .needsReview)
            if let acceptanceId {
                merge(try ids(
                    type: .acceptance,
                    id: acceptanceId,
                    version: nil
                ), status: .needsReview)
            }
        case let .acceptanceRevoked(outcomeId, version, acceptanceId):
            merge(try ids(type: .outcome, id: outcomeId, version: version),
                  status: .needsReview)
            merge(try ids(
                type: .acceptance,
                id: acceptanceId,
                version: nil
            ), status: .needsReview)
        case let .verificationInvalidated(
            outcomeId, version, verificationIds
        ):
            merge(try ids(type: .outcome, id: outcomeId, version: version),
                  status: .needsReview)
            for verificationId in verificationIds {
                merge(try ids(
                    type: .verification,
                    id: verificationId,
                    version: nil
                ), status: .invalidated)
            }
        case let .outcomeSuperseded(outcomeId, version):
            merge(try ids(type: .outcome, id: outcomeId, version: version),
                  status: .needsReview)
        case let .dependencyInvalidated(type, id, version, hash, deleted):
            merge(try ids(type: type, id: id, version: version, hash: hash),
                  status: deleted ? .deletedTombstone : .invalidated)
        }

        var result: [InvalidationTarget] = []
        for (id, status) in requested {
            guard let latest = try latestVersion(id: id, database: database),
                  let record = try memory(
                    id: id,
                    version: latest,
                    database: database
                  ), record.status != status,
                  record.status != .deletedTombstone
            else {
                continue
            }
            result.append(InvalidationTarget(record: record, status: status))
        }
        return result
    }

    private struct InvalidationTarget {
        let record: MemoryRecordVersionV1
        let status: MemoryRecordStatusV1
    }

    private struct AcceptanceDependencyHashMaterial: Codable {
        let id: String
        let outcomeId: String
        let outcomeVersion: Int
        let outcomeHash: String
        let decision: String
    }
}
