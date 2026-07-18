import Foundation

/// JSON 文件本地缓存
enum UsageCache {

    /// 缓存文件 URL
    private static var cacheFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("AgentQuotaBar")
        return dir.appendingPathComponent("usage-cache.json")
    }

    /// 确保目录存在
    private static func ensureDirectory() {
        let dir = cacheFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    /// 保存缓存
    static func save(cursor: CursorUsage?, codex: CodexUsage?) {
        ensureDirectory()

        var dict: [String: Any] = [:]

        if let cursor {
            dict["cursor"] = try? JSONSerialization.jsonObject(
                with: JSONEncoder().encode(cursor)
            )
            dict["cursorSavedAt"] = ISO8601DateFormatter().string(from: Date())
        }

        if let codex {
            dict["codex"] = try? JSONSerialization.jsonObject(
                with: JSONEncoder().encode(codex)
            )
            dict["codexSavedAt"] = ISO8601DateFormatter().string(from: Date())
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: dict, options: .prettyPrinted
        ) else { return }

        try? data.write(to: cacheFileURL)
    }

    /// 读取缓存
    static func load() -> (cursor: CursorUsage?, codex: CodexUsage?) {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let dict = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            return (nil, nil)
        }

        let cursor: CursorUsage?
        if let cursorDict = dict["cursor"] as? [String: Any],
           let cursorData = try? JSONSerialization.data(withJSONObject: cursorDict),
           let usage = try? JSONDecoder().decode(CursorUsage.self, from: cursorData) {
            cursor = usage
        } else {
            cursor = nil
        }

        let codex: CodexUsage?
        if let codexDict = dict["codex"] as? [String: Any],
           let codexData = try? JSONSerialization.data(withJSONObject: codexDict),
           let usage = try? JSONDecoder().decode(CodexUsage.self, from: codexData) {
            codex = usage
        } else {
            codex = nil
        }

        return (cursor, codex)
    }

    /// 清除缓存
    static func clear() {
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}
