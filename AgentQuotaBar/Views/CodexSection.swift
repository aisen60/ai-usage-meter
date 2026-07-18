import SwiftUI

/// Codex 周额度区域。Codex 与 Cursor 的口径不同，这里展示剩余额度。
struct CodexSection: View {
    let usage: CodexUsage
    let connectionState: QuotaController.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ServiceLogo(resourceName: "CodexIcon", fallbackSymbol: "terminal.fill")
                Text(isConnected ? usage.planName : "Codex")
                    .font(.system(size: MenuMetrics.serviceTitle, weight: .bold))
                Spacer()
                ConnectionStatus(state: connectionState)
            }
            .padding(.horizontal, MenuMetrics.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 11)

            UsageBarCard(
                label: "本周剩余",
                percent: remainingPercent,
                tint: isConnected ? .green : .gray,
                detail: resetDetail
            )
            .padding(.horizontal, MenuMetrics.horizontalPadding)
            .padding(.bottom, 11)
        }
    }

    private var isConnected: Bool {
        connectionState.isConnected && usage.isConnected
    }

    private var remainingPercent: Double {
        isConnected ? usage.percentRemaining : 0
    }

    private var resetDetail: String? {
        guard isConnected, let resetDate = usage.cycleEndDate else { return nil }

        let calendar = Calendar.current
        let days = max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: calendar.startOfDay(for: resetDate)
            ).day ?? 0
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let dateText = formatter.string(from: resetDate)

        if days == 0 { return "今天重置（\(dateText)）" }
        return "重置于 \(days) 天后（\(dateText)）"
    }
}
