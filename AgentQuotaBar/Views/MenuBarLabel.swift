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
                Text("CC \(cursorPercentText) \(otherPercentText) \(codexPercentText)")
            }
        }
        .accessibilityLabel("Cursor \(cursorPercentText)，Other \(otherPercentText)，Codex \(codexPercentText)")
    }

    private var renderedLabel: NSImage? {
        let renderer = ImageRenderer(
            content: StatusBarBadge(
                cursorText: cursorPercentText,
                otherText: otherPercentText,
                codexText: codexPercentText,
                cursorConnected: cursorConnected,
                otherConnected: otherConnected,
                codexConnected: codexConnected
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
        controller.cursorConnectionState.isConnected && controller.cursorUsage != nil
    }

    private var otherConnected: Bool {
        controller.cursorConnectionState.isConnected && controller.cursorUsage != nil
    }

    private var codexConnected: Bool {
        controller.codexConnectionState.isConnected && controller.codexUsage.isConnected
    }
}

private struct StatusBarBadge: View {
    let cursorText: String
    let otherText: String
    let codexText: String
    let cursorConnected: Bool
    let otherConnected: Bool
    let codexConnected: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text("CC")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))

            pill(
                cursorText,
                color: cursorConnected
                    ? Color(red: 0.04, green: 0.45, blue: 0.96)
                    : unavailableColor
            )
            pill(
                otherText,
                color: otherConnected
                    ? Color(red: 0.39, green: 0.39, blue: 0.39)
                    : unavailableColor
            )
            pill(
                codexText,
                color: codexConnected
                    ? Color(red: 0.00, green: 0.62, blue: 0.32)
                    : unavailableColor
            )
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
