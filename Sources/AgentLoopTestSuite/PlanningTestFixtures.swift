import Foundation

enum PlanningSourceFixtureError: Error, Equatable, CustomStringConvertible {
    case sourceMissing(String)
    case signatureMissing(String)
    case signatureDuplicated(String)
    case openingBraceMissing(String)
    case unbalancedBraces(String)
    case tokenMissing(String)
    case tokenOrder(String, String)

    var description: String {
        switch self {
        case let .sourceMissing(path):
            return "Planning source fixture is missing: \(path)"
        case let .signatureMissing(signature):
            return "Function signature is missing: \(signature)"
        case let .signatureDuplicated(signature):
            return "Function signature is duplicated: \(signature)"
        case let .openingBraceMissing(signature):
            return "Function opening brace is missing: \(signature)"
        case let .unbalancedBraces(signature):
            return "Function braces are unbalanced: \(signature)"
        case let .tokenMissing(token):
            return "Required token is missing: \(token)"
        case let .tokenOrder(first, second):
            return "Token order is invalid: \(first) must precede \(second)"
        }
    }
}

struct PlanningSourceFunctionFixture {
    let source: String
    let maskedSource: String
    let range: Range<String.Index>

    var body: Substring {
        source[range]
    }

    var maskedBody: Substring {
        maskedSource[range]
    }

    func requireTokensInOrder(_ tokens: [String]) throws {
        var cursor = maskedBody.startIndex
        for token in tokens {
            guard let range = maskedBody.range(
                of: token,
                range: cursor..<maskedBody.endIndex
            ) else {
                throw PlanningSourceFixtureError.tokenMissing(token)
            }
            cursor = range.upperBound
        }
    }

    func requireAbsent(_ token: String) throws {
        if maskedBody.range(of: token) != nil {
            throw PlanningSourceFixtureError.tokenOrder(token, "absent")
        }
    }
}

enum PlanningTestFixtures {
    static func packageRoot(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func source(
        _ relativePath: String,
        filePath: String = #filePath
    ) throws -> String {
        let url = packageRoot(filePath: filePath)
            .appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlanningSourceFixtureError.sourceMissing(url.path)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func uniqueFunction(
        in source: String,
        signature: String
    ) throws -> PlanningSourceFunctionFixture {
        let masked = maskCommentsAndStrings(in: source)
        var matches: [Range<String.Index>] = []
        var cursor = masked.startIndex
        while cursor < masked.endIndex,
              let match = masked.range(
                  of: signature,
                  range: cursor..<masked.endIndex
              )
        {
            matches.append(match)
            cursor = match.upperBound
        }
        guard !matches.isEmpty else {
            throw PlanningSourceFixtureError.signatureMissing(signature)
        }
        guard matches.count == 1, let signatureRange = matches.first else {
            throw PlanningSourceFixtureError.signatureDuplicated(signature)
        }
        guard let openingBrace = masked[
            signatureRange.upperBound..<masked.endIndex
        ].firstIndex(of: "{") else {
            throw PlanningSourceFixtureError.openingBraceMissing(signature)
        }

        var depth = 0
        var index = openingBrace
        while index < masked.endIndex {
            switch masked[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    let end = masked.index(after: index)
                    return PlanningSourceFunctionFixture(
                        source: source,
                        maskedSource: masked,
                        range: signatureRange.lowerBound..<end
                    )
                }
                if depth < 0 {
                    throw PlanningSourceFixtureError
                        .unbalancedBraces(signature)
                }
            default:
                break
            }
            index = masked.index(after: index)
        }
        throw PlanningSourceFixtureError.unbalancedBraces(signature)
    }

    static func maskCommentsAndStrings(in source: String) -> String {
        enum State {
            case code
            case lineComment
            case blockComment(depth: Int)
            case string(hashCount: Int, multiline: Bool)
        }

        let scalars = Array(source.unicodeScalars)
        var output = scalars
        var state = State.code
        var index = 0

        func matches(_ values: [UnicodeScalar], at offset: Int) -> Bool {
            guard offset + values.count <= scalars.count else { return false }
            return Array(scalars[offset..<(offset + values.count)]) == values
        }

        func replaceNonNewline(at offset: Int) {
            if scalars[offset] != "\n" && scalars[offset] != "\r" {
                output[offset] = " "
            }
        }

        while index < scalars.count {
            switch state {
            case .code:
                if matches(["/", "/"], at: index) {
                    replaceNonNewline(at: index)
                    replaceNonNewline(at: index + 1)
                    index += 2
                    state = .lineComment
                    continue
                }
                if matches(["/", "*"], at: index) {
                    replaceNonNewline(at: index)
                    replaceNonNewline(at: index + 1)
                    index += 2
                    state = .blockComment(depth: 1)
                    continue
                }

                var hashCount = 0
                var quoteOffset = index
                while quoteOffset < scalars.count,
                      scalars[quoteOffset] == "#"
                {
                    hashCount += 1
                    quoteOffset += 1
                }
                if quoteOffset < scalars.count,
                   scalars[quoteOffset] == "\""
                {
                    let multiline = matches(
                        ["\"", "\"", "\""],
                        at: quoteOffset
                    )
                    let terminatorCount = multiline ? 3 : 1
                    for offset in index..<(quoteOffset + terminatorCount) {
                        replaceNonNewline(at: offset)
                    }
                    index = quoteOffset + terminatorCount
                    state = .string(
                        hashCount: hashCount,
                        multiline: multiline
                    )
                    continue
                }
                index += 1

            case .lineComment:
                replaceNonNewline(at: index)
                if scalars[index] == "\n" || scalars[index] == "\r" {
                    state = .code
                }
                index += 1

            case let .blockComment(depth):
                if matches(["/", "*"], at: index) {
                    replaceNonNewline(at: index)
                    replaceNonNewline(at: index + 1)
                    index += 2
                    state = .blockComment(depth: depth + 1)
                } else if matches(["*", "/"], at: index) {
                    replaceNonNewline(at: index)
                    replaceNonNewline(at: index + 1)
                    index += 2
                    state = depth == 1
                        ? .code
                        : .blockComment(depth: depth - 1)
                } else {
                    replaceNonNewline(at: index)
                    index += 1
                }

            case let .string(hashCount, multiline):
                let quotes: [UnicodeScalar] = multiline
                    ? ["\"", "\"", "\""]
                    : ["\""]
                let hashes = Array(
                    repeating: "#" as UnicodeScalar,
                    count: hashCount
                )
                let terminator = quotes + hashes
                if matches(terminator, at: index) {
                    for offset in index..<(index + terminator.count) {
                        replaceNonNewline(at: offset)
                    }
                    index += terminator.count
                    state = .code
                    continue
                }
                if hashCount == 0,
                   !multiline,
                   scalars[index] == "\\",
                   index + 1 < scalars.count
                {
                    replaceNonNewline(at: index)
                    replaceNonNewline(at: index + 1)
                    index += 2
                    continue
                }
                replaceNonNewline(at: index)
                index += 1
            }
        }

        return String(String.UnicodeScalarView(output))
    }
}
