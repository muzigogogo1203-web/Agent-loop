import Foundation

public enum RuminationParseError: Error, Sendable, Equatable { case invalidJSON }

public enum RuminationParser {
    public static func parse(_ raw: String) throws -> RuminationResult {
        let stripped = stripFence(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if let result = try? RuminationCoding.decode(stripped) { return try validate(result) }

        // Deterministic repair: keep only the outermost JSON object. No second model call.
        if let first = stripped.firstIndex(of: "{"), let last = stripped.lastIndex(of: "}"), first <= last,
           let result = try? RuminationCoding.decode(String(stripped[first...last])) {
            return try validate(result)
        }
        throw RuminationParseError.invalidJSON
    }

    private static func validate(_ result: RuminationResult) throws -> RuminationResult {
        guard !result.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuminationParseError.invalidJSON
        }
        if let mission = result.suggestedMission,
           mission.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mission.acceptance.isEmpty {
            throw RuminationParseError.invalidJSON
        }
        return result
    }

    private static func stripFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else { return text }
        if let newline = text.firstIndex(of: "\n") { text = String(text[text.index(after: newline)...]) }
        if text.hasSuffix("```") { text.removeLast(3) }
        return text
    }
}
