// KeychainHelper — Secure password storage using macOS Keychain Services

import Foundation
import Security

enum KeychainHelper {
    static let serviceIdentifier = "com.shadowsocks.macos"

    // MARK: - Save

    /// Save a password to Keychain for a given server ID
    static func save(password: String, for serverID: UUID) throws {
        let key = serverID.uuidString
        let data = password.data(using: .utf8)!

        // Delete existing entry first (Keychain doesn't support in-place update)
        delete(for: serverID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.saveFailed(status: status)
        }
    }

    // MARK: - Load

    /// Load a password from Keychain for a given server ID
    static func load(for serverID: UUID) -> String? {
        let key = serverID.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    /// Delete a password from Keychain for a given server ID
    static func delete(for serverID: UUID) {
        let key = serverID.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Delete All

    /// Delete all stored passwords (for cleanup)
    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed (OSStatus: \(status))"
        case .loadFailed(let status):
            return "Keychain load failed (OSStatus: \(status))"
        }
    }
}
