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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CursorSection(
                usage: controller.cursorUsage,
                planName: controller.cursorPlanName,
                connectionState: controller.cursorConnectionState
            )

            Divider()
                .padding(.leading, 16)

            CodexSection(
                usage: controller.codexUsage,
                connectionState: controller.codexConnectionState
            )

            Divider()
                .padding(.leading, 16)

            bottomToolbar
                .padding(.horizontal, MenuMetrics.horizontalPadding)
                .padding(.vertical, 8)
        }
        .frame(width: MenuMetrics.width)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("错误", isPresented: $controller.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "未知错误")
        }
    }

    /// 底部工具栏
    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            Button(action: {
                Task { await controller.refresh() }
            }) {
                if controller.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .regular))
                }
            }
            .buttonStyle(.borderless)
            .disabled(controller.isRefreshing)
            .foregroundColor(.primary)
            .help(lastRefreshText)

            Text(lastRefreshText)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .regular))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
            .help("退出 Agent Quota Bar")
        }
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
