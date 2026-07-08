import SwiftUI
import AgentLoopCore

/// 设置页「MCP 驿站」区（M8-D6/D7）：精选模板一键添加、自定义（experimental）、
/// 状态/重启/删除、凭据 SecureField（值只进钥匙串）。
struct McpStationSection: View {
    @Environment(AppStore.self) private var store

    @State private var customExpanded = false
    @State private var customName = ""
    @State private var customCommand = ""
    @State private var customArgs = ""
    @State private var customEnv = ""
    @State private var customSecretKeys = ""
    @State private var secretDrafts: [String: String] = [:]
    @State private var deleteCandidate: McpServerRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CampSectionTitle("MCP 驿站")
            Text("驿站是外部工具的补给点（MCP server）。全局注册，按营地启用（营地首页勾选），再在伙伴编辑器里按人授权后伙伴才能用。")
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)

            if store.mcp.npxAvailable == false {
                Label("本机没找到 npx——精选驿站都靠 Node 拉起，请先安装 Node.js（nodejs.org）", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
            }

            // 已注册的驿站
            ForEach(store.mcp.servers, id: \.id) { server in
                serverRow(server)
            }

            // 精选模板（未添加的才显示）
            let remaining = McpStore.templates.filter { template in
                !store.mcp.servers.contains { $0.name == template.displayName }
            }
            if !remaining.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("精选驿站")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Camp.inkSecondary)
                    ForEach(remaining) { template in
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox")
                                .font(.callout)
                                .foregroundStyle(Camp.stone)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(template.displayName)
                                    .font(.callout.weight(.medium).monospaced())
                                    .foregroundStyle(Camp.ink)
                                Text(template.blurb)
                                    .font(.caption)
                                    .foregroundStyle(Camp.inkSecondary)
                            }
                            Spacer()
                            Button("添加") {
                                store.mcp.addFromTemplate(template)
                            }
                            .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
                        }
                        .padding(8)
                        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                    }
                }
            }

            // 自定义（experimental）
            DisclosureGroup(isExpanded: $customExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("实验功能：任何 stdio MCP server 都能接，但命令来自你手输——只接你信任的来源。", systemImage: "flask")
                        .font(.caption)
                        .foregroundStyle(Camp.amber)
                    customField("名字（将成为工具名前缀，字母/数字/短横线）", text: $customName)
                    customField("启动命令（如 npx / uvx / node）", text: $customCommand)
                    customField("参数（按空格切分，不支持引号）", text: $customArgs)
                    customField("环境变量（每行 KEY=VALUE，明文入库——密钥别放这里）", text: $customEnv)
                    customField("密钥 env 名（空格分隔，值稍后存钥匙串）", text: $customSecretKeys)
                    Button {
                        if store.mcp.addCustom(
                            name: customName, command: customCommand, argsLine: customArgs,
                            envLines: customEnv, secretKeysLine: customSecretKeys
                        ) {
                            customName = ""; customCommand = ""; customArgs = ""
                            customEnv = ""; customSecretKeys = ""
                            customExpanded = false
                        }
                    } label: {
                        Label("添加自定义驿站", systemImage: "plus")
                    }
                    .buttonStyle(CampSecondaryButtonStyle())
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty
                        || customCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 6) {
                    Text("自定义驿站")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Camp.ink)
                    CampChip(text: "experimental", color: Camp.amber, icon: "flask")
                }
            }
        }
        .campCard()
        .task {
            // 设置页可见期间轮询状态（2s 一拍；驿站死活变化即时反映）
            while !Task.isCancelled {
                await store.mcp.refreshStatuses()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .confirmationDialog(
            "删除驿站「\(deleteCandidate?.name ?? "")」？",
            isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })
        ) {
            Button("删除（停进程、清凭据、清各营地启用）", role: .destructive) {
                if let candidate = deleteCandidate {
                    store.mcp.delete(candidate)
                }
                deleteCandidate = nil
            }
            Button("取消", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("已勾选它工具的伙伴会失去这些工具（白名单里的名字保留，重新添加同名驿站即恢复）。")
        }
    }

    // MARK: - 驿站行

    @ViewBuilder
    private func serverRow(_ server: McpServerRecord) -> some View {
        let status = store.mcp.status(server.id)
        let busy = store.mcp.busyServerIds.contains(server.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusDot(status)
                Text(server.name)
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(Camp.ink)
                if server.experimental {
                    CampChip(text: "experimental", color: Camp.amber, icon: "flask")
                }
                statusChip(status)
                Spacer()
                Button {
                    store.mcp.restart(server)
                } label: {
                    if busy {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("重启", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(CampSecondaryButtonStyle())
                .disabled(busy)
                .help("拉起（或重启）这个驿站进程")
                Button {
                    deleteCandidate = server
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.charcoalRed))
                .disabled(busy)
            }
            Text("\(server.command) \(server.args.joined(separator: " "))")
                .font(.caption.monospaced())
                .foregroundStyle(Camp.inkSecondary)
                .lineLimit(2)
                .textSelection(.enabled)
            if case .down(let detail) = status {
                Label(detail, systemImage: "bolt.slash.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.charcoalRed)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            ForEach(server.secretEnvKeys, id: \.self) { key in
                secretRow(server: server, key: key)
            }
        }
        .padding(10)
        .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                .stroke(Camp.line, lineWidth: 1)
        )
    }

    private func secretRow(server: McpServerRecord, key: String) -> some View {
        let draftBinding = Binding(
            get: { secretDrafts["\(server.id)-\(key)"] ?? "" },
            set: { secretDrafts["\(server.id)-\(key)"] = $0 }
        )
        return HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.caption)
                .foregroundStyle(Camp.stone)
            Text(key)
                .font(.caption.monospaced())
                .foregroundStyle(Camp.inkSecondary)
            SecureField("值只进钥匙串", text: draftBinding)
                .textFieldStyle(.plain)
                .font(.caption.monospaced())
                .padding(6)
                .background(Camp.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Camp.line, lineWidth: 1)
                )
            if store.mcp.secretPresent(serverId: server.id, key: key) {
                CampChip(text: "已配置", color: Camp.moss, icon: "checkmark.seal.fill")
            }
            Button("存") {
                store.mcp.saveSecret(serverId: server.id, key: key, value: draftBinding.wrappedValue)
                secretDrafts["\(server.id)-\(key)"] = ""
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(draftBinding.wrappedValue.isEmpty)
        }
    }

    private func statusDot(_ status: McpServerManager.ServerStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    @ViewBuilder
    private func statusChip(_ status: McpServerManager.ServerStatus) -> some View {
        switch status {
        case .running(let toolCount):
            CampChip(text: "在营 · \(toolCount) 工具", color: Camp.moss)
        case .starting:
            CampChip(text: "启动中", color: Camp.amber)
        case .down:
            CampChip(text: "停摆", color: Camp.charcoalRed, icon: "bolt.slash.fill")
        case .stopped:
            CampChip(text: "未启动", color: Camp.stone)
        }
    }

    private func statusColor(_ status: McpServerManager.ServerStatus) -> Color {
        switch status {
        case .running: Camp.moss
        case .starting: Camp.amber
        case .down: Camp.charcoalRed
        case .stopped: Camp.stone
        }
    }

    private func customField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .font(.caption.monospaced())
            .padding(8)
            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                    .stroke(Camp.line, lineWidth: 1)
            )
    }
}
