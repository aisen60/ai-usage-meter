import Foundation
import Security

/// Keychain 封装 - 用于安全保存用户手动输入的 token
enum TokenKeychain {

    private static let service = "com.aisen.aiusagemeter"

    /// 保存 token 到 Keychain
    /// - Parameters:
    ///   - token: 要保存的 token
    ///   - account: 账户标识 (如 "cursor-token")
    /// - Returns: 是否成功
    @discardableResult
    static func save(token: String, account: String) -> Bool {
        let data = Data(token.utf8)

        // 先删除旧条目
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 从 Keychain 读取 token
    /// - Parameter account: 账户标识
    /// - Returns: token，如果未找到则返回 nil
    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// 删除 Keychain 中的 token
    /// - Parameter account: 账户标识
    /// - Returns: 是否成功
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
