import Foundation
import GRDB

public enum RuntimeProfileStoreError: LocalizedError, Sendable, Equatable {
    case defaultProfileNotFound
    case profileNotFound(String)
    case companionNotFound(String)
    case trustedCatalogUnavailable(String)
    case invalidReconciliationCommand
    case cannotDeleteDefaultProfile(String)
    case profileInUse(profileId: String, companionCount: Int)
    case credentialAttachmentConflict(profileId: String)

    public var errorDescription: String? {
        switch self {
        case .defaultProfileNotFound:
            return "还没有默认供给线"
        case .profileNotFound(let id):
            return "供给线不存在：\(id)"
        case .companionNotFound(let id):
            return "伙伴不存在：\(id)"
        case .trustedCatalogUnavailable:
            return "供给线的模型目录不可用"
        case .invalidReconciliationCommand:
            return "供给线对账命令已失效"
        case .cannotDeleteDefaultProfile(let name):
            return "不能删除当前默认供给线「\(name)」"
        case .profileInUse(_, let companionCount):
            return "还有 \(companionCount) 个伙伴正在使用这条供给线，不能删除"
        case .credentialAttachmentConflict:
            return "默认供给线已变化，未写入凭据绑定"
        }
    }
}

package struct RuntimeCredentialAttachmentTarget: Sendable, Equatable {
    fileprivate let profileId: String
    fileprivate let expectedKind: RuntimeProfileKind

    fileprivate init(
        profileId: String,
        expectedKind: RuntimeProfileKind
    ) {
        self.profileId = profileId
        self.expectedKind = expectedKind
    }
}

extension AppDatabase {
    /// 应用对账结论:伙伴项改 inherit(保留 model 字符串便于追溯);defaultModel 项
    /// 重置为受控目录第一项;distill/planner 项清空。伙伴项以外不开 DB 写事务。
    public func applyReconciliation(
        items: [ReconciliationItem],
        defaults: ProfileScopedDefaults = ProfileScopedDefaults()
    ) throws {
        struct PreparedDefaultMutation {
            let profileId: String
            let suffix: String
            let value: String
        }

        let preparedDefaults: [PreparedDefaultMutation] = try pool.write {
            database in
            var seenScopes = Set<String>()
            var defaultsMutations: [PreparedDefaultMutation] = []
            var companionsToUpdate: [CompanionRecord] = []

            for item in items {
                guard let profile = try RuntimeProfileRecord.fetchOne(
                    database,
                    key: item.profileId
                ) else {
                    throw RuntimeProfileStoreError.profileNotFound(
                        item.profileId
                    )
                }
                guard profile.name == item.profileName else {
                    throw RuntimeProfileStoreError
                        .invalidReconciliationCommand
                }

                let catalog = ModelCatalogService.trustedCatalog(
                    profile: profile,
                    defaults: defaults
                )
                if ModelCatalogService.isOfficialCatalogProfile(profile),
                   catalog == nil
                {
                    throw RuntimeProfileStoreError
                        .trustedCatalogUnavailable(profile.id)
                }
                let allowed = Set(catalog ?? [])
                guard !item.model.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                      !allowed.contains(item.model)
                else {
                    throw RuntimeProfileStoreError
                        .invalidReconciliationCommand
                }

                let scopeKey: String
                switch item.scope {
                case .companion(let id, let name):
                    scopeKey = "companion:\(id)"
                    guard var companion = try CompanionRecord.fetchOne(
                        database,
                        key: id
                    ) else {
                        throw RuntimeProfileStoreError.companionNotFound(id)
                    }
                    guard companion.name == name,
                          companion.model == item.model,
                          companion.modelPolicy == .pinned,
                          companion.runtimeProfileId == nil
                            || companion.runtimeProfileId == profile.id
                    else {
                        throw RuntimeProfileStoreError
                            .invalidReconciliationCommand
                    }
                    companion.modelPolicy = .inherit
                    companionsToUpdate.append(companion)
                case .defaultModel:
                    scopeKey = "default:\(profile.id)"
                    guard defaults.defaultModel(
                        profileID: profile.id,
                        fallback: item.model
                    ) == item.model,
                          let first = catalog?.first
                    else {
                        throw RuntimeProfileStoreError
                            .invalidReconciliationCommand
                    }
                    defaultsMutations.append(PreparedDefaultMutation(
                        profileId: profile.id,
                        suffix: "defaultModel",
                        value: first
                    ))
                case .distillModel:
                    scopeKey = "distill:\(profile.id)"
                    guard defaults.distillModel(profileID: profile.id)
                            == item.model
                    else {
                        throw RuntimeProfileStoreError
                            .invalidReconciliationCommand
                    }
                    defaultsMutations.append(PreparedDefaultMutation(
                        profileId: profile.id,
                        suffix: "distillModel",
                        value: ""
                    ))
                case .plannerModel:
                    scopeKey = "planner:\(profile.id)"
                    guard defaults.plannerModel(profileID: profile.id)
                            == item.model
                    else {
                        throw RuntimeProfileStoreError
                            .invalidReconciliationCommand
                    }
                    defaultsMutations.append(PreparedDefaultMutation(
                        profileId: profile.id,
                        suffix: "plannerModel",
                        value: ""
                    ))
                }
                guard seenScopes.insert(scopeKey).inserted else {
                    throw RuntimeProfileStoreError
                        .invalidReconciliationCommand
                }
            }

            for companion in companionsToUpdate {
                try companion.update(database)
            }
            return defaultsMutations
        }

        for mutation in preparedDefaults {
            defaults.setString(
                mutation.value,
                profileID: mutation.profileId,
                suffix: mutation.suffix
            )
        }
    }

    public func runtimeProfiles() throws -> [RuntimeProfileRecord] {
        try pool.read { db in
            try RuntimeProfileRecord
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func runtimeProfile(id: String) throws -> RuntimeProfileRecord? {
        try pool.read { db in
            try RuntimeProfileRecord.fetchOne(db, key: id)
        }
    }

    public func saveRuntimeProfile(_ profile: RuntimeProfileRecord) throws {
        try pool.write { db in
            if profile.isDefault {
                try RuntimeProfileRecord
                    .filter(Column("id") != profile.id)
                    .updateAll(db, Column("isDefault").set(to: false))
            }
            try profile.save(db)
        }
    }

    public func defaultProfile() throws -> RuntimeProfileRecord? {
        try pool.read { db in
            try RuntimeProfileRecord
                .filter(Column("isDefault") == true)
                .order(Column("createdAt"), Column.rowID)
                .fetchOne(db)
        }
    }

    public func setDefaultProfile(id: String) throws {
        _ = try setDefaultProfileReturningRecord(id: id)
    }

    package func setDefaultProfileReturningRecord(
        id: String
    ) throws -> RuntimeProfileRecord {
        try pool.write { db in
            guard var target = try RuntimeProfileRecord.fetchOne(db, key: id) else {
                throw RuntimeProfileStoreError.profileNotFound(id)
            }
            try RuntimeProfileRecord.updateAll(db, Column("isDefault").set(to: false))
            target.isDefault = true
            try target.update(db)
            return target
        }
    }

    public func deleteRuntimeProfile(id: String) throws {
        try pool.write { db in
            guard let profile = try RuntimeProfileRecord.fetchOne(db, key: id) else {
                throw RuntimeProfileStoreError.profileNotFound(id)
            }
            if profile.isDefault {
                throw RuntimeProfileStoreError.cannotDeleteDefaultProfile(profile.name)
            }
            let references = try CompanionRecord
                .filter(Column("runtimeProfileId") == id)
                .fetchCount(db)
            guard references == 0 else {
                throw RuntimeProfileStoreError.profileInUse(profileId: id, companionCount: references)
            }
            try RuntimeProfileRecord.deleteOne(db, key: id)
        }
    }

    public func reconciliationReport(
        switchingTo profileId: String,
        defaults: ProfileScopedDefaults = ProfileScopedDefaults()
    ) throws -> [ReconciliationItem] {
        let profile = try pool.read { db in
            try RuntimeProfileRecord.fetchOne(db, key: profileId)
        }
        guard let profile else {
            throw RuntimeProfileStoreError.profileNotFound(profileId)
        }
        guard !profile.kind.isCLI else {
            return []
        }
        let catalog = ModelCatalogService.trustedCatalog(
            profile: profile,
            defaults: defaults
        )
        if ModelCatalogService.isOfficialCatalogProfile(profile),
           catalog == nil
        {
            throw RuntimeProfileStoreError
                .trustedCatalogUnavailable(profile.id)
        }
        guard let catalog else { return [] }
        let allowed = Set(catalog)
        return try pool.read { db in
            var items: [ReconciliationItem] = []
            let companions = try CompanionRecord
                .filter(Column("modelPolicy") == CompanionModelPolicy.pinned.rawValue)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
            for companion in companions where companion.runtimeProfileId == nil || companion.runtimeProfileId == profileId {
                if !allowed.contains(companion.model) {
                    items.append(
                        ReconciliationItem(
                            scope: .companion(id: companion.id, name: companion.name),
                            model: companion.model,
                            profileId: profile.id,
                            profileName: profile.name
                        )
                    )
                }
            }

            let defaultModel = defaults.defaultModel(profileID: profile.id, fallback: KernelDefaults.defaultGuideModel)
            appendProfileSettingIfNeeded(
                scope: .defaultModel,
                model: defaultModel,
                profile: profile,
                allowed: allowed,
                items: &items
            )
            appendProfileSettingIfNeeded(
                scope: .distillModel,
                model: defaults.distillModel(profileID: profile.id),
                profile: profile,
                allowed: allowed,
                items: &items
            )
            appendProfileSettingIfNeeded(
                scope: .plannerModel,
                model: defaults.plannerModel(profileID: profile.id),
                profile: profile,
                allowed: allowed,
                items: &items
            )
            return items
        }
    }

    package func prepareDefaultAPIKeyAttachment() throws
        -> RuntimeCredentialAttachmentTarget?
    {
        try pool.read { database in
            let defaults = try RuntimeProfileRecord
                .filter(Column("isDefault") == true)
                .limit(2)
                .fetchAll(database)
            guard defaults.count == 1, let profile = defaults.first else {
                throw RuntimeProfileStoreError.defaultProfileNotFound
            }
            guard profile.kind == .anthropicAPI
                    || profile.kind == .openAIAPI,
                  profile.credentialAccount == nil
            else {
                return nil
            }
            return RuntimeCredentialAttachmentTarget(
                profileId: profile.id,
                expectedKind: profile.kind
            )
        }
    }

    package func commitDefaultAPIKeyAttachment(
        _ target: RuntimeCredentialAttachmentTarget,
        account: String
    ) throws -> RuntimeProfileRecord {
        try pool.write { database in
            try database.execute(
                sql: """
                    UPDATE runtime_profile
                    SET credentialAccount = ?
                    WHERE id = ?
                      AND isDefault = 1
                      AND kind = ?
                      AND credentialAccount IS NULL
                    """,
                arguments: [
                    account,
                    target.profileId,
                    target.expectedKind.rawValue,
                ]
            )
            if database.changesCount == 1,
               let committed = try RuntimeProfileRecord.fetchOne(
                    database,
                    key: target.profileId
               )
            {
                return committed
            }

            guard let current = try RuntimeProfileRecord.fetchOne(
                database,
                key: target.profileId
            ), current.isDefault,
                  current.kind == target.expectedKind,
                  current.credentialAccount == account
            else {
                throw RuntimeProfileStoreError
                    .credentialAttachmentConflict(
                        profileId: target.profileId
                    )
            }
            return current
        }
    }

    private func appendProfileSettingIfNeeded(
        scope: ReconciliationItem.Scope,
        model rawModel: String,
        profile: RuntimeProfileRecord,
        allowed: Set<String>,
        items: inout [ReconciliationItem]
    ) {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, !allowed.contains(model) else { return }
        items.append(
            ReconciliationItem(
                scope: scope,
                model: model,
                profileId: profile.id,
                profileName: profile.name
            )
        )
    }
}
