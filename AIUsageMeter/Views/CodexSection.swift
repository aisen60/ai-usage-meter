import SwiftUI

/// ChatGPT 服务组卡片：header 与 5 小时 / 1 周两条额度行共处同一圆角容器，
/// 两行之间只有一条组内细分隔线（design/v0.3.0/home.png）。
struct CodexSection: View {
    let usage: CodexUsage
    let connectionState: QuotaController.ConnectionState

    var body: some View {
        ServiceGroupCard {
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 0) {
                    QuotaRow(
                        label: "5 小时",
                        percent: shortPercent,
                        tint: isConnected ? QuotaPalette.chatgpt : .gray,
                        detail: shortResetDetail
                    )
                    Divider()
                    QuotaRow(
                        label: "1 周",
                        percent: weeklyPercent,
                        tint: isConnected ? QuotaPalette.chatgpt : .gray,
                        detail: weeklyResetDetail
                    )
                }
                .padding(.horizontal, MenuMetrics.groupInset)
                .padding(.bottom, MenuMetrics.groupContentBottom)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ServiceLogo(resourceName: "CodexIcon", fallbackSymbol: "terminal.fill")
            Text(isConnected ? usage.planName : "ChatGPT")
                .font(.system(size: MenuMetrics.serviceHeaderTitle, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 8)
            ConnectionStatus(state: connectionState)
                .layoutPriority(2)
        }
        .padding(.horizontal, MenuMetrics.groupInset)
        .padding(.top, MenuMetrics.groupHeaderTop)
        .padding(.bottom, MenuMetrics.groupHeaderBottom)
    }

    private var isConnected: Bool {
        connectionState.isConnected && usage.isConnected
    }

    private var shortPercent: Double {
        isConnected ? usage.shortWindow.percentRemaining : 0
    }

    private var weeklyPercent: Double {
        isConnected ? usage.weeklyWindow.percentRemaining : 0
    }

    /// 5 小时窗口：显示重置时间，如「23:12 重置」。
    private var shortResetDetail: String? {
        guard isConnected, let resetsAt = usage.shortWindow.resetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: resetsAt)) 重置"
    }

    /// 1 周窗口：显示重置日期，如「9 月 4 日重置」。
    private var weeklyResetDetail: String? {
        guard isConnected, let resetsAt = usage.weeklyWindow.resetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: resetsAt))重置"
    }
}
