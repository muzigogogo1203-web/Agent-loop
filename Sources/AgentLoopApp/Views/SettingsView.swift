import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""

    var body: some View {
        Form {
            Section("Anthropic API Key") {
                SecureField("sk-ant-...", text: $key)
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
