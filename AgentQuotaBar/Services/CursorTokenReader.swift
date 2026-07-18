import Foundation
import SQLite3

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
        let path = stateDBPath

        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        // 使用只读模式打开，避免锁定数据库
        let uri = "file:\(path)?mode=ro"
        var db: OpaquePointer?

        guard sqlite3_open_v2(
            uri, &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        ) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_close(db) }

        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        guard let valueCString = sqlite3_column_text(stmt, 0) else {
            return nil
        }

        let value = String(cString: valueCString)

        // 数据库中可能存储了引号，去除
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }

    /// 检查 Cursor 是否已安装
    static var isCursorInstalled: Bool {
        FileManager.default.fileExists(atPath: stateDBPath)
    }
}
