import SwiftUI

/// 菜单栏标题视图 - 显示在状态栏中
struct MenuBarLabel: View {
    @ObservedObject var controller: QuotaController

    var body: some View {
        HStack(spacing: 4) {
            // 状态圆点
            Circle()
                .fill(cursorDotColor)
                .frame(width: 8, height: 8)

            // Cursor 百分比
            Text(cursorPercentText)
                .font(.system(size: 13, weight: .medium))

            Text("·")
                .foregroundColor(.secondary)

            // Codex 百分比
            Text(codexPercentText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    controller.codexUsage.isConnected ? .primary : .secondary
                )
        }
    }

    /// Cursor 圆点颜色
    private var cursorDotColor: Color {
        switch controller.cursorConnectionState {
        case .connected:
            if let usage = controller.cursorUsage {
                if usage.totalPercentUsed > 80 { return .red }
                if usage.totalPercentUsed > 50 { return .orange }
                return .green
            }
            return .green
        case .disconnected, .unknown:
            return .gray
        case .error:
            return .yellow
        }
    }

    /// Cursor 百分比文本
    private var cursorPercentText: String {
        if let usage = controller.cursorUsage {
            let remaining = Int(usage.totalPercentRemaining)
            return "Cursor \(remaining)%"
        }
        return "Cursor --"
    }

    /// Codex 百分比文本
    private var codexPercentText: String {
        if controller.codexUsage.isConnected {
            let remaining = Int(controller.codexUsage.percentRemaining)
            return "Codex \(remaining)%"
        }
        return "Codex --"
    }
}
