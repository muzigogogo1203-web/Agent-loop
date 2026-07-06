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
                    } else if store.apiBaseURL != AppStore.defaultBaseURL {
                        Label("自定义端点：任何 Anthropic Messages API 兼容服务（官方 / 中转网关 / 本地代理）", systemImage: "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(Camp.inkSecondary)
                            .font(.caption)
                        Button("恢复官方端点") {
                            store.apiBaseURL = AppStore.defaultBaseURL
                        }
                        .buttonStyle(CampSecondaryButtonStyle())
                    }
                }
                .campCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CampSectionTitle("API Key")
                        Spacer()
                        if store.apiKeyPresent {
                            CampChip(text: "已配置", color: Camp.moss, icon: "checkmark.seal.fill")
                        }
                    }
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
