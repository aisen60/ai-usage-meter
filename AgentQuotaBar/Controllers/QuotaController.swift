import Foundation
import SwiftUI

/// 主控制器 - 管理所有配额数据和刷新逻辑
@MainActor
final class QuotaController: ObservableObject {

    // MARK: - Published State

    /// Cursor 用量数据
    @Published var cursorUsage: CursorUsage?

    /// Codex 用量数据
    @Published var codexUsage: CodexUsage = .disconnected

    /// 是否正在刷新
    @Published var isRefreshing = false

    /// 上次刷新时间
    @Published var lastRefreshTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否显示错误
    @Published var showError = false

    /// Cursor 连接状态
    @Published var cursorConnectionState: ConnectionState = .unknown

    /// Codex 连接状态
    @Published var codexConnectionState: ConnectionState = .unknown

    // MARK: - Properties

    /// 刷新间隔 (默认 15 分钟)
    var refreshInterval: TimeInterval = 15 * 60

    /// 定时刷新任务
    private var refreshTask: Task<Void, Never>?

    /// Token 来源
    private let tokenAccount = "cursor-token"

    // MARK: - Types

    enum ConnectionState {
        case unknown
        case connected
        case disconnected
        case error(String)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    // MARK: - Lifecycle

    init() {
        // 启动时加载缓存
        loadCache()
    }

    // 注意: @MainActor 类的 deinit 不能调用 actor 隔离方法
    // 定时器 Task 会在进程退出时由系统自动清理

    // MARK: - Public Methods

    /// 启动应用时调用 - 加载缓存并执行首次刷新
    func start() {
        loadCache()
        Task {
            await refresh()
        }
        startAutoRefresh()
    }

    /// 手动刷新
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        showError = false

        // 并行获取 Cursor 和 Codex
        async let cursorTask = refreshCursor()
        async let codexTask = refreshCodex()
        _ = await (cursorTask, codexTask)

        isRefreshing = false
        lastRefreshTime = Date()

        // 保存缓存
        saveCache()
    }

    /// 保存手动输入的 Cursor token
    func saveManualToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 保存到 Keychain
        if TokenKeychain.save(token: trimmed, account: tokenAccount) {
            // 立即刷新
            Task {
                await refresh()
            }
        }
    }

    /// 获取当前的 Cursor token (优先 Keychain，其次本地数据库)
    func resolveCursorToken() -> String? {
        // 1. 优先读取 Keychain (用户手动保存的)
        if let token = TokenKeychain.read(account: tokenAccount) {
            return token
        }
        // 2. 尝试读取 Cursor 本地数据库
        if let token = CursorTokenReader.readAccessToken() {
            return token
        }
        return nil
    }

    /// 保存手动录入的 Codex 数据
    func saveManualCodexUsage(
        planName: String,
        percentRemaining: Double,
        cycleEndDate: Date?,
        note: String?
    ) {
        codexUsage = CodexUsage(
            planName: planName,
            percentRemaining: max(0, min(100, percentRemaining)),
            cycleEndDate: cycleEndDate,
            source: .manual,
            fetchedAt: Date(),
            note: note
        )
        saveCache()
    }

    // MARK: - Private Methods

    private func refreshCursor() async {
        guard let token = resolveCursorToken() else {
            cursorConnectionState = .disconnected
            // 如果没有 token 但有缓存，保持缓存状态
            if cursorUsage != nil {
                cursorConnectionState = .connected
            }
            return
        }

        do {
            let usage = try await CursorAPIClient.fetchCurrentPeriodUsage(token: token)
            cursorUsage = usage
            cursorConnectionState = .connected
        } catch {
            // 失败时保持缓存数据
            if cursorUsage != nil {
                cursorConnectionState = .error("已显示缓存数据")
            } else {
                cursorConnectionState = .error(error.localizedDescription)
            }
            handleError(error)
        }
    }

    private func refreshCodex() async {
        if let usage = await CodexIntegration.fetchUsage() {
            codexUsage = usage
            codexConnectionState = .connected
        } else if codexUsage.isConnected {
            // 保持手动录入的数据
            codexConnectionState = .connected
        } else {
            codexConnectionState = .disconnected
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                // 等待刷新间隔
                try? await Task.sleep(
                    for: .seconds(self.refreshInterval)
                )
                if !Task.isCancelled {
                    await self.refresh()
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Cache

    private func loadCache() {
        let (cursor, codex) = UsageCache.load()
        if let cursor { cursorUsage = cursor }
        if let codex { codexUsage = codex }
    }

    private func saveCache() {
        UsageCache.save(cursor: cursorUsage, codex: codexUsage)
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
