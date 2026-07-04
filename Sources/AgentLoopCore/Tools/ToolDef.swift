public struct ToolDef: Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

extension ToolDef {
    static func objectSchema(_ properties: [String: JSONValue], required: [String]) -> JSONValue {
        [
            "type": "object",
            "properties": .object(properties),
            "required": .array(required.map(JSONValue.string)),
            "additionalProperties": false,
        ]
    }

    public static let completeCard = ToolDef(
        name: "complete_card",
        description: "完成当前小目标的唯一方式。校验通过后小目标进入 done。必须在工作真正完成并自查后调用。artifacts 里的 relativePath 必须是你已写入工作目录的真实文件；若确实无文件产物，给出 noArtifactReason。",
        inputSchema: objectSchema([
            "outcome": ["type": "string", "description": "结果一句话"],
            "summary": ["type": "string", "description": "人话摘要，给用户和下游伙伴看"],
            "artifacts": [
                "type": "array",
                "items": objectSchema([
                    "relativePath": ["type": "string"],
                    "kind": ["type": "string"],
                    "label": ["type": "string"],
                ], required: ["relativePath", "kind", "label"]),
            ],
            "noArtifactReason": ["type": "string"],
            "verification": [
                "type": "array",
                "items": objectSchema([
                    "method": ["type": "string"],
                    "passed": ["type": "boolean"],
                    "note": ["type": "string"],
                ], required: ["method", "passed", "note"]),
            ],
            "next": ["type": "string"],
            "risks": ["type": "array", "items": ["type": "string"]],
        ], required: ["outcome", "summary", "verification", "risks"])
    )

    public static let blockCard = ToolDef(
        name: "block_card",
        description: "当你确定无法继续（缺信息/权限/反复失败）时调用，说明原因。这会挂起小目标等待用户处理。",
        inputSchema: objectSchema([
            "reason": ["type": "string", "enum": ["needs_human_input", "tool_failure", "other"]],
            "detail": ["type": "string"],
        ], required: ["reason", "detail"])
    )

    public static let addProgressNote = ToolDef(
        name: "add_progress_note",
        description: "用一句话向用户汇报当前进展（会实时显示在界面上）。做完一个阶段就汇报一次。",
        inputSchema: objectSchema(["text": ["type": "string"]], required: ["text"])
    )

    public static let listDir = ToolDef(
        name: "list_dir",
        description: "列出工作目录内某个相对路径下的文件与子目录。path 为空字符串表示根目录。",
        inputSchema: objectSchema(["path": ["type": "string"]], required: ["path"])
    )

    public static let readFile = ToolDef(
        name: "read_file",
        description: "读取工作目录内的文本文件（相对路径）。",
        inputSchema: objectSchema(["path": ["type": "string"]], required: ["path"])
    )

    public static let writeFile = ToolDef(
        name: "write_file",
        description: "把文本写入工作目录内的相对路径（自动创建中间目录，覆盖已有文件）。",
        inputSchema: objectSchema([
            "path": ["type": "string"],
            "content": ["type": "string"],
        ], required: ["path", "content"])
    )

    public static let webFetch = ToolDef(
        name: "web_fetch",
        description: "抓取一个 https URL 的正文文本（只读，最多返回 ~50KB）。",
        inputSchema: objectSchema(["url": ["type": "string"]], required: ["url"])
    )

    public static let m1Tools: [ToolDef] = [
        completeCard,
        blockCard,
        addProgressNote,
        listDir,
        readFile,
        writeFile,
        webFetch,
    ]
}
