import Foundation

public struct RuminationResult: Codable, Sendable, Equatable {
    public struct KeyPoint: Codable, Sendable, Equatable {
        public var text: String
        public var sourceQuote: String
        public init(text: String, sourceQuote: String) { self.text = text; self.sourceQuote = sourceQuote }
    }

    public enum Confidence: String, Codable, Sendable { case high, medium, low }

    public struct Requirement: Codable, Sendable, Equatable {
        public var title: String
        public var detail: String
        public var confidence: Confidence
        public init(title: String, detail: String, confidence: Confidence) {
            self.title = title; self.detail = detail; self.confidence = confidence
        }
    }

    public struct Todo: Codable, Sendable, Equatable {
        public var title: String
        public var owner: String?
        public var dueText: String?
        public init(title: String, owner: String? = nil, dueText: String? = nil) {
            self.title = title; self.owner = owner; self.dueText = dueText
        }
    }

    public struct SuggestedMission: Codable, Sendable, Equatable {
        public var goal: String
        public var acceptance: [String]
        public var why: String
        public init(goal: String, acceptance: [String], why: String) {
            self.goal = goal; self.acceptance = acceptance; self.why = why
        }
    }

    public var suggestedTitle: String
    public var summary: String
    public var keyPoints: [KeyPoint]
    public var requirements: [Requirement]
    public var todos: [Todo]
    public var suggestedMission: SuggestedMission?
    public var uncertainties: [String]

    public init(
        suggestedTitle: String,
        summary: String,
        keyPoints: [KeyPoint],
        requirements: [Requirement],
        todos: [Todo],
        suggestedMission: SuggestedMission?,
        uncertainties: [String]
    ) {
        self.suggestedTitle = suggestedTitle
        self.summary = summary
        self.keyPoints = keyPoints
        self.requirements = requirements
        self.todos = todos
        self.suggestedMission = suggestedMission
        self.uncertainties = uncertainties
    }
}

public enum RuminationCoding {
    public static func encode(_ result: RuminationResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(result), as: UTF8.self)
    }

    public static func decode(_ json: String) throws -> RuminationResult {
        try JSONDecoder().decode(RuminationResult.self, from: Data(json.utf8))
    }
}
