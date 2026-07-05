import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""

    var body: some View {
        @Bindable var store = store
        Form {
            Section("API 端点") {
                TextField(AppStore.defaultBaseURL, text: $store.apiBaseURL)
                    .autocorrectionDisabled()
                if !store.apiBaseURLValid {
                    Label("URL 无效：需要 http(s):// 开头的完整地址", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                } else if store.apiBaseURL != AppStore.defaultBaseURL {
                    Label("自定义端点：任何 Anthropic Messages API 兼容服务（官方 / 中转网关 / 本地代理）", systemImage: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Button("恢复官方端点") {
                        store.apiBaseURL = AppStore.defaultBaseURL
                    }
                }
            }
            Section("API Key") {
                SecureField("sk-ant-… 或网关分发的 key", text: $key)
                HStack {
                    Button("保存到钥匙串") {
                        store.saveAPIKey(key)
                        key = ""
                    }
                    .disabled(key.isEmpty)
                    if store.apiKeyPresent {
                        Label("已配置", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}
