import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier
        ?? "com.agentquotabar.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let cursor = Logger(subsystem: subsystem, category: "cursor")
    static let codex = Logger(subsystem: subsystem, category: "codex")
}
