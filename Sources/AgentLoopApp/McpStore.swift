import SwiftUI
import AgentLoopCore

/// MCP 驿站视图状态（M8-D7/D8）：server CRUD、状态、营地启用、凭据。
/// AppStore 绞杀第二刀——新领域状态独立成 store，不再涌入 AppStore。
@MainActor @Observable
final class McpStore {
    struct Template: Identifiable {
        let id: String
        let displayName: String
        let command: String
        let args: [String]
        let secretEnvKeys: [String]
        /// filesystem 需要用户选一个根目录作最后一个参数
        let needsFolderPick: Bool
        let blurb: String
    }

    /// 精选清单（M8-D6）：开箱三件覆盖文件/代码/浏览器
    static let templates: [Template] = [
        Template(id: "filesystem", displayName: "filesystem", command: "npx",
                 args: ["-y", "@modelcontextprotocol/server-filesystem"],
                 secretEnvKeys: [], needsFolderPick: true,
                 blurb: "读写你指定的一个文件夹"),
        Template(id: "github", displayName: "github", command: "npx",
                 args: ["-y", "@modelcontextprotocol/server-github"],
                 secretEnvKeys: ["GITHUB_PERSONAL_ACCESS_TOKEN"], needsFolderPick: false,
                 blurb: "查 issue / PR / 仓库（需要 PAT）"),
        Template(id: "playwright", displayName: "playwright", command: "npx",
                 args: ["-y", "@playwright/mcp@latest"],
                 secretEnvKeys: [], needsFolderPick: false,
                 blurb: "驱动浏览器：打开网页、点按、截图"),
    ]

    private let db: AppDatabase
    let manager: McpServerManager
    private let keychain: KeychainStore
    var onToast: @MainActor (String) -> Void = { _ in }

    var servers: [McpServerRecord] = []
    var statuses: [String: McpServerManager.ServerStatus] = [:]
    /// 正在重启/连接中的 server（按钮置灰防重）
    var busyServerIds: Set<String> = []
    /// npx 可用性（添加驿站时检查；nil = 未检查过）
    var npxAvailable: Bool?

    init(db: AppDatabase, manager: McpServerManager, keychain: KeychainStore) {
        self.db = db
        self.manager = manager
        self.keychain = keychain
        reload()
    }

    func reload() {
        servers = (try? db.mcpServers()) ?? []
    }

    func refreshStatuses() async {
        statuses = await manager.statuses()
    }

    func status(_ serverId: String) -> McpServerManager.ServerStatus {
        statuses[serverId] ?? .stopped
    }

    // MARK: - 添加 / 删除

    /// 模板一键添加；filesystem 弹目录选择。重名时报错（name 是工具名组成部分，唯一约束）。
    func addFromTemplate(_ template: Template) {
        guard !servers.contains(where: { $0.name == template.displayName }) else {
            onToast("驿站「\(template.displayName)」已在列表里")
            return
        }
        var args = template.args
        if template.needsFolderPick {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "选择 filesystem 驿站可以读写的根目录"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            args.append(url.path)
        }
        let record = McpServerRecord.new(
            name: template.displayName, command: template.command, args: args,
            secretEnvKeys: template.secretEnvKeys, experimental: false)
        add(record)
    }

    /// 自定义驿站（experimental，M8-D6）：args 按空白切分（不支持引号转义——标注在 UI）。
    func addCustom(name: String, command: String, argsLine: String, envLines: String, secretKeysLine: String) -> Bool {
        let cleanName = McpToolNaming.serverComponent(name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !cleanName.isEmpty else {
            onToast("名字清洗后为空——请用字母/数字/短横线")
            return false
        }
        guard !servers.contains(where: { $0.name == cleanName }) else {
            onToast("驿站「\(cleanName)」已存在")
            return false
        }
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCommand.isEmpty else {
            onToast("需要启动命令")
            return false
        }
        let args = argsLine.split(whereSeparator: \.isWhitespace).map(String.init)
        var env: [String: String] = [:]
        for line in envLines.split(whereSeparator: \.isNewline) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...])
            if !key.isEmpty { env[key] = value }
        }
        let secretKeys = secretKeysLine.split(whereSeparator: \.isWhitespace).map(String.init)
        let record = McpServerRecord.new(
            name: cleanName, command: cleanCommand, args: args, env: env,
            secretEnvKeys: secretKeys, experimental: true)
        add(record)
        return true
    }

    private func add(_ record: McpServerRecord) {
        do {
            try db.addMcpServer(record)
            reload()
            checkNpxIfNeeded(command: record.command)
        } catch {
            onToast("添加失败：\(error.localizedDescription)")
        }
    }

    /// 删除驿站：停进程、清 Keychain 凭据、删记录与启用关联。
    func delete(_ server: McpServerRecord) {
        busyServerIds.insert(server.id)
        Task { [weak self] in
            guard let self else { return }
            await manager.stop(serverId: server.id)
            for key in server.secretEnvKeys {
                try? keychain.delete(account: Self.secretAccount(serverId: server.id, key: key))
            }
            try? db.deleteMcpServer(id: server.id)
            busyServerIds.remove(server.id)
            reload()
            await refreshStatuses()
        }
    }

    /// 手动重启（down 复活的唯一途径，M8-D3）
    func restart(_ server: McpServerRecord) {
        guard !busyServerIds.contains(server.id) else { return }
        busyServerIds.insert(server.id)
        Task { [weak self] in
            guard let self else { return }
            await manager.restart(serverId: server.id)
            busyServerIds.remove(server.id)
            await refreshStatuses()
            if case .down(let detail) = await manager.status(serverId: server.id) {
                onToast("驿站「\(server.name)」启动失败：\(detail.prefix(80))")
            }
        }
    }

    /// 连接以列出工具（伙伴编辑器用；对 stopped 的 server 做一次启动）
    func connectForToolListing(_ server: McpServerRecord) {
        guard !busyServerIds.contains(server.id) else { return }
        busyServerIds.insert(server.id)
        Task { [weak self] in
            guard let self else { return }
            await manager.ensureRunning(serverIds: [server.id])
            busyServerIds.remove(server.id)
            await refreshStatuses()
        }
    }

    func assembledTools(serverId: String) async -> [McpServerManager.AssembledTool] {
        await manager.assembledTools(serverId: serverId)
    }

    // MARK: - 营地启用

    func enabledServerIds(campId: String) -> Set<String> {
        (try? db.enabledMcpServerIds(campId: campId)) ?? []
    }

    func setEnabled(campId: String, serverId: String, enabled: Bool) {
        do {
            try db.setMcpServerEnabled(campId: campId, serverId: serverId, enabled: enabled)
        } catch {
            onToast("操作失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 凭据（M8-D5：值只进 Keychain）

    static func secretAccount(serverId: String, key: String) -> String {
        "mcp-\(serverId)-\(key)"
    }

    func secretPresent(serverId: String, key: String) -> Bool {
        guard !AppStore.isUIPreview else { return false }
        return (((try? keychain.get(account: Self.secretAccount(serverId: serverId, key: key))) ?? nil)
            .map { !$0.isEmpty }) ?? false
    }

    func saveSecret(serverId: String, key: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try keychain.delete(account: Self.secretAccount(serverId: serverId, key: key))
                onToast("已移除 \(key)")
            } else {
                try keychain.set(trimmed, account: Self.secretAccount(serverId: serverId, key: key))
                onToast("已存入钥匙串（下次启动驿站时生效）")
            }
        } catch {
            onToast("钥匙串写入失败：\(error.localizedDescription)")
        }
    }

    // MARK: - node 依赖检查（M8-D6：缺失给指引，不代装）

    private func checkNpxIfNeeded(command: String) {
        guard command == "npx" || command == "npm" || command == "node", npxAvailable == nil else { return }
        Task { [weak self] in
            let env = await LoginShellEnvironment.shared.environment()
            let path = env["PATH"] ?? ""
            let found = path.split(separator: ":").contains { dir in
                FileManager.default.isExecutableFile(atPath: "\(dir)/npx")
            }
            await MainActor.run {
                guard let self else { return }
                self.npxAvailable = found
                if !found {
                    self.onToast("本机没找到 npx——请先安装 Node.js（https://nodejs.org），否则这个驿站启动不了")
                }
            }
        }
    }
}
