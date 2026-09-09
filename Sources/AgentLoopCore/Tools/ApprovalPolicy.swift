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

package struct ApprovalGrantPolicyAuthorityV1:
    Codable, Sendable, Equatable, Hashable
{
    package let id: String
    package let version: Int
    package let actorId: String
    package let contentHash: String

    package init(id: String, version: Int, actorId: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateNonempty(actorId)
        let material = Material(
            id: id,
            version: version,
            actorId: actorId
        )
        self.id = id
        self.version = version
        self.actorId = actorId
        contentHash = try CanonicalContractCodingV1.hash(material)
    }

    private struct Material: Codable {
        let id: String
        let version: Int
        let actorId: String
    }
}

package struct ApprovalGrantPolicyRegistryV1: Sendable {
    private let authorities: Set<ApprovalGrantPolicyAuthorityV1>

    private init(authorities: Set<ApprovalGrantPolicyAuthorityV1>) {
        self.authorities = authorities
    }

    package init(_ authorities: [ApprovalGrantPolicyAuthorityV1]) throws {
        guard Set(authorities.map { "\($0.id):\($0.version)" }).count
                == authorities.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        self.authorities = Set(authorities)
    }

    package static let empty = ApprovalGrantPolicyRegistryV1(authorities: [])

    package func contains(_ grantor: ApprovalGrantorV1) -> Bool {
        guard grantor.type == .policy,
              let id = grantor.policyId,
              let version = grantor.policyVersion,
              let hash = grantor.policyHash
        else { return false }
        return authorities.contains(where: {
            $0.id == id && $0.version == version
                && $0.actorId == grantor.id && $0.contentHash == hash
        })
    }
}
