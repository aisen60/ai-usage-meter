import AppKit
import Foundation

/// 通过本机 Codex CLI 的 app-server 协议读取当前登录账号的额度。
enum CodexIntegration {
    private static let requestID = 2
    private static let timeout: Duration = .seconds(10)

    enum IntegrationError: LocalizedError {
        case executableNotFound
        case launchFailed(String)
        case timedOut
        case protocolError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "未找到 Codex CLI"
            case .launchFailed(let message):
                return "无法启动 Codex：\(message)"
            case .timedOut:
                return "读取 Codex 用量超时"
            case .protocolError(let message):
                return "Codex 返回错误：\(message)"
            case .invalidResponse:
                return "Codex 返回了无法识别的用量数据"
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

    /// 自动读取当前 Codex 登录账号的周额度。
    static func fetchUsage() async throws -> CodexUsage {
        guard let executableURL = findExecutable() else {
            AppLog.codex.notice("Codex executable was not found")
            throw IntegrationError.executableNotFound
        }

        AppLog.codex.debug("Codex executable detected")

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
              let window = longestWindow(in: rateLimits),
              let usedPercent = number(window["usedPercent"]) else {
            throw IntegrationError.invalidResponse
        }

        let remaining = max(0, min(100, 100 - usedPercent))
        let resetDate = number(window["resetsAt"])
            .map { Date(timeIntervalSince1970: $0) }

        return CodexUsage(
            planName: displayPlanName(rateLimits["planType"] as? String),
            percentRemaining: remaining,
            cycleEndDate: resetDate,
            source: .automatic,
            fetchedAt: Date(),
            note: nil
        )
    }

    private static func longestWindow(in rateLimits: [String: Any]) -> [String: Any]? {
        let windows = ["primary", "secondary"]
            .compactMap { rateLimits[$0] as? [String: Any] }

        return windows.max { lhs, rhs in
            (number(lhs["windowDurationMins"]) ?? 0)
                < (number(rhs["windowDurationMins"]) ?? 0)
        }
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
        return suffix.map { "Codex \($0)" } ?? "Codex"
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
                    "name": "agent-quota-bar",
                    "title": "Agent Quota Bar",
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
