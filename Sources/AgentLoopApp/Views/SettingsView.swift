import SwiftUI
import AgentLoopCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""
    @State private var searchKey = ""
    @State private var budgetText = ""
    @State private var budgetSavedFlash = false
    @State private var newModelId = ""

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("设置")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Camp.ink)
                    Text("基础连接保持清晰，模型、工具和预算属于高级能力。凭据只存在本机。")
                        .font(.callout)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    RanchSectionHeader(icon: "link", title: "API 端点", tint: Camp.creek)
                    Picker("接口格式", selection: $store.apiFormat) {
                        ForEach(ProviderAPIFormat.allCases, id: \.rawValue) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    Label("鉴权 header 按接口格式自动处理", systemImage: "wand.and.stars")
                        .foregroundStyle(Camp.inkSecondary)
                        .font(.caption)
                    TextField(AppStore.defaultBaseURL, text: $store.apiBaseURL)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .padding(11)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(store.apiBaseURLValid ? Camp.line : Camp.charcoalRed.opacity(0.6), lineWidth: 1)
                        )
                    if !store.apiBaseURLValid {
                        Label("URL 无效：需要 http(s):// 开头的完整地址", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Camp.charcoalRed)
                            .font(.caption)
                    } else if store.apiBaseURL != AppStore.defaultBaseURL || store.apiFormat != .anthropicMessages {
                        Label("自定义接入：端点会按所选接口格式自动补齐请求路径", systemImage: "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(Camp.inkSecondary)
                            .font(.caption)
                        Button("恢复官方端点") {
                            store.apiBaseURL = AppStore.defaultBaseURL
                            store.apiFormat = .anthropicMessages
                            store.apiAuthScheme = .automatic
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
                    }
                    if store.apiFormat == .openAIChatCompletions,
                       store.preferredCredentialSource == .webLogin {
                        Label("网页登录固定使用 ChatGPT 官方后端，自定义端点仅对 API key 生效", systemImage: "lock.fill")
                            .foregroundStyle(Camp.inkSecondary)
                            .font(.caption)
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        RanchSectionHeader(icon: "person.crop.circle.badge.checkmark", title: "认证", tint: Camp.moss)
                        Spacer()
                        if store.webCredentialPresent {
                            CampChip(text: "网页登录已授权", color: Camp.moss, icon: "checkmark.seal.fill")
                        }
                        if store.apiKeyPresent {
                            CampChip(text: "API Key 已保存", color: Camp.moss, icon: "key.fill")
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            store.openProviderAuth()
                        } label: {
                            Label(store.apiFormat == .openAIChatCompletions ? "OpenAI Auth 登录" : "网页登录授权", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(!store.apiBaseURLValid || AppStore.isUIPreview)
                        Text(
                            AppStore.isUIPreview
                                ? "预览模式不读取登录凭据；请用真实模式测试认证"
                                : (store.webCredentialPresent ? "优先使用网页登录凭据" : store.authHintText)
                        )
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    if let status = store.oauthLoginStatus {
                        Label(status, systemImage: store.webCredentialPresent ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(store.webCredentialPresent ? Camp.moss : Camp.inkSecondary)
                            .font(.caption)
                    }
                    if store.credentialAccessInProgress {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在读取系统钥匙串；如需授权，App 仍可继续使用")
                        }
                        .foregroundStyle(Camp.inkSecondary)
                        .font(.caption)
                    }
                    if let error = store.credentialAccessError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Camp.charcoalRed)
                            .font(.caption)
                    }
                    if store.oauthNeedsRelogin {
                        Label("登录已过期", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Camp.ember)
                            .font(.caption)
                    }
                    Divider()
                    CampSectionTitle("API Key")
                    SecureField("sk-ant-… 或网关分发的 key", text: $key)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .padding(11)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                    HStack {
                        Button {
                            store.saveAPIKey(key)
                            key = ""
                        } label: {
                            Label("保存到钥匙串", systemImage: "key.fill")
                        }
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(key.isEmpty)
                        Text("Key 只进系统钥匙串，不进配置文件。")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    Divider()
                    HStack(spacing: 10) {
                        Button {
                            store.testModelConnection()
                        } label: {
                            Label("测试连接", systemImage: "bolt.horizontal")
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
                        if let status = store.modelConnectionTestStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(
                                    status.hasPrefix("连接正常") ? Camp.moss
                                        : status.hasPrefix("正在") ? Camp.inkSecondary : Camp.charcoalRed
                                )
                        }
                    }
                }
                .campCard()

                // V1.1a:供给线管理
                RuntimeProfileSection()
                    .campCard()

                // M6-D11/D12：模型目录 + 默认/蒸馏/规划三档
                VStack(alignment: .leading, spacing: 12) {
                    RanchSectionHeader(icon: "cpu", title: "模型", tint: Camp.creek)
                    Text("目录里的模型会出现在牛的档案与下面三档选择里。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(store.modelChoices, id: \.self) { model in
                        HStack {
                            Text(model)
                                .font(.body.monospaced())
                                .foregroundStyle(Camp.ink)
                            Spacer()
                            if store.canRemoveModelFromCurrentCatalog(model) {
                                Button {
                                    removeModel(model)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Camp.inkSecondary)
                                }
                                .buttonStyle(.plain)
                                .help("从目录移除")
                            }
                        }
                    }
                    if store.currentModelCatalogAllowsManualInput {
                        HStack {
                            TextField("模型 id（如 glm-5.1）", text: $newModelId)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .font(.body.monospaced())
                                .padding(8)
                                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                        .stroke(Camp.line, lineWidth: 1)
                                )
                            Button {
                                addModel()
                            } label: {
                                Label("加入目录", systemImage: "plus")
                            }
                            .buttonStyle(CampSecondaryButtonStyle())
                            .disabled(newModelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("恢复目录") { store.resetCurrentModelCatalog() }
                                .buttonStyle(CampSecondaryButtonStyle())
                        }
                    } else {
                        Label("当前供给线使用受控模型目录，不能手动添加模型。", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    Divider()
                    modelPicker("默认模型", selection: $store.defaultModel, allowFollow: false)
                    modelPicker("蒸馏用模型", selection: $store.distillModel, allowFollow: true)
                    modelPicker("规划用模型", selection: $store.plannerModel, allowFollow: true)
                    Text("蒸馏与规划可以用轻量模型省成本；「跟随默认」= 不单独指定。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .campCard()

                // M7-D2：新行动的默认自主档位
                VStack(alignment: .leading, spacing: 12) {
                    RanchSectionHeader(icon: "shield.lefthalf.filled", title: "默认自主档位", tint: Camp.ember)
                    Picker("默认自主档位", selection: $store.defaultAutonomy) {
                        ForEach(MissionAutonomy.allCases, id: \.self) { autonomy in
                            Text(autonomy.displayName).tag(autonomy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 320)
                    Text("谨慎=写入即审批；标准=危险操作（跑命令）才审批；放手=预算内全放行。每个行动出发时可单独调整，进行中也能改。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .campCard()

                // M6-D7/D8：Tavily 搜索 key（Keychain 第二槽）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        RanchSectionHeader(icon: "globe", title: "联网搜索（Tavily）", tint: Camp.creek)
                        Spacer()
                        if store.searchKeyPresent {
                            CampChip(text: "已配置", color: Camp.moss, icon: "checkmark.seal.fill")
                        }
                    }
                    Text(store.searchKeyPresent
                        ? "牛可以用 web_search 联网搜索（可在牛的档案里逐只勾选）。"
                        : "配置 Tavily API key 后，牛才能联网搜索；不配置则该工具不出现。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    SecureField("tvly-…", text: $searchKey)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .padding(11)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                .stroke(Camp.line, lineWidth: 1)
                        )
                    HStack {
                        Button {
                            store.saveSearchKey(searchKey)
                            searchKey = ""
                        } label: {
                            Label("保存到钥匙串", systemImage: "key.fill")
                        }
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(searchKey.isEmpty)
                        if store.searchKeyPresent {
                            Button {
                                store.saveSearchKey("")
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                            .buttonStyle(CampSecondaryButtonStyle())
                        }
                    }
                }
                .campCard()

                // M8-D6/D7：MCP 驿站（全局注册；营地首页启用；伙伴编辑器按人授权）
                McpStationSection()

                // M10-D4:菜单栏常驻(默认关;开启后关窗保活,日程照常触发)
                VStack(alignment: .leading, spacing: 10) {
                    RanchSectionHeader(icon: "menubar.rectangle", title: "菜单栏常驻", tint: Camp.stone)
                    Toggle(isOn: Binding(
                        get: { (NSApp.delegate as? AppDelegate)?.menuBarResidencyEnabled ?? false },
                        set: { (NSApp.delegate as? AppDelegate)?.setMenuBarResidencyEnabled($0) }
                    )) {
                        Text("篝火常驻菜单栏,关窗后牧场继续守着日程")
                            .font(.callout)
                            .foregroundStyle(Camp.ink)
                    }
                    .toggleStyle(.switch)
                    Text("关闭时,关掉最后一个窗口即退出;定时行动只在 App 运行期间生效。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    RanchSectionHeader(icon: "gauge.with.dots.needle.50percent", title: "默认预算", tint: Camp.ember)
                    HStack(spacing: 10) {
                        TextField("\(KernelDefaults.missionBudget)", text: $budgetText)
                            .textFieldStyle(.plain)
                            .font(.body.monospaced())
                            .frame(width: 140)
                            .padding(11)
                            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                                    .stroke(Camp.line, lineWidth: 1)
                            )
                            .onSubmit(saveBudget)
                        Text("tokens / 放牛任务")
                            .font(.callout)
                            .foregroundStyle(Camp.inkSecondary)
                        Button {
                            saveBudget()
                        } label: {
                            if budgetSavedFlash {
                                Label("已保存", systemImage: "checkmark")
                            } else {
                                Text("保存")
                            }
                        }
                        .buttonStyle(CampSecondaryButtonStyle(tint: budgetSavedFlash ? Camp.moss : Camp.ember))
                        .disabled(Int(budgetText) == nil || Int(budgetText)! <= 0)
                    }
                    if !budgetText.isEmpty && (Int(budgetText) == nil || Int(budgetText)! <= 0) {
                        Label("需要正整数（tokens 数）", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Camp.charcoalRed)
                            .font(.caption)
                    }
                    Text("新放牛任务与营地管家提案的缺省预算；耗尽时任务暂停派发，可续预算 / 就地收成果 / 放弃。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .campCard()
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .onAppear {
            budgetText = String(store.defaultMissionBudget)
        }
    }

    private func saveBudget() {
        guard let value = Int(budgetText), value > 0 else { return }
        store.defaultMissionBudget = value
        budgetSavedFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            budgetSavedFlash = false
        }
    }

    // MARK: 模型目录（M6-D11/D12）

    @ViewBuilder
    private func modelPicker(_ title: String, selection: Binding<String>, allowFollow: Bool) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(Camp.ink)
                .frame(width: 96, alignment: .leading)
            Picker(title, selection: selection) {
                if allowFollow {
                    Text("跟随默认").tag("")
                }
                ForEach(store.modelChoices, id: \.self) { model in
                    Text(model).tag(model)
                }
                // 当前值不在目录里（目录被改过）也要可见可选，避免 Picker 空选
                if !selection.wrappedValue.isEmpty && !store.modelChoices.contains(selection.wrappedValue) {
                    Text("\(selection.wrappedValue)（不在目录）").tag(selection.wrappedValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private func addModel() {
        let id = newModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        store.addModelToCurrentCatalog(id)
        newModelId = ""
    }

    private func removeModel(_ model: String) {
        store.removeModelFromCurrentCatalog(model)
    }
}

private extension AppStore {
    var authHintText: String {
        apiFormat == .openAIChatCompletions
            ? "会打开 OpenAI 登录页"
            : "会打开当前端点对应的登录页"
    }
}

private extension ProviderAPIFormat {
    var displayName: String {
        switch self {
        case .anthropicMessages:
            return "Anthropic"
        case .openAIChatCompletions:
            return "OpenAI"
        }
    }
}
