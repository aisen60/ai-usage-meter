import AppKit
import SwiftUI

/// 状态栏与设置页共用的展示模型：可见项目顺序、每条文案、连接状态与无障碍描述。
/// 纯数据（不依赖 SwiftUI），便于单元测试；颜色由视图按 item 类型映射。
struct StatusBarPresentation: Equatable {
    struct Entry: Equatable, Identifiable {
        let item: MenuBarDisplaySettings.Item
        let text: String
        let isConnected: Bool
        let accessibilityText: String

        var id: MenuBarDisplaySettings.Item { item }
    }

    let entries: [Entry]
    let fallbackText: String
    let accessibilityDescription: String

    init(
        settings: MenuBarDisplaySettings,
        cursorUsage: CursorUsage?,
        cursorAvailable: Bool,
        cursorState: QuotaController.ConnectionState,
        codexUsage: CodexUsage,
        codexState: QuotaController.ConnectionState,
        codexAvailable: Bool = true,
        locale: Locale = AppLanguage.defaultLanguage.locale
    ) {
        let cursorConnected = cursorAvailable && cursorUsage != nil
        let onDemandAvailable = cursorAvailable && (cursorUsage?.onDemandAvailable ?? false)
        let codexConnected = codexAvailable && codexState.isConnected && codexUsage.isConnected

        let items = settings.visibleItems(
            cursorAvailable: cursorAvailable,
            onDemandAvailable: onDemandAvailable,
            chatGPTAvailable: codexAvailable
        )

        let entries: [Entry] = items.map { item in
            switch item {
            case .cursorModels:
                let text = Self.percent(cursorConnected ? cursorUsage?.autoPercentUsed : nil)
                return Entry(
                    item: item,
                    text: text,
                    isConnected: cursorConnected,
                    accessibilityText: Self.accessibilityText(
                        key: "statusBar.cursorModels.used",
                        value: text,
                        state: cursorState,
                        locale: locale
                    )
                )
            case .otherModels:
                let text = Self.percent(cursorConnected ? cursorUsage?.apiPercentUsed : nil)
                return Entry(
                    item: item,
                    text: text,
                    isConnected: cursorConnected,
                    accessibilityText: Self.accessibilityText(
                        key: "statusBar.otherModels.used",
                        value: text,
                        state: cursorState,
                        locale: locale
                    )
                )
            case .onDemand:
                let text = cursorUsage?.onDemandUsedAmountText ?? "$0"
                return Entry(
                    item: item,
                    text: text,
                    isConnected: cursorConnected,
                    accessibilityText: Self.accessibilityText(
                        key: "statusBar.onDemand.used",
                        value: text,
                        state: cursorState,
                        locale: locale
                    )
                )
            case .chatgptFiveHour:
                let text = codexConnected
                    ? Self.percent(codexUsage.shortWindow.percentRemaining)
                    : "0%"
                return Entry(
                    item: item,
                    text: text,
                    isConnected: codexConnected,
                    accessibilityText: Self.accessibilityText(
                        key: "statusBar.chatGPTFiveHours.remaining",
                        value: text,
                        state: codexState,
                        locale: locale
                    )
                )
            case .chatgptWeekly:
                let text = codexConnected
                    ? Self.percent(codexUsage.weeklyWindow.percentRemaining)
                    : "0%"
                return Entry(
                    item: item,
                    text: text,
                    isConnected: codexConnected,
                    accessibilityText: Self.accessibilityText(
                        key: "statusBar.chatGPTWeek.remaining",
                        value: text,
                        state: codexState,
                        locale: locale
                    )
                )
            }
        }

        self.entries = entries
        self.fallbackText = (["AI"] + entries.map(\.text)).joined(separator: " ")
        self.accessibilityDescription = entries.map(\.accessibilityText).joined(
            separator: AppLanguage.localized("statusBar.separator", locale: locale)
        )
    }

    private static func percent(_ value: Double?) -> String {
        "\(Int((value ?? 0).rounded()))%"
    }

    private static func accessibilityText(
        key: String,
        value: String,
        state: QuotaController.ConnectionState,
        locale: Locale
    ) -> String {
        AppLanguage.localized(key, locale: locale, arguments: value)
            + stateSuffix(state, locale: locale)
    }

    private static func stateSuffix(
        _ state: QuotaController.ConnectionState,
        locale: Locale
    ) -> String {
        switch state {
        case .connected: return ""
        case .stale:
            return AppLanguage.localized("statusBar.stateSuffix.cached", locale: locale)
        case .disconnected:
            return AppLanguage.localized("statusBar.stateSuffix.disconnected", locale: locale)
        case .error:
            return AppLanguage.localized("statusBar.stateSuffix.connectionIssue", locale: locale)
        case .unknown:
            return AppLanguage.localized("statusBar.stateSuffix.detecting", locale: locale)
        }
    }
}

/// 五个显示项目共用的胶囊配色，保证状态栏、设置页与卡片一致。
enum QuotaPalette {
    static let cursorModels = Color(red: 0.04, green: 0.45, blue: 0.96)
    static let otherModels = Color(red: 0.39, green: 0.39, blue: 0.39)
    static let onDemand = Color(red: 0.56, green: 0.30, blue: 0.78)
    static let chatgpt = Color(red: 0.00, green: 0.62, blue: 0.32)

    static func tint(for item: MenuBarDisplaySettings.Item) -> Color {
        switch item {
        case .cursorModels: return cursorModels
        case .otherModels: return otherModels
        case .onDemand: return onDemand
        case .chatgptFiveHour, .chatgptWeekly: return chatgpt
        }
    }
}

/// 菜单栏徽章：固定「AI」前缀 + 按显示设置与可用性过滤的胶囊。
///
/// 由 MenuBarLabel（经 ImageRenderer 渲染到状态栏）和 SettingsView
/// （设置页内的预览卡片）共用，保证两处视觉完全一致。
struct StatusBarBadge: View {
    let presentation: StatusBarPresentation

    var body: some View {
        HStack(spacing: 3) {
            Text("AI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))

            ForEach(presentation.entries) { entry in
                pill(entry.text, color: color(for: entry))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func color(for entry: StatusBarPresentation.Entry) -> Color {
        guard entry.isConnected else { return unavailableColor }
        return QuotaPalette.tint(for: entry.item)
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
