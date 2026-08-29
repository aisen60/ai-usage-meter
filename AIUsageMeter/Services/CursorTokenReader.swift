import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 从 Cursor 本地存储中读取 session token
enum CursorTokenReader {

    /// Cursor 本地 state 数据库路径
    static let stateDBPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("Cursor")
        .appendingPathComponent("User")
        .appendingPathComponent("globalStorage")
        .appendingPathComponent("state.vscdb")
        .path

    /// 尝试从 Cursor 本地数据库读取 accessToken
    /// - Returns: 原始 JWT token，如果未找到则返回 nil
    static func readAccessToken() -> String? {
        readValue(forKey: "cursorAuth/accessToken")
    }

    /// Cursor 客户端会把服务端同步后的会员类型缓存到本地数据库。
    static func readPlanName() -> String {
        guard let membershipType = readValue(
            forKey: "cursorAuth/stripeMembershipType"
        )?.lowercased() else {
            return "Cursor"
        }

        return displayPlanName(for: membershipType)
    }

    static func displayPlanName(for membershipType: String) -> String {
        switch membershipType.lowercased() {
        case "free", "hobby":
            return "Cursor Hobby"
        case "free_trial", "trial":
            return "Cursor Trial"
        case "pro":
            return "Cursor Pro"
        case "pro_plus", "proplus", "pro+":
            return "Cursor Pro+"
        case "ultra":
            return "Cursor Ultra"
        case "team", "teams":
            return "Cursor Teams"
        case "business":
            return "Cursor Business"
        case "enterprise":
            return "Cursor Enterprise"
        default:
            return "Cursor"
        }
    }

    /// 检查 Cursor 是否已安装
    static var isCursorInstalled: Bool {
        isCursorInstalled(applicationURLs: cursorApplicationURLs)
    }

    static func isCursorInstalled(applicationURLs: [URL]) -> Bool {
        applicationURLs.contains { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    /// Cursor 通常安装在系统或当前用户的 Applications 目录。
    /// 不使用状态数据库作为安装依据，因为卸载后它可能继续残留。
    private static var cursorApplicationURLs: [URL] {
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Cursor.app", isDirectory: true)
        return [
            URL(fileURLWithPath: "/Applications/Cursor.app", isDirectory: true),
            homeApplications,
        ]
    }

    /// 只读查询单个 Cursor 状态值，使用绑定参数避免拼接 SQL。
    private static func readValue(forKey key: String) -> String? {
        guard FileManager.default.fileExists(atPath: stateDBPath) else {
            return nil
        }

        let uri = "file:\(stateDBPath)?mode=ro"
        var db: OpaquePointer?

        guard sqlite3_open_v2(
            uri,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_URI,
            nil
        ) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT value FROM ItemTable WHERE key = ? LIMIT 1",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_bind_text(statement, 1, key, -1, sqliteTransient) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let valueCString = sqlite3_column_text(statement, 0) else {
            return nil
        }

        return String(cString: valueCString)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }
}
