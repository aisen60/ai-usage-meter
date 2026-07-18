import SwiftUI

/// Cursor 详情分区
struct CursorSection: View {
    let usage: CursorUsage?
    let connectionState: QuotaController.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题
            HStack {
                Image(systemName: "cursorarrow.rays")
                    .foregroundColor(.blue)
                Text("Cursor Pro")
                    .font(.headline)
                Spacer()
                connectionBadge
            }

            if let usage {
                // 综合额度
                UsageRow(
                    label: "综合额度",
                    percent: usage.totalPercentUsed,
                    color: usage.totalPercentUsed > 80 ? .red : .blue
                )

                // Auto / Composer
                UsageRow(
                    label: "Auto / Composer",
                    percent: usage.autoPercentUsed,
                    color: usage.autoPercentUsed > 80 ? .red : .orange
                )

                // API 模型
                UsageRow(
                    label: "API 模型",
                    percent: usage.apiPercentUsed,
                    color: .green
                )

                Divider()

                // 账期
                Text("账期: \(formattedCycleRange(usage))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 额外付费额度
                if usage.individualLimit > 0 {
                    Text(
                        "额外额度: $\(Int(usage.individualRemaining)) / $\(Int(usage.individualLimit))"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else {
                // 未连接状态
                Text(connectionMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
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

    /// 连接消息
    private var connectionMessage: String {
        switch connectionState {
        case .connected:
            return "已连接"
        case .disconnected:
            return "未检测到 Cursor 登录态，请在 Cursor 中登录或手动输入 Token"
        case .error(let msg):
            return "错误: \(msg)"
        case .unknown:
            return "检测中..."
        }
    }

    /// 格式化账期范围
    private func formattedCycleRange(_ usage: CursorUsage) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let start = formatter.string(from: usage.billingCycleStartDate)
        let end = formatter.string(from: usage.billingCycleEndDate)
        return "\(start) - \(end)"
    }
}

/// 用量行视图
struct UsageRow: View {
    let label: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(percent))% 已用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: min(percent, 100), total: 100)
                .tint(color)
        }
    }
}
