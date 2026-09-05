import Combine
import Foundation
import ServiceManagement

/// 抹平 `SMAppService` 的系统状态，避免界面层依赖 ServiceManagement 细节。
enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool {
        self == .enabled
    }

    var needsSystemApproval: Bool {
        self == .requiresApproval
    }
}

/// 系统登录项的最小适配层，供设置状态与单元测试共同使用。
protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
}

struct LaunchAtLoginService: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// 设置页使用的状态层。系统注册状态是唯一真实来源，不额外持久化偏好。
@MainActor
final class LaunchAtLoginSettings: ObservableObject {
    static let loginItemsSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )!

    @Published private(set) var status: LaunchAtLoginStatus
    @Published private(set) var didFailLastUpdate = false

    private let service: LaunchAtLoginControlling

    init(service: LaunchAtLoginControlling = LaunchAtLoginService()) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool {
        status.isEnabled
    }

    var needsSystemApproval: Bool {
        status.needsSystemApproval
    }

    func refresh() {
        status = service.status
        didFailLastUpdate = false
    }

    func setEnabled(_ enabled: Bool) {
        didFailLastUpdate = false

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // 不记录底层错误，避免将系统路径或实现细节带入日志。
            AppLog.app.error("Launch-at-login update failed")
            didFailLastUpdate = true
        }

        status = service.status
    }
}
