import SwiftUI

/// Codex 详情分区
struct CodexSection: View {
    let usage: CodexUsage
    let connectionState: QuotaController.ConnectionState
    let onOpenUsagePage: () -> Void
    let onManualInput: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Codex Pro")
                    .font(.headline)
                Spacer()
                connectionBadge
            }

            if usage.isConnected {
                // 剩余百分比
                UsageRow(
                    label: "剩余额度",
                    percent: usage.percentUsed,
                    color: usage.percentUsed > 80 ? .red : .purple
                )

                // 账期
                if let cycleEnd = usage.cycleEndDate {
                    Text("账期截止: \(formattedDate(cycleEnd))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 备注
                if let note = usage.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 来源标签
                Text(usage.source == .automatic ? "自动获取" : "手动录入")
                    .font(.caption2)
                    .foregroundColor(.secondary)

            } else {
                // 未连接状态
                Text("Codex 用量数据暂未接入")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)

                HStack(spacing: 8) {
                    Button("手动录入") { onManualInput() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("打开用量页面") { onOpenUsagePage() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    /// 连接状态小标签
    @ViewBuilder
    private var connectionBadge: some View {
        switch connectionState {
        case .connected:
            Text("已连接")
                .font(.caption2)
                .foregroundColor(.green)
        case .disconnected:
            Text("未连接")
                .font(.caption2)
                .foregroundColor(.gray)
        case .error(let msg):
            Text(msg)
                .font(.caption2)
                .foregroundColor(.orange)
        case .unknown:
            EmptyView()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
}
