import Foundation
import GRDB

/// Coding 牧场产品壳初始化。已有普通伙伴的老用户保持专家模式；空名册才补基础牛。
public struct ProductBootstrapService: Sendable {
    private let db: AppDatabase

    public init(db: AppDatabase) {
        self.db = db
    }

    @discardableResult
    public func ensureBootstrap() throws -> CodingRanchBootstrapResult {
        try db.ensureCodingRanchBootstrap()
    }
}

extension AppDatabase {
    @discardableResult
    public func ensureCodingRanchBootstrap() throws -> CodingRanchBootstrapResult {
        return try pool.write { database in
            let camp = try Self.ensureDefaultCamp(database)
            if var guide = try CompanionRecord
                .filter(
                    Column("campId") == camp.id
                        && Column("kind") == CompanionRecord.Kind.guide.rawValue
                )
                .fetchOne(database), guide.name == "向导" {
                guide.name = "营地管家"
                guide.rolePrompt = "你是 Coding 牧场的营地管家，负责帮助用户整理营地、解释反刍结果并提出可确认的放牛建议。"
                try guide.update(database)
            }

            if let existingBase = try CompanionRecord.fetchOne(database, key: CowTemplate.baseCowId) {
                _ = try CowResidencyStore.synchronizeCompanion(
                    existingBase,
                    provisionActiveResidency: existingBase.campId != nil,
                    database: database
                )
                return CodingRanchBootstrapResult(
                    camp: camp,
                    baseCow: existingBase,
                    newcomerMode: true
                )
            }

            let regularCount = try CompanionRecord
                .filter(Column("kind") == CompanionRecord.Kind.regular.rawValue)
                .fetchCount(database)
            guard regularCount == 0 else {
                return CodingRanchBootstrapResult(camp: camp, baseCow: nil, newcomerMode: false)
            }

            let baseCow = CowTemplate.baseCow(campId: camp.id)
            try baseCow.insert(database)
            _ = try CowResidencyStore.synchronizeCompanion(
                baseCow,
                provisionActiveResidency: true,
                database: database
            )

            try Self.appendEvent(
                database,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.baseCowProvisioned,
                payload: [
                    "campId": .string(camp.id),
                    "companionId": .string(baseCow.id),
                ]
            )

            return CodingRanchBootstrapResult(camp: camp, baseCow: baseCow, newcomerMode: true)
        }
    }
}
