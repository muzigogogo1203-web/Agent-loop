import Foundation

public struct HandoffPayload: Sendable, Equatable, Codable {
    public struct ArtifactDecl: Sendable, Equatable, Codable {
        public var relativePath: String
        public var kind: String
        public var label: String

        public init(relativePath: String, kind: String, label: String) {
            self.relativePath = relativePath
            self.kind = kind
            self.label = label
        }
    }

    public struct Verification: Sendable, Equatable, Codable {
        public var method: String
        public var passed: Bool
        public var note: String

        public init(method: String, passed: Bool, note: String) {
            self.method = method
            self.passed = passed
            self.note = note
        }
    }

    public var outcome: String
    public var summary: String
    public var artifacts: [ArtifactDecl]
    public var noArtifactReason: String?
    public var verification: [Verification]
    public var next: String?
    public var risks: [String]

    public init(
        outcome: String,
        summary: String,
        artifacts: [ArtifactDecl],
        noArtifactReason: String? = nil,
        verification: [Verification],
        next: String? = nil,
        risks: [String]
    ) {
        self.outcome = outcome
        self.summary = summary
        self.artifacts = artifacts
        self.noArtifactReason = noArtifactReason
        self.verification = verification
        self.next = next
        self.risks = risks
    }

    public static func parse(from input: JSONValue) -> Result<HandoffPayload, String> {
        do {
            let data = try JSONEncoder().encode(input)
            let handoff = try JSONDecoder().decode(HandoffPayload.self, from: data)
            if handoff.outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("outcome 不能为空")
            }
            if handoff.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("summary 不能为空")
            }
            if handoff.artifacts.isEmpty
                && (handoff.noArtifactReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("交接包校验失败：artifacts 为空时必须提供 noArtifactReason 说明为何没有文件产物")
            }
            return .success(handoff)
        } catch {
            return .failure("交接包格式不正确：\(error)。请按 complete_card 的参数 schema 重新提交。")
        }
    }
}
