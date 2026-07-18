import SwiftUI

/// 菜单栏下拉菜单主视图
struct MenuBarView: View {
    @ObservedObject var controller: QuotaController
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // === Cursor 区域 ===
            CursorSection(
                usage: controller.cursorUsage,
                connectionState: controller.cursorConnectionState
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // === Codex 区域 ===
            CodexSection(
                usage: controller.codexUsage,
                connectionState: controller.codexConnectionState,
                onOpenUsagePage: { CodexIntegration.openUsagePage() },
                onManualInput: { showSettings = true }
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()

            // === 底部工具栏 ===
            bottomToolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView(controller: controller)
        }
        .alert("错误", isPresented: $controller.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "未知错误")
        }
    }

    /// 底部工具栏
    private var bottomToolbar: some View {
        HStack {
            // 上次刷新时间
            Text(lastRefreshText)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            // 刷新按钮
            Button(action: {
                Task { await controller.refresh() }
            }) {
                if controller.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(controller.isRefreshing)

            // 设置按钮
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)

            // 退出按钮
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
        }
    }

    /// 上次刷新文本
    private var lastRefreshText: String {
        if controller.isRefreshing {
            return "刷新中..."
        }
        if let date = controller.lastRefreshTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "更新于 \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return "尚未刷新"
    }
}
