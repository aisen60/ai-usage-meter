import Foundation
import SwiftUI

/// 主控制器 - 管理所有配额数据和刷新逻辑
@MainActor
final class QuotaController: ObservableObject {

    // MARK: - Published State

    /// Cursor 用量数据
    @Published var cursorUsage: CursorUsage?

    /// 从 Cursor 桌面客户端本地状态动态读取的套餐名称
    @Published var cursorPlanName = "Cursor"

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

    /// 菜单栏显示项目设置（变更即持久化到 UserDefaults）
    @Published var displaySettings: MenuBarDisplaySettings

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
        case stale
        case disconnected
        case error(String)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        /// 当前是否有可展示的数据。Cursor 缓存可在降级状态继续展示，
        /// Codex 失败时不会进入 stale，因此不会误用旧额度。
        var canDisplayUsage: Bool {
            switch self {
            case .connected, .stale:
                return true
            case .unknown, .disconnected, .error:
                return false
            }
        }
    }

    // MARK: - Lifecycle

    init(autoStart: Bool = true) {
        displaySettings = MenuBarDisplaySettings.load()
        if autoStart {
            start()
        }
    }

    // 注意: @MainActor 类的 deinit 不能调用 actor 隔离方法
    // 定时器 Task 会在进程退出时由系统自动清理

    // MARK: - Public Methods

    /// 供将来重新启动刷新任务时调用。
    func start() {
        // 菜单栏标题在弹层打开前就需要有缓存和最新数据。
        loadCache()
        startAutoRefresh()
        Task { [weak self] in
            await self?.refresh()
        }
    }

    /// 手动刷新
    func refresh() async {
        guard !isRefreshing else {
            AppLog.app.debug("Refresh skipped because one is already running")
            return
        }
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

    /// 切换菜单栏显示项目。至少保留一项，关闭最后一项的请求会被拒绝。
    func setDisplayItem(_ item: MenuBarDisplaySettings.Item, visible: Bool) {
        guard let next = displaySettings.toggling(item, to: visible) else {
            AppLog.app.debug("Display item change rejected: at least one item must stay visible")
            return
        }
        displaySettings = next
        next.save()
    }

    // MARK: - Private Methods

    private func refreshCursor() async {
        AppLog.cursor.debug(
            "Cursor local state detection: \(CursorTokenReader.isCursorInstalled ? "installed" : "not-installed", privacy: .public)"
        )
        cursorPlanName = CursorTokenReader.readPlanName()

        guard let token = resolveCursorToken() else {
            AppLog.cursor.notice("Cursor credentials were not found")
            if cursorUsage != nil {
                cursorConnectionState = .stale
            } else {
                cursorConnectionState = .disconnected
            }
            return
        }

        do {
            let usage = try await CursorAPIClient.fetchCurrentPeriodUsage(token: token)
            cursorUsage = usage
            cursorConnectionState = .connected
            AppLog.cursor.info("Cursor usage refresh succeeded")
        } catch {
            // 失败时保持缓存数据
            if cursorUsage != nil {
                cursorConnectionState = .stale
            } else {
                cursorConnectionState = .error(error.localizedDescription)
            }
            let category = (error as? CursorError)?.logCategory ?? "unexpected"
            AppLog.cursor.error("Cursor usage refresh failed: \(category, privacy: .public)")
            handleError(error)
        }
    }

    private func refreshCodex() async {
        do {
            codexUsage = try await CodexIntegration.fetchUsage()
            codexConnectionState = .connected
            AppLog.codex.info("Codex usage refresh succeeded")
        } catch {
            // Codex 读取失败时不展示旧数据，避免把过期额度误认为当前额度。
            codexUsage = .disconnected
            codexConnectionState = .disconnected
            let category = (error as? CodexIntegration.IntegrationError)?.logCategory
                ?? "unexpected"
            AppLog.codex.error("Codex usage refresh failed: \(category, privacy: .public)")
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
        let (cursor, _) = UsageCache.load()
        if let cursor { cursorUsage = cursor }
        cursorPlanName = CursorTokenReader.readPlanName()
        codexUsage = .disconnected
        codexConnectionState = .disconnected
    }

    private func saveCache() {
        UsageCache.save(cursor: cursorUsage, codex: nil)
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
