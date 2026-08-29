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
                Text(presentation.fallbackText)
            }
        }
        .accessibilityLabel(presentation.accessibilityDescription)
    }

    /// 五项值与顺序、连接状态、回退文本与无障碍文案的单一来源。
    private var presentation: StatusBarPresentation {
        StatusBarPresentation(
            settings: controller.displaySettings,
            cursorUsage: controller.cursorUsage,
            cursorAvailable: controller.shouldShowCursor,
            cursorState: controller.cursorConnectionState,
            codexUsage: controller.codexUsage,
            codexState: controller.codexConnectionState
        )
    }

    private var renderedLabel: NSImage? {
        let renderer = ImageRenderer(
            content: StatusBarBadge(presentation: presentation)
                .fixedSize()
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }
}
