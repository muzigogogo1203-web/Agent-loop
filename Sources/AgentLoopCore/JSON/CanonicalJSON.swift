import CryptoKit
import Foundation

public struct CanonicalJSONNotCanonicalError: Error, Sendable, Equatable {
    public init() {}
}

public struct CanonicalJSONNumberOutOfRangeError: Error, Sendable, Equatable {
    public init() {}
}

internal enum CanonicalJSONRootKind: Sendable, Equatable {
    case object
    case array
    case string
    case number
    case boolean
    case null
}

public enum CanonicalJSONV1 {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.dataEncodingStrategy = .base64
        encoder.nonConformingFloatEncodingStrategy = .throw
        return try canonicalize(rawUTF8: encoder.encode(value))
    }

    public static func canonicalize(rawUTF8: Data) throws -> Data {
        try canonicalizeWithRootKind(rawUTF8: rawUTF8).data
    }

    public static func validateCanonical(rawUTF8: Data) throws {
        guard try canonicalize(rawUTF8: rawUTF8) == rawUTF8 else {
            throw CanonicalJSONNotCanonicalError()
        }
    }

    public static func sha256Hex(_ canonicalBytes: Data) -> String {
        let lowercaseHex: [UInt8] = Array("0123456789abcdef".utf8)
        var result: [UInt8] = []
        result.reserveCapacity(64)
        for byte in SHA256.hash(data: canonicalBytes) {
            result.append(lowercaseHex[Int(byte >> 4)])
            result.append(lowercaseHex[Int(byte & 0x0F)])
        }
        return String(decoding: result, as: UTF8.self)
    }

    internal static func canonicalizeWithRootKind(
        rawUTF8: Data
    ) throws -> (
        data: Data,
        rootKind: CanonicalJSONRootKind
    ) {
        let document = try parse(rawUTF8)
        return (
            data: try serialize(document.root),
            rootKind: document.root.kind
        )
    }

    internal static func validateDurableWorkUsageObject(
        rawUTF8: Data
    ) throws {
        let document = try parse(rawUTF8)
        let canonical = try serialize(document.root)
        guard canonical == rawUTF8 else {
            throw CanonicalJSONNotCanonicalError()
        }
        guard case let .object(members) = document.root else {
            throw CanonicalJSONUsageError.rootMustBeObject
        }

        let expectedKeys: Set<ByteString> = [
            ByteString(bytes: Array("cacheReadTokens".utf8)),
            ByteString(bytes: Array("inputTokens".utf8)),
            ByteString(bytes: Array("outputTokens".utf8)),
        ]
        guard members.count == expectedKeys.count else {
            throw CanonicalJSONUsageError.invalidKeys
        }

        var observedKeys = Set<ByteString>()
        for member in members {
            guard expectedKeys.contains(member.key) else {
                throw CanonicalJSONUsageError.invalidKeys
            }
            guard observedKeys.insert(member.key).inserted else {
                throw CanonicalJSONUsageError.invalidKeys
            }
            guard case let .number(number) = member.value else {
                throw CanonicalJSONUsageError.valueMustBeNonNegativeInt64
            }
            try validateNonNegativeInt64(number.raw)
        }
        guard observedKeys == expectedKeys else {
            throw CanonicalJSONUsageError.invalidKeys
        }
    }

    private static func parse(_ rawUTF8: Data) throws -> ParsedDocument {
        var parser = Parser(bytes: Array(rawUTF8))
        return try parser.parseDocument()
    }

    private static func serialize(_ root: Node) throws -> Data {
        var serializer = Serializer()
        try serializer.write(root)
        return Data(serializer.output)
    }

    private static func validateNonNegativeInt64(
        _ rawNumber: [UInt8]
    ) throws {
        guard !rawNumber.isEmpty else {
            throw CanonicalJSONUsageError.valueMustBeNonNegativeInt64
        }
        guard rawNumber.count == 1 || rawNumber[0] != ASCII.zero else {
            throw CanonicalJSONUsageError.valueMustBeNonNegativeInt64
        }

        var value: Int64 = 0
        for byte in rawNumber {
            guard ASCII.isDigit(byte) else {
                throw CanonicalJSONUsageError.valueMustBeNonNegativeInt64
            }
            let (multiplied, multiplyOverflow) =
                value.multipliedReportingOverflow(by: 10)
            let (advanced, addOverflow) = multiplied.addingReportingOverflow(
                Int64(byte - ASCII.zero)
            )
            guard !multiplyOverflow, !addOverflow else {
                throw CanonicalJSONUsageError.valueMustBeNonNegativeInt64
            }
            value = advanced
        }
    }
}

private enum CanonicalJSONSyntaxError: Error, Sendable, Equatable {
    case byteOrderMark
    case unexpectedEnd(offset: Int)
    case unexpectedByte(offset: Int)
    case invalidLiteral(offset: Int)
    case invalidString(offset: Int)
    case invalidEscape(offset: Int)
    case invalidUnicodeEscape(offset: Int)
    case invalidUTF8(offset: Int)
    case duplicateObjectKey(offset: Int)
    case invalidNumber(offset: Int)
    case trailingContent(offset: Int)
}

private enum CanonicalJSONUsageError: Error, Sendable, Equatable {
    case rootMustBeObject
    case invalidKeys
    case valueMustBeNonNegativeInt64
}

private struct ByteString: Hashable, Sendable {
    let bytes: [UInt8]
}

private struct NumberToken: Sendable {
    let raw: [UInt8]
}

private struct Member: Sendable {
    let key: ByteString
    let value: Node
}

private indirect enum Node: Sendable {
    case null
    case boolean(Bool)
    case number(NumberToken)
    case string(ByteString)
    case array([Node])
    case object([Member])

    var kind: CanonicalJSONRootKind {
        switch self {
        case .null:
            .null
        case .boolean:
            .boolean
        case .number:
            .number
        case .string:
            .string
        case .array:
            .array
        case .object:
            .object
        }
    }
}

private struct ParsedDocument: Sendable {
    let root: Node
}

private enum ASCII {
    static let quotationMark: UInt8 = 0x22
    static let reverseSolidus: UInt8 = 0x5C
    static let solidus: UInt8 = 0x2F
    static let minus: UInt8 = 0x2D
    static let plus: UInt8 = 0x2B
    static let period: UInt8 = 0x2E
    static let comma: UInt8 = 0x2C
    static let colon: UInt8 = 0x3A
    static let leftBrace: UInt8 = 0x7B
    static let rightBrace: UInt8 = 0x7D
    static let leftBracket: UInt8 = 0x5B
    static let rightBracket: UInt8 = 0x5D
    static let zero: UInt8 = 0x30
    static let nine: UInt8 = 0x39
    static let lowercaseE: UInt8 = 0x65
    static let uppercaseE: UInt8 = 0x45

    static func isDigit(_ byte: UInt8) -> Bool {
        byte >= zero && byte <= nine
    }

    static func isNonZeroDigit(_ byte: UInt8) -> Bool {
        byte >= 0x31 && byte <= nine
    }

    static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}

private struct Parser {
    let bytes: [UInt8]
    var offset = 0

    mutating func parseDocument() throws -> ParsedDocument {
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            throw CanonicalJSONSyntaxError.byteOrderMark
        }
        skipWhitespace()
        let root = try parseValue()
        skipWhitespace()
        guard offset == bytes.count else {
            throw CanonicalJSONSyntaxError.trailingContent(offset: offset)
        }
        return ParsedDocument(root: root)
    }

    private mutating func parseValue() throws -> Node {
        guard let byte = currentByte else {
            throw CanonicalJSONSyntaxError.unexpectedEnd(offset: offset)
        }
        switch byte {
        case ASCII.leftBrace:
            return try parseObject()
        case ASCII.leftBracket:
            return try parseArray()
        case ASCII.quotationMark:
            return .string(try parseString())
        case ASCII.minus, ASCII.zero ... ASCII.nine:
            return .number(try parseNumber())
        case 0x74:
            try consumeLiteral([0x74, 0x72, 0x75, 0x65])
            return .boolean(true)
        case 0x66:
            try consumeLiteral([0x66, 0x61, 0x6C, 0x73, 0x65])
            return .boolean(false)
        case 0x6E:
            try consumeLiteral([0x6E, 0x75, 0x6C, 0x6C])
            return .null
        default:
            throw CanonicalJSONSyntaxError.unexpectedByte(offset: offset)
        }
    }

    private mutating func parseObject() throws -> Node {
        offset += 1
        skipWhitespace()
        if consumeIf(ASCII.rightBrace) {
            return .object([])
        }

        var members: [Member] = []
        var decodedKeys = Set<ByteString>()
        while true {
            guard currentByte == ASCII.quotationMark else {
                throw CanonicalJSONSyntaxError.unexpectedByte(offset: offset)
            }
            let keyOffset = offset
            let key = try parseString()
            guard decodedKeys.insert(key).inserted else {
                throw CanonicalJSONSyntaxError.duplicateObjectKey(
                    offset: keyOffset
                )
            }

            skipWhitespace()
            guard consumeIf(ASCII.colon) else {
                throw CanonicalJSONSyntaxError.unexpectedByte(offset: offset)
            }
            skipWhitespace()
            let value = try parseValue()
            members.append(Member(key: key, value: value))

            skipWhitespace()
            if consumeIf(ASCII.rightBrace) {
                return .object(members)
            }
            guard consumeIf(ASCII.comma) else {
                throw CanonicalJSONSyntaxError.unexpectedByte(offset: offset)
            }
            skipWhitespace()
        }
    }

    private mutating func parseArray() throws -> Node {
        offset += 1
        skipWhitespace()
        if consumeIf(ASCII.rightBracket) {
            return .array([])
        }

        var elements: [Node] = []
        while true {
            elements.append(try parseValue())
            skipWhitespace()
            if consumeIf(ASCII.rightBracket) {
                return .array(elements)
            }
            guard consumeIf(ASCII.comma) else {
                throw CanonicalJSONSyntaxError.unexpectedByte(offset: offset)
            }
            skipWhitespace()
        }
    }

    private mutating func parseString() throws -> ByteString {
        guard consumeIf(ASCII.quotationMark) else {
            throw CanonicalJSONSyntaxError.invalidString(offset: offset)
        }

        var decoded: [UInt8] = []
        while true {
            guard let byte = currentByte else {
                throw CanonicalJSONSyntaxError.unexpectedEnd(offset: offset)
            }
            switch byte {
            case ASCII.quotationMark:
                offset += 1
                return ByteString(bytes: decoded)
            case ASCII.reverseSolidus:
                try parseEscape(into: &decoded)
            case 0x00 ... 0x1F:
                throw CanonicalJSONSyntaxError.invalidString(offset: offset)
            case 0x20 ... 0x7F:
                decoded.append(byte)
                offset += 1
            default:
                let scalarLength = try validatedUTF8ScalarLength(at: offset)
                decoded.append(
                    contentsOf: bytes[offset ..< offset + scalarLength]
                )
                offset += scalarLength
            }
        }
    }

    private mutating func parseEscape(into decoded: inout [UInt8]) throws {
        let escapeOffset = offset
        offset += 1
        guard let escaped = currentByte else {
            throw CanonicalJSONSyntaxError.unexpectedEnd(offset: offset)
        }
        offset += 1
        switch escaped {
        case ASCII.quotationMark:
            decoded.append(ASCII.quotationMark)
        case ASCII.reverseSolidus:
            decoded.append(ASCII.reverseSolidus)
        case ASCII.solidus:
            decoded.append(ASCII.solidus)
        case 0x62:
            decoded.append(0x08)
        case 0x66:
            decoded.append(0x0C)
        case 0x6E:
            decoded.append(0x0A)
        case 0x72:
            decoded.append(0x0D)
        case 0x74:
            decoded.append(0x09)
        case 0x75:
            try parseUnicodeEscape(into: &decoded, escapeOffset: escapeOffset)
        default:
            throw CanonicalJSONSyntaxError.invalidEscape(offset: escapeOffset)
        }
    }

    private mutating func parseUnicodeEscape(
        into decoded: inout [UInt8],
        escapeOffset: Int
    ) throws {
        let first = try parseFourHexDigits(escapeOffset: escapeOffset)
        let scalar: UInt32

        if first >= 0xD800, first <= 0xDBFF {
            guard
                remainingByteCount >= 2,
                bytes[offset] == ASCII.reverseSolidus,
                bytes[offset + 1] == 0x75
            else {
                throw CanonicalJSONSyntaxError.invalidUnicodeEscape(
                    offset: escapeOffset
                )
            }
            offset += 2
            let second = try parseFourHexDigits(escapeOffset: escapeOffset)
            guard second >= 0xDC00, second <= 0xDFFF else {
                throw CanonicalJSONSyntaxError.invalidUnicodeEscape(
                    offset: escapeOffset
                )
            }
            scalar =
                0x1_0000
                + (UInt32(first - 0xD800) << 10)
                + UInt32(second - 0xDC00)
        } else {
            guard first < 0xDC00 || first > 0xDFFF else {
                throw CanonicalJSONSyntaxError.invalidUnicodeEscape(
                    offset: escapeOffset
                )
            }
            scalar = UInt32(first)
        }

        appendUTF8(scalar, to: &decoded)
    }

    private mutating func parseFourHexDigits(
        escapeOffset: Int
    ) throws -> UInt16 {
        guard remainingByteCount >= 4 else {
            throw CanonicalJSONSyntaxError.unexpectedEnd(offset: offset)
        }
        var value: UInt16 = 0
        for _ in 0 ..< 4 {
            guard let nibble = hexNibble(bytes[offset]) else {
                throw CanonicalJSONSyntaxError.invalidUnicodeEscape(
                    offset: escapeOffset
                )
            }
            value = value * 16 + UInt16(nibble)
            offset += 1
        }
        return value
    }

    private func validatedUTF8ScalarLength(at start: Int) throws -> Int {
        let first = bytes[start]
        switch first {
        case 0xC2 ... 0xDF:
            try requireContinuationBytes(at: start, count: 1)
            return 2
        case 0xE0:
            try requireByte(at: start + 1, in: 0xA0 ... 0xBF, start: start)
            try requireByte(at: start + 2, in: 0x80 ... 0xBF, start: start)
            return 3
        case 0xE1 ... 0xEC, 0xEE ... 0xEF:
            try requireContinuationBytes(at: start, count: 2)
            return 3
        case 0xED:
            try requireByte(at: start + 1, in: 0x80 ... 0x9F, start: start)
            try requireByte(at: start + 2, in: 0x80 ... 0xBF, start: start)
            return 3
        case 0xF0:
            try requireByte(at: start + 1, in: 0x90 ... 0xBF, start: start)
            try requireByte(at: start + 2, in: 0x80 ... 0xBF, start: start)
            try requireByte(at: start + 3, in: 0x80 ... 0xBF, start: start)
            return 4
        case 0xF1 ... 0xF3:
            try requireContinuationBytes(at: start, count: 3)
            return 4
        case 0xF4:
            try requireByte(at: start + 1, in: 0x80 ... 0x8F, start: start)
            try requireByte(at: start + 2, in: 0x80 ... 0xBF, start: start)
            try requireByte(at: start + 3, in: 0x80 ... 0xBF, start: start)
            return 4
        default:
            throw CanonicalJSONSyntaxError.invalidUTF8(offset: start)
        }
    }

    private func requireContinuationBytes(
        at start: Int,
        count: Int
    ) throws {
        for distance in 1 ... count {
            try requireByte(
                at: start + distance,
                in: 0x80 ... 0xBF,
                start: start
            )
        }
    }

    private func requireByte(
        at index: Int,
        in range: ClosedRange<UInt8>,
        start: Int
    ) throws {
        guard index < bytes.count, range.contains(bytes[index]) else {
            throw CanonicalJSONSyntaxError.invalidUTF8(offset: start)
        }
    }

    private mutating func parseNumber() throws -> NumberToken {
        let start = offset
        _ = consumeIf(ASCII.minus)

        guard let firstIntegerByte = currentByte else {
            throw CanonicalJSONSyntaxError.invalidNumber(offset: start)
        }

        var coefficientDigitCount = 0
        if firstIntegerByte == ASCII.zero {
            offset += 1
            coefficientDigitCount = 1
            if let next = currentByte, ASCII.isDigit(next) {
                throw CanonicalJSONSyntaxError.invalidNumber(offset: start)
            }
        } else if ASCII.isNonZeroDigit(firstIntegerByte) {
            repeat {
                offset += 1
                coefficientDigitCount += 1
                try validateNumberInputLimits(
                    start: start,
                    coefficientDigitCount: coefficientDigitCount
                )
            } while currentByte.map(ASCII.isDigit) == true
        } else {
            throw CanonicalJSONSyntaxError.invalidNumber(offset: start)
        }

        if consumeIf(ASCII.period) {
            guard currentByte.map(ASCII.isDigit) == true else {
                throw CanonicalJSONSyntaxError.invalidNumber(offset: start)
            }
            repeat {
                offset += 1
                coefficientDigitCount += 1
                try validateNumberInputLimits(
                    start: start,
                    coefficientDigitCount: coefficientDigitCount
                )
            } while currentByte.map(ASCII.isDigit) == true
        }

        if currentByte == ASCII.lowercaseE || currentByte == ASCII.uppercaseE {
            offset += 1
            let exponentIsNegative = consumeIf(ASCII.minus)
            if !exponentIsNegative {
                _ = consumeIf(ASCII.plus)
            }
            guard currentByte.map(ASCII.isDigit) == true else {
                throw CanonicalJSONSyntaxError.invalidNumber(offset: start)
            }

            var exponentMagnitude = 0
            repeat {
                let digit = Int(bytes[offset] - ASCII.zero)
                let (multiplied, multiplyOverflow) =
                    exponentMagnitude.multipliedReportingOverflow(by: 10)
                let (advanced, addOverflow) =
                    multiplied.addingReportingOverflow(digit)
                guard !multiplyOverflow, !addOverflow else {
                    throw CanonicalJSONNumberOutOfRangeError()
                }
                exponentMagnitude = advanced
                offset += 1
                try validateNumberInputLimits(
                    start: start,
                    coefficientDigitCount: coefficientDigitCount
                )
            } while currentByte.map(ASCII.isDigit) == true

            let explicitExponent =
                exponentIsNegative ? -exponentMagnitude : exponentMagnitude
            guard (-324 ... 324).contains(explicitExponent) else {
                throw CanonicalJSONNumberOutOfRangeError()
            }
        }

        try validateNumberInputLimits(
            start: start,
            coefficientDigitCount: coefficientDigitCount
        )
        return NumberToken(raw: Array(bytes[start ..< offset]))
    }

    private func validateNumberInputLimits(
        start: Int,
        coefficientDigitCount: Int
    ) throws {
        guard offset - start <= 128, coefficientDigitCount <= 128 else {
            throw CanonicalJSONNumberOutOfRangeError()
        }
    }

    private mutating func consumeLiteral(_ literal: [UInt8]) throws {
        let start = offset
        guard remainingByteCount >= literal.count else {
            throw CanonicalJSONSyntaxError.unexpectedEnd(offset: offset)
        }
        for expected in literal {
            guard bytes[offset] == expected else {
                throw CanonicalJSONSyntaxError.invalidLiteral(offset: start)
            }
            offset += 1
        }
    }

    private mutating func skipWhitespace() {
        while let byte = currentByte, ASCII.isWhitespace(byte) {
            offset += 1
        }
    }

    private mutating func consumeIf(_ byte: UInt8) -> Bool {
        guard currentByte == byte else {
            return false
        }
        offset += 1
        return true
    }

    private var currentByte: UInt8? {
        offset < bytes.count ? bytes[offset] : nil
    }

    private var remainingByteCount: Int {
        bytes.count - offset
    }
}

private struct Serializer {
    var output: [UInt8] = []

    mutating func write(_ node: Node) throws {
        switch node {
        case .null:
            output.append(contentsOf: [0x6E, 0x75, 0x6C, 0x6C])
        case let .boolean(value):
            output.append(
                contentsOf: value
                    ? [0x74, 0x72, 0x75, 0x65]
                    : [0x66, 0x61, 0x6C, 0x73, 0x65]
            )
        case let .number(number):
            output.append(contentsOf: try normalizeNumber(number.raw))
        case let .string(string):
            writeString(string.bytes)
        case let .array(elements):
            output.append(ASCII.leftBracket)
            for (index, element) in elements.enumerated() {
                if index > 0 {
                    output.append(ASCII.comma)
                }
                try write(element)
            }
            output.append(ASCII.rightBracket)
        case let .object(members):
            output.append(ASCII.leftBrace)
            let sortedMembers = members.sorted {
                lexicographicallyPrecedes($0.key.bytes, $1.key.bytes)
            }
            for (index, member) in sortedMembers.enumerated() {
                if index > 0 {
                    output.append(ASCII.comma)
                }
                writeString(member.key.bytes)
                output.append(ASCII.colon)
                try write(member.value)
            }
            output.append(ASCII.rightBrace)
        }
    }

    private mutating func writeString(_ bytes: [UInt8]) {
        output.append(ASCII.quotationMark)
        for byte in bytes {
            switch byte {
            case ASCII.quotationMark:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x22])
            case ASCII.reverseSolidus:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x5C])
            case 0x08:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x62])
            case 0x09:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x74])
            case 0x0A:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x6E])
            case 0x0C:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x66])
            case 0x0D:
                output.append(contentsOf: [ASCII.reverseSolidus, 0x72])
            case 0x00 ... 0x1F:
                let lowercaseHex: [UInt8] =
                    Array("0123456789abcdef".utf8)
                output.append(contentsOf: [
                    ASCII.reverseSolidus,
                    0x75,
                    ASCII.zero,
                    ASCII.zero,
                    lowercaseHex[Int(byte >> 4)],
                    lowercaseHex[Int(byte & 0x0F)],
                ])
            default:
                output.append(byte)
            }
        }
        output.append(ASCII.quotationMark)
    }

    private func normalizeNumber(_ raw: [UInt8]) throws -> [UInt8] {
        var index = 0
        let isNegative = raw[index] == ASCII.minus
        if isNegative {
            index += 1
        }

        var digits: [UInt8] = []
        while index < raw.count, ASCII.isDigit(raw[index]) {
            digits.append(raw[index])
            index += 1
        }

        var fractionDigitCount = 0
        if index < raw.count, raw[index] == ASCII.period {
            index += 1
            while index < raw.count, ASCII.isDigit(raw[index]) {
                digits.append(raw[index])
                fractionDigitCount += 1
                index += 1
            }
        }

        var explicitExponent = 0
        if index < raw.count,
            raw[index] == ASCII.lowercaseE
                || raw[index] == ASCII.uppercaseE
        {
            index += 1
            let exponentIsNegative =
                index < raw.count && raw[index] == ASCII.minus
            if exponentIsNegative
                || (index < raw.count && raw[index] == ASCII.plus)
            {
                index += 1
            }
            var exponentMagnitude = 0
            while index < raw.count {
                let digit = Int(raw[index] - ASCII.zero)
                let (multiplied, multiplyOverflow) =
                    exponentMagnitude.multipliedReportingOverflow(by: 10)
                let (advanced, addOverflow) =
                    multiplied.addingReportingOverflow(digit)
                guard !multiplyOverflow, !addOverflow else {
                    throw CanonicalJSONNumberOutOfRangeError()
                }
                exponentMagnitude = advanced
                index += 1
            }
            explicitExponent =
                exponentIsNegative ? -exponentMagnitude : exponentMagnitude
        }

        guard digits.contains(where: { $0 != ASCII.zero }) else {
            return [ASCII.zero]
        }

        let firstNonZero = digits.firstIndex {
            $0 != ASCII.zero
        }!
        let lastNonZero = digits.lastIndex {
            $0 != ASCII.zero
        }!
        let trailingZeroCount = digits.count - lastNonZero - 1
        let significantDigits = Array(digits[firstNonZero ... lastNonZero])

        let (baseExponent, subtractOverflow) =
            explicitExponent.subtractingReportingOverflow(
                fractionDigitCount
            )
        let (decimalExponent, addOverflow) =
            baseExponent.addingReportingOverflow(trailingZeroCount)
        guard !subtractOverflow, !addOverflow else {
            throw CanonicalJSONNumberOutOfRangeError()
        }

        var normalized: [UInt8] = []
        if isNegative {
            normalized.append(ASCII.minus)
        }

        if decimalExponent >= 0 {
            normalized.append(contentsOf: significantDigits)
            try appendZeros(decimalExponent, to: &normalized)
        } else {
            let (pointPosition, pointOverflow) =
                significantDigits.count.addingReportingOverflow(
                    decimalExponent
                )
            guard !pointOverflow else {
                throw CanonicalJSONNumberOutOfRangeError()
            }
            if pointPosition > 0 {
                normalized.append(
                    contentsOf: significantDigits[..<pointPosition]
                )
                normalized.append(ASCII.period)
                normalized.append(
                    contentsOf: significantDigits[pointPosition...]
                )
            } else {
                normalized.append(contentsOf: [ASCII.zero, ASCII.period])
                guard pointPosition != Int.min else {
                    throw CanonicalJSONNumberOutOfRangeError()
                }
                try appendZeros(-pointPosition, to: &normalized)
                normalized.append(contentsOf: significantDigits)
            }
        }

        guard normalized.count <= 512 else {
            throw CanonicalJSONNumberOutOfRangeError()
        }
        return normalized
    }

    private func appendZeros(
        _ count: Int,
        to bytes: inout [UInt8]
    ) throws {
        guard count >= 0 else {
            throw CanonicalJSONNumberOutOfRangeError()
        }
        let (resultingCount, overflow) =
            bytes.count.addingReportingOverflow(count)
        guard !overflow, resultingCount <= 512 else {
            throw CanonicalJSONNumberOutOfRangeError()
        }
        bytes.append(contentsOf: repeatElement(ASCII.zero, count: count))
    }

    private func lexicographicallyPrecedes(
        _ lhs: [UInt8],
        _ rhs: [UInt8]
    ) -> Bool {
        let sharedCount = min(lhs.count, rhs.count)
        for index in 0 ..< sharedCount {
            if lhs[index] != rhs[index] {
                return lhs[index] < rhs[index]
            }
        }
        return lhs.count < rhs.count
    }
}

private func hexNibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 0x30 ... 0x39:
        byte - 0x30
    case 0x41 ... 0x46:
        byte - 0x41 + 10
    case 0x61 ... 0x66:
        byte - 0x61 + 10
    default:
        nil
    }
}

private func appendUTF8(_ scalar: UInt32, to bytes: inout [UInt8]) {
    switch scalar {
    case 0 ... 0x7F:
        bytes.append(UInt8(scalar))
    case 0x80 ... 0x7FF:
        bytes.append(0xC0 | UInt8(scalar >> 6))
        bytes.append(0x80 | UInt8(scalar & 0x3F))
    case 0x800 ... 0xFFFF:
        bytes.append(0xE0 | UInt8(scalar >> 12))
        bytes.append(0x80 | UInt8((scalar >> 6) & 0x3F))
        bytes.append(0x80 | UInt8(scalar & 0x3F))
    default:
        bytes.append(0xF0 | UInt8(scalar >> 18))
        bytes.append(0x80 | UInt8((scalar >> 12) & 0x3F))
        bytes.append(0x80 | UInt8((scalar >> 6) & 0x3F))
        bytes.append(0x80 | UInt8(scalar & 0x3F))
    }
}
