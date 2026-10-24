import XCTest
@testable import AIUsageMeter

/// Cursor token 解封与 Cookie 构造测试。
/// 夹具由独立实现生成（Python hashlib + OpenSSL），不使用被测代码自证：
/// - PBKDF2-HMAC-SHA1("peanuts", "saltysalt", 1003, 16)
///   = d9a09d499b4e1b7461f28e67972c6dbd
/// - 密文信封以口令 "unit-test-password" 加密明文 "unit-test-token-value" 生成。
final class CursorTokenTests: XCTestCase {

    private let fixtureStoredValue =
        "cursor-safe-storage:v1:djEwNrmYduGxbo6XVQFqij7a9V+QnKgx5VLX43XHITTLl+o="
    private let fixturePassword = Data("unit-test-password".utf8)

    // MARK: - safeStorage 解封

    func testDeriveKeyMatchesChromiumOSCryptVector() {
        let key = CursorTokenUnsealer.deriveKey(password: Data("peanuts".utf8))
        let hex = key?.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "d9a09d499b4e1b7461f28e67972c6dbd")
    }

    func testUnsealsSafeStorageEnvelope() {
        let token = CursorTokenUnsealer.unseal(
            storedValue: fixtureStoredValue,
            keychainPassword: { [fixturePassword] in fixturePassword }
        )
        XCTAssertEqual(token, "unit-test-token-value")
    }

    func testUnsealPassesThroughPlainValue() {
        let token = CursorTokenUnsealer.unseal(
            storedValue: "plain-token-value",
            keychainPassword: { nil }
        )
        XCTAssertEqual(token, "plain-token-value")
    }

    func testUnsealFailsWithoutKeychainPassword() {
        let token = CursorTokenUnsealer.unseal(
            storedValue: fixtureStoredValue,
            keychainPassword: { nil }
        )
        XCTAssertNil(token)
    }

    func testUnsealRejectsWrongKeychainPassword() {
        let token = CursorTokenUnsealer.unseal(
            storedValue: fixtureStoredValue,
            keychainPassword: { Data("wrong-password".utf8) }
        )
        XCTAssertNil(token)
    }

    func testUnsealRejectsCorruptEnvelope() {
        XCTAssertNil(CursorTokenUnsealer.unseal(
            storedValue: "cursor-safe-storage:v1:not-base64!!!",
            keychainPassword: { [fixturePassword] in fixturePassword }
        ))

        // 缺少 v10 魔数的信封
        let noMagic = "cursor-safe-storage:v1:"
            + Data("plain-text-envelope".utf8).base64EncodedString()
        XCTAssertNil(CursorTokenUnsealer.unseal(
            storedValue: noMagic,
            keychainPassword: { [fixturePassword] in fixturePassword }
        ))
    }

    // MARK: - Cookie 构造

    func testBuildCookieValueFromJWT() throws {
        let jwt = try makeJWT(sub: "auth0|user123")
        XCTAssertEqual(
            CursorAPIClient.buildCookieValue(fromToken: jwt),
            "WorkosCursorSessionToken=user123%3A%3A\(jwt)"
        )
    }

    func testBuildCookieValueAcceptsPrefilledSessionValue() {
        XCTAssertEqual(
            CursorAPIClient.buildCookieValue(fromToken: "user123::opaque-session"),
            "WorkosCursorSessionToken=user123%3A%3Aopaque-session"
        )
    }

    func testBuildCookieValueRejectsNonJWTValue() {
        XCTAssertNil(CursorAPIClient.buildCookieValue(fromToken: "not-a-jwt"))
    }

    // MARK: - Helpers

    private func makeJWT(sub: String) throws -> String {
        func base64URL(_ object: [String: Any]) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: object)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = try base64URL(["alg": "RS256", "typ": "JWT"])
        let payload = try base64URL(["sub": sub, "exp": 4_102_444_800])
        return "\(header).\(payload).signature"
    }
}
