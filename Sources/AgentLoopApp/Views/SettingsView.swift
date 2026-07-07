import SwiftUI
import AgentLoopCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""
    @State private var budgetText = ""
    @State private var budgetSavedFlash = false

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
