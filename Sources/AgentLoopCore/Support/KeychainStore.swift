import Foundation
import LocalAuthentication
import Security

public enum KeychainInteractionPolicy: Sendable, Equatable {
    case allow
    case failIfInteractionRequired
}

public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String = "com.muzi.agentloop") {
        self.service = service
    }

    public func set(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    public func get(account: String) throws -> String? {
        try get(account: account, interactionPolicy: .allow)
    }

    public func get(account: String, interactionPolicy: KeychainInteractionPolicy) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if interactionPolicy == .failIfInteractionRequired {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError(status: status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

public struct KeychainError: Error, Sendable {
    public let status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) {
            return message as String
        }
        return "钥匙串错误（状态码 \(status)）"
    }
}

extension KeychainStore: CredentialStore {}
