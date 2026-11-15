import Foundation
import Security
import SiftCore

struct LocalStore {
    let url: URL
    init() throws {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Sift", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        url = directory.appendingPathComponent("mailbox-v1.json")
    }
    func load() throws -> MailCache {
        guard FileManager.default.fileExists(atPath: url.path) else { return MailCache() }
        let cache = try JSONDecoder().decode(MailCache.self, from: Data(contentsOf: url))
        guard cache.version == 1 else { throw SiftError.message("Bu veri sürümü desteklenmiyor. Uygulamayı güncelle.") }
        return cache
    }
    func save(_ cache: MailCache) throws {
        try JSONEncoder().encode(cache).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum SiftError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { text } else { nil } }
}

struct TokenSet: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

struct KeychainStore: Sendable {
    private let service = "com.siftmail.app.microsoft"
    func save(_ token: TokenSet, account: String) throws {
        let data = try JSONEncoder().encode(token)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            try check(SecItemAdd(item as CFDictionary, nil))
        } else { try check(status) }
    }
    func load(account: String) throws -> TokenSet {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        try check(SecItemCopyMatching(query as CFDictionary, &result))
        guard let data = result as? Data else { throw SiftError.message("Hesabını yeniden bağla.") }
        return try JSONDecoder().decode(TokenSet.self, from: data)
    }
    func delete(account: String) throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw SiftError.message("Anahtar Zinciri erişimi başarısız (\(status)). Hesabını yeniden bağla veya macOS izinlerini kontrol et.") }
    }
}
