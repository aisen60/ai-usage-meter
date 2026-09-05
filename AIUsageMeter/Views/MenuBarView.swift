import SwiftUI

/// 紧凑型菜单栏弹层的统一尺寸，避免各区块各自出现魔法数字。
enum MenuMetrics {
    static let width: CGFloat = 320

    // 原有文字与图标度量
    static let horizontalPadding: CGFloat = 14
    static let serviceIcon: CGFloat = 27
    static let serviceTitle: CGFloat = 16
    static let serviceHeaderTitle: CGFloat = 15
    static let statusText: CGFloat = 12
    static let summaryText: CGFloat = 12
    static let cardTitle: CGFloat = 14
    static let bodyText: CGFloat = 11.5

    // MARK: - 主页面布局（design/v0.3.0/home.png）

    /// 主内容区相对弹层边缘的水平内边距
    static let outerHorizontalPadding: CGFloat = 12

    /// 主内容区顶部内边距
    static let outerTopPadding: CGFloat = 14

    /// 服务组区域与底栏上边线之间的间距
    static let outerBottomPadding: CGFloat = 12

    /// 两张服务组卡片之间的间距
    static let groupSpacing: CGFloat = 12

    /// 服务组卡片圆角
    static let groupCornerRadius: CGFloat = 10

    /// 服务组卡片描边透明度
    static let groupBorderOpacity: Double = 0.06

    /// 卡片内容（header 与额度行）的横向内边距；组内行分隔线按此缩进
    static let groupInset: CGFloat = 14

    /// header 顶部内边距
    static let groupHeaderTop: CGFloat = 12

    /// header 到第一条额度行的间距（行为自身另有上下内边距）
    static let groupHeaderBottom: CGFloat = 4

    /// 最后一条额度行之下的卡片底部内边距
    static let groupContentBottom: CGFloat = 5

    /// 额度行的上下内边距
    static let rowVerticalPadding: CGFloat = 9

    /// 行内标签 / 数值与进度条之间的间距
    static let rowSpacing: CGFloat = 7

    /// 进度条高度
    static let rowBarHeight: CGFloat = 6

    /// 底栏按钮区的上下内边距
    static let toolbarVerticalPadding: CGFloat = 10

    /// 底栏段间竖向分隔线高度
    static let toolbarDividerHeight: CGFloat = 20
}

/// 菜单栏下拉菜单主视图
struct MenuBarView: View {
    @ObservedObject var controller: QuotaController
    @ObservedObject var appUpdateController: AppUpdateController
    @Binding var appLanguage: AppLanguage
    @Environment(\.locale) private var locale

    /// 弹层内页面：主视图或设置页
    private enum Page {
        case main
        case settings
        case supportedApps
    }

    @State private var page: Page = .main

    var body: some View {
        Group {
            switch page {
            case .main:
                mainPage
            case .settings:
                SettingsView(
                    controller: controller,
                    appUpdateController: appUpdateController,
                    appLanguage: $appLanguage
                ) {
                    page = .main
                }
            case .supportedApps:
                supportedAppsPage
            }
        }
        // 两个页面共用同一宽度，切换时弹层不跳动
        .frame(width: MenuMetrics.width)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            controller.menuDidOpen()
        }
    }

    /// 主页面：外层留白 + 服务组卡片区域 + 通栏底栏
    private var mainPage: some View {
        VStack(spacing: 0) {
            mainContent
            .padding(.horizontal, MenuMetrics.outerHorizontalPadding)
            .padding(.top, MenuMetrics.outerTopPadding)
            .padding(.bottom, MenuMetrics.outerBottomPadding)

            // footer 是独立底栏，分隔线通栏
            Divider()

            bottomToolbar
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if controller.shouldShowEmptyAssistantState {
            EmptyAssistantStateView {
                page = .supportedApps
            }
        } else {
            VStack(spacing: MenuMetrics.groupSpacing) {
                if controller.shouldShowCursor {
                    CursorSection(
                        usage: controller.cursorUsage,
                        planName: controller.cursorPlanName,
                        connectionState: controller.cursorConnectionState
                    )
                }

                if controller.shouldShowChatGPT {
                    CodexSection(
                        usage: controller.codexUsage,
                        connectionState: controller.codexConnectionState
                    )
                }
            }
        }
    }

    private var supportedAppsPage: some View {
        VStack(spacing: 0) {
            SupportedAppsView(controller: controller) {
                page = .main
            }

            Divider()
            bottomToolbar
        }
    }

    /// 底部工具栏（设计稿 home.png）：
    /// 三等分分段式底栏 —— 设置 | 刷新状态 | 退出，段间竖向分隔线。
    private var bottomToolbar: some View {
        Group {
            if controller.shouldShowEmptyAssistantState {
                quitCell
            } else {
                HStack(spacing: 0) {
                    settingsCell
                    segmentDivider
                    refreshCell
                    segmentDivider
                    quitCell
                }
            }
        }
        .padding(.vertical, MenuMetrics.toolbarVerticalPadding)
    }

    /// 左段：设置入口（图标 + 文字）
    private var settingsCell: some View {
        Button(action: { page = .settings }) {
            Label("toolbar.settings", systemImage: "gearshape")
                .font(.system(size: 12.5, weight: .regular))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .help(AppLanguage.localized("toolbar.settings", locale: locale))
    }

    /// 中段：刷新动作 + 上次更新时间（图标 + 状态文字）
    private var refreshCell: some View {
        Button(action: {
            Task { await controller.refresh() }
        }) {
            HStack(spacing: 6) {
                if controller.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.8)
                        .frame(width: 13, height: 13)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12.5, weight: .regular))
                }
                Text(lastRefreshText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .disabled(controller.isRefreshing)
        .foregroundStyle(.primary)
        .help(AppLanguage.localized("toolbar.refresh", locale: locale))
        .accessibilityLabel(AppLanguage.localized("toolbar.refresh", locale: locale))
        .accessibilityValue(lastRefreshText)
    }

    /// 右段：退出（图标 + 文字）
    private var quitCell: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("toolbar.quit", systemImage: "power")
                .font(.system(size: 12.5, weight: .regular))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .help(AppLanguage.localized("toolbar.quitHelp", locale: locale))
    }

    /// 段间竖向分隔线
    private var segmentDivider: some View {
        Divider()
            .frame(height: MenuMetrics.toolbarDividerHeight)
    }

    /// 上次刷新文本
    private var lastRefreshText: String {
        RefreshTimeFormatter.text(
            isRefreshing: controller.isRefreshing,
            lastRefreshTime: controller.lastRefreshTime,
            now: Date(),
            locale: locale
        )
    }
}

/// 供工具栏和单元测试共用的相对刷新时间格式化逻辑。
enum RefreshTimeFormatter {
    static func text(
        isRefreshing: Bool,
        lastRefreshTime: Date?,
        now: Date,
        locale: Locale
    ) -> String {
        if isRefreshing {
            return AppLanguage.localized("toolbar.refreshing", locale: locale)
        }
        guard let lastRefreshTime else {
            return AppLanguage.localized("toolbar.neverRefreshed", locale: locale)
        }

        let elapsed = max(0, now.timeIntervalSince(lastRefreshTime))
        if elapsed < 60 {
            return AppLanguage.localized("toolbar.justUpdated", locale: locale)
        }
        if elapsed < 3_600 {
            return AppLanguage.localized(
                "toolbar.minutesAgo",
                locale: locale,
                arguments: Int(elapsed / 60)
            )
        }
        return AppLanguage.localized(
            "toolbar.hoursAgo",
            locale: locale,
            arguments: Int(elapsed / 3_600)
        )
    }
}
