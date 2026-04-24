import Foundation
import Security

/// Persists access/refresh tokens in Keychain and refreshes them on demand.
actor TokenStore {
    static let shared = TokenStore()

    private let accessKey  = "mobile.access"
    private let refreshKey = "mobile.refresh"

    // Cached in-memory copies for hot-path access from APIClient.
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    init() {
        self.accessToken  = Keychain.load(key: accessKey)
        self.refreshToken = Keychain.load(key: refreshKey)
    }

    func save(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        Keychain.save(key: accessKey, value: access)
        Keychain.save(key: refreshKey, value: refresh)
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        Keychain.delete(key: accessKey)
        Keychain.delete(key: refreshKey)
    }

    /// Call the /auth/refresh endpoint to rotate tokens. No-op if no refresh token.
    func refreshIfPossible() async throws {
        guard let rt = refreshToken else { return }
        struct Body: Encodable { let refreshToken: String }
        struct Resp: Decodable { let accessToken: String; let refreshToken: String }
        let ep = Endpoint(path: "auth/refresh", method: .POST, body: Body(refreshToken: rt))
        let resp: Resp = try await APIClient.shared.send(ep)
        save(access: resp.accessToken, refresh: resp.refreshToken)
    }
}

// MARK: - Tiny Keychain helper

enum Keychain {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }
}
