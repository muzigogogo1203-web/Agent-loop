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
        description: "把文本写入工作目录内的相对路径（自动创建中间目录）。默认覆盖已有文件；append 为 true 时在文件末尾追加（文件不存在时等同新建）。写长文件时分多次调用，用 append 续写。",
        inputSchema: objectSchema([
            "path": ["type": "string"],
            "content": ["type": "string"],
            "append": ["type": "boolean", "description": "true 时追加到文件末尾；缺省 false 覆盖写"],
        ], required: ["path", "content"])
    )

    public static let webFetch = ToolDef(
        name: "web_fetch",
        description: "抓取一个 https URL 的正文文本（只读，最多返回 ~50KB）。",
        inputSchema: objectSchema(["url": ["type": "string"]], required: ["url"])
    )

    public static let askUser = ToolDef(
        name: "ask_user",
        description: "当继续当前小目标需要用户选择、确认或补充文本时调用。系统会持久保存问题并挂起小目标，用户回答后从冷启动继续。",
        inputSchema: objectSchema([
            "kind": ["type": "string", "enum": ["choice", "confirm", "text"]],
            "prompt": ["type": "string"],
            "options": ["type": "array", "items": ["type": "string"]],
        ], required: ["kind", "prompt"])
    )

    public static let searchCampNotes = ToolDef(
        name: "search_camp_notes",
        description: "按关键词检索营地笔记（往期行动的经验复盘、沉淀结论），返回最相关几条的标题与摘要。",
        inputSchema: objectSchema(["query": ["type": "string"]], required: ["query"])
    )

    public static let campStatus = ToolDef(
        name: "camp_status",
        description: "查看营地全景（只读）：各行动的状态与小目标完成比、最近的交付物。",
        inputSchema: objectSchema([:], required: [])
    )

    public static let proposeSquad = ToolDef(
        name: "propose_squad",
        description: "提出组队开工提案：小队名、从名册选的成员 id、行动目标、可选 token 预算。提案会渲染为确认卡片，用户确认后才会真正建队开工——绝不能替用户做决定。",
        inputSchema: objectSchema([
            "name": ["type": "string"],
            "memberIds": ["type": "array", "items": ["type": "string"], "minItems": 1, "maxItems": 6],
            "goal": ["type": "string"],
            "budget": ["type": "integer", "description": "可选，行动 token 预算；缺省用系统默认值"],
        ], required: ["name", "memberIds", "goal"])
    )

    public static let agentTools: [ToolDef] = [
        completeCard,
        blockCard,
        addProgressNote,
        askUser,
        listDir,
        readFile,
        writeFile,
        webFetch,
        searchCampNotes,
    ]

    /// 向导工具固定三件（spec §8：读知识 + 读状态 + 提案组队），不参与勾选。
    public static let guideTools: [ToolDef] = [
        searchCampNotes,
        campStatus,
        proposeSquad,
    ]

    /// 工具中文名（M6-D5）：单点维护，UI 层（活动行/伙伴编辑器）统一查这里。
    public static func displayName(_ name: String) -> String {
        switch name {
        case "complete_card": return "提交交接包"
        case "block_card": return "报告受阻"
        case "add_progress_note": return "汇报进展"
        case "ask_user": return "提问"
        case "list_dir": return "查看目录"
        case "read_file": return "读文件"
        case "write_file": return "写文件"
        case "web_fetch": return "查网页"
        case "search_camp_notes": return "翻营地笔记"
        case "camp_status": return "查看营地全景"
        case "propose_squad": return "组队提案"
        default: return name
        }
    }
}
