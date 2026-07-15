import SwiftUI
import AgentLoopCore

/// V1.1a:供给线(RuntimeProfile)管理——设置页卡片内容。
struct RuntimeProfileSection: View {
    @Environment(AppStore.self) private var store
    @State private var editingProfile: ProfileDraft?
    @State private var reconciliation: ReconciliationContext?
    @State private var deletingProfile: RuntimeProfileRecord?
    @State private var refreshingProfileId: String?
    @State private var refreshResult: String?

    struct ReconciliationContext: Identifiable {
        var id: String { targetProfile.id }
        let targetProfile: RuntimeProfileRecord
        let items: [ReconciliationItem]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CampSectionTitle("供给线")
                Spacer()
                Button {
                    editingProfile = ProfileDraft()
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .buttonStyle(CampSecondaryButtonStyle())
            }
            Text("模型从哪来:官方 API、自定义网关或 ChatGPT 登录。伙伴可以各选各的供给线。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)

            ForEach(store.runtimeProfiles) { profile in
                profileRow(profile)
            }

            if let current = store.currentRuntimeProfile {
                Label("当前生效:\(current.name)(\(Self.kindLabel(current.kind)))", systemImage: "bolt.circle")
                    .font(.caption)
                    .foregroundStyle(Camp.moss)
            }
            if let refreshResult {
                Text(refreshResult)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
        .sheet(item: $editingProfile) { draft in
            ProfileEditorSheet(draft: draft) { record in
                if let record { store.saveRuntimeProfileAndReload(record) }
                editingProfile = nil
            }
        }
        .sheet(item: $reconciliation) { context in
            ReconciliationSheet(context: context) { inheritCompanionIds, resetScopes in
                store.switchDefaultRuntimeProfile(
                    id: context.targetProfile.id,
                    inheritCompanionIds: inheritCompanionIds,
                    resetSettingScopes: resetScopes
                )
                reconciliation = nil
            } onCancel: {
                reconciliation = nil
            }
            .environment(store)
        }
        .confirmationDialog(
            "删除供给线「\(deletingProfile?.name ?? "")」?",
            isPresented: Binding(
                get: { deletingProfile != nil },
                set: { if !$0 { deletingProfile = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let profile = deletingProfile { store.deleteRuntimeProfileAndReload(id: profile.id) }
                deletingProfile = nil
            }
            Button("再想想", role: .cancel) { deletingProfile = nil }
        } message: {
            Text("默认供给线或仍被伙伴使用的供给线不能删除。")
        }
    }

    private func profileRow(_ profile: RuntimeProfileRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: Self.kindIcon(profile.kind))
                .foregroundStyle(profile.isDefault ? Camp.ember : Camp.stone)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Camp.ink)
                    if profile.isDefault {
                        CampChip(text: "默认", color: Camp.ember, icon: "star.fill")
                    }
                }
                Text(profileCaption(profile))
                    .font(.caption2)
                    .foregroundStyle(Camp.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if refreshingProfileId == profile.id {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    refreshCatalog(profile)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Camp.stone)
                .help("刷新这条供给线的模型目录")
            }
            if !profile.isDefault {
                Button("设为默认") { beginSwitch(to: profile) }
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
            }
            Menu {
                Button("编辑…") { editingProfile = ProfileDraft(record: profile) }
                Divider()
                Button("删除…", role: .destructive) { deletingProfile = profile }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.vertical, 4)
    }

    private func profileCaption(_ profile: RuntimeProfileRecord) -> String {
        var parts = [Self.kindLabel(profile.kind)]
        if let baseURL = profile.baseURL, !baseURL.isEmpty { parts.append(baseURL) }
        let count = store.catalogChoices(profile: profile).count
        parts.append("目录 \(count) 个模型")
        return parts.joined(separator: " · ")
    }

    private func beginSwitch(to profile: RuntimeProfileRecord) {
        let items = store.reconciliationItems(switchingTo: profile.id)
        if items.isEmpty {
            store.switchDefaultRuntimeProfile(id: profile.id, inheritCompanionIds: [], resetSettingScopes: [])
        } else {
            reconciliation = ReconciliationContext(targetProfile: profile, items: items)
        }
    }

    private func refreshCatalog(_ profile: RuntimeProfileRecord) {
        refreshingProfileId = profile.id
        Task { @MainActor in
            let message = await store.refreshCatalog(profileId: profile.id)
            refreshingProfileId = nil
            refreshResult = message
        }
    }

    static func kindLabel(_ kind: RuntimeProfileKind) -> String {
        switch kind {
        case .anthropicAPI: "Anthropic API / 网关"
        case .openAIAPI: "OpenAI API"
        case .chatGPTOAuth: "ChatGPT 登录"
        }
    }

    static func kindIcon(_ kind: RuntimeProfileKind) -> String {
        switch kind {
        case .anthropicAPI: "shippingbox"
        case .openAIAPI: "shippingbox.fill"
        case .chatGPTOAuth: "person.crop.circle.badge.checkmark"
        }
    }
}

// MARK: - 供给线编辑

struct ProfileDraft: Identifiable {
    var id: String
    var kind: RuntimeProfileKind = .anthropicAPI
    var name = ""
    var baseURL = ""
    var isNew: Bool

    init() {
        id = UUID().uuidString
        isNew = true
    }

    init(record: RuntimeProfileRecord) {
        id = record.id
        kind = record.kind
        name = record.name
        baseURL = record.baseURL ?? ""
        isNew = false
    }
}

private struct ProfileEditorSheet: View {
    @State var draft: ProfileDraft
    var onFinish: (RuntimeProfileRecord?) -> Void

    @Environment(AppStore.self) private var store
    @State private var validation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.isNew ? "新建供给线" : "编辑供给线")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Camp.ink)

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("类型")
                Picker("类型", selection: $draft.kind) {
                    ForEach(RuntimeProfileKind.allCases, id: \.self) { kind in
                        Text(RuntimeProfileSection.kindLabel(kind)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!draft.isNew)
                if !draft.isNew {
                    Text("类型不可改;要换类型请新建一条供给线。")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                CampSectionTitle("名字")
                TextField("比如:公司网关 / 我的 ChatGPT", text: $draft.name)
                    .textFieldStyle(.plain)
                    .profileFieldChrome()
            }

            if draft.kind != .chatGPTOAuth {
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("API 端点")
                    TextField(AppStore.defaultBaseURL, text: $draft.baseURL)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .profileFieldChrome()
                    Text("凭据用设置页保存的 API Key(钥匙串);ChatGPT 登录类型走网页授权。")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                }
            }

            if let validation {
                Label(validation, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
            }

            HStack {
                Spacer()
                Button("取消") { onFinish(nil) }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460)
        .background(Camp.canvas)
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            validation = "给这条供给线起个名字"
            return
        }
        let baseURL = draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.kind != .chatGPTOAuth, !baseURL.isEmpty, ProviderEndpoint.normalizedBaseURL(baseURL) == nil {
            validation = "API 端点无效:需要 http(s):// 开头的完整地址"
            return
        }
        let existing = store.runtimeProfiles.first { $0.id == draft.id }
        var record = existing ?? RuntimeProfileRecord.new(kind: draft.kind, name: name)
        record.name = name
        record.baseURL = draft.kind == .chatGPTOAuth ? nil : (baseURL.isEmpty ? nil : baseURL)
        if record.credentialAccount == nil {
            record.credentialAccount = AppStore.credentialAccount(for: draft.kind)
        }
        onFinish(record)
    }
}

// MARK: - 切换对账

private struct ReconciliationSheet: View {
    let context: RuntimeProfileSection.ReconciliationContext
    var onConfirm: (_ inheritCompanionIds: Set<String>, _ resetScopes: Set<String>) -> Void
    var onCancel: () -> Void

    @State private var inheritCompanionIds: Set<String> = []
    @State private var resetScopes: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("切换到「\(context.targetProfile.name)」前先对个账", systemImage: "list.bullet.clipboard")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Camp.ink)
            Text("下面这些还钉着新供给线目录里没有的模型。保持不动的,派单时会被拦下来并说明原因;也可以改成跟随供给线默认。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(context.items) { item in
                        row(item)
                    }
                }
            }
            .frame(maxHeight: 260)

            HStack {
                Button("全部改跟随默认") {
                    inheritCompanionIds = Set(context.items.compactMap { item in
                        if case .companion(let id, _) = item.scope { return id }
                        return nil
                    })
                    resetScopes = Set(context.items.compactMap { item in
                        if case .companion = item.scope { return nil }
                        return item.id
                    })
                }
                .buttonStyle(CampSecondaryButtonStyle())
                Spacer()
                Button("取消") { onCancel() }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("切换") { onConfirm(inheritCompanionIds, resetScopes) }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
        .background(Camp.canvas)
    }

    private func row(_ item: ReconciliationItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(item.scope))
                .foregroundStyle(Camp.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(scopeLabel(item.scope))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("钉着 \(item.model)")
                    .font(.caption2)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            Picker("", selection: binding(for: item)) {
                Text("保持不动").tag(false)
                Text("改跟随默认").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
        }
        .padding(8)
        .background(Camp.surface, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
    }

    private func binding(for item: ReconciliationItem) -> Binding<Bool> {
        if case .companion(let id, _) = item.scope {
            return Binding(
                get: { inheritCompanionIds.contains(id) },
                set: { on in
                    if on { inheritCompanionIds.insert(id) } else { inheritCompanionIds.remove(id) }
                }
            )
        }
        return Binding(
            get: { resetScopes.contains(item.id) },
            set: { on in
                if on { resetScopes.insert(item.id) } else { resetScopes.remove(item.id) }
            }
        )
    }

    private func scopeLabel(_ scope: ReconciliationItem.Scope) -> String {
        switch scope {
        case .companion(_, let name): "伙伴「\(name)」"
        case .defaultModel: "默认模型"
        case .distillModel: "蒸馏模型"
        case .plannerModel: "规划模型"
        }
    }

    private func iconName(_ scope: ReconciliationItem.Scope) -> String {
        switch scope {
        case .companion: "pawprint"
        default: "slider.horizontal.3"
        }
    }
}

private extension View {
    func profileFieldChrome() -> some View {
        padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
    }
}
