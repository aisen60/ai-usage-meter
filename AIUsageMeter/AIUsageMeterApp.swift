import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppUpdateHelper.isInvocation {
            AppUpdateHelper.runIfNeeded()
            return
        }
        AppLog.app.info("AI Usage Meter launched")
    }
}

@main
struct AIUsageMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller: QuotaController
    @StateObject private var appUpdateController: AppUpdateController
    @State private var appLanguage: AppLanguage

    init() {
        // macOS 单元测试会启动宿主 App。测试期间禁用缓存、凭据和真实服务访问，
        // 保证普通测试只运行受控的本地逻辑。
        let isRunningTests = ProcessInfo.processInfo.environment[
            "XCTestConfigurationFilePath"
        ] != nil
        let isUpdateHelper = AppUpdateHelper.isInvocation
        _controller = StateObject(
            wrappedValue: QuotaController(autoStart: !isRunningTests && !isUpdateHelper)
        )
        _appUpdateController = StateObject(
            wrappedValue: AppUpdateController(autoStart: !isRunningTests && !isUpdateHelper)
        )
        _appLanguage = State(initialValue: AppLanguage.load())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                controller: controller,
                appUpdateController: appUpdateController,
                appLanguage: $appLanguage
            )
                .environment(\.locale, appLanguage.locale)
        } label: {
            MenuBarLabel(controller: controller)
                .environment(\.locale, appLanguage.locale)
        }
        // `.menu` 会把 SwiftUI 内容重新解释成系统菜单项，破坏卡片布局。
        // `.window` 才能完整保留设计稿所需的自定义弹层 UI。
        .menuBarExtraStyle(.window)
        .onChange(of: appLanguage) { language in
            language.save()
        }
    }
}
