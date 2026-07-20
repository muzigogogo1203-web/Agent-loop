import Foundation

public struct ProfileScopedDefaults: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func key(profileID: String, suffix: String) -> String {
        "profile.\(profileID).\(suffix)"
    }

    public func string(profileID: String, suffix: String) -> String? {
        defaults.string(forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func setString(_ value: String, profileID: String, suffix: String) {
        defaults.set(value, forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func bool(profileID: String, suffix: String) -> Bool {
        defaults.bool(forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func setBool(_ value: Bool, profileID: String, suffix: String) {
        defaults.set(value, forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func stringArray(profileID: String, suffix: String) -> [String]? {
        defaults.stringArray(forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func setStringArray(_ value: [String], profileID: String, suffix: String) {
        defaults.set(value, forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func date(profileID: String, suffix: String) -> Date? {
        let key = Self.key(profileID: profileID, suffix: suffix)
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.object(forKey: key) as? Date
    }

    public func setDate(_ value: Date, profileID: String, suffix: String) {
        defaults.set(value, forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func remove(profileID: String, suffix: String) {
        defaults.removeObject(forKey: Self.key(profileID: profileID, suffix: suffix))
    }

    public func defaultModel(profileID: String, fallback: String) -> String {
        let stored = string(profileID: profileID, suffix: "defaultModel")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? fallback : stored
    }

    public func distillModel(profileID: String) -> String {
        string(profileID: profileID, suffix: "distillModel") ?? ""
    }

    public func plannerModel(profileID: String) -> String {
        string(profileID: profileID, suffix: "plannerModel") ?? ""
    }

    public func modelChoices(profileID: String, fallback: [String]) -> [String] {
        guard let stored = stringArray(profileID: profileID, suffix: "modelChoices"),
              !stored.isEmpty else {
            return fallback
        }
        return stored
    }

    public func manualModels(profileID: String) -> [String] {
        stringArray(profileID: profileID, suffix: "manualModels") ?? []
    }

    public func setManualModels(_ models: [String], profileID: String) {
        setStringArray(Self.uniqueModels(models), profileID: profileID, suffix: "manualModels")
    }

    public func cachedCatalog(profileID: String) -> [String]? {
        stringArray(profileID: profileID, suffix: "modelCatalog")
    }

    @discardableResult
    public func clampModelSelections(profileID: String, catalog: [String]) -> Bool {
        guard !catalog.isEmpty else { return false }
        var changed = false
        let defaultValue = defaultModel(profileID: profileID, fallback: catalog[0])
        if !catalog.contains(defaultValue) {
            setString(catalog[0], profileID: profileID, suffix: "defaultModel")
            changed = true
        }
        for suffix in ["distillModel", "plannerModel"] {
            let value = string(profileID: profileID, suffix: suffix) ?? ""
            if !value.isEmpty && !catalog.contains(value) {
                setString("", profileID: profileID, suffix: suffix)
                changed = true
            }
        }
        return changed
    }

    public func setCachedCatalog(_ models: [String], fetchedAt: Date, profileID: String) {
        setStringArray(Self.uniqueModels(models), profileID: profileID, suffix: "modelCatalog")
        setDate(fetchedAt, profileID: profileID, suffix: "modelCatalogFetchedAt")
    }

    public func copyLegacyModelDefaults(
        to profileID: String,
        fallbackDefaultModel: String,
        fallbackModelChoices: [String]
    ) {
        copyStringIfMissing(
            legacyKey: "defaultModel",
            profileID: profileID,
            suffix: "defaultModel",
            fallback: fallbackDefaultModel
        )
        copyStringIfMissing(
            legacyKey: "distillModel",
            profileID: profileID,
            suffix: "distillModel",
            fallback: ""
        )
        copyStringIfMissing(
            legacyKey: "plannerModel",
            profileID: profileID,
            suffix: "plannerModel",
            fallback: ""
        )
        let modelChoicesKey = Self.key(profileID: profileID, suffix: "modelChoices")
        if defaults.object(forKey: modelChoicesKey) == nil {
            let choices = defaults.stringArray(forKey: "modelChoices") ?? fallbackModelChoices
            defaults.set(Self.uniqueModels(choices.isEmpty ? fallbackModelChoices : choices), forKey: modelChoicesKey)
        }
    }

    private func copyStringIfMissing(
        legacyKey: String,
        profileID: String,
        suffix: String,
        fallback: String
    ) {
        let profileKey = Self.key(profileID: profileID, suffix: suffix)
        guard defaults.object(forKey: profileKey) == nil else { return }
        defaults.set(defaults.string(forKey: legacyKey) ?? fallback, forKey: profileKey)
    }

    public static func uniqueModels(_ models: [String]) -> [String] {
        var seen = Set<String>()
        return models.compactMap { raw in
            let model = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty, seen.insert(model).inserted else { return nil }
            return model
        }
    }
}
