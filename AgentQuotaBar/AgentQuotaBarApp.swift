import SwiftUI

@main
struct AgentQuotaBarApp: App {
    @StateObject private var controller = QuotaController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
                .task {
                    // 菜单首次出现时启动
                    controller.start()
                }
        } label: {
            MenuBarLabel(controller: controller)
        }
        .menuBarExtraStyle(.menu)
    }
}
