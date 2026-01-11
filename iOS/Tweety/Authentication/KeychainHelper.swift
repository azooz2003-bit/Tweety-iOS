//
//  KeychainHelper.swift
//  Authentication
//

import Foundation
import Security

nonisolated
final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service: String

    private init(service: String = Bundle.main.bundleIdentifier ?? "com.tweety.app") {
        self.service = service
    }

    // MARK: - Save

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try save(data, for: key)
    }

    func save(_ data: Data, for key: String) throws {
        // Delete existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func save(_ date: Date, for key: String) throws {
        let data = try JSONEncoder().encode(date)
        try save(data, for: key)
    }

    // MARK: - Retrieve

    func getString(for key: String) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func getDate(for key: String) -> Date? {
        guard let data = getData(for: key) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: data)
    }

    // MARK: - Delete

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: Error {
    case invalidData
    case saveFailed(OSStatus)
    case notFound
}
