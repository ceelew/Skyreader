import Foundation
import Security

/// Minimal wrapper over Security.framework for storing small secrets (tokens, app password).
enum KeychainStore {
    private static let service = "com.coreylewis.BlueskyReader"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(baseQuery(for: key) as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }

    static func get(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    static func deleteAll() {
        for key in Key.allCases { delete(key.rawValue) }
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    enum Key: String, CaseIterable {
        case accessJwt
        case refreshJwt
        case did
        case handle
        case appPassword
    }
}
