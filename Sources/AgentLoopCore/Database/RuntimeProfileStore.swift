import Foundation
import GRDB

public enum RuntimeProfileStoreError: LocalizedError, Sendable, Equatable {
    case defaultProfileNotFound
    case profileNotFound(String)
    case cannotDeleteDefaultProfile(String)
    case profileInUse(profileId: String, companionCount: Int)

    public var errorDescription: String? {
        switch self {
        case .defaultProfileNotFound:
            return "还没有默认供给线"
        case .profileNotFound(let id):
            return "供给线不存在：\(id)"
        case .cannotDeleteDefaultProfile(let name):
            return "不能删除当前默认供给线「\(name)」"
        case .profileInUse(_, let companionCount):
            return "还有 \(companionCount) 个伙伴正在使用这条供给线，不能删除"
        }
    }
}

extension AppDatabase {
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
        try pool.write { db in
            guard var target = try RuntimeProfileRecord.fetchOne(db, key: id) else {
                throw RuntimeProfileStoreError.profileNotFound(id)
            }
            try RuntimeProfileRecord.updateAll(db, Column("isDefault").set(to: false))
            target.isDefault = true
            try target.update(db)
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
        guard let catalog = ModelCatalogService.trustedCatalog(profile: profile, defaults: defaults) else {
            return []
        }
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
