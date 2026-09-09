import Foundation

public struct BoardTools: Sendable {
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink

    package init(
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) {
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
    }

    package func complete(input: JSONValue) async throws -> ToolOutcome {
        let handoff: HandoffPayload
        switch HandoffPayload.parse(from: input) {
        case .failure(let message):
            return .error(message)
        case .success(let parsed):
            handoff = parsed
        }
        guard handoff.artifacts.allSatisfy({
            Self.isValidRelativeArtifactPath($0.relativePath)
        }) else {
            return .error("artifact.relativePath 必须是规范的工作区相对路径")
        }

        try await boardTerminalSink.submit(.completed(handoff: handoff))
        return .completed(handoff)
    }

    package func block(input: JSONValue) async throws -> ToolOutcome {
        guard let reason = input["reason"]?.stringValue,
              let detail = input["detail"]?.stringValue,
              !reason.isEmpty,
              !detail.isEmpty
        else {
            return .error("block_card.reason 和 detail 必须是非空字符串")
        }
        try await boardTerminalSink.submit(
            .blocked(reasonCode: reason, detail: detail)
        )
        return .blocked(reason: reason, detail: detail)
    }

    package func progressNote(
        input: JSONValue
    ) async throws -> ToolOutcome {
        guard let text = input["text"]?.stringValue, !text.isEmpty else {
            return .error("progress_note.text 必须是非空字符串")
        }
        try await progressSink.submit(.progress(message: text))
        return .result("已汇报")
    }

    package func askUser(input: JSONValue) async throws -> ToolOutcome {
        guard let object = input.objectValue else {
            return .error("ask_user 参数必须是对象")
        }
        let allowedKeys: Set<String> = ["kind", "prompt", "options"]
        let extraKeys = Set(object.keys).subtracting(allowedKeys)
        guard extraKeys.isEmpty else {
            return .error("ask_user 不支持参数：\(extraKeys.sorted().joined(separator: ", "))")
        }
        guard let kindRaw = object["kind"]?.stringValue,
              let kind = UserRequestRecord.Kind(rawValue: kindRaw),
              kind != .approval else {
            // approval 是内核审批门专用 kind（M7-D3），模型不可自造审批请求
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
        case .approval:
            // 前置 guard 已拒绝，仅为穷举完备
            return .error("ask_user.kind 必须是 choice / confirm / text")
        }

        try await boardTerminalSink.submit(
            .needsHumanInput(
                kind: kind,
                prompt: prompt,
                options: options ?? []
            )
        )
        return .blocked(reason: "needs_human_input", detail: prompt)
    }

    private static func isValidRelativeArtifactPath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasSuffix("/"),
              !path.contains("\\"),
              !path.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            return false
        }
        return path.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).allSatisfy { component in
            !component.isEmpty && component != "." && component != ".."
        }
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
        do {
            switch op {
            case .complete:
                return try await tools.complete(input: input)
            case .block:
                return try await tools.block(input: input)
            case .note:
                return try await tools.progressNote(input: input)
            case .askUser:
                return try await tools.askUser(input: input)
            }
        } catch {
            return .error("Board intent rejected.")
        }
    }
}
