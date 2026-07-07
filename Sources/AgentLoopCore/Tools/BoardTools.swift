import Foundation

public struct BoardTools: Sendable {
    let db: AppDatabase
    let cardId: String
    let runId: String
    let workspaceRoot: URL?
    let artifactStoreRoot: URL

    public init(
        db: AppDatabase,
        cardId: String,
        runId: String,
        workspaceRoot: URL?,
        artifactStoreRoot: URL
    ) {
        self.db = db
        self.cardId = cardId
        self.runId = runId
        self.workspaceRoot = workspaceRoot
        self.artifactStoreRoot = artifactStoreRoot
    }

    public func complete(input: JSONValue) async -> ToolOutcome {
        let handoff: HandoffPayload
        switch HandoffPayload.parse(from: input) {
        case .failure(let message):
            return .error(message)
        case .success(let parsed):
            handoff = parsed
        }

        let fileTools = FileTools(workspaceRoot: workspaceRoot)
        var copies: [(decl: HandoffPayload.ArtifactDecl, source: URL, destination: URL)] = []
        for decl in handoff.artifacts {
            switch fileTools.resolve(decl.relativePath, forWrite: false) {
            case .failure(let message):
                return .error("产物 \(decl.relativePath)：\(message)")
            case .success(let source):
                guard FileManager.default.fileExists(atPath: source.path) else {
                    return .error("声明的产物 \(decl.relativePath) 在工作目录中不存在。请先用 write_file 写入，或修正 relativePath。")
                }
                let destination = artifactDestination(for: decl.relativePath)
                copies.append((decl: decl, source: source, destination: destination))
            }
        }

        var copied: [URL] = []
        do {
            for copy in copies {
                try FileManager.default.createDirectory(
                    at: copy.destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: copy.destination.path) {
                    try FileManager.default.removeItem(at: copy.destination)
                }
                try FileManager.default.copyItem(at: copy.source, to: copy.destination)
                copied.append(copy.destination)
            }
        } catch {
            for url in copied {
                try? FileManager.default.removeItem(at: url)
            }
            return .error("产物拷贝失败：\(error.localizedDescription)")
        }

        do {
            try db.completeCard(
                id: cardId,
                runId: runId,
                handoff: handoff,
                durableArtifacts: copies.map { (decl: $0.decl, durablePath: $0.destination.path) }
            )
            return .completed(handoff)
        } catch {
            for copy in copies {
                try? FileManager.default.removeItem(at: copy.destination)
            }
            return .error("完成落库失败：\(error)")
        }
    }

    public func block(input: JSONValue) async -> ToolOutcome {
        let reason = input["reason"]?.stringValue ?? "other"
        let detail = input["detail"]?.stringValue ?? ""
        do {
            try db.blockCard(id: cardId, runId: runId, reason: reason, detail: detail)
            return .blocked(reason: reason, detail: detail)
        } catch {
            return .error("挂起失败：\(error)")
        }
    }

    public func progressNote(input: JSONValue) async -> ToolOutcome {
        let text = input["text"]?.stringValue ?? ""
        do {
            try await db.pool.write { database in
                guard let card = try CardRecord.fetchOne(database, key: cardId) else {
                    throw RecordNotFoundError(table: "card", id: cardId)
                }
                try AppDatabase.appendEvent(
                    database,
                    missionId: card.missionId,
                    cardId: cardId,
                    runId: runId,
                    kind: EventKind.progressNote,
                    payload: ["text": .string(text)]
                )
            }
            return .result("已汇报")
        } catch {
            return .error("汇报失败：\(error)")
        }
    }

    public func askUser(input: JSONValue) async -> ToolOutcome {
        guard let object = input.objectValue else {
            return .error("ask_user 参数必须是对象")
        }
        let allowedKeys: Set<String> = ["kind", "prompt", "options"]
        let extraKeys = Set(object.keys).subtracting(allowedKeys)
        guard extraKeys.isEmpty else {
            return .error("ask_user 不支持参数：\(extraKeys.sorted().joined(separator: ", "))")
        }
        guard let kindRaw = object["kind"]?.stringValue,
              let kind = UserRequestRecord.Kind(rawValue: kindRaw) else {
            return .error("ask_user.kind 必须是 choice / confirm / text")
        }
        let prompt = object["prompt"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            return .error("ask_user.prompt 不能为空")
        }

        let options: [String]?
        switch kind {
        case .choice:
            guard let rawOptions = object["options"]?.arrayValue else {
                return .error("ask_user.choice 必须提供 options")
            }
            var parsed: [String] = []
            for option in rawOptions {
                guard let text = option.stringValue else {
                    return .error("ask_user.options 必须全部是字符串")
                }
                parsed.append(text)
            }
            guard (2...6).contains(parsed.count) else {
                return .error("ask_user.choice options 必须是 2 到 6 项")
            }
            options = parsed
        case .confirm, .text:
            guard object["options"] == nil else {
                return .error("ask_user.\(kind.rawValue) 不接受 options")
            }
            options = nil
        }

        do {
            _ = try db.suspendCardForUserRequest(
                cardId: cardId,
                runId: runId,
                kind: kind,
                prompt: prompt,
                options: options
            )
            return .blocked(reason: "needs_human_input", detail: prompt)
        } catch {
            return .error("提问落库失败：\(error)")
        }
    }

    private func artifactDestination(for relativePath: String) -> URL {
        artifactStoreRoot
            .appendingPathComponent(cardId)
            .appendingPathComponent(relativePath)
            .standardizedFileURL
    }
}

public struct BoardToolHandler: ToolHandler {
    public enum Op: Sendable {
        case complete
        case block
        case note
        case askUser
    }

    let tools: BoardTools
    let op: Op

    public init(tools: BoardTools, op: Op) {
        self.tools = tools
        self.op = op
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        switch op {
        case .complete:
            return await tools.complete(input: input)
        case .block:
            return await tools.block(input: input)
        case .note:
            return await tools.progressNote(input: input)
        case .askUser:
            return await tools.askUser(input: input)
        }
    }
}
