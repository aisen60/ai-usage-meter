import SwiftUI

/// 菜单栏徽章：固定「CC」前缀 + 按显示设置过滤的百分比胶囊。
///
/// 由 MenuBarLabel（经 ImageRenderer 渲染到状态栏）和 SettingsView
/// （设置页内的预览卡片）共用，保证两处视觉完全一致。
struct StatusBarBadge: View {
    let cursorText: String
    let otherText: String
    let codexText: String
    let cursorConnected: Bool
    let otherConnected: Bool
    let codexConnected: Bool
    let settings: MenuBarDisplaySettings

    var body: some View {
        HStack(spacing: 3) {
            Text("CC")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))

            if settings.showCursorModels {
                pill(
                    cursorText,
                    color: cursorConnected
                        ? Color(red: 0.04, green: 0.45, blue: 0.96)
                        : unavailableColor
                )
            }
            if settings.showOtherModels {
                pill(
                    otherText,
                    color: otherConnected
                        ? Color(red: 0.39, green: 0.39, blue: 0.39)
                        : unavailableColor
                )
            }
            if settings.showCodexWeeklyRemaining {
                pill(
                    codexText,
                    color: codexConnected
                        ? Color(red: 0.00, green: 0.62, blue: 0.32)
                        : unavailableColor
                )
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var unavailableColor: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
            )
    }
}
