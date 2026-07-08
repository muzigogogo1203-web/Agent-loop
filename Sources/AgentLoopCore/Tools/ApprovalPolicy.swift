/// 工具风险分级与行动自主档位（M7-D1/D2）。
/// 放行矩阵 = risk × autonomy；板工具与只读工具永不过审（终结契约不可被门挡，spec §5.2-4）。

public enum ToolRisk: String, Sendable, Equatable {
    case readOnly = "read_only"
    case write
    case dangerous
}

extension ToolDef {
    /// 工具风险单点映射（M7-D1）。M8 的 MCP 外部工具（mcp__ 前缀）默认 write 级。
    public static func risk(_ name: String) -> ToolRisk {
        switch name {
        case "write_file":
            return .write
        case "run_shell":
            return .dangerous
        default:
            return name.hasPrefix("mcp__") ? .write : .readOnly
        }
    }
}

/// 行动自主档位（远征风：谨慎/标准/放手）。存 mission.autonomy（迁移 v5），中途可改（记事件）。
public enum MissionAutonomy: String, Codable, Sendable, CaseIterable, Equatable {
    case careful
    case standard
    case free

    /// 放行矩阵：该档位下调用某风险级的工具是否需要人工批准。
    public func requiresApproval(risk: ToolRisk) -> Bool {
        switch self {
        case .careful: return risk != .readOnly
        case .standard: return risk == .dangerous
        case .free: return false
        }
    }

    /// 界面名（远征风）
    public var displayName: String {
        switch self {
        case .careful: return "谨慎"
        case .standard: return "标准"
        case .free: return "放手"
        }
    }
}
