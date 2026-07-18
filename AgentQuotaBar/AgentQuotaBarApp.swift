import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("Agent Quota Bar launched")
        LaunchAtLoginService.registerIfNeeded()
    }
}

@main
struct AgentQuotaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = QuotaController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            MenuBarLabel(controller: controller)
        }
        // `.menu` 会把 SwiftUI 内容重新解释成系统菜单项，破坏卡片布局。
        // `.window` 才能完整保留设计稿所需的自定义弹层 UI。
        .menuBarExtraStyle(.window)
    }
}
