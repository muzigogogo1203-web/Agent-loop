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
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Camp.ink)
                    Text("接入方式与凭据，都存在本机。")
                        .font(.callout)
                        .foregroundStyle(Camp.inkSecondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("API 端点")
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
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("认证")
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
                        .disabled(!store.apiBaseURLValid)
                        .opacity(store.apiBaseURLValid ? 1 : 0.5)
                        Text(store.webCredentialPresent ? "优先使用网页登录凭据" : store.authHintText)
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                    if let status = store.oauthLoginStatus {
                        Label(status, systemImage: store.webCredentialPresent ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(store.webCredentialPresent ? Camp.moss : Camp.inkSecondary)
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
                        .opacity(key.isEmpty ? 0.5 : 1)
                        Text("Key 只进系统钥匙串，不进配置文件。")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
                .campCard()

                // M6-D11/D12：模型目录 + 默认/蒸馏/规划三档
                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("模型")
                    Text("目录里的模型会出现在伙伴编辑器与下面三档选择里。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(store.modelChoices, id: \.self) { model in
                        HStack {
                            Text(model)
                                .font(.body.monospaced())
                                .foregroundStyle(Camp.ink)
                            Spacer()
                            if store.modelChoices.count > 1 {
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
                        Button {
                            store.modelChoices = AppStore.factoryModelChoices
                            if !store.modelChoices.contains(store.defaultModel) {
                                store.defaultModel = store.modelChoices[0]
                            }
                        } label: {
                            Text("恢复出厂")
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
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
                    CampSectionTitle("默认自主档位")
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

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("长明火")
                        Spacer()
                        CampChip(
                            text: store.menuBarResident ? "菜单栏常驻" : "普通模式",
                            color: store.menuBarResident ? Camp.ember : Camp.stone,
                            icon: store.menuBarResident ? "flame.fill" : "macwindow"
                        )
                    }
                    Toggle(isOn: $store.menuBarResident) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("关窗后保留菜单栏篝火")
                                .foregroundStyle(Camp.ink)
                            Text("定时行动只在 App 运行期间触发；开启后可从菜单栏打开营地、查看下次日程和紧急收哨。")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("更新")
                        Spacer()
                        CampChip(
                            text: store.sparkleConfigured ? "已接入 Sparkle" : "未配置更新源",
                            color: store.sparkleConfigured ? Camp.moss : Camp.stone,
                            icon: store.sparkleConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle"
                        )
                    }
                    Toggle(isOn: $store.sparkleAutomaticallyChecksForUpdates) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("自动检查更新")
                                .foregroundStyle(Camp.ink)
                            Text(store.sparkleConfigured
                                ? "Sparkle 会按发布 feed 检查新版本。"
                                : "打包时传入 APPCAST_URL 和 SPARKLE_PUBLIC_KEY 后启用。")
                                .font(.caption)
                                .foregroundStyle(Camp.inkSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!store.sparkleConfigured)

                    HStack(spacing: 10) {
                        Button {
                            store.checkForUpdates()
                        } label: {
                            Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(CampPrimaryButtonStyle(size: .small))
                        .disabled(!store.sparkleConfigured || !store.sparkleCanCheckForUpdates)
                        .opacity(store.sparkleConfigured && store.sparkleCanCheckForUpdates ? 1 : 0.5)
                        Text("需要公开 appcast；私有仓库 release 资产不能作为更新源。")
                            .font(.caption)
                            .foregroundStyle(Camp.inkSecondary)
                    }
                }
                .campCard()

                // M6-D7/D8：Tavily 搜索 key（Keychain 第二槽）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("联网搜索（Tavily）")
                        Spacer()
                        if store.searchKeyPresent {
                            CampChip(text: "已配置", color: Camp.moss, icon: "checkmark.seal.fill")
                        }
                    }
                    Text(store.searchKeyPresent
                        ? "伙伴可以用 web_search 联网搜索（可在伙伴编辑器按人勾选）。"
                        : "配置 Tavily API key 后，伙伴才能联网搜索；不配置则该工具不出现。")
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
                        .opacity(searchKey.isEmpty ? 0.5 : 1)
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

                VStack(alignment: .leading, spacing: 12) {
                    CampSectionTitle("默认预算")
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
                        Text("tokens / 行动")
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
                    Text("新行动与向导组队提案的缺省预算；耗尽时行动暂停派发，可续预算 / 就地收成果 / 放弃。")
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
        guard !id.isEmpty, !store.modelChoices.contains(id) else {
            newModelId = ""
            return
        }
        store.modelChoices.append(id)
        newModelId = ""
    }

    private func removeModel(_ model: String) {
        guard store.modelChoices.count > 1 else { return }
        store.modelChoices.removeAll { $0 == model }
        // 默认模型被移除时落到目录首项；蒸馏/规划回「跟随默认」
        if store.defaultModel == model {
            store.defaultModel = store.modelChoices[0]
        }
        if store.distillModel == model { store.distillModel = "" }
        if store.plannerModel == model { store.plannerModel = "" }
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
