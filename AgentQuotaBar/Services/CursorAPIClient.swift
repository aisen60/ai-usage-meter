import Foundation

/// Cursor Dashboard API 客户端
/// 参考 cursor-usage (MIT) 实现: https://github.com/javaisbetterpython/cursor-usage
struct CursorAPIClient {

    /// 基础 URL
    private static let baseURL = "https://cursor.com"

    private static var userAgent: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
        return "AgentQuotaBar/\(version)"
    }

    /// 从 token 构造完整的 Cookie header 值
    /// Cookie 格式: WorkosCursorSessionToken=<sub>::<jwt>
    /// 其中 :: 需要 URL 编码为 %3A%3A
    static func buildCookieValue(fromToken token: String) -> String? {
        guard let sub = extractSubFromJWT(token) else { return nil }
        let raw = "\(sub)::\(token)"
        // 只编码 :: 分隔符，保留其他字符
        let encoded = raw.replacingOccurrences(
            of: "::", with: "%3A%3A"
        )
        return "WorkosCursorSessionToken=\(encoded)"
    }

    /// 从 JWT 中提取 sub claim
    private static func extractSubFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var payload = String(parts[1])

        // base64url → base64: 替换字符并补齐 padding
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let sub = json["sub"] as? String else { return nil }

        // sub 可能是 "auth0|xxx" 格式，取最后一段
        if let lastPart = sub.split(separator: "|").last {
            return String(lastPart)
        }
        return sub
    }

    /// 获取当前账期用量 (主要接口)
    /// - Parameter token: 原始 JWT accessToken
    static func fetchCurrentPeriodUsage(
        token: String
    ) async throws -> CursorUsage {
        guard let cookieValue = buildCookieValue(fromToken: token) else {
            throw CursorError.invalidToken
        }

        let url = URL(string: "\(baseURL)/api/dashboard/get-current-period-usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{}".data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CursorError.networkError
            }

            switch httpResponse.statusCode {
            case 200:
                guard let json = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any] else {
                    throw CursorError.decodingError
                }
                guard let usage = CursorUsage.from(json: json) else {
                    throw CursorError.decodingError
                }
                return usage
            case 401, 403:
                throw CursorError.unauthorized
            default:
                throw CursorError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch let error as CursorError {
            throw error
        } catch {
            throw CursorError.networkError
        }
    }

    /// 获取用户基本信息 (用于验证 token 有效性)
    static func fetchUserInfo(token: String) async throws -> [String: Any] {
        guard let cookieValue = buildCookieValue(fromToken: token) else {
            throw CursorError.invalidToken
        }

        let url = URL(string: "\(baseURL)/api/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CursorError.unauthorized
        }

        guard let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            throw CursorError.decodingError
        }
        return json
    }
}

/// Cursor 相关错误
enum CursorError: LocalizedError {
    case invalidToken
    case unauthorized
    case networkError
    case decodingError
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Token 格式无效"
        case .unauthorized:
            return "登录态已过期，请重新登录 Cursor"
        case .networkError:
            return "网络连接失败"
        case .decodingError:
            return "数据解析失败"
        case .httpError(let code):
            return "服务器错误 (\(code))"
        }
    }

    var logCategory: String {
        switch self {
        case .invalidToken: return "invalid-token"
        case .unauthorized: return "unauthorized"
        case .networkError: return "network"
        case .decodingError: return "decoding"
        case .httpError: return "http"
        }
    }
}
