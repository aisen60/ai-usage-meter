import SwiftUI

/// 紧凑型菜单栏弹层的统一尺寸，避免各区块各自出现魔法数字。
enum MenuMetrics {
    static let width: CGFloat = 320
    static let horizontalPadding: CGFloat = 14
    static let serviceIcon: CGFloat = 27
    static let serviceTitle: CGFloat = 16
    static let statusText: CGFloat = 12
    static let sectionTitle: CGFloat = 14.5
    static let summaryText: CGFloat = 12
    static let cardTitle: CGFloat = 14
    static let bodyText: CGFloat = 11.5
}

/// 菜单栏下拉菜单主视图
struct MenuBarView: View {
    @ObservedObject var controller: QuotaController

    /// 弹层内页面：主视图或设置页
    private enum Page {
        case main
        case settings
    }

    @State private var page: Page = .main

    var body: some View {
        Group {
            switch page {
            case .main:
                mainPage
            case .settings:
                SettingsView(controller: controller) {
                    page = .main
                }
            }
        }
        // 两个页面共用同一宽度，切换时弹层不跳动
        .frame(width: MenuMetrics.width)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("错误", isPresented: $controller.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "未知错误")
        }
    }

    /// 主页面：配额区块 + 底部工具栏
    private var mainPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            if controller.isCursorInstalled {
                CursorSection(
                    usage: controller.cursorUsage,
                    planName: controller.cursorPlanName,
                    connectionState: controller.cursorConnectionState
                )

                Divider()
                    .padding(.leading, 16)
            }

            CodexSection(
                usage: controller.codexUsage,
                connectionState: controller.codexConnectionState
            )

            // footer 是独立底栏，分隔线通栏
            Divider()

            bottomToolbar
        }
    }

    /// 底部工具栏（设计稿 main-page-footer-reference-inspired.png）：
    /// 三等分分段式底栏 —— 设置 | 刷新状态 | 退出，段间竖向分隔线。
    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            settingsCell
            segmentDivider
            refreshCell
            segmentDivider
            quitCell
        }
        .padding(.vertical, 8)
    }

    /// 左段：设置入口
    private var settingsCell: some View {
        Button(action: { page = .settings }) {
            Label("设置", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .regular))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.primary)
        .help("设置")
    }

    /// 中段：刷新动作 + 上次更新时间
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
                        .font(.system(size: 13, weight: .regular))
                }
                Text(lastRefreshText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .disabled(controller.isRefreshing)
        .foregroundColor(.primary)
        .help("刷新")
        .accessibilityLabel("刷新")
        .accessibilityValue(lastRefreshText)
    }

    /// 右段：退出
    private var quitCell: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("退出 Agent Quota Bar", systemImage: "power")
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .regular))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.primary)
        .help("退出 Agent Quota Bar")
    }

    /// 段间竖向分隔线
    private var segmentDivider: some View {
        Divider()
            .frame(height: 18)
    }

    /// 上次刷新文本
    private var lastRefreshText: String {
        if controller.isRefreshing {
            return "正在刷新…"
        }
        if let date = controller.lastRefreshTime {
            let elapsed = max(0, Date().timeIntervalSince(date))
            if elapsed < 60 { return "刚刚更新" }
            if elapsed < 3_600 { return "\(Int(elapsed / 60)) 分钟前" }
            return "\(Int(elapsed / 3_600)) 小时前"
        }
        return "尚未刷新"
    }
}
