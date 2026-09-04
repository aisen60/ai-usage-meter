import AppKit
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

    /// ChatGPT 用量数据（内部仍使用 CodexUsage 类型名）
    @Published var codexUsage: CodexUsage = .disconnected

    /// 是否正在刷新
    @Published var isRefreshing = false

    /// 上次刷新时间
    @Published var lastRefreshTime: Date?

    /// Cursor 连接状态
    @Published var cursorConnectionState: ConnectionState = .unknown

    /// 当前是否检测到 Cursor 本地状态。未安装时不展示 Cursor 相关界面。
    @Published private(set) var isCursorInstalled: Bool

    /// Cursor 已安装时显示卡片；未登录或读取失败仍保留卡片，明确展示连接状态。
    var shouldShowCursor: Bool {
        isCursorInstalled
    }

    /// On Demand 个人额度是否有有效上限，决定该项是否展示。
    var shouldShowOnDemand: Bool {
        shouldShowCursor && (cursorUsage?.onDemandAvailable ?? false)
    }

    /// ChatGPT 连接状态（内部仍使用 codex 命名）
    @Published var codexConnectionState: ConnectionState = .unknown

    /// 当前是否检测到 ChatGPT 桌面客户端。未安装时不展示 ChatGPT 卡片。
    @Published private(set) var isChatGPTInstalled: Bool

    var shouldShowChatGPT: Bool {
        isChatGPTInstalled
    }

    /// 两个支持的客户端均未安装时，主面板改为显示引导空状态。
    var shouldShowEmptyAssistantState: Bool {
        !shouldShowCursor && !shouldShowChatGPT
    }

    /// 菜单栏显示项目设置（变更即持久化到 UserDefaults）
    @Published var displaySettings: MenuBarDisplaySettings

    // MARK: - Properties

    /// 定时刷新任务
    private var refreshTask: Task<Void, Never>?

    /// 系统唤醒监听任务
    private var wakeObserverTask: Task<Void, Never>?

    /// 最近一次打开菜单的时间，用于判断用户是否正在关注额度。
    private var lastInteractionTime: Date?

    /// 自适应刷新策略
    private let refreshPolicy = AdaptiveRefreshPolicy()

    /// Token 来源
    private let tokenAccount = "cursor-token"

    /// Debug 预览时强制隐藏两个客户端，不读取或修改本机实际安装状态。
    private let forceNoAssistantApps: Bool

    /// Debug 预览时仅显示 Cursor，强制隐藏 ChatGPT。
    private let forceCursorOnly: Bool

    /// Debug 预览时仅显示 ChatGPT，强制隐藏 Cursor。
    private let forceChatGPTOnly: Bool

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
        /// ChatGPT 失败时不会进入 stale，因此不会误用旧额度。
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

    init(
        autoStart: Bool = true,
        cursorInstalled: Bool = CursorTokenReader.isCursorInstalled,
        chatGPTInstalled: Bool = CodexIntegration.isChatGPTInstalled,
        forceNoAssistantApps: Bool? = nil,
        forceCursorOnly: Bool? = nil,
        forceChatGPTOnly: Bool? = nil
    ) {
        let commandLinePreview = Self.commandLinePreview
        let shouldForceNoAssistantApps = forceNoAssistantApps
            ?? (commandLinePreview == .noAssistantApps)
        let shouldForceCursorOnly = forceCursorOnly
            ?? (commandLinePreview == .cursorOnly)
        let shouldForceChatGPTOnly = forceChatGPTOnly
            ?? (commandLinePreview == .chatGPTOnly)
        self.forceNoAssistantApps = shouldForceNoAssistantApps
        self.forceCursorOnly = shouldForceCursorOnly
        self.forceChatGPTOnly = shouldForceChatGPTOnly
        isCursorInstalled = (shouldForceNoAssistantApps || shouldForceChatGPTOnly)
            ? false
            : cursorInstalled
        isChatGPTInstalled = (shouldForceNoAssistantApps || shouldForceCursorOnly)
            ? false
            : chatGPTInstalled
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
        startWakeMonitoring()
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

        // 并行获取 Cursor 和 ChatGPT
        async let cursorTask: Void = refreshCursor()
        async let codexTask: Void = refreshCodex()
        _ = await (cursorTask, codexTask)

        isRefreshing = false
        lastRefreshTime = Date()

        // 保存缓存
        saveCache()
    }

    /// 菜单打开时记录交互，并只在数据已经过期时刷新。
    func menuDidOpen() {
        let now = Date()
        lastInteractionTime = now
        startAutoRefresh()

        Task { [weak self] in
            await self?.refreshIfNeeded(now: now)
        }
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

    /// 切换菜单栏显示项目。用户可以选择隐藏全部用量胶囊。
    func setDisplayItem(_ item: MenuBarDisplaySettings.Item, visible: Bool) {
        let next = displaySettings.toggling(item, to: visible)
        displaySettings = next
        next.save()
    }

    // MARK: - Private Methods

    private func refreshCursor() async {
        isCursorInstalled = (forceNoAssistantApps || forceChatGPTOnly)
            ? false
            : CursorTokenReader.isCursorInstalled
        AppLog.cursor.debug(
            "Cursor local state detection: \(self.isCursorInstalled ? "installed" : "not-installed", privacy: .public)"
        )

        guard isCursorInstalled else {
            cursorConnectionState = .disconnected
            AppLog.cursor.notice("Cursor is not installed; usage refresh skipped")
            return
        }

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
        }
    }

    private func refreshCodex() async {
        isChatGPTInstalled = forceNoAssistantApps
            ? false
            : (forceCursorOnly ? false : CodexIntegration.isChatGPTInstalled)
        guard isChatGPTInstalled else {
            codexUsage = .disconnected
            codexConnectionState = .disconnected
            AppLog.codex.notice("ChatGPT is not installed; usage refresh skipped")
            return
        }

        do {
            codexUsage = try await CodexIntegration.fetchUsage()
            codexConnectionState = .connected
            AppLog.codex.info("ChatGPT usage refresh succeeded")
        } catch {
            // ChatGPT 读取失败时不展示旧数据，避免把过期额度误认为当前额度。
            codexUsage = .disconnected
            codexConnectionState = .disconnected
            let category = (error as? CodexIntegration.IntegrationError)?.logCategory
                ?? "unexpected"
            AppLog.codex.error("ChatGPT usage refresh failed: \(category, privacy: .public)")
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let schedule = self.refreshPolicy.schedule(
                    now: Date(),
                    lastInteractionTime: self.lastInteractionTime,
                    isSystemConstrained: self.isSystemConstrained
                )
                AppLog.app.debug(
                    "Next automatic refresh in \(Int(schedule.interval), privacy: .public)s (\(schedule.reason.rawValue, privacy: .public))"
                )

                do {
                    try await Task.sleep(for: .seconds(schedule.interval))
                } catch {
                    break
                }
                // 调度任务只负责计时；重新排期时不会取消已经发出的网络刷新。
                Task { [weak self] in
                    await self?.refresh()
                }
            }
        }
    }

    /// 睡眠期间定时任务可能暂停；唤醒后重新排期，并补一次必要的刷新。
    private func startWakeMonitoring() {
        wakeObserverTask?.cancel()
        wakeObserverTask = Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            ) {
                guard !Task.isCancelled, let self else { break }
                let now = Date()
                self.startAutoRefresh()
                await self.refreshIfNeeded(now: now)
            }
        }
    }

    private func refreshIfNeeded(now: Date) async {
        guard refreshPolicy.shouldRefresh(
            now: now,
            lastRefreshTime: lastRefreshTime
        ) else {
            AppLog.app.debug("Interactive refresh skipped because data is still fresh")
            return
        }
        await refresh()
    }

    private var isSystemConstrained: Bool {
        let processInfo = ProcessInfo.processInfo
        switch processInfo.thermalState {
        case .serious, .critical:
            return true
        default:
            return processInfo.isLowPowerModeEnabled
        }
    }

    private enum AppAvailabilityPreview {
        case noAssistantApps
        case cursorOnly
        case chatGPTOnly
    }

    /// 仅 Debug 构建可通过启动参数预览安装状态。Release 构建忽略这些参数。
    private static var commandLinePreview: AppAvailabilityPreview? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-no-assistant-apps") {
            return .noAssistantApps
        }
        if arguments.contains("--preview-cursor-only") {
            return .cursorOnly
        }
        if arguments.contains("--preview-chatgpt-only") {
            return .chatGPTOnly
        }
        return nil
        #else
        nil
        #endif
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        wakeObserverTask?.cancel()
        wakeObserverTask = nil
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

}
