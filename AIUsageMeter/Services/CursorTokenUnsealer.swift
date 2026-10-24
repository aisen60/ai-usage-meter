import Foundation
import Security
import CommonCrypto

/// 解封 Cursor 本地落盘的 accessToken。
///
/// Cursor 3.27 起会把 `cursorAuth/accessToken` 以 Electron safeStorage
/// （Chromium OSCrypt）密文写入本地状态库，格式为
/// `cursor-safe-storage:v1:<base64("v10" + AES-128-CBC 密文)>`。
/// 密钥由钥匙串 `Cursor Safe Storage` 口令经 PBKDF2-HMAC-SHA1
///（盐 `saltysalt`、1003 轮）派生，IV 为 16 个空格。
///
/// 口令与明文 token 只在内存中短暂存在：不落盘、不写日志、不进测试夹具。
enum CursorTokenUnsealer {

    /// 密文存值前缀
    static let sealedPrefix = "cursor-safe-storage:v1:"

    private static let keychainService = "Cursor Safe Storage"
    private static let keychainAccount = "Cursor"
    private static let envelopeMagic = Data("v10".utf8)
    private static let salt = Array("saltysalt".utf8)
    private static let pbkdf2Rounds: UInt32 = 1003

    /// 还原本地存值为可用 token；非密文原样返回，解封失败返回 nil。
    static func unseal(storedValue: String) -> String? {
        unseal(storedValue: storedValue, keychainPassword: readKeychainPassword)
    }

    /// 供测试注入钥匙串口令的解封入口。
    static func unseal(
        storedValue: String,
        keychainPassword: () -> Data?
    ) -> String? {
        guard storedValue.hasPrefix(sealedPrefix) else { return storedValue }

        let encoded = String(storedValue.dropFirst(sealedPrefix.count))
        guard let envelope = Data(base64Encoded: encoded),
              let password = keychainPassword(),
              let key = deriveKey(password: password),
              let plaintext = decrypt(envelope: envelope, key: key),
              let token = String(data: plaintext, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    /// Chromium OSCrypt 派生规则：PBKDF2-HMAC-SHA1(password, "saltysalt", 1003) → 16 字节。
    static func deriveKey(password: Data) -> Data? {
        guard !password.isEmpty else { return nil }

        var key = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let status = password.withUnsafeBytes { passwordBytes -> Int32 in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                password.count,
                salt,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                pbkdf2Rounds,
                &key,
                key.count
            )
        }
        guard status == kCCSuccess else { return nil }
        return Data(key)
    }

    /// 解开 `v10 + AES-128-CBC(PKCS7)` 信封，IV 为 16 个空格。
    static func decrypt(envelope: Data, key: Data) -> Data? {
        guard envelope.count > envelopeMagic.count,
              envelope.prefix(envelopeMagic.count) == envelopeMagic,
              key.count == kCCKeySizeAES128 else {
            return nil
        }

        let ciphertext = envelope.dropFirst(envelopeMagic.count)
        let iv = [UInt8](repeating: UInt8(ascii: " "), count: kCCBlockSizeAES128)
        var plaintext = Data(count: ciphertext.count + kCCBlockSizeAES128)
        var plaintextCount = 0

        let status = plaintext.withUnsafeMutableBytes { plaintextBytes -> Int32 in
            ciphertext.withUnsafeBytes { ciphertextBytes -> Int32 in
                key.withUnsafeBytes { keyBytes -> Int32 in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress,
                        key.count,
                        iv,
                        ciphertextBytes.baseAddress,
                        ciphertext.count,
                        plaintextBytes.baseAddress,
                        plaintextBytes.count,
                        &plaintextCount
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(plaintext.prefix(plaintextCount))
    }

    /// 只读取 Cursor safeStorage 的钥匙串口令。
    /// 读取被拒或条目缺失时返回 nil，由调用方降级为凭据缺失状态。
    private static func readKeychainPassword() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let password = result as? Data,
              !password.isEmpty else {
            return nil
        }
        return password
    }
}
