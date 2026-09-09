import CryptoKit
import Foundation
import Testing
import AgentLoopCore

private struct CanonicalJSONTypedFixture: Encodable {
    let s: String
    let u: String
    let i: Int
    let f: Double
    let z: Double
}

private struct CanonicalJSONNonFiniteFixture: Encodable {
    let value: Double
}

private func canonicalJSONSource() throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("AgentLoopCore")
        .appendingPathComponent("JSON")
        .appendingPathComponent("CanonicalJSON.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

private func canonicalize(_ raw: String) throws -> String {
    String(
        decoding: try CanonicalJSONV1.canonicalize(
            rawUTF8: Data(raw.utf8)
        ),
        as: UTF8.self
    )
}

private func isLowercaseSHA256Hex(_ value: String) -> Bool {
    guard value.utf8.count == 64 else { return false }
    for byte in value.utf8 {
        let isDigit = byte >= 48 && byte <= 57
        let isLowerHexLetter = byte >= 97 && byte <= 102
        guard isDigit || isLowerHexLetter else { return false }
    }
    return true
}

@Test func canonicalTypedAndRawPathsProduceIdenticalBytes() throws {
    let typed = CanonicalJSONTypedFixture(
        s: "a/b",
        u: "é中",
        i: 42,
        f: 1.23,
        z: -0.0
    )
    let raw = Data(
        #"{"z":-0.0,"u":"\u00e9中","s":"a\/b","i":42,"f":1.2300}"#.utf8
    )

    let typedBytes = try CanonicalJSONV1.encode(typed)
    let rawBytes = try CanonicalJSONV1.canonicalize(rawUTF8: raw)
    #expect(typedBytes == rawBytes)
    #expect(
        String(decoding: typedBytes, as: UTF8.self)
            == #"{"f":1.23,"i":42,"s":"a/b","u":"é中","z":0}"#
    )

    let hash = CanonicalJSONV1.sha256Hex(typedBytes)
    #expect(hash.count == 64)
    #expect(isLowercaseSHA256Hex(hash))
    #expect(hash == SHA256.hash(data: typedBytes).map {
        String(format: "%02x", $0)
    }.joined())
}

@Test func canonicalSlashAndUnicodeGoldenBytes() throws {
    #expect(
        try canonicalize(#"{"s":"a\/b"}"#)
            == #"{"s":"a/b"}"#
    )
    #expect(
        try canonicalize(#"{"u":"\u00e9中"}"#)
            == #"{"u":"é中"}"#
    )
    #expect(
        try canonicalize(#"{"é":1,"e\u0301":2}"#)
            == #"{"é":2,"é":1}"#
    )
    #expect(
        try canonicalize(
            #"{"line":"a\nb","quote":"\"","slash":"\\","sep":"\u2028\u2029"}"#
        )
            == #"{"line":"a\nb","quote":"\"","sep":"  ","slash":"\\"}"#
    )
}

@Test func canonicalNumberGoldenBytes() throws {
    let input = #"{"i":42,"f":1.2300,"e":1e+3,"m":1e-3,"z":-0.0}"#
    #expect(
        try canonicalize(input)
            == #"{"e":1000,"f":1.23,"i":42,"m":0.001,"z":0}"#
    )
}

@Test func canonicalRejectsDuplicateDecodedKeysAndInvalidUnicode() throws {
    let duplicateDecodedKey = Data(#"{"a":1,"\u0061":2}"#.utf8)
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.canonicalize(rawUTF8: duplicateDecodedKey)
    }

    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.canonicalize(
            rawUTF8: Data(#""\uD800""#.utf8)
        )
    }
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.canonicalize(
            rawUTF8: Data([0x22, 0xC3, 0x28, 0x22])
        )
    }
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.canonicalize(
            rawUTF8: Data([0xEF, 0xBB, 0xBF, 0x7B, 0x7D])
        )
    }
}

@Test func canonicalPreservesIntegerBeyondTwoToThe53() throws {
    #expect(
        try canonicalize(#"{"n":9007199254740993}"#)
            == #"{"n":9007199254740993}"#
    )
    #expect(
        try canonicalize(#"{"n":9223372036854775808}"#)
            == #"{"n":9223372036854775808}"#
    )
}

@Test func canonicalKeepsCanonicallyEquivalentButByteDistinctKeys() throws {
    let composed = "é"
    let decomposed = "e\u{301}"
    #expect(Array(composed.utf8) != Array(decomposed.utf8))

    let canonical = try canonicalize(
        "{\"\(composed)\":1,\"\(decomposed)\":2}"
    )
    #expect(canonical == "{\"\(decomposed)\":2,\"\(composed)\":1}")
    #expect(canonical.utf8.contains(0xCC))
    #expect(canonical.utf8.contains(0xC3))
}

@Test func canonicalObjectRootInspectionDoesNotUseJSONValueOrRawJSONDecoder() throws {
    #expect(try canonicalize(#"{"object":true}"#) == #"{"object":true}"#)
    #expect(try canonicalize(#"[1,2,3]"#) == #"[1,2,3]"#)

    let source = try canonicalJSONSource()
    #expect(source.contains("canonicalizeWithRootKind"))
    #expect(source.contains("validateDurableWorkUsageObject"))
    #expect(!source.contains("JSONValue"))
    #expect(!source.contains("JSONSerialization"))
    #expect(!source.contains("JSONDecoder"))
}

@Test func canonicalRejectsInvalidOrOutOfBoundsNumbers() throws {
    let invalidValues = [
        "+1", "01", "-01", "-", "1.", ".1", "1e", "1e+", "1e-",
        "NaN", "Infinity", "-Infinity", "1e325", "1e-325",
        String(repeating: "9", count: 129),
        String(repeating: "9", count: 128) + ".1",
    ]
    for value in invalidValues {
        #expect(throws: (any Error).self) {
            try CanonicalJSONV1.canonicalize(
                rawUTF8: Data("[\(value)]".utf8)
            )
        }
    }

    let exactTokenLimit = String(repeating: "9", count: 128)
    #expect(try canonicalize(exactTokenLimit) == exactTokenLimit)

    // With all frozen input limits enforced, a standalone >512-byte output
    // cannot be reached. Exercise the largest boundary vector available under
    // the 128-byte token cap instead of fabricating an illegal successful parse.
    let maximumReachableToken =
        "-" + String(repeating: "9", count: 123) + "e324"
    #expect(maximumReachableToken.utf8.count == 128)
    let maximumReachableOutput = try CanonicalJSONV1.canonicalize(
        rawUTF8: Data(maximumReachableToken.utf8)
    )
    #expect(maximumReachableOutput.count == 448)
    #expect(maximumReachableOutput.first == 0x2D)
    #expect(maximumReachableOutput.last == 0x30)

    let source = try canonicalJSONSource()
    #expect(source.contains("512"))
    #expect(source.contains("CanonicalJSONNumberOutOfRangeError"))
}

@Test func canonicalTypedNonConformingFloatThrows() throws {
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.encode(
            CanonicalJSONNonFiniteFixture(value: .nan)
        )
    }
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.encode(
            CanonicalJSONNonFiniteFixture(value: .infinity)
        )
    }
    #expect(throws: (any Error).self) {
        try CanonicalJSONV1.encode(
            CanonicalJSONNonFiniteFixture(value: -.infinity)
        )
    }
}

@Test func validateCanonicalRejectsAlternateRepresentations() throws {
    let canonical = Data(#"{"m":0.001,"s":"a/b","u":"é","z":0}"#.utf8)
    try CanonicalJSONV1.validateCanonical(rawUTF8: canonical)

    let alternateRepresentations = [
        #" {"m":0.001,"s":"a/b","u":"é","z":0}"#,
        #"{"m":0.001,"s":"a\/b","u":"é","z":0}"#,
        #"{"m":0.001,"s":"a/b","u":"\u00e9","z":0}"#,
        #"{"m":0.0010,"s":"a/b","u":"é","z":0}"#,
        #"{"m":1e-3,"s":"a/b","u":"é","z":0}"#,
        #"{"m":0.001,"s":"a/b","u":"é","z":-0}"#,
    ]
    for alternate in alternateRepresentations {
        #expect(throws: CanonicalJSONNotCanonicalError.self) {
            try CanonicalJSONV1.validateCanonical(
                rawUTF8: Data(alternate.utf8)
            )
        }
        #expect(
            try CanonicalJSONV1.canonicalize(
                rawUTF8: Data(alternate.utf8)
            ) == canonical
        )
    }
}
