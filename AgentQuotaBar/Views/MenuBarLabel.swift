import SwiftUI
import AppKit

/// 菜单栏标题。将复合视图渲染成一张原色图片，避免 MenuBarExtra
/// 只保留第一个 Text，导致百分比胶囊被系统裁剪。
struct MenuBarLabel: View {
    @ObservedObject var controller: QuotaController

    var body: some View {
        Group {
            if let image = renderedLabel {
                Image(nsImage: image)
                    .renderingMode(.original)
            } else {
                Text(fallbackText)
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }

    private var renderedLabel: NSImage? {
        let renderer = ImageRenderer(
            content: StatusBarBadge(
                cursorText: cursorPercentText,
                otherText: otherPercentText,
                codexText: codexPercentText,
                cursorConnected: cursorConnected,
                otherConnected: otherConnected,
                codexConnected: codexConnected,
                settings: controller.displaySettings
            )
            .fixedSize()
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    private var cursorPercentText: String {
        guard cursorConnected, let usage = controller.cursorUsage else { return "0%" }
        return "\(Int(usage.autoPercentUsed.rounded()))%"
    }

    private var otherPercentText: String {
        guard otherConnected, let usage = controller.cursorUsage else { return "0%" }
        return "\(Int(usage.apiPercentUsed.rounded()))%"
    }

    private var codexPercentText: String {
        guard codexConnected else { return "0%" }
        return "\(Int(controller.codexUsage.percentRemaining.rounded()))%"
    }

    private var cursorConnected: Bool {
        controller.cursorConnectionState.canDisplayUsage && controller.cursorUsage != nil
    }

    private var otherConnected: Bool {
        cursorConnected
    }

    private var codexConnected: Bool {
        controller.codexConnectionState.isConnected && controller.codexUsage.isConnected
    }

    private var fallbackText: String {
        let values = controller.displaySettings.visibleItems.map(valueText(for:))
        return (["CC"] + values).joined(separator: " ")
    }

    private var accessibilityDescription: String {
        controller.displaySettings.visibleItems
            .map(accessibilityText(for:))
            .joined(separator: "，")
    }

    private func valueText(for item: MenuBarDisplaySettings.Item) -> String {
        switch item {
        case .cursorModels: return cursorPercentText
        case .otherModels: return otherPercentText
        case .codexWeeklyRemaining: return codexPercentText
        }
    }

    private func accessibilityText(for item: MenuBarDisplaySettings.Item) -> String {
        switch item {
        case .cursorModels:
            return "Cursor Models 已用 \(cursorPercentText)\(cursorStateSuffix)"
        case .otherModels:
            return "Other Models 已用 \(otherPercentText)\(cursorStateSuffix)"
        case .codexWeeklyRemaining:
            return "Codex 本周剩余 \(codexPercentText)\(codexStateSuffix)"
        }
    }

    private var cursorStateSuffix: String {
        stateSuffix(for: controller.cursorConnectionState)
    }

    private var codexStateSuffix: String {
        stateSuffix(for: controller.codexConnectionState)
    }

    private func stateSuffix(for state: QuotaController.ConnectionState) -> String {
        switch state {
        case .connected: return ""
        case .stale: return "，缓存数据"
        case .disconnected: return "，未连接"
        case .error: return "，连接异常"
        case .unknown: return "，检测中"
        }
    }
}
