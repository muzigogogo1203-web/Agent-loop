import SwiftUI
import AgentLoopCore

struct CompanionEditorView: View {
    @Environment(AppStore.self) private var store
    let companionId: String?
    var onDone: () -> Void

    @State private var name = ""
    @State private var color = "purple"
    @State private var rolePrompt = ""
    @State private var modelChoice = "claude-sonnet-4-6"
    @State private var customModel = ""
    /// V1.1a:供给线选择("" = 跟随默认供给线)与模型策略
    @State private var profileChoice = ""
    @State private var modelPolicy: CompanionModelPolicy = .pinned
    @State private var enabledTools: Set<String> = Set(ToolAccess.builtinCapabilityNames)
    @State private var saveError: String?
    /// 各驿站的已知工具（连接后取自 Manager 缓存）
    @State private var mcpToolsByServer: [String: [McpServerManager.AssembledTool]] = [:]
    @State private var cachedEditorModelChoices: [String] = []

    static let colors = ["purple", "teal", "coral", "pink", "blue", "green", "amber"]
    private static let customTag = "__custom__"

    private var resolvedModel: String {
        modelChoice == Self.customTag
            ? customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            : modelChoice
    }

    /// V1.1a:钉住模型的候选 = 所选供给线的目录(拿不到时回退全局 modelChoices)
    private var editorModelChoices: [String] { cachedEditorModelChoices.isEmpty ? store.modelChoices : cachedEditorModelChoices }

    private var selectedRuntimeProfile: RuntimeProfileRecord? {
        profileChoice.isEmpty
            ? store.currentRuntimeProfile
            : store.runtimeProfiles.first { $0.id == profileChoice }
    }

    private var allowsCustomModel: Bool {
        selectedRuntimeProfile?.kind.allowsManualModelEntry ?? true
    }

    private var canSave: Bool {
        !name.isEmpty && !rolePrompt.isEmpty && (modelPolicy == .inherit || !resolvedModel.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 头部：实时预览
                HStack(spacing: 16) {
                    CompanionAvatarView(
                        name: name.isEmpty ? "伙" : name,
                        colorName: color,
                        size: 64
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(companionId == nil ? "创建自定义牛" : "牛的档案")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Camp.ink)
                        Text(companionId == nil ? "起个名字、挑个颜色、写清职责，就能加入牛棚。" : "改动会用于之后的放牛任务与私聊。")
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("名字")
                    TextField("比如：阿规", text: $name)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(11)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )

                    CampSectionTitle("颜色")
                    HStack(spacing: 12) {
                        ForEach(Self.colors, id: \.self) { colorName in
                            colorSwatch(colorName)
                        }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("模型")
                    Picker("供给线", selection: $profileChoice) {
                        Text("跟随默认供给线").tag("")
                        ForEach(store.runtimeProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    Picker("模型策略", selection: $modelPolicy) {
                        Text("跟随供给线默认").tag(CompanionModelPolicy.inherit)
                        Text("钉住指定模型").tag(CompanionModelPolicy.pinned)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    if modelPolicy == .pinned {
                    Picker("模型", selection: $modelChoice) {
                        ForEach(editorModelChoices, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        if allowsCustomModel {
                            Text("自定义…").tag(Self.customTag)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    if modelChoice == Self.customTag {
                        TextField("模型 id（网关提供的名字，如 glm-5.1）", text: $customModel)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .padding(11)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                    .stroke(Camp.line, lineWidth: 1)
                            )
                    }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("工具")
                    Text("勾选这只牛执行工作卡时可用的工具；汇报进展、提问与交接始终可用。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(ToolAccess.builtinCapabilityNames, id: \.self) { tool in
                        // M6-D8：无 Tavily key 时 web_search 置灰，避免「可勾但运行时静默消失」
                        let searchLocked = tool == "web_search" && !store.searchKeyPresent
                        HStack(spacing: 6) {
                            Toggle(isOn: toolBinding(tool)) {
                                Text(ToolDef.displayName(tool))
                                    .font(.body)
                                    .foregroundStyle(searchLocked ? Camp.inkSecondary : Camp.ink)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(searchLocked)
                            if searchLocked {
                                Text("（先到设置页配置 Tavily key）")
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                        }
                    }
                    // M8-D7：驿站工具按 server 分组，显式勾选（默认全不勾，不随内置继承）
                    if !store.mcp.servers.isEmpty {
                        Divider()
                        Text("驿站工具（MCP）——外部来源，必须逐个显式勾选。")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                        ForEach(store.mcp.servers, id: \.id) { server in
                            mcpServerGroup(server)
                        }
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("职责")
                    Text("它决定这只牛擅长什么、以什么口吻做事（system prompt）。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    TextEditor(text: $rolePrompt)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                }
                .campCard()

                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Camp.charcoalRed)
                }

                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        Label(companionId == nil ? "入册" : "保存", systemImage: "checkmark")
                        Spacer()
                    }
                }
                .buttonStyle(CampPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .task(id: companionId) {
            reloadEditorModelChoices()
            load()
            await refreshMcpTools()
        }
        .onChange(of: profileChoice) {
            reloadEditorModelChoices()
            normalizeModelChoiceForSelectedProfile()
        }
    }

    private func colorSwatch(_ colorName: String) -> some View {
        let swatch = CompanionAvatarView.palette[colorName] ?? .gray
        return Button {
            color = colorName
        } label: {
            ZStack {
                Circle()
                    .fill(swatch.opacity(0.85))
                    .frame(width: 30, height: 30)
                if color == colorName {
                    Circle()
                        .stroke(Camp.ink, lineWidth: 2)
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func toolBinding(_ tool: String) -> Binding<Bool> {
        Binding(
            get: { enabledTools.contains(tool) },
            set: { on in
                if on { enabledTools.insert(tool) } else { enabledTools.remove(tool) }
            }
        )
    }

    // MARK: - 驿站工具分组（M8-D7）

    @ViewBuilder
    private func mcpServerGroup(_ server: McpServerRecord) -> some View {
        let status = store.mcp.status(server.id)
        let known = mcpToolsByServer[server.id] ?? []
        let knownNames = Set(known.map(\.def.name))
        // 已勾选但当前列不出来的名字（驿站没在跑/工具被下架）：保留可取消，不静默丢失
        let orphanNames = enabledTools
            .filter { McpToolNaming.parse($0)?.server == McpToolNaming.serverComponent(server.name) }
            .subtracting(knownNames)
            .sorted()
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(Camp.stone)
                Text(server.name)
                    .font(.callout.weight(.medium).monospaced())
                    .foregroundStyle(Camp.ink)
                if server.experimental {
                    Image(systemName: "flask")
                        .font(.caption2)
                        .foregroundStyle(Camp.amber)
                }
                Spacer()
                if !status.isRunning {
                    Button {
                        store.mcp.connectForToolListing(server)
                    } label: {
                        if store.mcp.busyServerIds.contains(server.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("连接列出工具")
                        }
                    }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .disabled(store.mcp.busyServerIds.contains(server.id))
                }
            }
            if known.isEmpty && orphanNames.isEmpty {
                Text(status.isRunning ? "这个驿站没有可用工具" : "连接后这里会列出它的工具")
                    .font(.caption)
                    .foregroundStyle(Camp.stone)
            }
            ForEach(known, id: \.def.name) { tool in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Toggle(isOn: toolBinding(tool.def.name)) {
                        Text(tool.originalToolName)
                            .font(.body.monospaced())
                            .foregroundStyle(Camp.ink)
                    }
                    .toggleStyle(.checkbox)
                    if !tool.def.description.isEmpty {
                        Text(tool.def.description)
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                            .lineLimit(1)
                    }
                }
            }
            ForEach(orphanNames, id: \.self) { name in
                HStack(spacing: 6) {
                    Toggle(isOn: toolBinding(name)) {
                        Text(McpToolNaming.parse(name)?.tool ?? name)
                            .font(.body.monospaced())
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    .toggleStyle(.checkbox)
                    Text("（当前列不出——驿站未连接或工具已下架）")
                        .font(.caption)
                        .foregroundStyle(Camp.stone)
                }
            }
        }
        .padding(8)
        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .onChange(of: status.isRunning) {
            Task { await refreshMcpTools() }
        }
    }

    private func refreshMcpTools() async {
        await store.mcp.refreshStatuses()
        var result: [String: [McpServerManager.AssembledTool]] = [:]
        for server in store.mcp.servers {
            result[server.id] = await store.mcp.assembledTools(serverId: server.id)
        }
        mcpToolsByServer = result
    }

    private func load() {
        saveError = nil
        guard let companionId else {
            name = ""
            color = "purple"
            rolePrompt = ""
            modelChoice = store.modelChoices.first ?? AppStore.factoryModelChoices[0]
            customModel = ""
            enabledTools = Set(ToolAccess.builtinCapabilityNames)
            return
        }
        guard let companion = try? store.db.companion(id: companionId) else {
            return
        }
        name = companion.name
        color = companion.color
        rolePrompt = companion.rolePrompt
        enabledTools = ToolAccess.parse(toolsJson: companion.toolsJson).capabilities
        profileChoice = companion.runtimeProfileId ?? ""
        modelPolicy = companion.modelPolicy
        if editorModelChoices.contains(companion.model) {
            modelChoice = companion.model
            customModel = ""
        } else if allowsCustomModel {
            modelChoice = Self.customTag
            customModel = companion.model
        } else {
            modelChoice = editorModelChoices.first ?? ""
            customModel = ""
        }
    }

    private func reloadEditorModelChoices() {
        guard let profile = selectedRuntimeProfile else {
            cachedEditorModelChoices = store.modelChoices
            return
        }
        cachedEditorModelChoices = store.catalogChoices(profile: profile)
    }

    private func normalizeModelChoiceForSelectedProfile() {
        let choices = editorModelChoices
        if modelChoice == Self.customTag, allowsCustomModel { return }
        if !choices.contains(modelChoice) {
            modelChoice = choices.first ?? (allowsCustomModel ? Self.customTag : "")
            if !allowsCustomModel { customModel = "" }
        }
    }

    private func save() {
        do {
            // M6-D5b：保存永远写显式 v2 列表——打开编辑器保存即视为显式授权
            let toolsJson = ToolAccess.explicitJson(allow: enabledTools)
            if let companionId {
                guard var companion = try store.db.companion(id: companionId) else {
                    saveError = "保存失败：这只牛不存在"
                    return
                }
                companion.name = name
                companion.color = color
                companion.rolePrompt = rolePrompt
                if modelPolicy == .pinned { companion.model = resolvedModel }
                companion.runtimeProfileId = profileChoice.isEmpty ? nil : profileChoice
                companion.modelPolicy = modelPolicy
                companion.toolsJson = toolsJson
                try store.db.saveCompanion(companion)
            } else {
                var companion = CompanionRecord.new(
                    name: name,
                    color: color,
                    rolePrompt: rolePrompt,
                    model: modelPolicy == .pinned ? resolvedModel : (editorModelChoices.first ?? resolvedModel)
                )
                companion.runtimeProfileId = profileChoice.isEmpty ? nil : profileChoice
                companion.modelPolicy = modelPolicy
                companion.toolsJson = toolsJson
                try store.db.saveCompanion(companion)
            }
            saveError = nil
            store.reload()
            onDone()
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }
}
