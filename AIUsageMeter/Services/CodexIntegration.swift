import AppKit
import Foundation

/// 通过本机 codex CLI 的 app-server 协议读取当前 ChatGPT 登录账号的额度。
enum CodexIntegration {
    private static let requestID = 2
    private static let timeout: Duration = .seconds(10)

    /// 5 小时窗口的典型时长（分钟）
    private static let shortWindowMins: Double = 300

    /// 1 周窗口的典型时长（分钟）
    private static let weeklyWindowMins: Double = 10_080

    /// 额度窗口分类。依赖窗口时长而非 `primary` / `secondary` 字段顺序。
    private enum QuotaWindowKind {
        case short
        case weekly
    }

    enum IntegrationError: LocalizedError {
        case executableNotFound
        case launchFailed(String)
        case timedOut
        case protocolError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "未找到 ChatGPT CLI"
            case .launchFailed(let message):
                return "无法启动 ChatGPT：\(message)"
            case .timedOut:
                return "读取 ChatGPT 用量超时"
            case .protocolError(let message):
                return "ChatGPT 返回错误：\(message)"
            case .invalidResponse:
                return "ChatGPT 返回了无法识别的用量数据"
            }
        }

        var logCategory: String {
            switch self {
            case .executableNotFound: return "executable-not-found"
            case .launchFailed: return "launch"
            case .timedOut: return "timeout"
            case .protocolError: return "protocol"
            case .invalidResponse: return "invalid-response"
            }
        }
    }

    /// 自动读取当前 ChatGPT 登录账号的额度（5 小时与 1 周）。
    static func fetchUsage() async throws -> CodexUsage {
        guard let executableURL = findExecutable() else {
            AppLog.codex.notice("ChatGPT executable was not found")
            throw IntegrationError.executableNotFound
        }

        AppLog.codex.debug("ChatGPT executable detected")

        return try await fetchUsage(
            executableURL: executableURL,
            requestTimeout: timeout
        )
    }

    static func fetchUsage(
        executableURL: URL,
        requestTimeout: Duration
    ) async throws -> CodexUsage {

        let session = AppServerSession(executableURL: executableURL)

        return try await withThrowingTaskGroup(of: CodexUsage.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try await session.readUsage()
                } onCancel: {
                    session.cancel()
                }
            }

            group.addTask {
                try await Task.sleep(for: requestTimeout)
                throw IntegrationError.timedOut
            }

            defer {
                group.cancelAll()
                session.cancel()
            }

            guard let result = try await group.next() else {
                throw IntegrationError.invalidResponse
            }
            return result
        }
    }

    /// 优先从已安装的 Codex/ChatGPT 应用定位，其次检查常见 CLI 路径和 PATH。
    private static func findExecutable() -> URL? {
        var candidates: [URL] = []

        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.openai.codex"
        ) {
            candidates.append(
                appURL.appendingPathComponent("Contents/Resources/codex")
            )
        }

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex")
        ])

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path
                .split(separator: ":")
                .map { URL(fileURLWithPath: String($0)).appendingPathComponent("codex") })
        }

        var seen = Set<String>()
        return candidates.first { url in
            seen.insert(url.path).inserted
                && FileManager.default.isExecutableFile(atPath: url.path)
        }
    }

    static func parseResponse(_ object: [String: Any]) throws -> CodexUsage {
        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "未知协议错误"
            throw IntegrationError.protocolError(message)
        }

        guard requestIdentifier(object["id"]) == requestID,
              let result = object["result"] as? [String: Any] else {
            throw IntegrationError.invalidResponse
        }

        let buckets = result["rateLimitsByLimitId"] as? [String: Any]
        let rateLimits = (buckets?["codex"] as? [String: Any])
            ?? (result["rateLimits"] as? [String: Any])

        guard let rateLimits,
              let primary = rateLimits["primary"] as? [String: Any],
              let secondary = rateLimits["secondary"] as? [String: Any] else {
            throw IntegrationError.invalidResponse
        }

        // 按时长分类到两个窗口，不依赖 primary / secondary 的字段顺序。
        var short: [String: Any]?
        var weekly: [String: Any]?
        for window in [primary, secondary] {
            guard let duration = number(window["windowDurationMins"]),
                  let kind = windowKind(durationMins: duration) else {
                throw IntegrationError.invalidResponse
            }
            switch kind {
            case .short where short == nil:
                short = window
            case .weekly where weekly == nil:
                weekly = window
            default:
                // 未知窗口时长或两个窗口重复归类为同一周期。
                throw IntegrationError.invalidResponse
            }
        }

        guard let short, let weekly else {
            throw IntegrationError.invalidResponse
        }

        return CodexUsage(
            planName: displayPlanName(rateLimits["planType"] as? String),
            shortWindow: try parseWindow(short),
            weeklyWindow: try parseWindow(weekly),
            source: .automatic,
            fetchedAt: Date(),
            note: nil
        )
    }

    private static func parseWindow(_ window: [String: Any]) throws -> QuotaWindow {
        guard let usedPercent = number(window["usedPercent"]) else {
            throw IntegrationError.invalidResponse
        }
        let remaining = max(0, min(100, 100 - usedPercent))
        let resetsAt = number(window["resetsAt"])
            .map { Date(timeIntervalSince1970: $0) }
        return QuotaWindow(percentRemaining: remaining, resetsAt: resetsAt)
    }

    /// 按窗口时长归类：约 300 分钟为 5 小时，约 10080 分钟为 1 周。
    /// 时长未知或为非有限正数时返回 nil。
    private static func windowKind(durationMins: Double) -> QuotaWindowKind? {
        guard durationMins.isFinite, durationMins > 0 else { return nil }
        let shortError = abs(durationMins - shortWindowMins) / shortWindowMins
        let weeklyError = abs(durationMins - weeklyWindowMins) / weeklyWindowMins
        if shortError <= 0.5 { return .short }
        if weeklyError <= 0.5 { return .weekly }
        return nil
    }

    private static func displayPlanName(_ planType: String?) -> String {
        let suffix: String?
        switch planType?.lowercased() {
        case "free": suffix = "Free"
        case "go": suffix = "Go"
        case "plus": suffix = "Plus"
        case "pro": suffix = "Pro"
        case "prolite": suffix = "Pro Lite"
        case "team": suffix = "Team"
        case "self_serve_business_usage_based", "business": suffix = "Business"
        case "enterprise_cbp_usage_based", "enterprise": suffix = "Enterprise"
        case "edu": suffix = "Edu"
        default: suffix = nil
        }
        return suffix.map { "ChatGPT \($0)" } ?? "ChatGPT"
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    fileprivate static func requestIdentifier(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

/// 每次刷新只创建一个短生命周期 app-server，读取完成后立即退出。
private final class AppServerSession: @unchecked Sendable {
    private let executableURL: URL
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let lock = NSLock()
    private var cancelled = false

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    func readUsage() async throws -> CodexUsage {
        process.executableURL = executableURL
        process.arguments = ["app-server"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 持续清空 stderr，避免警告输出填满管道后阻塞子进程。
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
        } catch {
            throw CodexIntegration.IntegrationError.launchFailed(error.localizedDescription)
        }

        let shouldCancel = lock.withLock { cancelled }
        if shouldCancel {
            cancel()
            throw CancellationError()
        }

        do {
            try send(initializeRequest)
            var initialized = false

            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any],
                      let identifier = CodexIntegration.requestIdentifier(object["id"]) else {
                    continue
                }

                if let error = object["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "未知协议错误"
                    throw CodexIntegration.IntegrationError.protocolError(message)
                }

                if identifier == 1, !initialized {
                    initialized = true
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": "account/rateLimits/read"])
                } else if identifier == 2, initialized {
                    return try CodexIntegration.parseResponse(object)
                }
            }

            throw CodexIntegration.IntegrationError.invalidResponse
        } catch {
            cancel()
            throw error
        }
    }

    func cancel() {
        let isRunning = lock.withLock {
            cancelled = true
            return process.isRunning
        }

        errorPipe.fileHandleForReading.readabilityHandler = nil
        try? inputPipe.fileHandleForWriting.close()
        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()

        if isRunning {
            process.terminate()
        }
    }

    private var initializeRequest: [String: Any] {
        [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "ai-usage-meter",
                    "title": "AI Usage Meter",
                    "version": appVersion
                ],
                "capabilities": ["experimentalApi": true]
            ]
        ]
    }

    private func send(_ request: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: request)
        data.append(0x0A)
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.0.0"
    }
}
