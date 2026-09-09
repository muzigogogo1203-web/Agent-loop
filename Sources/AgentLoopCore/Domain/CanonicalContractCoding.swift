import Foundation

package enum P1ContractValidationError: Error, Sendable, Equatable {
    case invalidKeys
    case invalidSchemaVersion
    case invalidIdentifier
    case invalidCampIdentifier
    case invalidHash
    case invalidInteger
    case invalidTime
    case invalidCode
    case invalidValue
    case duplicateKind
    case invalidMembership
    case overflow
}

package enum CanonicalContractCodingV1 {
    package static func encode<T: Encodable>(_ value: T) throws -> Data {
        try CanonicalJSONV1.encode(value)
    }

    package static func string<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encode(value), as: UTF8.self)
    }

    package static func hash<T: Encodable>(_ value: T) throws -> String {
        CanonicalJSONV1.sha256Hex(try encode(value))
    }

    package static func wholeCommandBytes<Payload: Encodable>(
        envelope: CommandEnvelopeV1,
        payload: Payload
    ) throws -> Data {
        try CanonicalJSONV1.encode(
            WholeCommand(envelope: envelope, payload: payload)
        )
    }

    package static func wholeCommandHash<Payload: Encodable>(
        envelope: CommandEnvelopeV1,
        payload: Payload
    ) throws -> String {
        CanonicalJSONV1.sha256Hex(
            try wholeCommandBytes(envelope: envelope, payload: payload)
        )
    }

    package static func decode<T: Codable>(
        _ type: T.Type,
        from bytes: Data
    ) throws -> T {
        try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .millisecondsSince1970
        decoder.dataDecodingStrategy = .base64
        decoder.nonConformingFloatDecodingStrategy = .throw
        let value = try decoder.decode(type, from: bytes)
        guard try CanonicalJSONV1.encode(value) == bytes else {
            throw CanonicalJSONNotCanonicalError()
        }
        return value
    }

    package static func validateCanonicalUUID(_ value: String) throws {
        guard let uuid = UUID(uuidString: value), uuid.uuidString == value else {
            throw P1ContractValidationError.invalidIdentifier
        }
    }

    package static func validateCampID(_ value: String) throws {
        try validateNonempty(value, campIdentity: true)
    }

    package static func validateNonempty(
        _ value: String,
        campIdentity: Bool = false
    ) throws {
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw campIdentity
                ? P1ContractValidationError.invalidCampIdentifier
                : P1ContractValidationError.invalidValue
        }
    }

    package static func validateOptionalNonempty(_ value: String?) throws {
        if let value {
            try validateNonempty(value)
        }
    }

    /// Narrative content keeps its exact formatting; identities use validateNonempty.
    package static func validateNarrativeText(_ value: String) throws {
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.unicodeScalars.contains(where: { scalar in
                  CharacterSet.controlCharacters.contains(scalar)
                      && scalar.value != 0x09 // TAB
                      && scalar.value != 0x0A // LF
                      && scalar.value != 0x0D // CR
              })
        else {
            throw P1ContractValidationError.invalidValue
        }
    }

    package static func validateLowercaseHash(_ value: String) throws {
        guard value.utf8.count == 64,
              value.utf8.allSatisfy({ byte in
                  (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)
              })
        else {
            throw P1ContractValidationError.invalidHash
        }
    }

    package static func validateNonnegative(_ value: Int) throws {
        guard value >= 0 else {
            throw P1ContractValidationError.invalidInteger
        }
    }

    package static func validatePositive(_ value: Int) throws {
        guard value > 0 else {
            throw P1ContractValidationError.invalidInteger
        }
    }

    package static func checkedIncrement(_ value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(1)
        guard !overflow else {
            throw P1ContractValidationError.overflow
        }
        return result
    }

    package static func validateFinite(_ value: Date) throws {
        guard value.timeIntervalSince1970.isFinite else {
            throw P1ContractValidationError.invalidTime
        }
    }

    package static func validateFiniteInterval(_ value: TimeInterval) throws {
        guard value.isFinite else {
            throw P1ContractValidationError.invalidTime
        }
    }

    package static func validateCode(_ value: String) throws {
        try validateNonempty(value)
        guard value.utf8.count <= 128 else {
            throw P1ContractValidationError.invalidCode
        }
    }
}

private struct WholeCommand<Payload: Encodable>: Encodable {
    let envelope: CommandEnvelopeV1
    let payload: Payload
}
